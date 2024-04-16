// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {IERC165} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/utils/introspection/IERC165.sol";
import {CCIPErrors} from "../libraries/CCIPErrors.sol";
import {ICCIPSenderReceiver} from "../interfaces/ICCIPSenderReceiver.sol";
import {IERC20WithPermit} from "../interfaces/IERC20WithPermit.sol";

/**
 * @title CCIPSenderReceiver
 * @author RealT, version of RealT CCIP Sender based on Chainlink CCIP
 * @notice The contract of REG CCIP Sender for cross-chain token transfers
 */
contract CCIPSenderReceiver is
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ICCIPSenderReceiver,
    IAny2EVMMessageReceiver
{
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE =
        0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a; // = keccak256("PAUSER_ROLE")

    bytes32 public constant UPGRADER_ROLE =
        0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3; // = keccak256("UPGRADER_ROLE")

    IRouterClient private _router;

    address private constant _linkToken =
        0x514910771AF9Ca656af840dff83E8264EcF986CA; // LINK on Ethereum

    address private constant _wrappedNativeToken =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on Ethereum

    // Mapping to keep track of allowlisted destination chains
    mapping(uint64 => AllowlistChainState) private _allowlistedChains;

    mapping(address => AllowlistTokenState) private _allowlistedTokens;

    uint64[] private _allowlistedChainsList;

    address[] private _allowlistedTokensList;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param defaultAdmin The address of the default admin
    /// @param pauser The address of the pauser
    /// @param upgrader The address of the upgrader
    /// @param router The address of the router contract
    function initialize(
        address defaultAdmin,
        address pauser,
        address upgrader,
        address router
    ) external initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(UPGRADER_ROLE, upgrader);

        _router = IRouterClient(router);
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
     * @notice Receive function to allow the contract to receive Ether
     * @dev This function has no function body, making it a default function for receiving Ether
     * It is automatically called when Ether is transferred to the contract without any data
     */
    receive() external payable {}

    /**
     * @dev Pause the contract if needed
     **/
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract if needed
     **/
    function unpause() external onlyRole(PAUSER_ROLE) {
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
            revert CCIPErrors.DestinationChainNotAllowlisted(
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
            revert CCIPErrors.TokenNotAllowlisted(token);
        _;
    }

    /**
     * @dev Modifier that checks a contract address
     * @param contractAddress The contract address
     */
    modifier validateContractAddress(address contractAddress) {
        if (!AddressUpgradeable.isContract(contractAddress))
            revert CCIPErrors.InvalidContractAddress();
        _;
    }

    /**
     * @dev Modifier that checks the receiver address is not 0
     * @param receiver The receiver address
     */
    modifier validateReceiver(address receiver) {
        if (receiver == address(0)) revert CCIPErrors.InvalidReceiverAddress();
        _;
    }

    /// @dev only calls from the set router are accepted.
    modifier onlyRouter() {
        if (msg.sender != address(_router))
            revert CCIPErrors.InvalidRouter(msg.sender);
        _;
    }

    /// @inheritdoc ICCIPSenderReceiver
    function allowlistDestinationChain(
        uint64 destinationChainSelector,
        address destinationChainReceiver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AllowlistChainState storage chainState = _allowlistedChains[
            destinationChainSelector
        ];

        if (chainState.destinationChainReceiver == destinationChainReceiver) {
            revert CCIPErrors.AllowedStateNotChange();
        }

        chainState.destinationChainReceiver = destinationChainReceiver;

        if (destinationChainReceiver != address(0) && !chainState.isInList) {
            _allowlistedChainsList.push(destinationChainSelector);
            chainState.isInList = true;
        }

        emit AllowlistDestinationChain(
            destinationChainSelector,
            destinationChainReceiver
        );
    }

    /// @inheritdoc ICCIPSenderReceiver
    function allowlistToken(
        address token,
        bool allowed
    ) external validateContractAddress(token) onlyRole(DEFAULT_ADMIN_ROLE) {
        AllowlistTokenState storage tokenState = _allowlistedTokens[token];

        if (tokenState.isAllowed == allowed) {
            revert CCIPErrors.AllowedStateNotChange();
        }

        tokenState.isAllowed = allowed;

        if (allowed && !tokenState.isInList) {
            _allowlistedTokensList.push(token);
            tokenState.isInList = true;
        }
        emit AllowlistToken(token, allowed);
    }

    /// @inheritdoc ICCIPSenderReceiver
    function setRouter(
        address router
    )
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        validateContractAddress(router)
    {
        _router = IRouterClient(router);
        emit SetRouter(router);
    }

    /// @inheritdoc ICCIPSenderReceiver
    function withdraw(
        address beneficiary
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Retrieve the balance of this contract
        uint256 amount = address(this).balance;

        // Revert if there is nothing to withdraw
        if (amount == 0) revert CCIPErrors.NothingToWithdraw();

        // Attempt to send the funds, capturing the success status and discarding any return data
        // This is considered safe because the beneficiary is chosen by admin
        (bool sent, bytes memory data) = beneficiary.call{value: amount}("");

        // Revert if the send failed, with information about the attempted transfer
        if (!sent)
            revert CCIPErrors.FailedToWithdrawEth(
                msg.sender,
                beneficiary,
                amount,
                data
            );
    }

    /// @inheritdoc ICCIPSenderReceiver
    function withdrawToken(
        address beneficiary,
        address token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert CCIPErrors.NothingToWithdraw();

        IERC20(token).safeTransfer(beneficiary, amount);
    }

    /// @inheritdoc ICCIPSenderReceiver
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

    /// @inheritdoc ICCIPSenderReceiver
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

    /// @inheritdoc ICCIPSenderReceiver
    function getRouter() external view override returns (address) {
        return address(_router);
    }

    /// @inheritdoc ICCIPSenderReceiver
    function getLinkToken() external pure override returns (address) {
        return _linkToken;
    }

    /// @inheritdoc ICCIPSenderReceiver
    function getWrappedNativeToken() external pure override returns (address) {
        return _wrappedNativeToken;
    }

    /// @inheritdoc ICCIPSenderReceiver
    function getAllowlistedDestinationChains()
        external
        view
        override
        returns (uint64[] memory)
    {
        return _allowlistedChainsList;
    }

    /// @inheritdoc ICCIPSenderReceiver
    function getAllowlistedTokens()
        external
        view
        override
        returns (address[] memory)
    {
        return _allowlistedTokensList;
    }

    /// @inheritdoc ICCIPSenderReceiver
    function isAllowlistedDestinationChain(
        uint64 destinationChainSelector
    ) external view override returns (bool) {
        return
            _allowlistedChains[destinationChainSelector]
                .destinationChainReceiver != address(0);
    }

    /// @inheritdoc ICCIPSenderReceiver
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
            revert CCIPErrors.InvalidFeeToken(feeToken);
        }
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        //  address(linkToken) means fees are paid in LINK

        address ccipReceiver = _allowlistedChains[destinationChainSelector]
            .destinationChainReceiver;
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            receiver, // final receiver to receive the token
            token, // token address
            amount, // amount of token
            feeToken, // token for CCIP fees (LINK or native gas)
            ccipReceiver, // CCIPReceiver on destination chain,
            gasLimit // gasLimit, adjust this value as needed
        );

        // Get the fee required to send the message
        uint256 fees = _router.getFee(destinationChainSelector, evm2AnyMessage);

        // Transfer REG token from the user to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
        IERC20(token).safeIncreaseAllowance(address(_router), amount);

        if (feeToken == address(0)) {
            // Check if msg.value is enough to pay for the fees
            if (fees > msg.value)
                revert CCIPErrors.NotEnoughBalance(msg.value, fees);

            // Send the message through the router and store the returned message ID
            // Safe to interact with Chainlink Router as it is a trusted contract
            messageId = _router.ccipSend{value: fees}(
                destinationChainSelector,
                evm2AnyMessage
            );
        } else {
            IERC20 feeTokenInstance = IERC20(feeToken);
            // Transfer LINK token from the user to this contract
            // If user does not have enough feeToken, the safeTransferFrom will fail first
            feeTokenInstance.safeTransferFrom(msg.sender, address(this), fees);

            // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
            feeTokenInstance.safeIncreaseAllowance(address(_router), fees);

            // Send the message through the router and store the returned message ID
            messageId = _router.ccipSend(
                destinationChainSelector,
                evm2AnyMessage
            );
        }

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

        // Return the message ID
        return messageId;
    }

    /**
     * @notice Construct a CCIP message
     * @dev This function will create an EVM2AnyMessage struct with all the necessary information for tokens transfer
     * @param receiver The address of the receiver
     * @param token The token to be transferred
     * @param amount The amount of the token to be transferred
     * @param feeTokenAddress The address of the token used for fees. Set address(0) for native gas
     * @param ccipReceiver The address of the CCIPSenderReceiver on the destination chain
     * @param gasLimit The gas limit for the ccipReceive function call on the destination chain
     * @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message
     */
    function _buildCCIPMessage(
        address receiver,
        address token,
        uint256 amount,
        address feeTokenAddress,
        address ccipReceiver,
        uint256 gasLimit
    ) private pure returns (Client.EVM2AnyMessage memory) {
        // Set the token amounts
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});
        bytes memory data = abi.encode(receiver);

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(ccipReceiver), // ABI-encoded receiver address
                data: data, // No data
                tokenAmounts: tokenAmounts, // The amount and type of token being transferred
                extraArgs: Client._argsToBytes(
                    // Setting gas limit for action on destination chain
                    Client.EVMExtraArgsV1({gasLimit: gasLimit})
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: feeTokenAddress
            });
    }

    /// @inheritdoc ICCIPSenderReceiver
    function getCcipFeesEstimation(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        address feeToken,
        uint256 gasLimit
    ) external view returns (uint256) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        // address(0) means fees are paid in native gas
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            receiver,
            token,
            amount,
            feeToken,
            _allowlistedChains[destinationChainSelector]
                .destinationChainReceiver,
            gasLimit
        );

        // Get the fee required to send the message
        uint256 fees = _router.getFee(destinationChainSelector, evm2AnyMessage);

        // Return fees in feeToken
        return fees;
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
        // TokenPool minted to receiver (CCIPSenderReceiverReceiver), then need to transfer to user address from data in message
        bytes32 messageId = message.messageId; // fetch the messageId
        uint64 sourceChainSelector = message.sourceChainSelector; // fetch the source chain selector
        address sender = abi.decode(message.sender, (address)); // abi-decoding of the CCIPSender address

        if (
            _allowlistedChains[sourceChainSelector].destinationChainReceiver !=
            sender
        ) {
            revert CCIPErrors.InvalidSender(sender);
        }

        address receiver = abi.decode(message.data, (address)); // abi-decoding of the receiver's address

        // Collect tokens transferred. This increases this contract's balance for that Token.
        Client.EVMTokenAmount[] memory tokenAmounts = message.destTokenAmounts;

        address token = tokenAmounts[0].token;
        uint256 amount = tokenAmounts[0].amount;

        // Transfer the token to the receiver
        IERC20(token).safeTransfer(receiver, amount);

        // Emit an event with the message details
        emit TokensReceived(
            messageId,
            sourceChainSelector,
            sender,
            receiver,
            token,
            amount
        );
    }
}
