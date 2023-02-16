# Lesson 7: 離線簽名會耗盡你的錢包 (Part 1/2)

作者: [ZenGo Wallet](https://zengo.com/)

翻譯：Helen

ZenGo Wallet團隊一直以來持續性地進行「區塊鏈與Ｗeb3資訊安全」研究，本次我們將分享Ｗeb3 去中心化應用（簡稱：dapp)的「離線簽名不同標準使用」的調查結果，並引領讀者重新審視2022年度其中一件最大型的駭客事件：OpenSea 離線簽名網站遭釣魚攻擊，導致價值數百萬美元的NFT被盜。

在本文中，我們將重新審視及說明該事件「原始攻擊手法」、評估OpenSea的「智能合約更新、緩解措施」並驗證OpenSea仍然有機會受到同樣的攻擊。

最後我們將會提供實用的建議給讀者。

### [](#key-takeaways)閱讀要點

*   離線簽名無論何時它的危險性都存在，且常常導致資產損失。這情況也存在於有效的OpenSea智能合約中。
*   舊版OpenSea智能合約更容易有此詐騙狀況。
*   即便是新版的SeaPort合約也不一定倖免於此攻擊。
*   我們在研究過程中已經見識到多種此類詐騙手法。

_**本文章第二部分將會介紹SeaPort智能合約未知的潛在攻擊向量**_

[](#opensea-original-incident-explained-wyvernv1)OpenSea 原始事件說明: WyvernV1
----------------------------------------------------------------------------------------------

根據[Cointelegraph](https://cointelegraph.com/news/opensea-monthly-volumes-top-5b-as-nfts-continue-to-mainstream)報導，在駭客事件發生前，OpenSea是交易量領先的 NFT交易平台，其2022年1月交易金額超過 $50億美金。直到2022年2月釣魚詐騙事件爆發。

### ***現在，為了更好地理解此騙局發生過程，我們先來了解OpenSea的正常上幣流程：***

### [](#step-1)第一步

*   NFT賣家首先要「授權」OpenSea智能合約作為相關 「NFT 集合」的運營商。這意味著 OpenSea 智能合約將擁有與集合中的 NFT 進行「交互」和「移動」的必要權限，以便在交易完成後將 NFT 從賣方的錢包轉移到買方的錢包。
    
*   此「授權」的功能是設計於「NFT 集合」合約中，引用EIP-721 & EIP-1155標準函數值`SetApprovalForAll`；這意味著每個 ERC721 和 ERC1155 合約（NFT）都應該在其合約代碼中包含此函數。
    
*   此函數須設定兩種參數:
    *   NFT 所有者批准管理的NFT之「地址」或「合約」。
    *   布林（原文：Boolean）值，指定 NFT 所有者是「授予」還是「撤銷」對指定地址或合約的批准。（若其狀態設定為`true`表「授予批准」）
  
    以下是用戶在平台上setApprovalForAll操作畫面：
    
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217187568-146cb7f2-3df2-4c9e-af11-eb436bd12b90.png" alt="Cover" width="60%"/>
   </div>

### [](#step-2)第二步

NFT賣家完成第一步「授權」後，為了在OpenSea應用程序UI「上架」其NFT列表參數（例如價格），會被要求「簽署」一份代表這些參數的「離線訊息」（此訊息會包含「賣家的以太坊私鑰」，以驗證賣家對 NFT 的所有權。）

一旦完成簽署，OpenSea會更新NFT狀態為「可購買狀態」。

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217187985-a72b2b88-6700-418c-8c0a-018a79cdbc25.png" alt="Cover" width="60%"/>
   </div>

### [](#step-3)第三步

當買方完成購買，系統會將「購買」的列表參數及儲存於資料庫的列表簽名回傳給智能合約驗證。當確認參與交易的各方的真實性，以及所交換數據的完整性後，合約將繼續將NFT轉移給買方，賣方則收到ETH（或其他任何代幣）。

由於簽名是銷售參數和「賣家私鑰」的衍生品，只有賣家知道正確的私鑰，潛浮的駭客無法偽造有效簽名冒充，並使用操作系統合約竊取 NFT。

為了克服此困難，詐騙者會使用極低的價格或0元標價NFT，誘騙受害者在列表訊息上簽名。

利用大部分的使用者不知道訊息參數的機制，詐遍者會使用各種釣魚手法，在OpenSea用戶不知情的情況下，騙取OpenSea用戶簽署惡意列表訊息，以獲得真正的私鑰。

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



