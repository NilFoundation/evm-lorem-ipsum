pragma solidity ^0.8.0;
import "../interfaces/IProofHandler.sol";
import "../ethereum/EthereumLightClient.sol";



contract MockEthereumLightClientHandler is IProofHandler {
    
    // last hash block 
    // 2-more
    function verifyProof(bytes memory proofSourceBytes) public {
        require(keccak256(proofSourceBytes) == keccak256("someStrongZKProof"), "Proof verification fail!");
    }

}