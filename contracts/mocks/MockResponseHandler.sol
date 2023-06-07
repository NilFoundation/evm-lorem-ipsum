pragma solidity ^0.8.16;

import "../amb/interfaces/ILoremIpsum.sol";

contract MockResponseHandler is ILoremIpsumResonseHandler {
    
    function handleResponseMessage(
        uint32 _sourceChainId, 
        address _sourceAddress, 
        bytes memory _response_data) public returns (bytes4) {
        
        return ILoremIpsumResonseHandler.handleResponseMessage.selector;
    }
}

