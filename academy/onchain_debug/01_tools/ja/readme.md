# オンチェーン取引のデバッグ: 1. ツール

著者: [Sun](https://twitter.com/1nf0s3cpt)

コミュニティ: [Discord](https://discord.gg/Fjyngakf3h)

この記事は XREX と[WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)に掲載されています。

オンチェーン取引の分析を学び始めた頃、オンラインのリソースは非常に限られていました。しかし、少しずつ情報を集め、テストと分析を重ねることができました。

私の研究から、Web3セキュリティに関する一連の記事を公開し、より多くの人々にWeb3セキュリティに参加してもらい、共に安全なネットワークを構築することを目指します。

このシリーズの初回では、オンチェーン分析の実施方法を紹介し、その後、オンチェーン攻撃を再現します。このスキルは、攻撃プロセス、脆弱性の根本原因、さらにはアービトラージボットがどのようにアービトラージを行うかを理解するのに役立ちます。

## ツールは効率を大幅に向上させる

分析に入る前に、いくつかの一般的なツールを紹介します。適切なツールは、より効率的に調査を行うのに役立ちます。

### 取引デバッグツール

[Phalcon](https://phalcon.blocksec.com/) | [Tx.viewer](https://tx.eth.samczsun.com/) | [Cruise](https://cruise.supremacy.team/) | [Ethtx](https://ethtx.info/) | [Tenderly](https://dashboard.tenderly.co/explorer)

Transaction Viewerは最も一般的に使用されるツールで、関数呼び出しのスタックトレースと、取引中の各関数における入力データを一覧表示できます。Transaction Viewerツールはどれも似ていますが、主な違いはチェーンサポートと補助機能のサポートです。私は個人的にPhalconとSamのTransaction Viewerを使用しています。サポートされていないチェーンに遭遇した場合は、Tenderly を使用します。Tenderlyはほとんどのチェーンをサポートしていますが、可読性が限られており、デバッグ機能を使用すると分析が遅くなることがあります。しかし、Ethtxとともに私が最初に学んだツールの 1 つです。

#### チェーンサポートの比較

Phalcon: `Ethereum、BSC、Avalanche C-Chain、Polygon、Solana、Arbitrum、Fantom、Optimism、Base、Linea、zkSync Era、Kava、Evmos、Merlin、Manta、Mantle、Holesky testnet、Sepolia testnet`

Sam's Transaction Viewer: `Ethereum、Polygon、BSC、Avalanche C-Chain、Fantom、Arbitrum、Optimism`

Cruise: `Ethereum、BSC、Polygon、Arbitrum、Fantom、Optimism、Avalanche、Celo、Gnosis`

Ethtx: `Ethereum、Goerli testnet`

Tenderly: `Ethereum、Polygon、BSC、Sepolia、Goerli、Gnosis、POA、RSK、Avalanche C-Chain、Arbitrum、Optimism、Fantom、Moonbeam、Moonriver`

#### 実践

JayPeggers の「不十分な検証 + 再入可能」の[インシデント](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/past/2022/README.md#20221229---jay---insufficient-validation--reentrancy)を例にとり、[TXID](https://phalcon.blocksec.com/tx/eth/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6)を分析します。

まず、Blocksecが開発したPhalcon ツールを使って説明します。取引の基本情報と残高の変更が下の図に示されています。残高の変更から、攻撃者がどれだけの利益を得たかを素早く確認できます。この例では、攻撃者は15.32 ETHの利益を得ました。

![210571234-402d96aa-fe5e-4bc4-becc-190bd5a78e68-2](https://user-images.githubusercontent.com/107249780/210686382-cc02cc6a-b8ec-4cb7-ac19-402cd8ff86f6.png)

Invocation Flow Visualizationは、トレースレベルの情報とイベントログを含む関数呼び出しの視覚化です。これには、呼び出しの実行、この取引の関数呼び出しレベル、フラッシュローンが使用されたかどうか、関与したプロジェクト、呼び出された関数、およびどのようなパラメータと生データが渡されたかなどが示されます。

![圖片](https://user-images.githubusercontent.com/52526645/210572053-eafdf62a-7ebe-4caa-a905-045e792add2b.png)


Phalcon 2.0では、資金フローとデバッグ+ソースコード分析が追加され、トレースとともにソースコード、パラメータ、戻り値が直接表示されるため、分析がより便利になりました。

![image](https://user-images.githubusercontent.com/107249780/210821062-d1da8d1a-9615-4f1f-838d-34f27b9c3f41.png)

次に、同じ[TXID](https://tx.eth.samczsun.com/ethereum/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6)を SamのTransaction Viewerで試してみましょう。Samは多くのツールを統合しており、下の図に示すように、ストレージの変更と各呼び出しで消費されたガスを確認できます。

左側のCallをクリックすると、Raw Inputデータがデコードされます。

では、同じ[TXID](https://dashboard.tenderly.co/tx/mainnet/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6)を Tenderlyで分析してみましょう。他のツールと同様に、基本情報を確認できます。しかし、デバッグ機能を使用すると、視覚化されず、ステップバイステップで分析する必要があります。ただし、デバッグ中にコードと入力データの変換プロセスを表示できるという利点があります。

これは、この取引が行ったすべてのことを明確にするのに役立ちます。POCを書く前に、リプレイ攻撃を実行できますか？はい、できます！TenderlyもPhalconもシミュレートされた取引をサポートしており、上の図の右上にRe-Simulateボタンがあります。ツールは下の図に示すように、取引からパラメータ値を自動的に入力します。ブロック番号、From、Gas、入力データなど、シミュレーションの必要に応じてパラメータを任意に変更できます。

### Ethereum 署名データベース

[4byte](https://www.4byte.directory/) | [sig.eth](https://sig.eth.samczsun.com/) | [etherface](https://www.etherface.io/hash)

Raw Input データの最初の4バイトは関数署名です。Etherscanや分析ツールが関数を識別できない場合、署名データベースを通じて可能な関数を確認できます。

以下の例では、関数`0xac9650d8`が何であるかわからないと仮定します。

sig.eth でクエリを実行すると、4 バイトの署名が`multicall(bytes[])`であることがわかります。

![圖片](https://user-images.githubusercontent.com/52526645/210583416-c31bbe07-fa03-4701-880d-0ae485b171f7.png)

### 便利なツール

[ABI to interface](https://gnidan.github.io/abi-to-sol/) | [Get ABI for unverified contracts](https://abi.w1nt3r.xyz/) | [ETH Calldata Decoder](https://apoorvlathey.com/eth-calldata-decoder/) | [ETHCMD - Guess ABI](https://www.ethcmd.com/)

ABI to interface: POCを開発する際には、他のコントラクトを呼び出すためのインターフェースが必要です。このツールを使用すると、インターフェースを素早く生成できます。Etherscanで ABI をコピーし、ツールに貼り付けると、生成されたインターフェースが表示されます。[Example](https://etherscan.io/address/0xb3da8d6da3ede239ccbf576ca0eaa74d86f0e9d3#code)

![圖片](https://user-images.githubusercontent.com/52526645/210587442-e7853d8b-0613-426e-8a27-d70c80e2a42d.png)
![圖片](https://user-images.githubusercontent.com/52526645/210587682-5fb07a01-2b21-41fa-9ed5-e7f45baa0b3e.png)

ETH Calldata Decoder: ABIなしでInputデータをデコードしたい場合は、このツールが必要です。前述のSamのTransaction ViewerもInputデータのデコードをサポートしています。

![圖片](https://user-images.githubusercontent.com/52526645/210585761-efd8b6f1-b901-485f-ae66-efaf9c84869c.png)

Obtain ABI for unverified contracts: 検証されていないコントラクトに遭遇した場合、このツールを使用して関数署名を推定できます。

![圖片](https://user-images.githubusercontent.com/52526645/210588945-701b0e22-7390-4539-9d2f-e13479b52824.png)

### 逆コンパイルツール

[Etherscan-decompile bytecode](https://etherscan.io/address/0xaE9C73fd0Fd237c1c6f66FE009d24ce969e98704#code) | [Dedaub](https://library.dedaub.com/decompile) | [heimdall-rs](https://github.com/Jon-Becker/heimdall-rs)
Etherscan には逆コンパイル機能が組み込まれていますが、結果の可読性は低いことが多いです。個人的には、より良い逆コンパイルコードを生成するDedaubをよく使用しています。これは私のおすすめの逆コンパイラです。攻撃された MEV Bot を例に、この[コントラクト](https://twitter.com/1nf0s3cpt/status/1577594615104172033)を自分で逆コンパイルしてみてください。

まず、検証されていないコントラクトのバイトコードをコピーし、Dedaub に貼り付けてDecompileをクリックします。
![截圖 2023-01-05 上午10 33 15](https://user-images.githubusercontent.com/107249780/210688395-927c6126-b6c1-4c6d-a0c7-a3fea3db9cdb.png)

![圖片](https://user-images.githubusercontent.com/52526645/210591478-6fa928f3-455d-42b5-a1ac-6694f97386c2.png)

さらに詳しく学びたい場合は、以下の動画を参照してください。

## リソース

[samczsun's eth txn explorer and vscode extension](https://www.youtube.com/watch?v=HXgu239mPBc)

[Vulnerabilities in DeFi by Daniel V.F.](https://www.youtube.com/watch?v=9fcOffCg2ig)

[Tenderly.co - Debug Transaction](https://www.youtube.com/watch?v=90GN9Ut8LhU)

[Reversing The EVM: Raw Calldata](https://degatchi.com/articles/reading-raw-evm-calldata)

https://web3sec.xrex.io/
