# Lesson 4: 空投钓鱼分析: 黑客目标精准指向这些人


Author: [Scam Sniffer](https://twitter.com/scamsniffer_)

最近有很多针对特定 NFT 持有者群体的空投网络钓鱼诈骗，让我们深入研究案例，看看诈骗是如何进行的。 这一切都始于 12 月 3 日，我们的 Scam Sniffer Alert Bot 检测到有一起网络钓鱼事件，最终导致 21 个 CloneX 被盗，价值 168 ETH。

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598204-a2855b53-dc9a-4902-941a-bc48c4ff0dc1.png" alt="Cover" width="60%"/>
</div>

在白帽群聊中与 [Cos(余弦)](https://twitter.com/evilcos) 讨论后，我们成功识别出发生在 12 月 8 日的原始的异常交易 Tx:

https://etherscan.io/tx/0xbf2542540ce22abe7a1822e15d67a50b73a7ba18e036bb305103e51606122b69

这笔交易发生在12-08号，NFT资产流向到了一个我们曾经收录过的钓鱼地址`0xa0b2ebf28b621fd925a2f809378a3dbc066c28f6`。随后这些NFT在交易市场陆续被售出，最终触发了Alert

### 异常交易

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598316-865e82d6-feb7-4ab8-b6d1-050b8a1ec9ef.png" alt="Cover" width="80%"/>
</div>

这是一笔Seaport的交易，在这笔交易中134个NFT以0 ETH的价格被卖出。让我们看一看这里面的相关地址：

*   0xabeaa3375534d2931b2149067af3e7b8458d2f0c 受害者
    
*   0x4574043b6423953723356237042bf6df2304f297 交易发起人
    
*   0xc0fdf4fa92f88b82ccbebfc80fbe4eb7e5a8e0ca 接收受害者资产的地址
    

`受害者`在钱包中对这笔恶意订单进行了签名，攻击者拿到签名后，使用 `交易发起人`地址发起了交易，在这笔恶意订单中指定了taker是`0xc0fdf4fa92f88b82ccbebfc80fbe4eb7e5a8e0ca`

#### 恶意Seaport订单

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598354-10dc6320-8744-4dce-ac52-de3d0f8314f5.png" alt="Cover" width="80%"/>
</div>

作为NFT交易者，大家对这样Opensea的Seaport挂单签名可能习以为常了。首先这是一笔正常的挂单订单签名，尽管Metamask特地加了箭头按钮必须点击才能签名, 但我可以确定的是，几乎很少有人会对Message里面的内容进行仔细的阅读和理解。

比如在这个截图里：

*   consideration的`startAmount`是92500000000000000,
    
*   token是 `0x0000000000000000000000000000000000000000`也就是ETH
    
*   也就是说这个挂单，期望要收到0.0925 ETH（扣除版税），才能拿到我要挂单的这个NFT
    

但估计很多不敏感的人可能都没仔细去理解过里面的内容，而这里面的内容，可以成为攻击者利用的点。

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212599038-7b3a7fba-6234-49da-bae3-27be2f39317d.png" alt="Cover" width="70%"/>
</div>

在MetaMask7月份对NFT资产的Approve也加上了巨大醒目的安全提醒之后，很多钓鱼网站转向了新的利用方式，而Seaport作为一个交易协议，在5月份上线后，几乎所有的NFT交易用户的NFT资产都对其授权过。

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598432-e99f5574-7de4-4c5d-b8e6-b08572ff2b69.png" alt="Cover" width="80%"/>
</div>

于是攻击者开始尝试构造Seaport的恶意订单，我们在7月底陆续发现了这一新的利用形式，效果很明显！

因为这一类的签名在MetaMask里是没有任何安全提醒的，而且大部分用户对这样的签名请求并没有任何概念。

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598499-63d1a8b2-21b5-4f71-9530-2dff912244b4.png" alt="Cover" width="70%"/>
</div>

<p align="center"">恶意订单</p>

但这样的签名也是有特征的，用户只需要关注下签名内容中的`consideration` ：

*   如果token不是ETH
    
*   startAmount是1或异常小
    

对于这些签名，MetaMask针对在这些交易协议类的EIP-712签名时，也应该加上足够的数据可读，确保用户知道相关风险。

### 如何发生的？

尽管知道了受害者是签名了恶意Seaport订单，但这一切是如何发生的呢？抱着这个疑问，突然想到了前两天余弦说过Polygon 上多了不少恶意空投NFT。

于是我立马打开了`0xabeaa3375534d2931b2149067af3e7b8458d2f0c`受害者在polygon上最近收到的交易

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598554-619196b9-c100-47d8-a947-0074db016e51.png" alt="Cover" width="70%"/>
</div>

很明显这里面有几笔RTFKT相关的NFT空投！https://polygonscan.com/tx/0xcf2f993113a4d558801e60f8790390c1c45085bcee717e7ed8b4a67e2e8c705d

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598606-442647a7-30c7-48ef-abfc-1b6a9a8827f9.png" alt="Cover" width="70%"/>
</div>

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/213104333-32cb879f-1a81-47e1-a34e-0afcfaaed1fa.png" alt="Cover" width="70%"/>
</div>
<p align="center""> Call Trace </p>

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/213104607-aa91daf7-4821-4df7-8db2-3c01e70d7b83.png" alt="Cover" width="70%"/>
</div>
<p align="center""> Decompiled snippet </p>

点开一看，好家伙！通过对Seaport合约发起了冒充交易空投的，这种方式应该可以逃过NFT平台的反垃圾空投的检测。再仔细看这笔交易，除了受害者外，还有其他几个地址也收到了。
                                                     

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598659-9527183c-0997-4b1c-a357-99c4e36a3796.png" alt="Cover" width="70%"/>
</div>

看来一共定向了883个地址

### 恶意网站

试着在我们库里找了下rtfkt相关的恶意网站，

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598712-66b28c26-145a-4ccf-a45d-e4767d29ed3c.png" alt="Cover" width="70%"/>
</div>

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598744-61409da7-f04d-4e95-930b-a4f01b4ef776.png" alt="Cover" width="70%"/>
</div>

<p align="center"">还有活着的钓鱼网站!</p>

抱着好奇我又试着检索了下RTFKT - MNLTH LRI X

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598893-b383afcd-1841-47d7-9044-0a773de95ba2.png" alt="Cover" width="70%"/>
</div>

原来12-07号有过官方的空投消息，那么很明显了。用户被截胡了！

### 时间线

让我们来重新梳理一下时间线

*   12-07 06:50 RTFKT官方发布消息空投会在一周内
    

*   钓鱼攻击者，看到这个消息，整理了目标NFT的持仓大户地址，开始在Polygon发起恶意NFT空投
    
*   受害者也看到了官方空投的消息
    

*   12-07 20:00 受害者钱包，收到了空投到的钓鱼NFT
    
*   12-08 18:58 受害者点进了NFT中的钓鱼网站，以为是领取空投，结果签名了恶意的Seaport挂单！
    
*   12-08 18:59 攻击者拿到挂单签名后，快速在链上发起交易，用户137个NFT资产被盗
    
*   12-09到12-11 被盗的NFT陆续在各大NFT交易市场被卖出
    

### 总结

Web3是片黑暗森林，由于用户资产的透明。钓鱼者可以通过链上数据以及各种空投事件，基于这些信息可以针对被定向者，发起大量上下文关联度极高的钓鱼活动。

有广撒网的空投，也有那种精细化针对大户的定向钓鱼，让人防不胜防。作为普通用户，希望大家提高警惕，多学习安全知识，Don't trust, Verify! 祝大家安全！
