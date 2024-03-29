import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {
  CHAIN_SELECTOR_MUMBAI,
  CHAIN_SELECTOR_SEPOLIA,
} from "../../helpers/constants";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  ...hre
}: HardhatRuntimeEnvironment) {
  const { deploy, save } = deployments;
  const { deployer } = await getNamedAccounts();

  const reg = (await deployments.get("REG")).address;
  const weth = (await deployments.get("WETH")).address;
  const linkToken = (await deployments.get("LinkToken")).address;
  const priceRegistry = (await deployments.get("PriceRegistry")).address;
  const armProxy = (await deployments.get("ARMProxy")).address;
  const tokenPool = (await deployments.get("BurnMintTokenPool")).address;
  const router = (await deployments.get("Router")).address;

  const onRamp = await deploy("EVM2EVMOnRamp", {
    from: deployer,
    args: [
      /// StaticConfig
      [
        linkToken, // address linkToken; // Link token address
        CHAIN_SELECTOR_SEPOLIA, // uint64 chainSelector; // Source chainSelector (Sepolia)
        CHAIN_SELECTOR_MUMBAI, // uint64 destChainSelector; // Destination chainSelector (Mumbai)
        "200000", // uint64 defaultTxGasLimit; // Default gas limit for a tx
        "20000000000000000000000", // uint96 maxNopFeesJuels; // Max nop fee balance onramp can have
        "0x0000000000000000000000000000000000000000", // address prevOnRamp; // Address of previous-version OnRamp
        armProxy, // address armProxy; // Address of ARM proxy
      ],

      /// DynamicConfig
      [
        router, // address router; // Router address
        1, // uint16 maxNumberOfTokensPerMsg; // Maximum number of distinct ERC20 token transferred per message
        350000, // uint32 destGasOverhead; // Gas charged on top of the gasLimit to cover destination chain costs
        16, // uint16 destGasPerPayloadByte; // Destination chain gas charged for passing each byte of `data` payload to receiver
        0, // uint32 destDataAvailabilityOverheadGas; // Extra data availability gas charged on top of the message, e.g. for OCR
        16, // uint16 destGasPerDataAvailabilityByte; // Amount of gas to charge per byte of message data that needs availability
        0, // uint16 destDataAvailabilityMultiplierBps; // Multiplier for data availability gas, multiples of bps, or 0.0001
        priceRegistry, // address priceRegistry; // Price registry address
        30000, // uint32 maxDataBytes; // Maximum payload data size in bytes
        2000000, // uint32 maxPerMsgGasLimit; // Maximum gas limit for messages targeting EVMs
      ],
      /// [] struct PoolUpdate
      [
        [
          reg, // address token; // The IERC20 token address
          tokenPool, // address pool; // The token pool address
        ],
      ],
      ///	struct Config
      [
        true, // bool isEnabled; // Indication whether the rate limiting should be enabled
        "1000000000000000000000000", // uint128 capacity; // ────╮ Specifies the capacity of the rate limiter
        "277000000000000000000", // uint128 rate; //  ───────╯ Specifies the rate of the rate limiter
      ],
      /// [] struct FeeTokenConfigArgs // TODO add WETH config in constructor
      [
        [
          linkToken, // address token; // ─────────────────────╮ Token address
          "50", // uint32 networkFeeUSDCents; //      │ Flat network fee to charge for messages,  multiples of 0.01 USD
          "1050000000000000000", // uint64 gasMultiplierWeiPerEth; // ─────╯ Multiplier for gas costs, 1e18 based so 11e17 = 10% extra cost
          "900000000000000000", // uint64 premiumMultiplierWeiPerEth; // ─╮ Multiplier for fee-token-specific premiums, 1e18 based
          true, // bool enabled; // ──────────────────────╯ Whether this fee token is enabled
        ],
        [
          weth, // address token; // ─────────────────────╮ Token address
          "50", // uint32 networkFeeUSDCents; //      │ Flat network fee to charge for messages,  multiples of 0.01 USD
          "1050000000000000000", // uint64 gasMultiplierWeiPerEth; // ─────╯ Multiplier for gas costs, 1e18 based so 11e17 = 10% extra cost
          "900000000000000000", // uint64 premiumMultiplierWeiPerEth; // ─╮ Multiplier for fee-token-specific premiums, 1e18 based
          true, // bool enabled; // ──────────────────────╯ Whether this fee token is enabled
        ],
      ],

      /// struct TokenTransferFeeConfigArgs
      [
        [
          reg, // address token; // Token address
          0, // uint32 minFeeUSDCents; // Minimum fee to charge per token transfer, multiples of 0.01 USD
          0, // uint32 maxFeeUSDCents; // Maximum fee to charge per token transfer, multiples of 0.01 USD
          0, // uint16 deciBps; // Basis points charged on token transfers, multiples of 0.1bps, or 1e-5
          0, // uint32 destGasOverhead; // Gas charged to execute the token transfer on the destination chain
          0, // uint32 destBytesOverhead; // Extra data availability bytes on top of fixed transfer data, including sourceTokenData and offchainData
        ],
      ],

      ///	struct NopAndWeight
      [
        [
          "0x9D219125a0CE10241b4eC1280c2F880475f172f1", // address nop; // Address of the node operator // first nop Ethereum => Polygon
          15, // uint16 weight; // Weight for nop rewards
        ],
      ],
    ],
    log: true,
  });
  console.log("EVM2EVMOnRamp deployed to:", onRamp.address);
};

func.tags = ["EVM2EVMOnRamp"];

export default func;

// constructor(
// 	StaticConfig memory staticConfig,
// 	DynamicConfig memory dynamicConfig,
// 	Internal.PoolUpdate[] memory tokensAndPools,
// 	RateLimiter.Config memory rateLimiterConfig,
// 	FeeTokenConfigArgs[] memory feeTokenConfigs,
// 	TokenTransferFeeConfigArgs[] memory tokenTransferFeeConfigArgs,
// 	NopAndWeight[] memory nopsAndWeights

// 	struct StaticConfig {
// address linkToken; // ────────╮ Link token address
// uint64 chainSelector; // ─────╯ Source chainSelector
// uint64 destChainSelector; // ─╮ Destination chainSelector
// uint64 defaultTxGasLimit; //  │ Default gas limit for a tx
// uint96 maxNopFeesJuels; // ───╯ Max nop fee balance onramp can have
// address prevOnRamp; //      Address of previous-version OnRamp
// address armProxy; //        Address of ARM proxy
//   }

// 	struct DynamicConfig {
// address router; // ──────────────────────────╮ Router address
// uint16 maxNumberOfTokensPerMsg; //       │ Maximum number of distinct ERC20 token transferred per message
// uint32 destGasOverhead; //               │ Gas charged on top of the gasLimit to cover destination chain costs
// uint16 destGasPerPayloadByte; //         │ Destination chain gas charged for passing each byte of `data` payload to receiver
// uint32 destDataAvailabilityOverheadGas; // ──╯ Extra data availability gas charged on top of the message, e.g. for OCR
// uint16 destGasPerDataAvailabilityByte; // ───╮ Amount of gas to charge per byte of message data that needs availability
// uint16 destDataAvailabilityMultiplierBps; // │ Multiplier for data availability gas, multiples of bps, or 0.0001
// address priceRegistry; //                │ Price registry address
// uint32 maxDataBytes; //                  │ Maximum payload data size in bytes
// uint32 maxPerMsgGasLimit; // ────────────────╯ Maximum gas limit for messages targeting EVMs
//   }

// 	struct PoolUpdate {
// address token; // The IERC20 token address
// address pool; // The token pool address
//   }

// 	struct Config {
// bool isEnabled; // Indication whether the rate limiting should be enabled
// uint128 capacity; // ────╮ Specifies the capacity of the rate limiter
// uint128 rate; //  ───────╯ Specifies the rate of the rate limiter
//   }

// 	struct FeeTokenConfigArgs {
// address token; // ─────────────────────╮ Token address
// uint32 networkFeeUSDCents; //      │ Flat network fee to charge for messages,  multiples of 0.01 USD
// uint64 gasMultiplierWeiPerEth; // ─────╯ Multiplier for gas costs, 1e18 based so 11e17 = 10% extra cost
// uint64 premiumMultiplierWeiPerEth; // ─╮ Multiplier for fee-token-specific premiums, 1e18 based
// bool enabled; // ──────────────────────╯ Whether this fee token is enabled
//   }

// 	struct TokenTransferFeeConfigArgs {
// address token; // ────────────╮ Token address
// uint32 minFeeUSDCents; // │ Minimum fee to charge per token transfer, multiples of 0.01 USD
// uint32 maxFeeUSDCents; // │ Maximum fee to charge per token transfer, multiples of 0.01 USD
// uint16 deciBps; // ───────────╯ Basis points charged on token transfers, multiples of 0.1bps, or 1e-5
// uint32 destGasOverhead; // ───╮ Gas charged to execute the token transfer on the destination chain
// uint32 destBytesOverhead; // ─╯ Extra data availability bytes on top of fixed transfer data, including sourceTokenData and offchainData
//   }

// 	struct NopAndWeight {
// address nop; // ────╮ Address of the node operator
// uint16 weight; // ──╯ Weight for nop rewards
//   }
