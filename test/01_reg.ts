import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import {
  ethers,
  upgrades,
  deployments,
  getNamedAccounts,
  getUnnamedAccounts,
} from "hardhat";
import { setupUsers, setupUser } from "./utils";
import {
  DEFAULT_ADMIN_ROLE,
  UPGRADER_ROLE,
  PAUSER_ROLE,
  MINTER_GOVERNANCE_ROLE,
  MINTER_BRIDGE_ROLE,
  ZERO_ADDRESS,
} from "../helpers/constants";
import { REGErrors } from "../helpers/types";

async function setup() {
  // it first ensure the deployment is executed and reset (use of evm_snaphost for fast test)
  await deployments.fixture(["REG"]);

  // we get an instantiated contract in the form of a ethers.js Contract instance:
  const REG = await deployments.get("REG");
  const contracts = {
    reg: await ethers.getContractAt("REG", REG.address),
  };

  // Get the named and unnamed accounts
  const { deployer, admin, bridge } = await getNamedAccounts();
  const users = await setupUsers(await getUnnamedAccounts(), contracts);

  return {
    ...contracts,
    users,
    deployer: await setupUser(deployer, contracts),
    admin: await setupUser(admin, contracts),
    bridge: await setupUser(bridge, contracts),
  };
}
describe("REG", function () {
  describe("Deployment", function () {
    it("1. Should set the right roles", async function () {
      // const { reg, deployer } = await loadFixture(deployREGFixture);
      const { reg, deployer, bridge } = await setup();

      expect(await reg.hasRole(DEFAULT_ADMIN_ROLE, deployer.address)).to.be
        .true;

      expect(await reg.hasRole(UPGRADER_ROLE, deployer.address)).to.be.true;

      expect(await reg.hasRole(PAUSER_ROLE, deployer.address)).to.be.true;

      expect(await reg.hasRole(MINTER_GOVERNANCE_ROLE, deployer.address)).to.be
        .true;

      expect(await reg.hasRole(MINTER_BRIDGE_ROLE, deployer.address)).to.be
        .false;

      expect(await reg.hasRole(MINTER_BRIDGE_ROLE, bridge.address)).to.be.false;

      await expect(
        deployer.reg.initialize(
          deployer.address,
          deployer.address,
          deployer.address,
          deployer.address
        )
      ).to.be.revertedWith("Initializable: contract is already initialized");
    });

    it("2. Admin should be able to pause/unpause", async function () {
      const { reg, deployer, bridge } = await setup();

      await expect(bridge.reg.pause()).to.be.revertedWith(
        `AccessControl: account ${bridge.address
          .toString()
          .toLowerCase()} is missing role ${PAUSER_ROLE}`
      );

      await expect(deployer.reg.pause()).to.emit(reg, "Paused");

      expect(await reg.paused()).to.be.true;

      await expect(bridge.reg.unpause()).to.be.revertedWith(
        `AccessControl: account ${bridge.address
          .toString()
          .toLowerCase()} is missing role ${PAUSER_ROLE}`
      );

      await expect(deployer.reg.unpause()).to.emit(reg, "Unpaused");

      expect(await reg.paused()).to.be.false;
    });

    it("3. Should be able to mint/burn with MINTER_BRIDGE_ROLE", async function () {
      const { reg, deployer, bridge, users } = await setup();

      await expect(deployer.reg.mint(users[0].address, 100)).to.be.revertedWith(
        `AccessControl: account ${deployer.address
          .toString()
          .toLowerCase()} is missing role ${MINTER_BRIDGE_ROLE}`
      );

      await deployer.reg.grantRole(MINTER_BRIDGE_ROLE, bridge.address);

      await expect(bridge.reg.mint(users[0].address, 100))
        .to.emit(reg, "MintByBridge")
        .withArgs(users[0].address, 100);

      expect(await reg.balanceOf(users[0].address)).to.be.equal(100);

      await users[0].reg.transfer(bridge.address, 50);

      expect(await reg.balanceOf(bridge.address)).to.be.equal(50);
      expect(await reg.balanceOf(users[0].address)).to.be.equal(50);

      await expect(deployer.reg.burn(50)).to.be.revertedWith(
        `AccessControl: account ${deployer.address
          .toString()
          .toLowerCase()} is missing role ${MINTER_BRIDGE_ROLE}`
      );

      await expect(bridge.reg.burn(50))
        .to.emit(reg, "BurnByBridge")
        .withArgs(bridge.address, 50);

      expect(await reg.balanceOf(bridge.address)).to.be.equal(0);
    });

    it("4. Should be able to mintByGovernance with MINTER_GOVERNANCE_ROLE", async function () {
      const { reg, deployer, bridge, users } = await setup();
      expect(await reg.balanceOf(users[0].address)).to.be.equal(0);

      await expect(
        bridge.reg.mintByGovernance(users[0].address, 100)
      ).to.be.revertedWith(
        `AccessControl: account ${bridge.address
          .toString()
          .toLowerCase()} is missing role ${MINTER_GOVERNANCE_ROLE}`
      );

      await expect(deployer.reg.mintByGovernance(users[0].address, 100))
        .to.emit(reg, "MintByGovernance")
        .withArgs(users[0].address, 100);

      expect(await reg.balanceOf(users[0].address)).to.be.equal(100);
    });

    it("4. Should be able to mintBatchByGovernance with MINTER_GOVERNANCE_ROLE", async function () {
      const { reg, deployer, bridge, users } = await setup();

      await expect(
        bridge.reg.mintBatchByGovernance(
          [users[1].address, users[2].address],
          [50, 50]
        )
      ).to.be.revertedWith(
        `AccessControl: account ${bridge.address
          .toString()
          .toLowerCase()} is missing role ${MINTER_GOVERNANCE_ROLE}`
      );

      await expect(
        deployer.reg.mintBatchByGovernance([], [50, 50])
      ).to.be.revertedWithCustomError(reg, REGErrors.InvalidLength);

      await expect(
        deployer.reg.mintBatchByGovernance([users[1].address], [50, 50])
      ).to.be.revertedWithCustomError(reg, REGErrors.LengthNotMatch);

      await expect(
        deployer.reg.mintBatchByGovernance(
          [users[1].address, users[2].address],
          [50, 50]
        )
      )
        .to.emit(reg, "MintByGovernance")
        .withArgs(users[1].address, 50);

      expect(await reg.balanceOf(users[1].address)).to.be.equal(50);
      expect(await reg.balanceOf(users[2].address)).to.be.equal(50);
    });

    it("5. Should be able to burnByGovernance with MINTER_GOVERNANCE_ROLE", async function () {
      const { reg, deployer, bridge, users } = await setup();
      // Mint some tokens to user1
      await expect(deployer.reg.mintByGovernance(users[0].address, 100))
        .to.emit(reg, "MintByGovernance")
        .withArgs(users[0].address, 100);

      // User1 accidently sent 100 tokens to the contract
      await users[0].reg.transfer(reg.target, 100);

      expect(await reg.balanceOf(reg.target)).to.be.equal(100);

      await expect(bridge.reg.burnByGovernance(100)).to.be.revertedWith(
        `AccessControl: account ${bridge.address
          .toString()
          .toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE}`
      );

      // Governance should be able to burn the tokens
      await expect(deployer.reg.burnByGovernance(100))
        .to.emit(reg, "BurnByGovernance")
        .withArgs(reg.target, 100);

      expect(await reg.balanceOf(reg.target)).to.be.equal(0);
    });

    it("6. TransferBatch", async function () {
      const { reg, deployer, users } = await setup();
      // Mint some tokens to user1
      await expect(deployer.reg.mintByGovernance(users[0].address, 100))
        .to.emit(reg, "MintByGovernance")
        .withArgs(users[0].address, 100);

      await expect(
        users[0].reg.transferBatch([], [50, 50])
      ).to.be.revertedWithCustomError(reg, REGErrors.InvalidLength);

      await expect(
        users[0].reg.transferBatch([users[1].address], [50, 50])
      ).to.be.revertedWithCustomError(reg, REGErrors.LengthNotMatch);

      await expect(
        users[0].reg.transferBatch(
          [users[1].address, users[2].address],
          [50, 50]
        )
      )
        .to.emit(reg, "Transfer")
        .withArgs(users[0].address, users[1].address, 50);
    });

    it("7. RecoverERC20", async function () {
      const { reg, deployer, bridge, users } = await setup();
      // Mint some tokens to user1
      await expect(deployer.reg.mintByGovernance(users[0].address, 100))
        .to.emit(reg, "MintByGovernance")
        .withArgs(users[0].address, 100);

      // User1 accidently sent 100 tokens to the contract
      await users[0].reg.transfer(reg.target, 100);

      expect(await reg.balanceOf(reg.target)).to.be.equal(100);
      expect(await reg.balanceOf(deployer.address)).to.be.equal(0);

      // Recover the tokens

      await expect(bridge.reg.recoverERC20(reg.target, 100)).to.be.revertedWith(
        `AccessControl: account ${bridge.address
          .toString()
          .toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE}`
      );

      await expect(deployer.reg.recoverERC20(reg.target, 100))
        .to.emit(reg, "RecoverByGovernance")
        .withArgs(reg.target, 100);

      expect(await reg.balanceOf(reg.target)).to.be.equal(0);
      expect(await reg.balanceOf(deployer.address)).to.be.equal(100);
    });

    it("8. Halt mint/burn/transfer during pause", async function () {
      const { reg, deployer, bridge, users } = await setup();
      // Mint some tokens to user1
      await expect(deployer.reg.mintByGovernance(users[0].address, 200))
        .to.emit(reg, "MintByGovernance")
        .withArgs(users[0].address, 200);

      await deployer.reg.grantRole(MINTER_BRIDGE_ROLE, bridge.address);

      await users[0].reg.transfer(reg.target, 50);
      await users[0].reg.transfer(bridge.address, 50);

      // Pause the contract
      await deployer.reg.pause();

      // Governance can not mintByGovernance/mintBatchByGovernance/burnByGovernance during pause
      await expect(
        deployer.reg.mintByGovernance(users[0].address, 100)
      ).to.be.revertedWith("ERC20Pausable: token transfer while paused");

      await expect(
        deployer.reg.mintBatchByGovernance(
          [users[0].address, users[1].address],
          [100, 100]
        )
      ).to.be.revertedWith("ERC20Pausable: token transfer while paused");

      await expect(deployer.reg.burnByGovernance(50)).to.be.revertedWith(
        "ERC20Pausable: token transfer while paused"
      );

      // Bridge can not mint/burn during pause
      await expect(bridge.reg.mint(users[0].address, 50)).to.be.revertedWith(
        "ERC20Pausable: token transfer while paused"
      );

      await expect(bridge.reg.burn(50)).to.be.revertedWith(
        "ERC20Pausable: token transfer while paused"
      );

      // User can not transfer/tansferBatch during pause
      await expect(
        users[0].reg.transfer(users[1].address, 100)
      ).to.be.revertedWith("ERC20Pausable: token transfer while paused");

      await expect(
        users[0].reg.transferBatch(
          [users[1].address, users[2].address],
          [50, 50]
        )
      ).to.be.revertedWith("ERC20Pausable: token transfer while paused");

      // Unpause the contract
      expect(await deployer.reg.unpause()).to.emit(reg, "Unpaused");
      await users[0].reg.transfer(users[1].address, 100);
      expect(await reg.balanceOf(users[1].address)).to.be.equal(100);
    });

    it("9. Upgradeablitity", async function () {
      const { reg, deployer, bridge } = await setup();

      await expect(bridge.reg.upgradeTo(ZERO_ADDRESS)).to.be.revertedWith(
        `AccessControl: account ${bridge.address
          .toString()
          .toLowerCase()} is missing role ${UPGRADER_ROLE}`
      );

      const REG = await ethers.getContractFactory("REG");
      const regV2 = await upgrades.upgradeProxy(reg.target, REG, {
        kind: "uups",
      });
    });
  });
});
