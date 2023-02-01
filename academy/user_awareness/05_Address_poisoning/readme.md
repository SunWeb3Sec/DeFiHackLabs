# Lesson 5: 警惕相同尾号空投骗局

Author: [SlowMist](https://twitter.com/SlowMist_Team)

## 事件概要

近期，有多个用户向我们反映`资产被盗`，以下為其中一個用戶訊息：

<img src="https://user-images.githubusercontent.com/107249780/215801351-2efc8437-f674-47f3-9614-6f3e340fe0b7.png" alt="Cover" width="40%"/>
</div>


根据多名中招用户的反馈，似乎是攻击者
* 针对交易规模较大频率较高的用户不断空投小额数量的 Token（例如 0.01 USDT 或 0.001 USDT 等），
* 攻击者地址尾数和用户地址尾数`几乎一样`，通常为后几位，用户去复制历史转账记录中的地址时一不小心就复制错，导致资产损失。

<div align=center>
<img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvAUUHUFicMGv6SfvsaVyRVFKsbbfPwzSO0RdeKBIfv8hCULpibpQAXYzKw/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="60%"/>
</div>

<p align="center">（图片来自 TokenPocket 钱包公众号）</p>

## 事件分析

### 相关信息

 * 攻击者地址 1：`TX...dWfKz`
 * 用户地址 1：`TW...dWfKz`
 * 攻击者地址 2：`TK...Qw5oH`
 * 用户地址 2：`TW...Qw5oH`

### MistTrack 分析

1. 先看看两个攻击者地址大致的交易情况。
    <div align=center>
    <img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvAkYXaa7gPQDgtPtNiboicoehaSGuXTG32icMntqcpm5PFmnziam2fU9PH0Q/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="80%"/>
    </div>
  
   * 可以看到，**攻击者地址 1** `TX...dWfKz`与用户地址`TW...dWfKz`尾数都是 `dWfKz`，在用户损失了 115,193 USDT 后，攻击者又先后使用两个新的地址分别对用户地址空投 0.01 USDT 和 0.001 USDT，尾数同样是 `dWfKz`。
    <div align=center>
    <img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvAWsv1OkfkoEmWAoIx8OHEkFGwoiaQLYLltK0lbe7pfgPkhiaBGmTqU4Kw/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="80%"/>
    </div>
  
   * 同样，**攻击者地址 2**`TK...Qw5oH`与用户地址`TW...Qw5oH`尾数都是 `Qw5oH`，在用户损失了 345,940 USDT 后，攻击者又使用新的地址（尾数为 `Qw5oH`）对用户地址空投 0.01 USDT。
   <div align=center>
   <img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvAJLvdFFs8Mor0SESoO7y1OBjdh6wAs3E9ic0SHtutP25YBTa5qN9k0ww/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="80%"/>
   </div>
   <div align=center>
   <img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvAb1CZwffsa3BtDOXGhwl8S5AhZPY8Qu9NcHjMTRZld917wUs6a5Fgtw/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="80%"/>
   </div>

2. 接下来，我们使用 MistTrack 来分析**攻击者地址 1**`TX...dWfKz`。

   * 如下图，**攻击者地址 1** 将 0.01 USDT、0.02 USDT 不断空投到各目标地址，而这些目标地址都曾与尾号为 `dWfKz` 的地址有过交互。
   <div align=center>
   <img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvARLzzMblO0N85OdzBObSJ9rslUxgHq27cIhJOdY0IVbXAYkUiaaDIzNw/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="60%"/>
   </div>
   
   * 往上追溯看看该地址的资金来源。最早一笔来自地址 `TF...J5Jo8` 于 10 月 10 日转入的 0.5 USDT。
 
   <div align=center>
   <img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvALibOjfHqunnonDAhFMBtsNHpxMRXzHAdhtOCSKu2FJnIdje0iaPzhgZg/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="60%"/>
   </div>
   
   * 近一步分析地址 `TF...J5Jo8`：
     
     该地址对将近 3300 个地址分别转入 0.5 USDT，也就是说，这些接收地址都有可能是攻击者用来空投的地址，我们随机选择一个地址验证。
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/216015584-c84ca0cc-26d2-4321-8e7a-504390342cb7.png" alt="Cover" width="80%"/>
   </div> 
   
   * 使用 MistTrack 对上图最后一个地址 `TX...4yBmC` 进行分析。如下图显示，该地址 `TX...4yBmC` 就是攻击者用来空投的地址，对多个曾与尾号为 `4yBmC` 地址有过交互的地址空投 0.01 USDT。
   <div align=center>
   <img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvAMjr0eHyfweWhovO1J5SVeQGPzKqgtQzv9ztJ1JCzlIFiaHibiasqYpm1A/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="60%"/>
   </div>
   
 3. 我们再来看看**攻击者地址 2** `TK...Qw5oH`的情况：空投 0.01 USDT 到多个地址，且初始资金来自地址 `TD...psxmk` 转入的 0.6 USDT。
    <div align=center>
    <img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvAwmAU7JwpwhH1uEx9Lpx6KNFFekPMd1RsPxEFBpr6oFoTeyTHzfYiclg/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="80%"/>
    </div> 
   
     * 这次往下追踪，**攻击者地址 2** 将 0.06 USDT 转到地址 `TD...kXbFq`，而地址 `TD...kXbFq` 也曾与尾号为 `Qw5oH` 的 FTX 用户充币地址有过交互。
     <div align=center>
     <img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvAD7d57ZXbsw7DCm7O38Yeevb95ia6nxOwWpaQQOQQndViba7tSD2l2F8Q/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="60%"/>
     </div>
     
     * 那我们反向猜想下，其他与 `TD...kXbFq` 交互过的地址，是否也有相同尾号的地址对它们进行空投？随机选择两个地址验证一下（例如上图的 Kraken 充币地址 `TU...hhcWoT` 和 Binance 充币地址 `TM...QM7me`）。
     <div align=center>
     <img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvARib9ek0PlZGud9DlHNMLlicH9qRhE4Bic5f17vYiaY31GWduETPXZeEqtA/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="80%"/>
     </div>
     <div align=center>
     <img src="https://mmbiz.qpic.cn/mmbiz_png/qsQ2ibEw5pLZL55l1mOR8pMaTfnZMFLvAhaF8G94HqrWZuIMDj0Q8rnSBV1bIicZeKQaecbIBqIvX9RHsNqOcb3g/640?wx_fmt=png&wxfrom=5&wx_lazy=1&wx_co=1" alt="Cover" width="80%"/>
     </div>
     
     不出所料，攻击者布了一个巨大的网，只钓粗心人。
     
     其他地址情况这里不再赘述。

## 总结
本文主要介绍了骗子利用用户复制交易记录中过往地址的这个习惯，生成相同尾号的地址作为伪装地址，并利用伪装地址向用户不断空投小额的 Token，使得骗子的地址出现在用户的交易记录中，用户稍不注意就复制错误地址，导致资产损失。慢雾在此提醒，由于区块链技术是不可篡改的，链上操作是不可逆的，所以在进行任何操作前，请务必仔细核对地址，同时建议使用钱包的地址簿转账功能，可直接通过选择地址转账。
