// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IREG} from "../interfaces/IREG.sol";
import {REGErrors} from "../libraries/REGErrors.sol";

/**
 * @title REG
 * @author RealT
 * @notice The contract of Real Estate Governance Token
 */
contract REG is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable,
    IREG
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant PAUSER_ROLE =
        0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a; // = keccak256("PAUSER_ROLE")
    bytes32 public constant UPGRADER_ROLE =
        0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3; // = keccak256("UPGRADER_ROLE")
    bytes32 public constant MINTER_GOVERNANCE_ROLE =
        0x54fd3c12c8b3fc99211f3f953b8d8233c4cdca02cfeedbead260add43c0f1bd5; // = keccak256("MINTER_GOVERNANCE_ROLE")
    bytes32 public constant MINTER_BRIDGE_ROLE =
        0x0dc18c621ac7c12ef6a5f7771b48b18abf4dd7238e67a277b031c58b2c7b7c09; // = keccak256("MINTER_BRIDGE_ROLE")

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract
     * @param defaultAdmin The address of the default admin
     * @param pauser The address of the pauser
     * @param minter The address of the minter
     * @param upgrader The address of the upgrader
     */
    function initialize(
        address defaultAdmin,
        address pauser,
        address minter,
        address upgrader
    ) external initializer {
        __ERC20_init("RealToken Ecosystem Governance", "REG");
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("RealToken Ecosystem Governance");
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_GOVERNANCE_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
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
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @inheritdoc IREG
    function mint(
        address account,
        uint256 amount
    ) external onlyRole(MINTER_BRIDGE_ROLE) returns (bool) {
        _mint(account, amount);
        emit MintByBridge(account, amount);
        return true;
    }

    /// @inheritdoc IREG
    function burn(
        uint256 amount
    ) external override onlyRole(MINTER_BRIDGE_ROLE) returns (bool) {
        _burn(_msgSender(), amount);
        emit BurnByBridge(_msgSender(), amount);
        return true;
    }

    /// @inheritdoc IREG
    function mintByGovernance(
        address account,
        uint256 amount
    ) external override onlyRole(MINTER_GOVERNANCE_ROLE) returns (bool) {
        _mint(account, amount);
        emit MintByGovernance(account, amount);
        return true;
    }

    /// @inheritdoc IREG
    function mintBatchByGovernance(
        address[] calldata accounts,
        uint256[] calldata amounts
    ) external override onlyRole(MINTER_GOVERNANCE_ROLE) returns (bool) {
        uint256 length = accounts.length;
        if (length == 0) revert REGErrors.InvalidLength(length);

        if (amounts.length != length)
            revert REGErrors.LengthNotMatch(length, amounts.length);

        for (uint256 i = 0; i < length; ) {
            _mint(accounts[i], amounts[i]);
            emit MintByGovernance(accounts[i], amounts[i]);
            unchecked {
                ++i;
            }
        }

        return true;
    }

    /// @inheritdoc IREG
    function burnByGovernance(
        uint256 amount
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        _burn(address(this), amount);
        emit BurnByGovernance(address(this), amount);
        return true;
    }

    /// @inheritdoc IREG
    function transferBatch(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external override returns (bool) {
        uint256 length = recipients.length;
        if (length == 0) {
            revert REGErrors.InvalidLength(length);
        }
        if (amounts.length != length) {
            revert REGErrors.LengthNotMatch(length, amounts.length);
        }

        for (uint256 i = 0; i < length; ) {
            _transfer(msg.sender, recipients[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
        return true;
    }

    /// @inheritdoc IREG
    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        IERC20Upgradeable(tokenAddress).safeTransfer(_msgSender(), tokenAmount);
        emit RecoverByGovernance(tokenAddress, tokenAmount);
        return true;
    }

    /**
     * @dev Check if the contract is paused before transfer/mint/burn
     **/
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "ERC20Pausable: token transfer while paused");
    }
}
