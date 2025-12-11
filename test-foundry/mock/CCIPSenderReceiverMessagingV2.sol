// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CCIPSenderReceiverMessaging} from "../../contracts/ccip/CCIPSenderReceiverMessaging.sol";

/**
 * @dev A mock second version of the contract to test UUPS upgrades.
 * Adds a new function, e.g. `newFunction()`.
 */
contract CCIPSenderReceiverMessagingV2 is CCIPSenderReceiverMessaging {
    function newFunction() external pure returns (string memory) {
        return "CCIPSenderReceiverMessaging V2 is active";
    }
}
