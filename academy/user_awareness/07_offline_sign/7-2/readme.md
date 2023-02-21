# Lesson 7: 离线签名可能掏空你的钱包 (Part 2/2)

Author: [ZenGo Wallet](https://zengo.com/)

翻譯: [GoPlus Security](https://twitter.com/GoplusSecurity)

这是 zengo 此前发布的「Web3 中最常见的漏洞利用」系列之第 2部分：离线签名。

在[第1部分](https://github.com/Yumistar/DeFiHackLabs-Draft2/tree/main/academy/user_awareness/07_offline_sign/7-1)，我们调研了 Web3 Dapp 中关于离线签名的不同标准的使用，并重新审视了该领域最大的黑客攻击之一：今年早些时候 OpenSea的一次网络钓鱼攻击事件导致价值数百万美元的 NFT 被盗，而此次黑客事件证明了与离线签名漏洞利用具有相关性。

***不久之后，ZenGo 发现了另一个一直被忽视的漏洞：ERC-20 代币也容易受到黑客攻击。***

接下来的这篇技术博文中，我们将探索一些最近发现的攻击向量，它们利用 OpenSea 最新的智能合约来窃取 ERC-20 代币，而不仅仅是 NFT。自发现该漏洞以来，我们已向 OpenSea 披露了该漏洞，在这之后，我们发现在我们研究中披露的漏洞确实在 OpenSea 用户身上发生了。文章的最后，我们也为用户提供了一些实用的建议。

### 要点：

* 诈骗者可通过滥用 SeaPort 合约套件来窃取 ERC-20 代币

* 离线签名（包括恶意签名）可以以一种意想不到的方式用于 Dapp

# 第一部分回顾：原生于SeaPort的NFT钓鱼骗局，可使受害者免费出售自己的NFT

2022 年 6 月，OpenSea 迁移至 SeaPort 合约。此次迁移的主要目的是改善交易体验，并新增一些其他功能，包括：藏品系列范围内的出价（Collection offers）、高级交易选项，以及通过使用更加有效的部署机制降低 gas 费。

   <div align=center>
   <a href="https://twitter.com/atareh/status/1528126971846066176">
   <img src="https://user-images.githubusercontent.com/107821372/217214961-07931d2a-33b2-49f8-897d-e0b7094097de.png" alt="Cover" width="60%"/>
   </a>
   </div>
   
   <div align=center>
   
   ***Source :https://twitter.com/atareh/status/1528126971846066176***
   
   </div>
   
   <div align=center>
   <a href="https://twitter.com/opensea/status/1536756396158599168">
   <img src="https://user-images.githubusercontent.com/107821372/217215315-39b89390-e218-4245-bd9e-a56198bb2807.png" alt="Cover" width="80%"/>
   </a>
   </div>
   
   <div align=center>
   
   ***Source :https://twitter.com/opensea/status/1536756396158599168***
   
   </div>
   
   首先，为了更好地理解最近发现的 ERC-20 骗局，这里将简要回顾一下这类骗局的流程。如果你已经读过我们发布的[第一篇博文](https://zengo.com/offline-signatures-can-drain-your-wallet-this-is-how-part-1-2/)，那么可以跳过此部分，直接阅读下面的第 2 部分：使用 Seaport 免费拿走你的 ERC-20 代币。
      
## 在 SeaPort 出售 NFT 的流程

### 第 1 步

NFT 卖家首先需要批准 OpenSea 合约对相应 NFT 系列的操作权，这意味着 OpenSea 合约将有权限从卖家钱包中移走该 NFT系列。

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217217235-a92de2de-f2c9-4712-91f0-5c163657dd50.png" alt="Cover" width="80%"/>
   </div>
   
### 第 2 步：

接下来，卖家被要求签署一条离线消息（ offline message ），该消息代表他们在 OpenSea 应用的 UI 上提交的上架参数（ listing parameters ）（比如价格）。


   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217217506-0765d78a-07d5-47a9-acd1-f096b8984296.png" alt="Cover" width="80%"/>
   </div>

### 第 3 步：

上架 NFT的数值由一个名为consideration的数组表示，该数组中的每一个元素代表购买交易的一个接收者。

如果选择常规上架（非拍卖）模式， startAmount和endAmount 则默认为相等的数值，会以WEI来进行计量（如果上架币种设置为ETH）。OpenSea 的 Dapp 会自动计算出每个接收者的出价数值（基于创作者设置的费用），并提示用户签名：

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217217702-8c3bf44b-82d2-48be-afe2-85e00b9f9b97.png" alt="Cover" width="40%"/>
   </div>

### 第 4 步：

一旦卖家签署该消息后，OpenSea 会将 NFT 的状态应用更新为可供购买。

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217217911-13c0b6c4-5174-4c35-ba1e-8009371db238.png" alt="Cover" width="60%"/>
   </div>
   
### 第 5 步：

当买家使用 OpenSea Dapp 购买NFT时，上架参数连同存储在 OpenSea DB 中的上架签名一起发送至合约。然后，智能合约会对购买参数和卖家的上架参数进行比较，如果条件满足，这次购买事件将被成功执行，OpenSea合约会将 NFT 转移给买方，将 ETH（或任何其他代币）转移给卖方。

## 免费上架 NFT

上述上架过程中最关键的一步是签名，其中， OpenSea Dapp 会使用这个已签署过的哈希签，当购买发生时将其提供给 SeaPort 合约。

如果卖家出于某种原因想要免费上架自己的 NFT，那么 consideration 数组就会留空：

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217218531-88e548c1-38c7-4f22-8c9d-b93f1139c8f4.png" alt="Cover" width="40%"/>
   </div>
   
   这条 JSON 信息长成以上这样：
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217219105-ea5baa64-ca18-40d4-8b4b-08ffaa8f5d76.png" alt="Cover" width="80%"/>
   </div>
   需要注意的是，这些签名的使用，不局限于 OpenSea Dapp，事实上，任何人，只要获取了一个有效的NFT上架签名哈希，就可以使用该签名来处理基于 SeaPort 合约的 NFT 购买，包括骗子。
   
鉴于目前大多数用户无法理解这种签署消息的原理，因此，诈骗者会通过这类 Dapp 骗局诱骗受害者对以免费价格上架NFT进行签名。


# 第 2 部分：攻击者滥用 SeaPort ，免费拿走你的 ERC-20 代币

SeaPort 协议为用户提供一系列通用的功能选择，允许用户之间交易各种 ERC-20 代币。
 
同时，OpenSea 的 Dapp 并没有实现该协议的所有功能，仅提供两项关键功能，分别是支持 NFT上架的扩展功能（如前所述）和允许以不同的 ERC-20 代币对 NFT 进行报价。

## 那么， ERC-20报价的工作原理是什么样的呢？

报价端（用户用一种ERC-20 代币对NFT进行报价）的流程和上架的流程正好相反：

* 报价者（NFT 买家）批准 SeaPort 与自己的 ERC-20 代币进行交互，这在 OpenSea 上很常见。比如 WETH 和 USDC。
* 报价者（NFT 买家）对以 ERC-20 代币报价进行签名，以获得他们报价的 NFT。 （下例中以 WETH 报价）。

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217219587-6c032ff2-91b5-4f10-8715-dca3d4f145dc.png" alt="Cover" width="40%"/>
   </div>
   
   在该案例中，报价的 itemType 为“1”，表示 ERC-20：

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217219716-ea3ce7b6-9b52-4a75-88a1-450c76ef71ea.png" alt="Cover" width="60%"/>
   </div>

* NFT 卖家如果接受该报价，需要向SeaPort合约提交报价者的签名和上架参数，这个操作通常会由 OpenSea 的 Dapp 自动完成。 
* SeaPort 合约将 NFT 从卖方转给报价者，并将报价者的 ERC-20 代币转给 NFT 卖方

### 回顾一下：

1. 出售 NFT 的签名结构与以潜在/设定价格向潜向买家出价 NFT 的签名结构相同；
2. SeaPort 合约处理 ERC-20代币出价的方式与处理 NFT上架的方式相同
3. 当用户用ERC-20代币对 NFT进行出价时，该NFT 的合约地址将会进入 consideration 数组中
4. 从技术上讲，consideration 数组可以为空（如此前 NFT 上架所示）

## 以免费的价格上架出售ERC-20 代币？ 

看到这里，精明的读者可能会问，当用户以上述所示免费上架NFT 的方式免费上架ERC-20 代币时（也就是说，以一个空的consideration数组对对 ERC-20代币报价）时会发生什么？

技术原理如下图：

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217220443-c058bfd8-f230-4b22-ba6e-41e07f06039c.png" alt="Cover" width="60%"/>
   </div> 
   
   由于 OpenSea Dapp 不支持（包括以任何价格，包括免费） ERC20 代币上架功能，我们创建了一款简单的 Dapp，可以用来对 1 WETH 免费上架进行签名。

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217220647-6b3f4ae4-5a79-4a60-93dc-f3760a359f16.png" alt="Cover" width="60%"/>
   </div>
   
   为了说明潜在攻击者的下一步行动，我们将签名哈希连同上架参数一起发送到 SeaPort 合约，以便从受害者那里获得 1 WETH（在我们的演示中，我们通过 Anvil 使用了 Goerli 本地分支，所以没有对用户产生真正的伤害）：
   从视频中可以看出，一旦攻击者获得受害者对该1 WETH 免费上架操作的签名，他们就可以简单地将其提供给 SeaPort 智能合约。

   <div align=center>
   <a href="https://www.youtube.com/watch?v=zGBnkHe8Ln4&t=3s">
   <img src="https://user-images.githubusercontent.com/107821372/217204176-11012df7-1eab-41bf-a3fd-4b46a757b1ee.png" alt="Cover" width="80%"/>
   </a>
   </div>

## 负责任的披露时间线

2022 年 9 月初（本文发布的四个月前），当我们最初发现该签名导致的潜在问题并实施概念验证 (PoC) 时，它尚未在用户操作中实际发生。
 
因此，我们决定通过 HackerOne 将它披露给 OpenSea。


   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/217220840-f60fe388-578f-4197-98dc-cab30862f1f9.png" alt="Cover" width="60%"/>
   </div>
   
OpenSea 团队回应表示，虽然他们知道这种攻击的存在，但因为涉及OpenSea 无法防御的网络钓鱼，因此，他们不能解决这个潜在的问题。
 
之后，我们发现有媒体报道这种攻击的变种正发生，以窃取 OpenSea 客户的 ERC-20 代币，如以下推文所示：

   <div align=center>
   <a href="https://twitter.com/0xVazi/status/1577937631781986305">
   <img src="https://user-images.githubusercontent.com/107821372/217221292-d32ffe83-cdab-4447-b08b-2ce9d88a8ae6.png" alt="Cover" width="40%"/>
   </a>
   </div>
   
   <div align=center>

   ***Source :https://twitter.com/0xVazi/status/1577937631781986305***
   
   </div>
   
   这条thread的最后一条，知名安全研究人员 (https://twitter.com/0xQuit) 补充说，目前 OpenSea 无法阻止此类攻击。
   
   <div align=center>
   <a href="https://twitter.com/0xQuit/status/1577803719508258817">
   <img src="https://user-images.githubusercontent.com/107821372/217221555-a81e2ee4-bed6-41ab-a350-cdb80d7d5579.png" alt="Cover" width="60%"/>
   </a>
   </div>

   <div align=center>

   ***Source :https://twitter.com/0xQuit/status/1577803719508258817***
   
   </div>

# 给用户的安全建议

* 恶意签名可以以意想不到的方式用于 Dapp ，因为诈骗者可以将它们直接发送到合约，并绕过 Dapp。

* 用户应该准确了解自己正在签署的内容——在本文案例中，了解“consideration”代表出售价格至关重要。但是，在大多数情况下，我们不能期望用户理解这种显示的签名结构。

* 用户在签署可用于合约的 EIP712 签名时需格外谨慎。

* 针对签名内容，钱包须为用户提供更加直观且易于理解的信息，并且在其他情况下警告用户防范恶意签名——就像 ZenGo 的 ClearSign 技术一样。

话虽如此，我们意识到目前的离线签名是危险的，并且对于普通用户来说，没有实际可用的解决方案。因此，我们正在研究一种新型范例，以彻底改善离线签名的安全性。
