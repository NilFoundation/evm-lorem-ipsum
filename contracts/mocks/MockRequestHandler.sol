pragma solidity 0.8.16;

import "../amb/interfaces/ILoremIpsum.sol";

contract MockRequestHandler is ILoremIpsumRequestHandler {

    event OK(uint32 some_random_succes_code);

    function handleRequestMessage(
        uint32 _sourceChainId, 
        address _sourceAddress, 
        bytes memory _data)
    public returns (bytes4) {
        emit OK(0x12345);
        return ILoremIpsumRequestHandler.handleRequestMessage.selector;
    }
}