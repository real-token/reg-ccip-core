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

  const REGCCIPReceiver = await ethers.getContractFactory("CCIPSenderReceiver");
  const regCCIPReceiver = await upgrades.deployProxy(
    REGCCIPReceiver,
    [deployer, deployer, deployer,  routerArtifact.address],
    { kind: "uups" }
  );
  await regCCIPReceiver.waitForDeployment();

  const implAddress = await upgrades.erc1967.getImplementationAddress(
    await regCCIPReceiver.getAddress()
  );

  console.log(
    "Deploy REGCCIPReceiver Proxy to: ",
    await regCCIPReceiver.getAddress()
  );
  console.log("Deploy REGCCIPReceiver Impl to: ", implAddress);

  const artifact = await deployments.getExtendedArtifact("CCIPSenderReceiver");
  let proxyDeployments = {
    address: await regCCIPReceiver.getAddress(),
    ...artifact,
  };

  await save("REGCCIPReceiver", proxyDeployments);
};

func.id = "REGCCIPReceiver";
func.tags = ["REGCCIPReceiver"];

export default func;
