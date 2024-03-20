// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";
import {REGCCIPErrors} from "../libraries/REGCCIPErrors.sol";
import {IREGCCIPSender} from "../interfaces/IREGCCIPSender.sol";

contract REGCCIPSender is
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IREGCCIPSender
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Mapping to keep track of allowlisted destination chains.
    mapping(uint64 => bool) public allowlistedChains;

    IRouterClient private _router;

    IERC20 private _linkToken;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Constructor initializes the contract with the router address.
    /// @param defaultAdmin The address of the default admin.
    /// @param upgrader The address of the upgrader.
    /// @param router The address of the router contract.
    /// @param link The address of the link contract.
    function initialize(
        address defaultAdmin,
        address upgrader,
        address router,
        address link
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, upgrader);

        _router = IRouterClient(router);
        _linkToken = IERC20(link);
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

    /// @dev Modifier that checks if the chain with the given destinationChainSelector is allowlisted.
    /// @param destinationChainSelector The selector of the destination chain.
    modifier onlyAllowlistedChain(uint64 destinationChainSelector) {
        if (!allowlistedChains[destinationChainSelector])
            revert REGCCIPErrors.DestinationChainNotAllowlisted(
                destinationChainSelector
            );
        _;
    }

    /// @dev Modifier that checks the receiver address is not 0.
    /// @param receiver The receiver address.
    modifier validateReceiver(address receiver) {
        if (receiver == address(0))
            revert REGCCIPErrors.InvalidReceiverAddress();
        _;
    }

    /// @dev Updates the allowlist status of a destination chain for transactions.
    /// @notice This function can only be called by the owner.
    /// @param destinationChainSelector The selector of the destination chain to be updated.
    /// @param allowed The allowlist status to be set for the destination chain.
    function allowlistDestinationChain(
        uint64 destinationChainSelector,
        bool allowed
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allowlistedChains[destinationChainSelector] = allowed;
    }

    /// @notice Transfer tokens to receiver on the destination chain.
    /// @notice pay in LINK.
    /// @notice the token must be in the list of supported tokens.
    /// @notice This function can only be called by the owner.
    /// @dev Assumes your contract has sufficient LINK tokens to pay for the fees.
    /// @param destinationChainSelector The identifier (aka selector) for the destination blockchain.
    /// @param receiver The address of the recipient on the destination blockchain.
    /// @param token token address.
    /// @param amount token amount.
    /// @return messageId The ID of the message that was sent.
    function transferTokensPayLINK(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
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

    /// @notice Transfer tokens to receiver on the destination chain.
    /// @notice Pay in native gas such as ETH on Ethereum or MATIC on Polgon.
    /// @notice the token must be in the list of supported tokens.
    /// @notice This function can only be called by the owner.
    /// @dev Assumes your contract has sufficient native gas like ETH on Ethereum or MATIC on Polygon.
    /// @param destinationChainSelector The identifier (aka selector) for the destination blockchain.
    /// @param receiver The address of the recipient on the destination blockchain.
    /// @param token token address.
    /// @param amount token amount.
    /// @return messageId The ID of the message that was sent.
    function transferTokensPayNative(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
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

    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for tokens transfer.
    /// @param receiver The address of the receiver.
    /// @param token The token to be transferred.
    /// @param amount The amount of the token to be transferred.
    /// @param feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
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

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is transferred to the contract without any data.
    receive() external payable {}

    /// @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
    /// @dev This function reverts if there are no funds to withdraw or if the transfer fails.
    /// It should only be callable by the owner of the contract.
    /// @param beneficiary The address to which the Ether should be transferred.
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

    /// @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token.
    /// @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw.
    /// @param beneficiary The address to which the tokens will be sent.
    /// @param token The contract address of the ERC20 token to be withdrawn.
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
}
