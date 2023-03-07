# Lesson 8 : NFT 防钓鱼指北：如何选择一款防钓鱼插件

作者：[SlowMist](https://twitter.com/SlowMist_Team)

***“我不需要知道 Jerry 是谁，在网络上做生意，你相信的就是网络上的小面板，剥掉面板，你就知道这玩意实际上有多脆弱，而事实上在那网站后面操作的真人，他们才是你需要信任的人。“
——《别相信任何人：虚拟货币悬案》***
   
## NFT 背景

2008 年 11 月 1 日，中本聪提出比特币（Bitcoin）的概念，2009 年 1 月 3 日，比特币正式诞生，而后随着全球数字经济加速发展，加密资产等概念爆热，2012 年第一个类似 NFT 的通证 Colored Coin（彩色币）诞生。彩色币由小面额的比特币组成，最小单位为一聪（比特币的最小单位）。随着技术的持续发展，时间一转来到 2021 年，NFT 迎来了爆发性增长，逐步成为市场最热的投资风向标之一。

艺术家 Beeple 的 NFT 作品《Everydays:The First 5000 Days》在佳士得官网上以 69,346,250 美元成交，虚拟游戏平台 Sandbox 上的一块虚拟土地以 430 万美元售出……随着水涨船高，层出不穷的高价项目持续刺激着人们的神经。然后在高价光环之下，NFT 也渐渐进入了犯罪分子的视野，从此开启了针对 NFT 的疯狂钓鱼、盗窃等行动。

## NFT 现状

引言这段话出自 Netflix 的自制纪录片《别相信任何人：虚拟货币悬案》，故事讲述加拿大最大加密货币交易所 QuadrigaCX 首席执行官格里·科滕离奇死亡后，他将 2.5 亿美元客户资金密码也带进了坟墓。大量惊恐的投资者拒绝接受官方的说法，他们认为格里的“死亡”具有“金蝉脱壳”的所有特征：他还活着，已经带着投资者的钱跑路了！

其实 QuadrigaCX 的故事只是 Web3 世界的冰山一角，而我们今天要聊的 NFT 世界里，被盗几乎每天都在上演，列举几个知名案例：

* 2021 年 2 月 21 日，OpenSea 用户遭到 personal_sign 类型网络钓鱼攻击，有 32 位用户签署了来自攻击者的恶意交易，导致用户部分 NFT 被盗，包括 BAYC、Azuki 等近百个 NFT，按当时价格计算，黑客获利 420 万美元；

* 2021 年 12 月 31 日，推特用户 Kramer 在推特称其点击了一个看起来像真的 NFT DApp 链接，结果这是一次网络钓鱼攻击，他的 16 个 NFT 被盗，包括 8 个 Bored Apes、7 个 Mutant Apes 和 1 个 Clonex，价值 190 万美元；

* 2022 年 4 月 29 日，周杰伦持有价值 320 万元的无聊猿 NFT 被盗；

* 2022 年 5 月 25 日，推特用户 @0xLosingMoney 称监测到 ID 为 @Dvincent_ 的用户通过发布钓鱼网站 p2peers[.]io 盗走了 29 枚 Moonbirds 系列 NFT，价值超 70 万美元；

* 2022 年 6 月 28 日，Web3 项目 Metabergs 创作者 Nickydooodles.eth 发推称，黑客使用钓鱼手段攻击了他的钱包，损失了 17 枚 ETH（约合 21,077 美元）和全部 NFT 藏品，包括 Goblintown NFT、Doodles NFT、Sandbox Land 等；

* 2022 年 11 月 1 日，KUMALEON 项目的 Discord 遭黑客入侵，攻击者通过发布钓鱼链接的方式实施攻击，导致社区用户大约 111 枚 NFT 被盗，包括 BAYC #5313 、ENS、ALIENFRENS 和 Art Blocks 等；

* 2023 年 1 月 15 日，知名博主 @NFT_GOD 因点击谷歌上的钓鱼广告链接，导致所有账户（substack、twitter 等）、加密货币以及 NFT 被盗；

* 2023 年 1 月 26 日，NFT 知名项目 Moonbirds 创始人 Kevin Rose 的钱包被盗，丢失约 40 枚 NFT，损失超过 200 万美元；

* 2023 年 1 月 28 日，NFT 知名项目 Azuki 官方 Twitter 账号被黑，导致其粉丝连接到钓鱼链接，超 122 枚 NFT 被盗，损失超过 78 万美元；

* 2023 年 2 月 8 日，一名受害者因一个存在已久的 NFT 钓鱼骗局，连接到钓鱼地址，损失超过 1,200,000 美元的 USDC；

---
 
鉴于 NFT 被盗的频发和影响严重性，慢雾科技针对 NFT 钓鱼团伙发布两次针对性追踪分析：

* 2022 年 12 月 24 日，慢雾科技首次全球披露[《朝鲜 APT 大规模 NFT 钓鱼分析》](https://mp.weixin.qq.com/s?__biz=MzU4ODQ3NTM2OA==&mid=2247496811&idx=1&sn=d8b7abf891ebd1b8ceec7b8a105ccb2d&chksm=fdde8aeccaa903fa0749587788e932abbc63a5150f6fe6e802e882fc6b4edff4ae8dfbe19ee7&scene=21#wechat_redirect)， APT 团伙针对加密生态的 NFT 用户进行大规模钓鱼活动，相关地址已被 MistTrack 标记为高风险钓鱼地址，交易数也非常多，APT 团伙共收到 1055 个 NFT，售出后获利近 300 枚 ETH。 

* 2023 年 2 月 10 日，慢雾科技再次发布 [《数千万美金大盗团伙 Monkey Drainer 的神秘面纱》](https://mp.weixin.qq.com/s?__biz=MzU4ODQ3NTM2OA==&mid=2247496989&idx=1&sn=b1129d682fb132b08aa44e380c741c66&chksm=fdde8b9acaa9028c6d506e974a2a038b28834cf26d036aab0ac1d96342a1b64dbbe0a3844212&scene=21#wechat_redirect)”，据 MistTrack 相关数据统计，Monkey Drainer 团伙通过钓鱼的方式共计获利约 1297.2 万美元，其中钓鱼 NFT 数量 7,059 个，获利 4,695.91 ETH，约合 761 万美元，占所获资金比例 58.66%；ERC20 Token 获利约 536.2 万美元，占所获资金比例 41.34%，其中主要获利 ERC20 Token 类型为 USDC, USDT, LINK, ENS, stETH。

除此之外，据慢雾区块链被黑事件档案库（Hacked.slowmist.io）和 Elliptic 的数据统计，截止 2023 年 1 月，NFT 被盗的知名安全事件有几百起，攻击者偷走了价值近 2 亿美元的 NFT。

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/221155326-b51cacf8-2a5c-4383-8ff0-6ad2d7098381.png" alt="Cover" width="80%"/>
   </div>

<div align=center>

 **資料來源 :[https://hacked.slowmist.io/](https://hacked.slowmist.io/)**

</div>

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/221155882-d9e8ebc6-c28e-44ca-b1e8-378de79784d5.png" alt="Cover" width="80%"/>
   </div>

据 SlowMist 数据显示，2022 年 NFT 盗窃案主要集中在 Ethererum 链，发生在社交媒体平台上，通过虚假域名、项目方相似域名、恶意木马、Discord 入侵发布虚假链接钓鱼等手法进行攻击，诈骗者平均每次盗窃 10 万美元。似乎不论牛市还是熊市，只有黑客在 “0 元购” 赚的盆满钵满。

那么问题来了：不管是普通用户还是项目方创始人都屡遭钓鱼攻击，面对如此恶劣的 NFT 钓鱼、欺诈环境，NFT 用户是不是就毫无办法？用户就是待宰的羔羊吗？

No！现在我们安全防御一直推行人防+技防的手段，即人员安全意识防御+技术手段防御。人员安全意识防御即个人安全意识，建议加密货币从业者可以学习下区块链黑暗森林自救手册：https://github.com/slowmist/Blockchain-dark-forest-selfguard-handbook/。

鉴于人是个复杂的高等动物，所以人员安全意识防御我们今天不展开讲，大家区块链黑暗森林自救手册好好读一下。

而技术防御手段又是什么？简单讲就是通过软硬件、浏览器插件等安全方式来保证资产等安全，而在 NFT 用户群体，浏览器交互是 90% 的 NFT 用户最常用的操作方式，也是最容易出现问题的环境，现在市场上已经有多款防钓鱼浏览器插件，下面我们来盘点与对比下，希望能给 NFT 用户一些安全指引。

## 安全插件对比

***免责提示：以下对比的几款浏览器安全插件仅从基本信息层、NFT 实时钓鱼检测层、基本操作层进行对比，慢雾仅作为中立第三方，不承担任何义务和法律责任***

下面我们来从几个角度评比下几款我们熟悉的防钓鱼浏览器插件，看看他们各自都有哪些特点：

### 1. 是否开源、安装次数、支持链、主要功能描述：

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/221156506-8ccf1f89-0605-441c-9b9b-3b1860587a70.Png" alt="Cover" width="80%"/>
   </div>

### 2. NFT 钓鱼网站、实时黑名单真实测试：

   我们找最常见的朝鲜 APT NFT 钓鱼特征和 Monkey Drainer NFT 钓鱼特征，进行实时特征扫描，找到团伙最新的钓鱼网站，发现时差 3 小时左右，来看下各个防钓鱼插件的反馈情况：

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/221156838-6bd8d891-7946-4be2-a543-1e0d35c7587d.png" alt="Cover" width="80%"/>
   </div>
    
  最新恶意 NFT 钓鱼站点：https://blur.do (发现时间为北京时间 2020-02-19 17:32:12）
    
  ### 下面为测试内容：

   **(1). PeckShieldAlert (Aegis)**
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222028232-6c1f91e0-cba0-487d-ae2e-67c6d3bec452.png" alt="Cover" width="80%"/>
   
**结果**：无任何提示，仍正常打开钓鱼网站。

   </div>

   **(2). Pocket Universe**
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222028709-a33c4694-a81e-4b5a-910e-f5de92186eec.png" alt="Cover" width="80%"/>
   
**结果**：无任何提示，仍正常打开钓鱼网站。

   </div>
   
   **(3). Revoke.cash**
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222028948-e721b975-d723-4d87-a3d1-1add5c6c3838.png" alt="Cover" width="80%"/>
   
**结果**：无任何提示，仍正常打开钓鱼网站。

   </div>
   
   **(4). Fire**
    
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222029425-ad6670cd-ef6f-4835-92ee-f873dda6baf9.png" alt="Cover" width="80%"/>
   
**结果**：无任何提示，仍正常打开钓鱼网站。

   </div>
   
   **(5). Scam Sniffer**
     
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222029997-58a2a2bf-8b89-4a6c-90da-c60ca82c76f4.png" alt="Cover" width="80%"/>
   </div> 
   
   <div align=center>
   
**结果**：提醒钓鱼网站并阻止访问钓鱼网站。

   </div>
   
   **(6). Wallet Guard**
    
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222030210-2f5d9dc4-2b37-4a7a-a55b-8d163b493947.png" alt="Cover" width="80%"/>
   <img src="https://user-images.githubusercontent.com/107821372/222030327-bf3525bc-b778-4d89-b6a9-15e7662cf45f.png" alt="Cover" width="80%"/>
   
**结果**：无任何提示，仍正常打开钓鱼网站。

   </div>
   
   **(7). MetaDock**
       
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222030561-5039e211-b460-486b-a729-54f48a71b03f.png" alt="Cover" width="80%"/>
   
**结果**：无任何提示，仍正常打开钓鱼网站。

   </div>
   
   **(8). Metashield**
          
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222030710-ab4496ce-6c51-4432-94e1-e710529ef81f.png" alt="Cover" width="80%"/>
   
**结果**：无任何提示，仍正常打开钓鱼网站。

   </div>
   
   **(9). Stelo**
             
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222030965-3a05b869-dd27-408e-b5e0-9cbf678b83a6.png" alt="Cover" width="80%"/>
   
**结果**：无任何提示，仍正常打开钓鱼网站。

   </div>
   
  为了测试 NFT 站点钓鱼的实时性、真实性，9 个安装的插件展示如下：（Ps：Wallet Guard 已展示出我所安装的插件。）

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222031182-febc0825-b129-49fd-b58e-f82f0b4e69b0.png" alt="Cover" width="80%"/>
   </div> 
   
   以上是以 3 小时时差级别的真实 NFT 钓鱼网站结果。 
   
### 3. 基本操作层测试内容

   **(1). PeckShieldAlert (Aegis)**
   
   安装后是让用户自己输入一个 Token Contract 来检测，这种方式不符合目前 NFT 用户急于第一时间知道站点是否是钓鱼网站的需求。它更像一个在线恶意合约扫描器插件。
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222040803-eab7f854-d39a-4e13-857c-1e5613c397df.png" alt="Cover" width="40%"/>
  
**personal_sign 测试**：无提示。

   </div>
   
   **(2). Pocket Universe**
   
   安装后可以知道逻辑用户触发交易时开始检测，所以在第一步用户打开 NFT 钓鱼网站时，是不能第一时间提醒用户的。我们来看下第二步：
                
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222040568-2a7b0305-2de4-419a-9e3d-1ce648993853.png" alt="Cover" width="80%"/>
   
   **personal_sign 测试**：提醒用户已经根据链上地址识别出风险地址，让用户不要签名，还是不错的，符合安全插件预期。
   
   <img src="https://user-images.githubusercontent.com/107821372/222040510-715662c3-70b2-4c4e-9efa-d920470f9560.png" alt="Cover" width="80%"/>
   </div>
   
   **(3). Revoke.cash**  
   
   第一步没有标示出 NFT 钓鱼网站，在第二步用户连接钓鱼网站后，根据链上地址识别出风险地址，提醒用户不要签名。符合安全插件预期。
                
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222040236-0330f62c-d8dd-4e4c-9085-2ede7c8599cd.png" alt="Cover" width="80%"/>
   </div>
   
   **personal_sign 测试**：
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222040141-66c221d2-05a2-473b-9777-b2e3374e3ff5.png" alt="Cover" width="80%"/>
   </div>

   **(4). Fire**
   
   第一步没有标示出 NFT 钓鱼网站，在第二步用户连接钓鱼网站后，根据链上地址没有识别出风险地址，也没有提示签名风险。但是 Fire 可以把签名预执行内容可读性显示出来，这点比较不错。
               
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222039945-30dca7b8-48be-4b70-b74f-f4314ed5f777.png" alt="Cover" width="80%"/>

**personal_sign 测试**：无提示。

   </div>
   
   **(5). Scam Sniffer**
   
   安装后用户访问 NFT 钓鱼网站时，直接提示风险并阻断了访问钓鱼网站。符合安全插件预期。
                   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222039502-41437111-c00d-451c-af10-e15acf285803.png" alt="Cover" width="80%"/>
  
**personal_sign 测试**：有提示。

   </div>
   
   **(6). Wallet Guard**
   
   安装后是在用户触发交易时开始检测，所以在第一步用户打开 NFT 钓鱼网站 时，不能第一时间提醒用户，我们来看下第二步：
               
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222039196-16093e19-b165-4ca5-aa08-15c131093f9a.png" alt="Cover" width="80%"/>
   </div> 

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222039049-d2760dd0-3d76-443b-bb74-028474923ec3.png" alt="Cover" width="80%"/>
   </div>

**personal_sign 测试**: 提醒用户现在已经标记到这个钓鱼网站（发现 Wallet Guard 有使用 Scam Sniffer 的恶意地址库），提醒有风险，不要签名，还是不错的。符合安全插件预期。
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222038829-39102d34-2de0-47fb-b84f-40301ba77dd9.png" alt="Cover" width="80%"/>
   </div> 
   
   **(7). MetaDock**
   
   安装后用户连接钓鱼网站，钓鱼网站骗取用户签名时，插件依旧没什么提示，无任何风险提示。更像是需要用户主动去提交扫描的方式，不符合安全插件预期。可能 MetaDock 不是一个防钓鱼插件？有兴趣的小伙伴可以找项目方确认下。
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222037796-1054b244-6c79-480c-8b50-953dc06852a2.png" alt="Cover" width="80%"/>
   </div>    

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222037910-91d1f009-dbab-47a5-a30a-487e02dc70f8.png" alt="Cover" width="80%"/>
   </div> 

   <div align=center>
   
**personal_sign 测试**：无提示。

   </div>
      
   **(8). Metashield**
   
   安装后与 “MetaDock”、 “PeckShieldAlert” 类似，用户连接钓鱼网站，钓鱼网站骗取用户签名时，插件依旧没什么提示，无任何风险提示。需要用户主动去提交扫描的方式，不符合安全插件预期。
                   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222037359-570ce7e1-51a6-469e-81f5-3211b065a8e3.png" alt="Cover" width="80%"/>
   
**personal_sign 测试**：无提示。

   </div>
   
   **(9). Stelo**
   
   安装后用户连接钓鱼网站，钓鱼网站骗取用户签名时，插件依旧没什么提示，无任何风险提示。
   
   **personal_sign 测试**：恶意信息提示为低风险。不符合安全插件预期。

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222036989-c8a25c21-5a3c-4141-b10b-2e03d4d03a61.png" alt="Cover" width="80%"/>
   </div> 
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222036888-e867d472-21e2-4547-9dfe-7e40a8789377.png" alt="Cover" width="80%"/>
   </div> 

   
   至此，对比结束。
   
---
   
### 最终对比结果

下图为最终对比结果：

   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222034634-8e5ccf6d-b3a6-488f-9458-c9fe05e4c789.png" alt="Cover" width="80%"/>
   </div> 
   
   在对比后，我们发现在第一步（用户打开钓鱼网站）的识别上多数安全插件都做得不够好，只有 Scam Sniffer 识别到了这个 3 小时时差的最新 NFT 钓鱼网站，在第二步（用户连接钓鱼网站）开始 eth_sign、personal_sign 签名等危险操作时，Pocket Universe、Revoke.cash、Wallet Guard  均做出了安全风险识别等提醒。
   
   但这只是目前的基础对比项，未来可能会进一步细化。
   
   测试的安全插件名称及版本号如下图：
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/222034772-444af843-0511-49c7-ae93-84b0b0790f4f.png" alt="Cover" width="80%"/>
   </div> 
   
   ***在此感谢吴说区块链的抛砖引玉；感谢以上优秀的插件项目方，虽然产品定位、对比结果各不相同，不少仍有改进的空间，但是他们的努力让区块链安全更进一步！***
   
   除此之外，推荐一个使用组合 （不构成任何建议）：
   
   1. Rabby wallet + Scam Sniffer
   2. Rabby wallet + Pocket Universe
   3. MetaMask + Pocket Universe
   4. MetaMask + Revoke.cash
   
## 写在最后

纵观区块链行业的钓鱼攻击，对个人用户来说，***风险主要在 “域名、签名” 两个核心点***，其中 90% 的 NFT 钓鱼都跟虚假域名有关。对用户来说，在进行链上操作前，提前了解目标地址的风险情况是十分必要的，如果用户在打开一个钓鱼页面时，相关的浏览器安全插件或钱包就能直接提示风险，这样就可以把风险阻断在第一步，直接阻断了用户后面的风险。就像 Web2 世界中 360 时代，直接解决了当时小白用户被病毒攻击的困扰，但它也并非解决了所有木马病毒问题，因为病毒的查杀和病毒的免杀（一种专业的躲避杀毒软件查杀技术，可以自行 Google 了解）永远存在时间差，如何做到时间差更小、样本数更快、识别更精准就决定了杀毒软件的厉害程度。

同样，在区块链、NFT 行业，如何能***第一步识别、提醒到钓鱼站点的实时情况***，在用户端快速反馈、识别出钓鱼网站，就决定了一款防钓鱼安全插件的能力；而如果相关产品因为时间差的问题没有在第一步识别到这些钓鱼域名，用户丢币的风险就大大增加；那么接下来到***第二步，用户交互时授权链接、签名步骤，如果浏览器安全插件或钱包有骗签识别，能够识别、友好的展示出用户要签名的详细信息，如授权什么币种、授权多少、授权给谁等人类可读数据***，比如 Rabby Wallet，在一定程度上也可以提示风险，一定程度上可以避免陷入资金损失的境地。

对钱包项目方来说，首先是需要进行全面的安全审计，重点提升用户交互安全部分，加强所见即所签机制，减少用户被钓鱼风险，如：

* **钓鱼网站提醒**：通过生态或者社区的力量汇聚各类钓鱼网站，并在用户与这些钓鱼网站交互的时候对风险进行醒目地提醒和告警。

* **签名的识别和提醒**: 识别并提醒 eth_sign、personal_sign、signTypedData 这类签名的请求，并重点提醒 eth_sign 盲签的风险。

* **所见即所签**: 钱包中可以对合约调用进行详尽解析机制，避免 Approve 钓鱼，让用户知道 DApp 交易构造时的详细内容。

* **预执行机制**: 通过交易预执行机制可以帮助用户了解到交易广播执行后的效果，有助于用户对交易执行进行预判。

* **尾号相同的诈骗提醒**: 在展示地址的时候醒目的提醒用户检查完整的目标地址，避免尾号相同的诈骗问题。设置白名单地址机制，用户可以将常用的地址加入到白名单中，避免类似尾号相同的攻击。

* **AML 合规提醒**：在转账的时候通过 AML 机制提醒用户转账的目标地址是否会触发 AML 的规则。
