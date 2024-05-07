REG (RealToken Ecosystem Governance) is an ERC20 governance token of the ecosystem.

It inherits Openzeppelin token implementation/access control and UUPS upgradeable:

- ERC20Upgradeable
- ERC20PausableUpgradeable
- ERC20PermitUpgradeable
- AccessControlUpgradeable
- UUPSUpgradeable

Besides, we also implement/modify several other functions to adapt our needs:

- mint (used by CCIP Bridge for cross-chain, does not change total supply on all chains)
- burn (used by CCIP Bridge for cross-chain, does not change total supply on all chains)
- mintByGovernance (used by governance to mint new token, change total supply on all chains)
- mintBatchByGovernance (used by governance to mint new token, change total supply on all chains)
- burnByGovernance (used by governance to burn tokens on the contract, change total supply on all chains)
- transferBatch (used by users when wanting to transfer a batch of tokens to multiple addresses)

Additionnal events:

- MintByGovernance (emitted when governance mint new tokens)
- BurnByGovernance (emitted when governance burn tokens holding by REG contract)
- MintByBridge (emitted when CCIP mint tokens to receiver on destination chain during a cross-chain transfer)
- BurnByBridge (emitted when CCIP burn tokens on source chain during a cross-chain transfer)
- RecoverByGovernance (emitted when governance recover an ERC20 token accidently sent to REG contract)
