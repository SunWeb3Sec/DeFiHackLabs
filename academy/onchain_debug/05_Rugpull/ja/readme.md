# オンチェーン取引のデバッグ: 5. CirculateBUSD プロジェクトのラグプル分析、$227 万ドルの損失！

著者: [Numen Cyber Technology](https://twitter.com/numencyber)

翻訳: [「」](https://x.com/yuu11111_?s=21)

2023 年 1 月 12 日午前 7 時 22 分 39 秒（UTC）、NUMEN のオンチェーンモニタリングによると、CirculateBUSD プロジェクトがコントラクト作成者によって資金を抜き取られ、227 万ドルの損失が発生しました。

このプロジェクトの資金流出は、主に管理者が CirculateBUSD.startTrading を呼び出したことによります。startTrading 内の主要な判断パラメータは、管理者が設定した非オープンソースコントラクト SwapHelper.TradingInfo によって返される値であり、その後 SwapHelper.swaptoToken を呼び出して資金が転送されます。

トランザクション：[https://bscscan.com/tx/0x3475278b4264d4263309020060a1af28d7be02963feaf1a1e97e9830c68834b3](https://bscscan.com/tx/0x3475278b4264d4263309020060a1af28d7be02963feaf1a1e97e9830c68834b3)

<div align=center>
<img src="https://miro.medium.com/max/1400/1*fLhvqu5spyN0EIycnFNqiw.png" alt="Cover" width="80%"/>
</div>

# **分析:**

まず、コントラクト startTrading（[https://bscscan.com/address/0x9639d76092b2ae074a7e2d13ac030b4b6a0313ff](https://bscscan.com/address/0x9639d76092b2ae074a7e2d13ac030b4b6a0313ff)）が呼び出され、この関数内で SwapHelper コントラクトの TradingInfo 関数が呼び出されています。詳細は以下のコードの通りです。

<div align=center>
<img src="https://miro.medium.com/max/1400/1*2LithcaYFRGcqls5IY_83g.png" alt="Cover" width="80%"/>
</div>

---

<div align=center>
<img src="https://miro.medium.com/max/1400/1*XbJHPldO3T-9frrr0SQrHA.png" alt="Cover" width="80%"/>
</div>

上の図はトランザクションのコールスタックです。コードと合わせると、TradingInfo 内部にはいくつかの静的呼び出し（Static Call）しかなく、主要な問題はこの関数にはないことがわかります。分析を続けると、コールスタックが approve 操作と safeapprove に対応していることがわかりました。次に SwapHelper の swaptoToken 関数が呼び出されており、コールスタックと組み合わせるとこれが重要な関数であることが判明し、この呼び出し内で転送トランザクションが実行されました。SwapHelper コントラクトは、以下のオンチェーン情報で確認された通り、オープンソースではありません。

[https://bscscan.com/address/0x112f8834cd3db8d2dded90be6ba924a88f56eb4b#code](https://bscscan.com/address/0x112f8834cd3db8d2dded90be6ba924a88f56eb4b#code)

リバース分析を試み、まず関数シグネチャ 0x63437561 を特定します。

<div align=center>
<img src="https://miro.medium.com/max/1400/1*i7kEvPo_8gYbNs9UGlo-KA.png" alt="Cover" width="80%"/>
</div>

その後、逆コンパイルしてこの関数を特定し、コールスタックが transfer をトリガーしていることから、transfer などのキーワードを探しました。

<div align=center>
<img src="https://miro.medium.com/max/1400/1*n8BEIqfn0tZ6plky2MFd7w.png" alt="Cover" width="80%"/>
</div>

この関数のブランチを特定し、まず stor_6_0_19,を読み出します。

<div align=center>
<img src="https://miro.medium.com/max/1400/1*ZGTqmc1sIz2_onKUT6-56Q.png" alt="Cover" width="80%"/>
</div>

この時点で、送金先アドレスは 0x0000000000000000000000005695ef5f2e997b2e142b38837132a6c3ddc463b7 であることが判明しました。これはコールスタックの送金先アドレスと同じです。

<div align=center>
<img src="https://miro.medium.com/max/1400/1*v37FEiN6L-0Nwn5OtbDgxQ.png" alt="Cover" width="80%"/>
</div>

この関数の if と else のブランチを注意深く分析したところ、if 条件を満たせば通常の償還が行われることがわかりました。これは、スロットから stor5 が 0x00000000000000000000000010ed43c718714eb63d5aa57b78b54704e256024e（このコントラクトは PancakeRouter です）であるためです。一方、else ブランチにあるバックドア機能は、渡されたパラメータと stor7 スロットに格納された値が一致すればトリガーされます。

<div align=center>
<img src="https://miro.medium.com/max/1400/1*xlYEmp6nsdLA85FUmANxfw.png" alt="Cover" width="80%"/>
</div>

以下の関数はスロット 7 の値を変更するもので、呼び出し権限はコントラクトの所有者のみが持っています。

<div align=center>
<img src="https://miro.medium.com/max/1400/1*lHLaCA9HM1HtmL3pXYxltw.png" alt="Cover" width="80%"/>
</div>

上記の分析はすべて、これがプロジェクト運営者による「ラグプル（持ち逃げ）」イベントであると断定するのに十分です。

# まとめ

Numen Cyber Labs は、ユーザーが投資を行う際には、プロジェクトのコントラクトに対してセキュリティ監査を実施する必要があることを注意喚起します。未検証のコントラクトには、プロジェクトの権限が大きすぎる、あるいはユーザーの資産の安全性を直接脅かす機能が含まれている可能性があります。このプロジェクトの問題は、ブロックチェーンエコシステム全体の問題の氷山の一角に過ぎません。ユーザーが投資を行う際やプロジェクト運営者がプロジェクトを開発する際には、必ずコードのセキュリティ監査を実施する必要があります。

Numen Cyber Labs は Web3 のエコシステムセキュリティ保護に尽力しています。最新の攻撃ニュースと分析に引き続きご注目ください。
