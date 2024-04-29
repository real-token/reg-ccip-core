import { isAddress } from "ethers/lib/utils";

const notAnAddressError = "Value provided is not a valid address";
export const validate = (val: string) =>
  isAddress(val) ? true : notAnAddressError;
