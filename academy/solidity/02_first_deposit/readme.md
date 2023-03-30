# Lesson 2: First Deposit Bug in CompoundV2 and its forks

作者: [Akshay Srivastav](https://twitter.com/akshaysrivastv)

翻譯: [SunSec](https://twitter.com/1nf0s3cpt)

**注意**: 此問題 Compound 已修復，本文章僅教學使用，提升安全開發意識.

Compound Finance V2 是一個建立在以太坊區塊鏈之上的去中心化借貸協議，該協議以去中心化和無信任的方式促進了加密貨幣資產的借貸，Compound 協議的簡單性和穩健性已經吸引了數十億美元作為其TVL，在高峰期超過 100 億美元.

最近，CompoundV2 智能合約中發現了一個潛在的漏洞，允許攻擊者竊取複合市場初始借貸人的資金.

讓我們深入了解該漏洞的細節.

CToken 是一種有收益的資產 (可以想像成可以收利息的概念)，當用戶將一些單位的加密資產存入 Compound 時就會被鑄造出來。鑄造給用戶的 CToken 的數量是根據用戶存入的加密貨幣的數量來計算的.

根據 CToken 合約的實作，存在兩種 CToken 計算鑄造多少數量的方法:

1. 首次存款 - 當 `CToken.totalSupply()` 為 `0`.
2. 所有後續存款


以下是CToken的實際程式碼，(為了更好地閱讀，多餘的代碼和註釋就拿掉了)，完成程式可參考 Compound [github](https://github.com/compound-finance/compound-protocol):

```
function exchangeRateStoredInternal() virtual internal view returns (uint) {
    uint _totalSupply = totalSupply;
    if (_totalSupply == 0) {
        return initialExchangeRateMantissa;
    } else {
        uint totalCash = getCashPrior();
        uint cashPlusBorrowsMinusReserves = totalCash + totalBorrows - totalReserves;
        uint exchangeRate = cashPlusBorrowsMinusReserves * expScale / _totalSupply;
        return exchangeRate;
    }
}

function mintFresh(address minter, uint mintAmount) internal {
    // ...
    Exp memory exchangeRate = Exp({mantissa: exchangeRateStoredInternal()});

    uint actualMintAmount = doTransferIn(minter, mintAmount);

    uint mintTokens = div_(actualMintAmount, exchangeRate);

    totalSupply = totalSupply + mintTokens;
    accountTokens[minter] = accountTokens[minter] + mintTokens;
    // ...
}
```

## 漏洞

從上述程式中存在一個關鍵的錯誤，可以被利用來竊取新部署的 CToken 市場的初始存款人的資金.

如果你仔細觀察，這些公式可以被簡化並寫成以下內容.

```
Exchange rate = underlying.balanceOf(CToken) * 1e18 / CToken.totalSupply()

CToken amount = User deposit amount / Exchange rate
```
有發現到了嗎?

如果交換匯率 (Exchange rate) 可以增加到大於用戶的存款值，會發生什麼？

CToken 的輸出金額就會變成`0`.

### 詳細分析:

由於交換匯率 (Exchange rate) 取決於 CToken 的總供應量與 CToken 合約的加密貨幣餘額的比率，攻擊者可以利用此問題來操縱交換匯率.
攻擊流程:

1. 一旦 CToken 被部署並加入到借貸協議中，攻擊者需要先 mint 最少量的 CTokens。 例如先存去 1 wei.

2. 然後攻擊者向 CToken 合約存款轉入加密貨幣，人為地抬高 `underlying.balanceOf(CToken)` 值.

    由於上述步驟，在下一次合法用戶存款時，用戶的 `mintTokens` 值將變得小於`1`，然後被 Solidity 四捨五入變成`0`。因為 EVM 不支援浮點數運算所以 `0.99` 會被 EVM 認為 `0`. 因此，用戶在他的存款中獲得了`0` CToken，而 CToken 的全部供應量則由攻擊者持有.

3. 攻擊者可以簡單地將他的 cToken 餘額兌換為 CToken 合約內全部的 `underlying 加密貨幣`.

同樣的步驟可以再次進行，以竊取下一個用戶的存款。

值得注意的是，這種攻擊可以通過兩種方式:
* 攻擊者可以在 CToken 被添加到借貸協議後，簡單地執行步驟1和2.
* 攻擊者觀察網絡中的待處理交易，通過執行步驟1和2對用戶的存款交易進行搶跑操作，然後用步驟3在用戶交易完成後操作.


## 影響

一個複雜的攻擊可以影響所有初始用戶的存款，直到借貸協議所有者和用戶被通知，協議暫停。由於這種攻擊是一種可複制的攻擊，它可以連續進行，以竊取所有試圖存入新 CToken 合約的儲戶的存款.

損失金額將是用戶向 CToken 所做的所有存款的總和，乘以相關代幣的價格.

假設有 10 個用戶，每個用戶都試圖將 `1,000,000` 個 USDT 存入 CToken 合約。 USDT 的價格為`1 美元`.
`總損失金額為 = $10,000,000 美元`

## 漏洞概念驗證 (Proof of Concept)

作者寫了一個 POC ，程式中也寫上詳細的解釋，說明攻擊的流程及影響，在 Github [repo](https://github.com/akshaysrivastav/first-deposit-bug-compv2) 

## 如何修復

防止此問題的解決方法是強制執行不能操作提款的最低存款限制。 這可以通過在第一次存款時將少量 CToken 代幣鑄造到 `0x00` 地址來完成。

```
function mintFresh(address minter, uint mintAmount) internal {
    // ...
    Exp memory exchangeRate = Exp({mantissa: exchangeRateStoredInternal()});

    uint actualMintAmount = doTransferIn(minter, mintAmount);

    uint mintTokens = div_(actualMintAmount, exchangeRate);

    /// THE FIX
    if (totalSupply == 0) {
        totalSupply = 1000;
        accountTokens[address(0)] = 1000;
        mintTokens -= 1000;
    }

    totalSupply = totalSupply + mintTokens;
    accountTokens[minter] = accountTokens[minter] + mintTokens;
    // ...
}
```
除了固定的`1000`值，還可以使用管理員者控制的參數值來控制每個 CToken 的銷毀量。

另外，一個快速的解決方案是，協議所有者用少量的 `底層` 代幣自己進行初始存款，然後將收到的 CToken 發送到 address(0)，從而永久地燒掉。

## Compound V2 Forks

由於 Compound 是用[Solidity](https://docs.soliditylang.org/en/v0.8.18/)開發的，這是一種在 EVM 上開發智能合約的語言。同一套合約可以部署到其他 EVM 兼容的鏈上。許多項目在BSC、Avalanche、Polygon等鏈上做了同樣的事情，並吸引了數十億美元的 TVL.

由於所有這些分叉項目都使用與 Compound 相同的智能合約，他們都容易受到本文提到的第一個存款錯誤的影響。他們應該嘗試實施上述建議的修復措施，如果需要，可以聯繫我[@akshaysrivastv](https://twitter.com/akshaysrivastv) 以獲得任何技術幫助.

該錯誤已報告給 Compound，問題也已修復，其多個分叉的項目也應該要立即修補此問題。這篇文章只為教育目的而寫.

## 學習資源

https://github.com/code-423n4/2022-03-prepo-findings/issues/27

https://github.com/code-423n4/2022-12-caviar-findings/issues/442

[Spearbit Community Workshop: Zach Obront](https://www.youtube.com/watch?v=PPfhIiclupc)

[Protect against inflation attacks by using OpenZeppelin’s ERC4626Router](https://twitter.com/OpenZeppelin/status/1621185916256792576)
