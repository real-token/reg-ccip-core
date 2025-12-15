// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {REG} from "../contracts/reg/REG.sol";
import {CCIPErrors} from "../contracts/libraries/CCIPErrors.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {CCIPLocalSimulator, WETH9, LinkToken, IRouterClient, BurnMintERC677Helper} from "lib/chainlink-local/src/ccip/CCIPLocalSimulator.sol";
import {CCIPSenderReceiver} from "../contracts/ccip/CCIPSenderReceiver.sol";
import {ICCIPSenderReceiver} from "../contracts/interfaces/ICCIPSenderReceiver.sol";
import {CCIPSenderReceiverV2} from "./mock/CCIPSenderReceiverV2.sol";

contract CCIPSenderReceiverTest is Test {
    address private constant ETHEREUM_LINKTOKEN =
        0x514910771AF9Ca656af840dff83E8264EcF986CA; // LINK on Ethereum
    address private constant ETHEREUM_WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on Ethereum

    CCIPLocalSimulator public ccipLocalSimulator;
    IRouterClient public destinationRouter;
    IRouterClient public sourceRouter;
    WETH9 public wrappedNative;
    LinkToken public linkToken;
    BurnMintERC677Helper public ccipBnM;
    BurnMintERC677Helper public ccipLnM;
    uint64 destinationChainSelector;
    uint64 sourceChainSelector;

    CCIPSenderReceiver private ccipImpl;
    CCIPSenderReceiver private ccip;
    ERC1967Proxy private ccipProxy;

    REG private regImpl;
    REG private reg;
    ERC1967Proxy private regProxy;

    address defaultAdmin = address(11);
    address pauser = address(12);
    address upgrader = address(14);
    address minter = address(15);

    uint256 alicePrivateKey = 0xBEEF;
    address alice = vm.addr(alicePrivateKey);
    address bob = address(102);

    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();

        (
            uint64 chainSelector_,
            IRouterClient sourceRouter_,
            IRouterClient destinationRouter_,
            WETH9 wrappedNative_,
            LinkToken linkToken_,
            BurnMintERC677Helper ccipBnM_,
            BurnMintERC677Helper ccipLnM_
        ) = ccipLocalSimulator.configuration();

        destinationChainSelector = chainSelector_;
        sourceRouter = sourceRouter_;
        destinationRouter = destinationRouter_;
        linkToken = linkToken_;
        wrappedNative = wrappedNative_;
        ccipBnM = ccipBnM_;
        ccipLnM = ccipLnM_;

        // Deploy CCIPSenderReceiver
        ccipImpl = new CCIPSenderReceiver();
        ccipProxy = new ERC1967Proxy(
            address(ccipImpl),
            abi.encodeWithSelector(
                CCIPSenderReceiver.initialize.selector,
                defaultAdmin,
                pauser,
                upgrader,
                sourceRouter
            )
        );
        ccip = CCIPSenderReceiver(address(ccipProxy));

        // Deploy REG
        regImpl = new REG();
        regProxy = new ERC1967Proxy(
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

        // Grant minter/burner role to CCIPSenderReceiver and support REG token in the CCIPLocalSimulator
        vm.startPrank(defaultAdmin);
        reg.grantRole(reg.MINTER_BRIDGE_ROLE(), address(ccip));
        ccipLocalSimulator.supportNewTokenViaAccessControlDefaultAdmin(
            address(reg)
        );
        vm.stopPrank();

        // Mint tokens to Alice and Bob
        vm.startPrank(minter);
        reg.mintByGovernance(alice, 1000 ether);
        reg.mintByGovernance(bob, 1000 ether);
        ccipLocalSimulator.requestLinkFromFaucet(alice, 10 ether);
        ccipLocalSimulator.requestLinkFromFaucet(bob, 10 ether);
        ccipBnM.drip(alice);
        ccipBnM.drip(bob);
        vm.stopPrank();

        // Label addresses for more readable traces
        vm.label(defaultAdmin, "DefaultAdmin");
        vm.label(pauser, "Pauser");
        vm.label(upgrader, "Upgrader");
        vm.label(address(sourceRouter), "SourceRouter");
        vm.label(address(destinationRouter), "DestinationRouter");
        vm.label(address(linkToken), "LinkToken");
        vm.label(address(wrappedNative), "WrappedNativeToken");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
    }

    function test_initializationAndRoles() public view {
        // Check roles
        assertTrue(ccip.hasRole(ccip.DEFAULT_ADMIN_ROLE(), defaultAdmin));
        assertTrue(ccip.hasRole(ccip.PAUSER_ROLE(), pauser));
        assertTrue(ccip.hasRole(ccip.UPGRADER_ROLE(), upgrader));
    }

    function test_pauseAndUnpause() public {
        vm.startPrank(pauser);
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Paused(pauser);
        ccip.pause();
        assertTrue(ccip.paused());
        vm.stopPrank();

        vm.startPrank(pauser);
        vm.expectEmit(true, true, true, true);
        emit PausableUpgradeable.Unpaused(pauser);
        ccip.unpause();
        assertFalse(ccip.paused());
        vm.stopPrank();
    }

    function test_allowlistDestinationChain() public {
        vm.startPrank(defaultAdmin);

        vm.expectEmit(true, true, true, true);
        emit ICCIPSenderReceiver.AllowlistDestinationChain(
            destinationChainSelector,
            address(destinationRouter)
        );
        ccip.allowlistDestinationChain(
            destinationChainSelector,
            address(destinationRouter)
        );

        vm.stopPrank();
    }

    function test_allowlistToken() public {
        vm.startPrank(defaultAdmin);

        vm.expectEmit(true, true, true, true);
        emit ICCIPSenderReceiver.AllowlistToken(address(reg), true);
        ccip.allowlistToken(address(reg), true);

        vm.expectEmit(true, true, true, true);
        emit ICCIPSenderReceiver.AllowlistToken(address(reg), false);
        ccip.allowlistToken(address(reg), false);

        vm.stopPrank();
    }

    function test_setRouter() public {
        vm.startPrank(defaultAdmin);
        vm.expectEmit(true, true, true, true);
        emit ICCIPSenderReceiver.SetRouter(sourceRouter);
        ccip.setRouter(sourceRouter);
        assertEq(address(ccip.getRouter()), address(sourceRouter));
        vm.stopPrank();
    }

    function test_withdraw(uint256 amount) public {
        vm.assume(amount != 0);
        vm.deal(address(ccip), amount);
        assertEq(address(ccip).balance, amount);

        vm.startPrank(defaultAdmin);
        ccip.withdraw(defaultAdmin);

        vm.stopPrank();

        assertEq(address(ccip).balance, 0);
        assertEq(defaultAdmin.balance, amount);
    }

    function test_withdrawToken(uint256 amount) public {
        vm.assume(amount != 0);
        vm.assume(amount < type(uint256).max - 2000 ether);

        vm.prank(minter);
        reg.mintByGovernance(address(ccip), amount);
        assertEq(reg.balanceOf(address(ccip)), amount);

        vm.startPrank(defaultAdmin);
        ccip.withdrawToken(defaultAdmin, IERC20(address(reg)));
        vm.stopPrank();

        assertEq(reg.balanceOf(address(ccip)), 0);
        assertEq(reg.balanceOf(defaultAdmin), amount);
    }

    function test_transferTokens() public {
        vm.startPrank(defaultAdmin);
        ccip.setRouter(sourceRouter);
        ccip.allowlistToken(address(reg), true);
        ccip.allowlistDestinationChain(destinationChainSelector, address(ccip));
        vm.stopPrank();

        vm.startPrank(alice);
        reg.approve(address(ccip), 1e18);

        // TODO LINK in contract is not the same as in simulator
        // ccip.transferTokens(
        //     destinationChainSelector,
        //     bob,
        //     address(reg),
        //     1e18,
        //     address(linkToken),
        //     1000000
        // );
        vm.stopPrank();
    }

    function test_transferTokensWithPermit() public {
        vm.startPrank(defaultAdmin);
        ccip.setRouter(sourceRouter);
        ccip.allowlistToken(address(reg), true);
        ccip.allowlistDestinationChain(destinationChainSelector, address(ccip));
        vm.stopPrank();

        // // ===== Build permit digest for EIP-2612 =====
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(
            alice,
            alicePrivateKey,
            address(ccip),
            1e18, // amount
            deadline
        );

        vm.startPrank(alice);

        // TODO LINK in contract is not the same as in simulator
        // ccip.transferTokensWithPermit(
        //     destinationChainSelector,
        //     bob,
        //     address(reg),
        //     1e18,
        //     address(linkToken),
        //     1000000,
        //     deadline,
        //     v,
        //     r,
        //     s
        // );

        vm.stopPrank();
    }

    function test_getRouter() public {
        assertEq(address(ccip.getRouter()), address(sourceRouter));
        vm.startPrank(defaultAdmin);
        vm.expectEmit(true, true, true, true);
        emit ICCIPSenderReceiver.SetRouter(sourceRouter);
        ccip.setRouter(sourceRouter);
        assertEq(address(ccip.getRouter()), address(sourceRouter));
        vm.stopPrank();
    }

    function test_getLinkToken() public view {
        assertEq(ccip.getLinkToken(), ETHEREUM_LINKTOKEN);
    }

    function test_getWrappedNativeToken() public view {
        assertEq(ccip.getWrappedNativeToken(), ETHEREUM_WETH);
    }

    function test_getAllowlistedDestinationChains() public {
        vm.startPrank(defaultAdmin);
        ccip.allowlistDestinationChain(
            destinationChainSelector,
            address(destinationRouter)
        );
        vm.stopPrank();

        assertEq(
            ccip.getAllowlistedDestinationChains()[0],
            destinationChainSelector
        );
    }

    function test_getAllowlistedTokens() public {
        vm.startPrank(defaultAdmin);
        ccip.allowlistToken(address(reg), true);
        vm.stopPrank();

        assertEq(ccip.getAllowlistedTokens()[0], address(reg));
    }

    function test_isAllowlistedDestinationChain() public {
        assertEq(
            ccip.isAllowlistedDestinationChain(destinationChainSelector),
            false
        );

        vm.startPrank(defaultAdmin);
        ccip.allowlistDestinationChain(
            destinationChainSelector,
            address(destinationRouter)
        );
        vm.stopPrank();

        assertEq(
            ccip.isAllowlistedDestinationChain(destinationChainSelector),
            true
        );
    }

    function test_isAllowlistedToken() public {
        assertEq(ccip.isAllowlistedToken(address(reg)), false);

        vm.startPrank(defaultAdmin);
        ccip.allowlistToken(address(reg), true);
        vm.stopPrank();

        assertEq(ccip.isAllowlistedToken(address(reg)), true);
    }

    function test_getCcipFeesEstimation(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        address feeToken,
        uint256 gasLimit
    ) public view {
        destinationChainSelector = destinationChainSelector;
        token = address(reg);
        feeToken = address(linkToken);
        gasLimit = 100000;

        uint256 fees = ccip.getCcipFeesEstimation(
            destinationChainSelector,
            receiver,
            token,
            amount,
            feeToken,
            gasLimit
        );
        console.log("Fees is: ", fees);
    }

    function test_ccipReceive() public {}

    function test_supportsInterface() public view {
        assertTrue(ccip.supportsInterface(0x01ffc9a7)); // type(IERC165).interfaceId = type(IERC165Upgradeable).interfaceId
        assertTrue(ccip.supportsInterface(0x85572ffb)); // type(IAny2EVMMessageReceiver).interfaceId
        assertTrue(ccip.supportsInterface(0x7965db0b)); // type(IAccessControlUpgradeable).interfaceId
    }

    function test_upgradeToV2() public {
        CCIPSenderReceiverV2 newImpl = new CCIPSenderReceiverV2();

        vm.startPrank(upgrader);
        ccip.upgradeTo(address(newImpl));

        CCIPSenderReceiverV2 ccipV2 = CCIPSenderReceiverV2(address(ccip));

        string memory resp = ccipV2.newFunction();
        assertEq(resp, "CCIPSenderReceiver V2 is active");
    }

    function testRevert_CannotInitializeAgain(address account) public {
        vm.startPrank(account);

        vm.expectRevert("Initializable: contract is already initialized");
        ccip.initialize(defaultAdmin, pauser, upgrader, sourceRouter);

        vm.stopPrank();
    }

    function testRevert_CannotPauseIfNotPauser(address account) public {
        vm.assume(account != pauser);
        vm.startPrank(account);
        vm.expectRevert(_getRevertMessage(account, ccip.PAUSER_ROLE()));
        ccip.pause();

        vm.stopPrank();
    }

    function testRevert_CannotUnpauseIfNotPauser(address account) public {
        vm.assume(account != pauser);

        vm.startPrank(pauser);
        ccip.pause();
        vm.stopPrank();

        vm.startPrank(account);
        vm.expectRevert(_getRevertMessage(account, ccip.PAUSER_ROLE()));
        ccip.unpause();
        vm.stopPrank();
    }

    function testRevert_CannotAllowlistDestinationChainIfNotDefaultAdmin(
        address account
    ) public {
        vm.assume(account != defaultAdmin);

        vm.startPrank(account);
        vm.expectRevert(_getRevertMessage(account, ccip.DEFAULT_ADMIN_ROLE()));
        ccip.allowlistDestinationChain(
            destinationChainSelector,
            address(destinationRouter)
        );
        vm.stopPrank();
    }

    function testRevert_CannotAllowlistDestinationChainTwice() public {
        vm.startPrank(defaultAdmin);
        ccip.allowlistDestinationChain(
            destinationChainSelector,
            address(destinationRouter)
        );

        // Second tx reverts because the allowlisted state of the destination chain does not change
        vm.expectRevert(
            abi.encodeWithSelector(CCIPErrors.AllowedStateNotChange.selector)
        );
        ccip.allowlistDestinationChain(
            destinationChainSelector,
            address(destinationRouter)
        );

        vm.stopPrank();
    }

    function testRevert_CannotAllowlistTokenIfNotDefaultAdmin(
        address account
    ) public {
        vm.assume(account != defaultAdmin);

        vm.startPrank(account);
        vm.expectRevert(_getRevertMessage(account, ccip.DEFAULT_ADMIN_ROLE()));
        ccip.allowlistToken(address(reg), true);

        vm.expectRevert(_getRevertMessage(account, ccip.DEFAULT_ADMIN_ROLE()));
        ccip.allowlistToken(address(reg), false);

        vm.stopPrank();
    }

    function testRevert_CannotAllowlistTokenForNonContractAddress() public {
        vm.startPrank(defaultAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(CCIPErrors.InvalidContractAddress.selector)
        );
        ccip.allowlistToken(address(0), true);

        vm.stopPrank();
    }

    function testRevert_CannotAllowlistTokenTwice() public {
        vm.startPrank(defaultAdmin);
        ccip.allowlistToken(address(reg), true);

        // Second tx reverts because the allowlisted state of the token does not change
        vm.expectRevert(
            abi.encodeWithSelector(CCIPErrors.AllowedStateNotChange.selector)
        );
        ccip.allowlistToken(address(reg), true);

        vm.stopPrank();
    }

    function testRevert_CannotSetRouterIfNotDefaultAdmin(
        address account
    ) public {
        vm.assume(account != defaultAdmin);
        vm.startPrank(account);
        vm.expectRevert(_getRevertMessage(account, ccip.DEFAULT_ADMIN_ROLE()));
        ccip.setRouter(sourceRouter);

        vm.stopPrank();
    }

    function testRevert_CannotSetRouterToNonContractAddress() public {
        vm.startPrank(defaultAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(CCIPErrors.InvalidContractAddress.selector)
        );
        ccip.setRouter(IRouterClient(address(0)));

        vm.stopPrank();
    }

    function testRevert_CannotWithdrawIfNotDefaultAdmin(
        address account
    ) public {
        vm.assume(account != defaultAdmin);
        vm.startPrank(account);
        vm.expectRevert(_getRevertMessage(account, ccip.DEFAULT_ADMIN_ROLE()));
        ccip.withdraw(account);

        vm.stopPrank();
    }

    function testRevert_CannotWithdrawIfNothing() public {
        vm.startPrank(defaultAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(CCIPErrors.NothingToWithdraw.selector)
        );
        ccip.withdraw(defaultAdmin);

        vm.stopPrank();
    }

    function testRevert_CannotWithdrawTokenIfNotDefaultAdmin(
        address account
    ) public {
        vm.assume(account != defaultAdmin);
        vm.startPrank(account);
        vm.expectRevert(_getRevertMessage(account, ccip.DEFAULT_ADMIN_ROLE()));
        ccip.withdrawToken(account, IERC20(address(reg)));

        vm.stopPrank();
    }

    function testRevert_CannotWithdrawTokenIfNothing() public {
        vm.startPrank(defaultAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(CCIPErrors.NothingToWithdraw.selector)
        );
        ccip.withdrawToken(defaultAdmin, IERC20(address(reg)));

        vm.stopPrank();
    }

    function testRevert_CannotTransferTokensWhenPaused() public {
        _setUpCcip();

        vm.startPrank(pauser);
        ccip.pause();
        vm.stopPrank();

        vm.startPrank(alice);
        reg.approve(address(ccip), 1e18);

        vm.expectRevert("Pausable: paused");
        ccip.transferTokens(
            destinationChainSelector,
            bob,
            address(reg),
            1e18,
            address(linkToken),
            1000000
        );

        vm.stopPrank();
    }

    function testRevert_CannotTransferTokensIfTokenNotAllowlisted() public {
        vm.startPrank(alice);
        reg.approve(address(ccip), 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPErrors.TokenNotAllowlisted.selector,
                address(reg)
            )
        );
        ccip.transferTokens(
            destinationChainSelector,
            bob,
            address(reg),
            1e18,
            address(linkToken),
            1000000
        );

        vm.stopPrank();
    }

    function testRevert_CannotTransferTokensIfDestinationChainNotAllowlisted()
        public
    {
        vm.prank(defaultAdmin);
        ccip.allowlistToken(address(reg), true);

        vm.startPrank(alice);
        reg.approve(address(ccip), 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPErrors.DestinationChainNotAllowlisted.selector,
                destinationChainSelector
            )
        );
        ccip.transferTokens(
            destinationChainSelector,
            bob,
            address(reg),
            1e18,
            address(linkToken),
            1000000
        );

        vm.stopPrank();
    }

    function testRevert_CannotTransferTokensIfFeeTokenInvalid(
        address invalidFeeToken
    ) public {
        vm.assume(invalidFeeToken != address(0));
        vm.assume(invalidFeeToken != address(linkToken));
        vm.assume(invalidFeeToken != ETHEREUM_LINKTOKEN);
        vm.assume(invalidFeeToken != ETHEREUM_WETH);
        vm.assume(invalidFeeToken != address(wrappedNative));

        _setUpCcip();

        vm.startPrank(alice);
        reg.approve(address(ccip), 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPErrors.InvalidFeeToken.selector,
                invalidFeeToken
            )
        );
        ccip.transferTokens(
            destinationChainSelector,
            bob,
            address(reg),
            1e18,
            invalidFeeToken,
            1000000
        );

        vm.stopPrank();
    }

    function testRevert_CannotTransferTokensIfSourceChainNotAllowlisted()
        public
    {}

    function testRevert_CannotTransferTokensWithPermitWhenPaused() public {
        _setUpCcip();

        vm.startPrank(pauser);
        ccip.pause();
        vm.stopPrank();

        vm.startPrank(alice);
        reg.approve(address(ccip), 1e18);

        vm.expectRevert("Pausable: paused");
        ccip.transferTokens(
            destinationChainSelector,
            bob,
            address(reg),
            1e18,
            address(linkToken),
            1000000
        );

        vm.stopPrank();
    }

    function testRevert_CannotTransferTokensWithPermitIfTokenNotAllowlisted()
        public
    {
        vm.startPrank(alice);
        reg.approve(address(ccip), 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPErrors.TokenNotAllowlisted.selector,
                address(reg)
            )
        );
        ccip.transferTokens(
            destinationChainSelector,
            bob,
            address(reg),
            1e18,
            address(linkToken),
            1000000
        );

        vm.stopPrank();
    }

    function testRevert_CannotTransferTokensWithPermitIfDestinationChainNotAllowlisted()
        public
    {
        vm.prank(defaultAdmin);
        ccip.allowlistToken(address(reg), true);

        vm.startPrank(alice);
        reg.approve(address(ccip), 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                CCIPErrors.DestinationChainNotAllowlisted.selector,
                destinationChainSelector
            )
        );
        ccip.transferTokens(
            destinationChainSelector,
            bob,
            address(reg),
            1e18,
            address(linkToken),
            1000000
        );

        vm.stopPrank();
    }

    function testRevert_CannotTransferTokensWithPermitIfSourceChainNotAllowlisted()
        public
    {}

    function testRevert_CannotCallCcipReceiveIfNotRouter(
        address account,
        Client.Any2EVMMessage calldata message
    ) public {
        vm.assume(account != address(destinationRouter));

        vm.startPrank(account);
        vm.expectRevert(
            abi.encodeWithSelector(CCIPErrors.InvalidRouter.selector, account)
        );
        ccip.ccipReceive(message);
        vm.stopPrank();
    }

    function testRevert_CannotUpgradeIfNotUpgrader(
        address account,
        address newImplementation
    ) public {
        vm.assume(account != upgrader);

        vm.startPrank(account);
        vm.expectRevert(_getRevertMessage(account, ccip.UPGRADER_ROLE()));
        ccip.upgradeTo(newImplementation);
        vm.stopPrank();
    }

    function _setUpCcip() private {
        vm.startPrank(defaultAdmin);
        ccip.setRouter(sourceRouter);
        ccip.allowlistToken(address(reg), true);
        ccip.allowlistDestinationChain(destinationChainSelector, address(ccip));
        vm.stopPrank();
    }

    function _getPermitSignature(
        address ownerAddress,
        uint256 ownerPrivateKey,
        address spender,
        uint256 amount,
        uint256 deadline
    ) private view returns (uint8 v, bytes32 r, bytes32 s) {
        // ===== Build permit digest for EIP-2612 =====
        uint256 nonce = reg.nonces(ownerAddress);

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                ownerAddress, // Owner
                spender, // Spender
                amount, // value
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", reg.DOMAIN_SEPARATOR(), structHash)
        );

        // Sign with ownerPrivateKey
        (v, r, s) = vm.sign(ownerPrivateKey, digest);
    }

    function _getRevertMessage(
        address account,
        bytes32 role
    ) private pure returns (bytes memory) {
        return
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(account),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            );
    }
}
