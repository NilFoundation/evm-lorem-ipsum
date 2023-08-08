pragma solidity ^0.8.0;
import "../interfaces/IProofHandler.sol";
import "../ethereum/EthereumLightClient.sol";



contract MockEthereumLightClientHandler is IProofHandler {
    
    function verify(bytes calldata proofSourceBytes, uint256[] calldata publicInput) public pure {
        require(keccak256(proofSourceBytes) == keccak256("someStrongZKProof"), "Proof verification fail!");
    }

}