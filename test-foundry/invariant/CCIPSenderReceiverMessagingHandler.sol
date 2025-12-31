// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import {REG} from "../../contracts/reg/REG.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {CCIPSenderReceiverMessaging} from "../../contracts/ccip/CCIPSenderReceiverMessaging.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {WETH9, LinkToken} from "lib/chainlink-local/src/ccip/CCIPLocalSimulator.sol";

contract CCIPHandler is Test {
    CCIPSenderReceiverMessaging public ccip;
    REG public reg;
    LinkToken public link;
    WETH9 public weth;

    address public defaultAdmin;
    address public pauser;
    address public unpauser;

    uint64 public destinationChainSelector;
    IRouterClient public router;

    // simple bookkeeping
    uint256 public totalRegBridged; // how much REG was moved from users into CCIP burn/bridge path

    address[] public users;
    address public receiver;

    constructor(
        CCIPSenderReceiverMessaging _ccip,
        REG _reg,
        LinkToken _link,
        WETH9 _weth,
        IRouterClient _router,
        uint64 _destSelector,
        address _defaultAdmin,
        address _pauser,
        address _unpauser,
        address _receiver,
        address[] memory _users
    ) {
        ccip = _ccip;
        reg = _reg;
        link = _link;
        weth = _weth;
        router = _router;
        destinationChainSelector = _destSelector;

        defaultAdmin = _defaultAdmin;
        pauser = _pauser;
        unpauser = _unpauser;

        receiver = _receiver;
        users = _users;
    }

    // --- Admin-ish actions (fuzzable) ---
    function admin_allowlistToken(bool allowed) external {
        vm.prank(defaultAdmin);
        // if it reverts because "no state change", that's fine in invariant fuzzing
        (bool ok, ) = address(ccip).call(
            abi.encodeWithSignature(
                "allowlistToken(address,bool)",
                address(reg),
                allowed
            )
        );
        ok; // ignore
    }

    function admin_allowlistDestination(bool allowedRouterAddr) external {
        vm.prank(defaultAdmin);
        address r = allowedRouterAddr ? address(router) : address(ccip); // any contract address
        (bool ok, ) = address(ccip).call(
            abi.encodeWithSignature(
                "allowlistDestinationChain(uint64,address)",
                destinationChainSelector,
                r
            )
        );
        ok;
    }

    function admin_setRouter() external {
        vm.prank(defaultAdmin);
        (bool ok, ) = address(ccip).call(
            abi.encodeWithSignature("setRouter(address)", address(router))
        );
        ok;
    }

    function admin_pause() external {
        vm.prank(pauser);
        (bool ok, ) = address(ccip).call(abi.encodeWithSignature("pause()"));
        ok;
    }

    function admin_unpause() external {
        vm.prank(unpauser);
        (bool ok, ) = address(ccip).call(abi.encodeWithSignature("unpause()"));
        ok;
    }

    // --- User-ish actions (fuzzable) ---
    function user_transferUsingLink(
        uint256 userSeed,
        uint256 amountSeed,
        uint256 gasLimitSeed
    ) external {
        address u = users[userSeed % users.length];

        // bound amount to user's balance
        uint256 bal = reg.balanceOf(u);
        if (bal == 0) return;

        uint256 amount = bound(amountSeed, 1, bal);
        uint256 gasLimit = bound(gasLimitSeed, 50_000, 2_000_000);

        // approve
        vm.startPrank(u);
        reg.approve(address(ccip), amount);
        link.approve(address(ccip), type(uint256).max);

        // compute fees; if reverts due to config, just return
        uint256 fees;
        try
            ccip.getCcipFeesEstimation(
                destinationChainSelector,
                receiver,
                address(reg),
                amount,
                address(link),
                gasLimit
            )
        returns (uint256 f) {
            fees = f;
        } catch {
            vm.stopPrank();
            return;
        }

        // call; if reverts (paused/not allowlisted/etc.), ignore
        (bool ok, ) = address(ccip).call(
            abi.encodeWithSignature(
                "transferTokens(uint64,address,address,uint256,address,uint256)",
                destinationChainSelector,
                receiver,
                address(reg),
                amount,
                address(link),
                gasLimit
            )
        );
        vm.stopPrank();

        if (ok) totalRegBridged += amount;
    }

    function user_transferUsingNative(
        uint256 userSeed,
        uint256 amountSeed,
        uint256 gasLimitSeed
    ) external {
        address u = users[userSeed % users.length];
        uint256 bal = reg.balanceOf(u);
        if (bal == 0) return;

        uint256 amount = bound(amountSeed, 1, bal);
        uint256 gasLimit = bound(gasLimitSeed, 50_000, 2_000_000);

        uint256 fees;
        try
            ccip.getCcipFeesEstimation(
                destinationChainSelector,
                receiver,
                address(reg),
                amount,
                address(0),
                gasLimit
            )
        returns (uint256 f) {
            fees = f;
        } catch {
            return;
        }

        vm.deal(u, fees + 1 ether);

        vm.startPrank(u);
        reg.approve(address(ccip), amount);

        (bool ok, ) = address(ccip).call{value: fees}(
            abi.encodeWithSignature(
                "transferTokens(uint64,address,address,uint256,address,uint256)",
                destinationChainSelector,
                receiver,
                address(reg),
                amount,
                address(0),
                gasLimit
            )
        );
        vm.stopPrank();

        if (ok) totalRegBridged += amount;
    }

    function user_transferUsingWeth(
        uint256 userSeed,
        uint256 amountSeed,
        uint256 gasLimitSeed
    ) external {
        address u = users[userSeed % users.length];
        uint256 bal = reg.balanceOf(u);
        if (bal == 0) return;

        uint256 amount = bound(amountSeed, 1, bal);
        uint256 gasLimit = bound(gasLimitSeed, 50_000, 2_000_000);

        uint256 fees;
        try
            ccip.getCcipFeesEstimation(
                destinationChainSelector,
                receiver,
                address(reg),
                amount,
                address(weth),
                gasLimit
            )
        returns (uint256 f) {
            fees = f;
        } catch {
            return;
        }

        vm.startPrank(u);
        reg.approve(address(ccip), amount);
        weth.approve(address(ccip), type(uint256).max);

        (bool ok, ) = address(ccip).call(
            abi.encodeWithSignature(
                "transferTokens(uint64,address,address,uint256,address,uint256)",
                destinationChainSelector,
                receiver,
                address(reg),
                amount,
                address(weth),
                gasLimit
            )
        );
        vm.stopPrank();

        if (ok) totalRegBridged += amount;
    }

    // Admin withdrawal actions (optional)
    function admin_withdrawNative() external {
        vm.prank(defaultAdmin);
        (bool ok, ) = address(ccip).call(
            abi.encodeWithSignature("withdraw(address)", defaultAdmin)
        );
        ok;
    }

    function admin_withdrawReg() external {
        vm.prank(defaultAdmin);
        (bool ok, ) = address(ccip).call(
            abi.encodeWithSignature(
                "withdrawToken(address,address)",
                defaultAdmin,
                address(reg)
            )
        );
        ok;
    }
}
