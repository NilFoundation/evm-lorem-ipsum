pragma solidity ^0.8.0;

import "./ILoremIpsum.sol";

abstract contract LoremIpsumHandler is ILoremIpsumHandler {
    error NotFromLoremIpsumRouter(address sender);

    address private _router;

    constructor(address router) {
        _router = router;
    }

    function handleMessage(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
    external override returns (bytes4) {
        if (msg.sender != _router) {
            revert NotFromLoremIpsumRouter(msg.sender);
        }
        handleMessageImpl(_sourceChainId, _sourceAddress, _data);
        return ILoremIpsumHandler.handleMessage.selector;
    }

    function handleMessageImpl(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
    internal virtual;
}
