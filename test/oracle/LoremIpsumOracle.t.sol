// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/amb/interfaces/ILoremIpsum.sol";
import "../../contracts/amb/mocks/MockLoremIpsum.sol";
import "../../contracts/oracle/LoremIpsumOracle.sol";
import "../../contracts/oracle/LoremIpsumOracleFulfiller.sol";

contract MockMainnetData {
    uint256 val = block.timestamp;

    function get() public view returns (uint256) {
        return val;
    }

    function hashString(string memory str) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(str));
    }
}

contract MockReceiver is IOracleCallbackReceiver {
    uint256 public result;

    function handleOracleResponse(uint256, bytes memory responseData, bool) external override {
        result = abi.decode(responseData, (uint256));
    }
}

contract LoremIpsumOracleTest is Test {
    event CrossChainRequestSent(
        uint256 indexed nonce,
        address targetContract,
        bytes targetCalldata,
        address callbackContract
    );

    MockLoremIpsum routerSrc;
    MockLoremIpsum routerDst;
    LoremIpsumOracleFulfiller fulfiller;
    LoremIpsumOracle oracle;

    uint32 ORACLE_CHAIN = 137;
    uint32 FULFILLER_CHAIN = 1;

    function makeRequest(
        address targetContract,
        bytes memory targetCalldata,
        address callbackContract
    ) internal returns (RequestData memory requestData, bytes32 requestHash) {
        uint256 nonce = oracle.requestCrossChain(targetContract, targetCalldata, callbackContract);
        requestData = RequestData(nonce, targetContract, targetCalldata, callbackContract);
        requestHash = keccak256(abi.encode(requestData));
    }

    function setUp() public {
        routerSrc = new MockLoremIpsum(FULFILLER_CHAIN);
        routerDst = new MockLoremIpsum(ORACLE_CHAIN);
        routerSrc.addTelepathyReceiver(ORACLE_CHAIN, routerDst);
        fulfiller = new LoremIpsumOracleFulfiller(address(routerSrc));
        oracle = new LoremIpsumOracle{salt: 0}(
            FULFILLER_CHAIN,
            address(routerDst),
            address(fulfiller)
        );
    }

    function testSimple() public {
        MockMainnetData mockMainnetData = new MockMainnetData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockMainnetData);
        bytes memory targetCalldata = abi.encodeWithSelector(MockMainnetData.get.selector);
        address callbackContract = address(receiver);

        vm.expectEmit(true, true, true, false);
        emit CrossChainRequestSent(1, targetContract, targetCalldata, callbackContract);
        (RequestData memory requestData, bytes32 requestHash) =
        makeRequest(targetContract, targetCalldata, callbackContract);
        assertEq(requestData.nonce, 1);
        assertTrue(oracle.requests(requestHash) == RequestStatus.PENDING);

        fulfiller.fulfillCrossChainRequest(ORACLE_CHAIN, address(oracle), requestData);

        routerSrc.executeNextMessage();

        assertEq(receiver.result(), mockMainnetData.get());
    }

    function testRevertNotFromRouter() public {
        vm.expectRevert(
            abi.encodeWithSelector(LoremIpsumHandler.NotFromLoremIpsumRouter.selector, address(this))
        );
        oracle.handleMessage(FULFILLER_CHAIN, address(fulfiller), "");
    }

    function testRevertWrongChainId() public {
        vm.prank(address(routerDst));
        vm.expectRevert(abi.encodeWithSelector(LoremIpsumOracle.InvalidChainId.selector, 12345));
        oracle.handleMessage(12345, address(fulfiller), "");
    }

    function testRevertNotFromFulfiller() public {
        vm.prank(address(routerDst));
        vm.expectRevert(
            abi.encodeWithSelector(LoremIpsumOracle.NotFulfiller.selector, address(this))
        );
        oracle.handleMessage(FULFILLER_CHAIN, address(this), "");
    }

    function testRevertReplayResponse() public {
        MockMainnetData mockMainnetData = new MockMainnetData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockMainnetData);
        bytes memory targetCalldata = abi.encodeWithSelector(MockMainnetData.get.selector);
        address callbackContract = address(receiver);

        (RequestData memory requestData, bytes32 requestHash) =
        makeRequest(targetContract, targetCalldata, callbackContract);

        fulfiller.fulfillCrossChainRequest(ORACLE_CHAIN, address(oracle), requestData);
        (,, uint32 sourceChainId, address senderAddress,,, bytes memory data) =
        routerSrc.sentMessages(1);
        vm.prank(address(routerDst));
        oracle.handleMessage(sourceChainId, senderAddress, data);

        fulfiller.fulfillCrossChainRequest(ORACLE_CHAIN, address(oracle), requestData);
        vm.prank(address(routerDst));
        vm.expectRevert(
            abi.encodeWithSelector(LoremIpsumOracle.RequestNotPending.selector, requestHash)
        );
        oracle.handleMessage(sourceChainId, senderAddress, data);
    }

    function testRevertIncorrectResponseData() public {
        MockMainnetData mockMainnetData = new MockMainnetData();
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(mockMainnetData);
        bytes memory targetCalldata =
        abi.encodeWithSelector(MockMainnetData.hashString.selector, "hello world");
        address callbackContract = address(receiver);

        bytes memory fakeTargetCalldata =
        abi.encodeWithSelector(MockMainnetData.hashString.selector, "goodbye world");

        (RequestData memory realRequestData,) =
        makeRequest(targetContract, targetCalldata, callbackContract);

        RequestData memory fakeRequestData = RequestData(
            realRequestData.nonce,
            realRequestData.targetContract,
            fakeTargetCalldata,
            realRequestData.callbackContract
        );

        fulfiller.fulfillCrossChainRequest(ORACLE_CHAIN, address(oracle), fakeRequestData);
        (,, uint32 sourceChainId, address senderAddress,,, bytes memory data) =
        routerSrc.sentMessages(1);

        bytes32 fakeRequestHash = keccak256(abi.encode(fakeRequestData));

        vm.prank(address(routerDst));
        vm.expectRevert(
            abi.encodeWithSelector(LoremIpsumOracle.RequestNotPending.selector, fakeRequestHash)
        );
        oracle.handleMessage(sourceChainId, senderAddress, data);
    }

    function testNonContractTarget() public {
        MockReceiver receiver = new MockReceiver();
        assertEq(receiver.result(), 0);
        address targetContract = address(0);
        bytes memory targetCalldata = "";
        address callbackContract = address(receiver);

        (RequestData memory requestData,) =
        makeRequest(targetContract, targetCalldata, callbackContract);

        fulfiller.fulfillCrossChainRequest(ORACLE_CHAIN, address(oracle), requestData);
        (,,,,,, bytes memory responseData) = routerSrc.sentMessages(1);
        (,,,, bool responseSuccess) =
        abi.decode(responseData, (uint256, bytes32, address, bytes, bool));

        assertFalse(responseSuccess);
    }
}
