# OnChain Transaction Debugging: 2. Warm up

Author: [Sun](https://twitter.com/1nf0s3cpt)

社群 [Discord](https://discord.gg/Fjyngakf3h)

同步發表: XREX | [WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)

鏈上交易數據包含從簡單的單筆交易轉帳、1 個 DeFi 合約交互、多個 DeFi 合約交互、閃電貸套利、治理提案、跨鏈交易等等，這一節我們先來熱身一下，先從簡單的開始。我將介紹通常使用區塊鏈瀏覽器 Etherscan 哪些訊息是我們所在意的，再來我們會使用交易分析工具 [Phalcon](https://phalcon.blocksec.com/) 看一下這些交易從簡單的轉帳、UniSWAP上 Swap、Curve 3pool 增加流動性、Compound 治理提案、閃電貸的調用差異。

## 開始進入熱身篇
- 首先環境上需要先安裝 [Foundry](https://github.com/foundry-rs/foundry)，安裝方法請參考 [instructions](https://book.getfoundry.sh/getting-started/installation.html).
    - 測試主要會用到 [Forge test](https://book.getfoundry.sh/reference/forge/forge-test)，如果第一次使用 Foundry，可以參考 [Foundry book](https://book.getfoundry.sh/)、[Foundry @EthCC](https://www.youtube.com/watch?v=wJnywGB33O4)、[WTF Solidity - Foundry](https://github.com/AmazingAng/WTF-Solidity/blob/main/Topics/Tools/TOOL07_Foundry/readme.md)
- 每條鏈上都有專屬的區塊鏈瀏覽器，這節我們都會使用 Ethereum 主網來當案例所以可以透過 Etherscan 來分析.
- 通常我會特別想看的欄位包含:
    -  Transaction Action: 因為複雜的交易中 ERC-20 Tokens Transferred 會很複雜，可讀性不好，所以可以透過 Transaction Action 看一下關鍵行為但不一定每筆交易都有
    -  From: msg.sender 執行這筆交易的來源錢包地址
    -  Interacted With (To): 跟哪個合約交互
    -  ERC-20 Tokens Transferred: 代幣轉移流程
    -  Input Data: 交易的原始 Input 資料，可以看到呼叫什麼 Function 和帶入什麼 Value
- 如果還不知道常用工具有哪些可以回顧第一課交易分析[工具篇](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools)

## 鏈上轉帳
![圖片](https://user-images.githubusercontent.com/52526645/211021954-6c5828be-7293-452b-8ef6-a268db54b932.png)
從上圖[例子](https://etherscan.io/tx/0x836ef3d01a52c4b9304c3d683f6ff2b296c7331b6fee86e3b116732ce1d5d124)可以解讀為:

From: 發送這筆交易的來源錢包地址

Interacted With (To): Tether USD (USDT) 合約

ERC-20 Tokens Transferred: 從用戶A 錢包轉 651.13 USDT 到用戶 B

Input Data: 呼叫了 transfer function

透過 [phalcon](https://phalcon.blocksec.com/tx/eth/0x836ef3d01a52c4b9304c3d683f6ff2b296c7331b6fee86e3b116732ce1d5d124) 來看: 從調用流程來看就只有一個 `Call USDT.transfer`，要注意的是 Value. 因為 EVM 不支持浮點數的運算，所以使用精度代表，每個 Token 都要注意它的精度大小，標準 ERC-20 代幣精度為 18，但也有特例，如 USDT 為例，精度是 6 所以 Value 帶入的值為 651130000，如果精度處理不當就容易造成問題。精度的查詢方式可以到 [Etherscan](https://etherscan.io/token/0xdac17f958d2ee523a2206206994597c13d831ec7) 代幣合約上看到。

![圖片](https://user-images.githubusercontent.com/52526645/211123692-d7224ced-bc0b-47a1-a876-2af086e2fce9.png)

![圖片](https://user-images.githubusercontent.com/52526645/211022964-f819b35c-d442-488c-9645-7733af219d1c.png)

## Uniswap Swap

![圖片](https://user-images.githubusercontent.com/52526645/211029091-c24963c7-d2f8-44f4-ad6a-a9185f98ec85.png)

從上圖[例子](https://etherscan.io/tx/0x1cd5ceda7e2b2d8c66f8c5657f27ef6f35f9e557c8d1532aa88665a37130da84) 可以解讀為:

Transaction Action: 很直覺就可以知道用戶在 Uniswap 上進行 Swap，將 12,716 USDT 換成 7,118 UNDEAD。

From: 發送這筆交易的來源錢包地址

Interacted With (To): 這個例子是一個 MEV Bot 合約呼叫 Uniswap 合約進行 Swap

ERC-20 Tokens Transferred: Token 交換的過程

透過 [phalcon](https://phalcon.blocksec.com/tx/eth/0x1cd5ceda7e2b2d8c66f8c5657f27ef6f35f9e557c8d1532aa88665a37130da84) 來看: MEV Bot 呼叫 Uniswap V2 USDT/UNDEAD 交易對合約呼叫 [swap](https://docs.uniswap.org/contracts/v2/reference/smart-contracts/pair#swap-1) 函示來進行代幣兌換。

![圖片](https://user-images.githubusercontent.com/52526645/211029737-4a606d32-2c96-41e9-aef7-82fe1fb4b21d.png)

我們使用 Foundry 來模擬操作使用 1BTC 在 Uniswap 換成 DAI，[範例程式碼](https://github.com/SunWeb3Sec/DeFiLabs/blob/main/src/test/Uniswapv2.sol)參考，執行以下指令
```sh
forge test --contracts ./src/test/Uniswapv2.sol -vvvv
```

如下圖所示我們透過呼叫 Uniswap_v2_router.[swapExactTokensForTokens](https://docs.uniswap.org/contracts/v2/reference/smart-contracts/router-02#swapexacttokensfortokens) 函式，將 1BTC 換到 16,788 DAI.

![圖片](https://user-images.githubusercontent.com/52526645/211143644-6ed295f0-e0d8-458b-a6a7-71b2da8a5baa.png)

## Curve 3pool - DAI/USDC/USDT

![圖片](https://user-images.githubusercontent.com/52526645/211030934-14fccba9-5239-480c-b431-21de393a6308.png)

從上圖[例子](https://etherscan.io/tx/0x667cb82d993657f2779507a0262c9ed9098f5a387e8ec754b99f6e1d61d92d0b)可以解讀為:

在 Curve 3pool 增加流動性

From: 發送這筆交易的來源錢包地址

Interacted With (To): Curve.fi: DAI/USDC/USDT Pool

ERC-20 Tokens Transferred: 用戶 A 轉入 3,524,968.44 USDT 到 Curve 3 pool，然後 Curve 鑄造 3,447,897.54 3Crv 代幣給用戶 A.

透過 [phalcon](https://phalcon.blocksec.com/tx/eth/0x667cb82d993657f2779507a0262c9ed9098f5a387e8ec754b99f6e1d61d92d0b) 來看: 從調用流程來看執行了三個步驟 1.add_liquidity 2.transferFrom 3.mint

![圖片](https://user-images.githubusercontent.com/52526645/211032540-b8ad83af-44cf-48ea-b22c-6c79d4dac1af.png)

## Compound propose

![圖片](https://user-images.githubusercontent.com/52526645/211033609-60713c9d-1760-45d4-957f-a74e08abf9a5.png)

從上圖[例子](https://etherscan.io/tx/0xba69b455c511c500e0be9453cf70319bc61e29eb4235a6e5ca5fe6ddf1934159)可以解讀為: 用戶在 Compound 治理合約上提交了一個提案，從 Etherscan 上可以點擊 Decode Input Data 就可以看到提案內容。

![圖片](https://user-images.githubusercontent.com/52526645/211033906-e3446f69-404e-4347-a0c6-e1b622039c5a.png)

透過 [phalcon](https://phalcon.blocksec.com/tx/eth/0xba69b455c511c500e0be9453cf70319bc61e29eb4235a6e5ca5fe6ddf1934159) 來看: 透過呼叫 propose 函式來提交 proposal 得到編號 44 號提案。

![圖片](https://user-images.githubusercontent.com/52526645/211034346-a600cbf4-eed9-47ca-8b5a-88232808f3a3.png)

## Uniswap Flashswap

我們使用 Foundry 來模擬操作看看如何在 Uniswap 上使用閃電貸，[官方Flash swap介紹](https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps)

[範例程式碼](https://github.com/SunWeb3Sec/DeFiLabs/blob/main/src/test/Uniswapv2_flashswap.sol)參考，執行以下指令
```sh
forge test --contracts ./src/test/Uniswapv2_flashswap.sol -vvvv
```
![圖片](https://user-images.githubusercontent.com/52526645/211125357-695c3fd0-4a56-4a70-9c98-80bac65586b8.png)

以這個例子透過 Uniswap UNI/WETH 交易兌上進行閃電貸借出 100 顆 WETH，再還回去給 Uniswap. 注意還款時要付 0.3% 手續費。

從下圖調用流程可以看出，呼叫 swap 進行 flashswap 然後透過 callback uniswapV2Call 來還款。

![圖片](https://user-images.githubusercontent.com/52526645/211038895-a1bc681a-41cd-4900-a745-3d3ddd0237d4.png)

簡單區分一下 Flashloan 和 Flashswap 的差異，兩種都是無需抵押資產就可以借出 Token，且需要在同一個區塊內還回去不然交易就會失敗，假如透過 token0/token1 進行 Flashloan 借出 token0 就要還 token0回去，Flashswap 借出 token0 可以還 token0 或 token1 回去，比較彈性。

更多 DeFi 基本操作可以參考 [DeFiLabs](https://github.com/SunWeb3Sec/DeFiLabs)


## Foundry cheatcodes

Foundry 的 cheatcodes 在我們做鏈上分析必須使用到的，這邊我介紹一下常用到的函式，更多介紹可以參考 [Cheatcodes Reference](https://book.getfoundry.sh/cheatcodes/)

- createSelectFork: 指定這次測試要複製哪個網路和區塊高度，注意每條鏈的 RPC 要寫在 [foundry.toml](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/foundry.toml)
- deal: 設定測試錢包餘額 
    -  設定 ETH 餘額 `deal(address(this), 3 ether);`
    -  設定 Token 餘額 `deal(address(USDC), address(this), 1 * 1e18);`
- prank: 模擬指定錢包身份，只有在下一個呼叫有效，下一個 msg.sender 是會所指定的錢包，例如使用巨鯨錢包轉帳
- startPrank: 模擬指定錢包身份，在沒有執行`stopPrank()`之前，所有 msg.sender 都會是指定的錢包地址
- label: 將錢包地址標籤化，方便在使用 Foundry debug 時提高可讀性
- roll: 調整區塊高度
- warp: 調整 block.timestamp

謝謝收看，我們準備進入下一課

## Resources
[Foundry book](https://book.getfoundry.sh/)

[Awesome-foundry](https://github.com/crisgarner/awesome-foundry)

[Foundry @EthCC](https://www.youtube.com/watch?v=wJnywGB33O4) | [Slides](https://docs.google.com/presentation/d/1AuQojnFMkozOiR8kDu5LlWT7vv1EfPytmVEeq1XMtM0/edit#slide=id.g13d8bd167cb_0_0)

[WTF Solidity - Foundry](https://github.com/AmazingAng/WTF-Solidity/blob/main/Topics/Tools/TOOL07_Foundry/readme.md)

[Flashloan vs Flashswap](https://blog.infura.io/post/build-a-flash-loan-arbitrage-bot-on-infura-part-i)
