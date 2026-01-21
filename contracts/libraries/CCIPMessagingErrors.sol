// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CCIPMessagingErrors library
 * @author RealT
 * @notice Defines the error messages emitted by the CCIPSenderReceiverMessaging contract
 */
library CCIPMessagingErrors {
    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(
        address owner,
        address target,
        uint256 value,
        bytes data
    ); // Used when the withdrawal of Ether fails.
    error FailedToRefund(bytes data); // Used when the refund of Ether fails.
    error FailedToBurnToken();
    error AllowedStateNotChange();
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
    error SourceChainNotAllowlisted(uint64 sourceChainSelector); // Used when the source chain has not been allowlisted by
    error TokenNotAllowlisted(address token); // Used when the token has not been allowlisted by the contract owner.
    error InvalidReceiverAddress(); // Used when the receiver address is 0.
    error InvalidContractAddress(); // Used when a contract address is set to zero address.
    error InvalidFeeToken(address feeToken); // Used when the fee token is not LINK or zero address (native)
    error InvalidRouter(address router); // Used when the router address is set to zero address.
    error InvalidSender(address sender); // Used when the sender address is not allowlisted.

    error TokenNotMapped(address token, uint64 chainSelector); // Used when token is not mapped to destination chain.
    error MaxBridgedAmountExceeded(
        address token,
        uint64 chainSelector,
        int256 currentBridged,
        uint256 amount,
        uint256 maxAmount
    ); // Used when max bridged amount would be exceeded.
    error ArrayLengthMismatch(); // Used when input arrays have different lengths.
    error EmptyArray(); // Used when an empty array is provided.
    error ZeroAddress(); // Used when a zero address is provided.
    error ZeroAmount(); // Used when a zero amount is provided.
}
