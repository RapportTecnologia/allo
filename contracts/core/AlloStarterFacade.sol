// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {
    IAccessControlUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/access/IAccessControlUpgradeable.sol";

// Importing the necessary interfaces and structs from the Allo Protocol
import "./interfaces/IRegistry.sol";
import "./interfaces/IAllo.sol";
import "./libraries/Errors.sol";
import "./libraries/Metadata.sol";
import "./libraries/Native.sol";

/// @title Allo Starter Facade
/// @notice Facade that creates and funds an Allo pool for an existing Registry profile.
/// @dev Identity-preserving design (SEC-002 fix):
///      'Registry.createProfile' only accepts members when 'msg.sender == _owner', so the
///      profile must be created by the end user beforehand:
///        1. The user calls 'Registry.createProfile(nonce, name, metadata, user, [facade, ...])'
///           listing this contract as a member.
///        2. The user calls 'initializeCampaign', which creates and optionally funds the pool.
///      Resulting privileges:
///      - The user remains the profile owner and receives the pool manager role.
///      - The pool admin role stays on this immutable, non-upgradeable contract. It can only be
///        exercised through the owner-gated functions ('addPoolManager', 'removePoolManager'),
///        which require 'msg.sender' to own the profile that owns the pool.
///      - ETH is forwarded 1:1 via 'msg.value'; ERC-20 funding pulls exactly '_amount' from the
///        caller and resets the Allo allowance after each operation.
///      - The profile owner may remove this contract from the profile members at any time via
///        'Registry.removeMembers'; this only blocks future pool creation, since the admin
///        functions remain bound to profile ownership.
contract AlloStarterFacade is Errors, Native, ReentrancyGuard {
    IRegistry public immutable registry;
    IAllo public immutable allo;

    /// @notice Emitted when a pool is created through this facade
    event CampaignInitialized(bytes32 indexed profileId, uint256 indexed poolId, address indexed owner);

    constructor(address _registry, address _allo) {
        if (_registry == address(0) || _allo == address(0)) revert ZERO_ADDRESS();
        if (_registry.code.length == 0 || _allo.code.length == 0) revert INVALID_ADDRESS();
        registry = IRegistry(_registry);
        allo = IAllo(_allo);
    }

    /// @notice Creates a pool for a profile that already lists this contract as a member.
    /// @param _profileId The ID of the caller's profile (must include the facade as member)
    /// @param _strategy The strategy (cloneable or custom-approved) for the pool
    /// @param _initStrategyData Strategy-specific initialization data
    /// @param _token The pool token ('NATIVE' for ETH)
    /// @param _amount The initial amount to fund the pool with
    /// @param _metadata The pool metadata
    /// @param _managers The pool managers granted 'POOL_MANAGER_ROLE'
    /// @return poolId The created pool ID
    function initializeCampaign(
        bytes32 _profileId,
        address _strategy,
        bytes memory _initStrategyData,
        address _token,
        uint256 _amount,
        Metadata memory _metadata,
        address[] memory _managers
    ) external payable nonReentrant returns (uint256 poolId) {
        if (!registry.isOwnerOrMemberOfProfile(_profileId, msg.sender)) {
            revert UNAUTHORIZED();
        }
        if (!registry.isMemberOfProfile(_profileId, address(this))) revert UNAUTHORIZED();

        _pullFunding(_token, _amount);

        poolId = allo.createPool{value: msg.value}(
            _profileId, _strategy, _initStrategyData, _token, _amount, _metadata, _managers
        );

        _resetAllowance(_token, _amount);

        // The caller receives the manager role; the admin role remains on this contract and is
        // only reachable through the profile-owner-gated functions below.
        IAccessControlUpgradeable(address(allo)).grantRole(bytes32(poolId), msg.sender);

        emit CampaignInitialized(_profileId, poolId, msg.sender);
    }

    /// @notice Adds a pool manager. Only callable by the owner of the profile that owns the pool.
    function addPoolManager(uint256 _poolId, address _manager) external {
        _requireProfileOwner(_poolId);
        allo.addPoolManager(_poolId, _manager);
    }

    /// @notice Removes a pool manager. Only callable by the owner of the profile that owns the pool.
    function removePoolManager(uint256 _poolId, address _manager) external {
        _requireProfileOwner(_poolId);
        allo.removePoolManager(_poolId, _manager);
    }

    /// @notice Funds a pool through this facade, forwarding ETH or pulling ERC-20 from the caller.
    /// @dev Funding is permissionless in Allo; this is a convenience wrapper that keeps the
    ///      approval flow identical to 'initializeCampaign'.
    function fundPool(uint256 _poolId, uint256 _amount) external payable nonReentrant {
        IAllo.Pool memory pool = allo.getPool(_poolId);

        _pullFunding(pool.token, _amount);

        allo.fundPool{value: msg.value}(_poolId, _amount);

        _resetAllowance(pool.token, _amount);
    }

    /// @dev Pulls '_amount' of an ERC-20 token from the caller and grants Allo the exact allowance.
    ///      Allo pulls 'feeAmount + amountAfterFee = _amount' from 'msg.sender' (this contract).
    function _pullFunding(address _token, uint256 _amount) internal {
        if (_token == NATIVE || _amount == 0) return;
        SafeTransferLib.safeTransferFrom(_token, msg.sender, address(this), _amount);
        SafeTransferLib.safeApprove(_token, address(allo), _amount);
    }

    /// @dev Resets the Allo allowance for ERC-20 tokens after the operation completes.
    function _resetAllowance(address _token, uint256 _amount) internal {
        if (_token == NATIVE || _amount == 0) return;
        SafeTransferLib.safeApprove(_token, address(allo), 0);
    }

    /// @dev Reverts unless 'msg.sender' owns the profile that owns the pool.
    function _requireProfileOwner(uint256 _poolId) internal view {
        if (!registry.isOwnerOfProfile(allo.getPool(_poolId).profileId, msg.sender)) revert UNAUTHORIZED();
    }
}
