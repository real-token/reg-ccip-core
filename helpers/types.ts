export enum REGErrors {
  InvalidAmount = "InvalidAmount",
  InvalidLength = "InvalidLength",
  LengthNotMatch = "LengthNotMatch",
}

export enum CCIPErrors {
  NotEnoughBalance = "NotEnoughBalance",
  NothingToWithdraw = "NothingToWithdraw",
  FailedToWithdrawEth = "FailedToWithdrawEth",
  DestinationChainNotAllowlisted = "DestinationChainNotAllowlisted",
  TokenNotAllowlisted = "TokenNotAllowlisted",
  InvalidReceiverAddress = "InvalidReceiverAddress",
  InvalidContractAddress = "InvalidContractAddress",
  InvalidFeeToken = "InvalidFeeToken",
  AllowedStateNotChange = "AllowedStateNotChange",
  InvalidRouter = "InvalidRouter",
  InvalidSender = "InvalidSender",
}
