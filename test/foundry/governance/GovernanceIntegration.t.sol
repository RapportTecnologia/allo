// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {Allo} from "../../../contracts/core/Allo.sol";
import {Registry} from "../../../contracts/core/Registry.sol";
import {AlloTimelockController} from "../../../contracts/governance/AlloTimelockController.sol";
import {AlloMultisigWallet} from "../../../contracts/governance/AlloMultisigWallet.sol";

contract GovernanceIntegrationTest is Test {
    Allo public allo;
    Registry public registry;
    AlloTimelockController public timelock;
    AlloMultisigWallet public multisig;

    address public initialOwner = makeAddr("initialOwner");
    address public signer1 = makeAddr("signer1");
    address public signer2 = makeAddr("signer2");
    address public treasury = makeAddr("treasury");

    address[] public signers;

    function setUp() public {
        signers.push(signer1);
        signers.push(signer2);

        vm.startPrank(initialOwner);

        registry = new Registry();
        registry.initialize(initialOwner);

        allo = new Allo();
        allo.initialize(initialOwner, address(registry), payable(treasury), 0, 0);

        timelock = new AlloTimelockController(2 days, new address[](0), new address[](0), initialOwner);
        multisig = new AlloMultisigWallet(signers, 2, address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(multisig));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(multisig));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(multisig));
        timelock.renounceRole(timelock.TIMELOCK_ADMIN_ROLE(), initialOwner);

        vm.stopPrank();
    }

    function test_TransferAlloOwnershipToTimelock() public {
        vm.prank(initialOwner);
        allo.transferOwnership(address(timelock));

        assertEq(allo.owner(), address(timelock));
    }

    function test_TransferRegistryAlloOwnerToTimelock() public {
        vm.prank(initialOwner);
        registry.transferAlloOwner(address(timelock));

        assertTrue(registry.hasRole(registry.ALLO_OWNER(), address(timelock)));
        assertFalse(registry.hasRole(registry.ALLO_OWNER(), initialOwner));
    }

    function test_TimelockCanCallAlloAdminFunction() public {
        // Transfer Allo ownership to timelock.
        vm.prank(initialOwner);
        allo.transferOwnership(address(timelock));

        // Governance proposal: update base fee to 1 ether through timelock.
        bytes memory data = abi.encodeWithSelector(Allo.updateBaseFee.selector, 1 ether);
        bytes32 salt = keccak256("update-base-fee");

        bytes memory scheduleData = abi.encodeWithSelector(
            timelock.schedule.selector,
            address(allo),
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

        // Advance through timelock delay.
        vm.warp(block.timestamp + 2 days);

        bytes memory executeData = abi.encodeWithSelector(
            timelock.execute.selector,
            address(allo),
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
        multisig.executeTransaction(txId2);

        assertEq(allo.getBaseFee(), 1 ether);
    }

    function test_TimelockCanCallRegistryAdminFunction() public {
        // Transfer Registry ALLO_OWNER to timelock.
        vm.prank(initialOwner);
        registry.transferAlloOwner(address(timelock));

        address nextOwner = makeAddr("nextOwner");

        // Governance proposal: transfer ALLO_OWNER from timelock to nextOwner.
        bytes memory data = abi.encodeWithSelector(Registry.transferAlloOwner.selector, nextOwner);
        bytes32 salt = keccak256("transfer-registry-owner");

        bytes memory scheduleData = abi.encodeWithSelector(
            timelock.schedule.selector,
            address(registry),
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

        vm.warp(block.timestamp + 2 days);

        bytes memory executeData = abi.encodeWithSelector(
            timelock.execute.selector,
            address(registry),
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
        multisig.executeTransaction(txId2);

        assertTrue(registry.hasRole(registry.ALLO_OWNER(), nextOwner));
        assertFalse(registry.hasRole(registry.ALLO_OWNER(), address(timelock)));
    }
}
