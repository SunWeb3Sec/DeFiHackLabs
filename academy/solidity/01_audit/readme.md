# 第一課：智能合約審計方法與技巧

Author：[Sm4rty](https://twitter.com/Sm4rty_)

Translation: [SunSec](https://twitter.com/1nf0s3cpt)

**摘要：**
本文概述了智能合約審計的方法和流程。雖然沒有通用的方法，但這篇文章提供了讓讀者如何建立自己的審計流程。此外，本文還介紹了許多審計資源和建議，以幫助你成為一位高效的合約審計師。

讓我們開始吧。

## **步驟1：閱讀文檔和開發心智模型**

在開始審計之前，首先必須先了解項目，包括技術設計、項目目標、合同類型等。有很多資料可以幫助審計師了解和掌握項目。

1. 白皮書或技術文件。
2. 程式註釋和 Natspec
3. 項目網站/Blog等。

**建立心智模型 (分析流程)**

在閱讀文檔的同時，為審計建立一個心智模型是非常關鍵的。審計將建立在你對智能合約分析的心智模型基礎上。在深入研究細節之前，我們必須對要審計的合約有一定的了解。

***一些工具可以幫助你協助完成這個過程：***

**[Solidity Metrics:](https://marketplace.visualstudio.com/items?itemName=tintinweb.solidity-metrics)**

該插件將為用[solidity](https://solidity.readthedocs.io/)編寫的項目生成程式碼量測、複雜性、調用圖和風險概況報告。它將幫助你初步了解智能合約的概況。

![https://user-images.githubusercontent.com/2865694/78451004-0252de00-7683-11ea-93d7-4c5dc436a14b.gif](https://user-images.githubusercontent.com/2865694/78451004-0252de00-7683-11ea-93d7-4c5dc436a14b.gif)

**[Solidity Visual Developer](https://marketplace.visualstudio.com/items?itemName=tintinweb.solidity-visual-auditor)**：這個插件主要是特別強調**以安全為中心的**語法和語義，例如：詳細的 Class 概要、可視圖，圖表，進階 Solidity 程式碼分析，以及對 Visual Studio Code 的優化。你可以用它來自動生成智能合約調用圖和UML圖。

![https://user-images.githubusercontent.com/2865694/57710279-e27e8a00-766c-11e9-9ca9-8cde50aa31fc.gif](https://user-images.githubusercontent.com/2865694/57710279-e27e8a00-766c-11e9-9ca9-8cde50aa31fc.gif)

## **步驟2：使用工具：**

**靜態分析工具：** 

在這一步，我們將運行一些靜態分析工具。靜態分析工具是用來分析智能合約的常見安全漏洞和容易發生的錯誤問題。靜態分析工具將大大減少你的漏報率，並幫助你偵測到人工分析不容易發現的問題。

我們可以使用[Mythx](https://mythx.io/), [Slither](https://github.com/crytic/slither), [Mythril,](https://github.com/ConsenSys/mythril) [4naly3er](https://github.com/Picodes/4naly3er), 以及其他很多工具來做掃描。

**模糊測試工具：** 

模糊測試涉及向智能合約提供大量隨機輸入並觀察其反應。模糊測試的目的是找到邊緣情況和意外行為，這可能發現安全漏洞或錯誤。 
我們可以使用[Echidna](https://github.com/crytic/echidna)、[Foundry Fuzz](https://book.getfoundry.sh/forge/fuzz-testing)或其他一些工具進行模糊處理。

需要注意的是，雖然這些工具可以提供有價值的發現並識別許多潛在的問題，但它們不能替代徹底的人工審查，這是我們的下一步。

---

## **第3步：人工程式碼分析**。

現在，我們知道了項目協議的概況，並對智能合約有了一個相應了解。讓我們深入到智能合約中，開始人工分析。開始逐行閱讀程式，以獲得對智能合約的深入了解。

像一個攻擊者一樣思考，找出可能出錯的地方。以下是我最常尋找的一些檢查。

1. 常見的智能合約錯誤
2. 關鍵功能中的訪問控制檢查
3. 檢查智能合約是否符合標準
4. 函數調用的流程
5. 檢查所有用戶控制的輸入
6. 現實的攻擊場景和邊緣案例

很多實際影響程式的 bug 和漏洞都是針對協議的。找到這些特定於協議的 bug 需要對協議有透徹的理解和一些想像力。通過集思廣益和尋找類似案例來確定協議的問題。

**程式註解：**

當審計一個複雜或龐大的函式庫時，重要的是需要記錄任何看起來有問題的東西。可以透過一些筆記軟件，如 notepad, notion, 或 Evernote。

VScode插件[Inline Bookmarks](https://marketplace.visualstudio.com/items?itemName=tintinweb.vscode-inline-bookmarks)也可以幫助你完成這個過程。在閱讀程式碼時，我們可以在發現bug或懷疑有漏洞的地方添加審計標籤。我們可以稍後輕鬆透過快捷找到它。

![https://user-images.githubusercontent.com/2865694/69681775-67803c80-10af-11ea-8e99-c79caf7781a5.gif](https://user-images.githubusercontent.com/2865694/69681775-67803c80-10af-11ea-8e99-c79caf7781a5.gif)

## **第4步：撰寫 POC**。

POC 是對一個想法的可行性證明，在智能合約審計中，它的作用是驗證該漏洞是否有效。現在我們發現了一些漏洞，我們可以使用foundry、hardhat或brownie等框架編寫一些PoC測試。下面是我們整理出寫PoC的幾種方法。

1. **單元測試**
2. **在分叉上進行開發**。
3. **模擬**

在每個 PoC 中提供足夠的註解說明是非常重要的，這既是為了我們自己快速回憶，也是為了讓其他人了解在做什麼。

## **步驟5：撰寫報告**。

一份好的報告應該包含。

1. **漏洞的摘要**：對漏洞的清晰和簡明的描述。
2. **影響**：這一部分是審計人員提供協議可能遭受的損失或損害的詳細情況。
3. **分配嚴重程度**：嚴重程度可根據影響、可能性和其他風險因素分為高、中、低或信息性。
4. **概念證明** ：一個有效的PoC可能是Hardhat/Foundry測試文件中可以觸發漏洞的攻擊腳本，或任何設法以某種方式利用項目的漏洞的代碼。
5. **緩解步驟**：在這一節中，審計師應提供關於如何緩解漏洞的建議。這將對項目有利，使其更容易解決這個問題。
6. **參考資料[可選]**：任何與該漏洞有關的外部參考鏈接。

## 彩蛋，如何提升審計能力？

1. 閱讀審計報告：特別是Code4rena和Sherlock的報告。深入了解他們的內容，以進一步加深你的知識。
2. 不僅要閱讀和了解智能合約的漏洞：還要嘗試使用Foundry/Hardhat重現該漏洞。 [DeFiVulnLabs](https://github.com/SunWeb3Sec/DeFiVulnLabs)可以作為使用Foundry重現該漏洞的有用資源。
3. 解決各種智能合約的CTF，以獲得安全研究的寶貴知識： 解出CTFs題目比其他形式的學習更有效。CTF: [Ethernaut](https://ethernaut.openzeppelin.com/)、[Damn Vulnerable DeFi Application](https://www.damnvulnerabledefi.xyz/)、[CTF Protocol](https://www.ctfprotocol.com/)、[QuillCTF](https://quillctf.super.site/)、[Paradigm CTF](https://github.com/paradigmxyz/paradigm-ctf-2021)。
4. 閱讀Immunefi的BugFix報告和最近的黑客分析：嘗試在本地重現該漏洞。 [DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs)可以作為使用Foundry複製DeFi黑客事件的有用資源。
5. 學習時做筆記是一個需要培養的重要習慣：它可以幫助你更好地保留信息，使你更容易回憶起重要的概念。在學習任何東西時都要做自己的筆記。就我個人而言，我使用Notion來記錄我的日常學習內容。
6. 通過參與社區活動保持信息暢通：一些頂級的Discord服務器可以密切注意其更新內容，如[Spearbit](https://discord.com/invite/spearbit23), [DeFiHackLabs](https://discord.gg/HtqdYn2ECa), [Secureum](https://discord.com/invite/vGebCTSfNx), [Immunefi](https://discord.com/invite/immunefi), [Blockchain Pentesting](https://discord.com/invite/5JZERC5Vxs) 等。
7. 理解金融和數學概念：一些漏洞往往需要對金融或複雜的數學計算有深刻的理解。掌握這些技能將使你在競爭中獲得優勢。
8. 最後，需要充分的睡眠時間：審計工作需要高度的注意力和精神敏銳度。如果沒有充足的睡眠和營養，你將無法完成一份出色的審計報告。

### **學習資源**
****[Guardian - Solidity Lab](https://lab.guardianaudits.com/)****

[**Auditing Mindmap**](https://github.com/Quillhash/Smart-contract-Auditing-Methodology-mindmap)

****[Initiation to Audits](https://www.youtube.com/watch?v=3xUHvx7IkfM)****

[**How to become a Smart contract Auditor**](https://cmichel.io/how-to-become-a-smart-contract-auditor/)

[**Web3 Security Library**](https://github.com/immunefi-team/Web3-Security-Library)

**[Smart Contract Auditing Heuristics](https://github.com/OpenCoreCH/smart-contract-auditing-heuristics)**

[**DeFi Hack Labs**](https://github.com/SunWeb3Sec/DeFiHackLabs)

[**3 Ways to write PoC**](https://www.joranhonig.nl/3-ways-to-write-a-proof-of-concept/)
