import { TokenPool } from "./../typechain-types/@chainlink/contracts-ccip/src/v0.8/ccip/pools/TokenPool";
import { PriceRegistry } from "./../typechain-types/@chainlink/contracts-ccip/src/v0.8/ccip/PriceRegistry";
import { LinkToken } from "./../typechain-types/@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken";
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
  ZERO_ADDRESS,
  LINKTOKEN_HARDHAT,
  CHAIN_SELECTOR_SEPOLIA,
  CHAIN_SELECTOR_MUMBAI,
  LINKTOKEN_ETHEREUM,
  ETHER_UNIT,
  MINTER_BRIDGE_ROLE,
} from "../helpers/constants";
import { REGCCIPErrors } from "../helpers/types";

async function setup() {
  // it first ensure the deployment is executed and reset (use of evm_snaphost for fast test)
  await deployments.fixture();

  // we get an instantiated contract in the form of a ethers.js Contract instance:
  const REG = await deployments.get("REG");
  const LinkToken = await deployments.get("LinkToken");
  const Router = await deployments.get("Router");
  const OnRamp = await deployments.get("EVM2EVMOnRamp");
  const PriceRegistry = await deployments.get("PriceRegistry");
  const TokenPool = await deployments.get("BurnMintTokenPool");
  const REGCCIPSender = await deployments.get("REGCCIPSender");

  const contracts = {
    reg: await ethers.getContractAt("REG", REG.address),
    linkToken: await ethers.getContractAt("LinkToken", LinkToken.address),
    router: await ethers.getContractAt("Router", Router.address),
    onRamp: await ethers.getContractAt("EVM2EVMOnRamp", OnRamp.address),
    priceRegistry: await ethers.getContractAt(
      "PriceRegistry",
      PriceRegistry.address
    ),
    tokenPool: await ethers.getContractAt(
      "BurnMintTokenPool",
      TokenPool.address
    ),
    ccip: await ethers.getContractAt("REGCCIPSender", REGCCIPSender.address),
  };

  await contracts.reg.grantRole(MINTER_BRIDGE_ROLE, TokenPool.address);

  await contracts.router.applyRampUpdates(
    [
      // onRampUpdates
      [CHAIN_SELECTOR_MUMBAI, contracts.onRamp.target],
    ],
    [], // offRampRemoves]
    [
      // offRampAdds
      [CHAIN_SELECTOR_SEPOLIA, contracts.onRamp.target],
    ]
  );

  await contracts.tokenPool.applyRampUpdates(
    [
      // onRamps A list of onRamps and their new permission status/rate limits
      [
        OnRamp.address, // address ramp
        true, // bool allowed
        [
          true, // bool isEnabled; // Indication whether the rate limiting should be enabled
          ETHER_UNIT, // uint128 capacity Specifies the capacity of the rate limiter
          ETHER_UNIT, // uint128 rate Specifies the rate of the rate limiter
        ],
      ],
    ],
    [] // offRamps A list of offRamps and their new permission status/rate limits
  );

  await contracts.priceRegistry.updatePrices([
    [
      [contracts.reg.target, ETHER_UNIT],
      [contracts.linkToken.target, ETHER_UNIT],
    ], // [sourceToken, usdPerToken]
    [
      [CHAIN_SELECTOR_SEPOLIA, 10], // [destChainSelector, usdPerUnitGas]
      [CHAIN_SELECTOR_MUMBAI, 10],
    ],
  ]);

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
describe("CCIP", function () {
  describe("Admin functions", function () {
    it("1. Should set the right roles", async function () {
      const { ccip, deployer } = await setup();
      expect(await ccip.hasRole(DEFAULT_ADMIN_ROLE, deployer.address)).to.be
        .true;

      expect(await ccip.hasRole(UPGRADER_ROLE, deployer.address)).to.be.true;
    });

    it("2. allowlistDestinationChain", async function () {
      const { ccip, deployer, admin } = await setup();

      await expect(
        admin.ccip.allowlistDestinationChain(CHAIN_SELECTOR_MUMBAI, true)
      ).to.be.revertedWith(
        `AccessControl: account ${admin.address
          .toString()
          .toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE}`
      );

      await expect(
        deployer.ccip.allowlistDestinationChain(CHAIN_SELECTOR_MUMBAI, true)
      )
        .to.emit(ccip, "AllowlistDestinationChain")
        .withArgs(CHAIN_SELECTOR_MUMBAI, true);
    });

    it("3. allowlistToken", async function () {
      const { reg, ccip, deployer, admin } = await setup();

      await expect(
        admin.ccip.allowlistToken(reg.target, true)
      ).to.be.revertedWith(
        `AccessControl: account ${admin.address
          .toString()
          .toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE}`
      );

      await expect(
        deployer.ccip.allowlistToken(ZERO_ADDRESS, true)
      ).to.be.revertedWithCustomError(
        ccip,
        REGCCIPErrors.InvalidContractAddress
      );

      await expect(deployer.ccip.allowlistToken(reg.target, true))
        .to.emit(ccip, "AllowlistToken")
        .withArgs(reg.target, true);
    });

    it("4. setRouter", async function () {
      const { ccip, router, deployer, admin } = await setup();

      await expect(admin.ccip.setRouter(router.target)).to.be.revertedWith(
        `AccessControl: account ${admin.address
          .toString()
          .toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE}`
      );

      await expect(
        deployer.ccip.setRouter(ZERO_ADDRESS)
      ).to.be.revertedWithCustomError(
        ccip,
        REGCCIPErrors.InvalidContractAddress
      );

      await expect(deployer.ccip.setRouter(router.target))
        .to.emit(ccip, "SetRouter")
        .withArgs(router.target);
    });

    it("5. withdraw", async function () {
      const { ccip, deployer, admin } = await setup();

      const [donator] = await ethers.getSigners();

      await donator.sendTransaction({
        to: ccip.target,
        value: ethers.parseEther("1"),
      });

      const balance = await ethers.provider.getBalance(ccip.target);
      console.log("Ether balance of ccip", balance.toString());

      await expect(admin.ccip.withdraw(admin.address)).to.be.revertedWith(
        `AccessControl: account ${admin.address
          .toString()
          .toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE}`
      );

      console.log(
        "Ether balance of deployer before: ",
        (await ethers.provider.getBalance(deployer.address)).toString()
      );
      await deployer.ccip.withdraw(deployer.address);
      console.log(
        "Ether balance of deployer after: ",
        (await ethers.provider.getBalance(deployer.address)).toString()
      );
    });

    it("6. withdrawToken", async function () {
      const { reg, ccip, deployer, admin } = await setup();

      await deployer.reg.mintByGovernance(ccip.target, 1000);
      let ccipBalance = await reg.balanceOf(ccip.target);
      expect(ccipBalance).to.be.equal(1000);
      console.log("Token balance of ccip", ccipBalance.toString());

      await expect(
        admin.ccip.withdrawToken(admin.address, reg.target)
      ).to.be.revertedWith(
        `AccessControl: account ${admin.address
          .toString()
          .toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE}`
      );

      await deployer.ccip.withdrawToken(deployer.address, reg.target);

      ccipBalance = await reg.balanceOf(ccip.target);
      expect(ccipBalance).to.be.equal(0);
    });
  });

  describe("User functions: transferTokens/transferTokenWithPermit", async function () {
    it("7. transferTokens", async function () {
      const { reg, ccip, deployer, admin, users, linkToken } = await setup();
      // Mint REG and LINK to users[0]
      await deployer.reg.mintByGovernance(users[0].address, ETHER_UNIT);
      await deployer.linkToken.grantMintRole(deployer.address);
      await deployer.linkToken.mint(users[0].address, ETHER_UNIT);
      console.log(
        "User LINK token balance before transfer",
        (await linkToken.balanceOf(users[0].address)).toString()
      );
      console.log(
        "User REG token balance before transfer",
        (await reg.balanceOf(users[0].address)).toString()
      );

      // Approve CCIP to spend LINK and REG
      await users[0].reg.approve(ccip.target, ETHER_UNIT);
      await users[0].linkToken.approve(ccip.target, ETHER_UNIT);

      let userBalance = await reg.balanceOf(users[0].address);
      console.log("User balance before transfer", userBalance.toString());

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          linkToken.target
        )
      ).to.be.revertedWithCustomError(ccip, REGCCIPErrors.TokenNotAllowlisted);

      await deployer.ccip.allowlistToken(reg.target, true);

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          linkToken.target
        )
      ).to.be.revertedWithCustomError(
        ccip,
        REGCCIPErrors.DestinationChainNotAllowlisted
      );

      await deployer.ccip.allowlistDestinationChain(
        CHAIN_SELECTOR_MUMBAI,
        true
      );

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          ZERO_ADDRESS,
          reg.target,
          1000,
          linkToken.target
        )
      ).to.be.revertedWithCustomError(
        ccip,
        REGCCIPErrors.InvalidReceiverAddress
      );

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          LINKTOKEN_ETHEREUM
        )
      ).to.be.revertedWithCustomError(ccip, REGCCIPErrors.InvalidFeeToken);

      await users[0].ccip.transferTokens(
        CHAIN_SELECTOR_MUMBAI,
        users[0].address,
        reg.target,
        1000,
        linkToken.target
      );
    });

    it("8. transferTokensWithPermit", async function () {
      const { ccip, deployer } = await setup();
    });
  });

  describe("View functions", async function () {
    it("9. getRouter", async function () {
      const { ccip, router } = await setup();

      console.log("Router", await ccip.getRouter());
      expect(await ccip.getRouter()).to.be.equal(router.target);
    });

    it("10. getLinkToken", async function () {
      const { ccip } = await setup();
      console.log("LinkToken", await ccip.getLinkToken());
      console.log("LINKTOKEN_HARDHAT", LINKTOKEN_HARDHAT);
      expect(await ccip.getLinkToken()).to.be.equal(LINKTOKEN_HARDHAT);
    });

    it("11. getWrappedNativeToken", async function () {
      const { ccip, deployer } = await setup();
      console.log("WrappedNativeToken", await ccip.getWrappedNativeToken());
      expect(await ccip.getWrappedNativeToken()).to.not.be.equal(ZERO_ADDRESS);
    });

    it("12. getAllowlistedDestinationChains/isAllowlistedDestinationChain", async function () {
      const { ccip, deployer } = await setup();
      await ccip.allowlistDestinationChain(CHAIN_SELECTOR_MUMBAI, true);
      expect(await ccip.getAllowlistedDestinationChains()).to.be.deep.equal([
        CHAIN_SELECTOR_MUMBAI,
      ]);

      expect(await ccip.isAllowlistedDestinationChain(CHAIN_SELECTOR_MUMBAI)).to
        .be.true;

      await expect(
        ccip.allowlistDestinationChain(CHAIN_SELECTOR_MUMBAI, true)
      ).to.be.revertedWithCustomError(
        ccip,
        REGCCIPErrors.AllowedStateNotChange
      );

      await ccip.allowlistDestinationChain(CHAIN_SELECTOR_MUMBAI, false);
      expect(await ccip.getAllowlistedDestinationChains()).to.be.deep.equal([
        CHAIN_SELECTOR_MUMBAI,
      ]);

      expect(await ccip.isAllowlistedDestinationChain(CHAIN_SELECTOR_MUMBAI)).to
        .be.false;
      await ccip.allowlistDestinationChain(CHAIN_SELECTOR_MUMBAI, true);
      expect(await ccip.getAllowlistedDestinationChains()).to.be.deep.equal([
        CHAIN_SELECTOR_MUMBAI,
      ]);
    });

    it("13. getAllowlistedTokens/isAllowlistedToken", async function () {
      const { ccip, reg } = await setup();
      await ccip.allowlistToken(reg.target, true);

      expect(await ccip.isAllowlistedToken(reg.target)).to.be.true;
      expect(await ccip.getAllowlistedTokens()).to.be.deep.equal([reg.target]);

      await expect(
        ccip.allowlistToken(reg.target, true)
      ).to.be.revertedWithCustomError(
        ccip,
        REGCCIPErrors.AllowedStateNotChange
      );

      await ccip.allowlistToken(reg.target, false);
      expect(await ccip.isAllowlistedToken(reg.target)).to.be.false;
      expect(await ccip.getAllowlistedTokens()).to.be.deep.equal([reg.target]);

      await ccip.allowlistToken(reg.target, true);
      expect(await ccip.isAllowlistedToken(reg.target)).to.be.true;
      expect(await ccip.getAllowlistedTokens()).to.be.deep.equal([reg.target]);
    });

    it("14. getCcipFeesEstimation", async function () {
      const { ccip, reg, router, deployer, admin } = await setup();

      const fee = await ccip.getCcipFeesEstimation(
        CHAIN_SELECTOR_MUMBAI,
        admin.address,
        reg.target,
        1000,
        LINKTOKEN_HARDHAT
      );
      console.log("fee", fee.toString());
      expect(fee).to.be.gt(0);
    });
  });

  describe("Receiver functions", async function () {
    it("15. supportsInterface", async function () {
      const { ccip, deployer } = await setup();

      console.log(
        "supportsInterface",
        await ccip.supportsInterface("0x01ffc9a7")
      );
    });

    // TODO replicate Chainlink offchain message sending to test ccipReceive
    it("16. ccipReceive", async function () {
      const { ccip, deployer } = await setup();
    });
  });

  describe("Upgradeability", async function () {
    it("17. Upgradeability", async function () {
      const { ccip, deployer, admin } = await setup();

      await expect(admin.ccip.upgradeTo(ZERO_ADDRESS)).to.be.revertedWith(
        `AccessControl: account ${admin.address
          .toString()
          .toLowerCase()} is missing role ${UPGRADER_ROLE}`
      );

      const REGCCIPSender = await ethers.getContractFactory("REGCCIPSender");
      const ccipV2 = await upgrades.upgradeProxy(ccip.target, REGCCIPSender, {
        kind: "uups",
      });
    });
  });
});
