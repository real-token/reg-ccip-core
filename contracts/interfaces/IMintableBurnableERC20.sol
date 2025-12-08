// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title ERC20 interface that includes burn mint and roles methods.
 */
interface IMintableBurnableERC20 is IERC20, IERC20Metadata {
    /**
     * @notice Burns a specific amount of the caller's tokens.
     * @dev This method should be permissioned to only allow designated parties to burn tokens.
     * @param amount The amount of tokens to burn.
     * @return True if the burn was successful, false otherwise.
     */
    function burn(uint256 amount) external returns (bool);

    /**
     * @notice Mints tokens and adds them to the balance of the `account` address.
     * @dev This method should be permissioned to only allow designated parties to mint tokens.
     * @param account The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     * @return True if the mint was successful, false otherwise.
     */
    function mint(address account, uint256 amount) external returns (bool);
}
