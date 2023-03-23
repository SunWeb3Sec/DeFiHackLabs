# DeFi Hacks Reproduce - Foundry

**Reproduce DeFi hack incidents using Foundry.**

182 incidents included.

This repo is only for the educational purpose.

Let's make Web3 secure! Join [Discord](https://discord.gg/Fjyngakf3h)

Notion: [101 root cause analysis of past DeFi hacked incidents](https://web3sec.xrex.io/)

[Transaction debugging tools](https://github.com/SunWeb3Sec/DeFiHackLabs/#transaction-debugging-tools)

## Getting Started

- Follow the [instructions](https://book.getfoundry.sh/getting-started/installation.html) to install [Foundry](https://github.com/foundry-rs/foundry).

- Clone and install dependencies:`git submodule update --init --recursive`

## [Web3 Cybersecurity Academy](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy)

All articles are also published on [Substack](https://defihacklabs.substack.com/).

### OnChain transaction debugging (Ongoing)

- Lesson 1: Tools ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/en) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools) | [Vietnamese](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/vi) | [Korean](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/ko) )
- Lesson 2: Warm up ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/02_warmup/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/02_warmup/) | [Korean](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/02_warmup/ko) )
- Lesson 3: Write Your Own PoC (Price Oracle Manipulation) ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03_write_your_own_poc/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03_write_your_own_poc/) )
- Lesson 4: Write Your Own PoC (MEV Bot) ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04_write_your_own_poc/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04_write_your_own_poc/) )
- Lesson 5: Rugpull Analysis ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/05_Rugpull/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/05_Rugpull/) )
- Lesson 6: Write Your Own PoC (Reentrancy) ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06_write_your_own_poc/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06_write_your_own_poc/) )
- Lesson 7: Hack Analysis: Nomad Bridge, August 2022 ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/07_Analysis_nomad_bridge/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/07_Analysis_nomad_bridge/) )

## List of Past DeFi Incidents

[20230322 BIGFI](#20230322---bigfi---reflection-token)

[20230317 ParaSpace NFT](#20230317---paraspace-nft---flashloan--scaledbalanceof-manipulation)

[20230315 Poolz](#20230315---poolz---integer-overflow)

[20230313 EulerFinance](#20230313---eulerfinance---business-logic-flaw)

[20230308 DKP](#20230308---dkp---flashloan-price-manipulation)

[20230307 Phoenix](#20230307---phoenix---access-control--arbitrary-external-call)

[20230227 LaunchZone](#20230227---launchzone---access-control)

[20230227 SwapX](#20230227---swapx---access-control)

[20230224 EFVault](#20230224---efvault---storage-collision)

[20230222 DYNA](#20230222---dyna---business-logic-flaw)

[20230218 RevertFinance](#20230218---revertfinance---arbitrary-external-call-vulnerability)

[20230217 Starlink](#20230217---starlink---business-logic-flaw)

[20230217 Dexible](#20230217---dexible---arbitrary-external-call-vulnerability)

[20230217 Platypusdefi](#20230217---platypusdefi---business-logic-flaw)

[20230210 Sheep Token](#20230210---sheep---reflection-token)

[20230210 dForce](#20230210---dforce---read-only-reentrancy)

[20230207 CowSwap](#20230207---cowswap---arbitrary-external-call-vulnerability)

[20230207 FDP Token](#20230207---fdp---reflection-token)

[20230203 Orion Protocol](#20230203---orion-protocol---reentrancy)

[20230203 Spherax USDs](#20230203---spherax-usds---balance-recalculation-bug)

[20230202 BonqDAO](#20230202---BonqDAO---price-oracle-manipulation)

[20230126 TomInu Token](#20230126---tinu---reflection-token)

[20230119 ThoreumFinance](#20230119---thoreumfinance-business-logic-flaw)

[20230118 QTN Token](#20230118---qtntoken---business-logic-flaw)

[20230118 UPS Token](#20230118---upstoken---business-logic-flaw)

[20230117 OmniEstate](#20230117---OmniEstate---no-input-parameter-check)

[20230116 MidasCapital](#20230116---midascapital---read-only-reentrancy)

[20230112 UFDao](#20230112---ufdao---incorrect-parameter-setting)

[20230112 ROE](#20230112---roefinance---flashloan-price-manipulation)

[20230110 BRA](#20230110---bra---business-logic-flaw)

[20230103 GDS](#20230103---gds---business-logic-flaw)

<details> <summary> 2022 </summary>

[20221230 DFS](#20221230---dfs---insufficient-validation--flashloan)

[20221229 JAY](#20221229---jay---insufficient-validation--reentrancy)

[20221225 Rubic](#20221225---rubic---arbitrary-external-call-vulnerability)

[20221223 Defrost](#20221223---defrost---reentrancy)

[20221214 Nmbplatform](#20221214---nmbplatform---flashloan-price-manipulation)

[20221213 ElasticSwap](#20221213---elasticswap---business-logic-flaw)

[20221212 BGLD](#20221212---bgld-deflationary-token---flashloan-price-manipulation)

[20221211 Lodestar](#20221211---lodestar---flashloan-price-manipulation)

[20221210 MUMUG](#20221210---mumug---flashloan-price-manipulation)

[20221210 TIFIToken](#20221210---tifitoken---flashloan-price-manipulation)

[20221209 NOVAToken](#20221209---novatoken---malicious-unlimted-minting-rugged)

[20221207 AES](#20221207---aes-deflationary-token----business-logic-flaw--flashloan-price-manipulation)

[20221205 RFB](#20221205---rfb---predicting-random-numbers)

[20221205 BBOX](#20221205---bbox---flashloan-price-manipulation)

[20221202 OverNight](#20221202---overnight---flashloan-attack)

[20221201 APC](#20221201---apc---flashloan--price-manipulation)

[20221129 MBC](#20221129---mbc---business-logic-flaw--access-control)

[20221129 SEAMAN](#20221129---seaman---business-logic-flaw)

[20221123 NUM](#20221123---num---protocol-token-incompatible)

[20221122 AUR](#20221122---aur---lack-of-permission-check)

[20221121 SDAO](#20221121---sdao---business-logic-flaw)

[20221119 AnnexFinance](#20221119---annexfinance---verify-flashloan-callback)

[20221117 UEarnPool](#20221117---uearnpool---flashloan-attack)

[20221116 SheepFarm](#20221116---sheepfarm---no-input-validation)

[20221110 DFXFinance](#20221110---dfxfinance---reentrancy)

[20221109 brahTOPG](#20221109-brahtopg---arbitrary-external-call-vulnerability)

[20221108 MEV_0ad8](#20221108-mev_0ad8---arbitrary-call)

[20221108 Kashi](#20221108-kashi---price-caching-design-defect)

[20221107 MooCAKECTX](#20221107-moocakectx---flashloan-attack)

[20221105 BDEX](#20221105-bdex---business-logic-flaw)

[20221027 VTF](#20221027-vtf-token---incorrect-reward-calculation)

[20221027 Team Finance](#20221027-team-finance---liquidity-migration-exploit)

[20221026 N00d Token](#20221026-n00d-token---reentrancy)

[20221026 ULME](#20221026-ulme---access-control)

[20221024 Market](#20221024-market---read-only-reentrancy)

[20221024 MulticallWithoutCheck](#20221024-multicallwithoutcheck---arbitrary-external-call-vulnerability)

[20221021 OlympusDAO](#20221021-olympusdao---no-input-validation)

[20221020 HEALTH Token](#20221020-health---transfer-logic-flaw)

[20221020 BEGO Token](#20221020-bego---incorrect-signature-verification)

[20221018 HPAY](#20221018-hpay---access-control)

[20221018 PLTD Token](#20221018-pltd---transfer-logic-flaw)

[20221017 Uerii Token](#20221017-uerii-token---access-control)

[20221014 INUKO Token](#20221014-inuko---flashloan-price-manipulation)

[20221014 EFLeverVault](#20221014-eflevervault---verify-flashloan-callback)

[20221014 MEVBOT a47b](#20221014-mevbota47b---mevbot-a47b)

[20221012 ATK](#20221012-atk---flashloan-manipulate-price)

[20221011 Rabby Wallet SwapRouter](#20221011-rabby-wallet-swaprouter---arbitrary-external-call-vulnerability)

[20221011 Templedao](#20221011-templedao---insufficient-access-control)

[20221010 Carrot](#20221010-carrot---public-functioncall)

[20221009 Xave Finance](#20221009-xave-finance---malicious-proposal-mint--transfer-ownership)

[20221006 RES-Token](#20221006-RES-Token---pair-manipulate)

[20221002 Transit Swap](#20221002-transit-swap---incorrect-owner-address-validation)

[20221001 BabySwap](#20221001-babyswap---parameter-access-control)

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

[20220824 LuckyTiger NFT](#20220824-luckytiger-nft---predicting-random-numbers)

[20220810 XSTABLE Protocol](#20220810-xstable-protocol---incorrect-logic-check)

[20220809 ANCH](#20220809-anch---skim-token-balance)

[20220807 EGD Finance](#20220807-egd-finance---flashloans--price-manipulation)

[20220802 Nomad Bridge](#20220802-nomad-bridge---business-logic-flaw--incorrect-acceptable-merkle-root-checks)

[20220801 Reaper Farm](#20220801-reaper-farm---business-logic-flaw--lack-of-access-control-mechanism)

[20220725 LPC](#20220725-lpc---business-logic-flaw--incorrect-recipient-balance-check-did-not-check-senderrecipient-in-transfer)

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

[20220524 HackDao](#20220524-HackDao---Skim-token-balance)

[20220517 ApeCoin](#20220517-apecoin-ape---flashloan)

[20220508 Fortress Loans](#20220508-fortress-loans---malicious-proposal--price-oracle-manipulation)

[20220430 Saddle Finance](#20220430-saddle-finance---swap-metapool-attack)

[20220430 Rari Capital/Fei Protocol](#20220430-rari-capitalfei-protocol---flashloan-attack--reentrancy)

[20220428 DEUS DAO](#20220428-deus-dao---flashloan--price-oracle-manipulation)

[20220424 Wiener DOGE](#20220424-wiener-doge---flashloan)

[20220423 Akutar NFT](#20220423-akutar-nft---denial-of-service)

[20220421 Zeed Finance](#20220421-zeed-finance)

[20220416 BeanstalkFarms](#20220416-beanstalkfarms---dao--flashloan)

[20220415 Rikkei Finance](#20220415-rikkei-finance---accesscontrol--price-oracle-manipulation)

[20220412 ElephantMoney](#20220412-elephantmoney---flashloan--price-oracle-manipulation)

[20220411 Creat Future](#20220411-creat-future)

[20220409 GYMNetwork](#20220409-gymnetwork)

[20220329 Ronin Network](#20220329-ronin-network---Bridge)

[20220329 Redacted Cartel](#20220329-redacted-cartel---custom-approval-logic)

[20220327 Revest Finance](#20220327-revest-finance---reentrancy)

[20220326 Auctus](#20220326-auctus)

[20220322 CompoundTUSDSweepTokenBypass](#20220322-compoundtusdsweeptokenbypass)

[20220321 OneRing Finance](#20220321-onering-finance---flashloan--price-oracle-manipulation)

[20220320 LI.FI](#20220320-LiFi---bridges)

[20220320 Umbrella Network](#20220320-umbrella-network---underflow)

[20220315 Hundred Finance](#20220313-hundred-finance---erc667-reentrancy)

[20220313 Paraluni](#20220313-paraluni---flashloan--reentrancy)

[20220309 Fantasm Finance](#20220309-fantasm-finance)

[20220305 Bacon Protocol](#20220305-bacon-protocol---reentrancy)

[20220303 TreasureDAO](#20220303-treasuredao---zero-fee)

[20220214 BuildFinance - DAO](#20220214-buildfinance---dao)

[20220208 Sandbox LAND](#20220208-sandbox-land---access-control)

[20220206 Meter](#20220206-Meter---bridge)

[20220128 Qubit Finance](#20220128-qubit-finance---bridge-address0safetransferfrom-does-not-revert)

[20220118 Multichain (Anyswap)](#20220118-multichain-anyswap---insufficient-token-validation)

</details>
<details> <summary> 2021 </summary>
 
[20211221 Visor Finance](#20211221-visor-finance---reentrancy)

[20211218 Grim Finance](#20211218-grim-finance---flashloan--reentrancy)

[20211130 MonoX Finance](#20211130-monox-finance---price-manipulation)

[20211027 Cream Finance](#20211027-creamfinance---price-manipulation)

[20211015 Indexed Finance](#20211015-indexed-finance---price-manipulation)

[20210916 SushiSwap Miso](#20210916-sushiswap-miso)

[20210915 Nimbus Platform](#20210915-nimbus-platform)

[20210915 NowSwap Platform](#20210915-nowswap-platform)

[20210912 ZABU Finance](#20210912-ZABU-Finance---Deflationary-token-uncompatible)

[20210903 DAO Maker](#20210903-dao-maker---bad-access-controal)

[20210830 Cream Finance](#20210830-cream-finance---flashloan-attack--reentrancy)

[20210817 XSURGE](#20210817-xsurge---flashloan-attack--reentrancy)

[20210811 Poly Network](#20210811-poly-network---bridge-getting-around-modifier-through-cross-chain-message)

[20210804 WaultFinance](#20210804-waultfinace---flashloan-price-manipulation)

[20210728 Levyathan Finance](#20210728-levyathan-finance---i-lost-keys-and-minting-ii-vulnerable-emergencywithdraw)

[20210710 Chainswap](#20210710-chainswap---bridge-logic-flaw)

[20210702 Chainswap](#20210702-chainswap---bridge-logic-flaw)

[20210628 SafeDollar](#20210628-safedollar---deflationary-token-uncompatible)

[20210622 Eleven Finance](#20210622-eleven-finance---doesnt-burn-shares)

[20210607 88mph NFT](#20210607-88mph-nft---access-control)

[20210603 PancakeHunny](#20210603-pancakehunny---incorrect-calculation)

[20210519 PancakeBunny](#20210519-pancakebunny---price-oracle-manipulation)

[20210125 Sushi Badger Digg](#20210125-sushi-badger-digg---sandwich-attack)

</details>
<details> <summary> Before 2020 </summary>
 
[20210508 Rari Capital](#20210509-raricapital---cross-contract-reentrancy)

[20210508 Value Defi](#20210508-value-defi---cross-contract-reentrancy)

[20210428 Uranium](#20210428-uranium---miscalculation)

[20210308 DODO](#20210308-dodo---flashloan-attack)

[20210305 Paid Network](#20210305-paid-network---private-key-compromised)

[20201229 Cover Protocol](#20201229-cover-protocol)

[20201121 Pickle Finance](#20201121-pickle-finance)

[20201026 Harvest Finance](#20201026-harvest-finance---flashloan-attack)

[20200804 Opyn Protocol](#20200804-opyn-protocol---msgValue-in-loop)

[20200618 Bancor Protocol](#20200618-bancor-protocol---access-control)

[20180422 Beauty Chain](#20180422-beauty-chain---integer-overflow)

[20171106 Parity - 'Accidentally Killed It'](#20171106-parity---accidentally-killed-it)

</details>
 
---
### Transaction debugging tools

[Phalcon](https://phalcon.blocksec.com/) | [Tx tracer](https://openchain.xyz/trace) | [Cruise](https://cruise.supremacy.team/) | [Ethtx](https://ethtx.info/) | [Tenderly](https://dashboard.tenderly.co/explorer) | [eigenphi](https://tx.eigenphi.io/analyseTransaction)

### Ethereum Signature Database

[4byte](https://www.4byte.directory/) | [sig db](https://openchain.xyz/signatures) | [etherface](https://www.etherface.io/hash)

### Useful tools

[ABI to interface](https://gnidan.github.io/abi-to-sol/) | [Get ABI for unverified contracts](https://abi.w1nt3r.xyz/) | [ETH Calldata Decoder](https://apoorvlathey.com/eth-calldata-decoder/) | [ETHCMD - Guess ABI](https://www.ethcmd.com/tools/decode-calldata/) | [Abi tools](https://openchain.xyz/tools/abi)

### Hacks Dashboard

[Slowmist](https://hacked.slowmist.io/) | [Defillama](https://defillama.com/hacks) | [Defiyield](https://defiyield.app/rekt-database) | [Rekt](https://rekt.news/) | [Cryptosec](https://cryptosec.info/defi-hacks/)

---

### List of DeFi Hacks & POCs

### 20230322 - BIGFI - Reflection token

### Lost: $30k

Testing
```
forge test --contracts ./src/test/BIGFI_exp.sol -vvv
```

#### Contract

[BIGFI_exp.sol](src/test/BIGFI_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1638522680654675970

---

### 20230317 - ParaSpace NFT - Flashloan + scaledBalanceOf Manipulation

### Rescued: ~2,909 ETH

Testing

```
forge test --contracts ./src/test/paraspace_exp.sol -vvv
```

#### Contract

[paraspace_exp.sol](src/test/paraspace_exp.sol)  
[Paraspace_exp_2.sol](src/test/Paraspace_exp_2.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1636650252844294144

---

### 20230315 - Poolz - integer overflow

### Lost: ~$390K

Testing

```
forge test --contracts ./src/test/poolz_exp.sol -vvv
```

#### Contract

[poolz_exp.sol](src/test/poolz_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1635860470359015425

---

### 20230313 - EulerFinance - Business Logic Flaw

### Lost: ~$200M

Testing 

```
forge test --contracts ./src/test/Euler_exp.sol -vvv
```

#### Contract

[Euler_exp.sol](src/test/Euler_exp.sol)

#### Link Reference

https://twitter.com/FrankResearcher/status/1635241475989721089

https://twitter.com/nomorebear/status/1635230621856600064

https://twitter.com/peckshield/status/1635229594596036608

https://twitter.com/BlockSecTeam/status/1635262150624305153

---

### 20230308 - DKP - FlashLoan price manipulation

### Lost: ~$80K

Testing

```
forge test --contracts ./src/test/DKP_exp.sol -vvv
```

#### Contract

[DKP_exp.sol](src/test/DKP_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1633421908996763648

---

### 20230307 - Phoenix - Access Control & Arbitrary External Call

### Lost: ~$100k

Testing

```
forge test --contracts src/test/Phoenix_exp.sol -vvv
```

#### Contract

[Phoenix_exp.sol](src/test/Phoenix_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1633090456157401088

---

### 20230227 - LaunchZone - Access Control

### Lost: ~$320,000

Testing

```
forge test  --contracts src/test/LaunchZone_exp.sol -vvv
```

#### Contract

[LuanchZone_exp.sol](src/test/LaunchZone_exp.sol)

#### Link Reference

https://twitter.com/immunefi/status/1630210901360951296

https://twitter.com/launchzoneann/status/1631538253424918528

---

### 20230227 - swapX - Access Control

### Lost: ~$1M

Testing

```
forge test --contracts ./src/test/swapX_exp.sol -vvv
```

#### Contract

[SwapX_exp.sol](src/test/SwapX_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1630111965942018049

https://twitter.com/peckshield/status/1630100506319413250

https://twitter.com/CertiKAlert/status/1630241903839985666

---

### 20230224 - EFVault - Storage Collision

### Lost: ~$5.1M

Testing

```
forge test --contracts ./src/test/EFVault_exp.sol -vvv
```

#### Contract

[EFVault_exp.sol](src/test/EFVault_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1630490333716029440

https://twitter.com/drdr_zz/status/1630500170373685248

https://twitter.com/gbaleeeee/status/1630587522698080257

---

### 20230222 - DYNA - Business Logic Flaw

### Lost: ~$21k

Testing

```
forge test --contracts ./src/test/DYNA_exp.sol -vvv
```

#### Contract

[DYNA_exp.sol](src/test/DYNA_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1628319536117153794

https://twitter.com/BeosinAlert/status/1628301635834486784

---

### 20230218 - RevertFinance - Arbitrary External Call Vulnerability

### Lost: ~$30k

Testing

```
forge test --contracts ./src/test/RevertFinance_exp.sol -vvv
```

#### Contract

[RevertFinance_exp.sol](src/test/RevertFinance_exp.sol)

#### Link Reference

https://mirror.xyz/revertfinance.eth/3sdpQ3v9vEKiOjaHXUi3TdEfhleAXXlAEWeODrRHJtU

---

### 20230217 - Starlink - Business Logic Flaw

### Lost: ~$12k

Testing

```
forge test --contracts ./src/test/Starlink_exp.sol -vvv
```

#### Contract

[Starlink_exp.sol](src/test/Starlink_exp.sol)

#### Link Reference

https://twitter.com/NumenAlert/status/1626447469361102850

https://twitter.com/bbbb/status/1626392605264351235

---

### 20230217 - Dexible - Arbitrary External Call Vulnerability

### Lost: ~$1.5M

Testing

```
forge test --contracts src/test/Dexible_exp.sol -vvv
```

#### Contract

[Dexible_exp.sol](src/test/Dexible_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1626493024879673344

https://twitter.com/MevRefund/status/1626450002254958592

---

### 20230217 - Platypusdefi - Business Logic Flaw

### Lost: ~$8.5M

Testing

```
forge test --contracts src/test/Platypus_exp.sol -vvv
```

#### Contract

[Platypus_exp.sol](src/test/Platypus_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1626367531480125440

https://twitter.com/spreekaway/status/1626319585040338953

---

### 20230210 - Sheep - Reflection token

### Lost: ~$3K

Testing

```
forge test --contracts src/test/Sheep_exp.sol -vvv
```

#### Contract

[Sheep_exp.sol](src/test/Sheep_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1623999717482045440

https://twitter.com/BlockSecTeam/status/1624077078852210691

---

### 20230210 - dForce - Read-Only-Reentrancy

### Lost: ~$3.65M

Testing

```
forge test --contracts ./src/test/dForce_exp.sol -vvv
```

#### Contract

[dForce_exp.sol](src/test/dForce_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1623956763598000129

https://twitter.com/BlockSecTeam/status/1623901011680333824

https://twitter.com/peckshield/status/1623910257033617408

---

### 20230207 - CowSwap - Arbitrary External Call Vulnerability

### Lost: ~$120k

Testing

```
forge test --contracts ./src/test/CowSwap_exp.sol -vvv
```

#### Contract

[CowSwap_exp.sol](src/test/CowSwap_exp.sol)

#### Link reference

https://twitter.com/MevRefund/status/1622793836291407873

https://twitter.com/peckshield/status/1622801412727148544

---

### 20230207 - FDP - Reflection token

### Lost: ~16 WBNB

Testing

```
forge test --contracts src/test/FDP_exp.t.sol -vv
```

#### Contract

[FDP_exp.t.sol](src/test/FDP_exp.t.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1622806011269771266

---

### 20230203 - Spherax USDs - Balance Recalculation Bug

### Lost: ~309k USDs (Stablecoin)

Testing

```
forge test --contracts ./src/test/USDs_exp.sol -vv
```

#### Contract

[USDs_exp.sol](src/test/USDs_exp.sol)

#### Link reference

https://twitter.com/danielvf/status/1621965412832350208

https://medium.com/sperax/usds-feb-3-exploit-report-from-engineering-team-9f0fd3cef00c

---

### 20230203 - Orion Protocol - Reentrancy

### Lost: $3M

Testing

```
forge test --contracts ./src/test/Orion_exp.sol -vvv
```

#### Contract

[Orion_exp.sol](src/test/Orion_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1621337925228306433

https://twitter.com/BlockSecTeam/status/1621263393054420992

https://www.numencyber.com/analysis-of-orionprotocol-reentrancy-attack-with-poc/

---

### 20230202 - BonqDAO - Price Oracle Manipulation

### Lost: BEUR stablecoin and ALBT Token (~88M US$)

Testing

```
forge test --contracts ./src/test/BonqDAO_exp.sol -vv
```

#### Contract

[BonqDAO_exp.sol](src/test/BonqDAO_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1621043757390123008

https://twitter.com/SlowMist_Team/status/1621087651158966274

---

### 20230126 - TINU - Reflection token

### Lost: 22 ETH

Testing

```sh
forge test --contracts ./src/test/TINU_exp.t.sol -vv
```

#### Contract

[TINU_exp.t.sol](src/test/TINU_exp.t.sol)

#### Link reference

https://twitter.com/libevm/status/1618718156343873536

---

### 20230118 - QTNToken - business logic flaw

### Lost: ~2ETH

Testing

```sh
forge test --contracts ./src/test/QTN_exp.sol -vvv
```

#### Contract

[QTN_exp.sol](src/test/QTN_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1615625901739511809

---

### 20230119 - ThoreumFinance-business logic flaw

### Lost: ~2000 BNB

Testing

```sh
forge test --contracts ./src/test/ThoreumFinance_exp.sol -vvv
```

#### Contract

[ThoreumFinance_exp.sol](src/test/ThoreumFinance_exp.sol)

#### Link reference

https://bscscan.com/tx/0x3fe3a1883f0ae263a260f7d3e9b462468f4f83c2c88bb89d1dee5d7d24262b51
https://twitter.com/AnciliaInc/status/1615944396134043648

### 20230118 - UPSToken - business logic flaw

### Lost: ~22 ETH

Testing

```sh
forge test --contracts ./src/test/Upswing_exp.sol -vvv
```

#### Contract

[Upswing_exp.sol](src/test/Upswing_exp.sol)

#### Link reference

https://etherscan.io/tx/0x4b3df6e9c68ae482c71a02832f7f599ff58ff877ec05fed0abd95b31d2d7d912
https://twitter.com/QuillAudits/status/1615634917802807297

---

### 20230117 - OmniEstate - No Input Parameter Check

### Lost: $70k(236 BNB)

Testing

```sh
forge test --contracts ./src/test/OmniEstate_exp.sol -vvv
```

#### Contract

[OmniEstate_exp.sol](src/test/OmniEstate_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1615232012834705408

---

### 20230116 - MidasCapital - Read-only Reentrancy

### Lost: $650k

Testing

```sh
forge test --contracts ./src/test/Midas_exp.sol -vvv
```

#### Contract

[Midas_exp.sol](src/test/Midas_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1614774855999844352

https://twitter.com/BlockSecTeam/status/1614864084956254209

---

### 20230112 - UFDao - Incorrect Parameter Setting

### Lost: $90k

Testing

```sh
forge test --contracts ./src/test/UFDao_exp.sol -vvv
```

#### Contract

[UFDao_exp.sol](src/test/UFDao_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1613507804412940289

---

### 20230112 - RoeFinance - FlashLoan price manipulation

### Lost: $80k

Testing

```sh
forge test --contracts ./src/test/RoeFinance_exp.sol -vvv
```

#### Contract

[RoeFinance_exp.sol](src/test/RoeFinance_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1613267000913960976

---

### 20230110 - BRA - Business Logic Flaw

### Lost: 819 BNB (~224k$)

Testing

```sh
forge test --contracts ./src/test/BRA.exp.sol -vvv
```

#### Contract

[BRA.exp.sol](src/test/BRA.exp.sol)

#### Link reference

https://twitter.com/CertiKAlert/status/1612674916070858753

https://twitter.com/BlockSecTeam/status/1612701106982862849

---

### 20230103 - GDS - Business Logic Flaw

### Lost: $180k

Testing

```sh
forge test --contracts ./src/test/GDS_exp.sol -vvv
```

#### Contract

[GDS_exp.sol](src/test/GDS_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1610095490368180224

https://twitter.com/BlockSecTeam/status/1610167174978760704

---

<details> <summary> 2022 </summary>

### 20221230 - DFS - Insufficient validation + flashloan

### Lost: $1450

Testing

```sh
forge test --contracts ./src/test/DFS_exp.sol -vvv
```

#### Contract

[DFS_exp.sol](src/test/DFS_exp.sol)

#### Link reference

https://twitter.com/CertiKAlert/status/1608788290785665024

---

### 20221229 - JAY - Insufficient validation + Reentrancy

### Lost: $15.32 ETH

Testing

```sh
forge test --contracts ./src/test/JAY_exp.sol -vvv
```

#### Contract

[JAY_exp.sol](src/test/JAY_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1608372475225866240

---

### 20221225 - Rubic - Arbitrary External Call Vulnerability

### Lost: $1.5M

Testing

```sh
forge test --contracts ./src/test/Rubic_exp.sol -vvv
```

#### Contract

[Rubic_exp.sol](src/test/Rubic_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1606993118901198849

https://twitter.com/peckshield/status/1606937055761952770

---

### 20221223 - Defrost - Reentrancy

### Lost: $170k

Testing

```sh
forge test --contracts ./src/test/Defrost_exp.sol -vvv
```

#### Contract

[Defrost_exp.sol](src/test/Defrost_exp.sol)

#### Link reference

https://twitter.com/PeckShieldAlert/status/1606276020276891650

---

### 20221214 - Nmbplatform - FlashLoan price manipulation

### Lost: 76k

Testing

```sh
forge test --contracts ./src/test/Nmbplatform_exp.sol -vvv
```

#### Contract

[Nmbplatform_exp.sol](src/test/Nmbplatform_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1602877048124735489

---

### 20221213 - ElasticSwap - Business Logic Flaw

### Lost: $845k

Testing

```sh
forge test --contracts ./src/test/ElasticSwap_exp.sol -vvv
```

#### Contract

[ElasticSwap_exp.sol](src/test/ElasticSwap_exp.sol)

#### Link reference

https://quillaudits.medium.com/decoding-elastic-swaps-850k-exploit-quillaudits-9ceb7fcd8d1a

---

### 20221212 - BGLD (Deflationary token) - FlashLoan price manipulation

### Lost: $18k

Testing

```sh
forge test --contracts ./src/test/BGLD_exp.sol -vvv
```

#### Contract

[BGLD_exp.sol](src/test/BGLD_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1602335214356660225

---

### 20221211 - Lodestar - FlashLoan price manipulation

### Lost: $4M

Testing

```sh
forge test --contracts ./src/test/Lodestar_exp.sol -vvv
```

#### Contract

[Lodestar_exp.sol](src/test/Lodestar_exp.sol)

#### Link reference

https://twitter.com/SolidityFinance/status/1601684150456438784

https://blog.lodestarfinance.io/post-mortem-summary-13f5fe0bb336

---

### 20221210 - MU&MUG - FlashLoan price manipulation

### Lost: $57k

Testing

```sh
forge test --contracts ./src/test/MUMUG_exp.sol -vvv
```

#### Contract

[MUMUG_exp.sol](src/test/MUMUG_exp.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1601422462012469248

---

### 20221210 - TIFIToken - FlashLoan price manipulation

### Lost: 87 WBNB

Testing

```sh
forge test --contracts ./src/test/TIFI_exp.sol -vvv
```

#### Contract

[TIFI_exp.sol](src/test/TIFI_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1601492605535399936

---

### 20221209 - NOVAToken - Malicious Unlimted Minting (Rugged)

### Lost: 330 $BNB

Testing

```sh
forge test --contracts ./src/test/NovaExchange_exp.sol -vvv
```

#### Contract

[NovaExchange_exp.sol](src/test/NovaExchange_exp.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1601168659585454081

---

### 20221207 - AES (Deflationary token) - Business Logic Flaw & FlashLoan price manipulation

### Lost: $60k

Testing

```sh
forge test --contracts ./src/test/AES_exp.sol -vvv
```

#### Contract

[AES_exp.sol](src/test/AES_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1600442137811689473

https://twitter.com/peckshield/status/1600418002163625984

---

### 20221205 - RFB - Predicting Random Numbers

### Lost: 12BNB

Testing

```sh
forge test --contracts ./src/test/RFB_exp.sol -vvv
```

#### Contract

[RFB_exp.sol](src/test/RFB_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1599991294947778560

---

### 20221205 - BBOX - FlashLoan price manipulation

### Lost: 12k

Testing

```sh
forge test --contracts ./src/test/BBOX_exp.sol -vvv
```

#### Contract

[BBOX_exp.sol](src/test/BBOX_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1599599614490877952

---

### 20221202 - OverNight - FlashLoan Attack

### Lost: 170k

Testing

```sh
forge test --contracts ./src/test/Overnight_exp.sol -vvv
```

#### Contract

[Overnight_exp.sol](src/test/Overnight_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1598704809690877952

---

### 20221201 - APC - FlashLoan & price manipulation

### Lost: $6k

Testing

```sh
forge test --contracts ./src/test/APC_exp.sol -vvv
```

#### Contract

[APC_exp.sol](src/test/APC_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1598262002010378241

---

### 20221129 - MBC - Business Logic Flaw & Access Control

### Lost $5.6k

Testing

```sh
forge test --contracts ./src/test/MBC_exp.sol -vvv
```

#### Contract

[MBC_exp.sol](src/test/MBC_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1597742575623888896

https://twitter.com/CertiKAlert/status/1597639717096460288

---

### 20221129 - SEAMAN - Business Logic Flaw

### Lost $7k

Testing

```sh
forge test --contracts ./src/test/SEAMAN_exp.sol -vvv
```

#### Contract

[SEAMAN_exp.sol](src/test/SEAMAN_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1597493955939405825

https://twitter.com/CertiKAlert/status/1597513374841044993

https://twitter.com/BeosinAlert/status/1597535796621631489

---

### 20221123 - NUM - Protocol Token incompatible

### Lost $13k

Testing

```sh
forge test --contracts ./src/test/NUM_exp.sol -vvv
```

#### Contract

[NUM_exp.sol](src/test/NUM_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1595346020237352960

---

### 20221122 - AUR - Lack of Permission Check

### Lost: $13k

Testing

```sh
forge test --contracts ./src/test/AUR_exp.sol -vvv
```

#### Contract

[AUR_exp.sol](src/test/AUR_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1595142246570958848

---

### 20221121 - sDAO - Business Logic Flaw

### Lost: $13k

Testing

```sh
forge test --contracts ./src/test/SDAO_exp.sol -vvv
```

#### Contract

[SDAO_exp.sol](src/test/SDAO_exp.sol)

#### Link reference

https://twitter.com/8olidity/status/1594693686398316544

https://twitter.com/CertiKAlert/status/1594615286556393478

---

### 20221119 - AnnexFinance - Verify flashLoan Callback

### Lost: $3k

Testing

```sh
forge test --contracts ./src/test/Annex_exp.sol -vvv
```

#### Contract

[Annex_exp.sol](src/test/Annex_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1593690338526273536

---

### 20221117 - UEarnPool - FlashLoan Attack

### Lost: $24k

Testing

```sh
forge test --contracts ./src/test/UEarnPool_exp.sol -vvv
```

#### Contract

[UEranPool_exp.sol](src/test/UEarnPool_exp.sol)

#### Link reference

https://twitter.com/CertiKAlert/status/1593094922160128000

---

### 20221116 - SheepFarm - No input validation

### Lost: ~1BNB

Testing

```sh
forge test --contracts ./src/test/SheepFram_exp.sol -vvv
```

#### Contract

[SheepFarm_exp.sol](src/test/SheepFram_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1592658104394473472

https://twitter.com/BlockSecTeam/status/1592734292727455744

---

### 20221110 - DFXFinance - Reentrancy

### Lost: $4M

Testing

```sh
forge test --contracts ./src/test/DFX_exp.sol -vvv
```

#### Contract

[DFX_exp.sol](src/test/DFX_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1590960299246780417

https://twitter.com/BeosinAlert/status/1591012525914861570

https://twitter.com/AnciliaInc/status/1590839104731684865

https://twitter.com/peckshield/status/1590831589004816384

---

### 20221109 BrahTOPG - Arbitrary External Call Vulnerability

### Lost: $89k

Testing

```sh
 forge test --contracts ./src/test/BrahTOPG_exp.sol -vvv
```

#### Contract

[BrahTOPG_exp.sol](src/test/BrahTOPG_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1590685173477101570

---

### 20221108 MEV_0ad8 - Arbitrary call

### Lost: $282k

Testing

```sh
forge test --contracts src/test/MEV_0ad8.t.sol -vvvv
```

#### Contract

[MEV_0ad8.t.sol](src/test/MEV_0ad8.t.sol)

#### Link reference

https://twitter.com/Supremacy_CA/status/1590337718755954690

---

### 20221108 Kashi - Price-caching Design Defect

### Lost: $110k

Testing

```sh
forge test --contracts ./src/test/Kashi_exp.sol -vvv
```

#### Contract

[Kashi_exp.sol](src/test/Kashi_exp.sol)

#### Link reference

https://eigenphi.substack.com/p/casting-a-magic-spell-on-abracadabra

https://twitter.com/BlockSecTeam/status/1603633067876155393

---

### 20221107 MooCAKECTX - FlashLoan Attack

### Lost: $140k

Testing

```sh
forge test --contracts ./src/test/MooCAKECTX_exp.sol -vvv
```

#### Contract

[MooCAKECTX_exp.sol](src/test/MooCAKECTX_exp.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1589501207181393920

https://twitter.com/CertiKAlert/status/1589428153591615488

---

### 20221105 BDEX - Business Logic Flaw

### Lost: 16WBNB

Testing

```sh
forge test --contracts ./src/test/BDEX_exp.sol -vvv
```

#### Contract

[BDEX_exp.sol](src/test/BDEX_exp.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1588579143830343683

---

### 20221027 VTF Token - Incorrect Reward calculation

### Lost: $50k

Testing

```sh
forge test --contracts ./src/test/VTF_exp.sol -vvv
```

#### Contract

[VTF_exp.sol](src/test/VTF_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1585575129936977920

https://twitter.com/peckshield/status/1585572694241988609

https://twitter.com/BeosinAlert/status/1585587030981218305

---

### 20221027 Team Finance - Liquidity Migration Exploit

### Lost: Multiple Tokens ~$15.8M US$

Testing

```sh
forge test --contracts ./src/test/TeamFinance.exp.sol -vvv
```

#### Contract

[TeamFinance.exp.sol](src/test/TeamFinance.exp.sol)

#### Link reference

https://twitter.com/TeamFinance_/status/1585770918873542656

https://twitter.com/peckshield/status/1585587858978623491

https://twitter.com/solid_group_1/status/1585643249305518083

https://twitter.com/BeosinAlert/status/1585578499125178369

---

### 20221026 N00d Token - Reentrancy

### Lost $29k

Testing

```sh
forge test --contracts src/test/N00d_exp.sol -vvv
```

#### Contract

[N00d_exp.sol](src/test/N00d_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1584959295829180416

https://twitter.com/AnciliaInc/status/1584955717877784576

---

### 20221026 ULME - Access Control

### Lost ~200k US$ which resulted in ~50k profit

Testing

```sh
forge test --contracts ./src/test/ULME.sol -vvv
```

#### Contract

[ULME.sol](src/test/ULME.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1584839309781135361
https://twitter.com/BeosinAlert/status/1584888021299916801

---

### 20221024 Market - Read-only Reentrancy

### Lost: $220k

Testing

```sh
forge test --contracts ./src/test/Market_exp.t.sol -vv
```

#### Contract

[Market_exp.t.sol](src/test/Market_exp.t.sol)

#### Link reference

https://quillaudits.medium.com/decoding-220k-read-only-reentrancy-exploit-quillaudits-30871d728ad5

---

### 20221024 MulticallWithoutCheck - Arbitrary External Call Vulnerability

### Lost $600

Testing

```sh
forge test --contracts ./src/test/MulticallWithoutCheck_exp.sol -vvv
```

#### Contract

[MulticallWithoutCheck_exp.sol](src/test/MulticallWithoutCheck_exp.sol)

---

### 20221021 OlympusDAO - No input validation

### Lost ~$292K (30500 OHM)

Testing

```sh
forge test --contracts ./src/test/OlympusDao.exp.sol -vvv
```

#### Contract

[OlympusDao.exp.sol](src/test/OlympusDao.exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1583416829237526528

---

### 20221020 HEALTH - Transfer Logic Flaw

### Lost 16 BNB

Testing

```sh
forge test --contracts ./src/test/HEALTH_exp.sol -vvv
```

#### Contract

[HEALTH_exp.sol](src/test/HEALTH_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1583073442433495040

---

### 20221020 BEGO - Incorrect signature verification

### Lost 12 BNB

Testing

```sh
forge test --contracts ./src/test/BEGO_exp.sol -vvv
```

#### Contract

[BEGO_exp.sol](src/test/BEGO_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1582828751250784256

https://twitter.com/peckshield/status/1582892058800685058

---

### 20221018 HPAY - Access Control

### Lost: 115 BNB

Testing

```sh
forge test --contracts ./src/test/HPAY_exp.sol -vvv
```

#### Contract

[HPAY_exp.sol](src/test/HPAY_exp.sol)

#### Link reference

https://twitter.com/Supremacy_CA/status/1582345448190140417

---

### 20221018 PLTD - Transfer Logic Flaw

### Lost: $ 24k

Testing

```sh
forge test --contracts ./src/test/PLTD_exp.sol -vvv
```

#### Contract

[PLTD_exp.sol](src/test/PLTD_exp.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1582181583343484928

---

### 20221017 Uerii Token - Access Control

### Lost: $2.4 k

Testing

```sh
forge test --contracts ./src/test/Uerii_exp.sol -vvv
```

#### Contract

[Uerii_exp.sol](src/test/Uerii_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1581988895142526976

---

### 20221014 INUKO - FlashLoan price manipulation

### Lost: $50k

Testing

```sh
forge test --contracts ./src/test/INUKO_exp.sol -vvv
```

#### Contract

[INUKO_exp.sol](src/test/INUKO_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1587848874076430336

---

### 20221014 EFLeverVault - Verify flashLoan Callback

### Lost: 750 ETH

Testing

```sh
 forge test --contracts ./src/test/EFLeverVault_exp.sol -vvv
```

#### Contract

[EFLeverVault_exp.sol](src/test/EFLeverVault_exp.sol)

#### Link reference

https://twitter.com/Supremacy_CA/status/1581012823701786624

https://twitter.com/MevRefund/status/1580917351217627136

https://twitter.com/danielvf/status/1580936010556661761

---

### 20221014 MEVBOTa47b - MEVBOT a47b

### Lost: $241 k

Testing

```sh
forge test --contracts ./src/test/MEVa47b_exp.sol -vvv
```

### Contract

[MEVa47b_exp.sol](src/test/MEVa47b_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1580779311862190080

https://twitter.com/AnciliaInc/status/1580705036400611328

https://etherscan.io/tx/0x35ecf595864400696853c53edf3e3d60096639b6071cadea6076c9c6ceb921c1

---

### 20221012 ATK - FlashLoan manipulate price

### Lost: $127 k

Testing

```sh
forge test --contracts ./src/test/ATK_exp.sol -vvv
```

#### Contract

[ATK_exp.sol](src/test/ATK_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1580095325200474112

---

### 20221011 Rabby Wallet SwapRouter - Arbitrary External Call Vulnerability

### Lost: ~200,000 US$

Testing

```sh
forge test --contracts src/test/RabbyWallet_SwapRouter.exp.sol -vv
```

#### Contract

[RabbyWallet_SwapRouter.exp.sol](src/test/RabbyWallet_SwapRouter.exp.sol)

#### Link reference

https://twitter.com/Supremacy_CA/status/1579813933669486592

https://twitter.com/SlowMist_Team/status/1579839744128978945

https://twitter.com/BeosinAlert/status/1579856733178331139

---

### 20221011 Templedao - Insufficient access control

### Lost: $2.3 million

Testing

```sh
forge test --contracts src/test/Templedao_exp.sol -vv
```

#### Contract

[Templedao_exp.sol](src/test/Templedao_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1579843881893769222

https://etherscan.io/tx/0x8c3f442fc6d640a6ff3ea0b12be64f1d4609ea94edd2966f42c01cd9bdcf04b5

---

### 20221010 Carrot - Public functionCall

Testing

```sh
forge test --contracts src/test/Carrot_exp.sol -vv
```

#### Contract

[Carrot_exp.sol](src/test/Carrot_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1579908411235237888

https://bscscan.com/tx/0xa624660c29ee97f3f4ebd36232d8199e7c97533c9db711fa4027994aa11e01b9

---

### 20221009 Xave Finance - Malicious Proposal Mint & Transfer Ownership

Testing

```sh
forge test --contracts src/test/XaveFinance_exp.sol -vv
```

#### Contract

[XaveFinance_exp.sol](src/test/XaveFinance_exp.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1579040051853303808

https://etherscan.io/tx/0xc18ec2eb7d41638d9982281e766945d0428aaeda6211b4ccb6626ea7cff31f4a

---

### 20221006 RES-Token - pair manipulate

Testing

```sh
forge test --contracts src/test/RES_exp.sol -vv
```

#### Contract

[RES_exp.sol](src/test/RES_exp.sol)
[RES02_exp.sol](src/test/RES02_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1578119778446680064

https://bscscan.com/tx/0xe59fa48212c4ee716c03e648e04f0ca390f4a4fc921a890fded0e01afa4ba96d

---

### 20221002 Transit Swap - Incorrect owner address validation

Testing

```sh
forge test --contracts src/test/TransitSwap_exp.sol -vv
```

#### Contract

[TransitSwap_exp.sol](src/test/TransitSwap_exp.sol)

#### Link reference

https://twitter.com/TransitFinance/status/1576463550557483008

https://twitter.com/1nf0s3cpt/status/1576511552592543745

https://bscscan.com/tx/0x181a7882aac0eab1036eedba25bc95a16e10f61b5df2e99d240a16c334b9b189

---

### 20221001 BabySwap - Parameter Access Control

Testing

```sh
forge test --contracts ./src/test/BabySwap_exp.sol -vvv
```

#### Contract

[BabySwap_exp.sol](src/test/BabySwap_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1576441612812836865

---

### 20221001 RL Token - Incorrect Reward calculation

Testing

```sh
forge test --contracts src/test/RL_exp.sol -vv
```

#### Contract

[RL_exp.sol](src/test/RL_exp.sol)

#### Link reference

https://twitter.com/CertiKAlert/status/1576195971003858944

---

### 20221001 Thunder Brawl - Reentrancy

Testing

```sh
forge test --contracts src/test/THB_exp.sol -vv
```

#### Contract

[THB_exp.sol](src/test/THB_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1575890733373849601

https://bscscan.com/tx/0x57aa9c85e03eb25ac5d94f15f22b3ba3ab2ef60b603b97ae76f855072ea9e3a0

---

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

---

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

---

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

---

### 20220923 RADT-DAO - pair manipulate

#### Lost: 94,304 USDT

Testing

```sh
forge test --contracts ./src/test/RADT_exp.sol -vvv
```

#### Contract

[RADT_exp.sol](src/test/RADT_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1573252869322846209

https://bscscan.com/tx/0xd692f71de2768017390395db815d34033013136c378177c05d0d46ef3b6f0897

---

### 20220913 MevBot private tx

### Lost: $140 K

Testing

```sh
forge test --contracts ./src/test/BNB48MEVBot_exp.sol -vvv
```

#### Contract

[BNB48MEVBot_exp.sol](src/test/BNB48MEVBot_exp.sol)

#### Link reference

https://blocksecteam.medium.com/the-two-sides-of-the-private-tx-service-on-binance-smart-chain-a76917c3ce51

https://twitter.com/1nf0s3cpt/status/1577594615104172033

https://bscscan.com/tx/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2

---

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

---

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

---

### 20220908 NewFreeDAO - Flashloans Attack

#### Lost: 1M US$

Testing

```sh
forge test --contracts ./src/test/NewFreeDAO_exp.sol -vvv
```

#### Contract

[NewFreeDAO_exp.sol](src/test/NewFreeDAO_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1567854876633309186

https://bscscan.com/tx/0x1fea385acf7ff046d928d4041db017e1d7ead66727ce7aacb3296b9d485d4a26

---

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

https://snowtrace.io/tx/0x0ab12913f9232b27b0664cd2d50e482ad6aa896aeb811b53081712f42d54c026

---

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

https://bscscan.com/tx/0xe176bd9cfefd40dc03508e91d856bd1fe72ffc1e9260cd63502db68962b4de1a

---

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

https://bscscan.com/tx/0xe30dc75253eecec3377e03c532aa41bae1c26909bc8618f21fb83d4330a01018

---

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

---

### 20220824 LuckyTiger NFT - Predicting Random Numbers

Testing

```sh
forge test --contracts ./src/test/LuckyTiger_exp -vvv
forge script script/LuckyTiger_s_exp.sol:luckyHack --fork-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY --broadcast
```

#### Contract

[LuckyTiger_exp.sol](src/test/LuckyTiger_exp.sol) | [LuckyTiger_s_exp.sol](/script/LuckyTiger_s_exp.sol)

#### Link reference

https://twitter.com/1nf0s3cpt/status/1576117129589317633

https://etherscan.io/tx/0x804ff3801542bff435a5d733f4d8a93a535d73d0de0f843fd979756a7eab26af

---

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

---

### 20220809 ANCH - Skim token balance

Testing

```sh
forge test --contracts ./src/test/ANCH_exp.sol -vvv
```

#### Contract

[ANCH_exp.sol](src/test/ANCH_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1557527183966408706

---

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

---

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

---

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

---

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

---

### 20220723 Audius - Storage Collision & Malicious Proposal

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

---

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

https://medium.com/numen-cyber-labs/spacegodzilla-attack-event-analysis-d29a061b17e1

https://learnblockchain.cn/article/4396

https://learnblockchain.cn/article/4395 \*\*\* math behind such attack

---

### 20220710 Omni NFT - Reentrancy

#### Lost: $1.4M

Testing

```sh
forge test --contracts ./src/test/Omni_exp.sol -vv
```

#### Contract

[Omni_exp.sol](src/test/Omni_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1546379086792388609

https://etherscan.io/tx/0x05d65e0adddc5d9ccfe6cd65be4a7899ebcb6e5ec7a39787971bcc3d6ba73996

---

### 20220706 FlippazOne NFT - Access control

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

---

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

---

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

---

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

---

### 20220618 SNOOD - Miscalculation on \_spendAllowance

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

---

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

---

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

---

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

---

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

---

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

---

### 20220524 HackDao - Skim token balance

Testing

```sh
forge test --contracts ./src/test/HackDao_exp.sol -vvv
```

#### Contract

[HackDao_exp.sol](src/test/HackDao_exp.sol)

### Link reference

https://twitter.com/BlockSecTeam/status/1529084919976034304

---

### 20220517 ApeCoin (APE) - Flashloan

#### Lost: $1.1 million

buys vault token -> redeems NFTs -> claims airdrop of 60k APE -> re-supply's the pool
Testing

```sh
forge test --contracts ./src/test/Bayc_apecoin_exp.sol -vvv
```

#### Contract

[Bayc_apecoin_exp.sol](src/test/Bayc_apecoin_exp.sol)

#### Link reference

https://etherscan.io/tx/0xeb8c3bebed11e2e4fcd30cbfc2fb3c55c4ca166003c7f7d319e78eaab9747098

https://news.coincu.com/73892-the-flashloan-attack-on-the-ape-airdrop-to-claim-1-1-million-of-ape-tokens/

---

### 20220508 Fortress Loans - Malicious Proposal & Price Oracle Manipulation

#### Lost: 1,048.1 ETH + 400,000 DAI (~$3.00M)

Testing

```sh
forge test --contracts ./src/test/FortressLoans.exp.sol -vvv
```

#### Contract

[FortressLoans.exp.sol](src/test/FortressLoans.exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1523530484877209600

https://www.certik.com/resources/blog/k6eZOpnK5Kdde7RfHBZgw-fortress-loans-exploit

---

### 20220430 Saddle Finance - Swap Metapool Attack

### Lost: $10 million

Testing

```sh
forge test --contracts ./src/test/Saddle_exp.sol -vvv
```

#### Contract

[Saddle_exp.sol](src/test/Saddle_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1520330006710616064

https://medium.com/immunefi/hack-analysis-saddle-finance-april-2022-f2bcb119f38

https://github.com/Hephyrius/Immuni-Saddle-POC

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

---

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

---

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

---

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

---

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

---

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

---

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

---

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

---

### 20220411 Creat Future

#### Lost: $1.9 million

Testing

```sh
forge test --contracts ./src/test/cftoken_exp.sol -vv
```

#### Contract

[cftoken_exp.sol](src/test/cftoken_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1556497016016228358

https://bscscan.com/tx/0xc7647406542f8f2473a06fea142d223022370aa5722c044c2b7ea030b8965dd0

---

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

---

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

---

### 20220329 Redacted Cartel - Custom Approval Logic

Testing

```sh
forge test --contracts ./src/test/RedactedCartel_exp.sol -vv
```

#### Contract

[RedactedCartel_exp.sol](src/test/RedactedCartel_exp.sol)

#### Link reference

https://medium.com/immunefi/redacted-cartel-custom-approval-logic-bugfix-review-9b2d039ca2c5

---

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

---

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

---

### 20220322 CompoundTUSDSweepTokenBypass

Testing

```sh
forge test --contracts ./src/test/CompoundTusd_exp.sol -vv
```

#### Contract

[CompoundTusd_exp.sol](src/test/CompoundTusd_exp.sol)

#### Link reference

https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/

---

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

---

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

---

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

---

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

---

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

---

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

https://www.certik.com/resources/blog/5p92144WQ44Ytm1AL4Jt9X-fantasm-finance

---

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

---

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

---

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

---

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

---

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

---

### 20220128 Qubit Finance - Bridge address(0).safeTransferFrom() does not revert

#### Lost: $80 million

Testing

```sh
forge test --contracts ./src/test/Qubit_exp.sol -vv
```

#### Contract

[Qubit_exp.sol](src/test/Qubit_exp.sol)

#### Link reference

https://rekt.news/qubit-rekt/

https://medium.com/@QubitFin/protocol-exploit-report-305c34540fa3

https://etherscan.io/address/0xd01ae1a708614948b2b5e0b7ab5be6afa01325c7
https://etherscan.io/tx/0xac7292e7d0ec8ebe1c94203d190874b2aab30592327b6cc875d00f18de6f3133
https://bscscan.com/tx/0x50946e3e4ccb7d39f3512b7ecb75df66e6868b9af0eee8a7e4b61ef8a459518e

---

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

---

</details>
<details> <summary> 2021 </summary>

### 20211221 Visor Finance - Reentrancy

#### Lost: $8.2 million

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

---

### 20211218 Grim Finance - Flashloan & Reentrancy

#### Lost: $30 million

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

---

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

---

### 20211027 CreamFinance - Price Manipulation

#### Lost: $130M

Testing

```sh
 forge test --contracts ./src/test/Cream_2_exp.sol -vvv
```

#### Contract

[Cream_2_exp.sol](src/test/Cream_2_exp.sol)

#### Link reference

https://medium.com/immunefi/hack-analysis-cream-finance-oct-2021-fc222d913fc5

---

### 20211015 Indexed Finance - Price Manipulation

#### Lost: $16M

Testing

```sh
forge test --contracts src/test/IndexedFinance_exp.t.sol -vv
```

#### Contract

[IndexedFinance_exp.t.sol](src/test/IndexedFinance_exp.t.sol)

#### Link reference

https://blocksecteam.medium.com/the-analysis-of-indexed-finance-security-incident-8a62b9799836

---

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

---

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

---

### 20210915 NowSwap Platform

#### Lost: 158.28 WETH and 535,706 USDT

Testing

```sh
forge test --contracts ./src/test/NowSwap_exp.sol -vv
```

#### Contract

[NowSwap_exp.sol](src/test/NowSwap_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1438100688215560192

---

### 20210912 ZABU Finance - Deflationary token uncompatible

Testing

```sh
forge test --contracts src/test/ZABU_exp.sol -vvv
```

#### Contract

[ZABU_exp.sol](src/test/ZABU_exp.sol)

### Link reference

https://slowmist.medium.com/brief-analysis-of-zabu-finance-being-hacked-44243919ea29

---

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

---

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

https://twitter.com/creamdotfinance/status/1432249773575208964

https://etherscan.io/tx/0xa9a1b8ea288eb9ad315088f17f7c7386b9989c95b4d13c81b69d5ddad7ffe61e

---

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

---

### 20210811 Poly Network - Bridge, getting around modifier through cross-chain message

#### Lost: $611 million

Testing

```sh
forge test --contracts ./src/test/PolyNetwork/PolyNetwork_exp.sol -vv
```

#### Contract

[PolyNetwork_exp.sol](src/test/PolyNetwork/PolyNetwork_exp.sol)

#### Link reference

https://rekt.news/polynetwork-rekt/

https://slowmist.medium.com/the-root-cause-of-poly-network-being-hacked-ec2ee1b0c68f

https://etherscan.io/tx/0xb1f70464bd95b774c6ce60fc706eb5f9e35cb5f06e6cfe7c17dcda46ffd59581/advanced

https://github.com/polynetwork/eth-contracts/tree/d16252b2b857eecf8e558bd3e1f3bb14cff30e9b

https://www.breadcrumbs.app/reports/671

#### FIX

One of the biggest design lessons that people need to take away from this is: if you have cross-chain relay contracts like this, MAKE SURE THAT THEY CAN'T BE USED TO CALL SPECIAL CONTRACTS. The EthCrossDomainManager shouldn't have owned the EthCrossDomainData contract.

---

### 20210804 WaultFinace - FlashLoan price manipulation

#### Lost: 390 ETH

Testing

```sh
forge test --contracts ./src/test/WaultFinance_exp.sol -vvv
```

#### Contract

[WaultFinance_exp.sol](src/test/WaultFinance_exp.sol)

#### Link reference

https://medium.com/@Knownsec_Blockchain_Lab/wault-finance-flash-loan-security-incident-analysis-368a2e1ebb5b

https://inspexco.medium.com/wault-finance-incident-analysis-wex-price-manipulation-using-wusdmaster-contract-c344be3ed376

---

### 20210728 Levyathan Finance - (I) Lost keys and minting (II) Vulnerable emergencyWithdraw

#### Lost: $1.5 million

Testing

```sh
forge test --contracts ./src/test/Levyathan_poc.sol -vv
```

#### Contract

[Levyathan_poc.sol](src/test/Levyathan_poc.sol)

#### Link reference

https://levyathan-index.medium.com/post-mortem-levyathan-c3ff7f9a6f65

---

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

---

### 20210702 Chainswap - Bridge, logic flaw

#### Lost: $.8 million

Testing

```sh
forge test --contracts ./src/test/Chainswap_exp1.sol -vv
```

#### Contract

[Chainswap_exp1.sol](src/test/Chainswap_exp1.sol)

#### Link reference

https://chain-swap.medium.com/chainswap-post-mortem-and-compensation-plan-90cad50898ab

---

### 20210628 SafeDollar - Deflationary token uncompatible

### Lost: $.2 million

Testing

```sh
forge test --contracts src/test/SafeDollar_exp.sol -vvv
```

#### Contract

[SafeDollar_exp.sol](src/test/SafeDollar_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1409443556251430918

---

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

---

### 20210607 88mph NFT - Access control

Testing

```sh
forge test --contracts ./src/test/88mph_exp.sol -vv
```

#### Contract

[88mph_exp.sol](src/test/88mph_exp.sol)

#### Link reference

https://medium.com/immunefi/88mph-function-initialization-bug-fix-postmortem-c3a2282894d3

---

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

---

### 20210519 PancakeBunny - Price Oracle Manipulation

Testing

```sh
forge test --contracts ./src/test/PancakeBunny_exp.sol -vv
```

#### Contract

[PancakeBunny_exp.sol](src/test/PancakeBunny_exp.sol)

#### Link reference

https://rekt.news/pancakebunny-rekt/

https://bscscan.com/tx/0x897c2de73dd55d7701e1b69ffb3a17b0f4801ced88b0c75fe1551c5fcce6a979

---

### 20210509 RariCapital - Cross Contract Reentrancy

Testing

```sh
forge test --contracts ./src/test/RariCapital_exp.sol -vv
```

#### Contract

[RariCapital_exp.sol](src/test/RariCapital_exp.sol)

#### Link reference

https://rekt.news/rari-capital-rekt/

https://etherscan.com/tx/0x171072422efb5cd461546bfe986017d9b5aa427ff1c07ebe8acc064b13a7b7be

---

### 20210508 Value Defi - Cross Contract Reentrancy

Testing

```sh
forge test --contracts ./src/test/ValueDefi_exp.sol -vv
```

#### Contract

[ValueDefi_exp.sol](src/test/ValueDefi_exp.sol)

#### Link reference

https://rekt.news/rari-capital-rekt/

https://bscscan.com/tx/0xa00def91954ba9f1a1320ef582420d41ca886d417d996362bf3ac3fe2bfb9006

---

### 20210428 Uranium - Miscalculation

#### Lost: $50 million

Testing

```sh
forge test --contracts ./src/test/Uranium_exp.sol -vv
```

#### Contract

[Uranium_exp.sol](src/test/Uranium_exp.sol)

#### Link reference

https://twitter.com/FrankResearcher/status/1387347025742557186

https://bscscan.com/tx/0x5a504fe72ef7fc76dfeb4d979e533af4e23fe37e90b5516186d5787893c37991

---

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

---

### 20210305 Paid Network - Private key compromised

#### Lost: $3 million

Testing

```sh
forge test --contracts ./src/test/PAID_exp.sol -vv
```

#### Contract

[PAID_exp.sol](src/test/PAID_exp.sol)

#### Link reference

https://paidnetwork.medium.com/paid-network-attack-postmortem-march-7-2021-9e4c0fef0e07

https://etherscan.io/tx/0x4bb10927ea7afc2336033574b74ebd6f73ef35ac0db1bb96229627c9d77555a0

---

### 20210125 Sushi Badger Digg - Sandwich attack

#### Lost: 81.68 ETH

Testing

```sh
forge test --contracts src/test/Sushi-Badger_Digg.exp.sol -vvvv
```

#### Contract

[Sushi-Badger_Digg.exp.sol](src/test/Sushi-Badger_Digg.exp.sol)

#### Link reference

https://cmichel.io/replaying-ethereum-hacks-sushiswap-badger-dao-digg/

---

</details>
<details> <summary> Before 2020 </summary>

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

---

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

---

### 20201026 Harvest Finance - Flashloan Attack

#### Lost: $33.8 million

Testing

```sh
forge test --contracts ./src/test/HarvestFinance_exp.sol -vv

```

#### Contract

[HarvestFinance_exp.sol](src/test/HarvestFinance_exp.sol)

#### Link reference

https://rekt.news/harvest-finance-rekt/

https://etherscan.io/tx/0x35f8d2f572fceaac9288e5d462117850ef2694786992a8c3f6d02612277b0877

### 20200804 Opyn Protocol - msgValue in loop

Testing

```sh
forge test --contracts ./src/test/Opyn.exp.sol -vv
```

#### Contract

[Opyn.exp.sol](src/test/Opyn.exp.sol)

#### Link reference

https://medium.com/opyn/opyn-eth-put-exploit-post-mortem-1a009e3347a8

https://etherscan.io/tx/0x56de6c4bd906ee0c067a332e64966db8b1e866c7965c044163a503de6ee6552a

---

### 20200618 Bancor Protocol - Access Control

Testing

```sh
forge test --contracts ./src/test/Bancor_exp.sol -vv
```

#### Contract

[Bancor_exp.sol](src/test/Bancor_exp.sol)

#### Link reference

https://blog.bancor.network/bancors-response-to-today-s-smart-contract-vulnerability-dc888c589fe4

https://etherscan.io/address/0x5f58058c0ec971492166763c8c22632b583f667f

---

### 20180422 Beauty Chain - Integer Overflow

#### Lost: $900 million

Testing

```sh
forge test --contracts ./src/test/BEC_exp.sol -vv
```

#### Contract

[BEC_exp.sol](src/test/BEC_exp.sol)

#### Link reference

https://etherscan.io/tx/0xad89ff16fd1ebe3a0a7cf4ed282302c06626c1af33221ebe0d3a470aba4a660f

https://etherscan.io/address/0xc5d105e63711398af9bbff092d4b6769c82f793d#code

---

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

</details>

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

_Demo_

![](./AudiusPocGasReport.gif)

### Bug Reproduce

Moved to [DeFiVulnLabs](https://github.com/SunWeb3Sec/DeFiVulnLabs)

### FlashLoan Testing

Moved to [DeFiLabs](https://github.com/SunWeb3Sec/DeFiLabs)
