# Lesson 3: Learn security risks with a new honeypot scam

***Take a deep dive into the code for it and be a Web3 guy with security awareness and security literacy.***

Author: [GoPlus Security](https://twitter.com/GoplusSecurity)

## Blackboard

If you are an active user for the decentralized thing, you are definitely familiar with a token scam named **Honeypot**. In case that you haven't heard the term, we're now here to do a brief intro here for it. 

It's a metaphor that refers to something that is designed to attract someone: in other words, `it's a trap`. In the case of a token scam, a honeypot happens when the contract creator places `elaborate traps within the contract code` to prevent speculators from selling their recently purchased token. This can come in the form of heavy internal commission upon transfers, or extreme limits on selling (both time based and % based).

Honeypot is getting smarter and smarter. To entice more people to fall into the trap, the hackers-the honeypot scam deployer, are incentivised to update the code in a more sophisticated logic design. As a result, it makes it more difficult for a security engine to detect the scam.

---

###  Common Attack Patterns

The recent data from GoPlus shows the honeypot tokens are on the rise. The scam deployed in 2022 has an increase of 64661 , reaching 101,267 in total, a **83.39%** increase over the full 2021. Out of all the honeypot scams, 92.8% of them were deployed on BNB Chain, while 6.6% of them occurred on Ethereum.

One of the reasons for the surge of honeypot scams in the market is **FTX's collapse**. After this FTX incident, as the trust that crypto users put on CEX is declining, we saw many users in crypto space begin to withdraw their digital assets and transfer them into a decentralized wallet. On-chain active users witnessed a surge while more so are the attackers. GoPlus data saw a newly added pattern of honeypot amounts to more than 120 and how often the attacks happen gets ~6x after a week of FTX collapsing

A sharp growth in numbers of honeypot scams beyond, the scam takes on the form of more sophisticated in pattern. As the competition between defending and attacking parties is getting tense, the hackers keep updating the way the attack works to make it less obvious and more difficult to be spotted. According to the data compiled by GoPlus Security from last year, there are some of the common attack patterns as below:

1. Make code less readable and hide the malicious logic

   It makes it more difficult for a security detector like GoPlus to identify the associated risks around a token by making the code less readable, including adding unnecessary code logic or calling relations within a piece of code. That would make more noise for the token contract and help hide the real logic which would deliver malicious behavior on a honeypot token.

2. Disguising its contract as an established project

   The attacker tries to get away from the security engine's detection by disguising its contract as some else including creating an exactly same contract name and contract implementation process as a well-known crypto project

3. Initiate the attack in a more intangible way

   The malicious code snippet tries to initiate the attack in a more intangible way, like making the action of trading tokens by the victims themself as a condition to initiate an attack. By doing so, the attacker needs to deal with the code in a more complex way. In practice, it works like this, only after multiple layers of nested conditionals past which are deliberately fabricated by hackers, the malicious behaviors could be executed, like some address couldn't be able to trade and transfer tokens, and more tokens are minted by privileged accounts. By doing all those things, a contract status could be modified and the asset could be stolen.

4. Faking trading volume.

   To entice more investors, the hackers could make it more like a real project with decent data showing a number flowing in and out on the market, instead of a scam .This could be done by sending airdrops to multiple addresses and faking a large number of trading volumes.

While the crypto attacks becomes more and more innovative and complicated, Goplus will be kicking off a new security risks series debuted from this piece, which as below takes a deep dive into the code on looking at how a new way of honeypot token's malicious logic could work.

---
### Case Analysis

That honeypot token is on BSC and the contract is [0x8f96e9348898b498a2b4677f4c8abdad64e4349f](https://bscscan.com/address/0x8f96e9348898b498a2b4677f4c8abdad64e4349f#code)

The address that's holding the token has been defined as a condition by the contract creator, which requires the cumulative amount of the tokens transferred out could not exceed the max limit. Otherwise, the transaction would fail. We see it as a typical honeypot scheme as the holders of the token would wind up with failing to sell their assets.

By transferring the contract ownership to a dead address, it seems like that the control by the owner over the contract has been destroyed. However, when taking a closer look at the contract code, we discovered that a method named `setAccSeMaxAmount` has been constructed, by which a specific control on changing the max amount of token that an address could transfer out is enabled and even alterring it arbitrarily.

**We'll take a deep dive into the code as below:**

1. Set the upper limit on the amount that could transfer out for any addresses that holds tokens.

   <div align=center>
   <img src="https://user-images.githubusercontent.com/52526645/212792084-4acc8745-c74b-4b95-943c-5d4cb87595f5.png" alt="Cover" width="70%"/>
   </div>
        
   * As seen in the snippet above, we see that a condition is placed on the sell order. On line `492`, `to == uniswapV2Pair` defines a condition that a token selling is happening. In this condition, the max amount of the token that could be transferred out has been placed on the address via the condition of `\_accSeAmount[from] \> 0`, and it would then accumulate the amount of tokens that have been transferred out at the moment from this address and then store it in `\_accSeAmount[from]`.
   * Next in line `495`, we see a condition has been placed for the execution of the transaction. That is the execution only works when the max amount of tokens that could be transferred out (sell included) placed on the address equals to or greater than the cumulative amount of tokens that has been transferred out for the given address. Otherwise, the transaction would fail. By doing this, a limit on selling has been placed on a certain address , which is the upper amount of the token that could be sold. But how did hackers locate the addresses?

2. An extra method of `setAccSeMaxAmount` controlled by contractSender1**
   * Check the owner of the contract address on etherscan and we see ownership of the contract has been transferred to the dead address `0x000000000000000000000000000000000000dead`.That means the owner's control over the contract has been disabled. Then how could `\_accSeMaxAmount[from]` could work in such a situation?

    <div align=center>
    <img src="https://user-images.githubusercontent.com/107821372/212655600-ae0ca5c8-8925-4270-990f-65fc483e0e68.png" alt="Cover" width="60%"/>
    </div>
      
   * However, when taking a closer look at the code, we see that an extra method in the name of `setAccSeMaxAmount` has been constructed, which could determine the max amount of tokens that could be transferred out for a given address. We see this method could be only controlled by a variable named `contractSender1`, which is assigned to the contract creator via `contractSender1 = msg.sender`.

    <div align=center>
    <img src="https://user-images.githubusercontent.com/52526645/212792240-dfceb1d1-5593-4048-9805-a74d378b0f9c.png" alt="Cover" width="80%"/>
    </div>

   * Now it seems like that the permission to call all the methods for the owner has been `disabled`. However, when taking a closer look on the contract code, we discovered that, a method named `setAccSeMaxAmount` has been constructed and can only be called by `contractSender1`, by which a specific control over writing the max amount of token that an address could transfer out has been retained and even alterring it arbitrarily.
  
---

### Listening for the off-chain event to target the addresses

Check the on-chain activities and we see that the contract address keeps calling the method of `setAccSeMaxAmount`. By doing this, a limit on selling has been placed on a certain address , which is the upper amount of the token that could be sold. But how did hackers locate the addresses? 

By checking the corresponding transaction details, we found that the hacker had collected the addresses by listening for the off-chain event. Once a new holder exists, the new address would be added to a blacklist.

If the cumulated number of the token sold by the addresses from the blacklist exceeds the limit, the transaction will fail.
<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212792296-a12cdbf0-ea3a-41b2-a1a8-039e7c0589a9.png" alt="Cover" width="80%"/>
</div>

## Summary
As hackers continue to iterate on their attack schemes, the security defense has become an extremely challenging task.

GoPlus security engine keeps an eye on all those attack vectors 24/7 around the clock and would never stop scanning the security risks associated with the token. In the same way,as a regular crypto user, we should never stop learning and honing our craft to be a web3 user with security awareness and security literacy. Only in this way can we protect against all those innovative but creepy risks.
