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
    event SentMessage(uint64 indexed nonce, bytes32 indexed msgHash, bytes message);

    function send(uint32 destinationChainId, bytes32 destinationAddress, bytes calldata data)
    external
    returns (bytes32);

    function send(uint32 destinationChainId, address destinationAddress, bytes calldata data)
    external
    returns (bytes32);
}

interface ILoremIpsumReceiver {
    event ExecutedMessage(
        uint32 indexed sourceChainId,
        uint64 indexed nonce,
        bytes32 indexed msgHash,
        bytes message,
        bool status
    );

    function executeMessage(uint64 slot,
        bytes calldata message,
        bytes[] calldata accountProof,
        bytes[] calldata storageProof) external;

}

interface ILoremIpsumHandler {
    function handleMessage(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
    external
    returns (bytes4);
}
