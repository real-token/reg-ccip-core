import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy, save } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log("Deploying TokenPool with deployer address:", deployer);

  const regArtifact = await deployments.get("REG");
  console.log("REG instance at artifact:", regArtifact.address);
  const armProxyArtifact = await deployments.get("ARMProxy");
  console.log("ARMProxy instance at artifact:", armProxyArtifact.address);

  const tokenPool = await deploy("BurnMintTokenPool", {
    from: deployer,
    args: [
      regArtifact.address, // token address to pool
      [], // allowlist (permissioned) or empty for all
      armProxyArtifact.address, // arm proxy address
    ],
    log: true,
  });
  console.log("BurnMintTokenPool deployed to:", tokenPool.address);
};

func.tags = ["BurnMintTokenPool"];

export default func;
