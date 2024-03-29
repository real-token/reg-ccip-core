# 1. Echina setup:

Set up Echina using TrailOfBits eth-security-toolbox and docker

```
docker run -it -v /$(PWD):/home/reg-ccip-core trailofbits/eth-security-toolbox

docker run -it -v /$(PWD):/home/reg-ccip-core trailofbits/echidna

docker run -it -v /$(PWD):/home/reg-ccip-core ghcr.io/crytic/echidna/echidna
solc-select install 0.8.19
solc-select use 0.8.19
```

cd home/reg-ccip-core

Run Echidna fuzzing tests using commands:

```
echidna --config echidna-config.yaml tob/echidna/FuzzREG.sol --contract FuzzREG
echidna --config echidna-config.yaml tob/echidna/FuzzREGCCIPSender.sol --contract FuzzREGCCIPSender
```
