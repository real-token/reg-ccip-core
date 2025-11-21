import { NetworksUserConfig } from "hardhat/types";
import * as dotenv from "dotenv";
dotenv.config();

const networks: NetworksUserConfig | undefined = {};
const FORK = process.env.FORK || "";
const FORK_BLOCK_NUMBER = process.env.FORK_BLOCK_NUMBER
  ? parseInt(process.env.FORK_BLOCK_NUMBER)
  : 0;

if (FORK) {
  networks.hardhat = {
    forking: {
      url: process.env.MAINNET_RPC_URL || "",
      blockNumber: FORK_BLOCK_NUMBER,
    },
  };
} else {
  networks.hardhat = {};
}

if (process.env.MAINNET_RPC_URL && process.env.PRIVATE_KEY) {
  networks.mainnet = {
    url: process.env.MAINNET_RPC_URL,
    chainId: 1,
    gasPrice: "auto",
    accounts: [process.env.PRIVATE_KEY],
  };
}

if (process.env.SEPOLIA_RPC_URL && process.env.PRIVATE_KEY) {
  networks.sepolia = {
    url: process.env.SEPOLIA_RPC_URL,
    chainId: 11155111,
    gasPrice: "auto",
    accounts: [process.env.PRIVATE_KEY],
  };
}

if (process.env.GNOSIS_RPC_URL && process.env.PRIVATE_KEY) {
  networks.gnosis = {
    url: process.env.GNOSIS_RPC_URL,
    chainId: 100,
    gasPrice: "auto",
    accounts: [process.env.PRIVATE_KEY],
  };
}

if (process.env.POLYGON_RPC_URL && process.env.PRIVATE_KEY) {
  networks.polygon = {
    url: process.env.POLYGON_RPC_URL,
    chainId: 137,
    gasPrice: "auto",
    accounts: [process.env.PRIVATE_KEY],
  };
}

if (process.env.MUMBAI_RPC_URL && process.env.PRIVATE_KEY) {
  networks.polygonMumbai = {
    url: process.env.MUMBAI_RPC_URL,
    chainId: 80001,
    gasPrice: "auto",
    accounts: [process.env.PRIVATE_KEY],
  };
}

if (process.env.FUJI_RPC_URL && process.env.PRIVATE_KEY) {
  networks.fuji = {
    url: process.env.FUJI_RPC_URL,
    chainId: 43113,
    gasPrice: "auto",
    accounts: [process.env.PRIVATE_KEY],
  };
}

export default networks;
