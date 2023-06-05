import "../amb/interfaces/ILoremIpsum.sol";
import "./LoremIpsumOracle.sol";

contract LoremIpsumTransitionsManager is IExecuteMessageTransitionHandler {

    struct TransitionStorage {
        uint8 proofTypeRequest;
        bytes accountProof;
        bytes stateProof;
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

    function processSendRequestCrossChain(        
        uint32 _destinationChainId,
        address _targetContract,
        bytes calldata _targetData,
        uint8 _proofTypeRequest) public returns (bytes32) {

        TransitionStorage memory transitionStorage;
        
        transitionStorage.targetData = _targetData;

        if (_proofTypeRequest & 0x1 != 0) {
            transitionStorage.accountProof = _requestAccountProof();
        }
        if (_proofTypeRequest & 0x2 != 0) {
            transitionStorage.stateProof = _requestStateProof();
        }

        transitionStorage.proofTypeRequest = _proofTypeRequest & 0x3;

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

        if (transitionStorage.proofTypeRequest & 0x1 != 0) {
            require(_verifyAccountProof(transitionStorage.accountProof), "Account proof verification fail");
        }

        if (transitionStorage.proofTypeRequest & 0x2 != 0) {
            require(_verifyStateProof(transitionStorage.stateProof), "State proof verification fail");
        }

        oracle.handleRequest(_sourceAddress, _sourceChainId, _destinationAddress, transitionStorage.targetData);
    }


    function _requestAccountProof() private returns(bytes memory) {
        return abi.encode("AccountProof");
    }
 
    function _requestStateProof() private returns(bytes memory) {
        return abi.encode("StateProof");
    }

    function _verifyAccountProof(bytes memory _accountProof) private returns(bool) {
        return (keccak256(abi.encode("AccountProof")) == keccak256(_accountProof));
    }

    function _verifyStateProof(bytes memory _stateProof) private returns(bool) {
        return (keccak256(abi.encode("StateProof")) == keccak256(_stateProof));
    }
}