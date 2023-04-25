pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/amb/mocks/MockLoremIpsum.sol";
import "../../contracts/pubsub/LoremIpsumSubscriber.sol";
import "../../contracts/pubsub/LoremIpsumPublisher.sol";
import "../../contracts/amb/interfaces/LoremIpsumHandler.sol";

contract LoremIpsumPublisherTest is Test {
    MockLoremIpsum mock;

    function setUp() public {
        mock = new MockLoremIpsum(1);
    }

    function test() public {
        // TODO after implementation is finalized
    }
}
