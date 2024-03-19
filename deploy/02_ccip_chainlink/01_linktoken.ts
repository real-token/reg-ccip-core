import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy, save } = deployments;
  const { deployer } = await getNamedAccounts();

  const linkToken = await deploy("LinkToken", {
    from: deployer,
    args: [],
    log: true,
  });
  console.log("LinkToken deployed to:", linkToken.address);
};

func.tags = ["LinkToken"];

export default func;
