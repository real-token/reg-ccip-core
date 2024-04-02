import { ethers, upgrades, run } from "hardhat";
import * as dotenv from "dotenv";
dotenv.config();

async function main() {
  const CCIPSenderReceiver = await ethers.getContractFactory(
    "CCIPSenderReceiver"
  );

  const ccipSenderReceiver = await upgrades.deployProxy(
    CCIPSenderReceiver,
    [process.env.ADMIN, process.env.UPGRADER, process.env.ROUTER],
    { kind: "uups" }
  );

  const ccipSenderReceiverDeployed = await ccipSenderReceiver.deployed();

  const implAddress = await upgrades.erc1967.getImplementationAddress(
    ccipSenderReceiverDeployed.address
  );

  console.log(`Proxy address deployed: ${ccipSenderReceiverDeployed.address}`);
  console.log(`Implementation address deployed: ${implAddress}`);

  function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  await sleep(20000); // wait for 20s to have the contract propagated before verifying

  try {
    await run("verify:verify", {
      address: implAddress,
      constructorArguments: [],
    });
  } catch (err) {
    console.log(err);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
