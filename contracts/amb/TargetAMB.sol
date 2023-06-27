pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./LoremIpsumStorage.sol";

import "../libraries/SimpleSerialize.sol";
import "../libraries/EventProof.sol";
import "../libraries/Typecast.sol";
import "../libraries/StateProofHelper.sol";
import "../libraries/MessageEncoding.sol";

import "./interfaces/ILoremIpsum.sol";

/// @title Target Arbitrary Message Bridge
/// @notice Executes messages sent from the source chain on the destination chain.
contract TargetAMB is ReceiverStorage, SharedStorage, ReentrancyGuardUpgradeable, ILoremIpsumReceiver {
    /// @notice The minimum delay for using any information from the light client.
    uint256 public constant MIN_LIGHT_CLIENT_DELAY = 2 minutes;

    /// @notice SentMessage event signature used in `executeMessageFromLog`.
    bytes32 internal constant SENT_MESSAGE_EVENT_SIG =
    keccak256("SentMessage(uint64,bytes32,bytes)");

    /// @notice The topic index of the message root in the SourceAMB SentMessage event.
    /// @dev Because topic[0] is the hash of the event signature (`SENT_MESSAGE_EVENT_SIG` above),
    ///      the topic index of msgHash is 2.
    uint256 internal constant MSG_HASH_TOPIC_IDX = 2;

    /// @notice The index of the `messages` mapping in LoremIpsumStorage.sol.
    /// @dev We need this when calling `executeMessage` via storage proofs, as it is used in
    /// getting the slot key.
    uint256 internal constant MESSAGES_MAPPING_STORAGE_INDEX = 1;

    /// @notice Gets the length of the sourceChainIds array.
    /// @return The length of the sourceChainIds array.
    function sourceChainIdsLength() external view returns (uint256) {
        return sourceChainIds.length;
    }

    function executeMessage(bytes calldata messageBytes, address _transitionManager) external nonReentrant {

        Message memory message;
        bytes32 messageRoot;

        (message, messageRoot) = _checkPreconditions(messageBytes);
        requireNotFrozen(message.sourceChainId);

        IExecuteMessageTransitionHandler(_transitionManager).
        processExecuteMessageCrossChain(
            message.nonce,
            message.sourceChainId,
            message.sourceAddress,
            message.destinationChainId,
            Address.fromBytes32(message.destinationAddress),
            message.data
        );
        
    }

    /// @notice Checks that the chainId is not frozen.
    function requireNotFrozen(uint32 chainId) internal view {
        require(!frozen[chainId], "Contract is frozen.");
    }
    /// @notice Decodes the message from messageBytes and checks conditions before message execution
    /// @param messageBytes The message we want to execute provided as bytes.
    function _checkPreconditions(bytes calldata messageBytes)
    internal
    returns (Message memory, bytes32)
    {
        Message memory message = abi.decode(messageBytes, (Message));
        bytes32 messageRoot = keccak256(messageBytes);
        if (messageStatus[messageRoot] != MessageStatus.NOT_EXECUTED) {
            revert("Message already executed.");
        } else if (message.destinationChainId != block.chainid) {
            revert("Wrong chain.");
        } else if (message.version != version) {
            revert("Wrong version.");
        } 
        return (message, messageRoot);
    }
}
