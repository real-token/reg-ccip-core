// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/src/Upgrades.sol";
import {CCIPSenderReceiverMessaging} from "../contracts/ccip/CCIPSenderReceiverMessaging.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";

contract DeployCCIPSenderReceiverMessaging is Script {
    error InvalidAddress();

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        address defaultAdmin = vm.envAddress("DEFAULT_ADMIN_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        address unpauser = vm.envAddress("UNPAUSER_ADDRESS");
        address upgrader = vm.envAddress("UPGRADER_ADDRESS");
        address routerAddress = vm.envAddress("ROUTER_ADDRESS");
        address linkToken = vm.envAddress("LINK_TOKEN");
        address wrappedNative = vm.envAddress("WRAPPED_NATIVE");

        if (defaultAdmin == address(0)) defaultAdmin = deployerAddress;
        if (pauser == address(0)) pauser = deployerAddress;
        if (unpauser == address(0)) unpauser = deployerAddress;
        if (upgrader == address(0)) upgrader = deployerAddress;
        if (routerAddress == address(0)) revert InvalidAddress();
        if (linkToken == address(0)) revert InvalidAddress();
        if (wrappedNative == address(0)) revert InvalidAddress();

        IRouterClient router = IRouterClient(routerAddress);
        vm.startBroadcast();

        address ccipProxy = Upgrades.deployUUPSProxy(
            "CCIPSenderReceiverMessaging",
            abi.encodeCall(
                CCIPSenderReceiverMessaging.initialize,
                (
                    defaultAdmin,
                    pauser,
                    unpauser,
                    upgrader,
                    router,
                    linkToken,
                    wrappedNative
                )
            )
        );

        // Logging
        console.log(
            "------------------- CCIPSenderReceiverMessaging Deployment Info -------------------"
        );

        vm.stopBroadcast();
    }
}
