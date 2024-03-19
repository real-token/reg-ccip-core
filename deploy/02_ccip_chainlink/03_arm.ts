import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy, save } = deployments;
  const { deployer, admin, moderator } = await getNamedAccounts();
  console.log("deployer: ", deployer);
  console.log("moderator: ", moderator);

  const arm = await deploy("ARM", {
    from: deployer,
    args: [
      [
        [
          [deployer, admin, moderator, 2, 2],
          // [moderator, moderator, moderator, 2, 2],
        ], // voters
        1, // blessWeightThreshold
        1, // curseWeightThreshold
      ],
    ],
    // [deployer], // voters
    // 1, // blessWeightThreshold
    // 1, // curseWeightThreshold

    log: true,
  });
  console.log("ARM deployed to:", arm.address);
};

func.tags = ["ARM"];

export default func;
