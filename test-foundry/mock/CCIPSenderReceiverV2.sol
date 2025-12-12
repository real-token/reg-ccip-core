// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CCIPSenderReceiver} from "../../contracts/ccip/CCIPSenderReceiver.sol";

/**
 * @dev A mock second version of the contract to test UUPS upgrades.
 * Adds a new function, e.g. `newFunction()`.
 */
contract CCIPSenderReceiverV2 is CCIPSenderReceiver {
    function newFunction() external pure returns (string memory) {
        return "CCIPSenderReceiver V2 is active";
    }
}
