# OnChain Transaction Debugging: 2. Tools

Author: [Sun](https://twitter.com/1nf0s3cpt)

社群 [Discord](https://discord.gg/3y3d9DMQ)

同步發表: XREX | [WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)

鏈上交易數據包含從簡單轉帳、單的 DeFi 交互、多個 DeFi 交互、搭配閃電貸套利、治理提案、跨鏈交易等等，這一節我們先來熱身一下，先從簡單的開始。我將介紹通常使用區塊練瀏覽器 Etherscan 哪些訊息是我們所在意要看的，再來我們會使用交易分析工具 [Phalcon](https://phalcon.blocksec.com/) 看一下簡單的交易、UniSWAP上 Swap、Curve 3pool 增加移除流動性、Compound治理提案、閃電貸等。

## 開始進入熱身篇
- 首先環境上需要先安裝 [Foundry](https://github.com/foundry-rs/foundry)，安裝方法請參考 [instructions](https://book.getfoundry.sh/getting-started/installation.html).
- 每條鏈上都有專屬的區塊鏈瀏覽器，這節我們都會使用 Ethereum 主網來當案例可以透過 Etherscan 來分析.
- 通常我會特別想看的欄位包含: Transaction Action、From、Interacted With (To)、ERC-20 Tokens Transferred、Input Data.

## 鏈上轉帳
![圖片](https://user-images.githubusercontent.com/52526645/211021954-6c5828be-7293-452b-8ef6-a268db54b932.png)
從上圖[例子](https://etherscan.io/tx/0x96a3fdd23fc5052d99b4be0ac55dc9b0eeff888fba447cce6b4dce1743497ad1) 可以解讀為:

From: 發送這筆交易的來源錢包地址

Interacted With (To): 跟哪個合約交互，這個例子 Tether USD (USDT) 

ERC-20 Tokens Transferred: 從用戶A 錢包轉 651.13 USDT 到用戶 B

Input Data: 呼叫了 transfer function

透過 [phalcon](https://phalcon.blocksec.com/tx/eth/0x836ef3d01a52c4b9304c3d683f6ff2b296c7331b6fee86e3b116732ce1d5d124) 來看看:

從調用流程來看就只有一個 Call USDT.transafer...，要注意的是 Value. 因為 EVM 不支持浮點數的運算，所以使用精度代表，每個 Token 都要注意它的精度大小，以 USDT 為例，精度是 6 所以 Value 帶入的值為 651130000，精度處理不當就容易造成問題。

![圖片](https://user-images.githubusercontent.com/52526645/211022964-f819b35c-d442-488c-9645-7733af219d1c.png)



## Uniswap Swap
每條鏈上都有專屬的區塊鏈瀏覽器，這節我們都會使用 Ethereum 主網來當案例可以透過 Etherscan 來分析。

![圖片](https://user-images.githubusercontent.com/52526645/211020562-67e6c7c1-a73f-42a6-97c4-b7546ae8bb95.png)

從上圖[例子](https://etherscan.io/tx/0x96a3fdd23fc5052d99b4be0ac55dc9b0eeff888fba447cce6b4dce1743497ad1) 通常我會特別想看的欄位包含: 

Transaction Action: 很直覺就可以知道用戶在 Uniswap 上進行 Swap，將 6716 $BC 換成 0.88 ETH.

From: 發送這筆交易的來源錢包地址

Interacted With (To): 跟哪個合約交互，這個例子是跟 Uniswap V3: Router 2

ERC-20 Tokens Transferred: Token 交換的過程

Input Data: 呼叫合約什麼 Function

## Resources
[Foundry book](https://book.getfoundry.sh/)
