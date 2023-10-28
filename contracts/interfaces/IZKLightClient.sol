pragma solidity ^0.8.0;


struct LightClientUpdate {
    uint256 attestedSlot;
    uint256 finalizedSlot;
    uint256 participation;
    bytes32 finalizedHeaderRoot;
    bytes32 executionStateRoot;
    bytes proof;
    uint256[] init_params;
    int256[][] columns_rotations;
}

interface IZKLightClient {

    function step(LightClientUpdate calldata update) external;

}
