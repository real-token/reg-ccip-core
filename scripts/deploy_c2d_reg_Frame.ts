import { Interface, isAddress } from "ethers/lib/utils";
import hre, { ethers, network } from "hardhat";
import { REG__factory } from "../typechain-types";
import create2ABI from "./abis/create2.json";
import { validate } from "./utils/c2d-utils";
import { input } from "@inquirer/prompts";
import { importRegFromC2d } from "../helpers/forceImports";

export default async function main() {
  if (!create2ABI) throw new Error("CREATE2 abi not found");

  const hexChainId = await network.provider.send("eth_chainId");
  const chainId = Number(hexChainId);

  // const [admin] = await ethers.getSigners();
  console.log("Get hardware wallet provider");

  const provider = new ethers.providers.JsonRpcProvider(
    "http://127.0.0.1:1248", // RPC FRAME
    {
      chainId: hre.network.config.chainId ?? 5,
      name: hre.network.name,
    }
  );

  const admin = provider.getSigner();

  const deployer = await admin.getAddress();

  console.log("Using hardware wallet: ", deployer);

  // Get the implementation contract
  const contract = (await ethers.getContractFactory("REG")).connect(admin);

  // Get the proxy contract
  const proxy = (await ethers.getContractFactory("ERC1967Proxy")).connect(
    admin
  );
  const iface = new Interface(create2ABI);

  // Get all parameters
  const salt = await input({ message: "Enter salt" });

  const create2 = await input({ message: "Enter create2 address", validate });

  const DEFAULT_ADMIN = await input({
    message: "Enter the default admin address",
    validate,
  });
  const PAUSER = await input({
    message: "Enter the pauser address",
    validate,
  });

  const MINTER = await input({
    message: "Enter the minter address",
    validate,
  });

  const UPGRADER = await input({
    message: "Enter the upgrader address",
    validate,
  });

  // Check if parameters are present
  if (!salt) throw new Error("please run command with SALT=someSalt");
  if (!create2) throw new Error("please run command with CREATE2=0x... prefix");
  if (!DEFAULT_ADMIN)
    throw new Error("please run command with DEFAULT_ADMIN=0x... prefix");
  if (!PAUSER) throw new Error("please run command with PAUSER=0x... prefix");
  if (!MINTER) throw new Error("please run command with MINTER=0x... prefix");
  if (!UPGRADER)
    throw new Error("please run command with UPGRADER=0x... prefix");

  // Check if parameters are valid
  if (!isAddress(DEFAULT_ADMIN))
    throw new Error("DEFAULT_ADMIN env var is not an address");
  if (!isAddress(PAUSER)) throw new Error("PAUSER env var is not an address");
  if (!isAddress(MINTER)) throw new Error("MINTER env var is not an address");
  if (!isAddress(UPGRADER))
    throw new Error("UPGRADER env var is not an address");

  if (!isAddress(create2)) throw new Error("create2 env var is not an address");

  const initializePayload = contract.interface.encodeFunctionData(
    "initialize",
    [DEFAULT_ADMIN, PAUSER, MINTER, UPGRADER]
  );

  const deployImpl = iface.encodeFunctionData("deploy", [
    "0",
    ethers.utils.formatBytes32String(salt),
    REG__factory.bytecode,
    "0x",
  ]);

  console.log("Deploying transaction 1");

  const tx1 = await admin.sendTransaction({
    data: deployImpl,
    to: create2,
    from: deployer,
  });

  console.log("Sending transaction 1");

  console.log("Transaction 1 hash: ", tx1.hash);
  const receipt1 = await tx1.wait(1);

  console.log("Decode event log of transaction 1");
  // console.log("Receipt 1: ", receipt1.logs);

  // Event: Deployed(newContract, salt, keccak256(bytecode))
  const createdImpl = iface.decodeEventLog(
    "Deployed",
    receipt1.logs[1].data,
    receipt1.logs[1].topics
  )[0];

  console.log("Implementation deployed at address: ", createdImpl);

  console.log("Deploying transaction 2");

  const deployProxy = iface.encodeFunctionData("deploy", [
    "0",
    ethers.utils.formatBytes32String(salt),
    (await proxy.getDeployTransaction(createdImpl, "0x")).data,
    initializePayload,
  ]);

  const tx2 = await admin.sendTransaction({
    data: deployProxy,
    to: create2,
    from: deployer,
  });

  console.log("Finished transaction 2");
  console.log("Transaction 2 hash: ", tx2.hash);

  const receipt2 = await tx2.wait(1);
  // console.log("Receipt 2: ", receipt2.logs);

  console.log("Decode event log of transaction 2");
  // Event: Deployed(newContract, salt, keccak256(bytecode))
  const proxyAddress = iface.decodeEventLog(
    "Deployed",
    receipt2.logs[6].data,
    receipt2.logs[6].topics
  )[0];
  console.log("Proxy deployed at address: ", proxyAddress);

  // Verify the implementation contract
  try {
    await run("verify:verify", {
      address: createdImpl,
      constructorArguments: [],
    });
  } catch (err) {
    console.log(err);
  }

  // Verify the proxy contract
  try {
    await run("verify:verify", {
      address: proxyAddress,
      constructorArguments: [createdImpl, "0x"], // (implementation, "0x")
    });
  } catch (err) {
    console.log(err);
  }

  console.log("Importing contract to force imports");
  await importRegFromC2d(proxyAddress);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
