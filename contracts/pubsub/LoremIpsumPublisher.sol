pragma solidity ^0.8.16;

import "./interfaces/IPubSub.sol";
import "./interfaces/ISubscriptionReceiver.sol";

import "../amb/LoremIpsumRouter.sol";

import "./PubSubStorage.sol";

/// @title LoremIpsumPublisher
/// @author Succinct Labs
/// @notice A contract that can publish events to a ISubscriptionReceiver contract.
contract LoremIpsumPublisher is IPublisher, PubSubStorage {
    /// @notice Publishes an event emit to a callback Subscriber, given an event proof.
    /// @param srcSlotTxSlotPack The slot where we want to read the header from and the slot where
    ///                          the tx executed, packed as two uint64s.
    /// @param receiptsRootProof A merkle proof proving the receiptsRoot in the block header.
    /// @param receiptsRoot The receipts root which contains the event.
    /// @param txIndexRLPEncoded The index of our transaction inside the block RLP encoded.
    /// @param logIndex The index of the event in our transaction.
    /// @param subscription The subscription data (sourceChainId, sourceAddress, callbackAddress, eventSig).
    /// @dev This function should be called for every subscriber that is subscribed to the event.
    function publishEvent(
        bytes calldata srcSlotTxSlotPack,
        bytes32[] calldata receiptsRootProof,
        bytes32 receiptsRoot,
        bytes[] calldata receiptProof,
        bytes memory txIndexRLPEncoded,
        uint256 logIndex,
        Subscription calldata subscription
    ) external {
        requireLightClientConsistency(subscription.sourceChainId);
        requireNotFrozen(subscription.sourceChainId);

        // Ensure the event emit may only be published to a subscriber once
        bytes32 subscriptionId = keccak256(abi.encode(subscription));
        bytes32 publishKey =
        keccak256(abi.encode(srcSlotTxSlotPack, txIndexRLPEncoded, logIndex, subscriptionId));
        require(
            eventsPublished[publishKey] == PublishStatus.NOT_EXECUTED, "Event already published"
        );

        (uint64 srcSlot, uint64 txSlot) = abi.decode(srcSlotTxSlotPack, (uint64, uint64));
        requireLightClientDelay(srcSlot, subscription.sourceChainId);
        bytes32 headerRoot =
        router.lightClients(subscription.sourceChainId).headers(srcSlot);
        require(headerRoot != bytes32(0), "HeaderRoot is missing");
        bool isValid =
        SSZ.verifyReceiptsRoot(receiptsRoot, receiptsRootProof, headerRoot, srcSlot, txSlot);
        require(isValid, "Invalid receipts root proof");

        (bytes32[] memory eventTopics, bytes memory eventData) = EventProof.parseEvent(
            receiptProof,
            receiptsRoot,
            txIndexRLPEncoded,
            logIndex,
            subscription.sourceAddress,
            subscription.eventSig
        );

        _publish(subscriptionId, subscription, publishKey, txSlot, eventTopics, eventData);
    }

    /// @notice Checks that the light client for a given chainId is consistent.
    function requireLightClientConsistency(uint32 chainId) internal view {
        require(
            address(router.lightClients(chainId)) != address(0), "Light client is not set."
        );
        require(router.lightClients(chainId).consistent(), "Light client is inconsistent.");
    }

    /// @notice Checks that the chainId is not frozen.
    function requireNotFrozen(uint32 chainId) internal view {
        require(!router.frozen(chainId), "Contract is frozen.");
    }

    /// @notice Checks that the light client delay is adequate.
    function requireLightClientDelay(uint64 slot, uint32 chainId) internal view {
        require(
            address(router.lightClients(chainId)) != address(0), "Light client is not set."
        );
        require(
            router.lightClients(chainId).timestamps(slot) != 0,
            "Timestamp is not set for slot."
        );
        uint256 elapsedTime =
        block.timestamp - router.lightClients(chainId).timestamps(slot);
        require(
            elapsedTime >= router.MIN_LIGHT_CLIENT_DELAY(),
            "Must wait longer to use this slot."
        );
    }

    /// @notice Executes the callback function on the subscriber, and marks the event publish as successful or failed.
    function _publish(
        bytes32 _subscriptionId,
        Subscription calldata _subscription,
        bytes32 _publishKey,
        uint64 _txSlot,
        bytes32[] memory _eventTopics,
        bytes memory _eventData
    ) internal {
        bool success;
        bytes memory data;
        {
            bytes memory receiveCall = abi.encodeWithSelector(
                ISubscriptionReceiver.handlePublish.selector,
                _subscriptionId,
                _subscription.sourceChainId,
                _subscription.sourceAddress,
                _txSlot,
                _eventTopics,
                _eventData
            );
            (success, data) = _subscription.callbackAddress.call(receiveCall);
        }

        bool implementsHandler = false;
        if (data.length == 32) {
            (bytes4 magic) = abi.decode(data, (bytes4));
            implementsHandler = magic == ISubscriptionReceiver.handlePublish.selector;
        }

        if (success && implementsHandler) {
            eventsPublished[_publishKey] = PublishStatus.EXECUTION_SUCCEEDED;
        } else {
            eventsPublished[_publishKey] = PublishStatus.EXECUTION_FAILED;
        }

        emit Publish(
            _subscriptionId,
            _subscription.sourceChainId,
            _subscription.sourceAddress,
            _subscription.callbackAddress,
            success
        );
    }
}
