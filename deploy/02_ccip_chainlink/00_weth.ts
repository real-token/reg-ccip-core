import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy, save } = deployments;
  const { deployer } = await getNamedAccounts();

  const weth = await deploy("WETH", {
    from: deployer,
    args: [],
    log: true,
  });
  console.log("WETH mock deployed to:", weth.address);
};

func.tags = ["WETH"];

export default func;
