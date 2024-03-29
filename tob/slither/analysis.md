# 1. Slither run:

To run Slither on REG contract and REGCCIPSender contract:

```
slither contracts/reg/REG.sol --solc-remaps '@openzeppelin=node_modules/@openzeppelin'
```

```
slither contracts/ccip/REGCCIPSender.sol --solc-remaps '@openzeppelin=node_modules/@openzeppelin @chainlink=node_modules/@chainlink'
```

# 2. Vunerabilities:

2 high severity and 2 medium problems of these contracts are found:

1. This is safe since the withdraw function can only be call by admin. The beneficiary is a trust wallet (treasury for example) to which we want to withdraw stuck ETH.

```
REGCCIPSender.withdraw(address) (contracts/ccip/REGCCIPSender.sol#187-207) sends eth to arbitrary user
Dangerous calls: - (sent) = beneficiary.call{value: amount}() (contracts/ccip/REGCCIPSender.sol#198)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#functions-that-send-ether-to-arbitrary-destinations
```

2. It is safe to interact with Chainlink Router as it is a trusted contract

```

REGCCIPSender.\_transferTokens(uint64,address,address,uint256,address) (contracts/ccip/REGCCIPSender.sol#334-418) sends eth to arbitrary user
Dangerous calls: - messageId = \_router.ccipSend{value: fees}(destinationChainSelector,evm2AnyMessage) (contracts/ccip/REGCCIPSender.sol#381-384)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#functions-that-send-ether-to-arbitrary-destinations
```

3. This is safe

```
REGCCIPSender.withdraw(address) (contracts/ccip/REGCCIPSender.sol#187-207) uses a dangerous strict equality: - amount == 0 (contracts/ccip/REGCCIPSender.sol#194)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities
```

4.  This is safe

```
REGCCIPSender.withdrawToken(address,address) (contracts/ccip/REGCCIPSender.sol#210-221) uses a dangerous strict equality: - amount == 0 (contracts/ccip/REGCCIPSender.sol#218)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities
```
