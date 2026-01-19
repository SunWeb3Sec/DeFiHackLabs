# DeFi Hacks Reproduce - Foundry

## 2025 - List of Past DeFi Incidents

### 20251201 yETH - Unsafe Math

### Lost: 9M USD


```sh
forge test --contracts ./src/test/2025-12/yETH_exp.sol -vvv  --evm-version cancun
```
#### Contract
[yETH_exp.sol](../../src/test/2025-12/yETH_exp.sol)
### Link reference

https://x.com/Togbe0x/status/1995241372354539621

---

### 20251110 DRLVaultV3 - Price Manipulation

### Lost: 100k USD

```sh
forge test --contracts ./src/test/2025-11/DRLVaultV3_exp.sol -vvv
```

#### Contract
[DRLVaultV3_exp.sol](../../src/test/2025-11/DRLVaultV3_exp.sol)

### Link reference

https://blog.verichains.io/p/the-drlvaultv3-exploit-a-slippage

---

### 20251104 Moonwell - Faulty Oracle

### Lost: 1M USD

```sh
forge test --contracts ./src/test/2025-11/Moonwell_exp.sol -vvv
```

#### Contract
[Moonwell_exp.sol](../../src/test/2025-11/Moonwell_exp.sol)

### Link reference

https://x.com/CertiKAlert/status/1985620452992253973

https://www.halborn.com/blog/post/explained-the-moonwell-hack-november-2025

---

### 20251103 BalancerV2 - Precision Loss

### Lost: 120M USD

```sh
forge test --contracts ./src/test/2025-11/BalancerV2_exp.sol --via-ir -vvv
```

#### Contract
[BalancerV2_exp.sol](../../src/test/2025-11/BalancerV2_exp.sol)

### Link reference

https://x.com/BlockSecTeam/status/1986057732810518640

https://x.com/SlowMist_Team/status/1986379316935205299

https://x.com/hklst4r/status/1985872151077953827

---

### 20251020 SharwaFinance - Post Insolvency Check

### Lost: 146,000 USD

```sh
forge test --contracts ./src/test/2025-10/SharwaFinance_exp.sol -vvv
```

#### Contract
[SharwaFinance_exp.sol](../../src/test/2025-10/SharwaFinance_exp.sol)

### Link reference

https://x.com/phalcon_xyz/status/1980219745480946087?s=46

---

### 20251007 TokenHolder - Access Control

### Lost: 20 WBNB


```sh
forge test --contracts ./src/test/2025-10/TokenHolder_exp.sol -vvv --evm-version shanghai
```
#### Contract
[TokenHolder_exp.sol](../../src/test/2025-10/TokenHolder_exp.sol)
### Link reference

https://t.me/defimon_alerts/2027

---

### 20251004 Abracadabra - Logic Flaw

### Lost: 1.8M USD

```sh
forge test --contracts ./src/test/2025-10/Abracadabra_exp.sol -vv
```

#### Contract
[Abracadabra_exp.sol](../../src/test/2025-10/Abracadabra_exp.sol)

### 20251004 MIMSpell3 - Bypassed Insolvency Check

### Lost: 1.7M USD


```sh
forge test --contracts ./src/test/2025-10/MIMSpell3_exp.sol -vvv
```
#### Contract
[MIMSpell3_exp.sol](../../src/test/2025-10/MIMSpell3_exp.sol)
### Link reference

https://x.com/Phalcon_xyz/status/1974532815208485102

---

### 20250918 NGP - Price Manipulation

### Lost: 2M USD

```sh
forge test --contracts ./src/test/2025-09/NGP_exp.sol -vvv
```

#### Contract
[NGP_exp.sol](../../src/test/2025-09/NGP_exp.sol)

### Link reference

https://blog.solidityscan.com/ngp-token-hack-analysis-414b6ca16d96

---

### 20250913 Kame - Arbitary External Call

### Lost: 18167.8 USD


```sh
forge test --contracts ./src/test/2025-09/Kame_exp.sol -vvv
```
#### Contract
[Kame_exp.sol](../../src/test/2025-09/Kame_exp.sol)
### Link reference

https://x.com/SupremacyHQ/status/1966909841483636849

---

### 20250830 EverValueCoin - Arbitrage

### Lost: 100k USD


```sh
forge test --contracts ./src/test/2025-08/EverValueCoin -vvv
```
#### Contract
[EverValueCoin](../../src/test/2025-08/EverValueCoin)
### Link reference

https://x.com/SuplabsYi/status/1961906638438445268

---

### 20250831 Hexotic - Incorrect Input Validation

### Lost: 500 USD

```sh
forge test --contracts ./src/test/2025-08/Hexotic_exp.sol -vvv
```
#### Contract
[Hexotic_exp.sol](../../src/test/2025-08/Hexotic_exp.sol)

### Link reference

https://t.me/defimon_alerts/1757

---


### 20250827 0xf340 - Access Control

### Lost: 4k USD


```sh
forge test --contracts ./src/test/2025-08/0xf340_exp.sol -vvv
```
#### Contract
[0xf340_exp.sol](../../src/test/2025-08/0xf340_exp.sol)

### Link reference

https://t.me/defimon_alerts/1733

---

### 20250823 ABCCApp - Lack of Access Control

### Lost: ~ $10.1K

```sh
forge test --contracts ./src/test/2025-08/ABCCApp_exp.sol -vvv
```

#### Contract

[ABCCApp_exp.sol](../../src/test/2025-08/ABCCApp_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1959457212914352530

---

### 20250820 MulticallWithXera - Access Control

### Lost: 17k USD


```sh
forge test --contracts ./src/test/2025-08/MulticallWithXera_exp.sol -vvv --evm-version shanghai
```
#### Contract
[MulticallWithXera_exp.sol](../../src/test/2025-08/MulticallWithXera_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1958354933247590450

---

### 20250820 0x8d2e - Access Control

### Lost: 40k USDC

```sh
forge test --contracts ./src/test/2025-08/0x8d2e_exp.sol -vvv --evm-version cancun
```

#### Contract

[0x8d2e_exp.sol](../../src/test/2025-08/0x8d2e_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1958354933247590450

---

### 20250816 d3xai - Price Manipulation

### Lost: 190 BNB

```sh
forge test --contracts ./src/test/2025-08/d3xai_exp.sol -vvv
```
#### Contract

[d3xai_exp.sol](../../src/test/2025-08/d3xai_exp.sol)

### Link reference

https://x.com/suplabsyi/status/1956695597546893598

---

### 20250815 PDZ - Price Manipulation

### Lost: 3.3 BNB


```sh
forge test --contracts ./src/test/2025-08/PDZ_exp.sol -vvv
```
#### Contract

[PDZ_exp.sol](../../src/test/2025-08/PDZ_exp.sol)

### Link reference

https://x.com/tikkalaresearch/status/1957500585965678828

---

### 20250815 SizeCredit - Access Control

### Lost: 19.7k USD

```sh
forge test --contracts ./src/test/2025-08/SizeCredit_exp.sol -vvv
```

#### Contract

[SizeCredit_exp.sol](../../src/test/2025-08/SizeCredit_exp.sol)

### Link reference

https://x.com/SuplabsYi/status/1956306748073230785

---

### 20250813 YuliAI - Price Manipulation

### Lost: 78k USDT

```sh
forge test --contracts ./src/test/2025-08/YuliAI_exp.sol -vvv
```

#### Contract

[YuliAI_exp.sol](../../src/test/2025-08/YuliAI_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1955817707808432584

---

### 20250813 coinbase - Misconfiguration

### Lost: 300k USD

```sh
forge test --contracts ./src/test/2025-08/coinbase_exp.sol -vvv --evm-version cancun
```
#### Contract
[coinbase_exp.sol](../../src/test/2025-08/coinbase_exp.sol)
### Link reference

https://x.com/deeberiroz/status/1955718986894549344

---

### 20250813 Grizzifi - Logic Flaw

### Lost: 61k USD

```sh
forge test --contracts ./src/test/2025-08/Grizzifi_exp.sol -vvv
```

#### Contract

[Grizzifi_exp.sol](../../src/test/2025-08/Grizzifi_exp.sol)

### Link reference

https://x.com/MetaTrustAlert/status/1955967862276829375

---

### 20250812 Bebop - Arbitrary user input

### Lost: 21k USD


```sh
forge test --contracts ./src/test/2025-08/Bebop_dex_exp.sol -vvv
```
#### Contract
[Bebop_dex](../../src/test/2025-08/Bebop_dex_exp.sol)
### Link reference

https://x.com/SuplabsYi/status/1955230173365961128


---

### 20250811 WXC - Incorrect token burn mechanism

### Lost: 37.5 WBNB


```sh
forge test --contracts ./src/test/2025-08/WXC_Token -vvv --evm-version shanghai
```
#### Contract
[WXC_Token](../../src/test/2025-08/WXC_Token_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1954774967481962832

---

### 20250728 SuperRare - Access Control

### Lost: 730K USD

```sh
forge test --contracts ./src/test/2025-07/SuperRare_exp.sol -vvv
```
#### Contract
[SuperRare_exp.sol](../../src/test/2025-07/SuperRare_exp.sol)
### Link reference

https://x.com/SlowMist_Team/status/1949770231733530682

---

### 20250726 MulticallWithETH - arbitrary-call

### Lost: 10K USD


```sh
forge test --contracts ./src/test/2025-07/MulticallWithETH_exp.sol -vvv
```
#### Contract
[MulticallWithETH_exp.sol](../../src/test/2025-07/MulticallWithETH_exp.sol)
### Link reference


---

### 20250724 SWAPPStaking - Incorrect Reward calculation

### Lost: $32,196.28


```sh
forge test --contracts ./src/test/2025-07/SWAPPStaking_exp.sol -vvv
```
#### Contract
[SWAPPStaking_exp.sol](../../src/test/2025-07/SWAPPStaking_exp.sol)
### Link reference

https://x.com/deeberiroz/status/1947213692220710950

---

### 20250720 Stepp2p - Logic Flaw

### Lost: 43k USD


```sh
forge test --contracts ./src/test/2025-07/Stepp2p_exp.sol -vvv --evm-version shanghai
```
#### Contract
[Stepp2p_exp.sol](../../src/test/2025-07/Stepp2p_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1946887946877149520

---

### 20250717 WETC - Incorrect Burn Logic

### Lost: 101k USD


```sh
forge test --contracts ./src/test/2025-07/WETC_Token_exp.sol -vvv --evm-version shanghai
```
#### Contract
[WETC_Token_exp.sol](../../src/test/2025-07/WETC_Token_exp.sol)

### Link reference

https://t.me/evmhacks/78?single

---


### 20250716 VDS - Logic Flaw

### Lost: 13k USD

```sh
forge test --contracts ./src/test/2025-07/VDS_exp.sol -vvv
```
#### Contract

[VDS_exp.sol](../../src/test/2025-07/VDS_exp.sol)

### Link reference

https://x.com/SlowMist_Team/status/1945672192471302645

---

### 20250709 GMX - Share price manipulation

### Lost: 41M USD

```sh
forge test --contracts ./src/test/2025-07/gmx_exp.sol -vvv
```
#### Contract
[gmx_exp.sol](../../src/test/2025-07/gmx_exp.sol)

### Link reference

https://x.com/GMX_IO/status/1943336664102756471

---

### 20250705 Unverified - Access Control

### Lost: ~ $285.7K

```sh
forge test --contracts ./src/test/2025-07/unverified_54cd_exp.sol -vvv
```
#### Contract
[unverified_54cd_exp.sol](../../src/test/2025-07/unverified_54cd_exp.sol)

### Link reference
https://x.com/TenArmorAlert/status/1941689712621576493

---

### 20250705 RANT - Logic Flaw

### Lost: ~ $204K

```sh
forge test --contracts ./src/test/2025-07/RANTToken_exp.sol -vvv
```
#### Contract
[RANTToken_exp.sol](../../src/test/2025-07/RANTToken_exp.sol)

### Link reference

- https://x.com/Phalcon_xyz/status/1941788315549946225
- https://x.com/AgentLISA_ai/status/1942162643437203531

---

### 20250702 FPC - Logic Flaw

### Lost: 4.7M USDT

```sh
forge test --contracts ./src/test/2025-07/FPC_exp.sol -vvv
```

#### Contract

[FPC_exp.sol](../../src/test/2025-07/FPC_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1940423393880244327

---

### 20250629 Stead - Access Control

### Lost: 14.5k USD

```sh
forge test --contracts ./src/test/2025-06/Stead_exp.sol -vvv
```

#### Contract

[Stead_exp.sol](../../src/test/2025-06/Stead_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1939508301596672036

---

### 20250626 ResupplyFi - Share price manipulation

### Lost: 9.6M USD


```sh
forge test --contracts ./src/test/2025-06/ResupplyFi_exp.sol -vvv
```
#### Contract
[ResupplyFi_exp.sol](../../src/test/2025-06/ResupplyFi_exp.sol)
### Link reference

https://x.com/ResupplyFi/status/1938927974272938420

---


### 20250625 Unverified_b5cb - Access Control

### Lost: 2M USD


```sh
forge test --contracts ./src/test/2025-06/unverified_b5cb_exp.sol -vvv
```
#### Contract
[unverified_b5cb_exp.sol](../../src/test/2025-06/unverified_b5cb_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1937761064713941187

---


### 20250623 GradientMakerPool - Price Oracle Manipulation

### Lost: 5k USD


```sh
forge test --contracts ./src/test/2025-06/GradientMakerPool_exp.sol -vvv
```
#### Contract
[GradientMakerPool_exp.sol](../../src/test/2025-06/GradientMakerPool_exp.sol)

### Link reference

https://t.me/defimon_alerts/1339

---

### 20250620 Gangsterfinance - Incorrect dividends

### Lost: 16.5k USD


```sh
forge test --contracts ./src/test/2025-06/Gangsterfinance.sol -vvv --evm-version shanghai
```
#### Contract
[Gangsterfinance](../../src/test/2025-06/Gangsterfinance_exp.sol)
### Link reference

https://t.me/defimon_alerts/1323

---

### 20250619 BankrollStack - Incorrect dividends calculation

### Lost: 5k USD


```sh
forge test --contracts ./src/test/2025-06/BankrollStack_exp.sol -vvv --evm-version shanghai
```
#### Contract
[BankrollStack](../../src/test/2025-06/BankrollStack_exp.sol)

---

### 20250619 BankrollNetwork - Incorrect dividends calculation

### Lost: 24.5 WBNB


```sh
forge test --contracts ./src/test/2025-06/BankrollNetwork_exp.sol -vvv --evm-version shanghai
```
#### Contract
[BankrollNetwork_exp](../../src/test/2025-06/BankrollNetwork_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1935618109802459464

---

### 20250617 MetaPool - Access Control

### Lost: 25k USD


```sh
forge test --contracts ./src/test/2025-06/MetaPool_exp.sol -vvv
```
#### Contract
[MetaPool_exp.sol](../../src/test/2025-06/MetaPool_exp.sol)
### Link reference

https://x.com/peckshield/status/1934895187102454206

---

### 20250612 AAVEBoost - Logic Flaw

### Lost: 14.8K USD


```sh
forge test --contracts ./src/test/2025-06/AAVEBoost_exp.sol -vvv
```
#### Contract
[AAVEBoost_exp](../../src/test/2025-06/AAVEBoost_exp.sol)
### Link reference

https://x.com/CertiKAlert/status/1933011428157563188

---

### 20250610 Unverified_8490 - Access Control

### Lost: 48.3K USD


```sh
forge test --contracts ./src/test/2025-06/unverified_8490_exp.sol -vvv
```
#### Contract
[unverified_8490_exp](../../src/test/2025-06/unverified_8490_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1932309011564781774

---

### 20250528 Corkprotocol - Access Control

### Lost: 12M USD


```sh
forge test --contracts ./src/test/2025-05/Corkprotocol_exp.sol -vvv --via-ir --evm-version cancun
```
#### Contract
[Corkprotocol_exp](../../src/test/2025-05/Corkprotocol_exp.sol)
### Link reference

https://x.com/SlowMist_Team/status/1928100756156194955


---

### 20250527 UsualMoney - Arbitrage

### Lost: 43k USD

```sh
forge test --contracts ./src/test/2025-05/UsualMoney_exp.sol -vvv
```
#### Contract
[UsualMoney_exp.sol](../../src/test/2025-05/UsualMoney_exp.sol)

### Link reference

https://x.com/BlockSecTeam/status/1927601457815040283

---

### 20250526 YDT - Logic Flaw

### Lost: 41k USD


```sh
forge test --contracts ./src/test/2025-05/YDTtoken_exp.sol -vvv --evm-version cancun
```
#### Contract
[YDTtoken_exp](../../src/test/2025-05/YDTtoken_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1926587721885040686

---

### 20250524 RICE - Lack of Access Control

### Lost: ~ $88.1K

```sh
forge test --contracts ./src/test/2025-05/RICE_exp.sol -vvv
```

#### Contract
[RICE_exp.sol](../../src/test/2025-05/RICE_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1926461662644633770

---

### 20250520 IRYSAI - rug pull

### Lost: 69.6K USD


```sh
forge test --contracts ./src/test/2025-05/IRYSAI_exp.sol -vvv
```
#### Contract
[IRYSAI_exp](../../src/test/2025-05/IRYSAI_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1925012844052975776

---

### 20250518 KRC - deflationary token

### Lost: 7k USD


```sh
forge test --contracts ./src/test/2025-05/KRC_token_exp.sol -vvv --evm-version shanghai
```
#### Contract
[KRCToken_pair_exp](../../src/test/2025-05/KRCToken_pair_exp.sol)
### Link reference

https://x.com/CertikAIAgent/status/1924280794916536765

---

### 20250514 Unwarp - lack-of-access-control

### Lost: 9K USD


```sh
forge test --contracts ./src/test/2025-05/Unwarp_exp.sol -vvv
```
#### Contract
[Unwarp_exp.sol](../../src/test/2025-05/Unwarp_exp.sol)
### Link reference

---

### 20250511 MBUToken - Price Manipulation not confirmed

### Lost: ~2.16 M BUSD

```sh
forge test --contracts ./src/test/2025-05/MBUToken_exp.sol -vvv
```

#### Contract
[MBUToken_exp.sol](../../src/test/2025-05/MBUToken_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1921474575965065701

https://x.com/CertiKAlert/status/1921483904483000457

---

### 20250509 Nalakuvara_LotteryTicket50 - Price Manipulation

### Lost: ~ 105.5K USD

```sh
forge test --contracts ./src/test/2025-05/Nalakuvara_LotteryTicket50_exp.sol -vvv
```

#### Contract
[Nalakuvara_LotteryTicket50_exp.sol](../../src/test/2025-05/Nalakuvara_LotteryTicket50_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1920816516653617318

---

### 20250426 Lifeprotocol - Price Manipulation

### Lost: 15114 BUSD


```sh
forge test --contracts ./src/test/2025-04/Lifeprotocol_exp.sol -vvv --evm-version shanghai
```
#### Contract
[Lifeprotocol_exp.sol](../../src/test/2025-04/Lifeprotocol_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1916312483792408688

---

### 20250426 ImpermaxV3 - FlashLoan Price Oracle Manipulation

### Lost: 62,628.66 USD


```sh
forge test --contracts ./src/test/2025-04/ImpermaxV3_exp.sol -vvv
```
#### Contract
[ImpermaxV3_exp.sol](../../src/test/2025-04/ImpermaxV3_exp.sol)
### Link reference

https://medium.com/@quillaudits/how-impermax-v3-lost-300k-in-a-flashloan-attack-35b02d0cf152

---

### 20250418 BTNFT - Claim Rewards Without Protection

### Lost: 19025.9193312786235214 BUSD

```sh
forge test --contracts ./src/test/2025-04/BTNFT_exp.sol -vvv
```

#### Contract
[BTNFT_exp.sol](../../src/test/2025-04/BTNFT_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1913500336301502542

---

### 20250416 YVToken - Not Slippage Protection

### Lost: 15261.68240413121964707 BUSD

```sh
forge test --contracts ./src/test/2025-04/YBToken_exp.sol -vvv --evm-version cancun
```

#### Contract
[YBToken_exp.sol](../../src/test/2025-04/YBToken_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1912684902664782087

---

### 20250416 Roar - Rug Pull

### Lost: $777k

```sh
forge test --contracts ./src/test/2025-04/Roar_exp.sol -vvv
```

#### Contract
[Roar_exp](../../src/test/2025-04/Roar_exp.sol)

### Link reference

https://x.com/CertiKAlert/status/1912430535999189042

---

### 20250411 Unverified 0x6077 - Lack of Access Control

### Lost: ~ $62.3K

```sh
forge test --contracts ./src/test/2025-04/Unverified_6077_exp.sol -vvv
```

#### Contract
[Unverified_6077_exp](../../src/test/2025-04/Unverified_6077_exp.sol)

### Link reference

---

### 20250408 Laundromat - Logic Flaw

### Lost: 1.5K USD


```sh
forge test --contracts ./src/test/2025-04/Laundromat_exp.sol -vvv
```
#### Contract
[Laundromat_exp.sol](../../src/test/2025-04/Laundromat_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1909814943290884596

---

### 20250404 AIRWA - Access Control

### Lost: $33.6K

```sh
forge test --contracts ./src/test/2025-04/AIRWA_exp.sol -vvv
```

#### Contract
[AIRWA_exp](../../src/test/2025-04/AIRWA_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1908086092772900909


---

### 20250330 LeverageSIR - Storage SLOT1 collision

### Lost: ~ 353.8 K (17814,86 USDC, 1,4085 WBTC, 119,87 WETH)

```sh
forge test --contracts ./src/test/2025-03/LeverageSIR_exp.sol -vvv --evm-version cancun
```

#### Contract
[LeverageSIR_exp.sol](../../src/test/2025-03/LeverageSIR_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1906268185046745262

---




### 20250328 Alkimiya_IO - unsafecast

### Lost: ~ 95.5 K (1.14015390 WBTC)

```sh
forge test --contracts ./src/test/2025-03/Alkimiya_io_exp.sol -vvv
```

#### Contract
[Alkimiya_io_exp.sol](../../src/test/2025-03/Alkimiya_io_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1906371419807568119

---

### 20250327 YziAI - Rug Pull

### Lost: ~ $239.4K

```sh
forge test --contracts ./src/test/2025-03/YziAIToken_exp.sol -vvv
```

#### Contract
[YziAIToken_exp.sol](../../src/test/2025-03/YziAIToken_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1905528525785805027

---

### 20250320 BBXToken - Price Manipulation

### Lost: 11902 BUSD

```sh
forge test --contracts ./src/test/2025-03/BBXToken_exp.sol -vvv
```

#### Contract

[BBXToken_exp.sol](../../src/test/2025-03/BBXToken_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1902651550733906379

---

### 20250318 DCFToken - Lack of Slippage Protection

### Lost: ~442k


```sh
forge test --contracts ./src/test/2025-03/DCFToken_exp.sol -vvv --evm-version shanghai
```
#### Contract
[DCFToken_exp.sol](../../src/test/2025-03/DCFToken_exp.sol)
### Link reference

https://x.com/Phalcon_xyz/status/1860890801909190664

---

### 20250316 wKeyDAO - unprotected function

### Lost: 737,000


```sh
forge test --contracts ./src/test/2025-03/wKeyDAO_exp.sol -vvv --evm-version shanghai
```
#### Contract
[wKeyDAO_exp.sol](../../src/test/2025-03/wKeyDAO_exp.sol)
### Link reference

https://x.com/Phalcon_xyz/status/1900809936906711549

---

### 20250314 H2O - Weak Random Mint

### Lost: 22470 USD

```sh
forge test --contracts ./src/test/2025-03/H2O_exp.sol -vvv --evm-version cancun
```

#### Contract
[H2O_exp.sol](../../src/test/2025-03/H2O_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1900525198157205692

---

### 20250311 DUCKVADER - Free Mint Bug

### Lost: ~ $9.6K

```sh
forge test --contracts ./src/test/2025-03/DUCKVADER_exp.sol -vvv
```

#### Contract
[DUCKVADER_exp.sol](../../src/test/2025-03/DUCKVADER_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1899378096056201414

---

### 20250307 UNI - Logic Flaw

### Lost: ~ $14K

```sh
forge test --contracts ./src/test/2025-03/UNI_exp.sol -vvv
```
#### Contract
[UNI_exp](../../src/test/2025-03/UNI_exp.sol)

### Link reference

https://x.com/CertiKAlert/status/1897973904653607330

---

### 20250307 SBR Token - Price Manipulation

### Lost: ~ $18.4K

```sh
forge test --contracts ./src/test/2025-03/SBRToken_exp.sol -vvv
```
#### Contract
[SBRToken_exp](../../src/test/2025-03/SBRToken_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1897826817429442652

---

### 20250305 1inch FusionV1 Settlement - Arbitrary Yul Calldata

### Lost: 4.5M


```sh
forge test --contracts ./src/test/2025-03/OneInchFusionV1SettlementHack.sol -vvv
```
#### Contract
[OneInchFusionV1SettlementHack.sol](../../src/test/2025-03/OneInchFusionV1SettlementHack.sol)
### Link reference

[linkhere](https://blog.decurity.io/yul-calldata-corruption-1inch-postmortem-a7ea7a53bfd9)

---

### 20250304 Pump - Not Slippage Protection

### Lost: ~ $6.4K

```sh
forge test --contracts ./src/test/2025-03/Pump_exp.sol -vvv
```

#### Contract

[Pump_exp.sol](../../src/test/2025-03/Pump_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1897115993962635520

---

### 20250223 HegicOptions - Business Logic Flaw

### Lost: ~104M


```sh
forge test --contracts ./src/test/2025-02/HegicOptions_exp.sol -vvv
```
#### Contract
[HegicOptions_exp.sol](../../src/test/2025-02/HegicOptions_exp.sol)
### Link reference

 [Pending]


---

### 20250222 Unverified_35bc - Reentrancy

### Lost : $6.7K

```sh
forge test --contracts ./src/test/2025-02/unverified_35bc_exp.sol -vvv
```

#### Contract
[Unverified_35bc_exp.sol](../../src/test/2025-02/unverified_35bc_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1893333680417890648


---





### 20250221 StepHeroNFTs - Reentrancy On Sell NFT

### Lost : 137.9 BNB

```sh
forge test --contracts ./src/test/2025-02/StepHeroNFTs_exp.sol -vvv
```

#### Contract
[StepHeroNFTs_exp.sol](../../src/test/2025-02/StepHeroNFTs_exp.sol)

### Link reference

https://x.com/SlowMist_Team/status/1892822286715277344

---






### 20250221 Bybit - Phishing attack

### Lost: 1.5B


```sh
forge test --contracts ./src/test/2025-02/Bybit_exp.sol -vvv
```
#### Contract
[Bybit_exp.sol](../../src/test/2025-02/Bybit_exp.sol)
### Link reference

https://x.com/dhkleung/status/1893073663391604753

---

### 20250215 unverified_d4f1 - access-control

### Lost: ~15.2k


```sh
forge test --contracts ./src/test/2025-02/unverified_d4f1_exp.sol -vvv
```
#### Contract
[unverified_d4f1_exp.sol](../../src/test/2025-02/unverified_d4f1_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1890776122918309932

---

### 20250211 FourMeme - Logic Flaw

### Lost: ~186k


```sh
forge test --contracts ./src/test/2025-02/FourMeme_exp.sol -vvv --evm-version shanghai
```
#### Contract
[FourMeme_exp.sol](../../src/test/2025-02/FourMeme_exp.sol)
### Link reference

https://www.chaincatcher.com/en/article/2167296

---

### 20250208 Peapods Finance - Price Manipulation

### Lost: ~ $3,500

```sh
forge test --contracts ./src/test/2025-02/PeapodsFinance_exp.sol -vvv
```

#### Contract
[PeapodsFinance_exp.sol](../../src/test/2025-02/PeapodsFinance_exp.sol)

### Link reference

https://blog.solidityscan.com/peapods-finance-hack-analysis-bdc5432107a5

---

### 20250123 ODOS - invalid-signature-verification

### Lost: ~50k

```sh
forge test --contracts ./src/test/2025-01/ODOS_exp.sol -vvv
```
#### Contract
[OODS_exp.sol](../../src/test/2025-01/ODOS_exp.sol)
### Link reference

https://app.blocksec.com/explorer/tx/base/0xd10faa5b33ddb501b1dc6430896c966048271f2510ff9ed681dd6d510c5df9f6

### 20250121 Ast - Price-Manipulation

### Lost: ~65K

```sh
forge test --contracts ./src/test/2025-01/Ast_exp.sol -vvv
```
#### Contract
[Ast_exp.sol](../../src/test/2025-01/Ast_exp.sol)
### Link reference

https://medium.com/@joichiro.sai/ast-token-hack-how-a-faulty-transfer-logic-led-to-a-65k-exploit-da75aed59a43

---

### 20250118 Paribus - Bad oracle

### Lost: ~86k


```sh
forge test --contracts ./src/test/2025-01/Paribus_exp.sol -vvv
```
#### Contract
[Paribus_exp.sol](../../src/test/2025-01/Paribus_exp.sol)
### Link reference

https://app.blocksec.com/explorer/tx/arbitrum/0xf5e753d3da60db214f2261343c1e1bc46e674d2fa4b7a953eaf3c52123aeebd2?line=415

---

### 20250114 IdolsNFT - Logic Flaw

### Lost: 97 stETH


```sh
forge test --contracts ./src/test/2025-01/IdolsNFT_exp.sol -vvv
```
#### Contract
[IdolsNFT_exp.sol](../../src/test/2025-01/IdolsNFT_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1879376744161132981

---

### 20250113 Mosca2 - Logic Flaw

### Lost: 37.6K


```sh
forge test --contracts ./src/test/2025-01/Mosca2_exp.sol -vvv --evm-version shanghai
```
#### Contract
[Mosca2_exp.sol](../../src/test/2025-01/Mosca2_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1878699517450883407

---

### 20250112 Unilend - Logic Flaw

### Lost: 60 stETH


```sh
forge test --contracts ./src/test/2025-01/Unilend_exp.sol -vvv
```
#### Contract
[Unilend_exp.sol](../../src/test/2025-01/Unilend_exp.sol)
### Link reference

https://slowmist.medium.com/analysis-of-the-unilend-hack-90022fa35a54

---

### 20250111 RoulettePotV2 - Price Manipulation

### Lost: ~28K

```sh
forge test --contracts ./src/test/2025-01/RoulettePotV2_exp.sol -vvv --evm-version shanghai
```
#### Contract
[RoulettePotV2_exp.sol](../../src/test/2025-01/RoulettePotV2_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1878008055717376068

---

### 20250110 JPulsepot - Logic Flaw

### Lost: 21.5K

```sh
forge test --contracts ./src/test/2025-01/JPulsepot_exp.sol -vvv --evm-version shanghai
```
#### Contract
[JPulsepot_exp.sol](../../src/test/2025-01/JPulsepot_exp.sol)
### Link reference

https://x.com/CertiKAlert/status/1877662352834793639

---

### 20250108 HORS - Access Control

### Lost: 14.8 WBNB


```sh
forge test --contracts ./src/test/2025-01/HORS_exp.sol -vvv
```
#### Contract
[HORS_exp.sol](../../src/test/2025-01/HORS_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1877032470098428058

---

### 20250108 LPMine - Incorrect reward calculation 

### Lost: ~24k USDT

```sh
forge test --contracts ./src/test/2025-01/LPMine.sol  -vvv --evm-version cancun
```
#### Contract
[LPMine_exp.sol](../../src/test/2025-01/LPMine_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1877030261067571234

---

### 20250107 IPC Incorrect burn pairs - Logic Flaw

### Lost: ～590k USDT

```sh
forge test --contracts ./src/test/2025-01/IPC_exp.sol  -vvv --evm-version cancun
```
#### Contract
[IPC_exp.sol](../../src/test/2025-01/IPC_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1876663900663370056

---

### 20250106 Mosca - Logic Flaw

### Lost: 19K


```sh
forge test --contracts ./src/test/2025-01/Mosca_exp.sol -vvv --evm-version shanghai
```
#### Contract
[Mosca_exp.sol](../../src/test/2025-01/Mosca_exp.sol)
### Link reference

 [Pending]

---

### 20250104 SorStaking - Incorrect reward calculation

### Lost: ～8 ETH

```sh
forge test --contracts ./src/test/2025-01/sorraStaking.sol  -vv --evm-version cancun
```
#### Contract
[sorraStaking.sol](../../src/test/2025-01/sorraStaking.sol)
### Link reference

https://x.com/TenArmorAlert/status/1875582709512188394

---

### 20250104 98Token - Unprotected public function

### Lost: 28K USDT

```sh
forge test --contracts ./src/test/2025-01/98Token_exp.sol  -vvvv --evm-version cancun
```
#### Contract
[98#Token_exp.sol](../../src/test/2025-01/98Token_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1875462686353363435

---

### 20250101 LAURAToken - Pair Balance Manipulation

### Lost: 12.34 ETH (~$41.2K USD)

```sh
forge test --contracts ./src/test/2025-01/LAURAToken_exp.sol -vvv
```
#### Contract
[LAURA_exp.sol](../../src/test/2025-01/LAURAToken_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1874455664187023752

---
