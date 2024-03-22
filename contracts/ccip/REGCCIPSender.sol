// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";
import {REGCCIPErrors} from "../libraries/REGCCIPErrors.sol";
import {IREGCCIPSender} from "../interfaces/IREGCCIPSender.sol";
import {IERC20WithPermit} from "../interfaces/IERC20WithPermit.sol";

/**
 * @title REGCCIPSender
 * @author RealT, version of RealT CCIP Sender based on Chainlink CCIP
 * @notice The contract of REG CCIP Sender for cross-chain token transfers
 */
contract REGCCIPSender is
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IREGCCIPSender
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    IRouterClient private _router;

    IERC20 private _linkToken;

    // Mapping to keep track of allowlisted destination chains
    mapping(uint64 => AllowlistState) private _allowlistedChains;

    mapping(address => AllowlistState) private _allowlistedTokens;

    uint64[] private _allowlistedChainsList;

    address[] private _allowlistedTokensList;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param defaultAdmin The address of the default admin
    /// @param upgrader The address of the upgrader
    /// @param router The address of the router contract
    /// @param linkToken The address of the LINK Token contract
    function initialize(
        address defaultAdmin,
        address upgrader,
        address router,
        address linkToken
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, upgrader);

        _router = IRouterClient(router);
        _linkToken = IERC20(linkToken);
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
     * @dev Modifier that checks if the chain with the given destinationChainSelector is allowlisted
     * @param destinationChainSelector The selector of the destination chain
     */
    modifier onlyAllowlistedChain(uint64 destinationChainSelector) {
        if (!_allowlistedChains[destinationChainSelector].isAllowed)
            revert REGCCIPErrors.DestinationChainNotAllowlisted(
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
            revert REGCCIPErrors.TokenNotAllowlisted(token);
        _;
    }

    /**
     * @dev Modifier that checks a contract address
     * @param contractAddress The contract address
     */
    modifier validateContractAddress(address contractAddress) {
        if (!AddressUpgradeable.isContract(contractAddress))
            revert REGCCIPErrors.InvalidContractAddress();
        _;
    }

    /**
     * @dev Modifier that checks the receiver address is not 0
     * @param receiver The receiver address
     */
    modifier validateReceiver(address receiver) {
        if (receiver == address(0))
            revert REGCCIPErrors.InvalidReceiverAddress();
        _;
    }

    /// @inheritdoc IREGCCIPSender
    function allowlistDestinationChain(
        uint64 destinationChainSelector,
        bool allowed
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AllowlistState storage chainState = _allowlistedChains[
            destinationChainSelector
        ];

        if (chainState.isAllowed == allowed) {
            revert REGCCIPErrors.AllowedStateNotChange();
        }

        chainState.isAllowed = allowed;

        if (allowed && !chainState.isInList) {
            _allowlistedChainsList.push(destinationChainSelector);
            chainState.isInList = true;
        }

        emit AllowlistDestinationChain(destinationChainSelector, allowed);
    }

    /// @inheritdoc IREGCCIPSender
    function allowlistToken(
        address token,
        bool allowed
    ) external validateContractAddress(token) onlyRole(DEFAULT_ADMIN_ROLE) {
        AllowlistState storage tokenState = _allowlistedTokens[token];

        if (tokenState.isAllowed == allowed) {
            revert REGCCIPErrors.AllowedStateNotChange();
        }

        tokenState.isAllowed = allowed;

        if (allowed && !tokenState.isInList) {
            _allowlistedTokensList.push(token);
            tokenState.isInList = true;
        }
        emit AllowlistToken(token, allowed);
    }

    /// @inheritdoc IREGCCIPSender
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

    /// @inheritdoc IREGCCIPSender
    function setLinkToken(
        address linkToken
    )
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        validateContractAddress(linkToken)
    {
        _linkToken = IERC20(linkToken);
        emit SetLinkToken(linkToken);
    }

    /// @inheritdoc IREGCCIPSender
    function withdraw(address beneficiary) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // Retrieve the balance of this contract
        uint256 amount = address(this).balance;

        // Revert if there is nothing to withdraw
        if (amount == 0) revert REGCCIPErrors.NothingToWithdraw();

        // Attempt to send the funds, capturing the success status and discarding any return data
        (bool sent, ) = beneficiary.call{value: amount}("");

        // Revert if the send failed, with information about the attempted transfer
        if (!sent)
            revert REGCCIPErrors.FailedToWithdrawEth(
                msg.sender,
                beneficiary,
                amount
            );
    }

    /// @inheritdoc IREGCCIPSender
    function withdrawToken(
        address beneficiary,
        address token
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert REGCCIPErrors.NothingToWithdraw();

        IERC20(token).transfer(beneficiary, amount);
    }

    /// @inheritdoc IREGCCIPSender
    function transferTokensPayLINK(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    ) external override returns (bytes32 messageId) {
        return
            _transferTokensPayLINK(
                destinationChainSelector,
                receiver,
                token,
                amount
            );
    }

    /// @inheritdoc IREGCCIPSender
    function transferTokensPayLINKWithPermit(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override returns (bytes32 messageId) {
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
            _transferTokensPayLINK(
                destinationChainSelector,
                receiver,
                token,
                amount
            );
    }

    /// @inheritdoc IREGCCIPSender
    function transferTokensPayNative(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    ) external payable override returns (bytes32 messageId) {
        return
            _transferTokensPayNative(
                destinationChainSelector,
                receiver,
                token,
                amount
            );
    }

    /// @inheritdoc IREGCCIPSender
    function transferTokensPayNativeWithPermit(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
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
            _transferTokensPayNative(
                destinationChainSelector,
                receiver,
                token,
                amount
            );
    }

    /// @inheritdoc IREGCCIPSender
    function getRouter() external view override returns (address) {
        return address(_router);
    }

    /// @inheritdoc IREGCCIPSender
    function getLinkToken() external view override returns (address) {
        return address(_linkToken);
    }

    /// @inheritdoc IREGCCIPSender
    function getAllowlistedDestinationChains()
        external
        view
        override
        returns (uint64[] memory)
    {
        return _allowlistedChainsList;
    }

    /// @inheritdoc IREGCCIPSender
    function getAllowlistedTokens()
        external
        view
        override
        returns (address[] memory)
    {
        return _allowlistedTokensList;
    }

    /// @inheritdoc IREGCCIPSender
    function isAllowlistedDestinationChain(
        uint64 destinationChainSelector
    ) external view override returns (bool) {
        return _allowlistedChains[destinationChainSelector].isAllowed;
    }

    /// @inheritdoc IREGCCIPSender
    function isAllowlistedToken(
        address token
    ) external view override returns (bool) {
        return _allowlistedTokens[token].isAllowed;
    }

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
    function _transferTokensPayLINK(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    )
        private
        onlyAllowlistedToken(token)
        onlyAllowlistedChain(destinationChainSelector)
        validateReceiver(receiver)
        returns (bytes32 messageId)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        //  address(linkToken) means fees are paid in LINK
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            receiver,
            token,
            amount,
            address(_linkToken)
        );

        // Get the fee required to send the message
        uint256 fees = _router.getFee(destinationChainSelector, evm2AnyMessage);

        if (fees > _linkToken.balanceOf(address(this)))
            revert REGCCIPErrors.NotEnoughBalance(
                _linkToken.balanceOf(address(this)),
                fees
            );

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        _linkToken.approve(address(_router), fees);

        // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
        IERC20(token).approve(address(_router), amount);

        // Transfer LINK token and REG token from the user to this contract
        _linkToken.transferFrom(msg.sender, address(this), fees);
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Send the message through the router and store the returned message ID
        messageId = _router.ccipSend(destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit TokensTransferred(
            messageId,
            destinationChainSelector,
            receiver,
            token,
            amount,
            address(_linkToken),
            fees
        );

        // Return the message ID
        return messageId;
    }

    /**
     * @notice Transfer tokens to receiver on the destination chain
     * @notice Pay in native gas such as ETH on Ethereum or MATIC on Polgon
     * @notice the token must be in the list of supported tokens
     * @notice This function can only be called by the owner
     * @dev Assumes your contract has sufficient native gas like ETH on Ethereum or MATIC on Polygon
     * @param destinationChainSelector The identifier (aka selector) for the destination blockchain
     * @param receiver The address of the recipient on the destination blockchain
     * @param token token address
     * @param amount token amount
     * @return messageId The ID of the message that was sent
     */
    function _transferTokensPayNative(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    )
        private
        onlyAllowlistedToken(token)
        onlyAllowlistedChain(destinationChainSelector)
        validateReceiver(receiver)
        returns (bytes32 messageId)
    {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        // address(0) means fees are paid in native gas
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            receiver,
            token,
            amount,
            address(0)
        );

        // Get the fee required to send the message
        uint256 fees = _router.getFee(destinationChainSelector, evm2AnyMessage);

        if (fees > address(this).balance)
            revert REGCCIPErrors.NotEnoughBalance(address(this).balance, fees);

        // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
        IERC20(token).approve(address(_router), amount);

        // Transfer REG token from the user to this contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Send the message through the router and store the returned message ID
        messageId = _router.ccipSend{value: fees}(
            destinationChainSelector,
            evm2AnyMessage
        );

        // Emit an event with message details
        emit TokensTransferred(
            messageId,
            destinationChainSelector,
            receiver,
            token,
            amount,
            address(0),
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
     * @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message
     */
    function _buildCCIPMessage(
        address receiver,
        address token,
        uint256 amount,
        address feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        // Set the token amounts
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(receiver), // ABI-encoded receiver address
                data: "", // No data
                tokenAmounts: tokenAmounts, // The amount and type of token being transferred
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit to 0 as we are not sending any data
                    Client.EVMExtraArgsV1({gasLimit: 0})
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: feeTokenAddress
            });
    }

    /// @inheritdoc IREGCCIPSender
    function getEstimatedCCIPFeesInLink(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    ) external view override returns (uint256) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        //  address(linkToken) means fees are paid in LINK
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            receiver,
            token,
            amount,
            address(_linkToken)
        );

        // Get the fee required to send the message
        uint256 fees = _router.getFee(destinationChainSelector, evm2AnyMessage);

        return fees;
    }

    /// @inheritdoc IREGCCIPSender
    function getEstimatedCCIPFeesInNative(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    ) external view override returns (uint256) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        // address(0) means fees are paid in native gas
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            receiver,
            token,
            amount,
            address(0)
        );

        // Get the fee required to send the message
        uint256 fees = _router.getFee(destinationChainSelector, evm2AnyMessage);

        return fees;
    }
}
