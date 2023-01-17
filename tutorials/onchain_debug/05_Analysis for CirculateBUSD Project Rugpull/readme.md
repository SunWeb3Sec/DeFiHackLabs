# OnChain Transaction Debugging: 5. Analysis for CirculateBUSD Project Rugpull, Loss of $2.27 Million!

Author: [Numen Cyber Labs](https://twitter.com/numencyber?ref_src=twsrc%5Egoogle%7Ctwcamp%5Eserp%7Ctwgr%5Eauthor)

社群 [Discord](https://discord.gg/3y3d9DMQ)

同步發表:  [Numen Cyber Labs](https://mp.weixin.qq.com/s/yVjIYo-aoeYQSVtKQJueXg)

## 前言
根据NUMEN链上监控显示，新加坡时间2023年1月12日下午 14:22:39 ，CirculateBUSD项目跑路，损失金额227万美金。该项目资金转移主要是管理员调用`CirculateBUSD.startTrading`，并且在startTrading里面的主要判断参数是由管理员设置的未开源合约`SwapHelper.TradingInfo`返回的数值，之后调用SwapHelper.swaptoToken转走资金。

<div align=center>
<img src="https://user-images.githubusercontent.com/107821372/212806617-33a2e763-754b-4682-baef-d78bccdbcbaa.png" alt="Cover" width="80%"/>
</div>

### 事件分析

* 首先调用了合约的`startTrading`，在函数内部调用了[SwapHelper合约](https://bscscan.com/address/0x9639d76092b2ae074a7e2d13ac030b4b6a0313ff)的`TradingInfo`函数，详细代码如下。

 <div align=center>
 <img src="https://user-images.githubusercontent.com/107821372/212807067-c3dfccde-6a26-4bb0-96e8-9a1141b88fc6.png" alt="Cover" width="80%"/>
 </div>

---
 <div align=center>
 <img src="https://user-images.githubusercontent.com/107821372/212807682-d99be725-a9a9-41a9-a380-329413af4b2f.png" alt="Cover" width="80%"/>
 </div>

上图是tx的调用栈，结合代码可知`TradingInfo`里面只是一些静态调用，关键问题不在这个函数。继续往下分析，发现调用栈中的`approve`操作和`safeapprove`对应上。接着又调用了SwapHelper的`swaptoToken`函数，结合调用栈发现这是个关键函数，转账交易在这个`call`里面执行的。通过链上信息发现`SwapHelper`合约并不开源，具体地址如下：https://bscscan.com/address/0x112f8834cd3db8d2dded90be6ba924a88f56eb4b#code

* 尝试逆向分析一下。首先定位函数签名`0x63437561`。
