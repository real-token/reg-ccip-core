import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-network-helpers";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
import "hardhat-dependency-compiler";
import "hardhat-contract-sizer";
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
        version: "0.8.19", // TODO back to 0.8.20 after testing, 0.8.19 required to deploy Chainlink Architecture
        settings: {
          optimizer: {
            enabled: true,
            runs: 10000, // TODO back to 100000 after testing (10000 required to deploy Chainlink OnRamp)
          },
          evmVersion: `paris`, // downgrade to `paris` if you encounter 'invalid opcode' error
        },
      },
    ],
  },
  // dependencyCompiler: {
  //   paths: [
  //     "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol",
  //     "@chainlink/contracts-ccip/contracts/ARM.sol",
  //     "@chainlink/contracts-ccip/contracts/ARMProxy.sol",
  //     "@chainlink/contracts-ccip/contracts/CommitStore.sol",
  //     "@chainlink/contracts-ccip/contracts/PriceRegistry.sol",
  //     "@chainlink/contracts-ccip/contracts/Router.sol",
  //     "@chainlink/contracts-ccip/contracts/pools/BurnMintTokenPool.sol",
  //     "@chainlink/contracts-ccip/contracts/onRamp/EVM2EVMOnRamp.sol",
  //     "@chainlink/contracts-ccip/contracts/offRamp/EVM2EVMOffRamp.sol",
  //   ],
  // },
  namedAccounts: {
    deployer: 0,
    admin: 1,
    moderator: 2,
    bridge: 3,
  },
  networks: networks,
  gasReporter: {
    coinmarketcap: process.env.REPORT_GAS,
    gasPrice: 20,
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  },
  etherscan: {
    enabled: true,
    apiKey: {
      // Etherscan V2 (Ethereum networks)
      mainnet: process.env.ETHERSCAN_API_KEY as string,
      sepolia: process.env.ETHERSCAN_API_KEY as string,
      // Avalanche (Snowtrace/Routescan)
      avalanche: process.env.AVAXSCAN_API_KEY as string,
      fuji: process.env.AVAXSCAN_API_KEY as string,
      // Polygon
      polygon: process.env.POLYGONSCAN_API_KEY as string,
      // Gnosis
      gnosis: process.env.GNOSISSCAN_API_KEY as string,
      chiado: process.env.GNOSISSCAN_API_KEY as string,
    },
    customChains: [
      {
        network: "fuji",
        chainId: 43113,
        urls: {
          apiURL:
            "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan",
          browserURL: "https://testnet.snowtrace.io",
        },
      },
      {
        network: "avalanche",
        chainId: 43114,
        urls: {
          apiURL:
            "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan",
          browserURL: "https://snowtrace.io",
        },
      },
    ],
  },
  sourcify: {
    enabled: false,
  },
};

export default config;
