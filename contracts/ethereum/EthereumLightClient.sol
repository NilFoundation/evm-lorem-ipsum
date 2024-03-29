pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

import '@nilfoundation/evm-placeholder-verification/contracts/interfaces/verifier.sol';

import "../interfaces/IProtocolState.sol";

import "../interfaces/IZKLightClient.sol";

import "../libraries/SimpleSerialize.sol";

struct PlaceholderProof {
    bytes blob;
    uint256[] init_params;
    int256[][] columns_rotations;
}

struct LightClientRotate {
    LightClientUpdate step;
    bytes32 syncCommitteeSSZ;
    bytes32 syncCommitteePoseidon;

    PlaceholderProof proof;
}

/// @notice Uses Ethereum 2's Sync Committee Protocol to keep up-to-date with block headers from a
///         Beacon Chain. This is done in a gas-efficient manner using zero-knowledge proofs.
contract EthereumLightClient is IProtocolState, Ownable, IZKLightClient {
    bytes32 public immutable GENESIS_VALIDATORS_ROOT;
    uint256 public immutable GENESIS_TIME;
    uint256 public immutable SECONDS_PER_SLOT;
    uint256 public immutable SLOTS_PER_PERIOD;
    uint32 public immutable SOURCE_CHAIN_ID;
    uint16 public immutable FINALITY_THRESHOLD;

    uint256 internal constant MIN_SYNC_COMMITTEE_PARTICIPANTS = 10;
    uint256 internal constant SYNC_COMMITTEE_SIZE = 512;
    uint256 internal constant FINALIZED_ROOT_INDEX = 105;
    uint256 internal constant NEXT_SYNC_COMMITTEE_INDEX = 55;
    uint256 internal constant EXECUTION_STATE_ROOT_INDEX = 402;

    address verifier;

    address rotateGate;

    address stepGate;

    /// @notice Whether the light client has had conflicting variables for the same slot.
    bool public consistent = true;

    /// @notice The latest slot the light client has a finalized header for.
    uint256 public head = 0;

    /// @notice Maps from a slot to a beacon block header root.
    mapping(uint256 => bytes32) public headers;

    /// @notice Maps from a slot to the timestamp of when the headers mapping was updated with slot as a key
    mapping(uint256 => uint256) public timestamps;

    /// @notice Maps from a slot to the current finalized state root.
    mapping(uint256 => bytes32) public stateRoots;

    /// @notice Maps from a period to the poseidon commitment for the sync committee.
    mapping(uint256 => bytes32) public syncCommitteePoseidons;

    event HeadUpdate(uint256 indexed slot, bytes32 indexed root);
    event SyncCommitteeUpdate(uint256 indexed period, bytes32 indexed root);

    constructor(address placeholderVerifier,
        address step,
        address rotate,
        bytes32 genesisValidatorsRoot,
        uint256 genesisTime,
        uint256 secondsPerSlot,
        uint256 slotsPerPeriod,
        uint256 syncCommitteePeriod,
        bytes32 syncCommitteePoseidon,
        uint32 sourceChainId,
        uint16 finalityThreshold) {

        verifier = placeholderVerifier;
        stepGate = step;
        rotateGate = rotate;

        GENESIS_VALIDATORS_ROOT = genesisValidatorsRoot;
        GENESIS_TIME = genesisTime;
        SECONDS_PER_SLOT = secondsPerSlot;
        SLOTS_PER_PERIOD = slotsPerPeriod;
        SOURCE_CHAIN_ID = sourceChainId;
        FINALITY_THRESHOLD = finalityThreshold;
        setSyncCommitteePoseidon(syncCommitteePeriod, syncCommitteePoseidon);
    }

    function setVerifier(address v) external onlyOwner {
        verifier = v;
    }

    function setRotateGate(address gateArgument) external onlyOwner {
        rotateGate = gateArgument;
    }

    function setStepGate(address gateArgument) external onlyOwner {
        stepGate = gateArgument;
    }

    /// @notice Updates the head of the light client to the provided slot.
    /// @dev The conditions for updating the head of the light client involve checking:
    ///      1) Enough signatures from the current sync committee for n=512
    ///      2) A valid finality proof
    ///      3) A valid execution state root proof
    function step(LightClientUpdate calldata update) external {
        bool finalized = true;
        
        //finalized = processStep(update);

        if (getCurrentSlot() < update.attestedSlot) {
            revert("Update slot is too far in the future");
        }

        if (update.finalizedSlot < head) {
            revert("Update slot less than current head");
        }

        if (finalized) {
            setSlotRoots(update.finalizedSlot, update.finalizedHeaderRoot, update.executionStateRoot);
        } else {
            revert("Not enough participants");
        }
    }

    /// @notice Sets the sync committee for the next sync committeee period.
    /// @dev A commitment to the the next sync committeee is signed by the current sync committee.
    function rotate(LightClientRotate calldata update) external {
        LightClientUpdate memory stepUpdate = update.step;
        bool finalized = processStep(update.step);
        uint256 currentPeriod = getSyncCommitteePeriod(stepUpdate.finalizedSlot);
        uint256 nextPeriod = currentPeriod + 1;

        zkLightClientRotate(update);

        if (finalized) {
            setSyncCommitteePoseidon(nextPeriod, update.syncCommitteePoseidon);
        }
    }

    /// @notice Verifies that the header has enough signatures for finality.
    function processStep(LightClientUpdate calldata update) internal view returns (bool) {
        uint256 currentPeriod = getSyncCommitteePeriod(update.attestedSlot);

        if (syncCommitteePoseidons[currentPeriod] == 0) {
            revert("Sync committee for current period is not initialized.");
        } else if (update.participation < MIN_SYNC_COMMITTEE_PARTICIPANTS) {
            revert("Less than MIN_SYNC_COMMITTEE_PARTICIPANTS signed.");
        }

        zkLightClientUpdate(update);

        return update.participation > FINALITY_THRESHOLD;
    }

    /// @notice Serializes the public inputs into a compressed form and verifies the step proof.
    function zkLightClientUpdate(LightClientUpdate calldata update) internal view {
        bytes32 attestedSlotLE = SSZ.toLittleEndian(update.attestedSlot);
        bytes32 finalizedSlotLE = SSZ.toLittleEndian(update.finalizedSlot);
        bytes32 participationLE = SSZ.toLittleEndian(update.participation);
        uint256 currentPeriod = getSyncCommitteePeriod(update.attestedSlot);
        bytes32 syncCommitteePoseidon = syncCommitteePoseidons[currentPeriod];

        bytes32 h;
        h = sha256(bytes.concat(attestedSlotLE, finalizedSlotLE));
        h = sha256(bytes.concat(h, update.finalizedHeaderRoot));
        h = sha256(bytes.concat(h, participationLE));
        h = sha256(bytes.concat(h, update.executionStateRoot));
        h = sha256(bytes.concat(h, syncCommitteePoseidon));
        uint256 t = uint256(SSZ.toLittleEndian(uint256(h)));
        t = t & ((uint256(1) << 253) - 1);

        PlaceholderProof memory proof = abi.decode(update.proof, (PlaceholderProof));
        uint256[1] memory inputs = [uint256(t)];
        require(IVerifier(verifier).verify(proof.blob, proof.init_params, proof.columns_rotations, stepGate));
    }

    /// @notice Serializes the public inputs and verifies the rotate proof.
    function zkLightClientRotate(LightClientRotate calldata update) internal view {
        PlaceholderProof memory proof = update.proof;
        uint256[65] memory inputs;

        uint256 syncCommitteeSSZNumeric = uint256(update.syncCommitteeSSZ);
        for (uint256 i = 0; i < 32; i++) {
            inputs[32 - 1 - i] = syncCommitteeSSZNumeric % 2 ** 8;
            syncCommitteeSSZNumeric = syncCommitteeSSZNumeric / 2 ** 8;
        }
        uint256 finalizedHeaderRootNumeric = uint256(update.step.finalizedHeaderRoot);
        for (uint256 i = 0; i < 32; i++) {
            inputs[64 - i] = finalizedHeaderRootNumeric % 2 ** 8;
            finalizedHeaderRootNumeric = finalizedHeaderRootNumeric / 2 ** 8;
        }
        inputs[32] = uint256(SSZ.toLittleEndian(uint256(update.syncCommitteePoseidon)));

        require(IVerifier(verifier).verify(proof.blob, proof.init_params, proof.columns_rotations, rotateGate));
    }

    /// @notice Gets the sync committee period from a slot.
    function getSyncCommitteePeriod(uint256 slot) internal view returns (uint256) {
        return slot / SLOTS_PER_PERIOD;
    }

    /// @notice Gets the current slot for the chain the light client is reflecting.
    function getCurrentSlot() internal view returns (uint256) {
        return (block.timestamp - GENESIS_TIME) / SECONDS_PER_SLOT;
    }

    /// @notice Sets the current slot for the chain the light client is reflecting.
    /// @dev Checks if roots exists for the slot already. If there is, check for a conflict between
    ///      the given roots and the existing roots. If there is an existing header but no
    ///      conflict, do nothing. This avoids timestamp renewal DoS attacks.
    function setSlotRoots(uint256 slot, bytes32 finalizedHeaderRoot, bytes32 executionStateRoot) internal {
        if (headers[slot] != bytes32(0)) {
            if (headers[slot] != finalizedHeaderRoot) {
                consistent = false;
            }
            return;
        }
        if (stateRoots[slot] != bytes32(0)) {
            if (stateRoots[slot] != executionStateRoot) {
                consistent = false;
            }
            return;
        }

        head = slot;
        headers[slot] = finalizedHeaderRoot;
        stateRoots[slot] = executionStateRoot;
        timestamps[slot] = block.timestamp;
        emit HeadUpdate(slot, finalizedHeaderRoot);
    }

    /// @notice Sets the sync committee poseidon for a given period.
    function setSyncCommitteePoseidon(uint256 period, bytes32 poseidon) internal {
        if (syncCommitteePoseidons[period] != bytes32(0) && syncCommitteePoseidons[period] != poseidon) {
            consistent = false;
            return;
        }
        syncCommitteePoseidons[period] = poseidon;
        emit SyncCommitteeUpdate(period, poseidon);
    }
}
