import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy, save } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log("Deploying ARMProxy with deployer address:", deployer);

  const armArtifact = await deployments.get("ARM");

  console.log("ARM instance at artifact:", armArtifact.address);
  console.log("Deployer address:", deployer);

  const armProxy = await deploy("ARMProxy", {
    from: deployer,
    args: [armArtifact.address],
    log: true,
  });
  console.log("ARMProxy deployed to:", armProxy.address);
};

func.tags = ["ARMProxy"];

export default func;
