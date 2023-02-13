# Lesson 7: Offline signatures can drain your wallet (Part 2/2)

Author: [ZenGo Wallet](https://zengo.com/)

This is part 2/2 in our series on one of the most exploited issues in Web3: Offline signatures.

In [part 1/2](https://github.com/Yumistar/DeFiHackLabs/blob/main/tutorials/usersec/07/readme.md), we investigated the use of different standards of offline signatures in Web3 Dapps, and revisited one of the biggest hacks in this domain: The OpenSea-related offline signature phishing attack earlier this year that resulted in the theft of NFTs valued at millions of USD and demonstrated how it is still relevant.

***Soon after, the ZenGo wallet's security research team discovered an additional layer of vulnerabilities that had remained overlooked: ERC-20 tokens are vulnerable to hackers as well.***

In this second technical blogpost we will explore some recently-discovered attack vectors taking advantage of OpenSea’s newest smart contracts, to steal ERC-20 tokens as well and not just NFTs. Since our discovery, we responsibly disclosed our findings to OpenSea and later found evidence for actual use of such exploits as speculated by our research, in the wild against actual OpenSea users. We will conclude with some practical recommendations for users.

### Key takeaways

* Scammers can steal ERC-20 tokens by abusing SeaPort’s contract suite
* Offline signatures, including malicious ones, may be used in ways Dapps don’t expect

# Part 1 Review: SeaPort’s original NFT phishing scam, selling victim’s NFTs for free

In June 2022, [OpenSea](https://opensea.io/) migrated to the SeaPort contract. The main purpose of this migration was to improve the trading experience and allow additional features, including: Collection offers, more advanced exchange options, and gas savings by using more efficient implementation mechanisms.

   <div align=center>
   <a href="https://twitter.com/atareh/status/1528126971846066176">
   <img src="https://user-images.githubusercontent.com/107821372/217214961-07931d2a-33b2-49f8-897d-e0b7094097de.png" alt="Cover" width="60%"/>
   </a>
   </div>
   
   <div align=center>
   
   ***Rource :https://twitter.com/atareh/status/1528126971846066176***
   
   </div>
   
   <div align=center>
   <a href="https://twitter.com/opensea/status/1536756396158599168">
   <img src="https://user-images.githubusercontent.com/107821372/217215315-39b89390-e218-4245-bd9e-a56198bb2807.png" alt="Cover" width="80%"/>
   </a>
   </div>
   
   <div align=center>
   
   ***Rource :https://twitter.com/opensea/status/1536756396158599168***
   
   </div>
   
   First, in order to better understand the more recently-discovered ERC-20 scam we will briefly review the original scam process.

If you are already familiar with our [first blogpost](https://zengo.com/offline-signatures-can-drain-your-wallet-this-is-how-part-1-2/) you can skip and directly proceed below to Part 2: Using Seaport to take your ERC-20 tokens for free.
      
## SeaPort: The process of selling an NFT

### Step 1

The NFT seller first needs to approve the OpenSea contract as an operator for the relevant NFT collection – meaning the OpenSea contract will have the permissions to move the collection’s NFTs from the seller’s wallet.

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217217235-a92de2de-f2c9-4712-91f0-5c163657dd50.png" alt="Cover" width="80%"/>
   </div>
   
### Step 2

Next, the seller is asked to sign an offline message that represents the listing parameters (e.g. price) that they submitted on the OpenSea application UI.

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217217506-0765d78a-07d5-47a9-acd1-f096b8984296.png" alt="Cover" width="80%"/>
   </div>

### Step 3

The listing value is represented by an array called “consideration,” where each of the array’s cells represents a recipient of the buying transaction.

When choosing a regular listing (not auction), startAmount and endAmount will be the same and are calculated in WEI (if listing for ETH). OpenSea’s Dapp automatically calculates the value for each recipient (based on the creator fees) and prompts the user to sign:

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217217702-8c3bf44b-82d2-48be-afe2-85e00b9f9b97.png" alt="Cover" width="40%"/>
   </div>

### Step 4

Once the seller signs that message, OpenSea updates the NFT’s status application as available for buying.

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217217911-13c0b6c4-5174-4c35-ba1e-8009371db238.png" alt="Cover" width="60%"/>
   </div>
   
### Step 5

When buyers make a purchase using the OpenSea Dapp, they send the listing parameters to the contract along with the listing signature as stored on OpenSea DB. The smart contract then compares the purchase parameters against the seller’s listing parameters and if they are met, the purchase event will go through successfully and the OS contract will move the NFT to the buyer and ETH (or any other token) to the seller.

## Listing an NFT for free

The most critical step of the aforementioned listing process is the Signature, in which the OpenSea Dapp uses this signed hash signature in order to serve it to the SeaPort contract when a purchase is made.

In case the seller, for whatever reason, wants to list their NFT for free, then the consideration array is simply left empty, as they do not expect anything in return for the NFT:

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217218531-88e548c1-38c7-4f22-8c9d-b93f1139c8f4.png" alt="Cover" width="40%"/>
   </div>
   
   And the message JSON would look like this:
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217219105-ea5baa64-ca18-40d4-8b4b-08ffaa8f5d76.png" alt="Cover" width="80%"/>
   </div>

   It’s important to note that the usage of these signatures is not limited to the OpenSea Dapp. Therefore, anyone that obtains a valid signature hash of a certain listing can use it in order to process an NFT purchase using SeaPort contract, ***scammers included***.

Scammers often use malicious Dapps in order to trick victims to sign an NFT listing for free, taking advantage of the fact the message to sign is not comprehensible to most users.

# Part 2: Attackers can abuse SeaPort & take your ERC-20 tokens for free

The SeaPort protocol was designed to accommodate a wide selection of features making it extremely generic, and potentially allowing users to trade ERC-20 tokens with each other.

At the same time, OpenSea’s Dapp does not implement all the protocol’s capabilities, but puts its focus on the extensive support of NFT listings (as described earlier) and NFT offers in return for ERC-20 tokens.

## So how does the ERC-20 offer work?

For Offers (user offers an ERC-20 in favor of NFT) the process is the opposite of the listing process:

* The offerer (NFT buyer) approves SeaPort to interact with their ERC-20 token, as is often seen on OpenSea. Examples include WETH and USDC.
* The offerer (NFT buyer) signs an ERC-20 offer, for consideration they expect to get the NFT they offer for. (WETH offer in the example below).

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217219587-6c032ff2-91b5-4f10-8715-dca3d4f145dc.png" alt="Cover" width="40%"/>
   </div>
   
   In this case the offer itemType is “1”, meaning ERC-20:

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217219716-ea3ce7b6-9b52-4a75-88a1-450c76ef71ea.png" alt="Cover" width="60%"/>
   </div>

* The NFT seller needs to accept the offer by submitting the offerer’s signature to the SeaPort contract along with the listing parameters, which is typically done automatically by OpenSea‘s Dapp.
* The SeaPort contract transfers the NFT from the seller to the offerer and the offering ERC-20 tokens to the NFT seller

### Let’s review

1. The signature structure for selling NFTs is the same as for Offering NFTs to a potential buyer at a potential/set price
2. SeaPort’s contract handles ERC-20 offering the same way it handles NFT listing
3. When you offer ERC-20 for an NFT the NFT contract address will be in the consideration array
4. Technically, the consideration array can be empty (as shown before for NFT listing)

## Listing ERC-20 tokens… for free?!

Given all the information above, the astute reader is probably already wondering what happens when users sign an empty ERC-20 offering (meaning, an ERC-20 offer with an empty consideration array) in a similar manner to the empty NFT listing shown above.

The answer, it is technically possible as shown below:

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217220443-c058bfd8-f230-4b22-ba6e-41e07f06039c.png" alt="Cover" width="60%"/>
   </div>
   
Since the feature of listing an ERC20 (for any price, free included) is not supported by the OpenSea Dapp, we created our own simple Dapp, which we will use in order to sign a listing of 1 WETH for free:

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217220647-6b3f4ae4-5a79-4a60-93dc-f3760a359f16.png" alt="Cover" width="60%"/>
   </div>

To illustrate the potential attacker’s next move we will send the signature hash along with the listing parameters to the SeaPort contract in order to get that 1 WETH from the victim (on our demo we have used a local fork of Goerli using Anvil, so no real harm could be caused to any user):

   <div align=center>
   <a href="https://www.youtube.com/watch?v=zGBnkHe8Ln4&t=3s">
   <img src="https://user-images.githubusercontent.com/107821372/217204176-11012df7-1eab-41bf-a3fd-4b46a757b1ee.png" alt="Cover" width="80%"/>
   </a>
   </div>

## Responsible disclosure timeline

In early September 2022 (four months ago) when we originally discovered that potential issue and implemented a Proof of Concept (PoC) it had yet to be discovered “in the wild.”

Therefore, we decided to disclose it to OpenSea via HackerOne.

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217220840-f60fe388-578f-4197-98dc-cab30862f1f9.png" alt="Cover" width="60%"/>
   </div>
   
The OpenSea team responded that they are aware of such a capability, but won’t plan to address this potential issue as it involves phishing, which OpenSea cannot defend against.

We later discovered such variant was reported to be used in the wild, actively stealing OpenSea’s customers’ ERC-20 tokens, as seen in the tweet below:

   <div align=center>
   <a href="https://twitter.com/0xVazi/status/1577937631781986305">
   <img src="https://user-images.githubusercontent.com/107821372/217221292-d32ffe83-cdab-4447-b08b-2ce9d88a8ae6.png" alt="Cover" width="40%"/>
   </a>
   </div>
   
   <div align=center>

   ***Rource :https://twitter.com/0xVazi/status/1577937631781986305***
   
   </div>
   
   Further down this thread, the renowned security researcher (https://twitter.com/0xQuit) adds that currently not much can be done by OpenSea to thwart such attacks.
   
   <div align=center>
   <a href="https://twitter.com/0xQuit/status/1577803719508258817">
   <img src="https://user-images.githubusercontent.com/107821372/217221555-a81e2ee4-bed6-41ab-a350-cdb80d7d5579.png" alt="Cover" width="60%"/>
   </a>
   </div>

   <div align=center>

   ***Rource :https://twitter.com/0xQuit/status/1577803719508258817***
   
   </div>

# Insights and Recommendations

* Malicious signatures can be used in a way that Dapps don’t expect as scammers can send them directly to the contract and bypass the Dapp.

* Users should understand exactly what they sign – in that example it’s important to understand that ‘consideration’ represents the selling value. In most cases, though, we cannot expect users to understand the signature structure presented to them.

* ***Users should be extra cautious*** when signing EIP712 signatures that can be used in contracts.

* Wallets must offer a better understanding for the signature content, and in other cases warn users against malicious signatures – as with [ZenGo’s ClearSign technology](https://zengo.com/hello-web3-firewall/).

Having said that, we realize that currently offline signatures are hazardous and there are no practical relevant solutions for everyday users that do not require a PhD in Web3. As a result we are working on a novel paradigm to revolutionize offline signatures security.
