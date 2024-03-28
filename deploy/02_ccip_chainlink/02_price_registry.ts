import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy, save } = deployments;
  const { deployer } = await getNamedAccounts();

  const linkTokenArtifact = await deployments.get("LinkToken");
  console.log("LinkToken instance at artifact:", linkTokenArtifact.address);

  const priceRegistry = await deploy("PriceRegistry", {
    from: deployer,
    args: [
      [deployer], // priceUpdaters
      [linkTokenArtifact.address], // feeTokens
      86400, // stalenessThreshold
    ],
    log: true,
  });
  console.log("PriceRegistry deployed to:", priceRegistry.address);
};

func.tags = ["PriceRegistry"];

export default func;
