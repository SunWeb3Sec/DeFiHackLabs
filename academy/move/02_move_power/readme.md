# Lesson 2: 如何在Aptos中验证智能合约：Move Prover 教程

Author: [MoveBit](https://twitter.com/MoveBit_)

Move 作为新一代智能合约编程语言，将安全作为了首要设计目标。Move 号称可以使用形式化验证工具 Move Prover(MVP) 来保障智能合约的安全。Move Prover 是如何使用的呢？Move Prover未来是否会变成安全编程必不可少的工具？

MoveBit 团队将写作一个系列文章，详细介绍 Mover Prover 的使用、技巧和最佳实践、Move Prover 的审计案例，当前局限和未来展望，带大家从 0 到 1 入门 Move Prover。

* 如何在Aptos中使用 Move Prover
* Move Prover 的技巧和最佳实践
* Move Prover 合约审计案例深入探讨
* Move Prover 当前的局限和未来展望

## 什么是 Move Prover

形式化验证是一种使用严格的数学方法来描述行为和推理计算机系统的正确性的技术。现在已经在操作系统、编译器等对正确性要求高的领域有一定应用。

部署在区块链上的智能合约操纵着各种数字资产，它们的正确性也十分关键。Move Prover（MVP） 就是为防止 Move 语言编写的智能合约中的错误而设计。用户可以使用 Move 规范语言（MSL） 指定智能合约的功能属性，然后使用 Move Prover 自动静态地检查它们。

简单地说，Move 文件中可以有两种成分：

* 一部分是程序代码，这是我们多数人最熟悉的部分。它用 Move 程序语言 (有时候也直接叫 Move 语言) 写成。我们用它定义数据类型、函数。

* 另一部分是形式规范（Formal specification）。它是可选的，用 Move 规范语言写成。我们用它说明程序代码应该满足怎样的性质。比如描述函数的行为。

当我们写了形式规范的时候，调用 Move Prover 后，它会按照写的规范去验证 Move 程序有没有满足这些要求，帮助开发人员在开发阶段尽早发现潜在的问题， 并让其它用户对已经验证过的程序性质有信心。

## 安装 Prover 的依赖

在使用 Move Prover 前，我们先安装它的一些外部依赖。
假设你已经根据文档安装好了[Aptos CLI](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli/)，并且已经运行了第三步。
```
  ./scripts/dev_setup.sh -yp
. ~/.profile
```
当上面的命令执行完毕时，输入 `boogie /version`，如果输出类似 "Boogie program verifier version X.X.X"，那么安装已经成功。

注意，目前 Move Prover 只能在 UNIX 系操作系统下运行（例如 Linux、macOS）。
Windows 用户可以通过安装[WSL](https://learn.microsoft.com/en-us/windows/wsl/install)来运行。

## 准备要验证的示例

### 项目创建

首先，我们来创建一个新的空 Move 包：
```
  mkdir basic_coin
cd basic_coin
aptos move init --name BasicCoin
```
可以看到它的目录结构如下：
```
  basic_coin
    |
    |---- Move.toml (text file)
    |
    `---- sources   (Directory)
```
### 模块代码

现在创建 `basic_coin/sources/BasicCoin.move`.

<details><summary>BasicCoin.move 内容</summary>

```
  /// This module defines a minimal and generic Coin and Balance.
module BasicCoin::basic_coin {
    use std::error;
    use std::signer;

    /// Error codes
    const ENOT_MODULE_OWNER: u64 = 0;
    const EINSUFFICIENT_BALANCE: u64 = 1;
    const EALREADY_HAS_BALANCE: u64 = 2;

    struct Coin<phantom CoinType> has store {
        value: u64
    }

    struct Balance<phantom CoinType> has key {
        coin: Coin<CoinType>
    }

    /// Publish an empty balance resource under `account`'s address. This function must be called before
    /// minting or transferring to the account.
    public fun publish_balance<CoinType>(account: &signer) {
        let empty_coin = Coin<CoinType> { value: 0 };
        assert!(!exists<Balance<CoinType>>(signer::address_of(account)), error::already_exists(EALREADY_HAS_BALANCE));
        move_to(account, Balance<CoinType> { coin:  empty_coin });
    }

    /// Mint `amount` tokens to `mint_addr`. This method requires a witness with `CoinType` so that the
    /// module that owns `CoinType` can decide the minting policy.
    public fun mint<CoinType: drop>(mint_addr: address, amount: u64, _witness: CoinType) acquires Balance {
        // Deposit `total_value` amount of tokens to mint_addr's balance
        deposit(mint_addr, Coin<CoinType> { value: amount });
    }

    public fun balance_of<CoinType>(owner: address): u64 acquires Balance {
        borrow_global<Balance<CoinType>>(owner).coin.value
    }

    /// Transfers `amount` of tokens from `from` to `to`. This method requires a witness with `CoinType` so that the
    /// module that owns `CoinType` can  decide the transferring policy.
    public fun transfer<CoinType: drop>(from: &signer, to: address, amount: u64, _witness: CoinType) acquires Balance {
        let addr_from = signer::address_of(from);
        let check = withdraw<CoinType>(addr_from, amount);
        deposit<CoinType>(to, check);
    }

    fun withdraw<CoinType>(addr: address, amount: u64) : Coin<CoinType> acquires Balance {
        let balance = balance_of<CoinType>(addr);
        assert!(balance >= amount, EINSUFFICIENT_BALANCE);
        let balance_ref = &mut borrow_global_mut<Balance<CoinType>>(addr).coin.value;
        *balance_ref = balance - amount;
        Coin<CoinType> { value: amount }
    }
    
    fun deposit<CoinType>(addr: address, check: Coin<CoinType>) acquires Balance{
        let balance = balance_of<CoinType>(addr);
        let balance_ref = &mut borrow_global_mut<Balance<CoinType>>(addr).coin.value;
        let Coin { value } = check;
        *balance_ref = balance + value;
    }
}
    
```

</details>
<br>
  
这里我们假设您已经对 Move 语言有一定掌握，并能理解上面 `BasicCoin.move` 的源码和知道各个部分的作用。
  
### TOML 配置
  
BasicCoin 使用到了 Aptos 标准库的一些设施，也要把 `aptos-framework` 添加到依赖当中。同时，BasicCoin 中用到了命名地址，我们也要指定它应该被何数值地址替换。

因此，我们把 Move.toml 修改如下：

```
  [package]
name = "BasicCoin"
version = "0.0.0"

[dependencies]
AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework/", rev = "main" }

[addresses]
BasicCoin="Replace_It_With_Your_Numerical_Address"  
  
```
  
## 第一段验证代码

为了让我们对 Move Prover 的使用有一个初步印象，在 `BasicCoin.move` 中 添加以下代码片段：

```
 spec balance_of {
    pragma aborts_if_is_strict;
}
```
语法上，这段代码可以添加在 BasicCoin 这个模块内的任何地方，但为了让阅读代码的时候方便清晰地看到定义和规范的对应关系，推荐把它就放在 `balance_of`函数的定义后面。
简单地说， `spec balance_of {...}` 这个代码块将会包含我们对 `balance_of` 这个函数的***性质规范 (property specification)***。

性质规范有很多种，常见的一些例子有：

* 这个函数会异常中止 (abort) 吗？它在什么情况下会异常中止？
* 调用这个函数的参数要满足什么条件？
* 这个函数的返回值是怎样的？
* 函数执行后，会对虚拟机状态产生怎样的改变？
* 这个函数会维持怎样的不变量（invariant）？

例如，当我们没有给出任何中止条件时，Move Prover 默认允许一切可能的异常中止。
而上面这个简单的片段中，我们用指示`aborts_if_is_strict`告诉 Prover：

> 我希望严格检查这个函数的异常中止的可能。如果出现了任何程序员没有列出的中止的情况，请报错。

现在，我们在`basic_coin`目录下运行 `prove`命令 aptos move prove：

```
  aptos move prove
```
会调用 Move Prover 对包内的代码进行检查。然后我们可以看到 Prover 报下面这样的错误信息：

```
   error: abort not covered by any of the `aborts_if` clauses
   ┌─ ./sources/BasicCoin.move:38:5
   │
35 │           borrow_global<Balance<CoinType>>(owner).coin.value
   │           ------------- abort happened here with execution failure
   ·
38 │ ╭     spec balance_of {
39 │ │       pragma aborts_if_is_strict;
40 │ │     }
   │ ╰─────^
   │
   =     at ./sources/BasicCoin.move:34: balance_of
   =         owner = 0x29
   =     at ./sources/BasicCoin.move:35: balance_of
   =         ABORTED

FAILURE proving 1 modules from package `basic_coin` in 1.794s
{
  "Error": "Move Prover failed: exiting with verification errors"
}
  
```
Prover 的输出告诉我们，它找到了一种让  `balance_of` 函数异常中止的情形，但我们却没有明确指出这种异常中止的可能。接着看触发异常中止的代码，可以发现，异常是在`owner`不拥有`Balance<CoinType>`类型的资源时调用内置的`borrow_global`函数造成的。

根据错误信息的指导，我们便可以添加如下的`aborts_if`条件：

```
  spec balance_of {
    pragma aborts_if_is_strict;
    aborts_if !exists<Balance<CoinType>>(owner);
}
```
添加这个条件后，尝试再调用 Prover，可以看到不再有验证错误。现在我们可以有信心确认：`balance_of` 函数有且仅有一种异常结束的可能，那就是参数 `owner` 不拥有 `Balance<CoinType>`类型的资源。
  
## 验证 withdraw 函数
函数 `withdraw`的签名如下:

```
  fun withdraw<CoinType>(addr: address, amount: u64) : Coin<CoinType> acquires Balance
```
它的作用是从地址`addr`中取出金额为`amount`的币，并将其返回。
  
### 指定`withdraw`的中止条件

`withdraw`有两种异常中止的可能：
  
1.`addr`中没有`Balance<CoinType>`类型的资源

2.`addr`中的余额小于  `amount`

根据这些，我们可以像这样定义中止条件：

```
  spec withdraw {
    let balance = global<Balance<CoinType>>(addr).coin.value;
    aborts_if !exists<Balance<CoinType>>(addr);
    aborts_if balance < amount;
}
```
可以看到，

* 一个 spec 块可以包含 let 绑定，它可以给比较长的表达式绑定一个名称，并可以反复使用。`global<T>(addr): T` 是一个内置函数，它返回地址`addr`处类型为 `T` 的资源。这里，我们通过 let 绑定将`balance` 设置为 `addr` 所拥有的代币数量；

* `exists<T>(address): bool` 是一个内置函数，如果资源 `T`在地址 `addr`处存在，则返回 true；否则返回 false.

这两行 `aborts_if` 语句对应于上面提到的两个条件。 一般来说，如果某个函数有多个`aborts_if` 条件，这些条件就会被或逻辑连接起来。
  
像前面提到的那样，如果我们没指定任何异常中止的条件，Prover 就不会对异常中止作任何限制。但一旦我们给出了任何一种中止的条件，Prover 就默认我们想严格检查所有异常中止的可能，因此需要列出所有可能的条件， 相当于隐式加了 `pragma aborts_if_is_strict`.这条指示。如果只列出了部分异常退出的条件，Prover 会报验证错误。

然而，如果在 spec 块中定义了  `pragma aborts_if_is_partial` , 就相当于告诉 Prover：
  
> 我只想列出一部分会导致异常中止的条件，请仅仅验证在这些条件下是否会异常中止。

如果感兴趣的话，可以做这样一组实验来验证：

* 当删除上面两个 `aborts_if`条件当中的任何一个时，Prover 将会报错；
* 当同时删除所有 `aborts_if`条件时，Prover 反而不会报错；
* 当加上`pragma aborts_if_is_partial`时，无论保留几条`aborts_if`条件，Prover 都不会报错（当然了，条件本身要是正确的）。
  
有读者可能会对 spec 块中三个语句的顺序的排列产生好奇:

1.`balance`的定义为什么可以写在`aborts_if !exists<Balance<CoinType>>(addr)` 的后面。

因为，如果后者成立的话，`balance`实际上是不存在的。

2. 这个顺序不会导致 Prover 出错吗？

简单地说：不会，spec 块当中的语句是声明式的，顺序没有任何影响。如果想作更细致的了解，可以参考 MSL 文档 以获得更多信息。

### 指定 withdraw 的功能性质

Next, we define functional properties.
接下来我们来定义功能性质。下面 spec 块当中的两个 `ensures` 语句给出了我们对`withdraw` 功能上的期待：

```
      spec withdraw {
    let balance = global<Balance<CoinType>>(addr).coin.value;
    aborts_if !exists<Balance<CoinType>>(addr);
    aborts_if balance < amount;

    let post balance_post = global<Balance<CoinType>>(addr).coin.value;
    ensures balance_post == balance - amount;
    ensures result == Coin<CoinType> { value: amount };
}
```
这段代码中，首先通过使用 `let post` 绑定，把 `balance_post` 定义为函数执行后 `addr`的余额，它应该等于  `balance - amount`。然后，`result`  是一个特殊的名字，表示返回值，它应该是金额为 `amount`  的代币。
  
## 验证 deposit 函数

函数 `deposit` 的签名如下：

```
fun deposit<CoinType>(addr: address, check: Coin<CoinType>) acquires Balance
```
它将`check`表示的代币资金存入到地址`addr`当中。它的规范定义如下:

```
  spec deposit {
    let balance = global<Balance<CoinType>>(addr).coin.value;
    let check_value = check.value;

    aborts_if !exists<Balance<CoinType>>(addr);
    aborts_if balance + check_value > MAX_U64;

    let post balance_post = global<Balance<CoinType>>(addr).coin.value;
    ensures balance_post == balance + check_value;
}
```
这里将`balance`定义为函数执行前`addr` 中的余额将`check_value`定义为要存入的代币金额。它在下面两种情况下会异常中断:

1. `addr`中没有类型为`Balance<CoinType>` 的资源；
2. 或者`balance`和`check_value`之和大于`u64`类型的最大值。

`ensures` 语句用于让 Prover 确定在任何情况下，函数执行后`addr`中的余额都可以被正确地更新。
  
前面提到过的语法此处不再赘述。敏锐的读者可能已经发现，有一点值得注意：

表达式`balance + check_value > MAX_U64` 在 Move 程序中是有问题的。因为左边的加法会可能引起溢出的异常。如果我们在 Move 程序中想写一个类似的检查，应该用类似 `balance > MAX_U64 - check_value`  的表达式来避开溢出的问题。

但是，这个表达式在 Move 规范语言（MSL）中却完全没问题。由于 spec 块使用的是 MSL 语言，它的类型系统和 Move 不一样。MSL 中，所有的整数都是`num`类型，它是数学意义上的整数。也就是说，它是有符号数，而且没有大小限制。当在 MSL 中引用 Move 程序中的数据时，所有内置整数类型（`u8`, `u64` 等）都会被自动转换成`num`类型。在 MSL 文档中可以找到更详细的关于类型系统的说明。

## 验证 transfer 函数

函数 `transfer` 的签名如下：

```
public fun transfer<CoinType: drop>(from: &signer, to: address, amount: u64, _witness: CoinType) acquires Balance
```
它负责从账户 `from`到地址 `to` 的转账，转账金额为 `amount`。

我们先暂时忽略异常中止条件，只考虑它的功能性质，来试试将其验证规范写出来：
  
```
spec transfer {
    let addr_from = signer::address_of(from);

    let balance_from = global<Balance<CoinType>>(addr_from).coin.value;
    let balance_to = global<Balance<CoinType>>(to).coin.value;
    let post balance_from_post = global<Balance<CoinType>>(addr_from).coin.value;
    let post balance_to_post = global<Balance<CoinType>>(to).coin.value;

    ensures balance_from_post == balance_from - amount;
    ensures balance_to_post == balance_to + amount;
}
```
这里的 `from`是`signer` 类型，而并非一个直接的地址。虽然程序中我们有创建一个名为`addr_from`的局部变量，但在 spec 块中我们无法直接引用它。同时，这个地址的表达式要重复好几次，反复书写很累赘，我们再次把它绑定到 `addr_from`上面。然后用`let`和 `let post`定义几个变量，对应着函数执行前后`addr_from` 和 `to` 两个地址内的余额。

最后用`ensures`语句告诉 `Prover from` 内的余额应该减去 `amount`；`to`内的余额以应该增加 amount。

乍看之下，似乎完全没有问题。可是真的是这样吗？我们来看看 Prover 是否认为这就是「对这个函数行为的正确描述」。在输入`aptos move prove`后可以看到：

```
  error: post-condition does not hold
   ┌─ ./sources/BasicCoin.move:58:9
   │
58 │         ensures balance_from_post == balance_from - amount;
   │         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   │
   =     at ./sources/BasicCoin.move:45: transfer
   =     at ./sources/BasicCoin.move:51: transfer (spec)
   =     at ./sources/BasicCoin.move:53: transfer (spec)
   =     at ./sources/BasicCoin.move:54: transfer (spec)
   =     at ./sources/BasicCoin.move:45: transfer
   =         from = signer{0x0}
   =         to = 0x0
   =         amount = 1
   =         _witness = <generic>
```
令人有些出乎意料，Prover 提示了后置条件不满足，说明前面的 spec 块中的所描述的行为和`transfer`函数并不完全一致。为什么会这样呢？我们再往下看：使得后置条件不满足的的参数是`from = signer{0x0} `和`to = 0x0`. 看到这里我们应该清楚原因了：当账户向自己转账时 `to` 和 `from` 指向的地址都一样，所以余额不产生任何变化。
  
现在有两个解决方案:

***方案甲*** 不修改函数定义，改变规范，在 spec 块中分情况考虑转账收发账户二者是否是同一地址两种情形：

```
let post eq_post = balance_to == balance_to_post;
let post ne_post = balance_from_post == balance_from - amount
                && balance_to_post   == balance_to   + amount;
ensures (addr_from == to && eq_post) || (addr_from != to && ne_post);
```
或者用另一种稍微直观些的 if 语法：
```
  let post eq_post = balance_to == balance_to_post;
let post ne_post = balance_from_post == balance_from - amount
                && balance_to_post   == balance_to   + amount;
ensures if (addr_from == to) eq_post else ne_post;
```
注意这里的 `if (P) E1 else E2` 和程序逻辑中的条件执行不太相同—— 它实际上是个语法糖，等价于同时 `ensures`了`P ==> E1` 和 `!P ==> E2`。而 `p ==> q` 又实际上就是 `!p || q`

也就是说，第二种写法的末尾实际上表示这样的逻辑：

```
ensures (addr_from == to  ===>  eq_post) && (addr_from != to  ===> ne_post);
```
即：
```
ensures (addr_from != to || eq_post) && (addr_from == to  || ne_post);
```
有兴趣的读者可以通过直值表或化简到范式的方式自行验证一下， 前面的  `(addr_from == to && eq_post) || (addr_from != to && ne_post)` 和后面的  `(addr_from != to || eq_post) && (addr_from == to || ne_post)` 实际上也是完全等价的表达式。

***方案乙*** 不修改 spec，直接在函数体内加上`assert!(addr_from != to, EEQUAL_ADDR);`并在前面加上错误码`EEQUAL_ADDR` 的定义，让自我转账交易无法完成。
  
显然，自己给自己转账并没有实际意义，不如直接禁止这种交易。因此方案乙是更好的做法。它直接保证了成功执行时两者肯定不是同一地址，而且代码也更为简洁。

### 练习

目前我们只完成了`transfer` 函数的功能性验证。但没有说明它会在哪些情况下异常中止。作为练习，请给它加上合适的`aborts_if`条件。答案我们会在第二篇文章中给出。
  
## 验证 mint 函数

函数 `mint`的签名如下：
```
public fun mint<CoinType: drop>(mint_addr: address, amount: u64, _witness: CoinType) acquires Balance
```
它负责铸造出金额为`amount` 的代币，并存到地址`mint_addr` 中。比较有趣的是`_witness`，其类型为 `CoinType`。因为只有定义`CoinType`的模块才能构造出这个类型的值，这就保证了调用者身份。

`mint` 函数中实际上只有一句对 `deposit`的调用。不难想到，它们俩的要满足的规范应该有很多的相似之处。照猫画虎，不难写出:

```
  spec mint {
    let balance = global<Balance<CoinType>>(mint_addr).coin.value;

    aborts_if !exists<Balance<CoinType>>(mint_addr);
    aborts_if balance + amount > MAX_U64;

    let post balance_post = global<Balance<CoinType>>(mint_addr).coin.value;
    ensures balance_post == balance + amount;
}
```
## 验证 publish_balance 函数

函数`publish_balance`的签名如下：

```
public fun publish_balance<CoinType>(account: &signer)
```
它在`account`下发布一个空的`Balance<CoinType>`类型的资源。因此如果资源已经存在时应当异常退出，而正常结束是余额应当是零：

```
spec publish_balance {
    let addr = signer::address_of(account);
    aborts_if exists<Balance<CoinType>>(addr);

    ensures exists<Balance<CoinType>>(addr);
    let post balance_post = global<Balance<CoinType>>(addr).coin.value;
    ensures balance_post == 0;
}
```
## 使用 Schema 简化冗余规范
  
恭喜！到目前为止，我们已经一步一步完成了 BasicCoin 的全部函数的验证。但是，如果仔细看代码的话，不少 spec 块看起来十分相似，如果能让它们精简一些的话，文件结构会更清晰。

Schema 是一种通过将属性分组来构建规范的手段。从语义上讲，它们也是语法糖，在 spec 块中使用它们等价于将它们包含的条件展开到函数、结构或模块。

### 消除简单重复
作为一个最明显的例子，`mint` 和 `deposit`的 spec 块除了变量名有点不一样（用术语来说，它们是[可 alpha 转换](https://en.wikipedia.org/wiki/Lambda_calculus#%CE%B1-conversion))，整体结构可以说是完全一致。为了简化它们，我们来创建一个 Schema:
  
```
spec schema DepositSchema<CoinType> {
    addr: address;
    amount: u64;

    let balance = global<Balance<CoinType>>(addr).coin.value;

    aborts_if !exists<Balance<CoinType>>(addr);
    aborts_if balance + amount > MAX_U64;

    let post balance_post = global<Balance<CoinType>>(addr).coin.value;
    ensures balance_post == balance + amount;
}
```
这个 Schema 声明了两个有类型的变量，以及一些关于这些变量应该满足的条件。当其它地方想用这个 Schema 的时候，就要用`include DepositSchema {addr: XX, amount: YY}`来导入它。其中`XX` 和 `YY` 分是用来替代`addr`和`amount`的表达式。如果表达式和对应的变量名正好一样，刚可以只写变量名，或者直接省略。

有了上面的 Schema 定义之后，我们现在可以简化之前的 spec 了：

```
  spec mint {
  include DepositSchema<CoinType> {addr: mint_addr};
}
// ....
spec deposit {
    include DepositSchema<CoinType> {amount: check.value};
}
```
### 练习
除了上面的示例以外，再找一个 spec 块（例如`publish_balance`），将它也拆分成一个 Schema 声明和一个使用对应 Schema 的 spec 块。作为一个练习，你创建的 Schema 可能在这份代码中无法利用，所以感觉看不出什么好处。但如果在后面开发中，有别的函数调用  `publish_balance`，就会更方便了。
  
## 结论
到目前为止，我们已经详细介绍了如何使用 Move Prover 来进行形式化验证，为智能合约安全提供保障，我们也初步认识到了 Move Prover的威力. 在后续的文章中，我们将介绍

* Move Prover 的技巧和最佳实践;
* Move Prover 合约审计案例深入探讨;
* Move Prover 当前的局限和未来展望;

请保持关注!

越来越多的开发者在 Move 生态中开发 Move 应用并且部署 Move 合约。我们强烈建议在上线Move DApp之前采用 Move Prover以及其他合约审计技术和工具对应用进行审计。

