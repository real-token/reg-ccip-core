import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy, save } = deployments;
  const { deployer } = await getNamedAccounts();

  const routerMock = await deploy("RouterMock", {
    from: deployer,
    args: [],
    log: true,
  });
  console.log("RouterMock deployed to:", routerMock.address);
};

func.tags = ["RouterMock"];

export default func;
