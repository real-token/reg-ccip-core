import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
import "hardhat-dependency-compiler";
import networks from "./hardhat.networks";
import * as dotenv from "dotenv";
dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 20000,
          },
        },
      },
    ],
  },
  dependencyCompiler: {
    paths: [
      "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol",
      "@chainlink/contracts-ccip/src/v0.8/ccip/ARM.sol",
      "@chainlink/contracts-ccip/src/v0.8/ccip/ARMProxy.sol",
      "@chainlink/contracts-ccip/src/v0.8/ccip/CommitStore.sol",
      "@chainlink/contracts-ccip/src/v0.8/ccip/PriceRegistry.sol",
      "@chainlink/contracts-ccip/src/v0.8/ccip/Router.sol",
      "@chainlink/contracts-ccip/src/v0.8/ccip/pools/BurnMintTokenPool.sol",
      "@chainlink/contracts-ccip/src/v0.8/ccip/onRamp/EVM2EVMOnRamp.sol",
      "@chainlink/contracts-ccip/src/v0.8/ccip/offRamp/EVM2EVMOffRamp.sol",
    ],
  },
  namedAccounts: {
    deployer: 0,
    admin: 1,
    moderator: 2,
  },
  networks: networks,
  gasReporter: {
    coinmarketcap: process.env.REPORT_GAS,
    gasPrice: 20,
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
