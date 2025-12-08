// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {CCIPSenderReceiverMessaging} from "../contracts/ccip/CCIPSenderReceiverMessaging.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CCIPSenderReceiverMessagingTest is Test {
    CCIPSenderReceiverMessaging private ccipMessagingImpl;
    CCIPSenderReceiverMessaging private ccipMessaging;
    ERC1967Proxy private ccipMessagingProxy;

    address defaultAdmin = address(11);
    address pauser = address(12);
    address unpauser = address(13);
    address upgrader = address(14);
    address router = address(15);
    address linkToken = address(16);
    address wrappedNativeToken = address(17);

    address alice = address(101);
    address bob = address(102);

    function setUp() public {
        ccipMessagingImpl = new CCIPSenderReceiverMessaging();
        ccipMessagingProxy = new ERC1967Proxy(
            address(ccipMessagingImpl),
            abi.encodeWithSelector(
                CCIPSenderReceiverMessaging.initialize.selector,
                defaultAdmin,
                pauser,
                unpauser,
                upgrader,
                router,
                linkToken,
                wrappedNativeToken
            )
        );
        ccipMessaging = CCIPSenderReceiverMessaging(
            address(ccipMessagingProxy)
        );

        // Label addresses for more readable traces
        vm.label(defaultAdmin, "DefaultAdmin");
        vm.label(pauser, "Pauser");
        vm.label(unpauser, "Unpauser");
        vm.label(router, "Router");
        vm.label(linkToken, "LinkToken");
        vm.label(wrappedNativeToken, "WrappedNativeToken");
        vm.label(upgrader, "Upgrader");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
    }

    function test_initializationAndRoles() public view {
        // Check roles
        assertTrue(
            ccipMessaging.hasRole(
                ccipMessaging.DEFAULT_ADMIN_ROLE(),
                defaultAdmin
            )
        );
        assertTrue(ccipMessaging.hasRole(ccipMessaging.PAUSER_ROLE(), pauser));
        assertTrue(
            ccipMessaging.hasRole(ccipMessaging.UNPAUSER_ROLE(), unpauser)
        );
        assertTrue(
            ccipMessaging.hasRole(ccipMessaging.UPGRADER_ROLE(), upgrader)
        );
    }

    function test_pauseAndUnpause() public {
        vm.startPrank(pauser);
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Paused(pauser);
        ccipMessaging.pause();
        assertTrue(ccipMessaging.paused());
        vm.stopPrank();

        vm.startPrank(unpauser);
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Unpaused(unpauser);
        ccipMessaging.unpause();
        assertFalse(ccipMessaging.paused());
        vm.stopPrank();
    }
}
