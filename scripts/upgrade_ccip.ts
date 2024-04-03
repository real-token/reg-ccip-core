import { ethers, upgrades } from "hardhat";

async function main() {
  const CCIPSenderReceiver = await ethers.getContractFactory(
    "CCIPSenderReceiver"
  );
  await upgrades.upgradeProxy(
    process.env.CCIP_MUMBAI as string, // Proxy address
    CCIPSenderReceiver,
    { timeout: 0 }
  );
  console.log("The contract is upgraded");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
