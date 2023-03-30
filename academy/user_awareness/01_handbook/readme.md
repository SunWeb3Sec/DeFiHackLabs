# Lesson 1: 区块链黑暗森林自救手册

Author: [SlowMist](https://twitter.com/SlowMist_Team)

## 前言

区块链是个伟大的发明，它带来了某些生产关系的变革，让「信任」这种宝贵的东西得以部分解决。但，现实是残酷的，人们对区块链的理解会存在许多误区。这些误区导致了坏人轻易钻了空子，频繁将黑手伸进了人们的钱包，造成了大量的资金损失。这早已是黑暗森林。

基于此，慢雾科技创始人[余弦](https://twitter.com/evilcos)倾力输出—— **区块链黑暗森林自救手册**。

<div align=center>
<img src="https://user-images.githubusercontent.com/107821372/212235792-09f72df1-2bcd-41c7-80a0-1500fd8d50a3.png" alt="Cover" width="80%"/>
</div>

**本手册（当前 V1 Beta）大概 3 万 7 千字，由于篇幅限制，这里仅罗列手册中的关键目录结构，也算是一种导读。完整内容可见：**

[https://github.com/slowmist/Blockchain-dark-forest-selfguard-handbook](https://github.com/slowmist/Blockchain-dark-forest-selfguard-handbook/blob/main/README.md)

我们选择 GitHub 平台作为本手册的首要发布位置是因为：方便协同及看到历史更新记录。你可以 Watch、Fork 及 Star，当然我们更希望你能参与贡献。

好，导读开始...

## 引子
如果你持有加密货币或对这个世界有兴趣，未来可能会持有加密货币，那么这本手册值得你反复阅读并谨慎实践。本手册的阅读需要一定的知识背景，希望初学者不必恐惧这些知识壁垒，因为其中大量是可以"玩"出来的。

在区块链黑暗森林世界里，首先牢记下面这两大安全法则：
* 零信任：简单来说就是保持怀疑，而且是始终保持怀疑。
* 持续验证：你要相信，你就必须有能力去验证你怀疑的点，并把这种能力养成习惯。

## 关键内容

<div align=center>
<img src="https://user-images.githubusercontent.com/107821372/212235985-906c9e23-e69d-4a8a-9be0-ff2d2de66ee7.png" alt="Cover" width="80%"/>
</div>

### 一、创建钱包
* #### 1. Download
  1. 找到正确的官网
      * Google
      * 行业知名收录，如 CoinMarketCap
      * 多问一些比较信任的人
  2. 下载安装应用 
      * PC 钱包：建议做下是否篡改的校验工作（文件一致性校验）
      * 浏览器扩展钱包：注意目标扩展下载页面里的用户数及评分情况 
      * 移动端钱包：判断方式类似扩展钱包
      * 硬件钱包：从官网源头的引导下购买，留意是否存在被异动手脚的情况
      * 网页钱包：不建议使用这种在线的钱包 

* #### 2. Mnemonic Phrase
  * 创建钱包时，助记词的出现是非常敏感的，请留意你身边没有人、摄像头等一切可以导致偷窥发生的情况。同时留意下助记词是不是足够随机出现

* #### 3. Keyless
  * Keyless 两大场景（此处区分是为了方便讲解）
      * C ustody，即托管方式。比如中心化交易所、钱包，用户只需注册账号，并不拥有私钥，安全完全依托于这些中心化平台
      * Non-Custodial: The user has a private key-like control power, which is not an actual private key (or seed phrase).
  * MPC 为主的 Keyless 方案的优缺点

### 二、备份钱包
* #### 1. 助记词/私钥类型
  1. 明文：12 个英文单词为主
  2. 带密码：助记词带上密码后会得到不一样的种子，这个种子就是之后拿来派生出一系列私钥、公钥及对应地址 
  3. 多签：可以理解为目标资金需要多个人签名授权才可以使用，多签很灵活，可以设置审批策略
  4. Shamir's Secret Sharing：Shamir 秘密共享方案，作用就是将种子分割为多个分片，恢复钱包时，需要使用指定数量的分片才能恢复

* #### 2. Encryption
  1. 多处备份
      * Cloud：Google /Apple /微软，结合 GPG /1Password 等
      * Paper：将助记词（明文、SSS 等形式的）抄写在纸卡片上
      * Device：电脑/iPad /iPhone /移动硬盘/U 盘等
      * Brain：注意脑记风险（记忆/意外）
  2. 加密
      * 一定要做到定期不定期地验证 
      * 采用部分验证也可以
      * 注意验证过程的机密性及安全性
      
### 三、使用钱包
* #### 1. AML
  1. 链上冻结
  2. 选择口碑好的平台、个人等作为你的交易对手
* #### 2. Cold Wallet
  1. 冷钱包使用方法
      * 接收加密货币：配合观察钱包，如 imToken、Trust Wallet 等 
      * 发送加密货币：QRCode/USB/Bluetooth
  2. 冷钱包风险点
      * 所见即所签这种用户交互安全机制缺失
      * 用户的有关知识背景缺失
* #### 3. Hot Wallet
  1. 与 DApp（DeFi、NFT、GameFi 等）交互<br>
  2. 恶意代码或后门作恶方式
      * 钱包运行时，恶意代码将相关助记词直接打包上传到黑客控制的服务端里
      * 钱包运行时，当用户发起转账，在钱包后台偷偷替换目标地址及金额等信息，此时用户很难察觉
      * 破坏助记词生成有关的随机数熵值，让这些助记词比较容易被破解 
* #### 4. DeFi 安全到底是什么
  1. 智能合约安全
      * 权限过大：增加时间锁（Timelock）/将 admin 多签等
      * 逐步学会阅读安全审计报告
  2. 区块链基础安全：共识账本安全/虚拟机安全等
  3. 前端安全
      * 内部作恶：前端页面里的目标智能合约地址被替换/植入授权钓鱼脚本
      * 第三方作恶：供应链作恶/前端页面引入的第三方远程 JavaScript 文件作恶或被黑
  4. 通信安全
      * HTTPS 安全
      * 举例：MyEtherWallet 安全事件
      * 安全解决方案：HSTS
  5. 人性安全：如项目方内部作恶
  6. 金融安全：币价、年化收益等
  7. 合规安全
      * AML /KYC /制裁地区限制/证券风险有关的内容等
      * AOPP
* #### 5.NFT 安全
  1. Metadata 安全
  2. 签名安全      
* #### 6. 小心签名/反常识签名
  1. 所见即所签
  2. OpenSea 数起知名 NFT 被盗事件
      * 用户在 OpenSea 授权了 NFT（挂单
      * 黑客钓鱼拿到用户的相关签名 
  3. 取消授权（app rove）
      * Token Approvals
      * Revoke.cash 
      * APPROVED.zone
      * Rabby 扩展钱包 
  4. 反常识真实案例）
* #### 7. 一些高级攻击方式
  1. 针对性钓鱼
  2. 广撒网钓鱼
  3. 结合 XSS、CSRF、Reverse Proxy 等技巧（如 Cloudflare 中间人攻击）
  
### 四、传统隐私保护
* #### 1. 操作系统
  1. 重视系统安全更新，有安全更新就立即行动
  2. 不乱下程序  
  3. 设置好磁盘加密保护
* #### 2. 手机
  1. 重视系统的安全更新及下载
  2. 不要越狱、Root 破解，除非你玩安全研究，否则没必要  
  3. 不要从非官方市场下载 App
  4. 官方的云同步使用的前提：账号安全方面你确信没问题
* #### 3. 网络
  1. 网络方面，尽量选择安全的，比如不乱连陌生 Wi-Fi
  2. 选择口碑好的路由器、运营商，切勿贪图小便宜，并祈祷路由器、运营商层面不会有高级作恶行为出现  
* #### 4. 浏览器
  1. 及时更新
  2. 扩展如无必要就不安装  
  3. 浏览器可以多个共存
  4. 使用隐私保护的知名扩展  
* #### 5. 密码管理器
  1. 别忘记你的主密码
  2. 确保你的邮箱安全  
  3. 1Password/Bitwarden 等
* ####  6. 双因素认证
  * Google Authenticator/Microsoft Authenticator 等
* ####  7. 科学上网
  * 科学上网、安全上网
* #### 8. 邮箱
  1. 安全且知名：Gmail/Outlook/QQ 邮箱等
  2. 隐私性：ProtonMail/Tutanota 
* #### 9. SIM 卡
  1. SIM 卡攻击
  2. 防御建议 
      * 启用知名的 2FA 工具
      * 设置 PIN 码 
* #### 10. GPG
  * 区分
      * PGP 是 Pretty Good Privacy 的缩写，是商用加密软件，发布 30 多年了，现在在赛门铁克麾下
      * OpenPGP 是一种加密标准，衍生自 PGP
      * GPG，全称 GnuPG，基于 OpenPGP 标准的开源加密软件      
* #### 11. 隔离环境
  1. 具备零信任安全法则思维
  2. 良好的隔离习惯 
  3. 隐私不是拿来保护的，隐私是拿来控制的 

### 五、人性安全
1. Telegram
2. Discord
3. 来自"官方"的钓鱼
4. Web3 隐私问题

### 六、区块链作恶方式
1. 盗币、恶意挖矿、勒索病毒、暗网交易、木马的 C2 中转、洗钱、资金盘、博彩等
2. SlowMist Hacked 区块链被黑档案库

### 七、被盗了怎么办
1. 止损第一
2. 保护好现场
3. 分析原因
4. 追踪溯源
5. 结案

### 八、误区
1. Code Is Law
2. Not Your Keys, Not Your Coins
3. In Blockchain We Trust
4. 密码学安全就是安全
5. 被黑很丢人
6. 立即更新<br>

## 总结
当你阅读完本手册后，一定需要实践起来、熟练起来、举一反三。如果之后你有自己的发现或经验，希望你也能贡献出来。如果你觉得敏感，可以适当脱敏，匿名也行。其次，致谢安全与隐私有关的立法与执法在全球范围内的成熟；各代当之无愧的密码学家、工程师、正义黑客及一切参与创造让这个世界更好的人们的努力，其中一位是中本聪。最后，感谢贡献者们，这个列表会持续更新，有任何的想法，希望你联系我们。

导读到此，完整版本，欢迎阅读并分享 :)

[https://github.com/slowmist/Blockchain-dark-forest-selfguard-handbook](https://github.com/slowmist/Blockchain-dark-forest-selfguard-handbook/blob/main/README.md)


