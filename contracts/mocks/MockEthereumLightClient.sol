pragma solidity 0.8.16;

import "../interfaces/IProtocolState.sol";

///@notice -- Ethereum Light Client mock. Used for end2end tests
contract MockEthereumLightClient is IProtocolState {

    struct EthereumLightClientState {
        bytes32 stateRootHash;
        bytes32 headers;
        uint256 timestamp;
        uint256 slot;
        bytes32 lightClientStateHash;
    }

    uint256 topSlot;
    bool isConsistent;

    mapping(uint256 => EthereumLightClientState) chainStorage;

    function updateState(bytes memory newRawState) public {
        EthereumLightClientState memory newState = abi.decode(newRawState, (EthereumLightClientState));

        bytes32 lightClientStateHash = keccak256(abi.encode(
            newState.stateRootHash,
            newState.headers,
            newState.timestamp,
            newState.slot
        ));

        require(lightClientStateHash == newState.lightClientStateHash, "lightClientStateHash is corrupted!");
        require(newState.slot > topSlot, "Try to renew old state!");

        topSlot = newState.slot;
        chainStorage[topSlot] = newState;
    }

    ///@notice -- function is used to simplify raw data encoding. The function 
    /// is called from the test environment. Not used in internal code
    function makeTestState(uint256 _slot) external pure returns (bytes memory) {
        EthereumLightClientState memory state;
        
        state.headers = keccak256(abi.encode("headers", _slot));
        state.stateRootHash = keccak256(abi.encode("stateRoots", _slot));
        state.slot = _slot;
        state.timestamp = _slot * 2;
        state.lightClientStateHash = keccak256(abi.encode(
            state.stateRootHash,
            state.headers,
            state.timestamp,
            state.slot
        ));

        return abi.encode(state);
    }

    function consistent() external view returns (bool) {
        return isConsistent;
    }

    function head() external view returns (uint256) {
        return topSlot;
    }

    function headers(uint256 slot) external view returns (bytes32) {
        return chainStorage[slot].headers;
    }

    function stateRoots(uint256 slot) external view returns (bytes32) {
        return chainStorage[slot].stateRootHash;

    }

    function timestamps(uint256 slot) external view returns (uint256) {
        return chainStorage[slot].timestamp;
    }
}