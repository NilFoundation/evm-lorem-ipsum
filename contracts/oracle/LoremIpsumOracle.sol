pragma solidity ^0.8.16;

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

struct ResponseHandler {
    address handler;
    address owner;
}

/// @notice The contract is the actual entry point for the cross-chain request
/// Oracle can be used as the default response handler if another one is not set
contract LoremIpsumOracle is AccessControl, ILoremIpsumResonseHandler {

    /// @notice Even notifies that the request submitted for verification
    event RequestForCrossChainSubmitted(
        uint256 indexed nonce,
        address sourceAddress,
        uint32 destinationChainId,
        address targetContract,
        bytes targetData
    );

    /// @notice Even notifies that the request decision is made. The result is _newStatus
    event CrossChainRequestSubmittReady(
        bytes32 _requestHash,
        RequestStatus _newStatus
    );

    /// @notice Even notifies that the request is committed to the Transition Manager
    event CrossChainRequestSent(
        uint256 indexed nonce,
        bytes32 hashRoot,
        address sourceAddress,
        uint32 destinationChainId,
        address targetContract,
        bytes targetData
    );

    /// @notice Even notifies that the cross-chain data sent to higher level handler
    event HandlerSetDone(
        uint256 indexed nonce,
        bytes32 hashRoot,
        address sourceAddress,
        uint32 destinationChainId,
        address targetContract,
        bytes targetData
    );

    /// @notice Even notifies that the cross-chain data sent to higher level handler
    event ResponseHandledByDefault(
        uint32 sourceId,
        address indexed sourceAddress,
        bytes responseData
    );


    /// @notice Maps request hashes to their status
    /// @dev The hash of a request is keccak256(abi.encode(RequestData))
    mapping(bytes32 => RequestStatus) public requests;
    /// @notice Maps chainId||targetContract to the handler that is responsible for the response processing
    mapping(bytes32 => ResponseHandler) public handlers;
    /// @notice Current chain ID
    uint32 public chainId;
    /// @notice The address of a LoremIpsumTransitionsManager contract
    LoremIpsumTransitionsManager public transitionManager;
    /// @notice The next nonce to use when sending a cross-chain request
    uint256 nonceNext;


    constructor(uint32 _ChainId, address _transitionManager) {
        _setOwner();
        chainId = _ChainId;
        transitionManager = LoremIpsumTransitionsManager(_transitionManager);
    }

    /// @notice Before sending each request should be verified by an oracle. This function emits an event with proper nonce and puts a request to the request list. 
    function sendRequestCrossChain(
        uint32 _destinationChainId,
        address _targetContract,
        bytes calldata _targetData
    ) external returns (uint256 nonce) {

        require(_destinationChainId != chainId, "Can not send to the same chain!");

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

    /// @notice Function is ownable -- only the owner (aka Oracle) can change the status of the transaction after the verification
    function setStatus(bytes32 _requestHash, RequestStatus _newStatus) public Ownable {

        require(requests[_requestHash] == RequestStatus.PENDING, "Request is not pending!");
        requests[_requestHash] = _newStatus;

        emit CrossChainRequestSubmittReady(_requestHash, _newStatus);
    }

    /// @notice The function is responsible for the actual cross-chain send request. It is recommended to send cross-chain request first
    function commitRequest(
        uint32 _destinationChainId,
        address _targetContract,
        bytes calldata _targetData,
        uint256 _nonce,
        bytes memory _proof,
        uint256 _proofVerificationTypeId
        ) external returns (bytes32) {

            //require(_destinationChainId != chainId, "Can not send to the same chain!");

            if (_nonce == 0) {
                unchecked {
                    ++nonceNext;
                }
                _nonce = nonceNext;
            }
            SendRequestData memory requestData = SendRequestData(_nonce, msg.sender, _destinationChainId, _targetContract, _targetData);
            bytes32 requestHash = keccak256(abi.encode(requestData));
            bytes32 hashRoot = transitionManager.processSendRequestCrossChain(
                    _destinationChainId, _targetContract, _targetData, _proof, _proofVerificationTypeId);

            emit CrossChainRequestSent(_nonce, hashRoot, msg.sender, _destinationChainId, _targetContract, _targetData);
            requests[requestHash] = RequestStatus.FINISHED;

            return hashRoot;
    }

    /// @notice A default response handler is used when a user didn't set the custom one
    function handleResponseMessage(
        uint32 _sourceChainId, 
        address _sourceAddress, 
        bytes calldata _response_data) public returns (bytes4) {
                
        emit ResponseHandledByDefault(_sourceChainId, _sourceAddress, _response_data);

        return ILoremIpsumResonseHandler.handleResponseMessage.selector;
    }

    /// @notice Only the owner of the handler can change it. A handler must be ownable!
    function setCustomResponseHandler( 
        uint32 _sourceChainId,
        address _targetContract,
        address _handler) external {

        bytes32 hash = keccak256(abi.encode(_sourceChainId, _targetContract));
        require(handlers[hash].owner == msg.sender || handlers[hash].owner == address(0), "Not owner!");

        handlers[hash] = ResponseHandler(_handler, msg.sender);
    }

    function handleRequest(
        address _sourceAddress,
        uint32 _sourceChainId,
        address _targetContract,
        bytes calldata _targetData 
        ) public {
        
        bool status;
        bytes32 handlerId = keccak256(abi.encode( _sourceChainId, _targetContract));
        bytes memory response;

        {
            bytes memory handlerInputData = abi.encodeWithSelector(
                ILoremIpsumRequestHandler.handleRequestMessage.selector,
                _sourceChainId,
                _sourceAddress,
                _targetData
            );

            (status, response) = _targetContract.call(handlerInputData);
        }

        require(status, "Request handling is not a success!");

        /// @notice If handler is not set by user -- default one will be used
        if (handlers[handlerId].handler == address(0)) {
            handlers[handlerId].handler = address(this);
        }

        {
            bytes memory handlerInputData = abi.encodeWithSelector(
                ILoremIpsumResonseHandler.handleResponseMessage.selector,
                _sourceChainId,
                _sourceAddress,
                response
            );

            (status,) = handlers[handlerId].handler.call(handlerInputData);
        }

        require(status, "Response handling is not a success!");

    }

}
