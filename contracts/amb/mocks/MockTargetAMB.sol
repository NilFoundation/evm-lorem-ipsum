pragma solidity 0.8.16;

import "../TargetAMB.sol";

/// @notice Mock for testing TargetAMB: proivdes initializers and setters for testing.
contract MockTargetAMB is TargetAMB {
    /// @notice Returns current contract version.
    uint8 public constant VERSION = 1;


    constructor(uint32[] memory _sourceChainIds,
        address[] memory _lightClients,
        address[] memory _broadcasters) initializer {
        __ReentrancyGuard_init();
        
        require(_sourceChainIds.length == _lightClients.length);
        require(_sourceChainIds.length == _broadcasters.length);

        sourceChainIds = _sourceChainIds;
        for (uint32 i = 0; i < sourceChainIds.length; i++) {
            lightClients[sourceChainIds[i]] = IProtocolState(_lightClients[i]);
            broadcasters[sourceChainIds[i]] = _broadcasters[i];
        }

        version = VERSION;
    }
}