# オンチェーン取引のデバッグ: 4. 独自の PoC を作成する - MEV Bot

著者: [Sun](https://twitter.com/1nf0s3cpt)

翻訳: [「」](https://x.com/yuu11111_?s=21)

コミュニティ: [Discord](https://discord.gg/Fjyngakf3h)

この記事は XREX と[WTF Academy](https://www.google.com/search?q=https://github.com/AmazingAng/WTF-Solidity%23%25E9%2593%25B2%25E4%25B8%258A%25E5%25A8%2581%25E8%2583%2581%25E5%2588%2586%25E6%259E%2590)で公開されています。

## MEV Bot (BNB48)を例にした PoC のステップバイステップ作成

- 要約

  - 2022 年 9 月 13 日、MEV Bot が攻撃者によって悪用され、コントラクト上の全資産が奪われました。総損失額は約 14 万ドルです。
  - 攻撃者は BNB48 のバリデーターノードを通じてプライベートトランザクションを送信しました。これは、フロントランニングを回避するためにトランザクションを公開メモリプールに入れない Flashbot と似た方法です。

- 分析

  - 攻撃者の[TXID](https://bscscan.com/tx/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2)を確認すると、MEV Bot コントラクトが未検証（オープンソースではない）であることが分かります。攻撃者はどのようにして悪用したのでしょうか？
  - [phalcon](https://phalcon.blocksec.com/tx/bsc/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2)を使って確認すると、このトランザクション内のファンクションフローの部分から、MEV Bot が 6 種類の資産を攻撃者のウォレットに転送していることが分かります。攻撃者はどのようにして悪用したのでしょうか？
    ![圖片](https://user-images.githubusercontent.com/52526645/211201079-e7c5cc3b-64f8-4146-ab0e-7dd46b535cc9.png)

- Function call の呼び出しプロセスを見てみましょう。`pancakeCall`関数がちょうど 6 回呼び出されていることが分かります。
  - From: `0xee286554f8b315f0560a15b6f085ddad616d0601`
  - 攻撃者のコントラクト: `0x5cb11ce550a2e6c24ebfc8df86c5757b596e69c1`
  - MEV Bot コントラクト: `0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d`
    ![圖片](https://user-images.githubusercontent.com/52526645/211201456-8b6f7bca-677d-40a2-b81b-fd6af18f94fd.png)
- `pancakeCall`の 1 つを展開して見てみましょう。攻撃者のコントラクトへのコールバックが`token0()`の値を BSC-USD として読み取り、その後 BSC-USD を攻撃者のウォレットに転送していることが分かります。このことから、攻撃者が MEV Bot コントラクト上のすべての資産を移動させる許可を持っているか、脆弱性を利用した可能性があることが分かりますが、次のステップでは、攻撃者がどのようにそれを利用したかを見つける必要があります。
  ![圖片](https://user-images.githubusercontent.com/52526645/211201744-9895803a-5f72-4f14-b147-b67b204bee75.png)

- MEV Bot コントラクトがオープンソースではないと前述したため、ここでは[Lesson 1](https://www.google.com/search?q=https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools)で紹介した逆コンパイルツール[Dedaub](https://library.dedaub.com/decompile)を使用します。何か見つけられるか分析してみましょう。まず、[Bscscan](https://bscscan.com/address/0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d#code)からコントラクトのバイトコードをコピーし、Dedaub に貼り付けて逆コンパイルします。下図に示すように、`pancakeCall`関数の権限が`public`に設定されており、誰でも呼び出せるようになっています。これは正常であり、Flash Loan のコールバックでは大きな問題にならないはずですが、赤枠の部分を見ると、`0x10a`関数が実行されています。次にそれを見てみましょう。
  ![圖片](https://user-images.githubusercontent.com/52526645/211202573-b4a4847d-a617-42c8-84d0-0f2dbd38a632.png)
- `0x10a`関数のロジックは下図の通りです。赤枠内のキーポイントに注目してください。まず、攻撃者のコントラクトにある`token0`がどのトークンであるかを読み込み、それを`transfer`関数に渡します。`transfer`関数の最初のパラメータである受信者のアドレス`address(MEM[varg0.data])`は、`pancakeCall`の`varg3 (_data)`で制御できるため、主要な脆弱性の問題はここにあります。

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211204177-fbebe377-23b0-4b0c-bb3e-dcb64dba2afc.png" alt="Cover" width="80%"/>
</div>

- 攻撃者が`pancakeCall`を呼び出す際のペイロードを振り返ると、`_data`の入力値の最初の 32 バイトが受取人ウォレットアドレスになっています。

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211453390-502db65b-cf82-4805-a463-04fc5c7e0dce.png" alt="Cover" width="80%"/>
</div>

- PoC の作成
  - 上記の攻撃プロセスを分析した後、PoC を作成するロジックは、MEV ボットコントラクトの`pancakeCall`を呼び出し、対応するパラメータを渡すことです。鍵となるのは、受信ウォレットアドレスを指定する`_data`であり、またコントラクトのロジックを満たすために`token0`、`token1`関数が存在する必要があります。自分で書いてみてください。
  - 解答: [POC](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/src/test/2022-09/BNB48MEVBot_exp.sol)。

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211204852-4fa65835-17f7-4c91-80ab-79f5b46125df.png" alt="Cover" width="80%"/>
</div>

## 拡張学習

- Foundry trace

  - Foundry を使用してトランザクションの関数トレースもリストアップできます。以下の通りです:

  `cast run 0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2 --quick --rpc-url https://rpc.ankr.com/bsc`

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211562868-12fde773-948c-47a9-acaf-6f744438925e.png" alt="Cover" width="80%"/>
</div>

- Foundry debug

  - Foundry を使用してトランザクションをデバッグすることもできます。以下の通りです:

  `cast run 0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2 --quick --debug  --rpc-url https://rpc.ankr.com/bsc`

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211565713-fdf3784f-da54-42e8-ad60-591ecac38c15.png" alt="Cover" width="80%"/>
</div>

## リソース

[Flashbots: Kings of The Mempool](https://noxx.substack.com/p/flashbots-kings-of-the-mempool?utm_source=profile&utm_medium=reader2)

[MEV Markets Part 1: Proof of Work](https://mirror.xyz/0xshittrader.eth/WiV8DM3I6abNMVsXf-DqioYb2NglnfjmM-zSsw2ruG8)

[MEV Markets Part 2: Proof of Stake](https://mirror.xyz/0xshittrader.eth/c6J_PCK87K3joTWmLEtG6qVN6BFXLBZxQniReYSEjLI)

[MEV Markets Part 3: Payment for Order Flow](https://mirror.xyz/0xshittrader.eth/f2VSuoZ91vAbCv82MtWM-Gosyf_DeUXfPlDx3EYV3RM)
