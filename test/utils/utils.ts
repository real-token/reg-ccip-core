import { BigNumberish, Contract, Signature } from "ethers";
// import { splitSignature } from "ethers";

import { REG } from "../../typechain-types";

export async function getPermitSignatureERC20(
  // wallet: Wallet,
  wallet: any,
  spender: string,
  value: BigNumberish,
  deadline: BigNumberish,
  token: Contract,
  permitConfig?: {
    nonce?: BigNumberish;
    name?: string;
    chainId?: number;
    version?: string;
  }
): Promise<Signature> {
  const [nonce, name, version, chainId] = await Promise.all([
    permitConfig?.nonce ?? token.nonces(wallet.address),
    permitConfig?.name ?? token.name(),
    permitConfig?.version ?? "1",
    permitConfig?.chainId ?? wallet.provider.getNetwork().chainId,
    // permitConfig?.chainId ?? wallet.getChainId(),
  ]);

  return Signature.from(
    await wallet.signTypedData(
      {
        name,
        version,
        chainId,
        verifyingContract: token.address,
      },
      {
        Permit: [
          {
            name: "owner",
            type: "address",
          },
          {
            name: "spender",
            type: "address",
          },
          {
            name: "value",
            type: "uint256",
          },
          {
            name: "nonce",
            type: "uint256",
          },
          {
            name: "deadline",
            type: "uint256",
          },
        ],
      },
      {
        owner: wallet.address,
        spender,
        value,
        nonce,
        deadline,
      }
    )
  );
}
