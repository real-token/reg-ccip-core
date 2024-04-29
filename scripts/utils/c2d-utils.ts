import { isAddress } from "ethers";

const notAnAddressError = "Value provided is not a valid address";
export const validate = (val: string) =>
  isAddress(val) ? true : notAnAddressError;
