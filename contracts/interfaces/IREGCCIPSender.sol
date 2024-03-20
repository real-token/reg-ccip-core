// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IREGCCIPSender {
    /**
     * @dev Emitted when the tokens are transferred to an account on another chain.
     * @param messageId The unique ID of the message.
     * @param destinationChainSelector The chain selector of the destination chain.
     * @param receiver The address of the receiver on the destination chain.
     * @param token The token address that was transferred.
     * @param tokenAmount The token amount that was transferred.
     * @param feeToken the token address used to pay CCIP fees.
     * @param fees The fees paid for sending the message.
     */
    event TokensTransferred(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        address token,
        uint256 tokenAmount,
        address feeToken,
        uint256 fees
    );

    /**
     * @dev Emitted when the CCIP router address is set.
     * @param router The CCIP router address.
     */
    event SetRouter(address router);

    /**
     * @dev Emitted when the LINK token address is set.
     * @param linkToken The LINK token address.
     */
    event SetLinkToken(address linkToken);

    /**
     * @dev Emitted when the REG token address is set.
     * @param regToken The REG token address.
     */
    event SetRegToken(address regToken);

    /**
     * @dev Updates the allowlist status of a destination chain for transactions.
     * @notice This function can only be called by the owner.
     * - Only callable by the DEFAULT_ADMIN_ROLE
     * @param destinationChainSelector The selector of the destination chain to be updated.
     * @param allowed The allowlist status to be set for the destination chain.
     */
    function allowlistDestinationChain(
        uint64 destinationChainSelector,
        bool allowed
    ) external;

    /**
     * @dev Set the CCIP router address.
     * @param router The CCIP router address.
     */
    function setRouter(address router) external;

    /**
     * @dev Set the LINK token address.
     * @param linkToken The LINK token address.
     */
    function setLinkToken(address linkToken) external;

    /**
     * @dev Set the REG token address.
     * @param regToken The REG token address.
     */
    function setRegToken(address regToken) external;

    /**
     * @notice Transfer tokens to receiver on the destination chain.
     * @notice pay in LINK.
     * @notice the token must be in the list of supported tokens.
     * @notice This function can only be called by the owner.
     * @dev Assumes your contract has sufficient LINK tokens to pay for the fees.
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain.
     * @param receiver The address of the recipient on the destination blockchain.
     * @param token token address.
     * @param amount token amount.
     * @return messageId The ID of the message that was sent.
     */
    function transferTokensPayLINK(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    ) external returns (bytes32 messageId);

    /**
     * @notice Transfer tokens to receiver on the destination chain.
     * @notice Pay in native gas such as ETH on Ethereum or MATIC on Polygon.
     * @notice the token must be in the list of supported tokens.
     * @notice This function can only be called by the owner.
     * @dev Assumes your contract has sufficient native gas like ETH on Ethereum or MATIC on Polygon.
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain.
     * @param receiver The address of the recipient on the destination blockchain.
     * @param token token address.
     * @param amount token amount.
     * @return messageId The ID of the message that was sent.
     */
    function transferTokensPayNative(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    ) external returns (bytes32 messageId);

    /**
     * @notice Transfer tokens to receiver on the destination chain.
     * @notice pay in LINK.
     * @notice the token must be in the list of supported tokens.
     * @notice This function can only be called by the owner.
     * @dev Assumes your contract has sufficient LINK tokens to pay for the fees.
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain.
     * @param receiver The address of the recipient on the destination blockchain.
     * @param token token address.
     * @param amount token amount.
     * @return messageId The ID of the message that was sent.
     */
    function transferTokensPayLINKWithPermit(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (bytes32 messageId);

    /**
     * @notice Transfer tokens to receiver on the destination chain.
     * @notice Pay in native gas such as ETH on Ethereum or MATIC on Polygon.
     * @notice the token must be in the list of supported tokens.
     * @notice This function can only be called by the owner.
     * @dev Assumes your contract has sufficient native gas like ETH on Ethereum or MATIC on Polygon.
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain.
     * @param receiver The address of the recipient on the destination blockchain.
     * @param token token address.
     * @param amount token amount.
     * @return messageId The ID of the message that was sent.
     */
    function transferTokensPayNativeWithPermit(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (bytes32 messageId);

    /**
     * @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
     * @dev This function reverts if there are no funds to withdraw or if the transfer fails.
     * It should only be callable by the owner of the contract.
     * @param beneficiary The address to which the Ether should be transferred.
     */
    function withdraw(address beneficiary) external;

    /**
     * @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token.
     * @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw.
     * @param beneficiary The address to which the tokens will be sent.
     * @param token The contract address of the ERC20 token to be withdrawn.
     */
    function withdrawToken(address beneficiary, address token) external;
}
