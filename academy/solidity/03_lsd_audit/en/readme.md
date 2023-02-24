# Lesson 3: Guidelines for Auditing Staking Protocols

Author:[QuillAudits](https://twitter.com/QuillAudits)

This document outlines the concept of liquidity staking protocols and auditing guidelines for staking protocols. The guidelines cover a range of vulnerable spots such as withdrawal mechanisms, rounding errors, external calls, fee logic, loops, structs, staking duration, and so on. 

This blog post will be a useful reference for auditing staking protocols and can help you identify potential bugs.

## What is Liquidity Staking?

Liquidity staking is a way for users to stake their cryptocurrency holdings and earn rewards without sacrificing liquidity. Instead of locking up their coins for a fixed period of time, users can receive a liquid token that represents their staked assets. This token can be traded or used like any other cryptocurrency, providing users with the flexibility to use their assets as they please while still earning staking rewards.
   
   <div align=center>
   <img src="https://user-images.githubusercontent.com/107821372/220809684-2dafef16-a5b6-48d9-b37e-bdcbe9ae3a1c.png" alt="Cover" width="80%"/>
   </div>
   
For example, let's say you have 100 ETH that you want to stake on the Ethereum network. Instead of locking up your ETH for a fixed period of time, you can use a liquidity staking service like Lido to stake your ETH and receive a liquid token called stETH in return. With stETH, you can still trade or use your staked ETH while earning staking rewards.

## Let’s get started with auditing staking contracts

Examine all of the audit specifications available before beginning with the contract code. It could be in the form of a white paper, README files, or something else. These will give you an idea of what the contract code will contain.

### ***When looking at the audit specification document for the staking contract, look for these points:***

* Types of Fees based and their calculations.
* Rewards mechanism for staked tokens
* Powers of the owner
* Will the contract hold ETH?
* What tokens the contract will hold?
* Original contract from which it is forked

Check that the specifications match the code. Begin with fees and tokenomics, followed by validation of the owner's authority. Check that all rewards and fee values are in accordance with the documentation.

## Vulnerable spots to look for?

1. Reward Withdraw Mechanism:

   Check that the staked token rewards mechanism is correctly implemented and that rewards are distributed fairly and proportionally to all stakers. Projects can distribute rewards in two ways: either automatically, on a periodic basis, or upon request by the users themselves. A withdrawal function can be implemented and customized according to the protocol's business logic.
   
   ### ***Below are a few checkpoints:***

   * Check if any user is able to withdraw more than its reward + staked amount.
   * Check for Overflow/underflow in the amount calculation
   * Check if certain parameters can have a negative impact on rewards during calculation.
   * If `block.timestamp` or `block.number` is used in this function. Check if it can be exploited in any way.
   
2. Fee Logic:

   If the deposit and withdrawal are subject to some fee, then verify that no single user can bypass the fee. Additionally, be vigilant for any potential overflow or underflow issues. Only the administrator or owner should be authorized to alter fee settings. Also verify that a threshold for maximum fees has been established, preventing the administrator from setting it at an excessively high amount.
   
3. LP Token’s Minting/Burning Mechanism：

   Verify if the minting and burning mechanisms have been correctly implemented. A burn function should reverse all state changes made by a mint function. Additionally, it is crucial to verify that users receive the appropriate amount of tokens during the first stake, when the pool is empty.
   
   The logic of minting and burning functions can be mathematically verified to uncover any hidden vulnerability. Also, the total supply of LP tokens minted should not exceed the staked assets.

4. Rounding Errors：

   Even though certain minor rounding mistakes are typically unavoidable and not a concern, they can grow significantly when it is possible to multiply them. Look for edge cases where one can profit from rounding errors by repeatedly staking and unstaking.
   
   To determine whether rounding errors can accrue to a substantial amount over an extended period of time, we can mathematically calculate the range of possible rounding errors.

5. Staking Duration：

   Ensure that the staking duration calculations in the contract align with the specified business logic. Verify that users cannot redeem rewards before the staking duration has ended by bypassing the duration checks. Also, Check if the duration of staking can be exploited by an attacker to get more rewards.

6. External Calls and Token Handling：

   Most of the external calls will be to the token contracts. So, we must determine what types of tokens the staking contract will handle. It is essential to check external calls for any errors and reentrancy attacks. Deflationary tokens or tokens with transfer fees, such as Safemoon, can pose a problem if their logic is not correctly implemented.

7. Price Manipulations Checks：

   Price Manipulation via a flash loan is One of the most frequent hacks on DeFi projects. There may be situations where malicious actors can use flash loans to manipulate prices during staking or unstaking large amount of tokens. Carefully review staking and unstaking functions to avoid edge-case scenarios that could result in flash loan-based price manipulation attacks and loss of other users' funds.

8. Some Additional Checks:

   * **Loops**: If the contract logic involves looping over arrays, it's important to ensure that the block gas limit is not exceeded. This can occur when the array size is very large, so you should investigate what functions could increase the size of the array and whether any user could exploit it to cause a DoS attack. Check out this [report](https://github.com/code-423n4/2022-06-putty-findings/issues/227).
   
   * **Structs**：Staking contracts use the struct type to store user or pool data. When declaring or accessing a struct within a function, it's important to specify whether to use “memory” or “storage.” It might help us save some gas. For more information, please refer to this [article](https://medium.com/coinmonks/ethereum-solidity-memory-vs-storage-which-to-use-in-local-functions-72b593c3703a).
   
   * **Front-Running**：Look for any scenarios where malicious actors could front-run any transaction to their advantage.
   
   * **Function Visibility/ Access Control Checks**：Any function that is declared as external or public can be accessed by anyone. Therefore, it is important to ensure that no public function can perform any sensitive actions. It is crucial to verify that the staking protocol has implemented appropriate controls to prevent unauthorized access to both the staked coins and the system's infrastructure.
   
   * **Centralization Risks**：It is important not to give the owner excessive powers. If the admin address is compromised, it could cause significant damage to the protocol. Verify that the owner or admin privileges are appropriate and ensure that the protocol has a plan in place for handling situations where an admin's private keys are leaked.
   
   * **ETH / WETH handling**：Contracts often include specific logic for handling ETH. For example, when `msg.value > 0`, a contract may convert ETH to WETH while still allowing WETH to be received directly. When a user specifies WETH as the currency but sends ETH with the call, this can break certain invariants and lead to incorrect behavior.
   
  So far, we have discussed liquidity staking protocols and the auditing guidelines for such protocols. In a nutshell, Liquidity staking allows users to earn staking rewards without sacrificing liquidity. We have outlined the vulnerable spots in staking contracts that auditors must pay attention to, such as withdrawal mechanisms, fee logic, LP token minting/burning mechanism, rounding errors, staking duration, external calls, and price manipulation checks. 
  
We recommend auditors to examine audit specifications documents, match specifications with code, and check fees and tokenomics validation. Apart from that, we also recommend some additional checks such as looping over arrays, specifying memory or storage for struct type data, and front-running scenarios. These guidelines will be useful for auditing staking protocols and help identify potential bugs.

## Further Reading

[DeFi Risk 101- An insecure fork of Masterchef](https://www.google.com/url?q=https://inspexco.medium.com/defi-risks-101-1-an-insecure-fork-of-masterchef-b44ca01b4e5e&sa=D&source=docs&ust=1677132410175689&usg=AOvVaw180xhoJbIov48c7otX-LlK)

[Polygon Yield Farm Exploit](https://www.google.com/url?q=https://cryptobriefing.com/polygon-yield-farm-crashes-zero-after-exploit/&sa=D&source=docs&ust=1677132417868263&usg=AOvVaw3h-b8eV6YHprUvDCb5DGor)

[SCSVS V2- Liquid Staking](https://www.google.com/url?q=https://github.com/ComposableSecurity/SCSVS/blob/master/2.0/0x200-Components/0x207-C7-Liquid-staking.md&sa=D&source=docs&ust=1677132424183933&usg=AOvVaw1KnZ5FOjTnpl1ay_CkeOQq)

[Security Risks of Staking Providers](https://www.google.com/url?q=https://runtimeverification.com/blog/security-risks-for-staking-providers/&sa=D&source=docs&ust=1677132434840543&usg=AOvVaw0ZUTVBM3VcTiX60hPvCxBM)

[Liquid Staking](https://www.google.com/url?q=https://www.finoa.io/blog/guide-liquid-staking/&sa=D&source=docs&ust=1677132447838820&usg=AOvVaw2RvZflu_I4ZGsWCIF3FTyW)

[Smart contract Auditing Heuristics](https://www.google.com/url?q=https://github.com/OpenCoreCH/smart-contract-auditing-heuristics&sa=D&source=docs&ust=1677132459011494&usg=AOvVaw2PFAeuRVmqqltA3XLrHDYJ)

## Sample Audit Reports for Reference:

[Euler Staking](https://github.com/Quillhash/QuillAudit_Reports/blob/master/Euler%20Staking%20Smart%20Contract%20Audit%20Report%20-%20QuillAudits.pdf)

[BollyStake](https://www.google.com/url?q=https://github.com/Quillhash/QuillAudit_Reports/blob/master/BollyStake%2520Smart%2520Contract%2520Audit%2520Report(new)%2520-%2520QuillAudits.pdf&sa=D&source=docs&ust=1677132477727119&usg=AOvVaw1NkvRag04h1SouBSPxsK4u)

[Stakehouse](https://code4rena.com/reports/2022-11-stakehouse/)

[PolyNuts Masterchef](https://github.com/Quillhash/QuillAudit_Reports/blob/master/PolyNuts%20Smart%20Contract%20Audit%20Report%20-%20QuillAudits.pdf)

[Pancakeswap Masterchef](https://certik-public-assets.s3.amazonaws.com/REP-PancakeSwap-16_10_2020.pdf)


