// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RegErrors library
 * @author RealT
 * @notice Defines the error messages emitted by the REG contract
 */
library REGErrors {
    error InvalidAmount(uint256 amount);
    error InvalidLength(uint256 length);
    error LengthNotMatch(uint256 length1, uint256 length2);
}
