import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, upgrades } from "hardhat";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy, save } = deployments;
  const { deployer } = await getNamedAccounts();

  const routerArtifact = await deployments.get("Router");
  console.log("Router instance at artifact:", routerArtifact.address);
  const linkTokenArtifact = await deployments.get("LinkToken");
  console.log("LinkToken instance at artifact:", linkTokenArtifact.address);

  const CCIPSenderReceiver = await ethers.getContractFactory(
    "CCIPSenderReceiver"
  );
  const ccipSenderReceiver = await upgrades.deployProxy(
    CCIPSenderReceiver,
    [deployer, deployer, deployer, routerArtifact.address],
    { kind: "uups" }
  );
  await ccipSenderReceiver.waitForDeployment();

  const implAddress = await upgrades.erc1967.getImplementationAddress(
    await ccipSenderReceiver.getAddress()
  );

  console.log(
    "Deploy CCIPSenderReceiver Proxy to: ",
    await ccipSenderReceiver.getAddress()
  );
  console.log("Deploy CCIPSenderReceiver Impl to: ", implAddress);

  const artifact = await deployments.getExtendedArtifact("CCIPSenderReceiver");
  let proxyDeployments = {
    address: await ccipSenderReceiver.getAddress(),
    ...artifact,
  };

  await save("CCIPSenderReceiver", proxyDeployments);
};

func.id = "CCIPSenderReceiver";
func.tags = ["CCIPSenderReceiver"];

export default func;
