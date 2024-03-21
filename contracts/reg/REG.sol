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
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MINTER_GOVERNANCE_ROLE =
        keccak256("MINTER_GOVERNANCE_ROLE");
    bytes32 public constant MINTER_BRIDGE_ROLE =
        keccak256("MINTER_BRIDGE_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

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

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "ERC20Pausable: token transfer while paused");
    }
}
