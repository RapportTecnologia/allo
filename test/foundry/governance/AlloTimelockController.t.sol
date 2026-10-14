// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {AlloTimelockController} from "../../../contracts/governance/AlloTimelockController.sol";
import {AlloMultisigWallet} from "../../../contracts/governance/AlloMultisigWallet.sol";

contract AlloTimelockControllerTest is Test {
    AlloTimelockController public timelock;
    AlloMultisigWallet public multisig;

    address public signer1 = makeAddr("signer1");
    address public signer2 = makeAddr("signer2");
    address public target = makeAddr("target");

    address[] public signers;

    function setUp() public {
        signers.push(signer1);
        signers.push(signer2);

        // Deploy timelock with deployer as admin, then multisig, then wire roles.
        timelock = new AlloTimelockController(2 days, new address[](0), new address[](0), address(this));
        multisig = new AlloMultisigWallet(signers, 2, address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(multisig));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(multisig));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(multisig));
        timelock.renounceRole(timelock.TIMELOCK_ADMIN_ROLE(), address(this));
    }

    function test_MinimumDelayIs48Hours() public {
        assertEq(timelock.MINIMUM_DELAY(), 2 days);
    }

    function test_DelayBelowMinimumIsClamped() public {
        // Constructor with 1 day should be clamped to 2 days.
        AlloTimelockController shortTimelock =
            new AlloTimelockController(1 days, new address[](0), new address[](0), address(this));
        assertEq(shortTimelock.getMinDelay(), 2 days);
    }

    function test_MultisigCanScheduleAndExecute() public {
        bytes memory data = abi.encodeWithSignature("foo()");
        bytes32 salt = keccak256("test");
        bytes32 predecessor = bytes32(0);

        // Step 1: multisig schedules the operation.
        bytes memory scheduleData = abi.encodeWithSelector(
            timelock.schedule.selector,
            target,
            0,
            data,
            predecessor,
            salt,
            2 days
        );

        vm.prank(signer1);
        uint256 txId = multisig.submitTransaction(address(timelock), 0, scheduleData);

        vm.prank(signer2);
        multisig.confirmTransaction(txId);

        vm.prank(signer1);
        multisig.executeTransaction(txId);

        bytes32 operationId = timelock.hashOperation(target, 0, data, predecessor, salt);
        assertTrue(timelock.isOperationPending(operationId));
        assertFalse(timelock.isOperationReady(operationId));

        // Step 2: advance time and execute through the multisig.
        vm.warp(block.timestamp + 2 days);

        bytes memory executeData = abi.encodeWithSelector(
            timelock.execute.selector,
            target,
            0,
            data,
            predecessor,
            salt
        );

        vm.prank(signer1);
        uint256 txId2 = multisig.submitTransaction(address(timelock), 0, executeData);

        vm.prank(signer2);
        multisig.confirmTransaction(txId2);

        vm.prank(signer1);
        multisig.executeTransaction(txId2);

        assertTrue(timelock.isOperationDone(operationId));
    }

    function test_RevertWhen_ExecuteBeforeDelay() public {
        bytes memory data = abi.encodeWithSignature("foo()");
        bytes32 salt = keccak256("too-early");

        bytes memory scheduleData = abi.encodeWithSelector(
            timelock.schedule.selector,
            target,
            0,
            data,
            bytes32(0),
            salt,
            2 days
        );

        vm.prank(signer1);
        uint256 txId = multisig.submitTransaction(address(timelock), 0, scheduleData);

        vm.prank(signer2);
        multisig.confirmTransaction(txId);

        vm.prank(signer1);
        multisig.executeTransaction(txId);

        bytes memory executeData = abi.encodeWithSelector(
            timelock.execute.selector,
            target,
            0,
            data,
            bytes32(0),
            salt
        );

        vm.prank(signer1);
        uint256 txId2 = multisig.submitTransaction(address(timelock), 0, executeData);

        vm.prank(signer2);
        multisig.confirmTransaction(txId2);

        vm.prank(signer1);
        vm.expectRevert();
        multisig.executeTransaction(txId2);
    }

    function test_NonProposerCannotSchedule() public {
        address stranger = makeAddr("stranger");
        vm.prank(stranger);
        vm.expectRevert();
        timelock.schedule(target, 0, "", bytes32(0), bytes32(0), 2 days);
    }

    function test_CancelScheduledOperation() public {
        bytes memory data = abi.encodeWithSignature("foo()");
        bytes32 salt = keccak256("cancel");

        bytes memory scheduleData = abi.encodeWithSelector(
            timelock.schedule.selector,
            target,
            0,
            data,
            bytes32(0),
            salt,
            2 days
        );

        vm.prank(signer1);
        uint256 txId = multisig.submitTransaction(address(timelock), 0, scheduleData);

        vm.prank(signer2);
        multisig.confirmTransaction(txId);

        vm.prank(signer1);
        multisig.executeTransaction(txId);

        bytes32 operationId = timelock.hashOperation(target, 0, data, bytes32(0), salt);
        assertTrue(timelock.isOperationPending(operationId));

        bytes memory cancelData = abi.encodeWithSelector(timelock.cancel.selector, operationId);

        vm.prank(signer1);
        uint256 txId2 = multisig.submitTransaction(address(timelock), 0, cancelData);

        vm.prank(signer2);
        multisig.confirmTransaction(txId2);

        vm.prank(signer1);
        multisig.executeTransaction(txId2);

        assertFalse(timelock.isOperationPending(operationId));
    }
}
