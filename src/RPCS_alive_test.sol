// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

contract RPCS_alive_test is Test {
    function test_mainnet() public {
        vm.createSelectFork("mainnet");
    }
    
    function test_blast() public {
        vm.createSelectFork("blast");
    }
    
    function test_optimism() public {
        vm.createSelectFork("optimism");
    }
    
    function test_fantom() public {
        vm.createSelectFork("fantom");
    }
    
    function test_arbitrum() public {
        vm.createSelectFork("arbitrum");
    }
    
    function test_bsc() public {
        vm.createSelectFork("bsc");
    }
    
    function test_moonriver() public {
        vm.createSelectFork("moonriver");
    }
    
    function test_gnosis() public {
        vm.createSelectFork("gnosis");
    }
    
    function test_avalanche() public {
        vm.createSelectFork("avalanche");
    }
    
    function test_polygon() public {
        vm.createSelectFork("polygon");
    }
    
    function test_celo() public {
        vm.createSelectFork("celo");
    }
    
    function test_base() public {
        vm.createSelectFork("base");
    }
    
    function test_linea() public {
        vm.createSelectFork("linea");
    }
    
    function test_mantle() public {
        vm.createSelectFork("mantle");
    }
}
