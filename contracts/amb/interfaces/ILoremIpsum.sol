pragma solidity ^0.8.0;

enum MessageStatus {
    NOT_EXECUTED,
    EXECUTION_FAILED,
    EXECUTION_SUCCEEDED
}

struct Message {
    uint8 version;
    uint64 nonce;
    uint32 sourceChainId;
    address sourceAddress;
    uint32 destinationChainId;
    bytes32 destinationAddress;
    bytes data;
}

interface ILoremIpsumSender {
    event SentMessage(bytes message);

    function send(uint32 destinationChainId, bytes32 destinationAddress, bytes calldata data)
    external
    returns (bytes32);

    function send(uint32 destinationChainId, address destinationAddress, bytes calldata data)
    external
    returns (bytes32);
}

interface IExecuteMessageTransitionHandler {
    function processExecuteMessageCrossChain(
        uint64 _nonce,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint32 _destinationChainId,
        address _destinationAddress,
        bytes calldata _transitionStorageRawData
    ) external;
}

interface ILoremIpsumReceiver {
    event ExecutedMessage(
        uint32 indexed sourceChainId,
        uint64 indexed nonce,
        bytes32 indexed msgHash,
        bytes message,
        bool status
    );

    function executeMessage(bytes calldata messageBytes, address _transitionManager) external;
}

interface ILoremIpsumResonseHandler {
    function handleResponseMessage(uint32 _sourceChainId, address _sourceAddress, bytes calldata _data)
    external
    returns (bytes4);
}

interface ILoremIpsumRequestHandler {
    function handleRequestMessage(uint32 _sourceChainId, address _sourceAddress, bytes calldata _data)
    external
    returns (bytes4);
}