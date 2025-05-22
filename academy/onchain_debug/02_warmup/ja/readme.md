# オンチェーン取引のデバッグ: 2. ウォームアップ

著者: [Sun](https://twitter.com/1nf0s3cpt)

翻訳: [「」](https://x.com/yuu11111_?s=21)

コミュニティ: [Discord](https://discord.gg/Fjyngakf3h)

この記事は XREX と[WTF Academy](https://www.google.com/search?q=https://github.com/AmazingAng/WTF-Solidity%23%25E9%2593%25B2%25E4%25B8%258A%25E5%25A8%2581%25E8%2583%2581%25E5%2588%2586%25E6%259E%2590)に掲載されています。

オンチェーンデータには、シンプルな単発の送金、単一または複数の DeFi コントラクトとのインタラクション、フラッシュローンアービトラージ、ガバナンス提案、クロスチェーン取引などが含まれます。このセクションでは、簡単なところから始めましょう。
まず、ブロックチェーンエクスプローラーである Etherscan でどのような情報に注目すべきかを紹介し、次に[Phalcon](https://phalcon.blocksec.com/)を使って、資産の送金、UniSwap でのスワップ、Curve 3pool での流動性追加、Compound の提案、Uniswap の Flashswap といった取引機能の呼び出しの違いを比較します。

## ウォームアップを開始

- 最初のステップは、環境に[Foundry](https://github.com/foundry-rs/foundry)をインストールすることです。インストール[手順](https://book.getfoundry.sh/getting-started/installation)に従ってください。
  - Forge は Foundry プラットフォーム上の主要なテストツールです。Foundry を初めて使用する場合は、[Foundry book](https://book.getfoundry.sh/)、[Foundry @EthCC](https://www.youtube.com/watch?v=wJnywGB33O4)、[WTF Solidity - Foundry](https://github.com/AmazingAng/WTF-Solidity/blob/main/Topics/Tools/TOOL07_Foundry/readme.md)を参照してください。
- 各チェーンには独自のブロックチェーンエクスプローラーがあります。このセクションでは、Ethereum のブロックチェーンネットワークをケーススタディとして使用します。
- 通常私が参照する代表的な情報には以下が含まれます:
  - Transaction Action: 複雑な ERC-20 トークンの送金は判別が難しいため、Transaction Action は送金の主要な挙動を提供してくれます。ただし、すべての取引にこの情報が含まれているわけではありません。
  - From: `msg.sender`、この取引を実行する送信元のウォレットアドレス。
  - Interacted With (To): どのコントラクトとインタラクションしたか。
  - ERC-20 Token Transfer: トークンの送金プロセス。
  - Input Data: 取引の生の入力データ。どの関数が呼び出され、どのような値が渡されたかを確認できます。
- 一般的に使用されるツールがわからない場合は、[最初のレッスン](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/en)で取引分析ツールを確認できます。

## 資産の送金

![圖片](https://user-images.githubusercontent.com/52526645/211021954-6c5828be-7293-452b-8ef6-a268db54b932.png)
上記の[Etherscan](https://etherscan.io/tx/0x836ef3d01a52c4b9304c3d683f6ff2b296c7331b6fee86e3b116732ce1d5d124)の例から以下を読み取ることができます:

- From: この取引の送信元 EOA ウォレットアドレス。
- Interacted With (To): Tether USD (USDT) コントラクト。
- ERC-20 Tokens Transferred: ユーザー A のウォレットからユーザー B へ 651.13 USDT が送金された。
- Input Data: `transfer`関数が呼び出された。

[Phalcon](https://phalcon.blocksec.com/tx/eth/0x836ef3d01a52c4b9304c3d683f6ff2b296c7331b6fee86e3b116732ce1d5d124)の"Invocation Flow"によると:

- USDT の`transfer`が一度だけ呼び出されています。しかし、"Value"に注意してください。イーサリアム仮想マシン（EVM）は浮動小数点演算をサポートしていないため、代わりに`decimals`表現が使用されます。
- 各トークンには独自の精度があり、これはトークンの値を表すために使用される小数点以下の桁数です。ERC-20 トークンでは通常 18 桁ですが、USDT は 6 桁です。トークンの精度が適切に処理されないと問題が発生します。
- これについては、Etherscan の[トークンコントラクト](https://etherscan.io/token/0xdac17f958d2ee523a2206206994597c13d831ec7)で確認できます。

![圖片](https://user-images.githubusercontent.com/52526645/211123692-d7224ced-bc0b-47a1-a876-2af086e2fce9.png)

![圖片](https://user-images.githubusercontent.com/52526645/211022964-f819b35c-d442-488c-9645-7733af219d1c.png)

## Uniswap スワップ

上記の[Etherscan](https://etherscan.io/tx/0x1cd5ceda7e2b2d8c66f8c5657f27ef6f35f9e557c8d1532aa88665a37130da84)の例から以下を読み取ることができます:

- Transaction Action: ユーザーが Uniswap V2 でスワップを実行し、12,716 USDT を 7,118 UNDEAD に交換しています。
- From: この取引の送信元ウォレットアドレス。
- Interacted With (To): Uniswap コントラクトでスワップを実行するために Uniswap コントラクトを呼び出した MEV Bot コントラクト。
- ERC-20 Tokens Transferred: トークンの交換プロセス。

[Phalcon](https://phalcon.blocksec.com/tx/eth/0x1cd5ceda7e2b2d8c66f8c5657f27ef6f35f9e557c8d1532aa88665a37130da84)の"Invocation Flow"によると:

- MEV Bot が Uniswap V2 の USDT/UNDEAD 取引ペアコントラクトを呼び出し、`swap`関数を呼び出してトークン交換を実行しています。

![圖片](https://user-images.githubusercontent.com/52526645/211029737-4a606d32-2c96-41e9-aef7-82fe1fb4b21d.png)

### Foundry

Foundry を使って、Uniswap で 1BTC を DAI に交換する操作をシミュレートしてみましょう。

- [サンプルコードの参照](https://github.com/SunWeb3Sec/DeFiLabs/blob/main/src/test/Uniswapv2.sol)。以下のコマンドを実行します:

```sh
forge test --contracts ./src/test/Uniswapv2.sol -vvvv
```

- 図によると、Uniswap_v2_router の[`swapExactTokensForTokens`](https://docs.uniswap.org/contracts/v2/reference/smart-contracts/router-02#swapexacttokensfortokens)関数を呼び出すことで、1 BTC を 16,788 DAI にスワップしています。

![圖片](https://user-images.githubusercontent.com/52526645/211143644-6ed295f0-e0d8-458b-a6a7-71b2da8a5baa.png)

## Curve 3pool - DAI/USDC/USDT

![圖片](https://user-images.githubusercontent.com/52526645/211030934-14fccba9-5239-480c-b431-21de393a6308.png)

上記の[Etherscan](https://etherscan.io/tx/0x667cb82d993657f2779507a0262c9ed9098f5a387e8ec754b99f6e1d61d92d0b)の例から以下を読み取ることができます:

- この取引の目的は、Curve の 3pool に流動性を追加することです。
- From: この取引の送信元ウォレットアドレス。
- Interacted With (To): Curve.fi: DAI/USDC/USDT Pool。
- ERC-20 Tokens Transferred: ユーザー A が 3,524,968.44USDT を Curve の 3pool に送金し、その後 Curve がユーザー A に 3,447,897.543Crv トークンをミントしました。

[Phalcon](https://phalcon.blocksec.com/tx/eth/0x667cb82d993657f2779507a0262c9ed9098f5a387e8ec754b99f6e1d61d92d0b)の"Invocation Flow"によると:

- 呼び出しシーケンスに基づくと、以下の 3 つのステップが実行されました:

1.  `add_liquidity` 2. `transferFrom` 3. `mint`

![圖片](https://user-images.githubusercontent.com/52526645/211032540-b8ad83af-44cf-48ea-b22c-6c79d4dac1af.png)

## Compound 提案 (propose)

![圖片](https://user-images.githubusercontent.com/52526645/211033609-60713c9d-1760-45d4-957f-a74e08abf9a5.png)

上記の[Etherscan](https://etherscan.io/tx/0xba69b455c511c500e0be9453cf70319bc61e29eb4235a6e5ca5fe6ddf1934159)の例から以下を読み取ることができます:

- ユーザーが Compound で提案を提出しました。提案の内容は、Etherscan で"Decode Input Data"をクリックすることで確認できます。

![圖片](https://user-images.githubusercontent.com/52526645/211033906-e3446f69-404e-4347-a0c6-e1b622039c5a.png)

[Phalcon](https://phalcon.blocksec.com/tx/eth/0xba69b455c511c500e0be9453cf70319bc61e29eb4235a6e5ca5fe6ddf1934159)の"Invocation Flow"によると:

- `propose`関数を通じて提案を提出した結果、提案番号 44 が生成されました。

![圖片](https://user-images.githubusercontent.com/52526645/211034346-a600cbf4-eed9-47ca-8b5a-88232808f3a3.png)

## Uniswap Flashswap

ここでは、Foundry を使って、Uniswap でのフラッシュローン利用方法をシミュレートする操作を行います。[公式の Flashswap の紹介](https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps)も参照してください。

- [サンプルコード](https://github.com/SunWeb3Sec/DeFiLabs/blob/main/src/test/Uniswapv2_flashswap.sol)を参照し、以下のコマンドを実行します:

```sh
forge test --contracts ./src/test/Uniswapv2_flashswap.sol -vvvv
```

![圖片](https://user-images.githubusercontent.com/52526645/211125357-695c3fd0-4a56-4a70-9c98-80bac65586b8.png)

- この例では、Uniswap の UNI/WETH 交換ペアを通じて 100 WETH のフラッシュローンを借り入れています。返済時には 0.3%の手数料を支払う必要があることに注意してください。
- 図の呼び出しフローによると、Flashswap は`swap`を呼び出し、その後`uniswapV2Call`をコールバックすることで返済しています。

![圖片](https://user-images.githubusercontent.com/52526645/211038895-a1bc681a-41cd-4900-a745-3d3ddd0237d4.png)

- フラッシュローンと Flashswap のさらなる紹介:

- A. 共通点:
    どちらも担保なしでトークンを借り入れることができ、同じブロック内で返済する必要があります。そうしないと取引は失敗します。

- B. 違い:
    Flashloan で token0/token1 から token0 を借り入れた場合、token0 を返済する必要があります。Flashswap は token0 を貸し出しますが、token0 または token1 のどちらでも返済できるため、より柔軟性があります。

より多くの DeFi の基本操作については、[DeFiLab](https://github.com/SunWeb3Sec/DeFiLabs)を参照してください。

## Foundry Cheatcodes

Foundry のチートコードは、チェーン分析を行う上で不可欠です。ここでは、いくつかのよく使われる関数を紹介します。詳細については、[Cheatcodes Reference](https://book.getfoundry.sh/cheatcodes/)を参照してください。

- `createSelectFork`: テストのためにコピーするネットワークとブロック高さを指定します。各チェーンの RPC は[foundry.toml](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/foundry.toml)に含める必要があります。
- `deal`: テストウォレットの残高を設定します。
    - ETH 残高の設定: `deal(address(this), 3 ether);`
    - トークン残高の設定: `deal(address(USDC), address(this), 1 * 1e18);`
- `prank`: シミュレートするウォレットアドレスを指定します。次の呼び出しに対してのみ有効で、`msg.sender`を指定されたウォレットアドレスに設定します。例えば、クジラウォレットからの送金をシミュレートする場合などです。
- `startPrank`: シミュレートするウォレットアドレスを指定します。`stopPrank()`が実行されるまで、すべての呼び出しに対して`msg.sender`を指定されたウォレットアドレスに設定します。
- `label`: Foundry のデバッグ時に可読性を向上させるために、ウォレットアドレスにラベルを付けます。
- `roll`: ブロック高さを調整します。
- `warp`: ブロックのタイムスタンプを調整します。

お付き合いいただきありがとうございます！次のレッスンに進みましょう。

## リソース

[Foundry book](https://book.getfoundry.sh/)

[Awesome-foundry](https://github.com/crisgarner/awesome-foundry)

[Flashloan vs Flashswap](https://blog.infura.io/post/build-a-flash-loan-arbitrage-bot-on-infura-part-i)
