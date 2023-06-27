pragma solidity ^0.8.0;

interface IProofHandler {

    function verifyProof(bytes calldata proofSourceBytes, bytes calldata publicInput) external;
    
}
