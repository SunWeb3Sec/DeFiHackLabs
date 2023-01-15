# Lesson 1: Blockchain dark forest selfguard handbook

Author: [SlowMist](https://twitter.com/SlowMist_Team)

## Blackboard

Blockchain is a great invention that brings about a change in production relations and solves the problem of trust to some degree. Specifically, blockchain creates many "trust" scenarios without the need for centralization and third parties, such as immutability, execution as agreed, and prevention of repudiation. However, the reality is cruel. There are many misunderstandings about blockchain, and the bad guys will use these misunderstandings to exploit a loophole and steal money from people, causing a lot of financial losses. Today, the crypto world has already become a dark forest.

Based on this, [Cos](https://twitter.com/evilcos), the founder of SlowMist, outputs the “Blockchain dark forest selfguard handbook”.


<div align=center>
<img src="https://user-images.githubusercontent.com/107821372/212235792-09f72df1-2bcd-41c7-80a0-1500fd8d50a3.png" alt="Cover" width="80%"/>
</div>


This handbook (current V1 Beta) is about 37,000 words. Due to space limitations, only the key directory structures in the handbook are listed here. The full content is available at:

[https://github.com/slowmist/Blockchain-dark-forest-selfguard-handbook](https://github.com/slowmist/Blockchain-dark-forest-selfguard-handbook/blob/main/README.md)

We chose the GitHub platform as the primary release location for this handbook because it is convenient for collaboration and viewing historical update records. You can Watch, Fork and Star, and of course, we hope you can contribute.

Ok, the introductory reading begins…

## A Diagram
No matter who you are - if you are a cryptocurrency holder or you want to jump into the crypto world in the future, this handbook will help you a lot. You should read this handbook closely and apply its teachings in real life. Additionally, understanding this handbook completely requires some background knowledge. However, please do not worry. As for beginners, do not be afraid of the knowledge barriers which can be overcome. 

Please remember the following two security rules to survive the blockchain dark forest.
1. Zero Trust: To make it simple, stay skeptical, and always stay so.
2. Continuous Security Validation: To trust something, you have to validate what you doubt, and make validating a habit.

## Key Contents
<div align=center>
<img src="https://user-images.githubusercontent.com/107821372/212235985-906c9e23-e69d-4a8a-9be0-ff2d2de66ee7.png" alt="Cover" width="80%"/>
</div>

### Create A Wallet
* #### Download
  1. Find the correct official website
      * using Google
      * using well-known official websites, such as CoinMarketCap
      * asking trusted people and friends
  2. Download and Install the application. If it is 
      * a PC wallet, it is highly recommended to verify whether the link has been tampered with before installation.
      * a browser extension wallet, the only thing you have to pay attention to is the download number and rating in the Chrome web store. 
      * a mobile wallet, it is similar to the browser extension wallet.
      * a hardware wallet, it is highly recommended to buy it from the official website. Once you receive the wallet, you should also pay attention to whether the downloaded application has been tampered with or not.
      * a web wallet, we highly recommend not to use it. 

* #### Mnemonic Phrase
  * When creating a wallet, your seed phrase is vulnerable. Please be aware that you are not surrounded by people or webcams or anything else that can steal your seed phrase. Also, please pay attention to whether the seed phrase is randomly generated.

* #### Keyless
  * Keyless into two major scenarios (for ease of explanation. Such division is not industry standard)
      * Custodial: Examples are centralized exchange and wallet, where users only need to register accounts and do not own the private key. Their security is completely dependent on these centralized platforms.
      * Non-Custodial: The user has a private key-like control power, which is not an actual private key (or seed phrase).
      * Advantages and disadvantages of the MPC-based Keyless solution

### Back up your wallet
* #### Mnemonic Phrase / Private Key
  1. Plain Text: Based on 12 English words
  2. With Password: The seed phrase is used to derive a series of private keys, public keys, and corresponding addresses. 
  3. Multi-signature: As the name suggests, it requires signatures from multiple people to access wallets. It's very flexible as you can set your own rules.
  4. Shamir's Secret Sharing, or SSS for short: SSS breaks down the seed into multiple shares (normally, each share contains 20 words). To recover the wallet, a specified number of shares has to be collected and used.

* #### Encryption
  1. Multiple backups
      * Cloud: Google/Apple/Microsoft, combined with GPG/1Password, etc.
      * Paper: Many hardware wallets come with several high-quality paper cards on which you can write down your mnemonic phrases (in plaintext, SSS, etc.).
      * Device: Computer/iPad/iPhone/mobile hard disk/U disk, etc.
      * Brain: Pay attention to two risks, firstly, memory fades away as time goes on and could cause confusion; the other risk is that you may have an accident. I will stop here and let you explore more.
  2. Encryption
      * According to the security principle of "continuous verification", your encryption and backup methods, whether excessive or not, must be verified continuously, both regularly as well as randomly. 
      * The verification frequency depends on your memory and you do not have to complete the whole process. As long as the process is correct, partial verification also works.
      * It is also necessary to pay attention to the confidentiality and security of the authentication process.

### How to use your wallet
* #### AML
  1. Freeze on the chain
  2. To better avoid AML issues, always choose platforms and individuals with a good reputation as your counterparty
* #### Cold Wallet
  1. How to use a cold wallet
      * Receive cryptocurrency: A cold wallet could provide an excellent experience by working with a Watch-only wallet, such as imToken, Trust Wallet, etc. 
      * Send cryptocurrency: QRCode/USB/Bluetooth
  2. Risks of cold wallets
      * The user interaction security mechanism of "What you see is what you sign" is missing.
      * Lack of relevant background knowledge of the user.
* #### Hot Wallet
  1. Interact with DApps (DeFi, NFT, GameFi, etc.)
  2. Several ways of doing evil
      * When the wallet is running, the malicious code packages and uploads the relevant secret phrase directly into the hacker-controlled server.
      * When the wallet is running and the user initiates a transfer, information such as the target address and amount is secretly replaced in the wallet backend, and it is difficult for the user to notice.
      * Corrupting the random number entropy values associated with the generation of secret phrases, which makes them relatively easy to decipher. 
  3. What is DeFi Security
      * Smart Contract Security
      * Blockchain Foundation Security
      * Frontend Security
      * Communication Security
      * Human Security
      * Financial Security
      * Compliance Security
  4. NFT Security
      * Metadata Security
      * Signature Security
  5. BE CAREFUL With Signing!
      * What you see is what you sign
      * Several well-known NFT theft incidents of OpenSea
      * Canceling the authorization/approval
      * Counter-intuitive Signatures Requests
      * Some Advanced Attacking Methodologies
      * Targeted phishing
      * Widespread phishing
      * Combining XSS, CSRF, Reverse Proxy, and other techniques
### Traditional Privacy Protection
* ####  Operation System
  1. Pay close attention to system updates, and apply them asap when available.
  2. You will have eliminated most of the risks if you don't download and install programs recklessly.
  3. The disk encryption should be turned on for important computers.
* ####  Mobile phone
  1. Do not jailbreak/root your phone, it's unnecessary unless you are doing relevant security research you are doing it for pirated software it depends on how well you can master the skill.
  2. Don't download apps from unofficial app stores.
  3. Don't do it unless you know what you are doing. Not to mention there are even many fake apps in official app stores.
  4. The prerequisite of utilizing the official Cloud synchronization function, is that you have to make sure your account is secure, otherwise if the Cloud account gets compromised, so will the mobile phone.
* ####  Network
  * Don't connect to unfamiliar Wi-Fi networks unless the more popular & secure 4G/5G network is not available or not stable.
* ####  Browsers
  1. Update as quickly as possible, don't take chances.
  2. Don't use an extension if not necessary. If you do, make your decisions based on user reviews, the number of users, maintaining the company, etc, and pay attention to the permission it asks for. Make sure you get the extension from your browser's official app store.
  3. Multiple browsers can be used in parallel, and it is strongly recommended that you perform important operations in one browser, and use another browser for more routine, less important operations.
  4. Here are some well-known privacy focused extensions (such as uBlock Origin, HTTPS Everywhere, ClearURLs, etc.), feel free to try them out.
* ####  Password Manager
  1. Do not ever forget your master password, and keep your account information safe, otherwise, everything will be lost.
  2. Make sure your email is secure. If your email is compromised, it might not directly compromise the sensitive information in your password manager, but bad actors can destroy it.
  3. I have verified the security of the tools I mentioned (such as 1Password), and have been closely watching the relevant security incidents, user reviews, news, etc. But I cannot guarantee that these tools are secure and that no black swan events are ever gonna happen in the future to them.
* ####  Two-Factor Authentication
  * Google Authenticator/Microsoft Authenticator etc.
* ####  Email
  1. Safe and Well known: Gmail/Outlook/QQ email etc.
  2. Privacy: ProtonMail/Tutanota
* ####  SIM Card
  1. SIM card attacks
  2. Enable a well-known 2FA solution and the SIM card password (PIN code)
* #### Segregation
  1. If your password security practice is good, when one of your accounts gets hacked, the same password will not compromise other accounts.
  2. If your cryptocurrency is not stored under one set of mnemonic seeds, you will not lose everything if you ever step into a trap.
  3. If your computer is infected, luckily this is just a computer used for casual activities, and there is nothing important in there So you do not have to panic, as reinstalling the computer would solve most of the problems. If you are good at using virtual machines, things are even better, as you can just restore the snapshot. Good virtual machine tools are VMware and Parallels.
  4. To summarize, you can have at least two accounts, two tools, two devices, etc. It is not impossible to completely create an independent virtual identity after you are familiar with it.
* #### Security of Human Nature
  1. Telegram/Discord
  2. "Official" phishing
  3. Web3 Privacy Issues

* #### What to do When You get hacked
  1. Stop Loss First
  2. Protect The Scene
  3. Root Cause Analysis
  4. Source Tracing
  5. Conclusion of Cases

## Summary

Once you have finished reading this handbook, you must practice, become proficient and draw inferences. When you have your discovery or experience afterward, I hope you will contribute. If you feel there is sensitive information you can mask them out, or anonymize the information.

Then, thanks to the global maturity of security and privacy-related legislation and enforcement; thanks to the efforts of all the pioneering cryptographers, engineers, ethical hackers, and all those involved in the creation of a better world, which includes Satoshi Nakamoto.

Finally, thanks to the contributors, this list will be continuously updated and I hope you can contact me if there are any ideas for this handbook.

Welcome to read and analyze the full version :)

[https://github.com/slowmist/Blockchain-dark-forest-selfguard-handbook](https://github.com/slowmist/Blockchain-dark-forest-selfguard-handbook/blob/main/README.md)


