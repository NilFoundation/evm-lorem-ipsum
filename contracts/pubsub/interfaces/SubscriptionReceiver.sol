pragma solidity ^0.8.16;

import "../LoremIpsumPubSub.sol";

abstract contract SubscriptionReceiver is ISubscriptionReceiver {
    error NotFromLoremIpsumPubSub(address sender);

    LoremIpsumPubSub public pubSub;

    constructor(address _pubSub) {
        pubSub = LoremIpsumPubSub(_pubSub);
    }

    function handlePublish(
        bytes32 _subscriptionId,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint64 _slot,
        bytes32[] memory _eventTopics,
        bytes memory _eventdata
    ) external override returns (bytes4) {
        if (msg.sender != address(pubSub)) {
            revert NotFromLoremIpsumPubSub(msg.sender);
        }
        handlePublishImpl(
            _subscriptionId, _sourceChainId, _sourceAddress, _slot, _eventTopics, _eventdata
        );
        return ISubscriptionReceiver.handlePublish.selector;
    }

    function handlePublishImpl(
        bytes32 _subscriptionId,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint64 _slot,
        bytes32[] memory _eventTopics,
        bytes memory _eventdata
    ) internal virtual;
}
