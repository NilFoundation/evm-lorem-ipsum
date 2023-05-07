pragma solidity 0.8.16;

import "@nilfoundation/evm-lorem-ipsum/contracts/amb/interfaces/ILoremIpsum.sol";
import "@nilfoundation/evm-lorem-ipsum/contracts/amb/interfaces/LoremIpsumHandler.sol";

contract SourceCounter {
    ILoremIpsumRouter router;
    uint32 targetChainId;

    constructor(address _router, uint32 _targetChainId) {
        router = ILoremIpsumRouter(_router);
        targetChainId = _targetChainId;
    }

    // Increment counter on target chain by given amount
    function increment(uint256 amount, address targetCounter) external virtual {
        bytes memory msgData = abi.encode(amount);
        router.send(targetChainId, targetCounter, msgData);
    }
}

contract TargetCounter is LoremIpsumHandler {
    uint256 public counter = 0;

    event Incremented(uint32 sourceChainId, address sender, uint256 amount);

    constructor(address _router) LoremIpsumHandler(_router) {}

    // Handle messages being sent and decoding
    function handleMessageImpl(uint32 sourceChainId, address sender, bytes memory msgData)
    internal
    override
    {
        (uint256 amount) = abi.decode(msgData, (uint256));
    unchecked {
        counter = counter + amount;
    }
        emit Incremented(sourceChainId, sender, amount);
    }
}
