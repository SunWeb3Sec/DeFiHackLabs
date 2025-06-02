# オンチェーン取引のデバッグ: 6. 独自の PoC を作成する (リエントランシー)

著者: [gbaleeee](https://twitter.com/gbaleeeee)

翻訳: [「」](https://x.com/yuu11111_?s=21)

コミュニティ: [Discord](https://discord.gg/Fjyngakf3h)

この著作は XREX | [WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)でも公開されています。

この記事では、実際の攻撃を実演し、Foundry を使用してテストと攻撃の再現を行うことで、リエントランシーについて学びます。

## 前提条件

1.  スマートコントラクトにおける一般的な攻撃ベクトルを理解していること。[DeFiVulnLabs](https://github.com/SunWeb3Sec/DeFiVulnLabs)は、学習を始めるのに最適なリソースです。
2.  基本的な DeFi モデルがどのように機能し、スマートコントラクトが他のコントラクトとどのように相互作用するかを知っていること。

## リエントランシー攻撃とは

出典: Consensys による[Reentrancy](https://consensysdiligence.github.io/smart-contract-best-practices/attacks/reentrancy/)。

リエントランシー攻撃は、よく知られた攻撃ベクトルです。[DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs)のデータベースを見ると、ほぼ毎月発生しています。リエントランシー攻撃のコレクションを維持している別の素晴らしいリポジトリ、[reentrancy-attacks](https://github.com/pcaversaccio/reentrancy-attacks)もあります。

簡単に言えば、ある関数が信頼できない外部呼び出しを行った場合、リエントランシー攻撃のリスクが生じる可能性があります。

リエントランシー攻撃は、主に以下の 3 つのタイプに分類できます。

1.  単一関数リエントランシー (Single Function Reentrancy)
2.  クロス関数リエントランシー (Cross-Function Reentrancy)
3.  クロスコントラクトリエントランシー (Cross-Contract Reentrancy)

## 実践的な PoC - DFX Finance

- 出典: [Pckshield alert 11/11/2022](https://twitter.com/peckshield/status/1590831589004816384)

  > DFXFinance の DEX プール（Curve と名付けられた）が、適切なリエントランシー保護の欠如によりハッキングされたようです（3000 ETH、約 400 万ドルが損失）。以下にトランザクションの例を示します: [https://etherscan.io/tx/0x6bfd9e286e37061ed279e4f139fbc03c8bd707a2cdd15f7260549052cbba79b7](https://etherscan.io/tx/0x6bfd9e286e37061ed279e4f139fbc03c8bd707a2cdd15f7260549052cbba79b7)。盗まれた資金は TornadoCash に入金されています。

- トランザクション概要

  上記のトランザクションに基づいて、etherscan からは限られた情報しか得られません。送信者（攻撃者）、攻撃者のコントラクト、トランザクション中のイベントなどが含まれます。このトランザクションは"MEV トランザクション"および"Flashbots"とラベル付けされており、攻撃者がフロントランニングボットの影響を回避しようとしたことを示しています。

  ![image](https://user-images.githubusercontent.com/53768199/215320542-a7798698-3fd4-4acf-90bf-263d37379795.png)

- トランザクション分析
  さらなる調査には、Blocksec の[Phalcon from Blocksec](https://phalcon.blocksec.com/tx/eth/0x6bfd9e286e37061ed279e4f139fbc03c8bd707a2cdd15f7260549052cbba79b7)を使用できます。

- 残高分析
  *Balance Changes*セクションでは、このトランザクションによる資金の変更を確認できます。攻撃コントラクト（受信者）は大量の`USDC`と`XIDR`トークンを利益として取得し、`dfx-xidr-v2`という名前のコントラクトは大量の`USDC`と`XIDR`トークンを失いました。同時に、`0x27e8`で始まるアドレスもいくらかの`USDC`と`XIDR`トークンを取得しました。このアドレスの調査によると、これは DFX Finance: Governance Multi-Signature ウォレットアドレスです。

  ![image](https://user-images.githubusercontent.com/53768199/215320922-72207a7f-cfac-457d-b69e-3fddc043206b.png)

  上記の観測に基づくと、被害者は DFX Finance の`dfx-xidr-v2`コントラクトであり、損失資産は`USDC`および`XIDR`トークンです。DFX のマルチシグアドレスもプロセス中にいくつかのトークンを受け取っています。私たちの経験から、これは手数料ロジックに関連しているはずです。

- 資産フロー分析
  Blocksec の別のツールである[metasleuth](https://metasleuth.io/result/eth/0x6bfd9e286e37061ed279e4f139fbc03c8bd707a2cdd15f7260549052cbba79b7)を使用して、資産フローを分析できます。

  ![image](https://user-images.githubusercontent.com/53768199/215321213-7ead5043-1410-4ab6-b247-1e710d931fe8.png)

  上記のグラフに基づくと、攻撃者はステップ[1]と[2]で被害者コントラクトから大量の`USDC`、`XIDR`トークンを借り入れました。ステップ[3]と[4]で、借り入れた資産は被害者コントラクトに送り返されました。その後、ステップ[5]で`dfx-xidr-v2`トークンが攻撃者にミントされ、DFX マルチシグウォレットはステップ[6]と[7]で`USDC`と`XIDR`の両方で手数料を受け取ります。最終的に、`dfx-xidr-v2`トークンは攻撃者のアドレスからバーンされます。

  まとめると、資産フローは以下の通りです:

  1.  攻撃者は被害者コントラクトから`USDC`、`XIDR`トークンを借りました。
  2.  攻撃者は借りた`USDC`、`XIDR`トークンを被害者コントラクトに返送しました。
  3.  攻撃者は`dfx-xidr-v2`トークンをミントしました。
  4.  DFX マルチシグウォレットは`USDC`、`XIDR`トークンを受け取りました。
  5.  攻撃者は`dfx-xidr-v2`トークンをバーンしました。

  この情報は、以下のトレース分析で確認できます。

- トレース分析

  トランザクションをレベル 2 まで展開して見てみましょう。

  ![image](https://user-images.githubusercontent.com/53768199/215321768-6aa93999-9a77-4af5-b758-dd91f7dc3973.png)

  完全な攻撃トランザクションの関数実行フローは次のように見ることができます。

  1.  攻撃者は攻撃のために関数`0xb727281f`を呼び出しました。
  2.  攻撃者は`staticcall`を介して`dfx-xidr-v2`コントラクト内の`viewDeposit`を呼び出しました。
  3.  攻撃者は`call`で`dfx-xidr-v2`コントラクト内の`flash`関数をトリガーしました。このトレースでは、攻撃コントラクト内の関数`0xc3924ed6`がコールバックとして使用されたことに注目する価値があります。

  4.  攻撃者は`dfx-xidr-v2`コントラクトの`withdraw`関数を呼び出しました。

- 詳細分析

  攻撃者が最初の手順で`viewDeposit`関数を呼び出した意図は、`viewDeposit`関数のコメントに見られます。攻撃者は、200_000 \* 1e18 `dfx-xidr-v2`トークンをミントするために、`USDC`、`XIDR`トークンの量を取得したいと考えています。

  ![image](https://user-images.githubusercontent.com/53768199/215324532-b441691f-dae4-4bb2-aadb-7bd93d284270.png)

  そして次のステップでは、攻撃は`viewDeposit`関数からの戻り値を`flash`関数呼び出しの入力の類似値として使用します（値は完全に同じではありません。詳細は後述）。

  ![image](https://user-images.githubusercontent.com/53768199/215329296-97b6af11-32aa-4d0a-a7c4-019f355be04d.png)

  攻撃者は 2 番目のステップとして、被害者コントラクトの`flash`関数を呼び出します。コードからいくつかの洞察を得ることができます。

  ![image](https://user-images.githubusercontent.com/53768199/215329457-3a48399c-e2e1-43a8-ab63-a89375fbc239.png)

  ご覧の通り、`flash`関数は Uniswap V2 のフラッシュローンに似ています。ユーザーはこの関数を介して資産を借りることができます。そして`flash`関数はユーザー向けのコールバック関数を持っています。コードは次の通りです。

  ```solidity
  IFlashCallback(msg.sender).flashCallback(fee0, fee1, data);
  ```

  この呼び出しは、以前のトレース分析セクションにおける攻撃者のコントラクト内のコールバック関数に対応しています。4 バイトハッシュ検証を行うと、それは`0xc3924ed6`です。

  ![image](https://user-images.githubusercontent.com/53768199/215329899-a6f2cc00-f2ac-49c8-b4df-38bb24663f37.png)

  ![image](https://user-images.githubusercontent.com/53768199/215329919-bbeb557d-41d0-47fb-bdf8-321e5217854e.png)

  最後のステップは`withdraw`関数の呼び出しで、これによりステーブルトークン（`dfx-xidr-v2`）がバーンされ、ペアになった資産（`USDC`、`XIDR`）が引き出されます。

  ![image](https://user-images.githubusercontent.com/53768199/215330132-7b54bf35-3787-495a-992d-ac2bcabb97d9.png)

- PoC の実装

  上記の分析に基づき、以下の PoC の骨格を実装できます。

  ```solidity
  contract EXP {
      uint256 amount;
      function testExploit() public{
        uint[] memory XIDR_USDC = new uint[](2);
        XIDR_USDC[0] = 0;
        XIDR_USDC[1] = 0;
        ( , XIDR_USDC) = dfx.viewDeposit(200_000 * 1e18);
        dfx.flash(address(this), XIDR_USDC[0] * 995 / 1000, XIDR_USDC[1] * 995 / 1000, new bytes(1)); // 5% fee
        dfx.withdraw(amount, block.timestamp + 60);
    }

    function flashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external{
        /*
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        */
    }
  }
  ```

  フラッシュローンで`withdraw`関数を使って攻撃者が資産を盗む方法について疑問が生じるかもしれません。明らかに、これは攻撃者が唯一利用できる部分です。では、コールバック関数を見てみましょう。

  ![image](https://user-images.githubusercontent.com/53768199/215330695-1b1fa612-4f01-4c6a-a5be-7324f464ecb1.png)

  ご覧の通り、攻撃者は被害者コントラクトの`deposit`関数を呼び出し、プールがサポートする基軸資産を受け取り、カーブトークンをミントします。上記のグラフで述べたように、`USDC`と`XIDR`は`transferFrom`を介して被害者に送られます。

  ![image](https://user-images.githubusercontent.com/53768199/215330576-d15642f7-5819-4e83-a8c8-1d3a48ad8c6d.png)

  この時点で、フラッシュローンの完了は、コントラクト内の対応するトークン資産がフラッシュローンコールバック実行前の状態以上であるかを確認することによって決定されることが知られています。そして、`deposit`関数がこの検証を完了させます。

  ```solidity
  require(balance0Before.add(fee0) <= balance0After, 'Curve/insufficient-token0-returned');
  require(balance1Before.add(fee1) <= balance1After, 'Curve/insufficient-token1-returned');
  ```

  攻撃者は、攻撃前にフラッシュローンの手数料メカニズムのためにいくらかの`USDC`と`XIDR`トークンを用意していたことに注意が必要です。これが、攻撃者のデポジットが借入額よりも比較的高い理由です。したがって、`deposit`呼び出しの合計額は、フラッシュローンで借りた金額と手数料の合計です。これにより、`flash`関数内の検証を通過できます。

  結果として、攻撃者はコールバック関数内で`deposit`を呼び出し、フラッシュローンの検証を迂回し、デポジットの記録を残しました。これらすべての操作の後、攻撃者はトークンを引き出しました。

  まとめると、攻撃全体の流れは以下の通りです。

  1.  事前に`USDC`と`XIDR`トークンを用意する。
  2.  `viewDeposit()`を使用して、後続の`deposit()`に必要な資産量を取得する。
  3.  ステップ 2 の戻り値に基づいて`USDC`と`XIDR`トークンをフラッシュする。
  4.  フラッシュローンコールバック内で`deposit()`関数を呼び出す。
  5.  前のステップでデポジット記録があるため、トークンを引き出す。

  完全な PoC の実装：

  ```solidity
  contract EXP {
      uint256 amount;
      function testExploit() public{
        uint[] memory XIDR_USDC = new uint[](2);
        XIDR_USDC[0] = 0;
        XIDR_USDC[1] = 0;
        ( , XIDR_USDC) = dfx.viewDeposit(200_000 * 1e18);
        dfx.flash(address(this), XIDR_USDC[0] * 995 / 1000, XIDR_USDC[1] * 995 / 1000, new bytes(1)); // 5% fee
        dfx.withdraw(amount, block.timestamp + 60);
    }

      function flashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external{
        (amount, ) = dfx.deposit(200_000 * 1e18, block.timestamp + 60);
    }
  }
  ```

  より詳細なコードベースは DefiHackLabs リポジトリで見つけることができます: [DFX_exp.sol](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/src/test/2022-11/DFX_exp.sol)

- 資金フローの検証

  次に、トランザクション中のトークンイベントで資産フローグラフを検証できます。

  ![image](https://user-images.githubusercontent.com/53768199/215331469-e1edd9b4-5147-4f82-9e38-64edce3cc91f.png)

  `deposit`関数の最後に、`dfx-xidr-v2`トークンが攻撃者にミントされました。

  ![image](https://user-images.githubusercontent.com/53768199/215331545-9730e5b0-564d-45d8-b169-3b7c8651962f.png)

  `flash`関数では、送金イベントが DFX マルチシグウォレットへの手数料徴収（`USDC`と`XIDR`）を示しています。

  ![image](https://user-images.githubusercontent.com/53768199/215331819-d80a1775-4056-4ddd-9083-6f5241d07213.png)

  `withdraw`関数は、以前のステップでミントされた`dfx-xidr-v2`トークンをバーンしました。

- まとめ

  DFX Finance のリエントランシー攻撃は典型的なクロス関数リエントランシー攻撃であり、攻撃者はフラッシュローンコールバック関数内で`deposit`関数を呼び出すことによってリエントランシーを完了させました。

  特筆すべきは、この攻撃の手法が CTF `damnvulnerabledefi`の第 4 問である「Side Entrance」と全く同じである点です。もしプロジェクト開発者が事前に注意深く対応していれば、おそらくこの攻撃は起こらなかったでしょう 🤣。同年 12 月には、[Defrost](https://github.com/SunWeb3Sec/DeFiHackLabs#20221223---defrost---reentrancy)プロジェクトも同様の問題で攻撃を受けました。

## 学習資料

[Reentrancy Attacks on Smart Contracts Distilled](https://blog.pessimistic.io/reentrancy-attacks-on-smart-contracts-distilled-7fed3b04f4b6)  
[C.R.E.A.M. Finance Post Mortem: AMP Exploit](https://medium.com/cream-finance/c-r-e-a-m-finance-post-mortem-amp-exploit-6ceb20a630c5)  
[Cross-Contract Reentrancy Attack](https://inspexco.medium.com/cross-contract-reentrancy-attack-402d27a02a15)  
[Sherlock Yield Strategy Bug Bounty Post-Mortem](https://mirror.xyz/0xE400820f3D60d77a3EC8018d44366ed0d334f93C/LOZF1YBcH1eBdxlC6HP223cAMeTpNgQ-Kc4EjQuxmGA)  
[Decoding $220K Read-only Reentrancy Exploit | QuillAudits](https://quillaudits.medium.com/decoding-220k-read-only-reentrancy-exploit-quillaudits-30871d728ad5)
