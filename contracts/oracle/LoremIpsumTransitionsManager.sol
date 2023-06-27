import "../amb/interfaces/ILoremIpsum.sol";
import "./LoremIpsumOracle.sol";
import "../interfaces/IProofHandler.sol";

contract LoremIpsumTransitionsManager is IExecuteMessageTransitionHandler {

    mapping(bytes32 => address) proofVerificationHandlers;

    struct TransitionStorage {
        uint256 proofVerificationTypeId;
        bytes proof;
        bytes targetData;
    }

    LoremIpsumOracle oracle;
    ILoremIpsumSender sender;

    constructor(address _sender) {
        sender = ILoremIpsumSender(_sender);
    }

    /// @notice Must be ownable!
    function setOracle(address _oracle) public {
        oracle = LoremIpsumOracle(_oracle);
    }

    function setVerifierHandler(uint32 _sourceChainId, uint256 _proofVerificationTypeId, address _verifier) public {
        bytes32 proofHandlerId = keccak256(abi.encode(_sourceChainId, _proofVerificationTypeId));

        proofVerificationHandlers[proofHandlerId] = _verifier;
    }

    function processTransitionStorageMessage(uint32 _sourceChainId, TransitionStorage memory _transitionStorage) internal {
        
        bytes32 proofHandlerId = keccak256(abi.encode(_sourceChainId, _transitionStorage.proofVerificationTypeId));
        bool status;

        require(proofVerificationHandlers[proofHandlerId] != address(0), "processTransitionStorageMessage: Handler is not exist!");

        {
            bytes memory handlerInputData = abi.encodeWithSelector(
                IProofHandler.verifyProof.selector,
                _transitionStorage.proof,
                _transitionStorage.proof // here must be public input
            );
            (status,) = proofVerificationHandlers[proofHandlerId].call(handlerInputData);
        }

        require(status, "processTransitionStorageMessage call fail");

    }
 
    function processSendRequestCrossChain(        
        uint32 _destinationChainId,
        address _targetContract,
        bytes calldata _targetData,
        bytes memory _proof,
        uint256 _proofVerificationTypeId) public returns (bytes32) {

        TransitionStorage memory transitionStorage;
        
        transitionStorage.proof = _proof;
        transitionStorage.targetData = _targetData;
        transitionStorage.proofVerificationTypeId = _proofVerificationTypeId;

        return sender.send(_destinationChainId, _targetContract, abi.encode(transitionStorage));

    }

    function processExecuteMessageCrossChain(
        uint64 _nonce,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint32 _destinationChainId,
        address _destinationAddress,
        bytes calldata _transitionStorageRawData
    ) public {

        TransitionStorage memory transitionStorage = abi.decode(_transitionStorageRawData, (TransitionStorage));

        processTransitionStorageMessage(_sourceChainId, transitionStorage);

        oracle.handleRequest(_sourceAddress, _sourceChainId, _destinationAddress, transitionStorage.targetData);
    }

}