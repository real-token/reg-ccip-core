import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ZERO_ADDRESS } from "../../helpers/constants";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy, save } = deployments;
  const { deployer } = await getNamedAccounts();

  const armProxyArtifact = await deployments.get("LinkToken");
  console.log("ARMProxy instance at artifact:", armProxyArtifact.address);

  const router = await deploy("Router", {
    from: deployer,
    args: [ZERO_ADDRESS, armProxyArtifact.address],
    log: true,
  });
  console.log("Router deployed to:", router.address);
};

func.tags = ["Router"];

export default func;
