# Lesson 2: VERIFY SMART CONTRACTS IN APTOS WITH THE MOVE PROVER PT.1

Author: [MoveBit](https://twitter.com/MoveBit_)

It has been widely acclaimed that the Move Prover makes it very simple to formally verify Move contracts, offering very strong safety guarantees. How does it work? Does it provide the ultimate safety guarantee for smart contracts?

We will write an article series on how to verify smart contracts with the Move Prover in Aptos, what are the tips and best practices, a more complicated case study using the Move Prover, and what are the current limitation and its future outlook.

For this part, we will first give a tutorial on how to verify smart contracts with the Move Prover in Aptos.

## WHAT IS THE MOVE PROVER

Formal verification is a technique that uses rigorous mathematical methods to describe the behavior and reason about the correctness of computer systems.

Now it has certain applications in the fields of operating systems, compilers, and other fields that require high correctness.

Smart contracts deployed on the blockchain manipulate various digital assets, and their correctness is also critical.

***Move Prover (MVP)*** is designed to prevent bugs in smart contracts written in the Move language.

In Aptos ( and Starcoin/Sui ), Users can specify functional properties of smart contracts using ***the Move Specification Language (MSL)***, and then use the Move Prover to automatically and statically inspect them.

Simply put, there can be two components in a Move file:

* Part of it is program code, which is the part most of us are most familiar with. It is written in the Move programming language (sometimes just called the Move language). We use it to define data types, and functions.

* The other part is the Formal specification. It is optional and written in the Move specification language. We use it to describe what properties a program code should satisfy. Such as describing the behavior of a function.

When we write the formal specification, after calling the Move Prover, it will verify whether the Move program meets these requirements according to the written specification, helping developers to find potential problems as early as possible in the development stage, and giving other users confidence in the properties of the program that has been verified.

## INSTALL PROVER DEPENDENCIES IN APTOS

Before using the Move Prover, let’s install some of its external dependencies.
It is assumed that you already have [installed Aptos CLI](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli/).
Make sure you did “Step 3” and installed the dependencies of the Move Prover:
```
  ./scripts/dev_setup.sh -yp
. ~/.profile
```
When the above command is executed, enter `boogie /version`, if the output is similar to “Boogie program verifier version X.X.X”, then the installation has been successful.

Note that currently the Move Prover can only run under UNIX-based operating systems (such as Linux, and macOS).
Windows users can run it by installing [WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

## PREPARE AN EXAMPLE FOR VERIFICATION IN

### Project creation

First, let’s create a new empty Move package:

```
  mkdir basic_coin
cd basic_coin
aptos move init --name BasicCoin
```
You can see that its directory structure is as follows:

```
  basic_coin
    |
    |---- Move.toml (text file)
    |
    `---- sources   (Directory)
```
### Module code

Now create `basic_coin/sources/BasicCoin.move`.


<details><summary>BasicCoin.move content</summary>

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
  
Here we assume that you have a certain grasp of the Move language, and can understand the source code of `BasicCoin.move` above and know the function of each part.
  
### TOML configuration
  
BasicCoin uses some facilities of the Aptos standard library, and also needs to add `aptos-framework` to the dependencies. We also need to specify what numerical address it should be replaced with.

Therefore, we modify Move.toml as follows:

```
  [package]
name = "BasicCoin"
version = "0.0.0"

[dependencies]
AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework/", rev = "main" }

[addresses]
BasicCoin="Replace_It_With_Your_Numerical_Address"  
  
```
  
## THE FIRST VERIFICATION CODE

  To give us a first impression of the use of the Move Prover, add the following code snippet to BasicCoin.move:

```
 spec balance_of {
    pragma aborts_if_is_strict;
}
```
Syntactically, this code can be added anywhere in the BasicCoin module, but it is recommended to place it after the definition of the `balance_of `function in order to clearly see the correspondence between the definition and the specification when reading the code.

Simply put, the `spec balance_of {...}` block will contain our ***property specification*** for the `balance_of` function.
There are many types of property specifications, some common examples are:

* Will this function abort? Under what circumstances does it abort?
* What conditions must be met for the parameters to call this function?
* What is the return value of this function?
* After the function is executed, how will the state of the virtual machine be changed?
* What invariants does this function maintain?

For example, the Move Prover allows all possible aborts by default when we don’t give any abort conditions.

And in the simple snippet above, we tell Prover with the directive `aborts_if_is_strict` :

> I would like to strictly check the possibility of aborting this function. 
> Report an error if there is any abort not listed by the programmer.

Now, we run the `prove` command in the `basic_coin` directory:

```
  aptos move prove
  
```
  
it will call the Move Prover to check the code in the package.
Then we can see the Prover reporting the following error message:

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
  
Prover’s output tells us that it found a situation where the `balance_of` function aborts, but we don’t explicitly point out the possibility of such aborts.

Looking at the code that triggers the abort, we can see that the exception is caused by calling the built-in `borrow_global` function when the `owner` does not own a resource of type `Balance<CoinType>`.

Following the guidance of the error message, we can add the following `aborts_if` condition:

```
  spec balance_of {
    pragma aborts_if_is_strict;
    aborts_if !exists<Balance<CoinType>>(owner);
}
```
After adding this condition, try calling Prover again and see that there are no more validation errors.

Now we can confidently confirm that the `balance_of` function has one and only one possibility of abnormal termination, that is, the parameter `owner` does not own a resource of type `Balance<CoinType>`.
  
## VERIFY WITHDRAW FUNCTION
The signature of the function `withdraw` is as follows:

```
  fun withdraw<CoinType>(addr: address, amount: u64) : Coin<CoinType> acquires Balance
```
Its role is to withdraw the `amount` of coins from the address `addr` and return it.
  
### Specify the abort condition for `withdraw`

There are two possibilities for `withdraw` to abort:
  
1. No resource of type `Balance<CoinType>` in `addr`.
2. The balance in `addr` is less than `amount`.

From these, we can define the abort condition like this:

```
  spec withdraw {
    let balance = global<Balance<CoinType>>(addr).coin.value;
    aborts_if !exists<Balance<CoinType>>(addr);
    aborts_if balance < amount;
}
```
* A spec block can contain let bindings, which bind a long expression with a name that can be used repeatedly.
                               
   `global<T>(addr): T` is a built-in function that returns a resource of type `T` at address `addr`.
  
  Here, we set balance to the number of tokens owned by addr via the let binding;

* `exists<T>(address): bool` is a built-in function that returns true if resource `T` exists at address `addr`; otherwise returns false.

The two lines of `aborts_if` statements correspond to the two conditions mentioned above.  
In general, if a function has multiple `aborts_if` conditions, the conditions are ORed together.
  
As mentioned earlier, if we don’t specify any abort conditions, Prover will not impose any restrictions on aborts.

But once we give any kind of abort conditions, Prover defaults that we want to strictly check all possible aborts, so we need to list all possible conditions, which is equivalent to implicitly adding the instruction `pragma aborts_if_is_strict`.

If only some of the conditions for abnormal exit are listed, the Prover will report a validation error.

However, if the `pragma aborts_if_is_partial` is defined in the spec block, this is equivalent to telling the Prover:
  
> I just want to list some of the conditions that will cause an abort, please just verify that it will abort under those conditions.

If you are interested, you can do such a set of experiments to verify:

* When deleting any of the above two `aborts_if` conditions, Prover will report an error;
* When all `aborts_if` conditions are deleted at the same time, Prover will not report an error;
* When adding `pragma aborts_if_is_partial`, no matter how many `aborts_if` conditions are kept, Prover will not report an error (of course, the conditions themselves must be correct).
  
Some readers may be curious about the order of the three statements in the spec block:

***Why the definition of balance can be written after `aborts_if !exists<Balance<CoinType>>(addr)`.***

Because, if the latter holds true, `balance` does not actually exist.

***Wouldn’t this order cause the Prover to fail?***

Simply put: no, the statements in the spec block are declarative and the order doesn’t matter.

For a more detailed understanding, you can refer to the MSL documentation for more information.

### Specify the functional nature of `withdraw`

Next, we define functional properties.
The two `ensures` statements in the following spec block give us what we expect from the `withdraw` functionality:

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
In this code, first by using `let post` binding, define `balance_post` as the balance of `addr` after the function is executed, it should be equal to `balance - amount`. Then, `result` is a special name that represents the return value, which should be the `amount` of tokens.

## VERIFY THE `DEPOSIT` FUNCTION

The signature of the function deposit is as follows:

```
fun deposit<CoinType>(addr: address, check: Coin<CoinType>) acquires Balance
```
It deposits the token funds indicated by `check` into the address `addr`. Its canonical definition is as follows:

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
Here, `balance` is defined as the balance in `addr` before the function is executed, and `check_value` is defined as the amount of tokens to be deposited. It will abort in two cases:

1. There is no resource of type `Balance<CoinType>` in `addr`;
2. Or the sum of `balance` and `check_value` is greater than the maximum value of type `u64`.

The `ensures` statement is used to let the Prover make sure that in any case, the balance in `addr` can be updated correctly after the function is executed.

The syntax mentioned earlier will not be repeated here.

Astute readers may have noticed that it is worth noting that the expression `balance + check_value > MAX_U64` is problematic in the Move program.
Because the addition on the left may cause an overflow exception.

If we want to write a similar check in the Move program, we should use an expression like `balance > MAX_U64 - check_value` to avoid the overflow problem.

However, this expression is perfectly fine in the Move Specification Language (MSL).

Since the spec block uses the MSL language, its type system is different from that of Move.

In MSL, all integers are of type `num`, which is an integer in the mathematical sense. That is, it is signed and has no size limit.

All built-in integer types (`u8`, `u64`, etc.) are automatically converted to type `num` when referencing data in a Move program in MSL.
A more detailed description of the type system can be found in the MSL documentation.

## VERIFY THE `TRANSFER` FUNCTION

The signature of the function `transfer` is as follows:

```
public fun transfer<CoinType: drop>(from: &signer, to: address, amount: u64, _witness: CoinType) acquires Balance
```
It is responsible for the transfer `from` the account from to the address `to`, and the transfer amount is `amount`.

Let’s ignore the abort condition for now and only consider its functional nature, and try to write its validation specification:

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
Here `from` is of type `signer`, not a direct address.

Although in the program we have created a local variable called `addr_from`, we cannot directly reference it in the spec block.

At the same time, the expression of this address needs to be repeated several times, and it is very cumbersome to write repeatedly. We bind it to addr_from again.

Then use `let` and `let post` to define several variables, corresponding to the balances in the two addresses `addr_from` and `to` before and after the function is executed.

Finally, use the `ensures` statement to tell Prover that the balance in `from` should be subtracted by `amount`; the balance in `to` should be increased by `amount`.

At first glance, there seems to be no problem at all. But is it really so?

Let’s see if Prover thinks this is “the correct description of the behavior of this function”.

After typing `aptos move prove` you can see:

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
It is somewhat out of our expectations. Prover prompts that the postconditions are not satisfied, indicating that the behavior described in the previous spec block is not exactly the same as the `transfer` function.

Why is this so? Let’s look down again: the parameters that make the postconditions not satisfied are `from = signer{0x0} `and `to = 0x0`. We should know the reason: when the account transfers money to itself, both `to` and `from` point to the same address, so the balance does not change.

There are two solutions now:

***Plan A*** does not modify the function definition, but changes the specification.
In the spec block, consider whether the two accounts for the transfer and receiving are the same address.

```
let post eq_post = balance_to == balance_to_post;
let post ne_post = balance_from_post == balance_from - amount
                && balance_to_post   == balance_to   + amount;
ensures (addr_from == to && eq_post) || (addr_from != to && ne_post);
```
Or use another slightly more intuitive if syntax:

```
  let post eq_post = balance_to == balance_to_post;
let post ne_post = balance_from_post == balance_from - amount
                && balance_to_post   == balance_to   + amount;
ensures if (addr_from == to) eq_post else ne_post;
```
Note that `if (P) E1 else E2` is not the same as conditional execution in program logic – it’s actually a syntactic sugar equivalent to `ensures` both `P ==> E1` and `!P ==> E2`.
And `p ==> q` is actually `!p || q`.

That is to say, the end of the second way of writing actually represents this logic:

```
ensures (addr_from == to  ===>  eq_post) && (addr_from != to  ===> ne_post);
```
that is:

```
ensures (addr_from != to || eq_post) && (addr_from == to  || ne_post);
```
Interested readers can verify it by themselves through the direct value table or by simplifying to normal form, the former `(addr_from == to && eq_post) || (addr_from != to && ne_post)` and the latter `(addr_from != to || eq_post) && (addr_from == to || ne_post)` are actually exactly equivalent expressions.

***Plan B*** does not modify the spec, but directly adds `assert!(addr_from != to, EEQUAL_ADDR);` in the function body, and adds the definition of the error code `EEQUAL_ADDR` in front, so that the self-transfer transaction cannot be completed.

Obviously, it is not meaningful to transfer money to yourself, so it is better to directly prohibit this kind of transaction.
So plan B is a better practice.
It directly guarantees that the two are definitely not the same address when successfully executed, and the code is more concise.

### Practice

Currently, we have only completed functional verification of the `transfer` function.

But it doesn’t say under what circumstances it will abort.

As an exercise, give it an appropriate `aborts_if` condition. The answer can be found in our next article.

## VERIFY MINT FUNCTION

The signature of the function `mint` is as follows:
```
public fun mint<CoinType: drop>(mint_addr: address, amount: u64, _witness: CoinType) acquires Balance
```
It is responsible for minting the `amount` of tokens and depositing them in the address `mint_addr`.
More interesting is `_witness`, which is of type `CoinType`.
Because only the module that defines the `CoinType` can construct a value of this type, this guarantees the identity of the caller.

There is actually only one call to `deposit` in the `mint` function.
It is not difficult to imagine that there should be many similarities in the specifications to be satisfied by the two. Drawing a tiger according to a cat, it is not difficult to write:
```
  spec mint {
    let balance = global<Balance<CoinType>>(mint_addr).coin.value;

    aborts_if !exists<Balance<CoinType>>(mint_addr);
    aborts_if balance + amount > MAX_U64;

    let post balance_post = global<Balance<CoinType>>(mint_addr).coin.value;
    ensures balance_post == balance + amount;
}
```
## VERIFY THE `PUBLISH_BALANCE` FUNCTION

The signature of the function `publish_balance` is as follows:

```
public fun publish_balance<CoinType>(account: &signer)
```
It publishes an empty `Balance<CoinType>` resource under `account`.
So if the resource already exists it should exit abnormally, and end normally the balance should be zero:

```
spec publish_balance {
    let addr = signer::address_of(account);
    aborts_if exists<Balance<CoinType>>(addr);

    ensures exists<Balance<CoinType>>(addr);
    let post balance_post = global<Balance<CoinType>>(addr).coin.value;
    ensures balance_post == 0;
}
```
## SIMPLIFY REDUNDANT SPECIFICATIONS WITH SCHEMA
Congratulations! So far, we have completed the verification of all the functions of BasicCoin step by step.
However, if you look closely at the code, many of the spec blocks look very similar, and the file structure would be clearer if they could be shortened a bit.

Schema is a means of building a specification by grouping properties.

Semantically, they are also syntactic sugar, and their use in a spec block is equivalent to expanding the conditions they contain into functions, structs, or modules.

### Eliminate simple repetitions
As a most obvious example, the spec blocks of `mint` and `deposit` are a little different except for the variable names (in terms, they are [alpha convertible](https://en.wikipedia.org/wiki/Lambda_calculus#%CE%B1-conversion)), and the overall structure can be said to be exactly the same.
To simplify them, let’s create a Schema:
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
This Schema declares two typed variables, and some conditions about what those variables should satisfy.

When other places want to use this Schema, use `include DepositSchema {addr: XX, amount: YY}` to import it.
where `XX` and `YY` are expressions used to replace `addr` and `amount`.

If the expression is exactly the same as the corresponding variable name, you can just write the variable name, or simply omit it.

With the above Schema definition, we can now simplify the previous spec:

```
  spec mint {
  include DepositSchema<CoinType> {addr: mint_addr};
}
// ....
spec deposit {
    include DepositSchema<CoinType> {amount: check.value};
}
```
### Practice
In addition to the above example, find another spec block (such as `publish_balance`), and split it into a Schema declaration and a spec block that uses the corresponding Schema.

As an exercise, the Schema you created might not be available in this code, so it doesn’t feel like there’s a benefit to it.

But if in the later development, there are other functions that call `publish_balance`, it will be more convenient.

## CONCLUSION
In our article so far, we’ve shown you how the Move Prover works and it could potentially provide the ultimate safety guarantee for smart contracts. In the upcoming series, we will explore

* the tips and best practices;
* a more complicated case study using the Move Prover;
* the limitation of the current version of the Move Prover, and its future outlook;

So stay tuned!

More and more developers are developing or deploying smart contracts on Move Ecosystem, it is recommended to ship the Move contracts with a comprehensive security assessment using the Move Prover and other industry-leading audit methodology.
