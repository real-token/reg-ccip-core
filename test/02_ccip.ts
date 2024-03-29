import { time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
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
import { CCIPErrors } from "../helpers/types";
import { getPermitSignatureERC20 } from "./utils/utils";

async function setup() {
  // it first ensure the deployment is executed and reset (use of evm_snaphost for fast test)
  await deployments.fixture();

  // we get an instantiated contract in the form of a ethers.js Contract instance:
  const REG = await deployments.get("REG");
  const WETH = await deployments.get("WETH");
  const LinkToken = await deployments.get("LinkToken");
  const Router = await deployments.get("Router");
  const OnRamp = await deployments.get("EVM2EVMOnRamp");
  const PriceRegistry = await deployments.get("PriceRegistry");
  const TokenPool = await deployments.get("BurnMintTokenPool");
  const CCIPSenderReceiver = await deployments.get("CCIPSenderReceiver");
  const REGCCIPReceiver = await deployments.get("REGCCIPReceiver");

  const contracts = {
    reg: await ethers.getContractAt("REG", REG.address),
    weth: await ethers.getContractAt("WETH", WETH.address),
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
    ccip: await ethers.getContractAt(
      "CCIPSenderReceiver",
      CCIPSenderReceiver.address
    ),
    ccipReceiver: await ethers.getContractAt(
      "CCIPSenderReceiver",
      REGCCIPReceiver.address
    ),
  };

  await contracts.reg.grantRole(MINTER_BRIDGE_ROLE, TokenPool.address);

  await contracts.router.setWrappedNative(contracts.weth.target);

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
      // [sourceToken, usdPerToken]
      [contracts.reg.target, ETHER_UNIT],
      [contracts.linkToken.target, ETHER_UNIT],
      [contracts.weth.target, ETHER_UNIT],
    ],
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
      const { ccip, router, deployer } = await setup();
      expect(await ccip.hasRole(DEFAULT_ADMIN_ROLE, deployer.address)).to.be
        .true;

      expect(await ccip.hasRole(UPGRADER_ROLE, deployer.address)).to.be.true;

      await expect(
        deployer.ccip.initialize(
          deployer.address,
          deployer.address,
          router.target
        )
      ).to.be.revertedWith("Initializable: contract is already initialized");
    });

    it("2. allowlistDestinationChain", async function () {
      const { ccip, ccipReceiver, deployer, admin } = await setup();

      await expect(
        admin.ccip.allowlistDestinationChain(
          CHAIN_SELECTOR_MUMBAI,
          ccipReceiver.target
        )
      ).to.be.revertedWith(
        `AccessControl: account ${admin.address
          .toString()
          .toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE}`
      );

      await expect(
        deployer.ccip.allowlistDestinationChain(
          CHAIN_SELECTOR_MUMBAI,
          ccipReceiver.target
        )
      )
        .to.emit(ccip, "AllowlistDestinationChain")
        .withArgs(CHAIN_SELECTOR_MUMBAI, ccipReceiver.target);
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
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.InvalidContractAddress);

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
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.InvalidContractAddress);

      await expect(deployer.ccip.setRouter(router.target))
        .to.emit(ccip, "SetRouter")
        .withArgs(router.target);
    });

    it("5. withdraw", async function () {
      const { ccip, deployer, admin } = await setup();

      // Revert when not default admin withdraw
      await expect(admin.ccip.withdraw(admin.address)).to.be.revertedWith(
        `AccessControl: account ${admin.address
          .toString()
          .toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE}`
      );

      // Revert when nothing to withdraw
      await expect(
        deployer.ccip.withdraw(deployer.address)
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.NothingToWithdraw);

      const [donator] = await ethers.getSigners();

      await donator.sendTransaction({
        to: ccip.target,
        value: ethers.parseEther("1"),
      });

      const balance = await ethers.provider.getBalance(ccip.target);
      console.log("Ether balance of ccip", balance.toString());

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

      await expect(
        admin.ccip.withdrawToken(admin.address, reg.target)
      ).to.be.revertedWith(
        `AccessControl: account ${admin.address
          .toString()
          .toLowerCase()} is missing role ${DEFAULT_ADMIN_ROLE}`
      );

      // Revert when nothing to withdraw
      await expect(
        deployer.ccip.withdrawToken(deployer.address, reg.target)
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.NothingToWithdraw);

      await deployer.reg.mintByGovernance(ccip.target, 1000);
      let ccipBalance = await reg.balanceOf(ccip.target);
      expect(ccipBalance).to.be.equal(1000);
      console.log("Token balance of ccip", ccipBalance.toString());

      await deployer.ccip.withdrawToken(deployer.address, reg.target);

      ccipBalance = await reg.balanceOf(ccip.target);
      expect(ccipBalance).to.be.equal(0);
    });
  });

  describe("User functions: transferTokens/transferTokenWithPermit", async function () {
    it("7. transferTokens using LINK: reverted cases", async function () {
      const { reg, ccip, ccipReceiver, deployer, admin, users, linkToken } =
        await setup();
      // Mint REG and LINK to users[0]
      await deployer.reg.mintByGovernance(users[0].address, ETHER_UNIT);
      // await deployer.linkToken.grantMintRole(deployer.address);
      // await deployer.linkToken.mint(users[0].address, ETHER_UNIT);
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

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          linkToken.target
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.TokenNotAllowlisted);

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
        CCIPErrors.DestinationChainNotAllowlisted
      );

      await deployer.ccip.allowlistDestinationChain(
        CHAIN_SELECTOR_MUMBAI,
        ccipReceiver.target
      );

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          ZERO_ADDRESS,
          reg.target,
          1000,
          linkToken.target
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.InvalidReceiverAddress);

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          LINKTOKEN_ETHEREUM
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.InvalidFeeToken);
    });

    it("8. transferTokens using native: reverted cases", async function () {
      const { reg, ccip, ccipReceiver, deployer, admin, users, linkToken } =
        await setup();
      // Mint REG users[0]
      await deployer.reg.mintByGovernance(users[0].address, ETHER_UNIT);

      console.log(
        "User REG token balance before transfer",
        (await reg.balanceOf(users[0].address)).toString()
      );

      // Approve CCIP to spend REG
      await users[0].reg.approve(ccip.target, ETHER_UNIT);

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          ZERO_ADDRESS
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.TokenNotAllowlisted);

      await deployer.ccip.allowlistToken(reg.target, true);

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          ZERO_ADDRESS
        )
      ).to.be.revertedWithCustomError(
        ccip,
        CCIPErrors.DestinationChainNotAllowlisted
      );

      await deployer.ccip.allowlistDestinationChain(
        CHAIN_SELECTOR_MUMBAI,
        ccipReceiver.target
      );

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          ZERO_ADDRESS,
          reg.target,
          1000,
          ZERO_ADDRESS
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.InvalidReceiverAddress);

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          LINKTOKEN_ETHEREUM
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.InvalidFeeToken);

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          ZERO_ADDRESS
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.NotEnoughBalance);
    });

    it("9. transferTokens using LINK: succeed", async function () {
      const { reg, ccip, ccipReceiver, deployer, users, linkToken } =
        await setup();
      // Mint REG and LINK to users[0]
      await deployer.reg.mintByGovernance(users[0].address, ETHER_UNIT);
      await deployer.linkToken.grantMintRole(deployer.address);
      await deployer.linkToken.mint(users[0].address, ETHER_UNIT);
      console.log(
        "User REG token balance before transfer",
        (await reg.balanceOf(users[0].address)).toString()
      );
      console.log(
        "User LINK token balance before transfer",
        (await linkToken.balanceOf(users[0].address)).toString()
      );

      // Approve CCIP to spend LINK and REG
      await users[0].reg.approve(ccip.target, ETHER_UNIT);
      await users[0].linkToken.approve(ccip.target, ETHER_UNIT);

      await deployer.ccip.allowlistToken(reg.target, true);
      await deployer.ccip.allowlistDestinationChain(
        CHAIN_SELECTOR_MUMBAI,
        ccipReceiver.target
      );

      const fees = await users[0].ccip.getCcipFeesEstimation(
        CHAIN_SELECTOR_MUMBAI,
        users[0].address,
        reg.target,
        1000,
        linkToken.target
      );

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          linkToken.target
        )
      ).to.emit(ccip, "TokensTransferred");
    });

    it("10. transferTokens using native: succeed", async function () {
      const { reg, ccip, ccipReceiver, deployer, users, linkToken } =
        await setup();
      // Mint REG to users[0]
      await deployer.reg.mintByGovernance(users[0].address, ETHER_UNIT);
      console.log(
        "User REG token balance before transfer",
        (await reg.balanceOf(users[0].address)).toString()
      );

      // Approve CCIP to spend REG
      await users[0].reg.approve(ccip.target, ETHER_UNIT);

      await deployer.ccip.allowlistToken(reg.target, true);
      await deployer.ccip.allowlistDestinationChain(
        CHAIN_SELECTOR_MUMBAI,
        ccipReceiver.target
      );

      // Estimate fees
      const fees = await users[0].ccip.getCcipFeesEstimation(
        CHAIN_SELECTOR_MUMBAI,
        users[0].address,
        reg.target,
        1000,
        ZERO_ADDRESS
      );
      console.log("Fee", fees.toString());

      // send tx with msg.value = fees
      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          ZERO_ADDRESS,
          { value: fees }
        )
      ).to.emit(ccip, "TokensTransferred");
    });

    it("11. transferTokensWithPermit using LINK: reverted cases", async function () {
      const { reg, ccip, ccipReceiver, deployer, admin, users, linkToken } =
        await setup();
      // Mint REG and LINK to users[0]
      await deployer.reg.mintByGovernance(users[0].address, ETHER_UNIT);
      // await deployer.linkToken.grantMintRole(deployer.address);
      // await deployer.linkToken.mint(users[0].address, ETHER_UNIT);
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

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          linkToken.target
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.TokenNotAllowlisted);

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
        CCIPErrors.DestinationChainNotAllowlisted
      );

      await deployer.ccip.allowlistDestinationChain(
        CHAIN_SELECTOR_MUMBAI,
        ccipReceiver.target
      );

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          ZERO_ADDRESS,
          reg.target,
          1000,
          linkToken.target
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.InvalidReceiverAddress);

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          LINKTOKEN_ETHEREUM
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.InvalidFeeToken);
    });

    it("12. transferTokensWithPermit using native: reverted cases", async function () {
      const { reg, ccip, ccipReceiver, deployer, admin, users, linkToken } =
        await setup();
      // Mint REG and LINK to users[0]
      await deployer.reg.mintByGovernance(users[0].address, ETHER_UNIT);
      // await deployer.linkToken.grantMintRole(deployer.address);
      // await deployer.linkToken.mint(users[0].address, ETHER_UNIT);
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

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          linkToken.target
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.TokenNotAllowlisted);

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
        CCIPErrors.DestinationChainNotAllowlisted
      );

      await deployer.ccip.allowlistDestinationChain(
        CHAIN_SELECTOR_MUMBAI,
        ccipReceiver.target
      );

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          ZERO_ADDRESS,
          reg.target,
          1000,
          linkToken.target
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.InvalidReceiverAddress);

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          LINKTOKEN_ETHEREUM
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.InvalidFeeToken);

      await expect(
        users[0].ccip.transferTokens(
          CHAIN_SELECTOR_MUMBAI,
          users[0].address,
          reg.target,
          1000,
          ZERO_ADDRESS
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.NotEnoughBalance);
    });

    it("13. transferTokensWithPermit using LINK: succeed", async function () {
      const { reg, ccip, ccipReceiver, deployer, users, linkToken } =
        await setup();
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

      await deployer.ccip.allowlistToken(reg.target, true);
      await deployer.ccip.allowlistDestinationChain(
        CHAIN_SELECTOR_MUMBAI,
        ccipReceiver.target
      );

      await users[0].ccip.transferTokens(
        CHAIN_SELECTOR_MUMBAI,
        users[0].address,
        reg.target,
        1000,
        linkToken.target
      );
    });

    it("14. transferTokensWithPermit using native: succeed", async function () {
      const { reg, ccip, ccipReceiver, deployer, users, linkToken } =
        await setup();
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

      await deployer.ccip.allowlistToken(reg.target, true);
      await deployer.ccip.allowlistDestinationChain(
        CHAIN_SELECTOR_MUMBAI,
        ccipReceiver.target
      );

      await users[0].ccip.transferTokens(
        CHAIN_SELECTOR_MUMBAI,
        users[0].address,
        reg.target,
        1000,
        linkToken.target
      );
    });

    it("8. transferTokensWithPermit", async function () {
      const { reg, ccip, deployer, users } = await setup();
      const timeStamp = await time.latest();
      const user0 = await ethers.getSigner(users[0].address);
      const [user1] = await ethers.getSigners();
      console.log("user0", user0);
      const transferSignature = await getPermitSignatureERC20(
        user0,
        ccip.target.toString(),
        timeStamp + 3600,
        1000,
        reg
      );
      console.log("transferSignature", transferSignature);
    });
  });

  describe("View functions", async function () {
    it("15. getRouter", async function () {
      const { ccip, router } = await setup();

      console.log("Router", await ccip.getRouter());
      expect(await ccip.getRouter()).to.be.equal(router.target);
    });

    it("16. getLinkToken", async function () {
      const { ccip } = await setup();
      console.log("LinkToken", await ccip.getLinkToken());
      console.log("LINKTOKEN_HARDHAT", LINKTOKEN_HARDHAT);
      expect(await ccip.getLinkToken()).to.be.equal(LINKTOKEN_HARDHAT);
    });

    it("17. getWrappedNativeToken", async function () {
      const { ccip, deployer } = await setup();
      console.log("WrappedNativeToken", await ccip.getWrappedNativeToken());
      expect(await ccip.getWrappedNativeToken()).to.not.be.equal(ZERO_ADDRESS);
    });

    it("18. getAllowlistedDestinationChains/isAllowlistedDestinationChain", async function () {
      const { ccip, ccipReceiver, deployer } = await setup();
      await ccip.allowlistDestinationChain(
        CHAIN_SELECTOR_MUMBAI,
        ccipReceiver.target
      );
      expect(await ccip.getAllowlistedDestinationChains()).to.be.deep.equal([
        CHAIN_SELECTOR_MUMBAI,
      ]);

      expect(await ccip.isAllowlistedDestinationChain(CHAIN_SELECTOR_MUMBAI)).to
        .be.true;

      await expect(
        ccip.allowlistDestinationChain(
          CHAIN_SELECTOR_MUMBAI,
          ccipReceiver.target
        )
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.AllowedStateNotChange);

      await ccip.allowlistDestinationChain(CHAIN_SELECTOR_MUMBAI, ZERO_ADDRESS);

      expect(await ccip.getAllowlistedDestinationChains()).to.be.deep.equal([
        CHAIN_SELECTOR_MUMBAI,
      ]);

      expect(await ccip.isAllowlistedDestinationChain(CHAIN_SELECTOR_MUMBAI)).to
        .be.false;
      await ccip.allowlistDestinationChain(
        CHAIN_SELECTOR_MUMBAI,
        ccipReceiver.target
      );
      expect(await ccip.getAllowlistedDestinationChains()).to.be.deep.equal([
        CHAIN_SELECTOR_MUMBAI,
      ]);
    });

    it("19. getAllowlistedTokens/isAllowlistedToken", async function () {
      const { ccip, reg } = await setup();
      await ccip.allowlistToken(reg.target, true);

      expect(await ccip.isAllowlistedToken(reg.target)).to.be.true;
      expect(await ccip.getAllowlistedTokens()).to.be.deep.equal([reg.target]);

      await expect(
        ccip.allowlistToken(reg.target, true)
      ).to.be.revertedWithCustomError(ccip, CCIPErrors.AllowedStateNotChange);

      await ccip.allowlistToken(reg.target, false);
      expect(await ccip.isAllowlistedToken(reg.target)).to.be.false;
      expect(await ccip.getAllowlistedTokens()).to.be.deep.equal([reg.target]);

      await ccip.allowlistToken(reg.target, true);
      expect(await ccip.isAllowlistedToken(reg.target)).to.be.true;
      expect(await ccip.getAllowlistedTokens()).to.be.deep.equal([reg.target]);
    });

    it("20. getCcipFeesEstimation", async function () {
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
    it("21. supportsInterface", async function () {
      const { ccip, deployer } = await setup();

      console.log(
        "supportsInterface",
        await ccip.supportsInterface("0x01ffc9a7")
      );
      expect(await ccip.supportsInterface("0x01ffc9a7")).to.be.true; // type(IERC165).interfaceId = type(IERC165Upgradeable).interfaceId
      expect(await ccip.supportsInterface("0x85572ffb")).to.be.true; // type(IAny2EVMMessageReceiver).interfaceId
      expect(await ccip.supportsInterface("0x7965db0b")).to.be.true; // type(IAccessControlUpgradeable).interfaceId
    });

    // TODO replicate Chainlink offchain message sending to test ccipReceive
    it("22. ccipReceive", async function () {
      const { ccip, deployer } = await setup();
    });
  });

  describe("Upgradeability", async function () {
    it("23. Upgradeability", async function () {
      const { ccip, deployer, admin } = await setup();

      await expect(admin.ccip.upgradeTo(ZERO_ADDRESS)).to.be.revertedWith(
        `AccessControl: account ${admin.address
          .toString()
          .toLowerCase()} is missing role ${UPGRADER_ROLE}`
      );

      const CCIPSenderReceiver = await ethers.getContractFactory(
        "CCIPSenderReceiver"
      );
      const ccipV2 = await upgrades.upgradeProxy(
        ccip.target,
        CCIPSenderReceiver,
        {
          kind: "uups",
        }
      );
    });
  });
});
