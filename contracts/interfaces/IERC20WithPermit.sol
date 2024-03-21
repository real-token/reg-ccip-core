//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @title Interface for ERC20 token with permit
 */

interface IERC20WithPermit is IERC20Upgradeable, IERC20PermitUpgradeable {
    // solhint-disable-previous-line no-empty-blocks
}
