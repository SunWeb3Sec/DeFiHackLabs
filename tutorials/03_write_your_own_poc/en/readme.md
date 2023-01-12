# OnChain Transaction Debugging: 3. Write Your Own PoC

Author: [▓▓▓▓▓▓](https://twitter.com/h0wsO1)

Community: [Discord](https://discord.gg/3y3d9DMQ)

Published on: XREX | [WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)

In [01_Tools](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/en), we learned how to use various tools to analyze transactions in smart contracts.

In  [02_Warm](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/academy/onchain_debug/02_warmup/en/readme.md), we analyzed a transaction on a decentralized exchange using Foundry.

For this publication, we will analyze an attack incident utilizing an oracle exploit. We’ll take you step-by-step through key function calls and then we’ll reproduce the attack together using the Foundry framework.


## Why is Reproducing Attacks Helpful?

At DeFiHackLabs we intend to promote Web3 security. We hope that when attacks happen, more people can analyze and contribute to overall security.

1. As unfortunate victims we improve our incident response and effectiveness.
2. As a whitehat we improve our ability in writing PoCs and snatch bug bounties. 
3. Aid the blue team in adjusting machine learning models. Ie., [Forta Network](https://forta.org/blog/how-fortas-predictive-ml-models-detect-attacks-before-exploitation/).
4. You’ll learn much more from reproducing the attack compared to reading post-mortems.
5. Improve your overall Solidity ”Kung Fu“.

## Some Need-to-knows Before Reproducing Transactions

1. Understanding of common attack modes. Which we have curated in [DeFiVulnLabs](https://github.com/SunWeb3Sec/DeFiVulnLabs).
2. Understanding of basic DeFi mechanisms including how smart contracts interact with each other.


### DeFi Oracle Introduction

Currently, smart contract values such as pricing and configurations cannot update themselves. To perform its contract logic, sometimes it requires external data during execution. This is typically done with the following methods.

1. Through externally owned accounts. We can calculate the price based on the reserves of these accounts.
2. Use an oracle. An oracle is a contract that is maintained by someone or even yourself. With external data updated periodically. ie., price, interest rate, anything. 

* For example, there is a lending contract, it requires the current ETH price to determine if the borrower’s position is to be liquidated.

  * In this case, ETH price is the external data. One possible solution is to obtain it from Uniswap V2.

    We know the formula  `x * y = k` in a typical AMM. `x` ( ETH price in this case) =  `k / y`.

    So we take a look at the Uniswap V2 WETH/USDC trading pair contract. At this address `0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc`.

![UniV2PairInfo](https://user-images.githubusercontent.com/26408530/211231355-0d1fb43e-280e-4328-b71e-9797be5ce7ec.png)

* At the time of publication we see the following reserve values:

  * WETH: `33,906.6145928`  USDC: `42,346,768.252804` 

  * Formula: Applying the `x * y = k` formula will yield the price for each ETH:

     `42,346,768.252804 / 33,906.6145928 = 1248.9235`

  * Solidity Pseudocode:For the lending contract to fetch the current ETH price,the pseudocode can be as the following:

```solidity=
uint256 UniV2_ETH_Reserve = WETH.balanceOf(0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc);
uint256 UniV2_USDC_Reserve = USDC.balanceOf(0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc);
uint256 ETH_Price = UniV2_USDC_Reserve / UniV2_ETH_Reserve;
```
   > #### Please note this method of obtaining price is easily manipulated. Please do not use it in the production code.

### Skim()
In Uniswap V2, skim() is one of the bail-out functions.

During a trade, it is possible to overfill uint112 storage slots for reserves if enough tokens are sent to a pair, which would otherwise cause the trade to fail. Using skim(), a user can withdraw the difference between the pair's current balance and that of the caller if the difference exceeds zero.

This function, however, can also be used with Price Actions.


* To understand Uniswap V2 AMM mechanisms, you may check [Smart Contract Programmer](https://www.youtube.com/watch?v=Ar4Ik7Bov0U).

* To understand more about oracle manipulation, you may check [WTFSolidity](https://github.com/WTFAcademy/WTF-Solidity/blob/main/S15_OracleManipulation/readme.md).


### Oracle Price Manipulation Attack Modes

Most common attack modes:

1. Alter the oracle address
    * Root cause: lack of verification mechanism
    * For example: [Rikkei Finance](https://github.com/SunWeb3Sec/DeFiHackLabs#20220415-rikkei-finance---access-control--price-oracle-manipulation)
2. Through flash loans, an attacker can drain liquidity, resulting in wrong pricing information in an oracle.
    * This is most often seen in attackers calling these functions. GetPrice、Swap、StackingReward, Transfer(with burn fee), etc.
    * Root cause: Protocols using unsafe/compromised oracles, or the oracle did not implement time-weighted average price features.
    * Example: [One Ring Finance](https://github.com/SunWeb3Sec/DeFiHackLabs#20220321-onering-finance---flashloan--price-oracle-manipulation)

    >  Protip-case 2: During code review ensure the function`balanceOf()`is well guarded.

## Step-by-step PoC - An Example from EGD Finance

### Step1: Information gathering

* Upon discovery of an attack. Twitter will often be the front line of the aftermath. Top DeFi analysts will continuously publish their new findings there.

> Protip: Join the [DeFiHackLabs Discord](https://discord.gg/Fjyngakf3h) security-alert channel to receive curated updates from top DeFi analysts!

* Upon an attack incident, it is important to gather and organize the newest information. Here is a template!
  1. Transaction ID
  2. Attacker Address(EOA)
  3. Attack Contract Address
  4. Vulnerable Address
  5. Total Loss
  6. Reference Links
  7. Post-mortem Links
  8. Vulnerable snippet
  9. Audit History

> Protip: Use the [Exploit-Template.sol](/script/Exploit-template.sol) template from DeFiHackLabs.
---
### Step2: Transaction Debugging

Based on experience, 12 hours after the attack, 90% of the attack autopsy will have been completed. It’s usually not too difficult to analyze the attack at this point.

* We will use a real case of EGD Finance as an example, to help you understand :
  1. the risk in oracle manipulation.
  2. how to profit from oracle manipulation.
  3. flash loans transaction.
  4. how attackers use only 1 transaction to accomplish the attack. This will be easier to reproduce.

* Let's use Phalcon from Blocksec to analyze the EGD Finance incident, [link to analysis](https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3).
<img width="1644" alt="Screenshot 2023-01-11 at 4 59 15 PM" src="https://user-images.githubusercontent.com/107821372/211762771-d2c54800-4595-4630-9392-30431094bfca.png">

* In Ethereum EVM, you will see 3 call types to trigger remote functions:
  1. Call: Typical cross-contract function call, will often change the receiver’s storage.
  2. StaticCall: Will not change the receiver’s storage, used for fetching state and variables.
  3. DelegateCall: `msg.sender`  will remain the same, typically used in proxying calls. Please see [WTF Solidity](https://github.com/WTFAcademy/WTF-Solidity/tree/main/23_Delegatecall) for more details.

> Please note, internal function calls[^1] are not visible in Ethereum EVM.
[^1]:nternal function calls are invisible to the blockchain, since they don't create any new transactions or blocks. In this way, they cannot be read by other smart contracts or show up in the blockchain transaction history.
---

Flash loan attack mode: 



1. Check if the attack will be profitable. First, ensure loans can be obtained, then ensure the target has enough balance.
    * This means you will see some static calls in the beginning.
2. Use DEX or Lending Protocols to obtain a flash loan
    * Look for the following key function calls
    * UniswapV2, Pancakeswap: .swap()
    * Balancer: flashLoan()
    * DODO: .flashloan()
    * AAVE: .flashLoan()
3. Callbacks from flash loan protocol to attacker’s contract
    * Look for the following key function calls
    * UniswapV2: .uniswapV2Call()
    * Pancakeswap: .Pancakeswap()
    * Balancer: .receiveFlashLoan()
    * DODO: .DXXFlashLoanCall()
    * AAVE: .executeOperation()
4. Execute the attack to profit from contract weakness.
5. Return the flash loan
    * Set approval allowing loan platforms to use transferFrom() and return the loan.

Practice: Identify various stages of the EGD Finance Exploit attack. More specifically flashloan, callback, weakness, and profit.

Expand Level: 3

[https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3](https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3)



<p id="gdcalert3" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image3.png). Store the image on your image server and adjust the path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert4">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image3.png "image_tooltip")


Protip: If you are unable to understand the logic of individual function calls. Try tracing through the entire call stack sequentially, take notes, and pay special attention to the money trail. You’ll have a much better understanding after doing this a few times.


---

At this point, we have a much better understanding of an attack transaction. Let’s now try to reproduce some code:

Step 1. Complete fixtures.

Click to show the code

Step2. Simulate an attacker calling the harvest function

Click to show the code

Step3. Complete part of the attack contract

Click to show the code


---

Let's continue with analyzing the exploit…

We see here the attacker called Pancakeswap.swap() function to take advantage of the exploit, looks like there is a second flash loan call in the call stack.



<p id="gdcalert4" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image4.png). Store the image on your image server and adjust the path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert5">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image4.png "image_tooltip")


Pancakeswap uses the .pancakeCall() interface to perform a callback on the attacker’s contract. You might be wondering how the attacker is executing different codes during each of the two callbacks.

The key is in the first flash loan, the attacker used 0x0000 in callback data.



<p id="gdcalert5" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image5.png). Store the image on your image server and adjust the path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert6">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image5.png "image_tooltip")


However, during the second flash loan, the attacker used 0x00 in callback data.



<p id="gdcalert6" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image6.png). Store the image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert7">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image6.png "image_tooltip")


Through this method, an attacking contract can determine what code to execute based on the _data parameter. Which could be either 0x0000 or 0x00.

Let's continue with analyzing the second callback logic during the second flash loan.

During the second callback, the attacker only called claimAllReward() from EGD Finance:



<p id="gdcalert7" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image7.png). Store the image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert8">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image7.png "image_tooltip")


Expanding the claimAllReward() call stack. You’ll find EGD Finance performed a read on  0xa361-Cake-LP for the balance of EGD Token and USDT, then transferred a large amount of EGD Token to the attacker’s contract.



<p id="gdcalert8" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image8.png). Store the image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert9">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image8.png "image_tooltip")


What is the 0xa361-Cake-LP contract?

Let's analyze the claimAllReward() function to see where the exploit lies.



<p id="gdcalert9" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image9.png). Store the image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert10">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image9.png "image_tooltip")


We see that the amount of Staking Reward is based on the reward quota factor (Meaning the amount of staking, and duration of staking) multiplied by getEGDPrice() the current EGD token price.

In return this means, the EGD Staking Reward is based on the price of the EGD Token. Less reward is yielded on a high EGD Token price and vice versa.

Now let's check how the getEGDPrice() function gets the current price of EGD Token:



<p id="gdcalert10" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image10.png). Store the image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert11">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image10.png "image_tooltip")


We see the all-familiar equation x * y = k like the one we introduced earlier in the DeFi oracle introduction section, to obtain the current price. The address of the trading pair is 0xa361-Cake-LP which matches the two STATICCALLs from the transaction view.






So how is the attacker taking advantage of this unsafe method of getting current prices?

The underlying mechanism is such that, from the second flash loan the attacker borrowed a large amount of USDT, therefore influencing the pool price based on the x * y = k formula. Before returning the loan, the getEGDPrice() will be incorrect.

Reference diagram:

![alt_text](images/image12.png "image_tooltip")


Conclusion: The attacker used a flash loan to alter the liquidity of the EGD/USDT trading pair, resulting in ClaimReward() getting an incorrect price, allowing the attacker to obtain an obscene amount of EGD tokens.

Finally, the attacker exchanged EGD Token using Pancakeswap for USDT, thus profiting from the attack.


---

Now that we’ve fully understood the attack, let's reproduce it:

Step4. Write the PoC code for the attack

Click to show the code

Step5. Write the PoC code for the second flash loan using the exploit

Click to show the code

Execute the code with forge test --contracts ./src/test/EGD-Finance.exp.sol -vvv. Pay attention to the change in balances.

[DeFiHackLabs - EGD-Finance.exp.sol](https://github.com/finn79426/DeFiHackLabs/blob/main/src/test/EGD-Finance.exp.sol)

Running 1 test for src/test/EGD-Finance.exp.sol: Attacker

[PASS] testExploit() (gas: 537204)

Logs:

  --------------------  Pre-work, stake 10 USDT to EGD Finance --------------------

  Tx: 0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8

  Attacker Stake 10 USDT to EGD Finance

  -------------------------------- Start Exploit ----------------------------------

  [Start] Attacker USDT Balance: 0.000000000000000000

  [INFO] EGD/USDT Price before price manipulation: 0.008096310933284567

  [INFO] Currently earned reward (EGD token): 0.000341874999999972

  Attacker manipulating price oracle of EGD Finance...

  Flashloan[1] : borrow 2,000 USDT from USDT/WBNB LPPool reserve

  Flashloan[1] received

  Flashloan[2] : borrow 99.99999925% USDT of EGD/USDT LPPool reserve

  Flashloan[2] received

  [INFO] EGD/USDT Price after price manipulation: 0.000000000060722331

  Claim all EGD Token rewards from the EGD Finance contract

  [INFO] Get reward (EGD token): 5630136.300267721935770000

  Flashloan[2] payback success

  Swap the profit...

  Flashloan[1] payback success

  -------------------------------- End Exploit ----------------------------------

  [End] Attacker USDT Balance: 18062.915446991996902763

Test result: ok. 1 passed; 0 failed; finished in 1.66s

Note: EGD-Finance.exp.sol from DeFiHackLabs includes a preemptive step which is staking.

This write-up does not include this step, feel free to try it yourself! Attacker Stack Tx: 0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8


## The third sharing will conclude here, if you wish to learn more, check out the links below.


## Learning materials

[samczsun's eth txn explorer and vscode extension](https://www.youtube.com/watch?v=HXgu239mPBc)

[Vulnerabilities in DeFi by Daniel V.F.](https://www.youtube.com/watch?v=9fcOffCg2ig)

[Tenderly.co - Debug Transaction](https://www.youtube.com/watch?v=90GN9Ut8LhU)

[Reversing The EVM: Raw Calldata](https://degatchi.com/articles/reading-raw-evm-calldata)

[https://web3sec.xrex.io/](https://web3sec.xrex.io/)

* ERRORs: 0
* WARNINGs: 0
* ALERTS: 12

Conversion time: 9.066 seconds.


Using this Markdown file:

1. Paste this output into your source file.
2. See the notes and action items below regarding this conversion run.
3. Check the rendered output (headings, lists, code blocks, tables) for proper
   formatting, and use a link checker before you publish this page.

Conversion notes:

* Docs to Markdown version 1.0β34
* Tue Jan 10 2023 22:15:22 GMT-0800 (PST)
* Source doc: Untitled document
* This document has images: check for >>>>> gd2md-HTML alert:  inline image link in generated source and store images to your server. NOTE: Images in an exported zip file from Google Docs may not appear in the same order as they do in your doc. Please check the images!

----->


<p style="color: red; font-weight: bold">>>>>>  gd2md-HTML alert:  ERRORs: 0; WARNINGs: 0; ALERTS: 12.</p>
<ul style="color: red; font-weight: bold"><li>See top comment block for details on ERRORs and WARNINGs. <li>In the converted Markdown or HTML, search for inline alerts that start with >>>>>  gd2md-html alert:  for specific instances that need correction.</ul>

<p style="color: red; font-weight: bold">Links to alert messages:</p><a href="#gdcalert1">alert1</a>Improve your overall Solidity Kung Fu
<a href="#gdcalert2">alert2</a>
<a href="#gdcalert3">alert3</a>
<a href="#gdcalert4">alert4</a>
<a href="#gdcalert5">alert5</a>
<a href="#gdcalert6">alert6</a>
<a href="#gdcalert7">alert7</a>
<a href="#gdcalert8">alert8</a>
<a href="#gdcalert9">alert9</a>
<a href="#gdcalert10">alert10</a>
<a href="#gdcalert11">alert11</a>
<a href="#gdcalert12">alert12</a>

<p style="color: red; font-weight: bold">>>>>> PLEASE check and correct alert issues and delete this message and the inline alerts.<hr></p>



# OnChain Transaction Debugging: 3. Write Your Own PoC

Author: [▓▓▓▓▓▓](https://twitter.com/h0wsO1)

Community: [Discord](https://discord.gg/3y3d9DMQ)

Published on: XREX | WTF Academy

In [01_Tools](https://github.com/finn79426/DeFiHackLabs/blob/main/tutorials/onchain_debug/01_tools/readme.md), we learned how to use various tools to analyze transactions in smart contracts.

In  [02_Warm](https://github.com/finn79426/DeFiHackLabs/blob/main/tutorials/onchain_debug/02_warm/readme.md), we analyzed a transaction on a decentralized exchange using Foundry.

For this publication we will analyze an attack incident utilizing an oracle exploit. We’ll take you step-by-step through key function calls and then we’ll reproduce the attack together using the Foundry framework.


## Why is Reproducing Attacks Helpful?

At DeFiHackLabs we intend to promote Web3 security. We hope that when attacks happen, more people can analyze and contribute to the overall security.



1. As an unfortunate victim we improve our incident response and effectiveness.
2. As a whitehat we improve our ability in writing PoCs and snatch bug bounties. 
3. Aid the blue team in adjusting machine learning models. Ie., [Forta Network](https://forta.org/blog/how-fortas-predictive-ml-models-detect-attacks-before-exploitation/).
4. You’ll learn much more from reproducing the attack compared to reading post mortems.
5. You’ll improve your overall Solidity Kung Fu.


## Some Need-to-knows Before Reproducing Transactions



1. Understanding of common attack modes. Which we have curated in [DeFiVulnLabs](https://github.com/SunWeb3Sec/DeFiVulnLabs).
2. Understanding of basic DeFi mechanisms including how smart contracts interact with each other.


## DeFi Oracle Introduction

Currently, smart contract values such as pricing and configurations cannot update itself. To perform its contract logic, sometimes it requires external data during execution. This is typically done with the following methods.



1. Through externally owned accounts. We can calculate the price based on reserves of these accounts.
2. Use an oracle. An oracle is a contract that is maintained by someone or even yourself. With external data updated periodically. ie., price, interest rate, anything really. 

For example: There is a lending contract, it requires the current ETH price to determine if the borrower’s position is to be liquidated.

In this example, ETH price is the external data. One possible solution is to obtain it from Uniswap V2.

We know the formula x * y = k in a typical AMM. x ( ETH price in this case) = k / y

So we take a look at the Uniswap V2 WETH/USDC trading pair contract. At this address 0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc.



<p id="gdcalert1" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image1.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert2">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image1.png "image_tooltip")


At the time of publication we see the following reserve values:

WETH: 33,906.6145928  USDC: 42,346,768.252804 

Applying the x * y = k formula will yield the price for each ETH:

42,346,768.252804 / 33,906.6145928 = 1248.9235

(存在細微差距，通常代表交易手續費收入或是有人意外轉入代幣，可被 skim() 取走)

所以，套利合約若想要取得 ETH 的價格，Solidity Pseudocode 大致可以理解成：

(The calculated price often yields minute discrepancies from the market price. This usually means trading fee or new transaction affecting the pool, this variance can be skimmed using the skim() function.)

Therefore, for the lending contract to fetch the current ETH price. The pseudocode can be summarized as the following:

uint256 UniV2_ETH_Reserve = WETH.balanceOf(0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc);

uint256 UniV2_USDC_Reserve = USDC.balanceOf(0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc);

uint256 ETH_Price = UniV2_USDC_Reserve / UniV2_ETH_Reserve;

Please note this method of obtaining price is easily manipulated. Please do not use it in production code.

To understand Uniswap V2 AMM mechanisms, you may check [Smart Contract Programmer](https://www.youtube.com/watch?v=Ar4Ik7Bov0U).

To understand more about oracle manipulation, you may check [WTFSolidity](https://github.com/WTFAcademy/WTF-Solidity/blob/main/S15_OracleManipulation/readme.md).


## Oracle Price Manipulation Attack Modes

Most common attack modes:



1. Alter oracle address
    * Root cause: lack of verification mechanism
    * For example: [Rikkei Finance](https://github.com/SunWeb3Sec/DeFiHackLabs#20220415-rikkei-finance---access-control--price-oracle-manipulation)
2. Through flash loans, an attacker can drain liquidity, resulting in wrong pricing information in an oracle.
    * This is most often seen in attackers calling these functions. GetPrice、Swap、StackingReward, Transfer(with burn fee) etc.
    * Root cause: Protocols using unsafe/compromised oracles, or the oracle did not implement time-weighted average price features.
    * Example: [One Ring Finance](https://github.com/SunWeb3Sec/DeFiHackLabs#20220321-onering-finance---flashloan--price-oracle-manipulation)

Protip: During code review ensure the function balanceOf() is well guarded.


## Step-by-step PoC - An Example from EGD Finance


### Step1: Information gathering

Upon a discovery of an attack. Twitter will often be the front line of the aftermath. Top DeFi analysts will continuously publish their new findings there.

Protip: Join the [DeFiHackLabs Discord](https://discord.gg/vG4FePvr) security-alert channel to receive curated updates from top DeFi analysts!

Upon an attack incident, it is important to gather and organize the newest information. Here is a template!



1. Transaction ID
2. Attacker Address(EOA)
3. Attack Contract Address
4. Vulnerable Address
5. Total Loss
6. Reference Links
7. Post-mortem Links
8. Vulnerable snippet
9. Audit History

Protip: Use the [Exploit-Template.sol](https://github.com/finn79426/DeFiHackLabs/blob/main/academy/onchain_debug/03_write_your_own_poc/script/Exploit-template.sol) template from DeFiHackLabs.


---


### Step2: Transaction Debugging

Based on experience, 12 hours after the attack, 90% of the attack autopsy will have been completed. It’s usually not too difficult to analyze the attack at this point.

The reason we used EGD Finance as an example:



1. To understand the risk in oracle manipulation from a real case.
2. To understand how to profit from oracle manipulation.
3. To understand flash loans.
4. Attacker used only 1 transaction to accomplish the attack without due diligence. This will be easier to reproduce.

Lets use Phalcon from Blocksec to analyze the EGD Finance incident, [link to analysis](https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3).



<p id="gdcalert2" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image2.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert3">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image2.png "image_tooltip")


In Ethereum EVM, you will see 3 call types to trigger remote functions:



1. Call: Typical cross contract function call, will often change the receiver’s storage.
2. StaticCall: Will not change the receiver’s storage, used for fetching state and variables.
3. DelegateCall: msg.sender will remain the same, typically used in proxying calls. Please see [WTFSolidity](https://github.com/WTFAcademy/WTF-Solidity/tree/main/23_Delegatecall) for more details.

Please note, internal function calls are not visible.


---

Flash loan attack mode: 



1. Check if the attack will be profitable. First, ensure loans can be obtained, then ensure the target has enough balance.
    * This means you will see some static calls in the beginning.
2. Use DEX or Lending Protocols to obtain flash loan
    * Look for the following key function calls
    * UniswapV2, Pancakeswap: .swap()
    * Balancer: flashLoan()
    * DODO: .flashloan()
    * AAVE: .flashLoan()
3. Callbacks from flash loan protocol to attacker’s contract
    * Look for the following key function calls
    * UniswapV2: .uniswapV2Call()
    * Pancakeswap: .Pancakeswap()
    * Balancer: .receiveFlashLoan()
    * DODO: .DXXFlashLoanCall()
    * AAVE: .executeOperation()
4. Execute the attack to profit from contract weakness.
5. Return the flash loan
    * Set approval allowing loan platforms to use transferFrom() and return the loan.

Practice: Identify various stages of the EGD Finance Exploit attack. More specifically flashloan, callback, weakness, profit.

Expand Level: 3

[https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3](https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3)



<p id="gdcalert3" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image3.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert4">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image3.png "image_tooltip")


Protip: If you are unable to understand the logic of individual function calls. Try tracing through the entire call stack sequentially, take notes, pay special attention to the money trail. You’ll have a much better understanding after doing this a few times.


---

At this point we have a much better understanding of an attack transaction. Let’s now try to reproduce some code:

Step 1. Complete fixtures.

Click to show code

Step2. Simulate an attacker calling the harvest function

Click to show code

Step3. Complete part of the attack contract

Click to show code


---

Let's continue with analyzing the exploit…

We see here the attacker called Pancakeswap.swap() function to take advantage of the exploit, looks like there is a second flash loan call in the call stack.



<p id="gdcalert4" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image4.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert5">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image4.png "image_tooltip")


Pancakeswap uses the .pancakeCall() interface to perform callback on the attacker’s contract. You might be wondering how the attacker is executing different code during each of the two  callbacks?

The key is in the first flash loan, the attacker used 0x0000 in callbackData.



<p id="gdcalert5" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image5.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert6">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image5.png "image_tooltip")


However, during the second flash loan, the attacker used 0x00 in callbackData.



<p id="gdcalert6" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image6.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert7">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image6.png "image_tooltip")


Through this method, an attack contract can determine what code to execute based on the _data parameter. Which could be either 0x0000 or 0x00.

Let's continue on with analyzing the second callback logic during the second flash loan.

During the second callback, the attacker only called claimAllReward() from EGD Finance:



<p id="gdcalert7" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image7.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert8">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image7.png "image_tooltip")


Expanding the claimAllReward() call stack. You’ll find EGD Finance performed a read on  0xa361-Cake-LP for the balance of EGD Token and USDT, then transferred a large amount of EGD Token to the attacker’s contract.



<p id="gdcalert8" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image8.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert9">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image8.png "image_tooltip")


What is the 0xa361-Cake-LP contract?

Let's analyze the claimAllReward() function to see where the exploit lies.



<p id="gdcalert9" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image9.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert10">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image9.png "image_tooltip")


We see that the amount of Staking Reward is based on reward quota factor (Meaning the amount of staking, duration of staking) multiplied by getEGDPrice() the current EGD token price.

In return this means, the EGD Staking Reward is based on the price of EGD Token. Less reward is yielded on a high EGD Token price and vice versa.

Now let's check how the getEGDPrice() function gets the current price of EGD Token:



<p id="gdcalert10" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image10.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert11">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image10.png "image_tooltip")


We see the all familiar equation x * y = k like the one we introduced earlier in the DeFi oracle introduction section, to obtain current price. The address of the trading pair is 0xa361-Cake-LP which matches the two STATICCALLs from the transaction view.



<p id="gdcalert11" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image11.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert12">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image11.png "image_tooltip")


So how is the attacker taking advantage of this unsafe method of getting current prices?

The underlying mechanism is such that, from the second flash loan the attacker borrowed large amount of USDT, therefore influencing pool price based on x * y = k formula. Before returning the loan, the getEGDPrice() will be incorrect.

Reference diagram:



<p id="gdcalert12" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image12.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert13">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image12.png "image_tooltip")


Conclusion: Attacker used a flash loan to alter the liquidity of the EGD/USDT trading pair, resulting in ClaimReward() getting an incorrect price, allowing the attacker to obtain an obscene amount of EGD token.

Finally, the attacker exchanged EGD Token using Pancakeswap for USDT, thus profiting from the attack.


---

Now that we’ve fully understood the attack, lets reproduce it:

Step4. Write the PoC code for the attack

Click to show code

Step5. Write the PoC code for the second flash loan using the exploit

Click to show code

Execute the code with forge test --contracts ./src/test/EGD-Finance.exp.sol -vvv. Pay attention to the change in balances.

[DeFiHackLabs - EGD-Finance.exp.sol](https://github.com/finn79426/DeFiHackLabs/blob/main/src/test/EGD-Finance.exp.sol)

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

Note: EGD-Finance.exp.sol from DeFiHackLabs includes a preemptive step which is staking.

This writeup does not include this step, feel free to try it yourself! Attacker Stack Tx: 0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8


## The third sharing will conclude here, if you wish to learn more, checkout the links below.


## Learning materials

[samczsun's eth txn explorer and vscode extension](https://www.youtube.com/watch?v=HXgu239mPBc)

[Vulnerabilities in DeFi by Daniel V.F.](https://www.youtube.com/watch?v=9fcOffCg2ig)

[Tenderly.co - Debug Transaction](https://www.youtube.com/watch?v=90GN9Ut8LhU)

[Reversing The EVM: Raw Calldata](https://degatchi.com/articles/reading-raw-evm-calldata)

[https://web3sec.xrex.io/](https://web3sec.xrex.io/)


