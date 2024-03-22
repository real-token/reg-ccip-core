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

  const REGCCIPSender = await ethers.getContractFactory("REGCCIPSender");
  const regCCIPSender = await upgrades.deployProxy(
    REGCCIPSender,
    [deployer, deployer, routerArtifact.address, linkTokenArtifact.address],
    { kind: "uups" }
  );
  await regCCIPSender.waitForDeployment();

  const implAddress = await upgrades.erc1967.getImplementationAddress(
    await regCCIPSender.getAddress()
  );

  console.log(
    "Deploy REGCCIPSender Proxy to: ",
    await regCCIPSender.getAddress()
  );
  console.log("Deploy REGCCIPSender Impl to: ", implAddress);

  const artifact = await deployments.getExtendedArtifact("REGCCIPSender");
  let proxyDeployments = {
    address: await regCCIPSender.getAddress(),
    ...artifact,
  };

  await save("REGCCIPSender", proxyDeployments);
};

func.id = "REGCCIPSender";
func.tags = ["REGCCIPSender"];

export default func;
