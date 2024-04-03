# 1. Slither run:

To run Slither on REG contract and CCIPSenderReceiver contract:

```
slither contracts/reg/REG.sol --solc-remaps '@openzeppelin=node_modules/@openzeppelin'
```

```
slither contracts/ccip/CCIPSenderReceiver.sol --solc-remaps '@openzeppelin=node_modules/@openzeppelin @chainlink=node_modules/@chainlink'
```

# 2. Vunerabilities:

2 high severity and 2 medium problems of these contracts are found:

1. This is safe since the withdraw function can only be call by admin. The beneficiary is a trust wallet (treasury for example) to which we want to withdraw stuck ETH.

```
REGCCIPSender.withdraw(address) (contracts/ccip/REGCCIPSender.sol#187-207) sends eth to arbitrary user
Dangerous calls:
- (sent) = beneficiary.call{value: amount}() (contracts/ccip/CCIPSenderReceiver.sol#219)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#functions-that-send-ether-to-arbitrary-destinations
```

2. It is safe to interact with Chainlink Router as it is a trusted contract

```

CCIPSenderReceiver._transferTokens(uint64,address,address,uint256,address) (contracts/ccip/CCIPSenderReceiver.sol#357-439) sends eth to arbitrary user
Dangerous calls:
- messageId = _router.ccipSend{value: fees}(destinationChainSelector,evm2AnyMessage) (contracts/ccip/CCIPSenderReceiver.sol#406-409)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#functions-that-send-ether-to-arbitrary-destinations
```

3. This is safe as admin withdraw native only when there is a balance

```
CCIPSenderReceiver.withdraw(address) (contracts/ccip/CCIPSenderReceiver.sol#208-228) uses a dangerous strict equality:
				- amount == 0 (contracts/ccip/CCIPSenderReceiver.sol#215)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities
```

4.  This is safe as admin withdraw a token only when there is a balance

```
CCIPSenderReceiver.withdrawToken(address,address) (contracts/ccip/CCIPSenderReceiver.sol#231-242) uses a dangerous strict equality:
        - amount == 0 (contracts/ccip/CCIPSenderReceiver.sol#239)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities
```
