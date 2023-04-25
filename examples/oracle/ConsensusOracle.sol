contract BeaconValidatorBalance {
    uint256 public constant VALIDATOR_PUBKEY_GINDEX = 0;
    uint256 public constant BALANCE_G_INDEX = 1;

    address lightclient;
    mapping(uint256 => bytes32) public indexToPubkey;
    mapping(uint256 => mapping(uint256 => uint256)) public indexToSlotToBalance;

    constructor(address _lightclient) {
        lightclient = _lightclient;
    }

    function addIndexAndPubkey(
        uint256 slot, uint256 index, bytes32 publicKey, bytes32[] memory proof
    ) public {
        bytes32 headerRoot = ILightClient(lightclient).headers(slot);
        bool isValidProof = SSZ.verifyMerkleBranch(
            publicKey,
            concatGIndex(VALIDATOR_PUBKEY_GINDEX, index),
            proof,
            headerRoot
        );
        require(isValidProof, "Invalid state root");
        indexToPubkey[index] = publicKey;
    }

    function addBalanceAtSlot(uint256 slot, uint256 index, uint256 balance, bytes32[] memory proof) public {
        bytes32 headerRoot = ILightClient(lightclient).headers(slot);
        bool isValidProof = SSZ.verifyMerkleBranch(
            bytes32(balance),
            concatGIndex(BALANCE_G_INDEX, index),
            proof,
            headerRoot
        );
        require(isValidProof, "Invalid state root");
        indexToSlotToBalance[index][slot] = balance;
    }
}