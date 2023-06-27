pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/IProtocolState.sol";

import "./LoremIpsumStorage.sol";
import "./interfaces/ILoremIpsum.sol";
import "./LoremIpsumAccess.sol";
import "./TargetAMB.sol";
import "./SourceAMB.sol";

/// @notice Send and receive arbitrary messages from other chains.
contract LoremIpsumRouter is SourceAMB, TargetAMB, LoremIpsumAccess, UUPSUpgradeable {
    /// @notice Returns current contract version.
    uint8 public constant VERSION = 1;

    /// @notice Prevents the implementation contract from being initialized outside of the upgradeable proxy.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract and the parent contracts once.
    function initialize(
        uint32[] memory _sourceChainIds,
        address[] memory _lightClients,
        address[] memory _broadcasters,
        address _timelock,
        address _guardian,
        bool _sendingEnabled
    ) external initializer {
        __ReentrancyGuard_init();
        __AccessControl_init();
        _grantRole(GUARDIAN_ROLE, _guardian);
        _grantRole(TIMELOCK_ROLE, _timelock);
        _grantRole(DEFAULT_ADMIN_ROLE, _timelock);
        __UUPSUpgradeable_init();

        require(_sourceChainIds.length == _lightClients.length);
        require(_sourceChainIds.length == _broadcasters.length);

        sourceChainIds = _sourceChainIds;
        for (uint32 i = 0; i < sourceChainIds.length; i++) {
            lightClients[sourceChainIds[i]] = IProtocolState(_lightClients[i]);
            broadcasters[sourceChainIds[i]] = _broadcasters[i];
        }
        sendingEnabled = _sendingEnabled;
        version = VERSION;
    }

    /// @notice Authorizes an upgrade for the implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyTimelock {}
}
