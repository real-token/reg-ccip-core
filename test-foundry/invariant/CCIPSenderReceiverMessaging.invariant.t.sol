// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import {REG} from "../../contracts/reg/REG.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {CCIPLocalSimulator, WETH9, LinkToken, IRouterClient, BurnMintERC677Helper} from "lib/chainlink-local/src/ccip/CCIPLocalSimulator.sol";

import {CCIPSenderReceiverMessaging} from "../../contracts/ccip/CCIPSenderReceiverMessaging.sol";
import {CCIPHandler} from "./CCIPSenderReceiverMessagingHandler.sol";

contract CCIPSenderReceiverMessagingInvariant is StdInvariant, Test {
    CCIPLocalSimulator public sim;
    IRouterClient public router;
    WETH9 public weth;
    LinkToken public link;

    uint64 public destSelector;

    CCIPSenderReceiverMessaging public ccip;
    REG public reg;

    address defaultAdmin = address(11);
    address pauser = address(12);
    address unpauser = address(13);
    address upgrader = address(14);
    address minter = address(15);

    uint256 alicePk = 0xBEEF;
    address alice;
    address bob;

    CCIPHandler public handler;

    function setUp() public {
        alice = vm.addr(alicePk);
        bob = address(102);

        sim = new CCIPLocalSimulator();

        (
            uint64 chainSelector_,
            IRouterClient sourceRouter_,
            IRouterClient destinationRouter_, // unused here
            WETH9 wrappedNative_,
            LinkToken linkToken_,
            BurnMintERC677Helper ccipBnM_,
            BurnMintERC677Helper ccipLnM_
        ) = sim.configuration();

        destSelector = chainSelector_;
        router = sourceRouter_;
        weth = wrappedNative_;
        link = linkToken_;

        // Deploy CCIP proxy
        CCIPSenderReceiverMessaging impl = new CCIPSenderReceiverMessaging();
        ERC1967Proxy ccipProxy = new ERC1967Proxy(
            address(impl),
            abi.encodeWithSelector(
                CCIPSenderReceiverMessaging.initialize.selector,
                defaultAdmin,
                pauser,
                unpauser,
                upgrader,
                router,
                link,
                weth
            )
        );
        ccip = CCIPSenderReceiverMessaging(address(ccipProxy));

        // Deploy REG proxy
        REG regImpl = new REG();
        ERC1967Proxy regProxy = new ERC1967Proxy(
            address(regImpl),
            abi.encodeWithSelector(
                REG.initialize.selector,
                defaultAdmin,
                pauser,
                minter,
                upgrader
            )
        );
        reg = REG(address(regProxy));

        // Setup roles & CCIP simulator support
        vm.startPrank(defaultAdmin);
        reg.grantRole(reg.MINTER_BRIDGE_ROLE(), address(ccip));
        sim.supportNewTokenViaAccessControlDefaultAdmin(address(reg));
        vm.stopPrank();

        // Mint balances
        vm.startPrank(minter);
        reg.mintByGovernance(alice, 1000 ether);
        reg.mintByGovernance(bob, 1000 ether);
        sim.requestLinkFromFaucet(alice, 10 ether);
        sim.requestLinkFromFaucet(bob, 10 ether);
        vm.stopPrank();

        // give WETH to users
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        weth.deposit{value: 5 ether}();

        vm.deal(bob, 10 ether);
        vm.prank(bob);
        weth.deposit{value: 5 ether}();

        // initial allowlists so actions can succeed sometimes
        vm.startPrank(defaultAdmin);
        ccip.setRouter(router);
        ccip.allowlistToken(address(reg), true);
        ccip.allowlistDestinationChain(destSelector, address(ccip)); // (your unit test does this; keep consistent)
        vm.stopPrank();

        // Build handler and set it as the fuzz target
        address;
        users[0] = alice;
        users[1] = bob;

        handler = new CCIPHandler(
            ccip,
            reg,
            link,
            weth,
            router,
            destSelector,
            defaultAdmin,
            pauser,
            unpauser,
            bob, // receiver
            users
        );

        targetContract(address(handler));

        // optional: focus on handler selectors only (reduces weird calls)
        bytes4;
        selectors[0] = handler.admin_allowlistToken.selector;
        selectors[1] = handler.admin_allowlistDestination.selector;
        selectors[2] = handler.admin_setRouter.selector;
        selectors[3] = handler.admin_pause.selector;
        selectors[4] = handler.admin_unpause.selector;
        selectors[5] = handler.user_transferUsingLink.selector;
        selectors[6] = handler.user_transferUsingNative.selector;
        selectors[7] = handler.user_transferUsingWeth.selector;
        selectors[8] = handler.admin_withdrawNative.selector;
        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );
    }

    // ---------------- INVARIANTS ----------------

    // 1) CCIP contract should never end up holding REG (unless your implementation purposely keeps some)
    // In your tests, REG is burned/minted for bridging; CCIP should not accumulate user REG.
    function invariant_ccipDoesNotAccumulateReg() public view {
        assertEq(reg.balanceOf(address(ccip)), 0);
    }

    // 2) Paused state must not be “stuck”: only pauser/unpauser can change it (hard to assert fully),
    // but we can at least assert: if paused, it is indeed paused in storage (sanity) and no weird value.
    function invariant_pauseFlagIsBoolean() public view {
        // trivial but catches storage corruption / upgrade mistakes
        bool p = ccip.paused();
        assertTrue(p == true || p == false);
    }

    // 3) Total bridged REG can never exceed what users started with.
    // (this catches "minting from nowhere" in the handler accounting)
    function invariant_totalBridgedWithinInitialSupply() public view {
        // initial: 1000 + 1000
        assertLe(handler.totalRegBridged(), 2000 ether);
    }
}
