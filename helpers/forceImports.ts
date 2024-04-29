import { ethers, upgrades } from "hardhat";

export const importRegFromC2d = async (reg: string) => {
  return upgrades.forceImport(reg, await ethers.getContractFactory("REG"));
};

export const importCcipFromC2d = async (ccip: string) => {
  return upgrades.forceImport(
    ccip,
    await ethers.getContractFactory("CCIPSenderReceiver")
  );
};
