# Lesson 1: Smart Contract Audit Methodology & Tips

Author: [Sm4rty](https://twitter.com/Sm4rty_)

**Summary:**
This blog outlines a methodology for auditing smart contracts. While there is no universal approach, this post provides insight into creating your own. Additionally, it includes resources and advice to help you become an efficient and effective auditor.

Let's start:

## **Step 1: Reading the Documentation and developing Mental Model:**

Before starting with auditing, one must first understand the project first which includes the technical designs, objectives of the Project, Contract types, etc. There are many sources that can help an auditor to understand and grasp the project.

1. Whitepapers or Documentations.
2. Code Comments and Natspec
3. Projects Website/Blogs and so on.

**Developing Mental Model**

While reading through the documentation It is critical to develop a mental model for auditing. The audit will be built on your mental model of the smart contract system. Before looking deeper into the details, it is essential that we have a strong high-level understanding of the contracts. 

***Some tools can help you assist with this process:***

**[Solidity Metrics:](https://marketplace.visualstudio.com/items?itemName=tintinweb.solidity-metrics)** This extension will generate Source Code Metrics, Complexity, call graphs, and Risk profile reports for projects written in [solidity](https://solidity.readthedocs.io/). It will help you understand the overview of the contracts. 

![https://user-images.githubusercontent.com/2865694/78451004-0252de00-7683-11ea-93d7-4c5dc436a14b.gif](https://user-images.githubusercontent.com/2865694/78451004-0252de00-7683-11ea-93d7-4c5dc436a14b.gif)

**[Solidity Visual Developer](https://marketplace.visualstudio.com/items?itemName=tintinweb.solidity-visual-auditor)**: This extension contributes **security-centric** syntax and semantic highlighting, a detailed class outline, specialized views, graphs, advanced Solidity code insights, and augmentation to Visual Studio Code. You can use it to automatically generate call graphs and UML diagrams.

![https://user-images.githubusercontent.com/2865694/57710279-e27e8a00-766c-11e9-9ca9-8cde50aa31fc.gif](https://user-images.githubusercontent.com/2865694/57710279-e27e8a00-766c-11e9-9ca9-8cde50aa31fc.gif)

---

## **Step 2: Running some Tools:**

**Static Analysis Tools:** 

In this step, we will run some static analysis tools. Static analysis tools are used to analyze smart contracts for common security vulnerabilities and low-hanging bugs. Static Analysis tools will drastically decrease your false-negative rate and help you catch things that manual analysis rarely uncovers. 

We can use [Mythx](https://mythx.io/), [Slither](https://github.com/crytic/slither), [Mythril,](https://github.com/ConsenSys/mythril) [4naly3er](https://github.com/Picodes/4naly3er), and a lot of other tools for it.

**Fuzzing Tools:** 

Fuzzing involves providing a large number of random inputs to a smart contract and observing how it responds. The goal of fuzzing is to find edge cases and unexpected behaviors that might indicate a security vulnerability or bug.
We can use tools like [Echidna](https://github.com/crytic/echidna), [Foundry Fuzz](https://book.getfoundry.sh/forge/fuzz-testing), or some other tools for fuzzing. 

*It's important to note that, while these tools can provide valuable insights and identify many potential issues, they are not a replacement for a thorough manual review, which is our next step.*

---

## **Step 3: Manual Code Review**

Now, that we know the overview of what the protocol does and have an eagle-eye view of the contracts.  Let's dive deep into the contracts and start Manual Auditing. Start Reading the codes  Line by Line to get an understanding of the contracts.  

Think like an attacker and identify potential places where things can go wrong. The following are some of the most common checks I look for:

1. Common Smart contract bugs
2. Access Controls Checks in Critical Functions
3. Check if the contract complies with the standards
4. The flow of Function calls
5. Examine all User-controlled Input
6. Realistic attack scenarios and edge cases

A lot of the bugs and vulnerabilities that actually impact a code are protocol-specific. Finding these protocol-specific bugs requires a thorough understanding of protocol and some creativity. Identify the protocol's pain points by brainstorming ideas and looking for edge cases. 

**Note-Taking:**

When auditing a complex or large codebase, it is important to take note of anything that appears to be wrong. Utilize some notetaking software like notepad, notion, or Evernote.

VScode Extension [Inline Bookmarks](https://marketplace.visualstudio.com/items?itemName=tintinweb.vscode-inline-bookmarks) can also assist you with the process. While reading the code, we can add audit tags wherever we find bugs or suspect a vulnerability. We can get back to it later. 

![https://user-images.githubusercontent.com/2865694/69681775-67803c80-10af-11ea-8e99-c79caf7781a5.gif](https://user-images.githubusercontent.com/2865694/69681775-67803c80-10af-11ea-8e99-c79caf7781a5.gif)

## **Step 4: Write POCs**

A POC is a demonstration of the feasibility and viability of an idea, and in the context of smart contract auditing, it serves to validate if the vulnerability is valid. Now that we found some vulnerabilities, We can write some PoC tests using frameworks like foundry, hardhat, or brownie. Below are a few ways to write PoC for our findings:

1. **Unit Test**
2. **Exploit on a Fork**
3. **Simulation**

It's critical to provide sufficient comments throughout each PoC, both for our own understanding and that of others. 

## **Step 5: Report Writing**

A good report should contain:

1. **Summary of the vulnerability**: A clear and concise description of the vulnerability.
2. **Impact**: This section is where Auditors provide a detailed breakdown of possible losses or damage to the protocol.
3. **Assigning Severity:** Severity can be classified as high, medium, low, or informational depending on the impact, likelihood, and other risk factors. 
4. **Proof of concept**:  A valid PoC might be an attack script in Hardhat/Foundry test file that can trigger the exploit or any code that manages to somehow exploit the project’s vulnerability.
5. **Mitigation steps**: In this section, the auditor should provide a recommendation on how to mitigate the vulnerability. This will be beneficial for the project, making it easier to resolve the issue.
6. **Reference [Optional]**: Any external reference links related to the vulnerability.

## Alpha Tips: How can you improve?

1. Read Audit Reports, particularly those of Code4rena and Sherlock. Gain a deeper understanding of their contents to further your knowledge.
2. Not only read and understand the smart contract's vulnerabilities but also try to reproduce the bug using Foundry/Hardhat. [DeFiVulnLabs](https://github.com/SunWeb3Sec/DeFiVulnLabs) can be a helpful resource for reproducing the bug using Foundry.
3. Solve various smart contract CTFs to gain valuable knowledge in security research. CTFs are more beneficial than other formats for learning. Solve CTFs like [Ethernaut](https://ethernaut.openzeppelin.com/), [Damn Vulnerable DeFi Application](https://www.damnvulnerabledefi.xyz/), [CTF Protocol](https://www.ctfprotocol.com/), [QuillCTF](https://quillctf.super.site/), [Paradigm CTF](https://github.com/paradigmxyz/paradigm-ctf-2021), etc.
4. Read BugFix Reports from Immunefi and Hack Analysis of Recent hacks. Try to reproduce the exploit locally. [DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs) can be a helpful resource for Reproducing DeFi hack incidents using Foundry. 
5. Taking notes while learning is an important habit to cultivate. It can help you retain information better and make it easier to recall important concepts.  Make your own notes while learning anything. Personally, I use Notion to keep a track of my everyday learnings. 
6. Stay informed by getting involved in the community. Some of the top Discord servers to keep up to date are [Spearbit](https://discord.com/invite/spearbit23), [DeFiHackLabs](https://discord.gg/HtqdYn2ECa), [Secureum](https://discord.com/invite/vGebCTSfNx), [Immunefi](https://discord.com/invite/immunefi), [Blockchain Pentesting](https://discord.com/invite/5JZERC5Vxs), etc.
7. Understand financial and mathematical concepts. Some Vulnerabilities often require a strong understanding of finance or complex mathematical calculations. Having a mastery of these skills will give you an edge in the competition.
8. Finally, take care of yourself. Audits demand a high level of concentration and mental acuity. You won't be able to deliver great audits without adequate sleep and nutrition.

### **Additional Resources**

****[Guardian - Solidity Lab](https://lab.guardianaudits.com/)****

[**Auditing Mindmap**](https://github.com/Quillhash/Smart-contract-Auditing-Methodology-mindmap)

****[Initiation to Audits](https://www.youtube.com/watch?v=3xUHvx7IkfM)****

[**How to become a Smart contract Auditor**](https://cmichel.io/how-to-become-a-smart-contract-auditor/)

[**Web3 Security Library**](https://github.com/immunefi-team/Web3-Security-Library)

**[Smart Contract Auditing Heuristics](https://github.com/OpenCoreCH/smart-contract-auditing-heuristics)**

[**DeFi Hack Labs**](https://github.com/SunWeb3Sec/DeFiHackLabs)

[**3 Ways to write PoC**](https://www.joranhonig.nl/3-ways-to-write-a-proof-of-concept/)
