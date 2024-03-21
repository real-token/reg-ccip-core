//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Interface of the Real Estate Governance Token
 * @author @RealToken
 * @notice REG DAO utility token
 */
interface IREG {
    event MintByBridge(address indexed account, uint256 indexed amount);
    event BurnByBridge(address indexed account, uint256 indexed amount);
    event MintByGovernance(address indexed account, uint256 indexed amount);
    event BurnByGovernance(address indexed account, uint256 indexed amount);
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

    /// @notice RecoverERC20, Transfer any ERC20 stored on the contract to a wallet, prevent mistakes
    /// @dev recoverERC20 function
    /// - require {DEFAULT_ADMIN_ROLE}
    /// @param tokenAddress address - token address to transfer
    /// @param tokenAmount token amount to be transfered
    /// @return return true on success
    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount
    ) external returns (bool);
}
