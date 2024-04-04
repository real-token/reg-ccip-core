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

We develop a CCIPSenderReceivercontract which is the entry for user to "bridge" their REG token from one chain to another chain. It has 2 main functionalities:

- transferTokens for an user to transfer token from the source chain
- ccipReceive to receive token minted on the destination chain, then transfer it to the user

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

### 3.2 Remarks:

ccipSend (transferTokens):

- verify destination chain, optimizing gas limit for actions on destination chain
- Use extraArgs to set gasLimit to be as close as possible to gas consumption (mutable, if extraArgs are left empty, a default of 200000 gasLimit will be set.)

ccipReceive:

- verify source chain, sender, router address
- emit event with all information for subgraph indexes

Prepare manual execution according to Chainlink if the transfer failed to execute on destination chain
