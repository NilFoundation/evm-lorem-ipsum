pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

import "../../contracts/amb/mocks/MockLoremIpsum.sol";
import "../../contracts/pubsub/LoremIpsumSubscriber.sol";
import "../../contracts/amb/interfaces/LoremIpsumHandler.sol";

contract EventProofTest is Test, EventProofFixture {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    uint256 constant FIXTURE_START = 18;
    uint256 constant FIXTURE_END = 22;

    Fixture[] fixtures;

    function setUp() public {
        // read all event proof fixtures
        for (uint256 i = FIXTURE_START; i <= FIXTURE_END; i++) {
            uint256 msgNonce = i;

            string memory filename = string.concat("eventProof", Strings.toString(msgNonce));
            string memory path =
            string.concat(vm.projectRoot(), "/test/pubsub/fixtures/", filename, ".json");
            try vm.readFile(path) returns (string memory file) {
                bytes memory parsed = vm.parseJson(file);
                fixtures.push(abi.decode(parsed, (Fixture)));
            } catch {
                continue;
            }
        }
    }

    function test_SetUp() public view {
        require(fixtures.length > 0, "no fixtures found");
    }

    function test_VerifyEvent() public {
        for (uint256 i = 0; i < fixtures.length; i++) {
            Fixture memory fixture = fixtures[i];

            bytes[] memory receiptProof = buildProof(fixture);

            (bytes32[] memory eventTopics, bytes memory eventData) = EventProof.parseEvent(
                receiptProof,
                fixture.receiptsRoot,
                vm.parseBytes(fixture.key),
                fixture.logIndex,
                fixture.logSource,
                fixture.logTopics[0]
            );

            assertEq(eventTopics.length, fixture.logTopics.length);
            for (uint256 j = 0; j < eventTopics.length; j++) {
                assertEq(eventTopics[j], fixture.logTopics[j]);
            }
            assertEq(eventData, fixture.logData);
        }
    }

    function test_VerifyEventRevert_WhenEventSourceInvalid() public {
        for (uint256 i = 0; i < fixtures.length; i++) {
            Fixture memory fixture = fixtures[i];

            bytes[] memory receiptProof = buildProof(fixture);

            vm.expectRevert("Event was not emitted by source contract");
            EventProof.parseEvent(
                receiptProof,
                fixture.receiptsRoot,
                vm.parseBytes(fixture.key),
                fixture.logIndex,
                makeAddr("bad"),
                fixture.logTopics[0]
            );
        }
    }

    function test_VerifyEventRevert_WhenEventSigInvalid() public {
        for (uint256 i = 0; i < fixtures.length; i++) {
            Fixture memory fixture = fixtures[i];

            bytes[] memory receiptProof = buildProof(fixture);

            vm.expectRevert("Event signature does not match");
            EventProof.parseEvent(
                receiptProof,
                fixture.receiptsRoot,
                vm.parseBytes(fixture.key),
                fixture.logIndex,
                fixture.logSource,
                keccak256("Incremented(uint256)")
            );
        }
    }
}
