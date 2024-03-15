// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IREG} from "../interfaces/IREG.sol";
import {RegErrors} from "../libraries/RegErrors.sol";

contract RealTokenEcosystemGovernance is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable,
    IREG
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

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
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("RealToken Ecosystem Governance");
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // function _update(
    //     address from,
    //     address to,
    //     uint256 value
    // ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
    //     super._update(from, to, value);
    // }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(
        address account,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) returns (bool) {
        _mint(account, amount);
        return true;
    }

    function batchMint(
        address[] calldata accounts,
        uint256[] calldata amounts
    ) external override onlyRole(MINTER_ROLE) returns (bool) {
        uint256 length = accounts.length;
        if (length == 0) revert RegErrors.InvalidLength(length);

        if (amounts.length != length)
            revert RegErrors.LengthNotMatch(length, amounts.length);

        for (uint256 i = 0; i < length; ) {
            _mint(accounts[i], amounts[i]);
            unchecked {
                ++i;
            }
        }

        return true;
    }

    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external override returns (bool) {
        uint256 length = recipients.length;
        if (length == 0) {
            revert RegErrors.InvalidLength(length);
        }
        if (amounts.length != length) {
            revert RegErrors.LengthNotMatch(length, amounts.length);
        }

        for (uint256 i = 0; i < length; ) {
            _transfer(msg.sender, recipients[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
        return true;
    }

    function contractBurn(
        uint256 amount
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        _burn(address(this), amount);
        return true;
    }

    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        IERC20Upgradeable(tokenAddress).safeTransfer(_msgSender(), tokenAmount);
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
