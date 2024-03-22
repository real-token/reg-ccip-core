// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Interface of the REG CCIP Sender contract
 * @author @RealT
 * @notice REG CCIP Sender
 */
interface IREGCCIPSender {
    struct AllowlistState {
        bool isAllowed;
        bool isInList;
    }

    /**
     * @dev Emitted when the tokens are transferred to an account on another chain
     * @param messageId The unique ID of the message
     * @param destinationChainSelector The chain selector of the destination chain
     * @param receiver The address of the receiver on the destination chain
     * @param token The token address that was transferred
     * @param tokenAmount The token amount that was transferred
     * @param feeToken the token address used to pay CCIP fees
     * @param fees The fees paid for sending the message
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
     * @dev Emitted when allowlistDestinationChain is called
     * @param destinationChainSelector The selector of the destination chain to be updated
     * @param allowed The allowlist status to be set for the destination chain
     */
    event AllowlistDestinationChain(
        uint64 indexed destinationChainSelector,
        bool indexed allowed
    );

    /**
     * @dev Emitted when allowlistDestinationChain is called
     * @param token The token address
     * @param allowed The allowlist status to be set for the token
     */
    event AllowlistToken(address indexed token, bool indexed allowed);

    /**
     * @dev Emitted when the CCIP router address is set
     * @param router The CCIP router address
     */
    event SetRouter(address indexed router);

    /**
     * @dev Emitted when the LINK token address is set
     * @param linkToken The LINK token address
     */
    event SetLinkToken(address indexed linkToken);

    /**
     * @dev Updates the allowlist status of a destination chain for transactions
     * @notice This function can only be called by the owner
     * - Only callable by the DEFAULT_ADMIN_ROLE
     * @param destinationChainSelector The selector of the destination chain to be updated
     * @param allowed The allowlist status to be set for the destination chain
     */
    function allowlistDestinationChain(
        uint64 destinationChainSelector,
        bool allowed
    ) external;

    /**
     * @dev Updates the allowlist status of a token
     * @notice This function can only be called by the owner
     * - Only callable by the DEFAULT_ADMIN_ROLE
     * @param token The token address
     * @param allowed The allowlist status to be set for the token
     */
    function allowlistToken(address token, bool allowed) external;

    /**
     * @dev Set the CCIP router address
     * - Only callable by the DEFAULT_ADMIN_ROLE
     * @param router The CCIP router address
     */
    function setRouter(address router) external;

    /**
     * @dev Set the LINK token address
     * - Only callable by the DEFAULT_ADMIN_ROLE
     * @param linkToken The LINK token address
     */
    function setLinkToken(address linkToken) external;

    /**
     * @notice Transfer tokens to receiver on the destination chain
     * @notice pay in LINK
     * @notice the token must be in the list of supported tokens
     * @notice This function can only be called by the owner
     * @dev Assumes your contract has sufficient LINK tokens to pay for the fees
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain
     * @param receiver The address of the recipient on the destination blockchain
     * @param token token address
     * @param amount token amount
     * @return messageId The ID of the message that was sent
     */
    function transferTokensPayLINK(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    ) external returns (bytes32 messageId);

    /**
     * @notice Transfer tokens to receiver on the destination chain
     * @notice Pay in native gas such as ETH on Ethereum or MATIC on Polygon
     * @notice the token must be in the list of supported tokens
     * @notice This function can only be called by the owner
     * @dev Assumes your contract has sufficient native gas like ETH on Ethereum or MATIC on Polygon
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain
     * @param receiver The address of the recipient on the destination blockchain
     * @param token token address
     * @param amount token amount
     * @return messageId The ID of the message that was sent
     */
    function transferTokensPayNative(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    ) external payable returns (bytes32 messageId);

    /**
     * @notice Transfer tokens to receiver on the destination chain
     * @notice pay in LINK
     * @notice the token must be in the list of supported tokens
     * @notice This function can only be called by the owner
     * @dev Assumes your contract has sufficient LINK tokens to pay for the fees
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain
     * @param receiver The address of the recipient on the destination blockchain
     * @param token token address
     * @param amount token amount
     * @param deadline The deadline timestamp for the permit signature
     * @param v Signature parameter
     * @param r Signature parameter
     * @param s Signature parameter
     * @return messageId The ID of the message that was sent
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
     * @notice Transfer tokens to receiver on the destination chain
     * @notice Pay in native gas such as ETH on Ethereum or MATIC on Polygon
     * @notice the token must be in the list of supported tokens
     * @notice This function can only be called by the owner
     * @dev Assumes your contract has sufficient native gas like ETH on Ethereum or MATIC on Polygon
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain
     * @param receiver The address of the recipient on the destination blockchain
     * @param token token address
     * @param amount token amount
     * @param deadline The deadline timestamp for the permit signature
     * @param v Signature parameter
     * @param r Signature parameter
     * @param s Signature parameter
     * @return messageId The ID of the message that was sent
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
    ) external payable returns (bytes32 messageId);

    /**
     * @notice Allows the contract owner to withdraw the entire balance of Ether from the contract
     * @dev This function reverts if there are no funds to withdraw or if the transfer fails
     * - Only callable by the DEFAULT_ADMIN_ROLE
     * @param beneficiary The address to which the Ether should be transferred
     */
    function withdraw(address beneficiary) external;

    /**
     * @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token
     * @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw
     * - Only callable by the DEFAULT_ADMIN_ROLE
     * @param beneficiary The address to which the tokens will be sent
     * @param token The contract address of the ERC20 token to be withdrawn
     */
    function withdrawToken(address beneficiary, address token) external;

    /**
     * @notice Returns the CCIP router address
     * @return The CCIP router address
     */
    function getRouter() external view returns (address);

    /**
     * @notice Returns the LINK token address
     * @return The LINK token address
     */
    function getLinkToken() external view returns (address);

    /**
     * @notice Returns the allowlist of destination chains
     * @return The allowlist of destination chains
     */
    function getAllowlistedDestinationChains()
        external
        view
        returns (uint64[] memory);

    /**
     * @notice Returns the allowlist of tokens that can be transferred
     * @return The allowlist of tokens
     */
    function getAllowlistedTokens() external view returns (address[] memory);

    /**
     * @notice Returns if a destination chain is allowlisted or not
     * @return Return true if the destination chain is allowlisted
     */
    function isAllowlistedDestinationChain(
        uint64 destinationChainSelector
    ) external view returns (bool);

    /**
     * @notice Returns if the token is allowlisted or not
     * @return Return true if the token is allowlisted
     */
    function isAllowlistedToken(address token) external view returns (bool);

    /**
     * @notice Returns the estimated fees of CCIP tx in LINK
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain
     * @param receiver The address of the recipient on the destination blockchain
     * @param token token address
     * @param amount token amount
     * @return The estimated fees of CCIP tx in LINK
     */
    function getEstimatedCCIPFeesInLink(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    ) external view returns (uint256);

    /**
     * @notice Returns the estimated fees of CCIP tx in native
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain
     * @param receiver The address of the recipient on the destination blockchain
     * @param token token address
     * @param amount token amount
     * @return The estimated fees of CCIP tx in native
     */
    function getEstimatedCCIPFeesInNative(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    ) external view returns (uint256);
}
