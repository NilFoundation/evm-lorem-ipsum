pragma solidity ^0.8.16;

import "./LoremIpsumPublisher.sol";
import "./LoremIpsumSubscriber.sol";

// TODO: This (and Oracle Fulfiller) probably should have access control so the LoremIpsumRouter reference can be set again.

/// @notice This allows an on-chain Publisher-Suscriber model to be used for events. Contracts can subscribe to
///         events emitted from a source contract, and it will be relayed these events through the publisher. Before
///         the events are relayed, they are verified using the Light Client for proof of consensus on the
///         source chain.
contract LoremIpsumPubSub is LoremIpsumPublisher, LoremIpsumSubscriber {
    uint8 public constant VERSION = 1;

    constructor(address _router) {
        router = LoremIpsumRouter(_router);
    }

    // This contract is mostly just a placeholder which follows the same LoremIpsumRouter pattern. In the future it can
    // be modified to handle upgradability.
}
