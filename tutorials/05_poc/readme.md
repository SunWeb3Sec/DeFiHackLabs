# OnChain Transaction Debugging: 5. Write your own POC - MevBot

Author: [Sun](https://twitter.com/1nf0s3cpt)



## 手把手撰寫 PoC - 以 Mev Bot - BNB48 為例
- 前情提要
    - 20220913 有一個 MevBot 被攻擊者發現漏洞進而將合約上的資產都轉走，共損失約 $140K.
    - 攻擊者透過 BNB48 驗證節點發送隱私交易，類似於 Flashbot 不把交易放入 mempool 而直接打包避免被搶跑攻擊.
    
- 分析
    - 攻擊者發動攻擊的 [TXID](https://bscscan.com/tx/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2)，Mev Bot合約未開源，如何利用的?
    - 透過 [phalcon](https://phalcon.blocksec.com/tx/bsc/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2) 來分析看看，從金流的部分可到這筆交易將 Mev bot 轉移了 6 種資產到攻擊者錢包上，如何利用的?
![圖片](https://user-images.githubusercontent.com/52526645/211201079-e7c5cc3b-64f8-4146-ab0e-7dd46b535cc9.png)
    - 再來換看看 Function call 調用流程，看到剛好也調用了 6 次 `pancakeCall` 函式.
        - From: `0xee286554f8b315f0560a15b6f085ddad616d0601`
        - 攻擊者合約: `0x5cb11ce550a2e6c24ebfc8df86c5757b596e69c1`
        - Mev Bot合約: `0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d`
![圖片](https://user-images.githubusercontent.com/52526645/211201456-8b6f7bca-677d-40a2-b81b-fd6af18f94fd.png)
    - 我們展開其中一個 `pancakeCall` 看看，可以看到回調到攻擊者的合約讀取了 token0()的值為 BSC-USD，緊接者就進行 transfer BSC-USD 到攻擊者的錢包，看到這邊可以知道攻擊者可能有權限或透過漏洞把 Mev Bot 合約上的資產都搬走，接下來就要找出攻擊者是怎麼利用的?
    ![圖片](https://user-images.githubusercontent.com/52526645/211201744-9895803a-5f72-4f14-b147-b67b204bee75.png)
    - 因為前面有提到 Mev Bot 合約未開源，所以這邊我們可以使用[第一課](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools)介紹的反編譯工具 [Dedaub](https://library.dedaub.com/decompile)，來分析看看可不可以發現到什麼. 首先先到 [Bscscan](https://bscscan.com/address/0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d#code) 上把合約 bytecodes 貼到 Dedaub 反編譯，如下圖我們可以看到 `pancakeCall` 函式權限設定為 public，就是公開每個人都可以調用，在閃電貸的回調公開是很正常應該沒太大問題，但是可以看到紅色框起來的地方，執行了一個 `0x10a` 函示，再往下追看看.
    ![圖片](https://user-images.githubusercontent.com/52526645/211202573-b4a4847d-a617-42c8-84d0-0f2dbd38a632.png)
   - `0x10a` 函示邏輯如下圖，可以看到關鍵看到紅色框起來的地方，先讀取攻擊者合約上的 token0 是什麼代幣然後帶入轉帳函式 `transfer`，在函式中第一個參數接收者地址 `address(MEM[varg0.data])` 是在 `pancakeCall` 的 `varg3 (_data)` 可被控制的，所以關鍵漏洞問題就在這邊.
    
      ![圖片](https://user-images.githubusercontent.com/52526645/211204177-fbebe377-23b0-4b0c-bb3e-dcb64dba2afc.png)
    
- 開發 POC
    - 通過以上分析攻擊流程後，開發 POC 的合約的邏輯就是呼叫 Mev bot 合約的 `pancakeCall` 然後帶入對應的參數，關鍵是 `_data` 指定收款錢包地址，再來是合約中要有 token0，token1 函式來滿足合約邏輯. 自己可以動手寫寫看. 
    - 解答: [POC](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/src/test/BNB48MEVBot_exp.sol) 參考.
    
      ![圖片](https://user-images.githubusercontent.com/52526645/211204852-4fa65835-17f7-4c91-80ab-79f5b46125df.png)
