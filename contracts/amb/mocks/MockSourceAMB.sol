pragma solidity 0.8.16;

import "../SourceAMB.sol";

/// @notice Mock for testing SourceAMB: proivdes initializers and setters for testing.
contract MockSourceAMB is SourceAMB {
    /// @notice Returns current contract version.
    uint8 public constant VERSION = 1;


    constructor(bool _sendingEnabled) {
        sendingEnabled = _sendingEnabled;
        version = VERSION;
        nonce = 0;
    }
}