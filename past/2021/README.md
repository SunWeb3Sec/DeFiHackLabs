# DeFi Hacks Reproduce - Foundry

## Before 2021 - List of Past DeFi Incidents

36 incidents included.

[20211221 Visor Finance](#20211221-visor-finance---reentrancy)

[20211218 Grim Finance](#20211218-grim-finance---flashloan--reentrancy)

[20211214 Nerve Bridge](#20211214-nerve-bridge---swap-metapool-attack)

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

[20210527 BurgerSwap](#20210527-burgerswap---mathematical-flaw--reentrancy)

[20210519 PancakeBunny](#20210519-pancakebunny---price-oracle-manipulation)

[20210508 Rari Capital](#20210509-raricapital---cross-contract-reentrancy)

[20210508 Value Defi](#20210508-value-defi---cross-contract-reentrancy)

[20210428 Uranium](#20210428-uranium---miscalculation)

[20210308 DODO](#20210308-dodo---flashloan-attack)

[20210305 Paid Network](#20210305-paid-network---private-key-compromised)

[20210125 Sushi Badger Digg](#20210125-sushi-badger-digg---sandwich-attack)

[20201229 Cover Protocol](#20201229-cover-protocol)

[20201121 Pickle Finance](#20201121-pickle-finance)

[20201026 Harvest Finance](#20201026-harvest-finance---flashloan-attack)

[20200804 Opyn Protocol](#20200804-opyn-protocol---msgValue-in-loop)

[20200618 Bancor Protocol](#20200618-bancor-protocol---access-control)

[20180422 Beauty Chain](#20180422-beauty-chain---integer-overflow)

[20171106 Parity - 'Accidentally Killed It'](#20171106-parity---accidentally-killed-it)

### 20211221 Visor Finance - Reentrancy

#### Lost: $8.2 million

Testing

```sh
forge test --contracts ./src/test/Visor_exp.t.sol -vv
```

#### Contract

[Visor_exp.t.sol](../../src/test/Visor_exp.t.sol)

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

[Grim_exp.sol](../../src/test/Grim_exp.sol)

#### Link reference

https://cointelegraph.com/news/defi-protocol-grim-finance-lost-30m-in-5x-reentrancy-hack

https://rekt.news/grim-finance-rekt/

https://ftmscan.com/tx/0x19315e5b150d0a83e797203bb9c957ec1fa8a6f404f4f761d970cb29a74a5dd6

---

### 20211214 Nerve Bridge - Swap Metapool Attack

#### Lost: 900 BNB

Testing

```sh
forge test --contracts ./src/test/NerveBridge.t.sol -vv
```

#### Contract

[NerveBridge.t.sol](src/test/NerveBridge.t.sol)

#### Link reference

https://blocksecteam.medium.com/the-analysis-of-nerve-bridge-security-incident-ead361a21025

---

### 20211130 MonoX Finance - Price Manipulation

#### Lost: $31 million

Testing

```sh
forge test --contracts ./src/test/Mono_exp.t.sol -vv
```

#### Contract

[Mono_exp.t.sol](../../src/test/Mono_exp.t.sol)

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

[Cream_2_exp.sol](../../src/test/Cream_2_exp.sol)

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

[IndexedFinance_exp.t.sol](../../src/test/IndexedFinance_exp.t.sol)

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

[Sushimiso_exp.sol](../../src/test/Sushimiso_exp.sol)

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

[Nimbus_exp.sol](../../src/test/Nimbus_exp.sol)

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

[NowSwap_exp.sol](../../src/test/NowSwap_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1438100688215560192

---

### 20210912 ZABU Finance - Deflationary token uncompatible

Testing

```sh
forge test --contracts src/test/ZABU_exp.sol -vvv
```

#### Contract

[ZABU_exp.sol](../../src/test/ZABU_exp.sol)

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

[DaoMaker_exp.sol](../../src/test/DaoMaker_exp.sol)

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

[Cream_exp.sol](../../src/test/Cream_exp.sol)

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

[XSURGE_exp.t.sol](../../src/test/XSURGE_exp.t.sol)

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

[PolyNetwork_exp.sol](../../src/test/PolyNetwork/PolyNetwork_exp.sol)

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

[WaultFinance_exp.sol](../../src/test/WaultFinance_exp.sol)

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

[Levyathan_poc.sol](../../src/test/Levyathan_poc.sol)

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

[Chainswap_exp2.sol](../../src/test/Chainswap_exp2.sol)

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

[Chainswap_exp1.sol](../../src/test/Chainswap_exp1.sol)

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

[SafeDollar_exp.sol](../../src/test/SafeDollar_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1409443556251430918

---

### 20210622 Eleven Finance - Doesn’t burn shares

Testing

```sh
forge test --contracts ./src/test/Eleven.sol -vv
```

#### Contract

[Eleven.sol](../../src/test/Eleven.sol)

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

[88mph_exp.sol](../../src/test/88mph_exp.sol)

#### Link reference

https://medium.com/immunefi/88mph-function-initialization-bug-fix-postmortem-c3a2282894d3

---

### 20210603 PancakeHunny - Incorrect calculation

Testing

```sh
forge test --contracts ./src/test/PancakeHunny_exp.sol -vv
```

#### Contract

[PancakeHunny_exp.sol](../../src/test/PancakeHunny_exp.sol)

#### Link reference

https://medium.com/hunnyfinance/pancakehunny-post-mortem-analysis-de78967401d8

https://bscscan.com/tx/0x765de8357994a206bb90af57dcf427f48a2021f2f28ca81f2c00bc3b9842be8e

---

### 20210527 BurgerSwap - Mathematical flaw + Reentrancy

Testing

```sh
forge test --contracts src/test/BurgerSwap_exp.sol -vv
```

#### Contract

[BurgerSwap_exp.sol](src/test/BurgerSwap_exp.sol)

#### Link reference
https://twitter.com/Mudit__Gupta/status/1398156036574306304

---

### 20210519 PancakeBunny - Price Oracle Manipulation

Testing

```sh
forge test --contracts ./src/test/PancakeBunny_exp.sol -vv
```

#### Contract

[PancakeBunny_exp.sol](../../src/test/PancakeBunny_exp.sol)

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

[RariCapital_exp.sol](../../src/test/RariCapital_exp.sol)

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

[ValueDefi_exp.sol](../../src/test/ValueDefi_exp.sol)

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

[Uranium_exp.sol](../../src/test/Uranium_exp.sol)

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

[dodo_flashloan_exp.sol](../../src/test/dodo_flashloan_exp.sol)

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

[PAID_exp.sol](../../src/test/PAID_exp.sol)

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

[Sushi-Badger_Digg.exp.sol](../../src/test/Sushi-Badger_Digg.exp.sol)

#### Link reference

https://cmichel.io/replaying-ethereum-hacks-sushiswap-badger-dao-digg/

---

### 20201229 Cover Protocol

Testing

```sh
forge test --contracts ./src/test/Cover_exp.sol -vv
```

#### Contract

[Cover_exp.sol](../../src/test/Cover_exp.sol)

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

[Pickle_exp.sol](../../src/test/Pickle_exp.sol)

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

[HarvestFinance_exp.sol](../../src/test/HarvestFinance_exp.sol)

#### Link reference

https://rekt.news/harvest-finance-rekt/

https://etherscan.io/tx/0x35f8d2f572fceaac9288e5d462117850ef2694786992a8c3f6d02612277b0877

### 20200804 Opyn Protocol - msgValue in loop

Testing

```sh
forge test --contracts ./src/test/Opyn.exp.sol -vv
```

#### Contract

[Opyn.exp.sol](../../src/test/Opyn.exp.sol)

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

[Bancor_exp.sol](../../src/test/Bancor_exp.sol)

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

[BEC_exp.sol](../../src/test/BEC_exp.sol)

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

[Parity_kill.sol](../../src/test/Parity_kill.sol)

#### Link reference

https://elementus.io/blog/which-icos-are-affected-by-the-parity-wallet-bug/

https://etherscan.io/tx/0x05f71e1b2cb4f03e547739db15d080fd30c989eda04d37ce6264c5686e0722c9

https://etherscan.io/tx/0x47f7cff7a5e671884629c93b368cb18f58a993f4b19c2a53a8662e3f1482f690
