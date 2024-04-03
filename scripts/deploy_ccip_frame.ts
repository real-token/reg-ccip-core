import hre, { ethers, upgrades, run } from "hardhat";
import * as dotenv from "dotenv";
dotenv.config();

async function main() {
  const CCIPSenderReceiver = await ethers.getContractFactory(
    "CCIPSenderReceiver"
  );

  const provider = new ethers.JsonRpcProvider(
    "http://127.0.0.1:1248", // RPC FRAME
    {
      chainId: hre.network.config.chainId ?? 5,
      name: hre.network.name,
    }
  );
  const signer = await provider.getSigner();
  const deployer = await signer.getAddress();
  console.log("Using hardware wallet: ", deployer);

  const ccipSenderReceiver = CCIPSenderReceiver.connect(signer);

  const ccipSenderReceiverTx = await upgrades.deployProxy(
    ccipSenderReceiver,
    [process.env.ADMIN, process.env.UPGRADER, process.env.ROUTER],
    { kind: "uups" }
  );

  await ccipSenderReceiverTx.waitForDeployment();

  const implAddress = await upgrades.erc1967.getImplementationAddress(
    await ccipSenderReceiverTx.getAddress()
  );

  console.log(
    `Proxy address deployed: ${await ccipSenderReceiverTx.getAddress()}`
  );
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
