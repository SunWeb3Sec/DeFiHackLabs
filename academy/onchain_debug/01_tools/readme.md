# OnChain Transaction Debugging: 1. Tools

Author: [Sun](https://twitter.com/1nf0s3cpt)

社群 [Discord](https://discord.gg/Fjyngakf3h)

同步發表: XREX | [WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)

當初我在學習鏈上交易分析時，很少相關教學文章，只能自己慢慢地收集資料從中挖掘如何分析到測試。 我們將推出一系列 Web3 安全的教學文章, 幫助更多人加入 Web3 安全，共創安全網路。

第一個系列我們將介紹如何進行鏈上分析到撰寫攻擊重現。此技能將能幫助你分析攻擊過程和漏洞原因甚至套利機器人如何套利！

## 工欲善其事，必先利其器
在進入分析之前，我先介紹一些常用工具，正確的工具可以幫助你做研究時更有效率。
### Transaction debugging tools
[Phalcon](https://phalcon.blocksec.com/) | [Tx.viewer](https://tx.eth.samczsun.com/) | [Cruise](https://cruise.supremacy.team/) | [Ethtx](https://ethtx.info/) | [Tenderly](https://dashboard.tenderly.co/explorer)

Transaction Viewer 這類工具是最常用的，可以幫助我們針對想要分析的交易 Transaction，以可視化列出函數呼叫的流程以及每個函式帶入了什麼的參數等。
每個工具大同小異，只差異在鏈的支援度不同和輔助功能，我個人是比較常用 Phalcon 和 Sam 的 Transaction Viewer，如果遇到不支援的鏈則會使用 Tenderly，Tenderly 支援最多鏈，但是可讀性就不是這麼方便，需要 Debug 慢慢分析。不過我最初在研究鏈上分析是先學習 Ethtx 和 Tenderly。

#### 鏈支援度比較

Phalcon： `Ethereum、BSC、Avalanche C-Chain、Polygon、Solana、Arbitrum、Fantom、Optimism、Base、Linea、zkSync Era、Kava、Evmos、Merlin、Manta、Mantle、Holesky testnet、Sepolia testnet`

Sam's Transaction viewer： `Ethereum、Polygon、BSC、Avalanche C-Chain、Fantom、Arbitrum、Optimism`

Cruise： `Ethereum、BSC 、Polygon、Arbitrum、Fantom、Optimism、Avalanche、Celo、Gnosis`

Ethtx： `Ethereum、Goerli testnet`

Tendery： `Ethereum、Polygon、BSC、Sepolia、Goerli、Gnosis、POA、RSK、Avalanche C-Chain、Arbitrum、Optimism
、Fantom、Moonbeam、Moonriver`

#### 實務操作
以 JayPeggers - Insufficient validation + Reentrancy [事件](https://github.com/SunWeb3Sec/DeFiHackLabs/#20221229---jay---insufficient-validation--reentrancy)來當例子 [TXID](https://phalcon.blocksec.com/tx/eth/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6)
使用 Blocksec 開發的 Phalcon 工具來說明，下圖可以看到該交易的基本資訊和餘額變化，從餘額變化可以快速看出攻擊著大概獲利多少，以這個例子攻擊者獲利 15.32 ETH。

![210571234-402d96aa-fe5e-4bc4-becc-190bd5a78e68-2](https://user-images.githubusercontent.com/107249780/210686382-cc02cc6a-b8ec-4cb7-ac19-402cd8ff86f6.png)

Invocation Flow 可視化函式調用流程: 可以讓我們知道這一筆交易調用流程和函式呼叫的層級，有沒有使用閃電貸、涉及了哪些項目、呼叫了哪些函式帶入了什麼參數和原始 data 等等

![圖片](https://user-images.githubusercontent.com/52526645/210572053-eafdf62a-7ebe-4caa-a905-045e792add2b.png)

Phalcon 2.0 新增了資金流向和 Debug + 原始碼分析可以在 Trace 的過程中邊看程式執行的片段、參數、返回值，分析上方便了不少。

![image](https://user-images.githubusercontent.com/107249780/210821062-d1da8d1a-9615-4f1f-838d-34f27b9c3f41.png)

換 Sam 的 Transaction Viewer 來看看 [TXID](https://tx.eth.samczsun.com/ethereum/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6)
跟 Phalcon 類似但 Sam 整合了許多小工具在裡面，如下圖的眼睛點下去可以看到 Storage 的變化和每個呼叫所消耗的 Gas。

![210574290-790f6129-aa82-4152-b3e1-d21820524a0a-2](https://user-images.githubusercontent.com/107249780/210686653-f964a682-d2a7-4b49-bafc-c9a2b0fa2c55.png)


點擊最左邊的 Call，可以把原始 Input data 嘗試 Decode。

![圖片](https://user-images.githubusercontent.com/52526645/210575619-89c8e8de-e2f9-4243-9646-0661b9483913.png)

再來換 Tendery 來看看 [TXID](https://dashboard.tenderly.co/tx/mainnet/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6)
在 Tendery 介面上，一樣可以看到基本資訊，但在 Debug 的部分就不是可視化，需要一步一步 Debug 走下去分析，不過好處是可以邊 Debug 邊看程式碼還有 Input data 的轉換過程。

![圖片](https://user-images.githubusercontent.com/52526645/210577802-c455545c-80d7-4f35-974a-dadbe59c626e.png)

到這邊就可以幫我們釐清大概這筆交易做了哪些事情，在還沒有開始寫 Poc 時，如果想要快速重放攻擊可以嗎? 可以! 可以使用Tendery 或 Phalcon，這兩個工具另外支援了模擬交易重現，在上圖右上角有一個按鈕 Re-Simulate，工具會自動幫你帶上該交易的參數值如下圖
從圖中的欄位可以依照需求任意改變如改block number, From, Value, Input data 等

![圖片](https://user-images.githubusercontent.com/52526645/210580340-f2abf864-e540-4881-8482-f28030e5e35b.png)

### Ethereum Signature Database

[4byte](https://www.4byte.directory/) | [sig.eth](https://sig.eth.samczsun.com/) | [etherface](https://www.etherface.io/hash)

在原始 Input data，前面 4bytes 為 Function Signature. 有時遇到 Etherscan 或分析工具無法解出來時，可以透過 Signature Database 來查看看可能是什麼 Function。

以下舉例假設我們不知道 `0xac9650d8` 是什麼 Function
![image](https://user-images.githubusercontent.com/107249780/211152650-bfe5ca56-971c-4f38-8407-8ca795fd5b73.png)

透過 sig.eth 查詢，可以看到這個 4 bytes signature 為 `multicall(bytes[])`
![圖片](https://user-images.githubusercontent.com/52526645/210583416-c31bbe07-fa03-4701-880d-0ae485b171f7.png)

### Useful tools

[ABI to interface](https://gnidan.github.io/abi-to-sol/) | [Get ABI for unverified contracts](https://abi.w1nt3r.xyz/) | [ETH Calldata Decoder](https://apoorvlathey.com/eth-calldata-decoder/) | [ETHCMD - Guess ABI](https://www.ethcmd.com/)

ABI to interface: 在開發 Poc 時需要呼叫其他合約時要有 Interface 接口，我們可以透過這個工具幫你快速產生你要的接口。
先去 Etherscan 把 ABI 複製下來，貼過去工具上就可以看到產生出來的 Interface。
[例子](https://etherscan.io/address/0xb3da8d6da3ede239ccbf576ca0eaa74d86f0e9d3#code)

![圖片](https://user-images.githubusercontent.com/52526645/210587442-e7853d8b-0613-426e-8a27-d70c80e2a42d.png)
![圖片](https://user-images.githubusercontent.com/52526645/210587682-5fb07a01-2b21-41fa-9ed5-e7f45baa0b3e.png)


ETH Calldata Decoder: 有時候在沒有 ABI 的情況下想要解看看 Input data 可以試試看 ETH Calldata Decoder，在前面介紹到 Sam 的工具就有支援 Input data decode。 

![圖片](https://user-images.githubusercontent.com/52526645/210585761-efd8b6f1-b901-485f-ae66-efaf9c84869c.png)

Get ABI for unverified contracts: 如果遇到未開源的合約，可以透過這個工具嘗試列舉出這個合約中存在的 Function Signature.
[例子](https://abi.w1nt3r.xyz/mainnet/0xaE9C73fd0Fd237c1c6f66FE009d24ce969e98704)

![圖片](https://user-images.githubusercontent.com/52526645/210588945-701b0e22-7390-4539-9d2f-e13479b52824.png)

### Decompile tools
[Etherscan-decompile bytecode](https://etherscan.io/address/0xaE9C73fd0Fd237c1c6f66FE009d24ce969e98704#code) | [Dedaub](https://library.dedaub.com/decompile) | [heimdall-rs](https://github.com/Jon-Becker/heimdall-rs)

Etherscan 內建有一個反編譯功能但可讀性偏差，個人比較常使用 Dedaub，可讀性好一點，也是常常最多人DM 問我都使用哪個工具反編譯。
我們拿一個 MEV Bot 被攻擊來當[例子](https://twitter.com/1nf0s3cpt/status/1577594615104172033)
可以自己試試解看看 [例子](https://bscscan.com/address/0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d#code)

首先把未開源合約的 Bytecodes 複製下來貼到 Dedaub 上，點 Decompile 即可。
![截圖 2023-01-05 上午10 33 15](https://user-images.githubusercontent.com/107249780/210688395-927c6126-b6c1-4c6d-a0c7-a3fea3db9cdb.png)

![圖片](https://user-images.githubusercontent.com/52526645/210591478-6fa928f3-455d-42b5-a1ac-6694f97386c2.png)

第一課分享就先到這邊，想學更多可以參考以下學習資源。
---
## 學習資源
[samczsun's eth txn explorer and vscode extension](https://www.youtube.com/watch?v=HXgu239mPBc)

[Vulnerabilities in DeFi by Daniel V.F.](https://www.youtube.com/watch?v=9fcOffCg2ig)

[Tenderly.co - Debug Transaction](https://www.youtube.com/watch?v=90GN9Ut8LhU)

[Reversing The EVM: Raw Calldata](https://degatchi.com/articles/reading-raw-evm-calldata)

https://web3sec.xrex.io/
