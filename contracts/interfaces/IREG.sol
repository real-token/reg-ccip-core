//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Interface of the Real Estate Governance Token
 * @author @RealT
 * @notice Real Estate Governance Token
 */
interface IREG {
    /**
     * @dev Emitted on mint
     * @param account The account address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    event MintByBridge(address indexed account, uint256 indexed amount);

    /**
     * @dev Emitted on burn
     * @param account The account address from which the tokens will be burned
     * @param amount The amount of tokens to burn
     */
    event BurnByBridge(address indexed account, uint256 indexed amount);

    /**
     * @dev Emitted on mintByGovernance
     * @param account The account address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    event MintByGovernance(address indexed account, uint256 indexed amount);

    /**
     * @dev Emitted on burnByGovernance
     * @param account The account address from which the tokens will be burned
     * @param amount The amount of tokens to burn
     */
    event BurnByGovernance(address indexed account, uint256 indexed amount);

    /**
     * @dev Emitted on recoverERC20
     * @param token The token address that will be recovered
     * @param amount The amount of token to be recovered
     */
    event RecoverByGovernance(address indexed token, uint256 indexed amount);

    /**
     * @notice Mint function for CCIP, only callable by MINTER_BRIDGE_ROLE
     * @dev Mint function
     * - require {MINTER_BRIDGE_ROLE}
     * @param account address - account that will receive created funds
     * @param amount amount to be minted
     * @return Return true on success
     */
    function mint(address account, uint256 amount) external returns (bool);

    /**
     * @notice Burn function for CCIP, only callable by MINTER_BRIDGE_ROLE
     * @dev Burn function
     * - require {MINTER_BRIDGE_ROLE}
     * @param amount amount that will be burned on CCIP TokenPool
     * @return Return true on success
     */
    function burn(uint256 amount) external returns (bool);

    /**
     * @notice Mint function only MINTER_GOVERNANCE_ROLE
     * @dev Mint function
     * - require {MINTER_GOVERNANCE_ROLE}
     * @param account address - account that will receive created funds
     * @param amount amount to be minted
     * @return Return true on success
     */
    function mintByGovernance(
        address account,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice Mint to multiple accounts in the same transaction
     * @dev Mint function
     * - require {MINTER_GOVERNANCE_ROLE}
     * @param accounts The addresses of accounts that will receive the tokens
     * @param amounts The amounts of tokens that will be minted to the accounts
     * @return Return true on success
     */
    function mintBatchByGovernance(
        address[] calldata accounts,
        uint256[] calldata amounts
    ) external returns (bool);

    /**
     * @notice Burn tokens that are stored on the contract
     * @dev Burn function
     * - require {DEFAULT_ADMIN_ROLE}
     * @param amount amount that will be burned on the contract
     * @return Return true on success
     */
    function burnByGovernance(uint256 amount) external returns (bool);

    /**
     * @notice transfer token in batch to multiple recipients
     * @param recipients The addresses of recipients that will receive the tokens
     * @param amounts The amounts of tokens that will be transferred to the recipients
     * @return Return true on success
     */
    function transferBatch(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external returns (bool);

    /**
     * @notice RecoverERC20, Transfer any ERC20 stored on the contract to a wallet, prevent mistakes
     * @dev recoverERC20 function
     * - require {DEFAULT_ADMIN_ROLE}
     * @param tokenAddress address - token address to transfer
     * @param tokenAmount token amount to be transfered
     * @return Return true on success
     */
    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount
    ) external returns (bool);
}
