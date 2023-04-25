pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../../contracts/amb/mocks/MockLoremIpsum.sol";
import "../../../contracts/pubsub/LoremIpsumPubSub.sol";
import "../../../contracts/amb/interfaces/LoremIpsumHandler.sol";
import "./LoremIpsumValidator.sol";

interface IForeignAMB {}

interface IBasicHomeAMB {
    function executeAffirmation(bytes calldata message) external;
}

contract LoremIpsumValidatorTest is Test {
    event Subscribe(
        bytes32 indexed subscriptionId,
        uint64 indexed startSlot,
        uint64 indexed endSlot,
        Subscription subscription
    );

    MockLoremIpsum mockLoremIpsum;
    LoremIpsumPubSub pubSub;
    IBasicHomeAMB basicHomeAMB;
    IForeignAMB foreignAMB;
    LoremIpsumValidator validator;
    address owner = makeAddr("owner");

    uint32 DESTINATION_CHAIN = 100;
    uint32 SOURCE_CHAIN = 1;
    bytes32 EVENT_SIG = keccak256("UserRequestForAffirmation(bytes32,bytes)");

    function setUp() public {
        mockLoremIpsum = new MockLoremIpsum(DESTINATION_CHAIN);
        pubSub = new LoremIpsumPubSub(address(mockLoremIpsum));

        basicHomeAMB = IBasicHomeAMB(makeAddr("BasicHomeAMB"));
        foreignAMB = IForeignAMB(makeAddr("ForeignAMB"));

        validator = new LoremIpsumValidator(
            address(pubSub),
            SOURCE_CHAIN,
            address(foreignAMB),
            0,
            0,
            address(basicHomeAMB),
            owner
        );
    }

    function test_SubscribeToAffirmationEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(
                    Subscription(
                        SOURCE_CHAIN, address(foreignAMB), address(validator), EVENT_SIG
                    )
                )
            ),
            uint64(0),
            uint64(0),
            Subscription(SOURCE_CHAIN, address(foreignAMB), address(validator), EVENT_SIG)
        );
        vm.prank(owner);
        validator.subscribeToAffirmationEvent();
    }

    function test_toggleExecuteAffirmations() public {
        vm.prank(owner);
        validator.toggleExecuteAffirmations();
    }
}
