pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/mocks/ERC721Mock.sol";

import "../../contracts/amb/mocks/MockLoremIpsum.sol";
import "../../contracts/oracle/LoremIpsumOracleFulfiller.sol";
import "./NFTAirdrop.sol";

contract SimpleNFTAirdrop is NFTAirdrop {
    constructor(address _nft, address _oracle) payable NFTAirdrop(_nft, _oracle) {
        require(msg.value == 10 ether);
    }

    function _giveAirdrop(address _to, uint256) internal override {
        (bool success,) = payable(_to).call{value: 1 ether}("");
        require(success);
    }
}

contract NFTAirdropTest is Test {
    MockLoremIpsum messageRouterSrc;
    MockLoremIpsum messageRouterDst;
    LoremIpsumOracleFulfiller fulfiller;
    LoremIpsumOracle oracle;
    ERC721Mock nft;
    NFTAirdrop nftAirdrop;

    uint32 ORACLE_CHAIN = 137;
    uint32 FULFILLER_CHAIN = 1;

    address USER = makeAddr("user");
    address USER2 = makeAddr("user2");

    function setUp() public {
        messageRouterSrc = new MockLoremIpsum(FULFILLER_CHAIN);
        messageRouterDst = new MockLoremIpsum(ORACLE_CHAIN);
        messageRouterSrc.addMessageReceiver(ORACLE_CHAIN, messageRouterDst);
        fulfiller = new LoremIpsumOracleFulfiller(address(messageRouterSrc));
        oracle = new LoremIpsumOracle(
            FULFILLER_CHAIN,
            address(messageRouterDst),
            address(fulfiller)
        );
        nft = new ERC721Mock("Test NFT", "NFT");
        nftAirdrop = new SimpleNFTAirdrop{value: 10 ether}(
            address(nft),
            address(oracle)
        );
    }

    function sendClaim(address, uint256 tokenId) internal {
        vm.prank(USER);
        nftAirdrop.claimAirdrop(tokenId);
        fulfiller.fulfillCrossChainRequest(
            ORACLE_CHAIN,
            address(oracle),
            RequestData(
                1,
                address(nft),
                abi.encodeWithSignature("ownerOf(uint256)", tokenId),
                address(nftAirdrop)
            )
        );
    }

    /// @dev Gets Router message and decodes the remote query data+success
    function getOracleResponse(uint64 messageNonce)
        internal
        view
        returns (bytes memory responseData, bool responseSuccess)
    {
        (,,,,,, bytes memory messageData) = messageRouterSrc.sentMessages(messageNonce);

        (,,, responseData, responseSuccess) =
            abi.decode(messageData, (uint256, bytes32, address, bytes, bool));
    }

    function testSimple() public {
        uint256 tokenId = 0;
        nft.mint(USER, tokenId);

        sendClaim(USER, tokenId);
        messageRouterSrc.executeNextMessage();
        assertEq(USER.balance, 1 ether);
    }

    function testRevertNotOwner() public {
        uint256 tokenId = 0;
        nft.mint(address(this), tokenId);

        sendClaim(USER, tokenId);

        (bytes memory responseData, bool responseSuccess) = getOracleResponse(1);

        vm.expectRevert(abi.encodeWithSelector(NFTAirdrop.NotOwnerOfToken.selector, USER, tokenId));
        vm.prank(address(oracle));
        nftAirdrop.handleOracleResponse(1, responseData, responseSuccess);
    }

    function testRevertQueryFailed() public {
        uint256 tokenId = 0;
        // not minting the token so ownerOf will fail

        sendClaim(USER, tokenId);

        (bytes memory responseData, bool responseSuccess) = getOracleResponse(1);

        vm.expectRevert(abi.encodeWithSelector(NFTAirdrop.OracleQueryFailed.selector));
        vm.prank(address(oracle));
        nftAirdrop.handleOracleResponse(1, responseData, responseSuccess);
    }

    function testRevertNotOracle() public {
        uint256 tokenId = 0;
        nft.mint(address(USER), tokenId);

        sendClaim(USER, tokenId);

        (bytes memory responseData, bool responseSuccess) = getOracleResponse(1);

        vm.expectRevert(abi.encodeWithSelector(NFTAirdrop.NotFromOracle.selector, address(this)));
        nftAirdrop.handleOracleResponse(1, responseData, responseSuccess);
    }

    function testRevertAlreadyClaimed() public {
        // claim1, response1, transfer, claim2
        uint256 tokenId = 0;
        nft.mint(address(USER), tokenId);

        // claim1
        sendClaim(USER, tokenId);

        (bytes memory responseData, bool responseSuccess) = getOracleResponse(1);

        // response1
        vm.prank(address(oracle));
        nftAirdrop.handleOracleResponse(1, responseData, responseSuccess);

        // transfer
        vm.prank(USER);
        nft.transferFrom(USER, USER2, tokenId);

        // claim2
        vm.expectRevert(abi.encodeWithSelector(NFTAirdrop.AlreadyClaimed.selector, tokenId));
        sendClaim(USER2, tokenId);
    }

    function testRevertClaimWhileFirstClaimPending() public {
        // claim1, transfer, claim2, response1, response2
        uint256 tokenId = 0;
        nft.mint(address(USER), tokenId);

        // claim1
        sendClaim(USER, tokenId);

        // transfer
        vm.prank(USER);
        nft.transferFrom(USER, USER2, tokenId);

        // claim2
        sendClaim(USER2, tokenId);

        (bytes memory responseData, bool responseSuccess) = getOracleResponse(1);

        (bytes memory responseData2, bool responseSuccess2) = getOracleResponse(2);

        // reponse1
        vm.prank(address(oracle));
        nftAirdrop.handleOracleResponse(1, responseData, responseSuccess);

        // response2
        vm.expectRevert(abi.encodeWithSelector(NFTAirdrop.AlreadyClaimed.selector, tokenId));
        vm.prank(address(oracle));
        nftAirdrop.handleOracleResponse(1, responseData2, responseSuccess2);
    }
}
