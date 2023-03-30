# Lesson 3: 流動性質押審計指南

作者: [QuillAudits](https://twitter.com/QuillAudits)

翻譯: [SunSec](https://twitter.com/1nf0s3cpt)

本文概述了流動性質押協議的概念以及用於評估這些協議的審計指南。這些指南涵蓋了一系列易受攻擊的地方，例如提款機制、取整誤差、外部調用、手續費邏輯、loops、structs、鎖定期限等等。

這篇文章將成為審計流動性質押協議的有用參考，有助於幫助您發現潛在的問題。

## 流動性質押是什麼?

流動性質押是一種讓使用者可以質押其加密貨幣並賺取回報，同時不會犧牲流動性的方法。使用者不需要將其貨幣質押並鎖倉在固定時間內，而是可以獲得一個代表其質押資產的流動代幣。這個代幣可以像任何其他加密貨幣一樣進行交易或使用，使得使用者可以自由地使用其資產，同時仍然賺取貨幣質押的回報。
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/220809684-2dafef16-a5b6-48d9-b37e-bdcbe9ae3a1c.png" alt="Cover" width="80%"/>
   </div>
   
例如，假設您有100 ETH想在以太坊網絡上進行貨幣質押。您可以使用像Lido這樣的流動性質押服務，將您的ETH進行質押，並以一種名為stETH的流動代幣作為回報。使用stETH，您可以在賺取貨幣質押回報的同時，仍然可以交易或使用您的stETH。

## 讓我們開始審計流動性質押合約

在開始分析合約程式碼之前，先看官方提供的技術文件，這可能是白皮書、README文件或其他文件。這些文件會介紹項目架構，合約程式碼，專有名詞的概念。

### 在檢查質押合約的規範文件時，請優先看以下幾點：

* 收費類型及其計算方式
* 貨幣質押機制的回報方式
* 所有者的權限
* 合約是否持有ETH？
* 合約將持有哪些代幣？
* 從哪個原始合約中分叉而來

檢查規範與程式碼是否匹配。首先檢查手續費和代幣經濟學，然後驗證所有者的權限。檢查所有的回報和手續費值是否符合文件要求。

## 哪些地方容易產生問題?

1. 獎勵提取機制

   檢查貨幣質押的獎勵機制是否正確實現，以及獎勵是否按比例公平地分配給所有參與者。
   項目可以通過兩種方式分發獎勵：自動定期或在用戶請求時。提款函數可以根據協議的業務邏輯進行實現和定制。
   
   以下是一些檢查點：

   * 檢查是否有任何用戶能夠提取超過其獎勵+質押金額的代幣
   * 檢查計算金額時是否存在溢出/下溢的情況
   * 檢查在計算過程中是否存在某些參數可能對獎勵產生負數
   * 如果此函數中使用了`block.timestamp`或`block.number`，請檢查是否存在可能被利用的漏洞
   
2. 手續費計算：

   如果存款和提款需要支付一些手續費，請確認沒有任何用戶可以繞過此費用。此外，要警惕任何可能的溢出或下溢問題。只有管理員或合約所有者有權更改手續費。同時，請確認已經建立了最大手續費閾值，以防止管理員將其設置為過高的金額。
   
3. LP 代幣鑄幣/銷毀機制：

   驗證代幣鑄造和銷毀機制是否已正確實施，銷毀功能應該要能撤銷所有由鑄造功能所做的狀態更改，以確保代幣的總供應量保持準確。
   此外，當資金池為空時，驗證用戶是否收到了適當數量的代幣是至關重要的。
   
   鑄造和銷毀功能的邏輯應進行數學驗證，以檢核任何潛在漏洞。同時，代幣的總供應量不應超過質押的資產。

4. 取整誤差 (4捨5入)：

   雖然某些微小的捨入誤差通常是無法避免和無需擔憂的，但當可能會對其進行乘法運算時，這些誤差可能會顯著增加。極端的情況是，攻擊者可以通過反覆質押和贖回從舍入誤差中獲利。
   
   為了確定在較長時間內舍入誤差是否會積累到大量資產，我們可以在數學上計算可能的捨入誤差範圍。

5. 質押期限：

   確保合約中的質押期限計算與指定的業務邏輯相符。驗證用戶不能通過繞過期限檢查在質押期限結束之前贖回獎勵。還要檢查質押期限是否可以被攻擊者利用以獲取更多獎勵。

6. 外部調用和代幣處理：

   大多數外部調用將是對代幣合約的調用。因此，我們必須確定質押合約將處理哪些類型的代幣。必須檢查外部調用是否存在任何錯誤和可重入攻擊。如果未正確實現通縮型代幣或具有轉賬費用的代幣（如Safemoon），可能會出現問題。

7. 價格操縱檢查：

   通過閃電貸進行價格操縱是DeFi項目最常見的黑客攻擊之一。可能存在攻擊者可以利用閃電貸在大量代幣質押或贖回期間操縱價格的情況。仔細審查質押和贖回函數，以避免可能導致基於閃電貸的價格操縱攻擊和其他用戶資金損失的極端情況。

8. 其他檢查：

   * Loops：如果合約邏輯涉及循環迴圈，則必須確保沒有超過塊燃料限制。當 Array 大小非常大時，可能會發生 out of gas 錯誤，因此您應該檢查可能增加 Array 大小的函數以及是否有任何用戶可以利用它來引發DoS攻擊.請查看此[報告](https://www.google.com/url?q=https://github.com/code-423n4/2022-06-putty-findings/issues/227&sa=D&source=docs&ust=1677128054454294&usg=AOvVaw3gM91sQvOggH5Uok1ldQHK)。
   
   * Structs：Staking 合約使用結構體類型來存儲用戶或流動池的數據。在函數中聲明或訪問結構體時，重要的是要指定使用“memory”或“storage”。這可能有助於節省一些Gas，但會造成計算不準確。有關更多信息，請參閱[本文](https://medium.com/coinmonks/ethereum-solidity-memory-vs-storage-which-to-use-in-local-functions-72b593c3703a)。
   
   * 搶跑交易 (Front-Running)：攻擊者可能利用的搶跑交易。
   
   * 函數可見性/訪問控制檢查：任何聲明為外部或公共的函數都可以被任何人訪問。因此，重要的是確保沒有公共函數可以執行任何敏感操作。必須驗證stake協議已實施適當的控制以防止未經授權訪問被質押的代幣和系統基礎架構。
   
   * 集中化風險：重要的是不要給予所有者過多的權力。如果管理員地址被駭，這可能會對協議造成重大損失。請驗證所有者或管理員特權是否適當，並確保協議有應對管理員私鑰泄露的計劃。
   
   * ETH / WETH處理：合約通常包含用於處理ETH的特定邏輯。例如，當`msg.value> 0`時，合約可以將ETH轉換為WETH，同時仍然允許直接接收WETH。當用戶指定WETH作為代幣但使用發送ETH時，這可能會破壞某些不變數並導致不正確的行為。
   
  到目前為止，我們已經討論了流動性代幣質押協議以及此類協定的審計指南。
  
  簡言之，代幣質押協議允許使用者在不犧牲流動性的情況下賺取額外獎勵。我們已經概述了審計人員必須注意的質押合約中的常見問題，例如提款機制、手續費邏輯、LP 代幣鑄造/銷毀機制、捨入錯誤、質押期限、外部調用和價格操縱檢查。
  
  我們建議審計人員檢查項目官方技術件，將規格與程式碼進行比對，檢查費用和代幣經濟模型驗證。除此之外，我們還建議進行一些額外的檢查，例如對 Array 進行迴圈，Struct 指定為 memory或 storage，以及搶跑交易等場景。這些指南將對審計流動性質押協議有所幫助，並有助於發現潛在的問題。

## 延伸閱讀:

[DeFi Risk 101- An insecure fork of Masterchef](https://www.google.com/url?q=https://inspexco.medium.com/defi-risks-101-1-an-insecure-fork-of-masterchef-b44ca01b4e5e&sa=D&source=docs&ust=1677132410175689&usg=AOvVaw180xhoJbIov48c7otX-LlK)

[Polygon Yield Farm Exploit](https://www.google.com/url?q=https://cryptobriefing.com/polygon-yield-farm-crashes-zero-after-exploit/&sa=D&source=docs&ust=1677132417868263&usg=AOvVaw3h-b8eV6YHprUvDCb5DGor)

[SCSVS V2- Liquid Staking](https://www.google.com/url?q=https://github.com/ComposableSecurity/SCSVS/blob/master/2.0/0x200-Components/0x207-C7-Liquid-staking.md&sa=D&source=docs&ust=1677132424183933&usg=AOvVaw1KnZ5FOjTnpl1ay_CkeOQq)

[Security Risks of Staking Providers](https://www.google.com/url?q=https://runtimeverification.com/blog/security-risks-for-staking-providers/&sa=D&source=docs&ust=1677132434840543&usg=AOvVaw0ZUTVBM3VcTiX60hPvCxBM)

[Liquid Staking](https://www.google.com/url?q=https://www.finoa.io/blog/guide-liquid-staking/&sa=D&source=docs&ust=1677132447838820&usg=AOvVaw2RvZflu_I4ZGsWCIF3FTyW)

[Smart contract Auditing Heuristics](https://www.google.com/url?q=https://github.com/OpenCoreCH/smart-contract-auditing-heuristics&sa=D&source=docs&ust=1677132459011494&usg=AOvVaw2PFAeuRVmqqltA3XLrHDYJ)

## 審計報告樣本:

[Euler Staking](https://github.com/Quillhash/QuillAudit_Reports/blob/master/Euler%20Staking%20Smart%20Contract%20Audit%20Report%20-%20QuillAudits.pdf)

[BollyStake](https://www.google.com/url?q=https://github.com/Quillhash/QuillAudit_Reports/blob/master/BollyStake%2520Smart%2520Contract%2520Audit%2520Report(new)%2520-%2520QuillAudits.pdf&sa=D&source=docs&ust=1677132477727119&usg=AOvVaw1NkvRag04h1SouBSPxsK4u)

[Stakehouse](https://code4rena.com/reports/2022-11-stakehouse/)

[PolyNuts Masterchef](https://github.com/Quillhash/QuillAudit_Reports/blob/master/PolyNuts%20Smart%20Contract%20Audit%20Report%20-%20QuillAudits.pdf)

[Pancakeswap Masterchef](https://certik-public-assets.s3.amazonaws.com/REP-PancakeSwap-16_10_2020.pdf)
