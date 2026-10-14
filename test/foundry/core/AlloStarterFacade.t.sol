// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

// Interfaces
import {
    IAccessControlUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/access/IAccessControlUpgradeable.sol";
import {IAllo} from "../../../contracts/core/interfaces/IAllo.sol";
// Core contracts
import {AlloStarterFacade} from "../../../contracts/core/AlloStarterFacade.sol";
// Internal Libraries
import {Errors} from "../../../contracts/core/libraries/Errors.sol";
import {Metadata} from "../../../contracts/core/libraries/Metadata.sol";
import {Native} from "../../../contracts/core/libraries/Native.sol";
// Test libraries
import {AlloSetup} from "../shared/AlloSetup.sol";
import {RegistrySetupFull} from "../shared/RegistrySetup.sol";
import {MockStrategy} from "../../utils/MockStrategy.sol";
import {MockERC20} from "../../utils/MockERC20.sol";

contract AlloStarterFacadeTest is Test, AlloSetup, RegistrySetupFull, Native, Errors {
    AlloStarterFacade internal facade;
    address internal strategy;
    MockERC20 internal token;

    uint256 internal mintAmount = 1_000_000 * 1e18;
    Metadata internal metadata = Metadata({protocol: 1, pointer: "campaign"});

    function setUp() public {
        __RegistrySetupFull();
        __AlloSetup(address(registry()));

        token = new MockERC20();
        token.mint(pool_admin(), mintAmount);

        strategy = address(new MockStrategy(address(allo())));

        vm.prank(allo_owner());
        allo().transferOwnership(local());
        allo().addToCloneableStrategies(strategy);

        facade = new AlloStarterFacade(address(registry()), address(allo()));
    }

    uint256 internal _nonceCounter = 10_000;

    /// @dev Step 1 of the facade flow: the user creates the profile listing the facade as member.
    function _createProfileWithFacade() internal returns (bytes32) {
        address[] memory members = new address[](1);
        members[0] = address(facade);
        vm.prank(pool_admin());
        return registry().createProfile(_nonceCounter++, "FacadeProfile", metadata, pool_admin(), members);
    }

    /// @dev A profile that does NOT list the facade as member.
    function _createProfileWithoutFacade() internal returns (bytes32) {
        address[] memory members = new address[](0);
        vm.prank(profile1_owner());
        return registry().createProfile(777, "NoFacade", metadata, profile1_owner(), members);
    }

    // ====================================
    // ===== Constructor =================
    // ====================================

    function testRevert_constructor_ZERO_ADDRESS_registry() public {
        vm.expectRevert(ZERO_ADDRESS.selector);
        new AlloStarterFacade(address(0), address(allo()));
    }

    function testRevert_constructor_ZERO_ADDRESS_allo() public {
        vm.expectRevert(ZERO_ADDRESS.selector);
        new AlloStarterFacade(address(registry()), address(0));
    }

    function testRevert_constructor_INVALID_ADDRESS_EOA() public {
        vm.expectRevert(INVALID_ADDRESS.selector);
        new AlloStarterFacade(makeAddr("eoa"), address(allo()));

        vm.expectRevert(INVALID_ADDRESS.selector);
        new AlloStarterFacade(address(registry()), makeAddr("eoa"));
    }

    // ====================================
    // ===== initializeCampaign ==========
    // ====================================

    function test_AC_FACADE_001_initializeCampaign_preservesIdentity() public {
        bytes32 profileId = _createProfileWithFacade();

        vm.prank(pool_admin());
        uint256 poolId = facade.initializeCampaign(profileId, strategy, "0x", NATIVE, 0, metadata, pool_managers());

        // The caller owns the profile, not the facade
        assertTrue(registry().isOwnerOfProfile(profileId, pool_admin()));
        assertFalse(registry().isOwnerOfProfile(profileId, address(facade)));

        // Pool is registered and linked to the profile
        IAllo.Pool memory pool = allo().getPool(poolId);
        assertEq(pool.profileId, profileId);
        assertNotEq(address(pool.strategy), address(0));

        // The caller holds the manager role; the admin role is held by the facade
        IAccessControlUpgradeable access = IAccessControlUpgradeable(address(allo()));
        bytes32 managerRole = bytes32(poolId);
        bytes32 adminRole = keccak256(abi.encodePacked(poolId, "admin"));
        assertTrue(access.hasRole(managerRole, pool_admin()));
        assertTrue(access.hasRole(adminRole, address(facade)));
        assertFalse(access.hasRole(adminRole, pool_admin()));
    }

    function test_AC_FACADE_002_initializeCampaign_erc20Funding() public {
        bytes32 profileId = _createProfileWithFacade();
        uint256 amount = 100 ether;

        vm.startPrank(pool_admin());
        token.approve(address(facade), amount);
        uint256 poolId =
            facade.initializeCampaign(profileId, strategy, "0x", address(token), amount, metadata, pool_managers());
        vm.stopPrank();

        // Total amount was pulled through the facade and the allowance was reset
        assertEq(token.balanceOf(address(facade)), 0);
        assertEq(token.allowance(address(facade), address(allo())), 0);

        // Fee (1%) went to treasury; the rest reached the pool strategy
        uint256 fee = amount / 100;
        assertEq(token.balanceOf(allo_treasury()), fee);
        IAllo.Pool memory pool = allo().getPool(poolId);
        assertEq(token.balanceOf(address(pool.strategy)), amount - fee);
    }

    function test_AC_FACADE_003_initializeCampaign_forwardsNativeValue() public {
        bytes32 profileId = _createProfileWithFacade();
        uint256 baseFee = 0.01 ether;
        allo().updateBaseFee(baseFee);
        vm.deal(pool_admin(), baseFee);

        vm.prank(pool_admin());
        facade.initializeCampaign{value: baseFee}(profileId, strategy, "0x", NATIVE, 0, metadata, pool_managers());

        // The base fee paid in ETH was forwarded through the facade to the treasury
        assertEq(allo_treasury().balance, baseFee);
        assertEq(address(facade).balance, 0);
    }

    function testRevert_initializeCampaign_UNAUTHORIZED_notProfileMember() public {
        bytes32 profileId = _createProfileWithFacade();

        vm.prank(pool_notAManager());
        vm.expectRevert(UNAUTHORIZED.selector);
        facade.initializeCampaign(profileId, strategy, "0x", NATIVE, 0, metadata, pool_managers());
    }

    function testRevert_initializeCampaign_UNAUTHORIZED_facadeNotMember() public {
        bytes32 profileId = _createProfileWithoutFacade();

        vm.prank(profile1_owner());
        vm.expectRevert(UNAUTHORIZED.selector);
        facade.initializeCampaign(profileId, strategy, "0x", NATIVE, 0, metadata, pool_managers());
    }

    function testRevert_initializeCampaign_noAllowance() public {
        bytes32 profileId = _createProfileWithFacade();

        vm.prank(pool_admin());
        vm.expectRevert();
        facade.initializeCampaign(profileId, strategy, "0x", address(token), 100 ether, metadata, pool_managers());
    }

    // ====================================
    // ===== Owner-gated admin ops =======
    // ====================================

    function test_AC_FACADE_004_addPoolManager_onlyProfileOwner() public {
        bytes32 profileId = _createProfileWithFacade();

        vm.prank(pool_admin());
        uint256 poolId = facade.initializeCampaign(profileId, strategy, "0x", NATIVE, 0, metadata, pool_managers());

        IAccessControlUpgradeable access = IAccessControlUpgradeable(address(allo()));
        address newManager = makeAddr("newManager");

        vm.prank(pool_admin());
        facade.addPoolManager(poolId, newManager);
        assertTrue(access.hasRole(bytes32(poolId), newManager));
    }

    function test_AC_FACADE_005_removePoolManager_onlyProfileOwner() public {
        bytes32 profileId = _createProfileWithFacade();

        vm.prank(pool_admin());
        uint256 poolId = facade.initializeCampaign(profileId, strategy, "0x", NATIVE, 0, metadata, pool_managers());

        IAccessControlUpgradeable access = IAccessControlUpgradeable(address(allo()));

        vm.prank(pool_admin());
        facade.removePoolManager(poolId, pool_manager1());
        assertFalse(access.hasRole(bytes32(poolId), pool_manager1()));
    }

    function testRevert_addPoolManager_notProfileOwner() public {
        bytes32 profileId = _createProfileWithFacade();

        vm.prank(pool_admin());
        uint256 poolId = facade.initializeCampaign(profileId, strategy, "0x", NATIVE, 0, metadata, pool_managers());

        vm.prank(pool_notAManager());
        vm.expectRevert(UNAUTHORIZED.selector);
        facade.addPoolManager(poolId, makeAddr("intruder"));
    }

    function testRevert_removePoolManager_notProfileOwner() public {
        bytes32 profileId = _createProfileWithFacade();

        vm.prank(pool_admin());
        uint256 poolId = facade.initializeCampaign(profileId, strategy, "0x", NATIVE, 0, metadata, pool_managers());

        vm.prank(pool_notAManager());
        vm.expectRevert(UNAUTHORIZED.selector);
        facade.removePoolManager(poolId, pool_manager1());
    }

    // ====================================
    // ===== fundPool convenience ========
    // ====================================

    function test_AC_FACADE_006_fundPool_erc20() public {
        bytes32 profileId = _createProfileWithFacade();

        vm.startPrank(pool_admin());
        token.approve(address(facade), mintAmount);
        uint256 poolId =
            facade.initializeCampaign(profileId, strategy, "0x", address(token), 0, metadata, pool_managers());

        facade.fundPool(poolId, 50 ether);
        vm.stopPrank();

        IAllo.Pool memory pool = allo().getPool(poolId);
        uint256 fee = 50 ether / 100;
        assertEq(token.balanceOf(address(pool.strategy)), 50 ether - fee);
        assertEq(token.allowance(address(facade), address(allo())), 0);
    }
}
