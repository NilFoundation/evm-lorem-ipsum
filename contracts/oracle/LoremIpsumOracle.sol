pragma solidity ^0.8.16;

import "../amb/interfaces/LoremIpsumHandler.sol";
import "../libraries/AccessControl.sol";
import "./LoremIpsumTransitionsManager.sol";

enum RequestStatus {
    UNSENT,
    PENDING,
    SUCCESS,
    FINISHED,
    FAILED
}

struct SendRequestData {
    uint256 nonce;
    address sourceAddress;
    uint32 destinationChainId;
    address targetContract;
    bytes targetCallData;
}

/// @notice The contract is the actual entry point for the cross chain request

contract LoremIpsumOracle is AccessControl {

    event RequestForCrossChainSubmitted(
        uint256 indexed nonce,
        address sourceAddress,
        uint32 destinationChainId,
        address targetContract,
        bytes targetData
    );

    event CrossChainRequestSubmittReady(
        bytes32 _requestHash,
        RequestStatus _newStatus
    );

    event CrossChainRequestSent(
        uint256 indexed nonce,
        bytes32 hashRoot,
        address sourceAddress,
        uint32 destinationChainId,
        address targetContract,
        bytes targetData
    );



    /// @notice Maps request hashes to their status
    /// @dev The hash of a request is keccak256(abi.encode(RequestData))
    mapping(bytes32 => RequestStatus) public requests;
    /// @notice Current chain ID
    uint32 public chainId;
    /// @notice The address of a router contract (actually proxy address)
    LoremIpsumTransitionsManager public sender;
    /// @notice The next nonce to use when sending a cross-chain request
    uint256 nonceNext;


    constructor(uint32 _ChainId, address _sender) {
        _setOwner();
        chainId = _ChainId;
        sender = LoremIpsumTransitionsManager(_sender);
    }


    function sendRequestCrossChain(
        uint32 _destinationChainId,
        address _targetContract,
        bytes calldata _targetData
    ) external returns (uint256 nonce) {

        require(_destinationChainId != chainId, "cur chain");

        unchecked {
            ++nonceNext;
        }
        nonce = nonceNext;

        SendRequestData memory sendRequestData = SendRequestData(nonce, msg.sender, _destinationChainId, _targetContract, _targetData);
        // Unique request id
        bytes32 requestHash = keccak256(abi.encode(sendRequestData));

        requests[requestHash] = RequestStatus.PENDING;

        emit RequestForCrossChainSubmitted(nonce, msg.sender, _destinationChainId, _targetContract, _targetData);
        return nonce;
    }


    function setStatus(bytes32 _requestHash, RequestStatus _newStatus) public {
        require(requests[_requestHash] == RequestStatus.PENDING, "not pending");
        requests[_requestHash] = _newStatus;
        emit CrossChainRequestSubmittReady(_requestHash, _newStatus);
    }

    function commitRequest(
        uint32 _destinationChainId,
        address _targetContract,
        bytes calldata _targetData,
        uint256 _nonce) public returns (bytes32) {

            SendRequestData memory requestData = SendRequestData(_nonce, msg.sender, _destinationChainId, _targetContract, _targetData);
            bytes32 requestHash = keccak256(abi.encode(requestData));

            require(requests[requestHash] == RequestStatus.SUCCESS, "Not success status");

            bytes32 hashRoot = sender.append(_destinationChainId, _targetContract, _targetData);

            emit CrossChainRequestSent(_nonce, hashRoot, msg.sender, _destinationChainId, _targetContract, _targetData);

            requests[requestHash] = RequestStatus.FINISHED;

            return hashRoot;
    }

}
