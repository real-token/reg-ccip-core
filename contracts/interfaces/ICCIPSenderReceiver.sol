// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

/**
 * @title Interface of the REG CCIP Sender contract
 * @author @RealT
 * @notice REG CCIP Sender
 */
interface ICCIPSenderReceiver {
    struct AllowlistChainState {
        address destinationChainReceiver;
        bool isInList;
    }

    struct AllowlistTokenState {
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
     * @dev Emitted on ccipReceive when the tokens are received from CCIP
     * @param messageId The unique ID of the message
     * @param sourceChainSelector The chain selector of the source chain
     * @param sender The address of the sender on the source chain
     * @param receiver The address of the final receiver to receive the token
     * @param token The token address
     * @param amount the token amount that was transferred
     */
    event TokensReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        address receiver,
        address token,
        uint256 amount
    );

    /**
     * @dev Emitted when allowlistDestinationChain is called
     * @param destinationChainSelector The selector of the destination chain to be updated
     * @param destinationChainReceiver The CCIP receiver contract address for the destination chain
     */
    event AllowlistDestinationChain(
        uint64 indexed destinationChainSelector,
        address indexed destinationChainReceiver
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
    event SetRouter(IRouterClient indexed router);

    /**
     * @dev Updates the allowlist status of a destination chain for transactions
     * @notice This function can only be called by the owner
     * - Only callable by the DEFAULT_ADMIN_ROLE
     * @param destinationChainSelector The selector of the destination chain to be updated
     * @param destinationChainReceiver The CCIP receiver contract address for the destination chain
     */
    function allowlistDestinationChain(
        uint64 destinationChainSelector,
        address destinationChainReceiver
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
    function setRouter(IRouterClient router) external;

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
     * @param feeToken the token address used to pay CCIP fees
     * @param gasLimit The gas limit for the ccipReceive function call on the destination chain
     * @return messageId The ID of the message that was sent
     */
    function transferTokens(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        address feeToken,
        uint256 gasLimit
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
     * @param feeToken the token address used to pay CCIP fees
     * @param gasLimit The gas limit for the ccipReceive function call on the destination chain
     * @param deadline The deadline timestamp for the permit signature
     * @param v Signature parameter
     * @param r Signature parameter
     * @param s Signature parameter
     * @return messageId The ID of the message that was sent
     */
    function transferTokensWithPermit(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        address feeToken,
        uint256 gasLimit,
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
    function getRouter() external view returns (IRouterClient);

    /**
     * @notice Returns the LINK token address
     * @return The LINK token address
     */
    function getLinkToken() external pure returns (address);

    /**
     * @notice Returns the wrapped native token address (WETH, WMATIC, WXDAI)
     * @return The wrapped native token address
     */
    function getWrappedNativeToken() external pure returns (address);

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
     * @notice Returns the estimated fees of CCIP tx in feeToken (address(0) for native gas)
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain
     * @param receiver The address of the recipient on the destination blockchain
     * @param token token address
     * @param amount token amount
     * @param gasLimit The gas limit for the ccipReceive function call on the destination chain
     * @return The estimated fees of CCIP tx in feeToken (address(0) for native gas)
     */
    function getCcipFeesEstimation(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        address feeToken,
        uint256 gasLimit
    ) external view returns (uint256);
}
