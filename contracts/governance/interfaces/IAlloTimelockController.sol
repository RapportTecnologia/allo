// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// @title IAlloTimelockController
/// @notice Minimal interface for the Allo timelock controller used by the multisig wallet.
interface IAlloTimelockController {
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32);

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;

    function cancel(bytes32 id) external;

    function getMinDelay() external view returns (uint256);

    function isOperationPending(bytes32 id) external view returns (bool);

    function isOperationReady(bytes32 id) external view returns (bool);

    function isOperationDone(bytes32 id) external view returns (bool);
}
