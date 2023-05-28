pragma solidity 0.8.16;

import "../interfaces/IProtocolState.sol";

/// @notice Mock for testing TargetAMB: proivdes initializers and setters for testing.
contract MockProtocolState is IProtocolState {
    /// @notice Whether the light client has had conflicting variables for the same slot.
    bool public consistent = true;

    /// @notice The latest slot the light client has a finalized header for.
    uint256 public head = 0;

    /// @notice Maps from a slot to a beacon block header root.
    mapping(uint256 => bytes32) public headers;

    /// @notice Maps from a slot to the timestamp of when the headers mapping was updated with slot as a key
    mapping(uint256 => uint256) public timestamps;

    /// @notice Maps from a slot to the current finalized state root.
    mapping(uint256 => bytes32) public stateRoots;

    function setHead(uint256 _head) external {
        head = _head;
    }

    function addSlot(uint256 slot, bytes32 header, uint256 timestamp, bytes32 stateRoot) external {
        headers[slot] = header;
        timestamps[slot] = timestamp;
        stateRoots[slot] = stateRoot;
    }
}