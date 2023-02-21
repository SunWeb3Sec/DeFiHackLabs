# Lesson 7: 離線簽名可能會掏空你的錢包 (Part 1/2)

作者: [ZenGo Wallet](https://zengo.com/)

翻譯：Helen

ZenGo Wallet團隊一直以來持續性地進行「區塊鏈與Ｗeb3資訊安全」研究，本次我們將分享Ｗeb3 去中心化應用（簡稱：dapp)的「離線簽名不同標準使用」的調查結果，並引領讀者重新審視2022年度其中一件最大型的駭客事件：OpenSea 離線簽名網站遭釣魚攻擊，導致價值數百萬美元的NFT被盜。

在本文中，我們將重新審視及說明該事件「原始攻擊手法」、評估OpenSea的「智能合約更新、緩解措施」並驗證OpenSea仍然有機會受到同樣的攻擊。

最後我們將會提供實用的建議給讀者。

### [](#key-takeaways)要點

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

NFT賣家完成第一步「授權」後，為了在OpenSea應用程序UI上架参数（ listing parameters ）（比如價格），賣家會被要求「簽署」一份代表這些參數的「離線消息」（ offline message ）（此訊息會包含「賣家的以太坊私鑰」，以驗證賣家對 NFT 的所有權。）

一旦完成簽署，OpenSea會更新NFT狀態為「可購買狀態」。

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217187985-a72b2b88-6700-418c-8c0a-018a79cdbc25.png" alt="Cover" width="60%"/>
   </div>

### [](#step-3)第三步

當買方完成購買，系統會將「購買」的列表參數及儲存於資料庫的列表簽名回傳給智能合約驗證。當確認參與交易的各方的真實性，以及所交換數據的完整性後，合約將繼續將NFT轉移給買方，賣方則收到ETH（或其他任何代幣）。

由於簽名是銷售參數和「賣家私鑰」的衍生品，潛浮的駭客無法偽造有效簽名透過操作系統合約竊取 NFT。

為了克服此困難，詐騙者會使用極低的價格或0元出售受害者珍貴的NFT，誘騙他們在列表訊息上簽名。其利用大部分的使用者不知道訊息參數的機制，詐騙者會使用各種釣魚手法，在OpenSea用戶不知情的情況下，騙取OpenSea用戶簽署惡意列表訊息，以獲得真正的私鑰。

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217188687-4c25a904-b458-4576-a650-dd0dfd243846.png" alt="Cover" width="40%"/>
   </div>

這就是2月騙局發生的事情經過：詐騙者誘騙受害者在不知不覺中以 0 美元的價格上架他們珍貴的 NFT，從而設法積累了受害者的惡意上架簽名。 這使得詐騙者可以在遷移到新合約之前立即「購買」所有這些 NFT（價格為 0）。

[這裡](https://twitter.com/TalBeerySec/status/1495331621351968769)可以獲得更多相關資訊．

[](#the-first-migration-wyvernv2)第一次遷移：WyvernV2
--------------------------------------------------------------

OpenSea早在2022年2月攻擊發生前，便計畫搬遷至 WyvernV2，此計劃有機會作為EIP-712加快簽名的緩解措施。EIP-712 允許用戶更好地理解「訊息」，因為顯示了參數，用戶不再需要在難以理解的十六進製字符串上簽名。

然而，儘管這些參數是可見的，但非專家用戶仍然很難理解這些參數的含義。
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217191194-43d27361-16a7-4b21-bd78-985d5c0c4013.png" alt="Cover" width="40%"/>
   </div>

[](#the-latest-migration--seaport)最新遷移 ：SeaPort
------------------------------------------------------------------

2022 年 6 月，OpenSea 從上述 WyvernV2 合約遷移到其當前最新的 SeaPort 合約。遷移的主要目的是改善交易體驗並允許額外的功能，例如：集合報價、更高級的交換選項，以及通過使用更有效的實施機制來節省Gas。

[這裡](https://twitter.com/atareh/status/1528126971846066176)、 [這裡](https://twitter.com/opensea/status/1536756396158599168)可以找到有關 SeaPort 的更多信息 。

SeaPort和WyvernV2都支持 EIP-712 簽名。 儘管 SeaPort 的簽名更清晰，但它並沒有讓非專業用戶更容易理解。 其使用複雜的結構來表示上市價格和收取費用。

[](#are-we-saved-no-heres-how-we-reproduced-the-attack-on-openseas-newest-smart-contract-seaport)我們得救了嗎？ 否：以下是我們如何重現對 OpenSea 最新智能合約 (SeaPort) 的攻擊
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

因SeaPort 複雜的簽名結構，欺詐者可以輕鬆誘騙毫無戒心的用戶通過釣魚網站簽署惡意列表。這也凸顯了簽名（和交易）資訊對用戶更加透明的必要性。

使用 OpenSea 的最新版本，我們想確認攻擊是否仍然可行。 在此之前，我們必須深入研究 OpenSea 當前的 SeaPort 智能合約。簡言之，SeaPort 智能合約中上架和購買與上面描述的過程類似，但是簽名結構完全改變了：
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217193339-77b3ad8f-09b2-4af2-9dfe-72fc20cf0638.png" alt="Cover" width="80%"/>
   </div>

### ***讓我們分 3 個步驟深入研究關鍵簽名參數：***

### [](#step-1-1)第一步

上架價值由一個名為consideration的數組表示。 該數組的每個元素代表購買交易的另一個接收者。 如果選擇常規上架（非拍賣模式），startAmount 和 endAmount 則默認為相等的數值，並以 wei 計算（如果上架幣種設置為ETH，如示例中）

### [](#step-2-1)第二步

例如，如果我選擇以 1 ETH 的價格列出我的 NFT

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217193691-890743e7-2d6d-4bbb-b57f-d41c66927a4e.png" alt="Cover" width="80%"/>
   </div>

系統會自動計算 wei 中的所有對價值，然後簽名請求將顯示：

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217193898-12261641-a31b-4bb9-81c1-93c5ae68066c.png" alt="Cover" width="40%"/>
   </div>

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217193954-997e99ab-0c70-4667-a61e-4d3109fff736.png" alt="Cover" width="40%"/>
   </div>

在這個例子中，第一個考慮單元格代表要轉移到賣方地址（簽名者）的價值，第二個單元格代表要轉移到操作系統的價值（由操作系統前端自動生成），它代表 2.5% 的價值。

由於收集版稅為 0%，因此只有 2 個單元格。

### [](#step-3-1)第三步

當購買 NFT 且恢復的參數與 DB 參數匹配時：

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217194213-b8f51f6f-53d6-4e49-8110-68ea0f54686c.png" alt="Cover" width="60%"/>
   </div>

訂單將完成，SeaPort 合約會將 NFT（因為它被批准）從賣方的錢包轉移到它的新所有者——買方。

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217194395-d06081b0-e910-433e-bc9b-1dfc0f70c1f9.png" alt="Cover" width="60%"/>
   </div>

這些是在合約中表示的訂單參數：

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217194563-7b488c46-9de5-44a7-8f12-d69f28972713.png" alt="Cover" width="60%"/>
   </div>

_**[這裡](https://support.opensea.io/hc/en-us/articles/4449355421075-What-does-a-typed-signature-request-look-like-)可以找到更多關於參數的資訊**_

如您所見，「對價」是簽名中確定上市價值的唯一輸入。 如果詐騙者讓賣家簽署一份欺詐性清單（其中「對價」沒有價值），他將能夠免費拿走 NFT——假設 SeaPort 合同被批准為該集合的轉移運營商。

一旦騙子有了簽名，他就可以發送帶有用戶簽名的交易（例如使用 ethers.js 庫）。

   <div align=center>
   <a href="https://www.youtube.com/watch?v=PPdyUl5Qie4">
   <img src="https://user-images.githubusercontent.com/107821372/217198450-0873374f-1739-4c95-a4c3-da9a50e387d5.png" alt="Cover" width="80%"/>
   </a>
   </div>

[](#recommendations)給用戶的安全建議
-----------------------------------

*   用戶應該準確了解自己正在簽署的內容——在本文案例中，了解“consideration”代表出售價格至關重要。但是，在大多數情況下，我們不能期望用戶理解這種顯示的簽名結構。
    
*   用戶在簽署可用於合約的 EIP712 簽名時需格外謹慎。
    
*   針對簽名內容，錢包須為用戶提供更加直觀且易於理解的信息，並且在其他情況下警告用戶防範惡意簽名——就像 ZenGo 的 ClearSign 技術一樣。
    

[](#want-to-learn-about-part-2)想了解第 2 部分？
----------------------------------------------------------

[這裡](https://github.com/Yumistar/DeFiHackLabs-Draft2/tree/main/academy/user_awareness/07_offline_sign/7-2)





