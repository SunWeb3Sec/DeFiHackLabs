# Lesson 7: Offline signatures can drain your wallet (Part 1/2)

Author: [ZenGo Wallet](https://zengo.com/)

As part of our ongoing Blockchain and Web3 security research, we investigated the use of different standards of offline signatures in Web3 dapps, and revisited one of the biggest hacks in this domain: The OpenSea-related offline signature phishing attack earlier this year that resulted in the theft of NFTs valued at millions of USD.

This technical blogpost will revisit and explain the original attack, evaluate OpenSea’s upgrades & mitigation for their smart contracts, and demonstrate that OpenSea is still potentially vulnerable to such attacks. We will conclude with some practical recommendations for users.

### [](#key-takeaways)Key takeaways

*   Offline signatures can still be dangerous in many cases, oftentimes resulting in loss of assets: This includes active OpenSea contracts.
*   These scams were active on older versions of OpenSea smart contracts.
*   The updated SeaPort contract is not safe from this kind of scam;
*   We have already seen such a type of scam implemented in production.

_**Part 2 of this series will introduce an unknown potential attack vector using SeaPort**_

[](#opensea-original-incident-explained-wyvernv1)OpenSea original incident explained: WyvernV1
----------------------------------------------------------------------------------------------

OpenSea is the leading NFT trading platform with a monthly volume of more than $5B at its peak in January 2022, according to [Cointelegraph](https://cointelegraph.com/news/opensea-monthly-volumes-top-5b-as-nfts-continue-to-mainstream), shortly before the incident.

In February 2022, a phishing scam broke out. In order to better understand how the scam worked, let’s first breakdown OpenSea’s normal listing process:

### [](#step-1)Step 1

*   The NFT seller first needs to approve the OpenSea contract as an operator for the relevant NFT collection – meaning the OpenSea contract will have the permissions to move NFTs from this collection.
    
*   The destination of this transaction is the NFT collection contract, the called function named SetApprovalForAll and is part of the EIP-721 & EIP-1155 standard, means every ERC721 & ERC1155 contract (NFTs) should have this function on its code.
    
*   The function receives 2 parameters: An address (that can access your token from that specific collection) and a Boolean (which represents the state – true if we want to grant permissions)
    
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217187568-146cb7f2-3df2-4c9e-af11-eb436bd12b90.png" alt="Cover" width="60%"/>
   </div>

### [](#step-2)Step 2

Next, the seller is asked to sign an offline message that represents the listing parameters (e.g. price) that they submitted on the OpenSea application UI.

Once the seller signs that message, OpenSea updates the NFT’s status application as available for buying.

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217187985-a72b2b88-6700-418c-8c0a-018a79cdbc25.png" alt="Cover" width="60%"/>
   </div>

### [](#step-3)Step 3

When a buyer makes a purchase, they send the listing parameters to the contract along with the listing signature as stored on OS DB. The smart contract then compares the purchase parameters against the seller’s listing parameters and if they are met, the purchase event will go through successfully and the OS contract will move the NFT to the buyer and ETH (or any other token) to the seller.

Since the signature is a derivative of the selling parameters and the seller’s private key, a potential hacker cannot fake a valid signature and by that steal an NFT using the OS contract.

To overcome this obstacle, Scammers need to trick the victim to sign on a listing message, with parameters that the scammers chose, most likely selling the victim’s precious NFT for a very low price, or even zero.

To do so, scammers may apply various phishing techniques, leveraging the fact that these message parameters are unclear for most users. When the original phishing scam against OpenSea users took place, it asked the victims to sign a malicious listing message abusing the fact that it’s impossible for the victims to understand what they actually sign:

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217188687-4c25a904-b458-4576-a650-dd0dfd243846.png" alt="Cover" width="40%"/>
   </div>

And that’s what happened in the February scam: the scammers managed to accumulate malicious listing signatures from victims by tricking them into unknowingly listing their precious NFTs for the price of $0. This allowed the scammers to later “buy” all these NFTs at once (for the price of 0), right before the migration to a new contract.

More info can be found [here](https://twitter.com/TalBeerySec/status/1495331621351968769).

[](#the-first-migration-wyvernv2)The first migration: WyvernV2
--------------------------------------------------------------

OpenSea’s Migration to WyvernV2 in February 2022 was planned before the attack and was probably expedited as a mitigation.The purpose of this migration was to support the EIP-712 signatures standard. EIP-712 allows users a better understanding of the message since the parameters are shown, and users no longer need to sign off on inscrutable hexadecimal strings.

However, while the parameters are indeed visible it is still barely possible for the non expert user to understand their actual meaning.

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217191194-43d27361-16a7-4b21-bd78-985d5c0c4013.png" alt="Cover" width="40%"/>
   </div>

[](#the-latest-migration--seaport)The latest migration – (SeaPort)
------------------------------------------------------------------

In June 2022, OpenSea migrated from the aforementioned WyvernV2 contract to its current SeaPort contract, which is also the latest implementation.

The main purpose of the migration was to improve the trading experience & allow extra features like: collection offers, more advanced exchange options, and saving gas by using more efficient implementation mechanisms.

More info on SeaPort can be found [here](https://twitter.com/atareh/status/1528126971846066176) and [here](https://twitter.com/opensea/status/1536756396158599168).

Like WyvernV2, SeaPort also supports EIP-712 signatures as its signing method. Although in terms of signature clarity, SeaPort doesn’t make it easier for a non-expert user to figure out what’s going on. It uses some complex structs in order to represent the listing price and collection fees are part of that structure.

[](#are-we-saved-no-heres-how-we-reproduced-the-attack-on-openseas-newest-smart-contract-seaport)Are we saved? No: Here’s how we reproduced the attack on OpenSea’s newest Smart Contract (SeaPort)
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SeaPort’s complex signature struct allows a potential scammer to make an inexperienced user sign a malicious listing through a phishing website, which emphasizes the need of making signatures (and transactions) more transparent for users.

We wanted to see if the attack is still feasible on OpenSea’s latest version. To do so we had to take a dive into OpenSea’s current SeaPort contract

Overall In terms of the listing & buying it’s similar process as described above, but the signature structure was completely changed:

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217193339-77b3ad8f-09b2-4af2-9dfe-72fc20cf0638.png" alt="Cover" width="80%"/>
   </div>

Let’s dig in the critical signature parameters in 3 steps:

### [](#step-1-1)Step 1

The listing value is determined by an array called consideration. Each cell of that array is another recipient for the buying transaction. If choosing a regular listing (not an auction), startAmount and endAmount will be the same and are calculated in wei (in a case of ETH listing like in the example)

### [](#step-2-1)Step 2

If for example I chose to list my NFT for 1 ETH

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217193691-890743e7-2d6d-4bbb-b57f-d41c66927a4e.png" alt="Cover" width="80%"/>
   </div>

OS will automatically calculate all the consideration values in wei then the signature request will display:

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217193898-12261641-a31b-4bb9-81c1-93c5ae68066c.png" alt="Cover" width="40%"/>
   </div>

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217193954-997e99ab-0c70-4667-a61e-4d3109fff736.png" alt="Cover" width="40%"/>
   </div>

In this example, the first consideration cell represents the value to be transferred to the seller address (the signer), the second cell represents the value to be transferred to OS (which is being generated automatically by OS frontend), and it represents 2.5% of the value.

Since the collection royalties are 0% there are only 2 cells.

### [](#step-3-1)Step 3

When the NFT is purchased and the recovered parameters match the DB parameters:

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217194213-b8f51f6f-53d6-4e49-8110-68ea0f54686c.png" alt="Cover" width="60%"/>
   </div>

The order will be fulfilled and the SeaPort contract will move the NFT (since it was approved) from the seller’s wallet to its new owner – the buyer.

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217194395-d06081b0-e910-433e-bc9b-1dfc0f70c1f9.png" alt="Cover" width="60%"/>
   </div>

These are the Order parameters as being represented on the contract:

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217194563-7b488c46-9de5-44a7-8f12-d69f28972713.png" alt="Cover" width="60%"/>
   </div>

_**More info about the parameters can be found [here](https://support.opensea.io/hc/en-us/articles/4449355421075-What-does-a-typed-signature-request-look-like-).**_

As you can see, consideration is the only input in the signature that determines the listing value. If a scammer makes the seller sign a fraudulent listing (where the consideration has no value) he would be able to take the NFT for free – assuming the SeaPort contract is approved as an operator for transfer for that collection.

Once the scammer has the signature he can send a transaction with the user signature (using for example the ethers.js library).

   <div align=center>
   <a href="https://www.youtube.com/watch?v=PPdyUl5Qie4">
   <img src="https://user-images.githubusercontent.com/107821372/217198450-0873374f-1739-4c95-a4c3-da9a50e387d5.png" alt="Cover" width="80%"/>
   </a>
   </div>

[](#recommendations)Recommendations
-----------------------------------

*   Users should understand exactly what they sign – in that example it’s important to understand that ‘consideration’ represents the selling value. In most cases, though, we cannot just expect users to understand that signature structure.
    
*   **Be extra cautious** when signing EIP712 signatures that can be used in contracts.
    
*   Wallets should give a better understanding for the signature content, and in other cases warn users against malicious signatures – as with ZenGo’s ClearSign technology.
    

[](#want-to-learn-about-part-2)Want to learn about Part 2?
----------------------------------------------------------

It’s live! Read it [here](https://github.com/Yumistar/DeFiHackLabs/blob/main/tutorials/usersec/07-2/readme.md).

Give feedback


