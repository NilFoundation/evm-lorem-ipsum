pragma solidity ^0.8.16;

import "@eth-optimism/contracts-bedrock/contracts/libraries/rlp/RLPReader.sol";
import "@eth-optimism/contracts-bedrock/contracts/libraries/rlp/RLPWriter.sol";
import "@eth-optimism/contracts-bedrock/contracts/libraries/trie/MerkleTrie.sol";

import "../libraries/UintBytes.sol";

library EventProof {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    /// @notice Verifies that the given log data is valid for the given event proof.
    function parseEvent(
        bytes[] memory _receiptProof,
        bytes32 _receiptRoot,
        bytes memory _txIndexRLPEncoded,
        uint256 _logIndex,
        address _eventSource,
        bytes32 _eventSig
    ) internal pure returns (bytes32[] memory, bytes memory) {
        bytes memory value = MerkleTrie.get(_txIndexRLPEncoded, _receiptProof, _receiptRoot);
        bytes1 txTypeOrFirstByte = value[0];

        // Currently, there are three possible transaction types on Ethereum. Receipts either come
        // in the form "TransactionType | ReceiptPayload" or "ReceiptPayload". The currently
        // supported set of transaction types are 0x01 and 0x02. In this case, we must truncate
        // the first byte to access the payload. To detect the other case, we can use the fact
        // that the first byte of a RLP-encoded list will always be greater than 0xc0.
        // Reference 1: https://eips.ethereum.org/EIPS/eip-2718
        // Reference 2: https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp
        uint256 offset;
        if (txTypeOrFirstByte == 0x01 || txTypeOrFirstByte == 0x02) {
            offset = 1;
        } else if (txTypeOrFirstByte >= 0xc0) {
            offset = 0;
        } else {
            revert("Unsupported transaction type");
        }

        // Truncate the first byte if eneded and get the RLP decoding of the receipt.
        uint256 ptr;
        assembly {
            ptr := add(value, 32)
        }
        RLPReader.RLPItem memory valueAsItem = RLPReader.RLPItem({
            length: value.length - offset,
            ptr: RLPReader.MemoryPointer.wrap(ptr + offset)
        });

        // The length of the receipt must be at least four, as the fourth entry contains events
        RLPReader.RLPItem[] memory valueAsList = valueAsItem.readList();
        require(valueAsList.length == 4, "Invalid receipt length");

        // Read the logs from the receipts and check that it is not ill-formed
        RLPReader.RLPItem[] memory logs = valueAsList[3].readList();
        require(_logIndex < logs.length, "Log index out of bounds");
        RLPReader.RLPItem[] memory relevantLog = logs[_logIndex].readList();

        // Validate that the correct contract emitted the event
        (uint160 result,) = UintBytes.readUint160(relevantLog[0].readBytes(), 0);
        address sourceContract = address(result);
        require(sourceContract == _eventSource, "Event was not emitted by source contract");

        // Validate that the event signature matches
        bytes32[] memory topics = parseTopics(relevantLog[1].readList());
        require(bytes32(topics[0]) == _eventSig, "Event signature does not match");

        bytes memory data = relevantLog[2].readBytes();

        return (topics, data);
    }

    function parseTopics(RLPReader.RLPItem[] memory _topicsRLPEncoded)
    private pure returns (bytes32[] memory) {
        bytes32[] memory topics = new bytes32[](_topicsRLPEncoded.length);
        for (uint256 i = 0; i < _topicsRLPEncoded.length; i++) {
            topics[i] = bytes32(_topicsRLPEncoded[i].readBytes());
        }
        return topics;
    }

    function getEventTopic(
        bytes[] memory proof,
        bytes32 receiptRoot,
        bytes memory key,
        uint256 logIndex,
        address claimedEmitter,
        bytes32 eventSignature,
        uint256 topicIndex
    ) internal pure returns (bytes32) {
        bytes memory value = MerkleTrie.get(key, proof, receiptRoot);
        bytes1 txTypeOrFirstByte = value[0];

        // Currently, there are three possible transaction types on Ethereum. Receipts either come
        // in the form "TransactionType | ReceiptPayload" or "ReceiptPayload". The currently
        // supported set of transaction types are 0x01 and 0x02. In this case, we must truncate
        // the first byte to access the payload. To detect the other case, we can use the fact
        // that the first byte of a RLP-encoded list will always be greater than 0xc0.
        // Reference 1: https://eips.ethereum.org/EIPS/eip-2718
        // Reference 2: https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp
        uint256 offset;
        if (txTypeOrFirstByte == 0x01 || txTypeOrFirstByte == 0x02) {
            offset = 1;
        } else if (txTypeOrFirstByte >= 0xc0) {
            offset = 0;
        } else {
            revert("Unsupported transaction type");
        }

        // Truncate the first byte if eneded and get the RLP decoding of the receipt.
        uint256 ptr;
        assembly {
            ptr := add(value, 32)
        }
        RLPReader.RLPItem memory valueAsItem = RLPReader.RLPItem({
            length: value.length - offset,
            ptr: RLPReader.MemoryPointer.wrap(ptr + offset)
        });

        // The length of the receipt must be at least four, as the fourth entry contains events
        RLPReader.RLPItem[] memory valueAsList = valueAsItem.readList();
        require(valueAsList.length == 4, "Invalid receipt length");

        // Read the logs from the receipts and check that it is not ill-formed
        RLPReader.RLPItem[] memory logs = valueAsList[3].readList();
        require(logIndex < logs.length, "Log index out of bounds");
        RLPReader.RLPItem[] memory relevantLog = logs[logIndex].readList();
        require(relevantLog.length == 3, "Log has incorrect number of fields");

        // Validate that the correct contract emitted the event
        uint160 result;
        (result,) = UintBytes.readUint160(relevantLog[0].readBytes(), 0);
        address contractAddress = address(result);
        require(contractAddress == claimedEmitter, "Event was not emitted by claimedEmitter");
        RLPReader.RLPItem[] memory topics = relevantLog[1].readList();

        // Validate that the correct event was emitted by checking the event signature
        require(
            bytes32(topics[0].readBytes()) == eventSignature,
            "Event signature does not match eventSignature"
        );

        return bytes32(topics[topicIndex].readBytes());
    }
}
