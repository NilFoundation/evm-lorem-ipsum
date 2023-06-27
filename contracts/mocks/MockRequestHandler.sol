pragma solidity 0.8.16;

import "./MockEthereumLightClient.sol";
import "../amb/interfaces/ILoremIpsum.sol";
import "../interfaces/IProtocolState.sol";

contract MockRequestHandler is ILoremIpsumRequestHandler {

    MockEthereumLightClient lightClient;
    constructor(address _lightClient) {
        lightClient = MockEthereumLightClient(_lightClient);
    }

    ///@notice -- target chain request handle function. If any data is incorrect
    /// there will be a revert called and test failed
    function handleRequestMessage(
        uint32 _sourceChainId, 
        address _sourceAddress, 
        bytes memory _data)
    public returns (bytes4) {

        lightClient.updateState(_data);


        /* Check via IProtocolState interface for clarity */
        IProtocolState state = IProtocolState(lightClient);
        uint256 headSlot = state.head();

        /* state update check and verify with original state from client */
        require(state.headers(headSlot) == keccak256(abi.encode("headers", headSlot)), "Headers are wrong!");
        require(state.stateRoots(headSlot) == keccak256(abi.encode("stateRoots", headSlot)), "Headers are wrong!");
        require(state.timestamps(headSlot) == headSlot * 2, "timestamps are wrong!");

        return ILoremIpsumRequestHandler.handleRequestMessage.selector;
    }
}