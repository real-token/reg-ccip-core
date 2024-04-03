# CCIP overview

## 1. CCIP architecture

RealT contracts

| Source chain          | Destination chain     |
| --------------------- | --------------------- |
| REG                   | REG                   |
| REGCCIPSenderReceiver | REGCCIPSenderReceiver |

Chainlink contracts

| Source chain      | Destination chain |
| ----------------- | ----------------- |
| Router            | Router            |
| EVM2EVMOnRamp     | EVM2EVMOffRamp    |
| BurnMintTokenPool | BurnMintTokenPool |
| LinkToken         |                   |
| PriceRegistry     |                   |
| ARMProxy          | ARMProxy          |
| ARM               | ARM               |
|                   | CommitStore       |

## 2. CCIP Chainlink

Router (1 per source/destination chain)

- Entry contract of Chainlink CCIP for other protocol contracts to interact with
- Initiating cross-chain interaction
- 1 router per chain

OnRamp (on source chain)

- Check account addresses, message size, gas limit
- 1 per lane

OffRamp (on destination chain)

- Check: message, proof of executing DON vs blessed Merkle root, tx is executed once
- Validation OK => transmit message to router, call TokenPool

TokenPool (1 per source/destination chain)

- 1 layer of ERC20
- burn/mint - lock/mint
- Rate limiting

Commit store (on destination chain)

- Committing DON store Merkle root
- RMN bless/curse before executing DON
- 1 commit store per lane on destination blockchain

Risk Management network contract
ARMProxy/ARM (1 per source/destination chain)

## 3. CCIP RealT

To enable cross-chain applications of REG token, we use Chainlink CCIP.

### 3.1 CCIPSenderReceiver contract:

We develop a CCIPSenderReceivercontract which is the entry for user to "bridge" their REG token from one chain to another chain

The contract includes:

Admin function:

- allowlistDestinationChain
- allowlistToken
- setRouter
- withdraw
- withdrawToken

User functions:

- transferTokens
- transferTokensWithPermit

View functions:

- getRouter
- getLinkToken
- getWrappedNativeToken
- getAllowlistedDestinationChains
- getAllowlistedTokens
- isAllowlistedDestinationChain
- isAllowlistedToken

### 3.2 Questions:

Questions:

- Only bridge REG or allow whitelisted tokens? => Use allowlist token to be able to transfer other token in the future
- Should we create a receiver contract on the destination chain? Or mint directly to user on destination chain?
- What to do if cross-chain tx failed (manual execution)

### 3.3 Practices:

- ccipSend: verify destination chain, optimizing gas limit for actions on destination chain
- ccipReceive:
  verify source chain, sender, router address
  setting gasLimit
- Use extraArgs to set gasLimit to be as close as possible to gas consumption (mutable, if extraArgs are left empty, a default of 200000 gasLimit will be set.)
- Prepare manual execution according to Chainlink if the transfer failed to execute on destination chain
