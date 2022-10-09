# DeFi Hacks Reproduce - Foundry
**Reproduce DeFi hack incidents using Foundry.**

87 incidents included.

This repo is only for the educational purpose.

Let's make Web3 secure! Join [Discord](https://discord.gg/Fjyngakf3h)

## Getting Started

* Follow the [instructions](https://book.getfoundry.sh/getting-started/installation.html) to install [Foundry](https://github.com/foundry-rs/foundry).

* Clone and install dependencies:```git submodule update --init --recursive```

## List of DeFi Hacks & Exploits

[20221002 Transit Swap](#20221002-transit-swap---incorrect-owner-address-validation)

[20221001 RL](#20221001-RL-Token---Incorrect-Reward-calculation)

[20221001 Thunder Brawl](#20221001-thunder-brawl---reentrancy)

[20220929 BXH](#20220928-bxh---flashloan--price-oracle-manipulation)

[20220928 MEVBOT Badc0de](#20220928-MEVBOT---Badc0de)

[20220923 RADT-DAO](#20220923-RADT-DAO---pair-manipulate)

[20220913 MevBot Private TX](#20220913-mevbot-private-tx)

[20220910 DPC](#20220910-dpc---Incorrect-Reward-calculation)

[20220909 YYDS](#20220909-YYDS---pair-manipulate)

[20220908 NewFreeDAO](#20220908-newfreedao---flashloans-attack)

[20220908 Ragnarok Online Invasion](#20220908-ragnarok-online-invasion---broken-access-control)

[20220906 NXUSD](#20220906-NXUSD---flashloan-price-oracle-manipulation)

[20220905 ZoomproFinance](#20220905-zoomprofinance---flashloans--price-manipulation)

[20220902 ShadowFi](#20220902-shadowfi---access-control)

[20220902 Bad Guys by RPF](#20220902-bad-guys-by-rpf---business-logic-flaw--missing-check-for-number-of-nft-to-mint)

[20220824 LuckeyTiger NFT](#20220824-luckeytiger-nft---predicting-random-numbers)

[20220810 XSTABLE Protocol](#20220810-xstable-protocol---incorrect-logic-check)

[20220807 EGD Finance](#20220807-egd-finance---flashloans--price-manipulation)

[20220802 Nomad Bridge](#20220802-nomad-bridge---business-logic-flaw--incorrect-acceptable-merkle-root-checks)

[20220801 Reaper Farm](#20220801-reaper-farm---business-logic-flaw--lack-of-access-control-mechanism)

[20220725 LPC](#20220725-lpc---business-logic-flaw--incorrect-recipient-balance-check)

[20220713 Audius](#20220723-audius---storage-collision--malicious-proposal)

[20220713 SpaceGodzilla](#20220713-spacegodzilla---flashloans--price-manipulation)

[20220710 Omni NFT](#20220710-omni-nft---reentrancy)

[20220706 FlippazOne NFT](#20220706-flippazone-nft----accesscontrol)

[20220701 Quixotic - Optimism NFT Marketplace](#20220701-quixotic---optimism-nft-marketplace)

[20220626 XCarnival](#20220626-xcarnival---infinite-number-of-loans)

[20220624 Harmony's Horizon Bridge](#20220624-harmonys-horizon-bridge---private-key-compromised)

[20220618 SNOOD](#20220618-snood---miscalculation-on-_spendallowance)

[20220616 InverseFinance](#20220616-inversefinance---flashloan--price-oracle-manipulation)

[20220608 GYMNetwork](#20220608-gymnetwork---accesscontrol)

[20220608 Optimism - Wintermute](#20220608-optimism---wintermute)

[20220606 Discover](#20220606-discover---flashloan--price-oracle-manipulation)

[20220529 NOVO Protocol](#20220529-novo-protocol---flashloan--price-oracle-manipulation)

[20220517 ApeCoin](#20220517-apecoin-ape---flashloan)

[20220508 Fortress Loans](#20220508-fortress-loans---malicious-proposal--price-oracle-manipulation)

[20220430 Rari Capital/Fei Protocol](#20220430-rari-capitalfei-protocol---flashloan-attack--reentrancy)

[20220428 DEUS DAO](#20220428-deus-dao---flashloan--price-oracle-manipulation)

[20220424 Wiener DOGE](#20220424-wiener-doge---flashloan)

[20220423 Akutar NFT](#20220423-akutar-nft---denial-of-service)

[20220421 Zeed Finance](#20220421-zeed-finance)

[20220416 BeanstalkFarms](#20220416-beanstalkfarms---dao--flashloan)

[20220415 Rikkei Finance](#20220415-rikkei-finance---accesscontrol--price-oracle-manipulation)

[20220412 ElephantMoney](#20220412-elephantmoney---flashloan--price-oracle-manipulation)

[20220409 GYMNetwork](#20220409-gymnetwork)

[20220329 Ronin Network](#20220329-ronin-network---Bridge)

[20220329 Redacted Cartel](#20220329-redacted-cartel---custom-approval-logic)

[20220327 Revest Finance](#20220327-revest-finance---reentrancy)

[20220326 Auctus](#20220326-auctus)

[20220322 CompoundTUSDSweepTokenBypass](#20220322-compoundtusdsweeptokenbypass)

[20220321 OneRing Finance](#20220321-onering-finance---flashloan--price-oracle-manipulation)

[20220320 LI.FI](#20220320-Li.Fi---bridges)

[20220320 Umbrella Network](#20220320-umbrella-network---underflow)

[20220315 Hundred Finance](#20220313-hundred-finance---erc667-reentrancy)

[20220313 Paraluni](#20220313-paraluni---flashloan--reentrancy)

[20220309 Fantasm Finance](#20220309-fantasm-finance)

[20220305 Bacon Protocol](#20220305-bacon-protocol---reentrancy)

[20220303 TreasureDAO](#20220303-treasuredao---zero-fee)

[20220214 BuildFinance - DAO](#20220214-buildfinance---dao)

[20220208 Sandbox LAND](#20220208-sandbox-land---access-control)

[20220206 Meter](#20220206-Meter---bridge)

[20220128 Qubit Finance](#20220128-qubit-finance---bridge)

[20220118 Multichain (Anyswap)](#20220118-multichain-anyswap---insufficient-token-validation)

[20211221 Visor Finance](#20211221-visor-finance---reentrancy)

[20211218 Grim Finance](#20211218-grim-finance---flashloan--reentrancy)

[20211130 MonoX Finance](#20211130-monox-finance---price-manipulation)

[20210916 SushiSwap Miso](#20210916-sushiswap-miso)

[20210915 Nimbus Platform](#20210915-nimbus-platform)

[20210915 NowSwap Platform](#20210915-nowswap-platform)

[20210912 ZABU Finance](#20210912-ZABU-Finance---Deflationary-token-uncompatible)

[20210903 DAO Maker](#20210903-dao-maker---bad-access-controal)

[20210830 Cream Finance](#20210830-cream-finance---flashloan-attack--reentrancy)

[20210811 Poly Network](#20210811-poly-network---bridge-getting-around-modifier-through-cross-chain-message)

[20210817 XSURGE](#20210817-xsurge---flashloan-attack--reentrancy)

[20210710 Chainswap](#20210710-chainswap---bridge-logic-flaw)

[20210702 Chainswap](#20210702-chainswap---bridge-logic-flaw)

[20210628 SafeDollar](#20210628-safedollar---deflationary-token-uncompatible)

[20210622 Eleven Finance](#20210622-eleven-finance---doesnt-burn-shares)

[20210607 88mph NFT](#20210607-88mph-nft---access-control)

[20210603 PancakeHunny](#20210603-pancakehunny---incorrect-calculation)

[20210519 PancakeBunny](#20210519-pancakebunny---price-oracle-manipulation)

[20210308 DODO](#20210308-dodo---flashloan-attack)

[20201229 Cover Protocol](#20201229-cover-protocol)

[20201121 Pickle Finance](#20201121-pickle-finance)

[20201026 Harvest Finance](#20201026-harvest-finance---flashloan-attack)

[20171106 Parity - 'Accidentally Killed It'](#20171106-parity---accidentally-killed-it)

### Transaction debugging tools
[Phalcon](https://phalcon.blocksec.com/) | [Tx.viewer](https://tx.eth.samczsun.com/) | [Ethtx](https://ethtx.info/) |  [Tenderly](https://dashboard.tenderly.co/explorer)

### Ethereum Signature Database
[4byte](https://www.4byte.directory/) | [sig.eth](https://sig.eth.samczsun.com/) | [etherface](https://www.etherface.io/hash)

### Useful tools
[ABI to interface](https://gnidan.github.io/abi-to-sol/) | [Get ABI for unverified contracts](https://abi.w1nt3r.xyz/) | [ETH Calldata Decoder](https://apoorvlathey.com/eth-calldata-decoder/)

### 20221002 Transit Swap - Incorrect owner address validation

Testing
```sh
forge test --contracts src/test/TransitSwap_exp.sol -vv
```

#### Contract

[TransitSwap_exp.sol](src/test/TransitSwap_exp.sol)

#### Link reference

https://twitter.com/TransitFinance/status/1576463550557483008

https://bscscan.com/tx/0x181a7882aac0eab1036eedba25bc95a16e10f61b5df2e99d240a16c334b9b189

### 20221001 RL Token - Incorrect Reward calculation

Testing
```sh
forge test --contracts src/test/RL_exp.sol -vv
```

#### Contract

[RL_exp.sol](src/test/RL_exp.sol)

#### Link reference

https://twitter.com/CertiKAlert/status/1576195971003858944


### 20221001 Thunder Brawl - Reentrancy

Testing
```sh
forge test --contracts src/test/THB_exp.sol -vv
```

#### Contract

[THB_exp.sol](src/test/THB_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1575890733373849601

### 20220928 BXH - Flashloan & Price Oracle Manipulation
### Lost: $40,305

Testing
```sh
forge test --contracts src/test/BXH_exp.sol -vv
```

#### Contract

[BXH_exp.sol](src/test/BXH_exp.sol)

#### Link reference

https://www.jinse.com/lives/319392.html

https://bscscan.com/tx/0xa13c8c7a0c97093dba3096c88044273c29cebeee109e23622cd412dcca8f50f4

### 20220910 DPC - Incorrect Reward calculation
#### Lost: $103,755

Testing
```sh
forge test --contracts ./src/test/DPC_exp.sol -vvv 
```
#### Contract

[DPC_exp.sol](src/test/DPC_exp.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1568429355919089664

https://bscscan.com/address/0x2109bbecB0a563e204985524Dd3DB2F6254AB419

https://learnblockchain.cn/article/4733


### 20220928 MEVBOT - Badc0de

### Lost: $1,469,700

An anonymous attacker noticed a flaw in the bots arbitrage contract code, and stole not only the recently acquired 800 ETH, but the entire 1,101 ETH in 0xbad’s wallet.

Testing
```sh
forge test --contracts ./src/test/MEVbadc0de_exp.sol -vvv 
```

#### Contract

[MEVbadc0de_exp.sol](src/test/MEVbadc0de_exp.sol)

#### Link reference

https://rekt.news/ripmevbot/

https://etherscan.io/tx/0x59ddcf5ee5c687af2cbf291c3ac63bf28316a8ecbb621d9f62d07fa8a5b8ef4e

### 20220923 RADT-DAO - pair manipulate

Testing
```sh
forge test --contracts ./src/test/RADT_exp.sol -vvv 
```
#### Contract

[RADT_exp.sol](src/test/RADT_exp.sol)

#### Link reference
https://twitter.com/BlockSecTeam/status/1573252869322846209

https://bscscan.com/tx/0xd692f71de2768017390395db815d34033013136c378177c05d0d46ef3b6f0897

### 20220913 MevBot private tx 

Testing
```sh
forge test --contracts ./src/test/BNB48MEVBot_exp.sol -vvv 
```
#### Contract

[BNB48MEVBot_exp.sol](src/test/BNB48MEVBot_exp.sol)

#### Link reference

https://blocksecteam.medium.com/the-two-sides-of-the-private-tx-service-on-binance-smart-chain-a76917c3ce51

https://bscscan.com/tx/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2


### 20220909 YYDS - pair manipulate
#### Lost: 742,286.27 BUSD

Testing
```sh
forge test --contracts ./src/test/Yyds_exp.sol -vvv 
```
#### Contract

[Yyds_exp.sol](src/test/Yyds_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1567928377432051713

https://bscscan.com/tx/0x04a1f0d1694242515ecb14faa71053901f11a1286cd21c27fe5542f9eeb62356

### 20220908 Ragnarok Online Invasion - Broken Access Control
#### Lost: 157.98 BNB (~44,000 US$)

Testing
```sh
forge test --contracts ./src/test/ROI_exp.sol -vvv 
```
#### Contract

[ROI_exp.sol](src/test/ROI_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1567746825616236544

https://twitter.com/CertiKAlert/status/1567754904663429123

https://www.panewslab.com/zh_hk/articledetails/mbzalpdi.html

https://medium.com/quillhash/decoding-ragnarok-online-invasion-44k-exploit-quillaudits-261b7e23b55

### 20220908 NewFreeDAO - Flashloans Attack
#### Lost: 4,481 BNB (~125M US$)

Testing
```sh
forge test --contracts ./src/test/NewFreeDAO_exp.sol -vvv 
```
#### Contract

[NewFreeDAO_exp.sol](src/test/NewFreeDAO_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1567710274244825088

https://twitter.com/BeosinAlert/status/1567757251024396288

https://twitter.com/BlockSecTeam/status/1567706201277988866

https://twitter.com/SlowMist_Team/status/1567854876633309186

### 20220906 NXUSD - flashloan price oracle manipulation
#### Lost 50,000 USD

Testing
```sh
forge test --contracts ./src/test/NXUSD_exp.sol -vvv 
```
#### Contract

[NXUSD_exp.sol](src/test/NXUSD_exp.sol)

#### Link reference

https://medium.com/nereus-protocol/post-mortem-flash-loan-exploit-in-single-nxusd-market-343fa32f0c6

### 20220905 ZoomproFinance - Flashloans & Price Manipulation
#### Lost: 61,160 USDT

Testing
```sh
forge test --contracts ./src/test/ZoomproFinance_exp.sol -vvv 
```
#### Contract

[ZoomproFinance_exp.sol](src/test/ZoomproFinance_exp.sol)

#### Link reference

https://twitter.com/blocksecteam/status/1567027459207606273

### 20220902 ShadowFi - Access Control
#### Lost: 1,078 BNB

Anyone can burn $SDF

Testing
```sh
forge test --contracts ./src/test/Shadowfi_exp.sol -vvv 
```
#### Contract

[Shadowfi_exp.sol](src/test/Shadowfi_exp.sol)

#### Link reference

https://twitter.com/PeckShieldAlert/status/1565549688509861888

### 20220902 Bad Guys by RPF - Business Logic Flaw : Missing Check For Number of NFT to Mint
#### Lost: Bad Guys by RPF(400 NFTs)

Testing
```sh
forge test --contracts ./src/test/BadGuysbyRPF_exp.sol -vvv
```
#### Contract

[BadGuysbyRPF_exp.sol](src/test/BadGuysbyRPF_exp.sol)

#### Link reference

https://twitter.com/RugDoctorApe/status/1565739119606890498

https://etherscan.io/tx/0x27e64a8215ae1528245c912bcca09883fdd7cce69249bd5d5d1c0eecf5297b96

### 20220824 LuckeyTiger NFT - Predicting Random Numbers

Testing
```sh
forge test --contracts ./src/test/LuckyTiger_exp -vvv 
forge script script/LuckyTiger_s_exp.sol:luckyHack --fork-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY --broadcast
```
#### Contract

[LuckyTiger_exp.sol](src/test/LuckyTiger_exp.sol) | [LuckyTiger_s_exp.sol](/script/LuckyTiger_s_exp.sol)

#### Link reference

https://etherscan.io/tx/0x804ff3801542bff435a5d733f4d8a93a535d73d0de0f843fd979756a7eab26af

### 20220810 XSTABLE Protocol - Incorrect Logic Check
Testing
```sh
forge test --contracts ./src/test/XST.exp.sol -vvv 
```
#### Contract

[XST.exp.sol](src/test/XST.exp.sol)
[XST02_exp.sol](src/test/XST02_exp.sol)

#### Link reference

https://mobile.twitter.com/BlockSecTeam/status/1557195012042936320

### 20220807 EGD Finance - Flashloans & Price Manipulation
#### Lost: 36,044 USDT

Testing
```sh
forge test --contracts ./src/test/EGD-Finance.exp.sol -vvv 
```
#### Contract

[EGD-Finance.exp.sol](src/test/EGD-Finance.exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1556483435388350464

https://twitter.com/PeckShieldAlert/status/1556486817406283776

### 20220802 Nomad Bridge - Business Logic Flaw : Incorrect acceptable merkle-root checks
#### Lost: Multiple ERC-20 Tokens (~152M US$)

Testing
```sh
forge test --contracts ./src/test/NomadBridge.exp.sol -vvv 
```
#### Contract

[NomadBridge.exp.sol](src/test/NomadBridge.exp.sol)

#### Link reference

https://twitter.com/samczsun/status/1554252024723546112

https://www.certik.com/resources/blog/28fMavD63CpZJOKOjb9DX3-nomad-bridge-exploit-incident-analysis

https://blog.coinbase.com/nomad-bridge-incident-analysis-899b425b0f34

### 20220801 Reaper Farm - Business Logic Flaw : Lack of access control mechanism
#### Lost: Multiple ERC-20 Tokens (~1.7M US$)
Testing
```sh
forge test --contracts ./src/test/ReaperFarm.exp.sol -vvv 
```
#### Contract

[ReaperFarm.exp.sol](src/test/ReaperFarm.exp.sol)

#### Link reference

https://twitter.com/Reaper_Farm/status/1554500909740302337

https://twitter.com/BeosinAlert/status/1554476940593340421

### 20220725 LPC - Business Logic Flaw : Incorrect recipient balance check, did not check sender!=recipient in transfer
#### Lost: 178 BNB (~45,715 US$)

Testing
```sh
forge test --contracts ./src/test/LPC.exp.sol -vvv 
```
#### Contract

[LPC.exp.sol](src/test/LPC.exp.sol)

#### Link reference

https://www.panewslab.com/zh_hk/articledetails/uwv4sma2.html

https://twitter.com/BeosinAlert/status/1551535854681718784

### 20220723 Audius - Storage Collision & Malicious Proposal, storage collision of proxy and implementation contracts
#### Lost: 704 ETH (~1.08M US$)

Testing
```sh
forge test --contracts ./src/test/Audius.exp.sol -vvv 
```
#### Contract

[Audius.exp.sol](src/test/Audius.exp.sol)

#### Link reference
https://twitter.com/AudiusProject/status/1551000725169180672

https://twitter.com/1nf0s3cpt/status/1551050841146400768

https://blog.audius.co/article/audius-governance-takeover-post-mortem-7-23-22

### 20220713 SpaceGodzilla - Flashloans & Price Manipulation
#### Lost: 25,378 BUSD

Testing
```sh
forge test --contracts ./src/test/SpaceGodzilla.exp.sol -vvv 
```
#### Contract

[SpaceGodzilla.exp.sol](src/test/SpaceGodzilla.exp.sol)

#### Link reference
https://mobile.twitter.com/BlockSecTeam/status/1547456591900749824

https://www.panewslab.com/zh_hk/articledetails/u25j5p3kdvu9.html

https://medium.com/numen-cyber-labs/spacegodzilla-attack-event-analysis-d29a061b17e1

https://learnblockchain.cn/article/4396

https://learnblockchain.cn/article/4395  *** math behind such attack

### 20220710 Omni NFT - Reentrancy
#### Lost: $1.4M

Testing
```sh
forge test --contracts ./src/test/Omni_exp.sol -vv
```
#### Contract

[Omni_exp.sol](src/test/Omni_exp.sol)

#### Link reference
https://twitter.com/peckshield/status/1546084680138498049

https://twitter.com/SlowMist_Team/status/1546379086792388609

https://etherscan.io/tx/0x05d65e0adddc5d9ccfe6cd65be4a7899ebcb6e5ec7a39787971bcc3d6ba73996

### 20220706 FlippazOne NFT -  Access control

The ownerWithdrawAllTo() without onlyOwner can call it.

Testing
```sh
forge test --contracts ./src/test/FlippazOne.sol -vvvv
```
#### Contract

[FlippazOne.sol](src/test/FlippazOne.sol)

#### Link reference
https://twitter.com/bertcmiller/status/1544496577338826752

https://etherscan.io/tx/0x8bded20c1db5a1d5f595b15e682a95ce11d3c895d6031147fa49c4ffa5729a30


### 20220703 CREMA FINANCE faulty owner validation (solana)
#### Lost: $8.8M
The attack was made possible due to faulty owner validation on one of the protocol’s accounts storing price tick data. These data are used by Crema to calculate LP fees.

<!-- Testing
```sh
forge test --contracts ./src/test/Quixotic_exp.sol -vv
``` -->
#### Contract

[Quixotic_exp.sol](src/test/Quixotic_exp.sol)

#### Link reference
https://rekt.news/crema-finance-rekt/

https://twitter.com/Crema_Finance/status/1543638844410499073


### 20220701 Quixotic - Optimism NFT Marketplace
#### Lost: $100K
fillSellOrder function only check seller signature.

ECDSA signature combined with v r s, if recoveredAddress == sellOrder.seller; sellorder execute.

Testing 
```sh
forge test --contracts ./src/test/Quixotic_exp.sol -vv
```
#### Contract

[Quixotic_exp.sol](src/test/Quixotic_exp.sol)

#### Link reference
https://twitter.com/1nf0s3cpt/status/1542808565349777408

https://twitter.com/SlowMist_Team/status/1542795627603857409

https://optimistic.etherscan.io/tx/0x5dc519726e1236eb846271f6699e03cdd1a8fd593a2900c71cd2aabbdb7c92e6

### 20220626 XCarnival - Infinite Number of Loans
#### Lost: 3087 ETH (~$3.87M)

Testing
```sh
forge test --contracts ./src/test/XCarnival.exp.sol -vv
```
#### Contract

[XCarnival.exp.sol](src/test/XCarnival.exp.sol)

#### Link reference
https://twitter.com/XCarnival_Lab/status/1541226298399653888

https://twitter.com/peckshield/status/1541047171453034501

https://twitter.com/BlockSecTeam/status/1541070850505723905

### 20220624 Harmony's Horizon Bridge - Private key compromised
#### Lost: $100 million
Private key compromised case of Multisig wallet

Testing
```sh
forge test --contracts ./src/test/Harmony_multisig.sol -vvvv
```
#### Contract

[Harmony_multisig.sol](src/test/Harmony_multisig.sol)

#### Link reference
https://twitter.com/harmonyprotocol/status/1540110924400324608

https://twitter.com/0xIvo/status/1540165571681128448

https://twitter.com/1nf0s3cpt/status/1540139812715261952

### 20220618 SNOOD - Miscalculation on _spendAllowance

#### Lost: 104 ETH

On `_spendAllowance` function they use `_getStandardAmount` and should be `_getReflectedAmount`

Testing
```sh
forge test --contracts ./src/test/Snood_poc.t.sol -vv
```

#### Contract

[Snood_poc.t.sol](src/test/Snood_poc.t.sol)

#### Link reference
https://ethereum.stackexchange.com/questions/130472/attack-on-erc-777-smart-contract-and-uniswapv2pair-resulting-in-104-eth-liquidit

https://etherscan.io/tx/0x9a6227ef97d7ce75732645bd604ef128bb5dfbc1bfbe0966ad1cd2870d45a20e

https://ethtx.info/mainnet/0x9a6227ef97d7ce75732645bd604ef128bb5dfbc1bfbe0966ad1cd2870d45a20e/

### 20220616 InverseFinance - Flashloan & Price Oracle Manipulation
#### Lost: 53.2445 WBTC and 99,976.29 USDT

Testing
```sh
forge test --contracts ./src/test/InverseFinance_exp.sol -vv
```
#### Contract

[InverseFinance_exp.sol](src/test/InverseFinance_exp.sol)

#### Link reference
https://twitter.com/peckshield/status/1537382891230883841

https://twitter.com/SlowMist_Team/status/1537602909512376321

https://blocksecteam.medium.com/price-oracle-manipulation-attack-on-inverse-finance-a5544218ea91

https://www.certik.com/resources/blog/6LbL57WA3iMNm8zd7q111R-inverse-finance-incident-analysis

https://etherscan.io/tx/0x958236266991bc3fe3b77feaacea120f172c0708ad01c7a715b255f218f9313c

### 20220608 GYMNetwork - Access control
#### Lost: $2.1 million

Testing
```sh
forge test --contracts ./src/test/Gym_2_exp.sol -vv
```
#### Contract

[Gym_2_exp.sol](src/test/Gym_2_exp.sol)

#### Link reference
https://twitter.com/peckshield/status/1534423219607719936

https://twitter.com/1nf0s3cpt/status/1534464698069884929

https://www.jinse.com/news/blockchain/1658455.html

### 20220608 Optimism - Wintermute - Signature replay
#### Lost: 20 million Optimism (OP) tokens returned 17 million of them

Testing
```sh
forge test --contracts ./src/test/Optimism_exp.sol -vv
```
#### Contract

[Optimism_exp.sol](src/test/Optimism_exp.sol)

#### Link reference
https://inspexco.medium.com/how-20-million-op-was-stolen-from-the-multisig-wallet-not-yet-owned-by-wintermute-3f6c75db740a

https://optimistic.etherscan.io/tx/0x75a42f240d229518979199f56cd7c82e4fc1f1a20ad9a4864c635354b4a34261

https://optimistic.etherscan.io/tx/0x00a3da68f0f6a69cb067f09c3f7e741a01636cbc27a84c603b468f65271d415b

### 20220606 Discover - Flashloan & Price Oracle Manipulation
#### Lost: 49 BNB

Testing
```sh
forge test --contracts ./src/test/Discover_exp.sol -vv
```
#### Contract

[Discover_exp.sol](src/test/Discover_exp.sol)

#### Link reference
https://www.twitter.com/BeosinAlert/status/1533734518623899648

https://www.anquanke.com/post/id/274003

https://bscscan.com/tx/0x8a33a1f8c7af372a9c81ede9e442114f0aabb537e5c3a22c0fd7231c4820f1e9

https://bscscan.com/tx/0x1dd4989052f69cd388f4dfbeb1690a3f3a323ebb73df816e5ef2466dc98fa4a4


### 20220529 NOVO Protocol - Flashloan & Price Oracle Manipulation
#### Lost: 279 BNB

Testing
```sh
forge test --contracts ./src/test/Novo_exp.sol -vvv
```
#### Contract

[Novo_exp.sol](src/test/Novo_exp.sol)

#### Link reference
https://www.panewslab.com/zh_hk/articledetails/f40t9xb4.html

https://bscscan.com/tx/0xc346adf14e5082e6df5aeae650f3d7f606d7e08247c2b856510766b4dfcdc57f

https://bscscan.com/address/0xa0787daad6062349f63b7c228cbfd5d8a3db08f1#code

### 20220517 ApeCoin (APE) - Flashloan
#### Lost: $1.1 million
buys vault token -> redeems NFTs -> claims airdrop of 60k APE -> re-supply's the pool
Testing
```sh
forge test --contracts ./src/test/Bayc_apecoin_exp -vvv
```
#### Contract

[Bayc_apecoin_exp.sol](src/test/Bayc_apecoin_exp.sol)

#### Link reference
https://etherscan.io/tx/0xeb8c3bebed11e2e4fcd30cbfc2fb3c55c4ca166003c7f7d319e78eaab9747098

https://news.coincu.com/73892-the-flashloan-attack-on-the-ape-airdrop-to-claim-1-1-million-of-ape-tokens/

### 20220508 Fortress Loans - Malicious Proposal & Price Oracle Manipulation
#### Lost: 1,048.1 ETH + 400,000 DAI (~$3.00M)

Testing
```sh
forge test --contracts ./src/test/FortressLoans.exp.sol -vvv
```
#### Contract

[FortressLoans.exp.sol](src/test/FortressLoans.exp.sol)

#### Link reference
https://twitter.com/Fortressloans/status/1523495202115051520

https://twitter.com/PeckShieldAlert/status/1523489670323404800

https://twitter.com/BlockSecTeam/status/1523530484877209600

https://www.certik.com/resources/blog/k6eZOpnK5Kdde7RfHBZgw-fortress-loans-exploit


### 20220430 Rari Capital/Fei Protocol - Flashloan Attack + Reentrancy
#### Lost: $80 million

Testing
```sh
forge test --contracts ./src/test/Rari_exp.t.sol -vv
```
#### Contract

[Rari_exp.t.sol](src/test/Rari_exp.t.sol)

#### Link reference
https://certik.medium.com/fei-protocol-incident-analysis-8527440696cc

https://twitter.com/peckshield/status/1520369315698016256

https://etherscan.io/tx/0xab486012f21be741c9e674ffda227e30518e8a1e37a5f1d58d0b0d41f6e76530


### 20220424 Wiener DOGE - Flashloan
#### Lost: 78 BNB

Testing
```sh
forge test --contracts ./src/test/Wdoge_exp.sol -vvv

```
#### Contract

[Wdoge_exp.sol](src/test/Wdoge_exp.sol)

#### Link reference
https://coinyuppie.com/four-combinations-of-hackers-analysis-of-attacks-on-wiener-doge-last-kilometer-medamon-and-pidao-projects/

https://twitter.com/solid_group_1/status/1519034573354676224

https://bscscan.com/tx/0x4f2005e3815c15d1a9abd8588dd1464769a00414a6b7adcbfd75a5331d378e1d

### 20220428 DEUS DAO - Flashloan & Price Oracle Manipulation
#### Lost: $13 million

Testing
```sh
forge test --contracts ./src/test/deus_exp.sol -vv
```
#### Contract

[deus_exp.sol](src/test/deus_exp.sol)

#### Link reference
https://twitter.com/peckshield/status/1519531866109317121

https://ftmscan.com/tx/0xe374495036fac18aa5b1a497a17e70f256c4d3d416dd1408c026f3f5c70a3a9c

### 20220423 Akutar NFT - Denial of Service
#### Lost: 34M USD

Testing
```sh
forge test --contracts ./src/test/AkutarNFT_exp.sol -vv  
```
#### Contract

[AkutarNFT_exp.sol](src/test/AkutarNFT_exp.sol)

#### Link reference
https://blocksecteam.medium.com/how-akutar-nft-loses-34m-usd-60d6cb053dff

https://etherscan.io/address/0xf42c318dbfbaab0eee040279c6a2588fa01a961d#code

### 20220421 Zeed Finance - Reward distribution flaw
#### Lost: $1 million

Testing
```sh
forge test --contracts ./src/test/Zeed_exp.sol -vv
```
#### Contract

[Zeed_exp.sol](src/test/Zeed_exp.sol)

#### Link reference
https://www.cryptotimes.io/hacker-leaves-1m-to-self-destruct-after-zeed-protocol-exploit/

https://medium.com/@zeedcommunity/the-solution-for-the-yeed-lp-pool-attack-a120c53948cd

https://bscscan.com/tx/0x0507476234193a9a5c7ae2c47e4c4b833a7c3923cefc6fd7667b72f3ca3fa83a

### 20220416 BeanstalkFarms - DAO + Flashloan
#### Lost: $182 million

Testing
```sh
forge test --contracts ./src/test/Beanstalk_exp.sol -vv
```
#### Contract

[Beanstalk_exp.sol](src/test/Beanstalk_exp.sol)

#### Link reference
https://rekt.news/beanstalk-rekt/

https://medium.com/uno-re/beanstalk-farms-hacked-total-damage-is-182-million-b699dd3e5c8

https://twitter.com/peckshield/status/1515680335769456640

https://etherscan.io/tx/0x68cdec0ac76454c3b0f7af0b8a3895db00adf6daaf3b50a99716858c4fa54c6f

https://etherscan.io/tx/0xcd314668aaa9bbfebaf1a0bd2b6553d01dd58899c508d4729fa7311dc5d33ad7

### 20220415 Rikkei Finance - Access control & Price Oracle Manipulation
#### Lost: $1.1 million (2671 BNB)

Testing
```sh
forge test --contracts ./src/test/Rikkei_exp.sol -vv
```
#### Contract

[Rikkei_exp.sol](src/test/Rikkei_exp.sol)

#### Link reference
https://blockmagnates.com/rikkei-finance-hack/

https://knownseclab.com/news/625e865cf1c544005a4bdaf2

https://rikkeifinance.medium.com/rikkei-finance-incident-investigation-report-b5b1745b0155

https://bscscan.com/tx/0x93a9b022df260f1953420cd3e18789e7d1e095459e36fe2eb534918ed1687492

### 20220412 ElephantMoney - Flashloan & Price Oracle Manipulation
#### Lost: $11.2 million (27,416.46 BNB)

Testing
```sh
forge test --contracts ./src/test/Elephant_Money_poc.sol -vv
```
#### Contract

[Elephant_Money_poc.sol](src/test/Elephant_Money_poc.sol)

#### Link reference
https://medium.com/elephant-money/reserve-exploit-52fd36ccc7e8

https://twitter.com/peckshield/status/1514023036596330496

https://twitter.com/BlockSecTeam/status/1513966074357698563

https://bscscan.com/tx/0xec317deb2f3efdc1dbf7ed5d3902cdf2c33ae512151646383a8cf8cbcd3d4577

### 20220409 GYMNetwork - Flashloan + token migrate flaw
#### Lost: 1,327 WBNB

Testing
```sh
forge test --contracts ./src/test/Gym_1_exp.sol -vv
```
#### Contract

[Gym_1_exp.sol](src/test/Gym_1_exp.sol)

#### Link reference
https://twitter.com/BlockSecTeam/status/1512832398643265537

https://medium.com/@Beosin_com/beosin-analysis-of-the-attack-on-gymdefi-e5a23bfd93fe

https://bscscan.com/tx/0xa5b0246f2f8d238bb56c0ddb500b04bbe0c30db650e06a41e00b6a0fff11a7e5

### 20220329 Ronin Network - Bridge
#### Lost: $624 million

Testing
```sh
forge test --contracts ./src/test/Ronin_exp.sol -vv
```
#### Contract

[Ronin_exp.sol](src/test/Ronin_exp.sol)

#### Link reference
https://rekt.news/ronin-rekt/

https://etherscan.io/tx/0xc28fad5e8d5e0ce6a2eaf67b6687be5d58113e16be590824d6cfa1a94467d0b7

https://etherscan.io/tx/0xed2c72ef1a552ddaec6dd1f5cddf0b59a8f37f82bdda5257d9c7c37db7bb9b08

### 20220329 Redacted Cartel - Custom Approval Logic

Testing
```sh
forge test --contracts ./src/test/RedactedCartel_exp.sol -vv
```
#### Contract

[RedactedCartel_exp.sol](src/test/RedactedCartel_exp.sol)

#### Link reference
https://medium.com/immunefi/redacted-cartel-custom-approval-logic-bugfix-review-9b2d039ca2c5

### 20220327 Revest Finance - Reentrancy
#### Lost: $11.2 million

Testing
```sh
forge test --contracts ./src/test/Revest_exp.sol -vv
```
#### Contract

[Revest_exp.sol](src/test/Revest_exp.sol)

#### Link reference
https://blocksecteam.medium.com/revest-finance-vulnerabilities-more-than-re-entrancy-1609957b742f

https://etherscan.io/tx/0xe0b0c2672b760bef4e2851e91c69c8c0ad135c6987bbf1f43f5846d89e691428

### 20220326 Auctus
#### Lost: $726 k

Testing
```sh
forge test --contracts ./src/test/Auctus_exp.sol -vv
```
#### Contract

[Auctus_exp.sol](src/test/Auctus_exp.sol)

#### Link reference
https://twitter.com/AuctusOptions/status/1508647849663291398?cxt=HHwWjICzpbzO5e8pAAAA

https://etherscan.io/tx/0x2e7d7e7a6eb157b98974c8687fbd848d0158d37edc1302ea08ee5ddb376befea


### 20220322 CompoundTUSDSweepTokenBypass

Testing
```sh
forge test --contracts ./src/test/CompoundTusd_exp.sol -vv
```
#### Contract

[CompoundTusd_exp.sol](src/test/CompoundTusd_exp.sol)

#### Link reference
https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/

### 20220321 OneRing Finance - Flashloan & Price Oracle Manipulation
#### Lost: $1.45 million

Testing
```sh
forge test --contracts ./src/test/OneRing_exp.sol -vv
```
#### Contract

[OneRing_exp.sol](src/test/OneRing_exp.sol)

#### Link reference
https://medium.com/oneringfinance/onering-finance-exploit-post-mortem-after-oshare-hack-602a529db99b

https://ftmscan.com/tx/0xca8dd33850e29cf138c8382e17a19e77d7331b57c7a8451648788bbb26a70145

### 20220320 Li.Fi - Bridges
#### Lost: $570K

Testing
```sh
forge test --contracts ./src/test/LiFi_exp.sol -vvvv
```
#### Contract

[LiFi_exp.sol](src/test/LiFi_exp.sol)

#### Link reference
https://blog.li.fi/20th-march-the-exploit-e9e1c5c03eb9

https://twitter.com/lifiprotocol/status/1505738407938387971

https://etherscan.io/tx/0x4b4143cbe7f5475029cf23d6dcbb56856366d91794426f2e33819b9b1aac4e96

#### Fix
implemented a whitelist to only allow calls to approved DEXs. 

### 20220320 Umbrella Network - Underflow

Testing
```sh
forge test --contracts ./src/test/Umbrella_exp.sol -vv
```
#### Contract

[Umbrella_exp.sol](src/test/Umbrella_exp.sol)

#### Link reference
https://medium.com/uno-re/umbrella-network-hacked-700k-lost-97285b69e8c7

https://etherscan.io/tx/0x33479bcfbc792aa0f8103ab0d7a3784788b5b0e1467c81ffbed1b7682660b4fa

### 20220313 Hundred Finance - ERC667 Reentrancy
#### Lost: $1.7 million

Testing
```sh
forge test --contracts ./src/test/HundredFinance_exp.sol -vv
```
#### Contract

[HundredFinance_exp.sol](src/test/HundredFinance_exp.sol)

#### Link reference
https://medium.com/immunefi/a-poc-of-the-hundred-finance-heist-4121f23a098

https://gnosisscan.io/tx/0x534b84f657883ddc1b66a314e8b392feb35024afdec61dfe8e7c510cfac1a098

### 20220313 Paraluni - Flashloan & Reentrancy
#### Lost: $1.7 million

Testing
```sh
forge test --contracts ./src/test/Paraluni_exp.sol -vv
```
#### Contract

[Paraluni_exp.sol](src/test/Paraluni_exp.sol)

#### Link reference
https://halborn.com/explained-the-paraluni-hack-march-2022/

https://twitter.com/peckshield/status/1502815435498176514

https://mobile.twitter.com/paraluni/status/1502951606202994694

https://zhuanlan.zhihu.com/p/517535530

https://bscscan.com/tx/0x70f367b9420ac2654a5223cc311c7f9c361736a39fd4e7dff9ed1b85bab7ad54


### 20220309 Fantasm Finance - Business logic in mint()
#### Lost: $2.6 million

Testing
```sh
forge test --contracts ./src/test/Fantasm_exp.sol -vv
```
#### Contract

[Fantasm_exp.sol](src/test/Fantasm_exp.sol)

#### Link reference
https://twitter.com/fantasm_finance/status/1501569232881995785

https://medium.com/quillhash/fantom-based-protocol-fantasm-suffers-2-6m-exploit-32de8191ccd4

https://etherscan.io/tx/0xacfcaa8e1c482148f9f2d592c78ca7a27934c7333dab31978ed0aef333a28ab6


### 20220305 Bacon Protocol - Reentrancy
#### Lost: $1 million

Testing
```sh
forge test --contracts ./src/test/Bacon_exp.sol -vv
```
#### Contract

[Bacon_exp.sol](src/test/Bacon_exp.sol)

#### Link reference
https://twitter.com/peckshield/status/1500105933128495108

https://etherscan.io/tx/0xacfcaa8e1c482148f9f2d592c78ca7a27934c7333dab31978ed0aef333a28ab6

https://etherscan.io/tx/0x7d2296bcb936aa5e2397ddf8ccba59f54a178c3901666b49291d880369dbcf31

### 20220303 TreasureDAO - Zero Fee
#### Lost: $1 million

Testing
```sh
forge test --contracts ./src/test/TreasureDAO_exp.sol -vv
```
#### Contract

[TreasureDAO_exp.sol](src/test/TreasureDAO_exp.sol)

#### Link reference
https://slowmist.medium.com/analysis-of-the-treasuredao-zero-fee-exploit-73791f4b9c14

https://arbiscan.io/tx/0x82a5ff772c186fb3f62bf9a8461aeadd8ea0904025c3330a4d247822ff34bc02

### 20220214 BuildFinance - DAO
#### Lost: $470k

Testing
```sh
forge test --contracts ./src/test/BuildF_exp.sol -vv
```
#### Contract

[BuildF_exp.sol](src/test/BuildF_exp.sol)

#### Link reference
https://twitter.com/finance_build/status/1493223190071554049

https://www.cryptotimes.io/build-finance-suffered-hostile-governance-takeover-lost-470k/

https://etherscan.io/tx/0x544e5849b71b98393f41d641683586d0b519c46a2eeac9bcb351917f40258a85

### 20220208 Sandbox LAND - Access control

Testing
```sh
forge test --contracts ./src/test/Sandbox_exp.sol -vv
```
#### Contract

[Sandbox_exp.sol](src/test/Sandbox_exp.sol)

#### Link reference
https://slowmist.medium.com/the-vulnerability-behind-the-sandbox-land-migration-2abf68933170

https://etherscan.io/tx/0x34516ee081c221d8576939f68aee71e002dd5557180d45194209d6692241f7b1


### 20220206 Meter - Bridge
#### Lost: $4.3 million

Testing
```sh
Solana TBD
forge test --contracts ./src/test/meter_exp.sol -vv
```
#### Contract

[meter_exp.sol](src/test/meter_exp.sol)

#### Link reference

https://twitter.com/ishwinder/status/1490227406824685569

https://blog.chainsafe.io/breaking-down-the-meter-io-hack-a46a389e7ae4

this does not seem to be the correct transaction though: 
https://moonriver.moonscan.io/tx/0x5a87c24d0665c8f67958099d1ad22e39a03aa08d47d00b7276b8d42294ee0591

### 20220128 Qubit Finance - Bridge address(0).safeTransferFrom() does not revert
#### Lost: $80 million

Testing
```sh
forge test --contracts ./src/test/Qubit_exp.sol -vv
```
#### Contract

[qubit_exp.sol](src/test/qubit_exp.sol)

#### Link reference
https://rekt.news/qubit-rekt/

https://medium.com/@QubitFin/protocol-exploit-report-305c34540fa3

https://etherscan.io/address/0xd01ae1a708614948b2b5e0b7ab5be6afa01325c7
https://etherscan.io/tx/0xac7292e7d0ec8ebe1c94203d190874b2aab30592327b6cc875d00f18de6f3133
https://bscscan.com/tx/0x50946e3e4ccb7d39f3512b7ecb75df66e6868b9af0eee8a7e4b61ef8a459518e

### 20220118 Multichain (Anyswap) - Insufficient Token Validation
#### Lost: $1.4 million

Testing
```sh
forge test --contracts ./src/test/Anyswap_poc.t.sol -vv
```
#### Contract

[Anyswap_poc.t.sol](src/test/Anyswap_poc.t.sol)

#### Link reference
https://medium.com/zengo/without-permit-multichains-exploit-explained-8417e8c1639b

https://twitter.com/PeckShieldAlert/status/1483363515411099651

https://etherscan.io/tx/0xe50ed602bd916fc304d53c4fed236698b71691a95774ff0aeeb74b699c6227f7


### 20211221 Visor Finance - Reentrancy
#### Lost:  $8.2 million

Testing
```sh
forge test --contracts ./src/test/Visor_exp.t.sol -vv
```
#### Contract

[Visor_exp.t.sol](src/test/Visor_exp.t.sol)

#### Link reference
https://beosin.medium.com/two-vulnerabilities-in-one-function-the-analysis-of-visor-finance-exploit-a15735e2492

https://twitter.com/GammaStrategies/status/1473306777131405314

https://etherscan.io/tx/0x69272d8c84d67d1da2f6425b339192fa472898dce936f24818fda415c1c1ff3f


### 20211218 Grim Finance - Flashloan & Reentrancy
#### Lost:  $30 million

Testing
```sh
forge test --contracts ./src/test/Grim_exp.sol -vv
```
#### Contract

[Grim_exp.sol](src/test/Grim_exp.sol)

#### Link reference
https://cointelegraph.com/news/defi-protocol-grim-finance-lost-30m-in-5x-reentrancy-hack

https://rekt.news/grim-finance-rekt/

https://ftmscan.com/tx/0x19315e5b150d0a83e797203bb9c957ec1fa8a6f404f4f761d970cb29a74a5dd6

### 20211130 MonoX Finance - Price Manipulation
#### Lost: $31 million

Testing
```sh
forge test --contracts ./src/test/Mono_exp.t.sol -vv
```
#### Contract

[Mono_exp.t.sol](src/test/Mono_exp.t.sol)

#### Link reference
https://slowmist.medium.com/detailed-analysis-of-the-31-million-monox-protocol-hack-574d8c44a9c8

https://knownseclab.com/news/61a986811992da0067558749

https://www.tuoniaox.com/news/p-521076.html

https://polygonscan.com/tx/0x5a03b9c03eedcb9ec6e70c6841eaa4976a732d050a6218969e39483bb3004d5d

https://etherscan.io/tx/0x9f14d093a2349de08f02fc0fb018dadb449351d0cdb7d0738ff69cc6fef5f299

### 20210916 SushiSwap Miso
#### Lost: All funds returned

Testing
```sh
forge test --contracts ./src/test/Sushimiso_exp.sol -vv
```
#### Contract

[Sushimiso_exp.sol](src/test/Sushimiso_exp.sol)

#### Link reference
https://www.paradigm.xyz/2021/08/two-rights-might-make-a-wrong

https://etherscan.io/tx/0x78d6355703507f88f2090eb780d245b0ab26bf470eabdb004761cedf3b1cda44

### 20210915 Nimbus Platform
#### Lost: 1.45 ETH

Testing
```sh
forge test --contracts ./src/test/Nimbus_exp.sol -vv
```
#### Contract

[Nimbus_exp.sol](src/test/Nimbus_exp.sol)

#### Link reference
https://twitter.com/BlockSecTeam/status/1438100688215560192

### 20210915 NowSwap Platform
#### Lost: 158.28 WETH and 535,706 USDT

Testing
```sh
forge test --contracts ./src/test/NowSwap_exp.sol -vv
```
#### Contract

[Nimbus_exp.sol](src/test/NowSwap_exp.sol)

#### Link reference
https://twitter.com/BlockSecTeam/status/1438100688215560192

### 20210912 ZABU Finance - Deflationary token uncompatible

Testing
```sh
forge test --contracts src/test/ZABU_exp.sol -vvv
```
#### Contract

[ZABU_exp.sol](src/test/ZABU_exp.sol)

### Link reference

https://slowmist.medium.com/brief-analysis-of-zabu-finance-being-hacked-44243919ea29

### 20210903 DAO Maker - Bad Access Controal
#### Lost: $4 million

Testing
```sh
forge test --contracts ./src/test/DaoMaker_exp.sol -vv
```
#### Contract

[DaoMaker_exp.sol](src/test/DaoMaker_exp.sol)

#### Link reference
https://twitter.com/Mudit__Gupta/status/1434059922774237185

https://etherscan.io/tx/0xd5e2edd6089dcf5dca78c0ccbdf659acedab173a8ab3cb65720e35b640c0af7c

### 20210830 Cream Finance - Flashloan Attack + Reentrancy
#### Lost: $18 million

Testing
```sh
forge test --contracts ./src/test/Cream_exp.sol -vv
```
#### Contract

[Cream_exp.sol](src/test/Cream_exp.sol)

#### Link reference
https://twitter.com/peckshield/status/1432249600002478081

https://etherscan.io/tx/0xa9a1b8ea288eb9ad315088f17f7c7386b9989c95b4d13c81b69d5ddad7ffe61e

https://slowmist.medium.com/cream-hacked-analysis-us-130-million-hacked-95c9410320ca

### 20210811 Poly Network - Bridge, getting around modifier through cross-chain message
#### Lost: $611 million

Testing
```sh
forge test --contracts ./src/test/PolyNetwork/PolyNetwork_exp.sol -vv
```
#### Contract

[PolyNetwork_exp.sol](src/test/PolyNetwork_exp.sol)

#### Link reference
https://rekt.news/polynetwork-rekt/

https://slowmist.medium.com/the-root-cause-of-poly-network-being-hacked-ec2ee1b0c68f

https://etherscan.io/tx/0xb1f70464bd95b774c6ce60fc706eb5f9e35cb5f06e6cfe7c17dcda46ffd59581/advanced

https://github.com/polynetwork/eth-contracts/tree/d16252b2b857eecf8e558bd3e1f3bb14cff30e9b

https://www.breadcrumbs.app/reports/671

#### FIX
One of the biggest design lessons that people need to take away from this is: if you have cross-chain relay contracts like this, MAKE SURE THAT THEY CAN'T BE USED TO CALL SPECIAL CONTRACTS. The EthCrossDomainManager shouldn't have owned the EthCrossDomainData contract.

### 20210817 XSURGE - Flashloan Attack + Reentrancy
#### Lost: $5 million

Testing
```sh
forge test --contracts ./src/test/XSURGE_exp.t.sol -vv
```
#### Contract

[XSURGE_exp.t.sol](src/test/XSURGE_exp.t.sol)

#### Link reference
https://beosin.medium.com/a-sweet-blow-fb0a5e08657d

https://medium.com/@Knownsec_Blockchain_Lab/knownsec-blockchain-lab-comprehensive-analysis-of-xsurge-attacks-c83d238fbc55

https://bscscan.com/tx/0x8c93d6e5d6b3ec7478b4195123a696dbc82a3441be090e048fe4b33a242ef09d

### 20210710 Chainswap - Bridge, logic flaw
#### Lost: $4.4 million

Testing
```sh
forge test --contracts ./src/test/Chainswap_exp2.sol -vv
```
#### Contract

[Chainswap_exp2.sol](src/test/Chainswap_exp2.sol)

#### Link reference
https://twitter.com/real_n3o/status/1414071223940571139

https://rekt.news/chainswap-rekt/

https://chain-swap.medium.com/chainswap-exploit-11-july-2021-post-mortem-6e4e346e5a32

### 20210702 Chainswap - Bridge, logic flaw
#### Lost: $.8 million

Testing
```sh
forge test --contracts ./src/test/Chainswap_exp1.t.sol -vv
```
#### Contract

[Chainswap_exp1.t.sol](src/test/Chainswap_exp1.t.sol)

#### Link reference
https://chain-swap.medium.com/chainswap-post-mortem-and-compensation-plan-90cad50898ab

### 20210628 SafeDollar - Deflationary token uncompatible
### Lost: $.2  million

Testing
```sh
forge test --contracts src/test/SafeDollar_exp.sol -vvv
```
#### Contract

[SafeDollar_exp.sol](src/test/SafeDollar_exp.sol)

#### Link reference
https://twitter.com/peckshield/status/1409443556251430918

### 20210622 Eleven Finance - Doesn’t burn shares
Testing
```sh
forge test --contracts ./src/test/Eleven.sol -vv
```
#### Contract

[Eleven.sol](src/test/Eleven.sol)

#### Link reference
https://peckshield.medium.com/eleven-finance-incident-root-cause-analysis-123b5675fa76

https://bscscan.com/tx/0xeaaa8f4d33b1035a790f0d7c4eb6e38db7d6d3b580e0bbc9ba39a9d6b80dd250

## 20200618 Bancor Protocol - Access Control
Testing
```sh
forge test --contracts ./src/test/Bancor_exp.sol -vv
```
#### Contract

[Bancor_exp.sol](src/test/Bancor_exp.sol)

#### Link reference
https://blog.bancor.network/bancors-response-to-today-s-smart-contract-vulnerability-dc888c589fe4

https://etherscan.io/address/0x5f58058c0ec971492166763c8c22632b583f667f

### 20210607 88mph NFT - Access control
Testing
```sh
forge test --contracts ./src/test/88mph_exp.sol -vv
```
#### Contract

[88mph_exp.sol](src/test/88mph_exp.sol)

#### Link reference
https://medium.com/immunefi/88mph-function-initialization-bug-fix-postmortem-c3a2282894d3

### 20210603 PancakeHunny - Incorrect calculation
Testing
```sh
forge test --contracts ./src/test/PancakeHunny_exp.sol -vv
```
#### Contract

[PancakeHunny_exp.sol](src/test/PancakeHunny_exp.sol)

#### Link reference
https://medium.com/hunnyfinance/pancakehunny-post-mortem-analysis-de78967401d8

https://bscscan.com/tx/0x765de8357994a206bb90af57dcf427f48a2021f2f28ca81f2c00bc3b9842be8e

### 20210519 PancakeBunny - Price Oracle Manipulation
Testing
```sh
forge test --contracts ./src/test/PancakeBunny_exp.sol --fork-url <BSC-RPC-URL> --fork-block-number 7556330 -vv
```

#### Contract

[PancakeBunny_exp.sol](src/test/PancakeBunny_exp.sol)

#### Link reference
https://rekt.news/pancakebunny-rekt/

https://bscscan.com/tx/0x897c2de73dd55d7701e1b69ffb3a17b0f4801ced88b0c75fe1551c5fcce6a979

### 20210308 DODO - Flashloan Attack
#### Lost: $700,000
Testing
```sh
forge test --contracts ./src/test/dodo_flashloan_exp.sol -vv
```
#### Contract

[dodo_flashloan_exp.sol](src/test/dodo_flashloan_exp.sol)

#### Link reference
https://blog.dodoex.io/dodo-pool-incident-postmortem-with-a-little-help-from-our-friends-327e66872d42

https://halborn.com/explained-the-dodo-dex-hack-march-2021/

https://etherscan.io/tx/0x395675b56370a9f5fe8b32badfa80043f5291443bd6c8273900476880fb5221e

### 20201229 Cover Protocol

Testing
```sh
forge test --contracts ./src/test/Cover_exp.sol -vv
```
#### Contract

[Cover_exp.sol](src/test/Cover_exp.sol)

#### Link reference
https://mudit.blog/cover-protocol-hack-analysis-tokens-minted-exploit/

https://slowmist.medium.com/a-brief-analysis-of-the-cover-protocol-hacked-event-700d747b309c

### 20201121 Pickle Finance
#### Lost: $20 million
Testing
```sh
forge test --contracts ./src/test/Pickle_exp.sol -vv
```
#### Contract

[Pickle_exp.sol](src/test/Pickle_exp.sol)

#### Link reference
https://github.com/banteg/evil-jar

https://etherscan.io/tx/0xe72d4e7ba9b5af0cf2a8cfb1e30fd9f388df0ab3da79790be842bfbed11087b0

### 20201026 Harvest Finance - Flashloan Attack
#### Lost: $33.8 million
Testing
```sh
forge test --contracts ./src/test/HarvestFinance_exp.sol -vv

```
#### Contract

[HarvestFinance_exp.sol](src/test/HarvestFinance_exp.sol)

#### Link reference
https://mudit.blog/cover-protocol-hack-analysis-tokens-minted-exploit/

https://slowmist.medium.com/a-brief-analysis-of-the-cover-protocol-hacked-event-700d747b309c

https://rekt.news/harvest-finance-rekt/

https://etherscan.io/tx/0x35f8d2f572fceaac9288e5d462117850ef2694786992a8c3f6d02612277b0877

### 20171106 Parity - 'Accidentally Killed It'
#### Lost: 514k ETH
Testing
```sh
forge test --contracts ./src/test/Parity_kill.sol -vvvv
```
#### Contract

[Parity_kill.sol](src/test/Parity_kill.sol)

#### Link reference
https://elementus.io/blog/which-icos-are-affected-by-the-parity-wallet-bug/

https://etherscan.io/tx/0x05f71e1b2cb4f03e547739db15d080fd30c989eda04d37ce6264c5686e0722c9

https://etherscan.io/tx/0x47f7cff7a5e671884629c93b368cb18f58a993f4b19c2a53a8662e3f1482f690

### View Gas Reports

Foundry also has the ability to [report](https://book.getfoundry.sh/forge/gas-reports) the `gas` used per function call which mimics the behavior of [hardhat-gas-reporter](https://github.com/cgewecke/hardhat-gas-reporter). Generally speaking if gas costs per function call is very high, then the likelihood of its success is reduced. Gas optimization is an important activity done by smart contract developers.

Every poc in this repository can produce a gas report like this:

```bash
forge test --gas-report --contracts <contract> -vvv
```

For Example:
Let us find out the gas used in the [Audius poc](#20220723-audius---storage-collision--malicious-proposal)

**Execution**
```bash 
forge test --gas-report --contracts ./src/test/Audius.exp.sol -vvv 
```

*Demo*

![](./AudiusPocGasReport.gif)

### Bug Reproduce
Moved to [DeFiVulnLabs](https://github.com/SunWeb3Sec/DeFiVulnLabs)

### FlashLoan Testing
Moved to [DeFiLabs](https://github.com/SunWeb3Sec/DeFiLabs)

#### Some codes referred to Rivaill and W2Ning repo and rewrote to the foundry version.

