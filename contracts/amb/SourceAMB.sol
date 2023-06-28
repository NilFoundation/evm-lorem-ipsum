pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../libraries/Typecast.sol";
import "../libraries/MessageEncoding.sol";
import "./interfaces/ILoremIpsum.sol";
import "./LoremIpsumAccess.sol";
import "../libraries/Typecast.sol";

/// @title Source Arbitrary Message Bridge
/// @notice This contract is the entrypoint for sending messages to other chains.
contract SourceAMB is SenderStorage, SharedStorage, ILoremIpsumSender {
    /// @notice Modifier to require that sending is enabled.
    modifier isSendingEnabled() {
        require(sendingEnabled, "Sending is disabled");
        _;
    }

    /// @notice Sends (proxy) a message to a destination chain.
    /// @param destinationChainId The chain id that specifies the destination chain.
    /// @param destinationAddress The contract address that will be called on the destination chain.
    /// @param data The data passed to the contract on the other chain
    /// @return bytes32 A unique identifier for a message.
    function send(uint32 destinationChainId, bytes32 destinationAddress, bytes calldata data)
    public isSendingEnabled returns (bytes32) {
        return _send(destinationChainId, destinationAddress, data);
    }

    /// @notice Sends (proxy) a message to a destination chain.
    /// @param destinationChainId The chain id that specifies the destination chain.
    /// @param destinationAddress The contract address that will be called on the destination chain.
    /// @param data The data passed to the contract on the other chain
    /// @return bytes32 A unique identifier for a message.
    function send(uint32 destinationChainId, address destinationAddress, bytes calldata data)
    external isSendingEnabled returns (bytes32) {
        return _send(destinationChainId, Bytes32.fromAddress(destinationAddress), data);
    }

    /// @notice Sends (implementation) a message to a destination chain.
    /// @param destinationChainId The chain id that specifies the destination chain.
    /// @param destinationAddress The contract address that will be called on the destination chain.
    /// @param data The data passed to the contract on the other chain
    /// @return bytes32 A unique identifier for a message.
    function _send(uint32 destinationChainId, bytes32 destinationAddress, bytes calldata data)
    private returns (bytes32) {
        /* 
            Current tests are working on the same chain, so it is commented for now 
        */
        //require(destinationChainId != block.chainid, "Cannot send to same chain");

        /* 
            Current message encoding is simplified but it must be done in a smarter way
            later on like it is done in _getMessageAndRoot -- now it is not actually used
        */
        (bytes memory message, bytes32 messageRoot) =
        _getMessageAndRoot(destinationChainId, destinationAddress, data);
        
        Message memory crossChainMessage = Message(version,
            nonce,
            uint32(block.chainid),
            msg.sender,
            destinationChainId,
            destinationAddress,
            data);

        emit SentMessage(abi.encode(crossChainMessage));
        return messageRoot;
    }

    /// @notice Gets the message and message root from the user-provided arguments to `send`
    /// @param destinationChainId The chain id that specifies the destination chain.
    /// @param destinationAddress The contract address that will be called on the destination chain.
    /// @param data The calldata used when calling the contract on the destination chain.
    /// @return messageBytes The message encoded as bytes, used in SentMessage event.
    /// @return messageRoot The hash of messageBytes, used as a unique identifier for a message.
    function _getMessageAndRoot(
        uint32 destinationChainId,
        bytes32 destinationAddress,
        bytes calldata data
    ) internal view returns (bytes memory messageBytes, bytes32 messageRoot) {
        messageBytes = abi.encode(
            version,
            nonce,
            uint32(block.chainid),
            msg.sender,
            destinationChainId,
            destinationAddress,
            data
        );
        messageRoot = keccak256(messageBytes);
    }
}
