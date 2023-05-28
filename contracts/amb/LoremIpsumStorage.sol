pragma solidity 0.8.16;

import "./interfaces/ILoremIpsum.sol";
import "../interfaces/IProtocolState.sol";


abstract contract SenderStorage {
    /// @notice Whether sending is enabled or not.
    bool public sendingEnabled;

    /// @notice Keeps track of the next nonce to be used.
    uint64 public nonce;

    /// @dev This empty reserved space is put in place to allow future versions to add new variables
    /// without shifting down storage in the inheritance chain.
    /// See: https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#storage-gaps
    uint256[50] private __gap;
}

abstract contract ReceiverStorage {
    /// @notice All sourceChainIds.
    uint32[] public sourceChainIds;

    /// @notice Mapping between source chainId and the corresponding light client.
    mapping(uint32 => IProtocolState) public lightClients;

    /// @notice Mapping between source chainId and the address of the Lorem Ipsum broadcaster on that chain.
    mapping(uint32 => address) public broadcasters;

    /// @notice Mapping between a source chainId and whether it's frozen.
    mapping(uint32 => bool) public frozen;

    /// @notice Mapping between a message root and its status.
    mapping(bytes32 => MessageStatus) public messageStatus;

    /// @notice Storage root cache.
    mapping(bytes32 => bytes32) public storageRootCache;

    /// @dev This empty reserved space is put in place to allow future versions to add new variables
    /// without shifting down storage in the inheritance chain.
    /// See: https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#storage-gaps
    uint256[50] private __gap;
}

abstract contract SharedStorage {
    /// @notice Returns current contract version.
    uint8 public version;

    /// @dev This empty reserved space is put in place to allow future versions to add new variables
    /// without shifting down storage in the inheritance chain.
    /// See: https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#storage-gaps
    uint256[50] private __gap;
}
