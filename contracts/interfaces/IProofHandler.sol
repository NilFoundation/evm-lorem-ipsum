pragma solidity ^0.8.0;

interface IProofHandler {
    function verify(
        bytes calldata blob,
        uint256[] calldata publicInput
    ) external view;
}
