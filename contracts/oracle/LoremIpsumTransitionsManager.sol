import "../amb/interfaces/ILoremIpsum.sol";


contract LoremIpsumTransitionsManager {

    struct TransitionStorage {
        bytes accountProof;
        bytes stateProof;
        bytes targetData;
    }

    ILoremIpsumSender sender;

    constructor(address _sender) {
        sender = ILoremIpsumSender(_sender);
    }

    function append(        
        uint32 destinationChainId,
        address targetContract,
        bytes memory targetData) public returns (bytes32) {

        TransitionStorage memory transitionStorage;

        transitionStorage.targetData = targetData;
        transitionStorage.stateProof = _requestStateProof();
        transitionStorage.accountProof = _requestAccountProof();

        return sender.send(destinationChainId, targetContract, abi.encode(targetData));

    }


    function _requestAccountProof() private returns(bytes memory) {
        return abi.encode("32");
    }
 
    function _requestStateProof() private returns(bytes memory) {
        return abi.encode("32");
    }
}