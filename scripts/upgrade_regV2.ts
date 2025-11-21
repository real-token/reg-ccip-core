import { ethers, upgrades } from "hardhat";

async function main() {
  const REGV2 = await ethers.getContractFactory("REGV2");
  await upgrades.upgradeProxy(
    process.env.REG_PROXY_SEPOLIA as string, // Proxy address
    REGV2,
    {
      unsafeSkipStorageCheck: true, // Need to manually check storage layout compatibility
      timeout: 0,
    }
  );
  console.log("The contract is upgraded");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
