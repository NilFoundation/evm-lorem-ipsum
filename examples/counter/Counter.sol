pragma solidity 0.8.16;

import "../../contracts/amb/interfaces/ILoremIpsum.sol";

contract Counter is ILoremIpsumHandler {
    uint256 public counter = 0;
    address public router;

    event Incremented(uint32 indexed sourceChainId, address indexed sender);

    constructor(address _router) {
        router = _router;
    }

    function handleMessage(uint32 sourceChainId, address sender, bytes memory)
        public
        returns (bytes4)
    {
        require(msg.sender == address(router), "Sender is not router");
        counter = counter + 1;
        emit Incremented(sourceChainId, sender);
        return ILoremIpsumHandler.handleMessage.selector;
    }
}
