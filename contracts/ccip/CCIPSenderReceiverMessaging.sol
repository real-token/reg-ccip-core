// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/contracts/interfaces/IAny2EVMMessageReceiver.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {CCIPMessagingErrors} from "../libraries/CCIPMessagingErrors.sol";
import {IERC20WithPermit} from "../interfaces/IERC20WithPermit.sol";
import {IMintableBurnableERC20} from "../interfaces/IMintableBurnableERC20.sol";
import {ICCIPSenderReceiverMessaging} from "../interfaces/ICCIPSenderReceiverMessaging.sol";

/**
 * @title CCIPSenderReceiverMessaging
 * @author RealToken Inc.
 * @notice The entry contract for cross-chain token transfers using CCIP messaging
 */
contract CCIPSenderReceiverMessaging is
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ICCIPSenderReceiverMessaging,
    IAny2EVMMessageReceiver
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IMintableBurnableERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    IRouterClient private _router;

    address private _linkToken;

    address private _wrappedNativeToken;

    // Mapping to keep track of allowlisted destination chains
    mapping(uint64 => AllowlistChainState) private _allowlistedChains;

    mapping(address => AllowlistTokenState) private _allowlistedTokens;

    uint64[] private _chainsListHistory;

    address[] private _tokensListHistory;

    // Token mapping: sourceToken => destinationChainSelector => destinationToken
    mapping(address => mapping(uint64 => TokenMappingState))
        private _tokenMappings;

    // Max bridging amount per token per chain
    mapping(address => mapping(uint64 => uint256)) private _chainMaxAmount;

    // Bridged amount tracking per token per chain (negative = outbound, positive = inbound)
    mapping(address => mapping(uint64 => int256)) private _chainBridgedAmount;

    // Total bridged amount per token across all chains
    mapping(address => int256) private _totalBridgedAmount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Receive function to accept ETH
    receive() external payable {}

    /// @notice Initializes the contract
    /// @param defaultAdmin The address of the default admin
    /// @param pauser The address of the pauser
    /// @param unpauser The address of the unpauser
    /// @param upgrader The address of the upgrader
    /// @param router The router contract
    /// @param linkToken The LINK token address
    /// @param wrappedNativeToken The wrapped native token address
    function initialize(
        address defaultAdmin,
        address pauser,
        address unpauser,
        address upgrader,
        IRouterClient router,
        address linkToken,
        address wrappedNativeToken
    ) external initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(UNPAUSER_ROLE, unpauser);
        _grantRole(UPGRADER_ROLE, upgrader);

        _router = router;
        _linkToken = linkToken;
        _wrappedNativeToken = wrappedNativeToken;

        emit SetRouter(router);
    }

    /**
     * @notice The admin (with upgrader role) uses this function to update the contract
     * @dev This function is always needed in future implementation contract versions, otherwise, the contract will not be upgradeable
     * @param newImplementation is the address of the new implementation contract
     **/
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {
        // Intentionally left blank
    }

    /**
     * @dev Pause the contract if needed
     **/
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract if needed
     **/
    function unpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Modifier that checks if the chain with the given destinationChainSelector is allowlisted
     * @param destinationChainSelector The selector of the destination chain
     */
    modifier onlyAllowlistedChain(uint64 destinationChainSelector) {
        if (
            _allowlistedChains[destinationChainSelector]
                .destinationChainReceiver == address(0)
        )
            revert CCIPMessagingErrors.DestinationChainNotAllowlisted(
                destinationChainSelector
            );
        _;
    }

    /**
     * @dev Modifier that checks if the token is allowlisted
     * @param token The token address
     */
    modifier onlyAllowlistedToken(address token) {
        if (!_allowlistedTokens[token].isAllowed)
            revert CCIPMessagingErrors.TokenNotAllowlisted(token);
        _;
    }

    /**
     * @dev Modifier that checks a contract address
     * @param contractAddress The contract address
     */
    modifier validateContractAddress(address contractAddress) {
        if (!AddressUpgradeable.isContract(contractAddress))
            revert CCIPMessagingErrors.InvalidContractAddress();
        _;
    }

    /**
     * @dev Modifier that checks the receiver address is not 0
     * @param receiver The receiver address
     */
    modifier validateReceiver(address receiver) {
        if (receiver == address(0))
            revert CCIPMessagingErrors.InvalidReceiverAddress();
        _;
    }

    /// @dev only calls from the set router are accepted.
    modifier onlyRouter() {
        if (msg.sender != address(_router))
            revert CCIPMessagingErrors.InvalidRouter(msg.sender);
        _;
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function allowlistDestinationChain(
        uint64 destinationChainSelector,
        address destinationChainReceiver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AllowlistChainState storage chainState = _allowlistedChains[
            destinationChainSelector
        ];

        if (chainState.destinationChainReceiver == destinationChainReceiver) {
            revert CCIPMessagingErrors.AllowedStateNotChange();
        }

        chainState.destinationChainReceiver = destinationChainReceiver;

        if (destinationChainReceiver != address(0) && !chainState.isInList) {
            _chainsListHistory.push(destinationChainSelector);
            chainState.isInList = true;
        }

        emit AllowlistDestinationChain(
            destinationChainSelector,
            destinationChainReceiver
        );
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function allowlistToken(
        address token,
        bool allowed
    ) external validateContractAddress(token) onlyRole(DEFAULT_ADMIN_ROLE) {
        AllowlistTokenState storage tokenState = _allowlistedTokens[token];

        if (tokenState.isAllowed == allowed) {
            revert CCIPMessagingErrors.AllowedStateNotChange();
        }

        tokenState.isAllowed = allowed;

        if (allowed && !tokenState.isInList) {
            _tokensListHistory.push(token);
            tokenState.isInList = true;
        }
        emit AllowlistToken(token, allowed);
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function setRouter(
        IRouterClient router
    )
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        validateContractAddress(address(router))
    {
        _router = router;
        emit SetRouter(router);
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function setMappedTokens(
        uint64 chainSelector,
        address[] calldata sourceTokens,
        address[] calldata destinationTokens
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = sourceTokens.length;
        if (length == 0) revert CCIPMessagingErrors.EmptyArray();
        if (length != destinationTokens.length)
            revert CCIPMessagingErrors.ArrayLengthMismatch();

        for (uint256 i = 0; i < length; ) {
            if (
                sourceTokens[i] == address(0) ||
                destinationTokens[i] == address(0)
            ) revert CCIPMessagingErrors.ZeroAddress();

            TokenMappingState storage mappingState = _tokenMappings[
                sourceTokens[i]
            ][chainSelector];
            mappingState.destinationToken = destinationTokens[i];

            if (!mappingState.isInList) {
                mappingState.isInList = true;
            }

            emit TokenMapped(
                sourceTokens[i],
                chainSelector,
                destinationTokens[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function removeMappedTokens(
        uint64 chainSelector,
        address[] calldata sourceTokens
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = sourceTokens.length;
        if (length == 0) revert CCIPMessagingErrors.EmptyArray();

        for (uint256 i = 0; i < length; ) {
            if (
                _tokenMappings[sourceTokens[i]][chainSelector]
                    .destinationToken == address(0)
            )
                revert CCIPMessagingErrors.TokenNotMapped(
                    sourceTokens[i],
                    chainSelector
                );

            delete _tokenMappings[sourceTokens[i]][chainSelector]
                .destinationToken;

            emit TokenUnmapped(sourceTokens[i], chainSelector);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function setMaxChainAmount(
        uint64 chainSelector,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = tokens.length;
        if (length == 0) revert CCIPMessagingErrors.EmptyArray();
        if (length != amounts.length)
            revert CCIPMessagingErrors.ArrayLengthMismatch();

        for (uint256 i = 0; i < length; ) {
            if (tokens[i] == address(0))
                revert CCIPMessagingErrors.ZeroAddress();
            if (amounts[i] == 0) revert CCIPMessagingErrors.ZeroAmount();

            _chainMaxAmount[tokens[i]][chainSelector] = amounts[i];

            emit MaxChainAmountSet(tokens[i], chainSelector, amounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function removeMaxChainAmount(
        uint64 chainSelector,
        address[] calldata tokens
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = tokens.length;
        if (length == 0) revert CCIPMessagingErrors.EmptyArray();

        for (uint256 i = 0; i < length; ) {
            if (_chainMaxAmount[tokens[i]][chainSelector] == 0)
                revert CCIPMessagingErrors.ZeroAmount();

            delete _chainMaxAmount[tokens[i]][chainSelector];

            emit MaxChainAmountRemoved(tokens[i], chainSelector);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function withdraw(
        address beneficiary
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Retrieve the balance of this contract
        uint256 amount = address(this).balance;

        // Revert if there is nothing to withdraw
        if (amount == 0) revert CCIPMessagingErrors.NothingToWithdraw();

        // Attempt to send the funds, capturing the success status and discarding any return data
        // This is considered safe because the beneficiary is chosen by admin
        (bool sent, bytes memory data) = beneficiary.call{value: amount}("");

        // Revert if the send failed, with information about the attempted transfer
        if (!sent)
            revert CCIPMessagingErrors.FailedToWithdrawEth(
                msg.sender,
                beneficiary,
                amount,
                data
            );
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function withdrawToken(
        address beneficiary,
        IERC20 token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Retrieve the balance of this contract
        uint256 amount = token.balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert CCIPMessagingErrors.NothingToWithdraw();

        token.safeTransfer(beneficiary, amount);
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function transferTokens(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        address feeToken,
        uint256 gasLimit
    ) external payable override returns (bytes32 messageId) {
        return
            _transferTokens(
                destinationChainSelector,
                receiver,
                token,
                amount,
                feeToken,
                gasLimit
            );
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
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
    ) external payable override returns (bytes32 messageId) {
        IERC20WithPermit(token).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        return
            _transferTokens(
                destinationChainSelector,
                receiver,
                token,
                amount,
                feeToken,
                gasLimit
            );
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function getRouter() external view override returns (IRouterClient) {
        return _router;
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function getLinkToken() external view override returns (address) {
        return _linkToken;
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function getWrappedNativeToken() external view override returns (address) {
        return _wrappedNativeToken;
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function getAllowlistedDestinationChains()
        external
        view
        override
        returns (uint64[] memory)
    {
        return _chainsListHistory;
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function getAllowlistedTokens()
        external
        view
        override
        returns (address[] memory)
    {
        return _tokensListHistory;
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function isAllowlistedDestinationChain(
        uint64 destinationChainSelector
    ) external view override returns (bool) {
        return
            _allowlistedChains[destinationChainSelector]
                .destinationChainReceiver != address(0);
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function isAllowlistedToken(
        address token
    ) external view override returns (bool) {
        return _allowlistedTokens[token].isAllowed;
    }

    /**
     * @notice Transfer tokens to receiver on the destination chain
     * @notice pay in LINK/Native gas
     * @notice the token must be in the list of supported tokens
     * @notice This function can only be called by the owner
     * @dev Assumes your contract has sufficient LINK/Native to pay for the fees
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain
     * @param receiver The address of the recipient on the destination blockchain
     * @param token token address
     * @param amount token amount
     * @param feeToken fee token address (LINK or 0 for native gas)
     * @param gasLimit The gas limit for the ccipReceive function call on the destination chain
     * @return messageId The ID of the message that was sent
     */
    function _transferTokens(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        address feeToken,
        uint256 gasLimit
    )
        private
        whenNotPaused
        onlyAllowlistedToken(token)
        onlyAllowlistedChain(destinationChainSelector)
        validateReceiver(receiver)
        returns (bytes32 messageId)
    {
        // Check if the fee token is LINK or 0 (native gas) or wrapped native token
        if (
            feeToken != address(0) &&
            feeToken != _linkToken &&
            feeToken != _wrappedNativeToken
        ) {
            revert CCIPMessagingErrors.InvalidFeeToken(feeToken);
        }

        // Check token mapping and max bridged amount
        _validateBridgeLimits(token, destinationChainSelector, amount);

        // Build CCIP message params
        CCIPMessageParams memory params = CCIPMessageParams({
            receiver: receiver,
            sourceToken: token,
            destToken: _tokenMappings[token][destinationChainSelector]
                .destinationToken,
            amount: amount,
            feeToken: feeToken,
            ccipReceiver: _allowlistedChains[destinationChainSelector]
                .destinationChainReceiver,
            gasLimit: gasLimit
        });

        // Get the fee and send message
        uint256 fees;
        (messageId, fees) = _burnAndSendCCIP(
            destinationChainSelector,
            token,
            amount,
            feeToken,
            params
        );

        // Emit an event with message details
        emit TokensTransferred(
            messageId,
            destinationChainSelector,
            receiver,
            token,
            amount,
            feeToken,
            fees
        );
    }

    /**
     * @notice Validate bridge limits for token transfer
     * @param token The token address
     * @param chainSelector The destination chain selector
     * @param amount The amount to bridge
     */
    function _validateBridgeLimits(
        address token,
        uint64 chainSelector,
        uint256 amount
    ) private view {
        // Check token mapping exists
        if (_tokenMappings[token][chainSelector].destinationToken == address(0))
            revert CCIPMessagingErrors.TokenNotMapped(token, chainSelector);

        // Check max bridged amount if limit is set
        uint256 maxAmount = _chainMaxAmount[token][chainSelector];
        if (maxAmount > 0) {
            int256 currentBridged = _chainBridgedAmount[token][chainSelector];
            // Outbound bridging is negative, so we check if (currentBridged - amount) would exceed -maxAmount
            // This means: amount - currentBridged <= maxAmount (after rearranging)
            if (int256(amount) - currentBridged > int256(maxAmount)) {
                revert CCIPMessagingErrors.MaxBridgedAmountExceeded(
                    token,
                    chainSelector,
                    currentBridged,
                    amount,
                    maxAmount
                );
            }
        }
    }

    /**
     * @notice Burns tokens and sends CCIP message
     * @param chainSelector The destination chain selector
     * @param token The token address
     * @param amount The amount to bridge
     * @param feeToken The fee token address
     * @param params The CCIP message params
     * @return messageId The CCIP message ID
     * @return fees The fees paid
     */
    function _burnAndSendCCIP(
        uint64 chainSelector,
        address token,
        uint256 amount,
        address feeToken,
        CCIPMessageParams memory params
    ) private returns (bytes32 messageId, uint256 fees) {
        // Build the CCIP message
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(params);

        // Get the fee required to send the message
        fees = _router.getFee(chainSelector, evm2AnyMessage);

        // Transfer token from the user to this contract then burn it
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        bool success = IMintableBurnableERC20(token).burn(amount);
        if (!success) revert CCIPMessagingErrors.FailedToBurnToken();

        // Update bridged amount tracking (outbound is negative)
        _chainBridgedAmount[token][chainSelector] -= int256(amount);
        _totalBridgedAmount[token] -= int256(amount);

        // Handle fee payment and send message
        messageId = _handleFeesAndSend(
            chainSelector,
            feeToken,
            fees,
            evm2AnyMessage
        );
    }

    /**
     * @notice Handles fee payment and sends CCIP message
     * @param chainSelector The destination chain selector
     * @param feeToken The fee token address
     * @param fees The fees to pay
     * @param evm2AnyMessage The CCIP message
     * @return messageId The CCIP message ID
     */
    function _handleFeesAndSend(
        uint64 chainSelector,
        address feeToken,
        uint256 fees,
        Client.EVM2AnyMessage memory evm2AnyMessage
    ) private returns (bytes32 messageId) {
        if (feeToken == address(0)) {
            messageId = _handleNativeFeeAndSend(
                chainSelector,
                fees,
                evm2AnyMessage
            );
        } else {
            messageId = _handleTokenFeeAndSend(
                chainSelector,
                feeToken,
                fees,
                evm2AnyMessage
            );
        }
    }

    /**
     * @notice Handles native fee payment and sends CCIP message
     */
    function _handleNativeFeeAndSend(
        uint64 chainSelector,
        uint256 fees,
        Client.EVM2AnyMessage memory evm2AnyMessage
    ) private returns (bytes32 messageId) {
        // Check if msg.value is enough to pay for the fees
        if (fees > msg.value)
            revert CCIPMessagingErrors.NotEnoughBalance(msg.value, fees);
        // If the user sent more than the required fees, send the excess back
        if (msg.value > fees) {
            (bool sent, bytes memory data) = msg.sender.call{
                value: msg.value - fees
            }("");
            if (!sent) revert CCIPMessagingErrors.FailedToRefund(data);
        }
        messageId = _router.ccipSend{value: fees}(
            chainSelector,
            evm2AnyMessage
        );
    }

    /**
     * @notice Handles token fee payment and sends CCIP message
     */
    function _handleTokenFeeAndSend(
        uint64 chainSelector,
        address feeToken,
        uint256 fees,
        Client.EVM2AnyMessage memory evm2AnyMessage
    ) private returns (bytes32 messageId) {
        IERC20 feeTokenInstance = IERC20(feeToken);

        // Transfer fee token from the user to this contract
        feeTokenInstance.safeTransferFrom(msg.sender, address(this), fees);

        // approve the Router to transfer fee tokens on contract's behalf
        feeTokenInstance.safeIncreaseAllowance(address(_router), fees);

        messageId = _router.ccipSend(chainSelector, evm2AnyMessage);
    }

    /**
     * @notice Construct a CCIP message
     * @dev This function will create an EVM2AnyMessage struct with all the necessary information for tokens transfer
     * @param params The CCIPMessageParams struct containing all message parameters
     * @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message
     */
    function _buildCCIPMessage(
        CCIPMessageParams memory params
    ) private pure returns (Client.EVM2AnyMessage memory) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(params.ccipReceiver), // ABI-encoded receiver address
                data: abi.encode(
                    params.sourceToken,
                    params.destToken,
                    params.amount,
                    params.receiver
                ), // Encode with source token, dest token, amount, and receiver
                tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array as no tokens are transferred
                extraArgs: Client._argsToBytes(
                    // Setting gas limit for action on destination chain
                    Client.EVMExtraArgsV1({gasLimit: params.gasLimit})
                ),
                // Set the feeToken to a feeToken, indicating specific asset will be used for fees
                feeToken: params.feeToken
            });
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function getCcipFeesEstimation(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        address feeToken,
        uint256 gasLimit
    ) external view returns (uint256) {
        CCIPMessageParams memory params = CCIPMessageParams({
            receiver: receiver,
            sourceToken: token,
            destToken: _tokenMappings[token][destinationChainSelector]
                .destinationToken,
            amount: amount,
            feeToken: feeToken,
            ccipReceiver: _allowlistedChains[destinationChainSelector]
                .destinationChainReceiver,
            gasLimit: gasLimit
        });
        return
            _router.getFee(destinationChainSelector, _buildCCIPMessage(params));
    }

    //**************************************** Receiver Logic starts here ****************************************/

    /// @notice IERC165 supports an interfaceId
    /// @param interfaceId The interfaceId to check
    /// @return true if the interfaceId is supported
    /// @dev Should indicate whether the contract implements IAny2EVMMessageReceiver
    /// e.g. return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId
    /// This allows CCIP to check if ccipReceive is available before calling it.
    /// If this returns false or reverts, only tokens are transferred to the receiver.
    /// If this returns true, tokens are transferred and ccipReceive is called atomically.
    /// Additionally, if the receiver address does not have code associated with
    /// it at the time of execution (EXTCODESIZE returns 0), only tokens will be transferred.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IAny2EVMMessageReceiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IAny2EVMMessageReceiver
    function ccipReceive(
        Client.Any2EVMMessage calldata message
    ) external override whenNotPaused onlyRouter {
        // Handle the received message, emit event with all information for subgraph to index
        bytes32 messageId = message.messageId; // fetch the messageId
        uint64 sourceChainSelector = message.sourceChainSelector; // fetch the source chain selector
        address sender = abi.decode(message.sender, (address)); // abi-decoding of the CCIPSender address

        // Decode the new message format: (sourceToken, destToken, amount, receiver)
        (
            address sourceToken,
            address destToken,
            uint256 amount,
            address receiver
        ) = abi.decode(message.data, (address, address, uint256, address));

        // Validate the sender is allowlisted
        if (
            _allowlistedChains[sourceChainSelector].destinationChainReceiver !=
            sender
        ) {
            revert CCIPMessagingErrors.InvalidSender(sender);
        }

        // Verify the token mapping is correct (source token from sender chain should map to destToken here)
        address expectedSourceToken = _tokenMappings[destToken][
            sourceChainSelector
        ].destinationToken;
        if (expectedSourceToken != sourceToken) {
            revert CCIPMessagingErrors.TokenNotMapped(
                destToken,
                sourceChainSelector
            );
        }

        // Mint the destination token to the receiver
        IMintableBurnableERC20(destToken).mint(receiver, amount);

        // Update bridged amount tracking (inbound is positive)
        _chainBridgedAmount[destToken][sourceChainSelector] += int256(amount);
        _totalBridgedAmount[destToken] += int256(amount);

        // Emit an event with the message details
        emit TokensReceived(
            messageId,
            sourceChainSelector,
            sender,
            receiver,
            destToken,
            amount
        );
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function getMappedToken(
        address sourceToken,
        uint64 chainSelector
    ) external view returns (address) {
        return _tokenMappings[sourceToken][chainSelector].destinationToken;
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function isTokenMapped(
        address sourceToken,
        uint64 chainSelector
    ) external view returns (bool) {
        return
            _tokenMappings[sourceToken][chainSelector].destinationToken !=
            address(0);
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function getMaxChainAmount(
        address token,
        uint64 chainSelector
    ) external view returns (uint256) {
        return _chainMaxAmount[token][chainSelector];
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function getTotalBridgedAmount(
        address token
    ) external view returns (int256) {
        return _totalBridgedAmount[token];
    }

    /// @inheritdoc ICCIPSenderReceiverMessaging
    function getChainBridgedAmount(
        address token,
        uint64 chainSelector
    ) external view returns (int256) {
        return _chainBridgedAmount[token][chainSelector];
    }
}
