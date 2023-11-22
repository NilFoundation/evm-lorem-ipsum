pragma solidity ^0.8.0;
import "../interfaces/IProofHandler.sol";
import "../ethereum/EthereumLightClient.sol";


import '@nilfoundation/evm-placeholder-verification/contracts/verifier.sol';
import '@nilfoundation/evm-placeholder-verification/contracts/test/unified_addition/unified_addition_gen.sol';


contract MockEthereumLightClientHandler is IProofHandler {
    
    function verify(bytes calldata proofSourceBytes, uint256[] calldata publicInput) public pure {
        require(keccak256(proofSourceBytes) == keccak256("someStrongZKProof"), "Proof verification fail!");
    }

}