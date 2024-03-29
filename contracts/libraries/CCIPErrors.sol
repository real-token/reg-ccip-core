// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CCIPErrors library
 * @author RealT
 * @notice Defines the error messages emitted by the CCIPSenderReceiver contract
 */
library CCIPErrors {
    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
    error TokenNotAllowlisted(address token); // Used when the token has not been allowlisted by the contract owner.
    error InvalidReceiverAddress(); // Used when the receiver address is 0.
    error InvalidContractAddress(); // Used when a contract address is set to zero address.
    error InvalidFeeToken(address feeToken); // Used when the fee token is not LINK or zero address (native)
    error AllowedStateNotChange();
    error InvalidRouter(address router); // Used when the router address is set to zero address.
    error InvalidSender(address sender); // Used when the sender address is not allowlisted.
}
