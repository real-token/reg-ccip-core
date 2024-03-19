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

  const REG = await ethers.getContractFactory("REG");
  const reg = await upgrades.deployProxy(
    REG,
    [deployer, deployer, deployer, deployer],
    { kind: "uups" }
  );
  await reg.waitForDeployment();

  const implAddress = await upgrades.erc1967.getImplementationAddress(
    await reg.getAddress()
  );

  console.log("Deploy REG Proxy to: ", await reg.getAddress());
  console.log("Deploy REG Impl to: ", implAddress);

  const artifact = await deployments.getExtendedArtifact("REG");
  let proxyDeployments = {
    address: await reg.getAddress(),
    ...artifact,
  };

  await save("REG", proxyDeployments);
};

func.id = "REG";
func.tags = ["REG"];

export default func;
