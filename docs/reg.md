REG (RealToken Ecosystem Governance) is an ERC20 governance token of the ecosystem.

It inherits Openzeppelin token implementation:

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

- MintByGovernance
- BurnByGovernance
- MintByBridge
- BurnByBridge
- RecoverByGovernance
