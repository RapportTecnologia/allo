// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title AlloTimelockController
/// @notice Timelock controller for administrative actions on the Allo protocol.
/// @dev Enforces a minimum delay of 48 hours as required by SEC-005/SEC-009.
///      The sole proposer/executor is the AlloMultisigWallet, so every admin
///      action requires multiple signatures plus the on-chain timelock wait.
contract AlloTimelockController is TimelockController {
    /// @notice Minimum delay enforced by the protocol security rules.
    uint256 public constant MINIMUM_DELAY = 2 days;

    /// @dev TimelockController requires `minDelay`, `proposers`, `executors`
    ///      and an optional `admin` for initial configuration. The admin role
    ///      must be renounced after the multisig is registered as proposer/executor.
    /// @param minDelay Delay before a scheduled operation becomes executable.
    /// @param proposers Accounts granted the proposer and canceller roles.
    /// @param executors Accounts granted the executor role.
    /// @param admin Optional initial admin role; use deployer and renounce later.
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        TimelockController(_enforceMinimumDelay(minDelay), proposers, executors, admin)
    {}

    /// @notice Validates that the requested delay is not shorter than the protocol minimum.
    /// @param minDelay Delay provided at construction time.
    /// @return The larger value between `minDelay` and `MINIMUM_DELAY`.
    function _enforceMinimumDelay(uint256 minDelay) internal pure returns (uint256) {
        return minDelay < MINIMUM_DELAY ? MINIMUM_DELAY : minDelay;
    }
}
