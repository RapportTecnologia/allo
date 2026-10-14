// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {AlloMultisigWallet} from "../../../contracts/governance/AlloMultisigWallet.sol";

contract AlloMultisigWalletTest is Test {
    AlloMultisigWallet public multisig;

    address public signer1 = makeAddr("signer1");
    address public signer2 = makeAddr("signer2");
    address public signer3 = makeAddr("signer3");
    address public nonSigner = makeAddr("nonSigner");
    address public timelock = makeAddr("timelock");
    address public target = makeAddr("target");

    address[] public signers;

    function setUp() public {
        signers.push(signer1);
        signers.push(signer2);
        signers.push(signer3);
        multisig = new AlloMultisigWallet(signers, 2, timelock);
    }

    function test_Constructor() public {
        assertEq(multisig.threshold(), 2);
        assertEq(multisig.getSignerCount(), 3);
        assertTrue(multisig.isSigner(signer1));
        assertTrue(multisig.isSigner(signer2));
        assertTrue(multisig.isSigner(signer3));
        assertFalse(multisig.isSigner(nonSigner));
        assertEq(address(multisig.timelock()), timelock);
    }

    function test_RevertWhen_ThresholdZero() public {
        vm.expectRevert(AlloMultisigWallet.INVALID_THRESHOLD.selector);
        new AlloMultisigWallet(signers, 0, timelock);
    }

    function test_RevertWhen_ThresholdAboveSignerCount() public {
        vm.expectRevert(AlloMultisigWallet.INVALID_THRESHOLD.selector);
        new AlloMultisigWallet(signers, 4, timelock);
    }

    function test_RevertWhen_DuplicateSigner() public {
        address[] memory badSigners = new address[](2);
        badSigners[0] = signer1;
        badSigners[1] = signer1;
        vm.expectRevert(AlloMultisigWallet.DUPLICATE_SIGNER.selector);
        new AlloMultisigWallet(badSigners, 2, timelock);
    }

    function test_SubmitTransaction() public {
        bytes memory data = abi.encodeWithSignature("foo()");
        vm.prank(signer1);
        uint256 txId = multisig.submitTransaction(target, 0, data);

        assertEq(txId, 0);
        assertEq(multisig.getConfirmationCount(txId), 1);

        (address t, uint256 v, bytes memory d, bool executed, bool cancelled,) = multisig.transactions(txId);
        assertEq(t, target);
        assertEq(v, 0);
        assertEq(d, data);
        assertFalse(executed);
        assertFalse(cancelled);
    }

    function test_RevertWhen_NonSignerSubmits() public {
        vm.prank(nonSigner);
        vm.expectRevert(AlloMultisigWallet.NOT_SIGNER.selector);
        multisig.submitTransaction(target, 0, "");
    }

    function test_ConfirmAndExecuteTransaction() public {
        bytes memory data = "";
        vm.deal(address(multisig), 1 ether);

        vm.prank(signer1);
        uint256 txId = multisig.submitTransaction(target, 0.5 ether, data);

        vm.prank(signer2);
        multisig.confirmTransaction(txId);

        assertEq(multisig.getConfirmationCount(txId), 2);

        vm.prank(signer3);
        multisig.executeTransaction(txId);

        (, , , bool executed, ,) = multisig.transactions(txId);
        assertTrue(executed);
        assertEq(target.balance, 0.5 ether);
    }

    function test_RevertWhen_ExecuteBelowThreshold() public {
        vm.prank(signer1);
        uint256 txId = multisig.submitTransaction(target, 0, "");

        vm.prank(signer2);
        multisig.confirmTransaction(txId);

        // Revoke one confirmation to drop below threshold.
        vm.prank(signer1);
        multisig.revokeConfirmation(txId);

        vm.prank(signer3);
        vm.expectRevert(AlloMultisigWallet.NOT_ENOUGH_CONFIRMATIONS.selector);
        multisig.executeTransaction(txId);
    }

    function test_RevokeConfirmation() public {
        vm.prank(signer1);
        uint256 txId = multisig.submitTransaction(target, 0, "");

        vm.prank(signer2);
        multisig.confirmTransaction(txId);

        vm.prank(signer2);
        multisig.revokeConfirmation(txId);

        assertEq(multisig.getConfirmationCount(txId), 1);
        assertFalse(multisig.confirmations(txId, signer2));
    }

    function test_CancelTransaction() public {
        vm.prank(signer1);
        uint256 txId = multisig.submitTransaction(target, 0, "");

        vm.prank(signer2);
        multisig.confirmTransaction(txId);

        vm.prank(signer3);
        multisig.cancelTransaction(txId);

        (, , , , bool cancelled,) = multisig.transactions(txId);
        assertTrue(cancelled);
    }

    function test_RevertWhen_ExecuteCancelled() public {
        vm.prank(signer1);
        uint256 txId = multisig.submitTransaction(target, 0, "");

        vm.prank(signer2);
        multisig.confirmTransaction(txId);

        vm.prank(signer3);
        multisig.cancelTransaction(txId);

        vm.prank(signer3);
        vm.expectRevert(AlloMultisigWallet.TX_CANCELLED.selector);
        multisig.executeTransaction(txId);
    }

    function test_SignerManagementThroughWallet() public {
        // Add a signer through a self-referential transaction.
        address newSigner = makeAddr("newSigner");
        bytes memory addData = abi.encodeWithSelector(AlloMultisigWallet.addSigner.selector, newSigner);

        vm.prank(signer1);
        uint256 txId = multisig.submitTransaction(address(multisig), 0, addData);

        vm.prank(signer2);
        multisig.confirmTransaction(txId);

        vm.prank(signer1);
        multisig.executeTransaction(txId);

        assertTrue(multisig.isSigner(newSigner));
        assertEq(multisig.getSignerCount(), 4);

        // Replace a signer.
        address replacement = makeAddr("replacement");
        bytes memory replaceData = abi.encodeWithSelector(
            AlloMultisigWallet.replaceSigner.selector,
            signer3,
            replacement
        );

        vm.prank(signer1);
        uint256 txId2 = multisig.submitTransaction(address(multisig), 0, replaceData);

        vm.prank(signer2);
        multisig.confirmTransaction(txId2);

        vm.prank(newSigner);
        multisig.executeTransaction(txId2);

        assertFalse(multisig.isSigner(signer3));
        assertTrue(multisig.isSigner(replacement));

        // Remove a signer.
        bytes memory removeData = abi.encodeWithSelector(AlloMultisigWallet.removeSigner.selector, replacement);

        vm.prank(signer1);
        uint256 txId3 = multisig.submitTransaction(address(multisig), 0, removeData);

        vm.prank(signer2);
        multisig.confirmTransaction(txId3);

        vm.prank(newSigner);
        multisig.executeTransaction(txId3);

        assertFalse(multisig.isSigner(replacement));
        assertEq(multisig.getSignerCount(), 3);
    }

    function test_ChangeThresholdThroughWallet() public {
        bytes memory data = abi.encodeWithSelector(AlloMultisigWallet.changeThreshold.selector, 3);

        vm.prank(signer1);
        uint256 txId = multisig.submitTransaction(address(multisig), 0, data);

        vm.prank(signer2);
        multisig.confirmTransaction(txId);

        vm.prank(signer3);
        multisig.executeTransaction(txId);

        assertEq(multisig.threshold(), 3);
    }

    receive() external payable {}
}
