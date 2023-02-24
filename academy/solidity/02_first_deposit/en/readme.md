# Lesson 2: First Deposit Bug in CompoundV2 and its forks

Author：[Akshay Srivastav](https://twitter.com/akshaysrivastv)

**Note: Compound has been addressed this issue, this article is written for educational purposes only.**

The Compound Finance V2 is a decentralized money market protocol built on top of Ethereum blockchain. The protocol facilitates lending and borrowing of crypto assets in a decentralized and trustless way. The simplicity and robustness of compound protocol has attracted billions of dollars as its TVL, more than $10 Billions at its peak.

Recently a potential vulnerability was discovered in the CompoundV2 smart contracts which allows an Attacker to steal funds of the initial lenders of a Compound market.

Let's dive into the details of the bug.

The CToken is a yield bearing asset which is minted when a user deposits some units of `underlying` tokens into the money market. The amount of CTokens minted to a user are calculated based upon the amount of `underlying` tokens the user is depositing.

As per the implementation of CToken contract, there exist two cases for CToken amount calculation:

1. First deposit - when `CToken.totalSupply()` is `0`.
2. All subsequent deposits.


Here is the actual CToken code (extra code and comments clipped for better reading) taken from project's [github](https://github.com/compound-finance/compound-protocol):

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

## The Bug

The above implementation contains a critical bug which can be exploited to steal funds of initial depositors of a freshly deployed CToken market.

If you look closely, the formulas can be simplified and written as below:

```
Exchange rate = underlying.balanceOf(CToken) * 1e18 / CToken.totalSupply()

CToken amount = User deposit amount / Exchange rate
```
Noticed anything?

What happens if exchange rate can be increased to a value greater than the user's deposit?

The CToken output amount comes out to be `0`.

### Here are more detailed steps:

As the exchange rate is dependent upon the ratio of CToken's total supply and underlying token balance of CToken contract, the attacker can craft transactions to manipulate the exchange rate.

Steps to attack:

1. Once the CToken has been deployed and added to the lending protocol, the attacker mints the smallest possible amount of CTokens.

2. Then the attacker does a plain `underlying` token transfer to the CToken contract, artificially inflating the `underlying.balanceOf(CToken)` value.

    Due to the above steps, during the next legitimate user deposit, the `mintTokens` value for the user will become less than `1` and essentially be rounded down to `0` by Solidity. Hence the user gets `0` CTokens against his deposit and the CToken's entire supply is held by the Attacker.

3. The Attacker can then simply `reedem` his CToken balance for the entire `underlying` token balance of the CToken contract.

The same steps can be performed again to steal the next user's deposit.

It should be noted that the attack can happen in two ways:
* The attacker can simply execute the Step 1 and 2 as soon as the CToken gets added to the lending protocol.
* The attacker watches the pending transactions of the network and frontruns the user's deposit transaction by executing Step 1 and 2 and then backruns it with Step 3.

## Impact

A sophisticated attack can impact all initial user deposits until the lending protocols owners and users are notified and contracts are paused. Since this attack is a replicable attack it can be performed continuously to steal the deposits of all depositors that try to deposit into the new CToken contract.

The loss amount will be the sum of all deposits done by users into the CToken multiplied by the underlying token's price.

Suppose there are `10` users and each of them tries to deposit `1,000,000` underlying tokens into the CToken contract. Price of underlying token is `$1`.

`Total loss (in $) = $10,000,000`

## Proof of Concept

A working PoC is present at github [repo](https://github.com/akshaysrivastav/first-deposit-bug-compv2) with sufficient comments written to explain the flow of attack and its impact.

## The Fix

The fix to prevent this issue would be to enforce a minimum deposit that cannot be withdrawn. This can be done by minting small amount of CToken units to `0x00` address on the first deposit.

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
Instead of a fixed `1000` value an admin controlled parameterized value can also be used to control the burn amount on a per CToken basis.

Alternatively, a quick fix would be that the protocol owners perform the initial deposit themselves with a small amount of `underlying` tokens and then burn the received CTokens permanently by sending them to a dead address.

## Compound V2 Forks

As the compound protocol is written in [Solidity](https://docs.soliditylang.org/en/v0.8.18/), a language to write code for Ethereum Virtual Machine. The same set of contracts can be deployed to other EVM compatible chains. Many projects have done the same on chains like BSC, Avalanche, Polygon, etc. and have attracted billions of dollars in TVL.

Since all of those forked projects use the same smart contracts as of Compound's, they all are susceptible to the first deposit bug mentioned in this article. They should try to implement the fixes suggested above, or if needed, reach out to me [@akshaysrivastv](https://twitter.com/akshaysrivastv) to get any technical help.

The bug was swiftly reported to Compound Finance and its multiple forks and remediation steps were taken accordingly. This article is written for educational purposes only.

## Resource

https://github.com/code-423n4/2022-03-prepo-findings/issues/27

https://github.com/code-423n4/2022-12-caviar-findings/issues/442

[Spearbit Community Workshop: Zach Obront](https://www.youtube.com/watch?v=PPfhIiclupc)

[Protect against inflation attacks by using OpenZeppelin’s ERC4626Router](https://twitter.com/OpenZeppelin/status/1621185916256792576)
