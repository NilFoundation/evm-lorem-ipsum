pragma solidity ^0.8.0;

interface IProofHandler {

    function verifyProof(bytes memory proofSourceBytes) external;
    
}
