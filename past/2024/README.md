# DeFi Hacks Reproduce - Foundry

## 2024 - List of Past DeFi Incidents

180 incidents included.

### 20241227 Bizness - Reentrancy

### Lost: 15.7k USD

```sh
forge test --contracts ./../../src/test/2024-12/Bizness_exp.sol -vvv
```
#### Contract
[Bizness_exp.sol](../../src/test/2024-12/Bizness_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1872857132363645205

---

### 20241223 Moonhacker - improper input validation

### Lost:  318.9 k


```sh
forge test --contracts ./../../src/test/2024-12/Moonhacker_exp.sol -vvv --evm-version shanghai
```
#### Contract
[Moonhacker_exp.sol](../../src/test/2024-12/Moonhacker_exp.sol)
### Link reference

https://blog.solidityscan.com/moonhacker-vault-hack-analysis-ab122cb226f6

---

### 20241218 SlurpyCoin - Logic Flaw

### Lost: 3k USD


```sh
forge test --contracts ../../src/test/2024-12/SlurpyCoin_exp.sol -vvv
```

#### Contract

[SlurpyCoin_exp.sol](../../src/test/2024-12/SlurpyCoin_exp.sol)

### Link reference

https://x.com/CertiKAlert/status/1869580379675590731

---

### 20241216 BTC24H - Logic Flaw

### Lost: ~ $85.7K

```sh
forge test --contracts ../../src/test/2024-12/BTC24H_exp.sol -vvv
```

#### Contract

[BTC24H_exp.sol](../../src/test/2024-12/BTC24H_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1868845296945426760

---


### 20241214 JHY - Logic Flaw

### Lost: 11k BSC-USD

```sh
forge test --contracts ./src/test/2024-12/JHY_exp.sol -vvv
```
#### Contract

[JHY_exp.sol](../../src/test/2024-12/JHY_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1867950089156575317

---

### 20241210 LABUBU Token - Logic Flaw

#### Lost: 17.4 BNB (~ $12,048)

```sh
forge test --contracts ./../../src/test/2024-12/LABUBU_exp.sol -vvv
```

#### Contract

[LABUBU_exp.sol](../../src/test/2024-12/LABUBU_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1866481066610958431

---

### 20241210 CloberDEX - Reentrancy

### Lost: ~501K US$ (133.7 WETH)

```sh
forge test --contracts ./../../src/test/2024-12/CloberDEX_exp.sol -vvv --evm-version cancun
```
#### Contract
[CloberDEX_exp.sol](../../src/test/2024-12/CloberDEX_exp.sol)
### Link reference

https://x.com/peckshield/status/1866443215186088048

---

### 20241203 Pledge - Access Control

### Lost: 15K


```sh
forge test --contracts ./../../src/test/2024-12/Pledge_exp.sol -vvv --evm-version shanghai
```
#### Contract
[Pledge_exp.sol](../../src/test/2024-12/Pledge_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1864126176848965810

---

### 20241126 NFTG - Access Control

### Lost: 10k USD

```sh
forge test --contracts ./../../src/test/2024-11/NFTG_exp.sol -vvv
```
#### Contract

[NFTG_exp.sol](../../src/test/2024-11/NFTG_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1861430745572745245

---

### 20241124 Proxy_b7e1 - Logic Flaw

### Lost: 8.5k USD

```sh
forge test --contracts ./../../src/test/2024-11/proxy_b7e1_exp.sol -vvv --via-ir
```
#### Contract

[proxy_b7e1_exp.sol](../../src/test/2024-11/proxy_b7e1_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1860867560885150050

---

### 20241123 Ak1111 - Access Control

### Lost: 31.5K USD

```sh
forge test --contracts ./../../src/test/2024-11/Ak1111_exp.sol -vvv
```
#### Contract

[Ak1111_exp.sol](../../src/test/2024-11/Ak1111_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1860554838897197135

---

### 20241121 Matez - Integer Truncation

### Lost: 80k USD


```sh
forge test --contracts ./../../src/test/2024-11/Matez_exp.sol -vvv
```
#### Contract

[Matez_exp.sol](../../src/test/2024-11/Matez_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1859830885966905670

---

### 20241120 MainnetSettler - Access Control

### Lost: $66K


```sh
forge test --contracts ./../../src/test/2024-11/MainnetSettler_exp.sol -vvv --evm-version cancun
```
#### Contract
[MainnetSettler_exp.sol](../../src/test/2024-11/MainnetSettler_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1859416451473604902

---

### 20241119 PolterFinance - FlashLoan Attack

### Lost: $7M


```sh
forge test --contracts ./../../src/test/2024-11/PolterFinance_exploit.sol -vvv
```
#### Contract
[PolterFinance_exploit.sol](../../src/test/2024-11/PolterFinance_exploit.sol)
### Link reference

https://twitter.com/Bcpaintball26/status/1857865758551805976

---

### 20241117 MFT - Logic Flaw

### Lost: 33.7k USD

```sh
forge test --contracts ./../../src/test/2024-11/MFT_exp.sol -vvv
```

#### Contract

[MFT_exp.sol](../../src/test/2024-11/MFT_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1858351609371406617

---

### 20241114 vETH - Vulnerable Price Dependency

### Lost: 447k


```sh
forge test --contracts ./src/test/2024-11/vETH_exp.sol -vvv
```
#### Contract
[vETH_exp.sol](../../src/test/2024-11/vETH_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1856984299905716645

---

### 20241111 DeltaPrime - Reentrancy

### Lost: $12.9 K


```sh
forge test --contracts ./../../src/test/2024-11/DeltaPrime_exp.sol -vvv
```
#### Contract
[DeltaPrime_exp.sol](../../src/test/2024-11/DeltaPrime_exp.sol)
### Link reference

https://x.com/peckshield/status/1855910524460159197

---

### 20241109 X319 - Access Control

### Lost: $12.9 K


```sh
forge test --contracts ./../../src/test/2024-11/X319_exp.sol -vvv
```
#### Contract
[X319_exp.sol](../../src/test/2024-11/X319_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1855263208124416377

---

### 20241107 ChiSale - Logic Flaw

### Lost: $16.3 K


```sh
forge test --contracts ./../../src/test/2024-11/ChiSale_exp.sol -vvv
```
#### Contract
[ChiSale_exp.sol](../../src/test/2024-11/ChiSale_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1854357930382156107

---

### 20241107 CoW - Access Control

### Lost: $59 K


```sh
forge test --contracts ./../../src/test/2024-11/CoW_exp.sol -vvv
```
#### Contract
[CoW_exp.sol](../../src/test/2024-11/CoW_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1854538807854649791

---

### 20241107 VRug - Rug pull

### Lost: $8.4 K


```sh
forge test --contracts ./../../src/test/2024-11/VRug_exp.sol -vvv
```
#### Contract
[VRug_exp.sol](../../src/test/2024-11/VRug_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1854702463737380958

---

### 20241105 RPP - Logic Flaw

### Lost: ~ $14.1K

```sh
forge test --contracts ./../../src/test/2024-11/RPP_exp.sol -vvv
```

#### Contract
[RPP_exp.sol](../../src/test/2024-11/RPP_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1853984974309142768

---

### 20241029 BUBAI - Rug pull

### Lost: $131K


```sh
forge test --contracts ./../../src/test/2024-10/BUBAI_exp.sol -vvv
```
#### Contract
[BUBAI_exp.sol](../../src/test/2024-10/BUBAI_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1851445795918118927

---

### 20241026 CompoundFork - Flashloan attack

### Lost: $1M


```sh
forge test --contracts ./../../src/test/2024-10/CompoundFork_exploit.sol -vvv --evm-version shanghai
```
#### Contract
[CompoundFork_exploit.sol](../../src/test/2024-10/CompoundFork_exploit.sol)
### Link reference

https://x.com/Phalcon_xyz/status/1849636437349527725
https://app.blocksec.com/explorer/tx/base/0x6ab5b7b51f780e8c6c5ddaf65e9badb868811a95c1fd64e86435283074d3149e

---

### 20241022 Erc20transfer - Access Control

### Lost: $14,773.35


```sh
forge test --contracts ./../../src/test/2024-10/Erc20transfer_exp.sol -vvv
```
#### Contract
[Erc20transfer_exp.sol](../../src/test/2024-10/Erc20transfer_exp.sol)
### Link reference

https://x.com/d23e_AG/status/1849064161017225645

---

### 20241022 Vista - flashmint receive error

### Lost: $28,000


```sh
forge test --contracts ./../../src/test/2024-10/VISTA_exp.sol -vvv --evm-version cancun
```
#### Contract
[VISTA_exp.sol](../../src/test/2024-10/VISTA_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/1848403791881900130

---


### 20241013 MorphoBlue - Overpriced Asset in Oracle

### Lost: $230,000


```sh
forge test --contracts ./../../src/test/2024-10/MorphoBlue_exp.sol -vvv --evm-version shanghai
```
#### Contract
[MorphoBlue_exp.sol](../../src/test/2024-10/MorphoBlue_exp.sol)
### Link reference

https://x.com/omeragoldberg/status/1845515843787960661

---

### 20241011 P719Token - Price Manipulation Inflate Attack

### Total Lost : 547.18 BNB (~$312K USD)

```
forge test --match-contract P719Token_exp -vvv
```

#### Contract

[P719Token_exp.sol](../../src/test/2024-10/P719Token_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1844753750386426182

---

### 20241006 SASHAToken - Price Manipulation

### Total Lost : 249 ETH (~$600K USD)

```
forge test --match-contract SASHAToken_exp -vvv
```

#### Contract

[SASHAToken_exp.sol](../../src/test/2024-10/SASHAToken_exp.sol)

### Link reference

 [Pending]

---


### 20241010 HYDT - Oracle Price Manipulation

### Total Lost : 5.8k USDT

```
forge test --contracts ./../../src/test/2024-10/HYDT_exp.sol -vvv --evm-version cancun
```

#### Contract

[HYDT_exp.sol](../../src/test/2024-10/HYDT_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1844241843518951451

---

### 20241005 AIZPTToken - Wrong Price Calculation

### Total Lost : 34.88 BNB (~$20K USD)

```sh
forge test --match-contract AIZPTToken_exp -vvv
```

#### Contract

[AIZPTToken_exp.sol](../../src/test/2024-10/AIZPTToken_exp.sol)

### Link reference

 [Pending]

---

### 20241001 FireToken - Pair Manipulation With Transfer Function

### Lost: 8.45 ETH (~$20K USD)

```sh
forge test --contracts ./../../src/test/2024-10/FireToken_exp.sol -vvv
```

#### Contract

[FireToken_exp.sol](../../src/test/2024-10/FireToken_exp.sol)

### Link reference

 [Pending]

---

### 20241002 LavaLending - Price Manipulation

### Lost: 1 USDC, 125795.6 cUSDC, 0,0067 WBTC, 2.25 WETH (~$130K USD)

```sh
forge test --match-contract LavaLending_exp -vvv
```

#### Contract

[LavaLending_exp.sol](../../src/test/2024-10/LavaLending_exp.sol)

### Link reference

 [Pending]

---

### 20240926 OnyxDAO - Fake Market

### Lost: 4.1M VUSD, 7.35M XCN, 5K DAI, 0.23 WBTC, 50K USDT (>$3.8M USD)

```sh
forge test --match-contract OnyxDAO_exp -vvv
```

#### Contract

[OnyxDAO_exp.sol](../../src/test/2024-09/OnyxDAO_exp.sol)

### Link reference

https://x.com/peckshield/status/1839302663680438342

---

### 20240926 Bedrock_DeFi - Swap ETH/BTC 1/1 in mint function

### Lost: 27.83925883 BTC (~$1.7M USD)

```sh
forge test --match-contract Bedrock_DeFi_exp -vvv
```

#### Contract

[Bedrock_DeFi_exp.sol](../../src/test/2024-09/Bedrock_DeFi_exp.sol)

### Link reference

https://x.com/certikalert/status/1839403126694326374

---

### 20240924-MARA---price-manipulation

### Lost: ~8.8 WBNB (~5.3K USD)

```sh
forge test --match-contract MARA_exp -vvv

```

#### Contract

[MARA_exp.sol](/../../src/test/2024-09/MARA_exp.sol)

### Link reference

https://bscscan.com/tx/0x0fe3716431f8c2e43217c3ca6d25eed87e14d0fbfa9c9ee8ce4cef2e5ec4583c

### 20240923 Bankroll_Network - Incorrect input validation

### Lost: ~404 WBNB (~234.8K USD)

```sh
forge test --match-contract Bankroll_exp -vvv
```

#### Contract

[Bankroll_exp.sol](/../../src/test/2024-09/Bankroll_exp.sol)

### Link reference

https://x.com/Phalcon_xyz/status/1838042368018137547

---

### 20240923 PestoToken - Price Manipulation

### Lost: 1.4K

```sh
forge test --contracts ./../../src/test/2024-09/PestoToken_exp.sol -vvv
```

#### Contract

[PestoToken_exp.sol](/../../src/test/2024-09/PestoToken_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1838225968009527652

---

### 20240920 DOGGO - Logic Flaw

### Lost: 7K USD


```sh
forge test --contracts ./../../src/test/2024-09/DOGGO_exp.sol -vvv
```

#### Contract

[DOGGO_exp.sol](../../src/test/2024-09/DOGGO_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1837358462076080521

---

### 20240920 Shezmu - Access Control

### Lost: 4.9M USD


```sh
forge test --contracts ./../../src/test/2024-09/Shezmu_exp.sol -vvv
```

#### Contract

[Shezmu_exp.sol](../../src/test/2024-09/Shezmu_exp.sol)

### Link reference

https://x.com/shoucccc/status/1837228053862437244

---

### 20240918 Unverified_766a - Access control

### Lost: 100 USD

```sh
forge test --contracts ./../../src/test/2024-09/unverified_766a_exp.sol -vvv
```
#### Contract

[unverified_766a_exp.sol](../../src/test/2024-09/unverified_766a_exp.sol)

### Link reference
https://x.com/TenArmorAlert/status/1836339028616188321



---

### 20240915 WXETA - Logic Flaw

### Lost: 110K

```sh
forge test --contracts ./../../src/test/2024-09/WXETA_exp.sol -vvv
```
#### Contract

[WXETA_exp.sol](../../src/test/2024-09/WXETA_exp.sol)

### Link reference
https://x.com/TenArmorAlert/status/1835494807495659645


---

### 20240913 Unverified_5697 - Access Control

### Lost: 12K

```sh
forge test --contracts ./../../src/test/2024-09/unverified_5697_exp.sol -vvv
```
#### Contract

[unverified_5697_exp.sol](../../src/test/2024-09/unverified_5697_exp.sol)

### Link reference
https://x.com/TenArmorAlert/status/1834432197375533433

---

### 20240913 OTSeaStaking - Logic Flaw

### Lost: 26k

```sh
forge test --match-contract OTSeaStaking_exp -vvv
```
#### Contract

[OTSeaStaking_exp.sol](../../src/test/2024-09/OTSeaStaking_exp.sol)

### Link reference

---

### 20240912 Unverified_03f9 - Access Control

### Lost: 1.7k

```sh
forge test --contracts ./../../src/test/2024-09/unverified_03f9_exp.sol -vvv
```
#### Contract

[unverified_03f9_exp.sol](../../src/test/2024-09/unverified_03f9_exp.sol)

### Link reference
https://x.com/TenArmorAlert/status/1834488796953673862

---

### 20240911 INUMI - Access control

### Lost: ~11.7k USD

```sh
forge test --contracts ./../../src/test/2024-09/INUMI_exp.sol -vvv
```

#### Contract

[INUMI_exp.sol](/../../src/test/2024-09/INUMI_exp.sol)

### Link reference
https://x.com/TenArmorAlert/status/1834504921561100606

---

### 20240911 INUMI_db27 - Access control

### Lost: ~4.7k USD

```sh
forge test --contracts ./../../src/test/2024-09/IUNMI_db27_exp.sol -vvv
```

#### Contract

[IUNMI_db27_exp.sol](/../../src/test/2024-09/IUNMI_db27_exp.sol)

### Link reference
https://x.com/TenArmorAlert/status/1834503422655263099

---

### 20240911 AIRBTC_exp - Access control

### Lost: ~6.8k USD

```sh
forge test --contracts ./../../src/test/2024-09/AIRBTC_exp.sol -vvv
```

#### Contract

[AIRBTC_exp.sol](/../../src/test/2024-09/AIRBTC_exp.sol)

### Link reference
https://x.com/TenArmorAlert/status/1833825098962550802

---

### 20240910 Caterpillar_Coin_CUT - Price Manipulation

### Lost: ~1.4M USD

```sh
forge test --match-contract Caterpillar_Coin_CUT_exp -vvv --evm-version shanghai
```

#### Contract

[Caterpillar_Coin_CUT_exp.sol](/../../src/test/2024-09/Caterpillar_Coin_CUT_exp.sol)

### Link reference

https://www.certik.com/zh-CN/resources/blog/caterpillar-coin-cut-token-incident-analysis


---

### 20240905 Unverified_a89f - Access control

### Lost: 1.5k

```sh
forge test --contracts ./../../src/test/2024-09/unverified_a89f_exp.sol -vvv
```

#### Contract

[unverified_a89f_exp.sol](/../../src/test/2024-09/unverified_a89f_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1831637553415610877

---

### 20240905 PLN - Access control

### Lost: 400K USD

```sh
forge test --contracts ./../../src/test/2024-09/PLN_exp.sol -vvv
```

#### Contract

[PLN_exp.sol](/../../src/test/2024-09/PLN_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1831525062253654300


---

### 20240905 HANAToken - Price Manipulation

### Lost: 283 USD

```sh
forge test --contracts ./../../src/test/2024-09/HANAToken_exp.sol -vvv
```

#### Contract

[HANAToken_exp.sol](/../../src/test/2024-09/HANAToken_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1838963740731203737


---

### 20240904 Unverified_16d0 - Access control

### Lost: 329 USD

```sh
forge test --contracts ./../../src/test/2024-09/unverified_16d0.sol -vvv
```

#### Contract

[unverified_16d0.sol](/../../src/test/2024-09/unverified_16d0.sol)

### Link reference

https://x.com/TenArmorAlert/status/1831511554619273630


---


### 20240903 Penpiexyz_io - Reentrancy and Reward Manipulation

### Lost: 11,113.6 ETH (~$27,348,259 USD)

```sh
forge test --match-contract Penpiexyzio_exp -vvv --evm-version shanghai
```
#### Contract

[Penpiexyzio_exp.sol](../../src/test/2024-09/Penpiexyzio_exp.sol)

### Link reference

https://x.com/peckshield/status/1831072098669953388

https://x.com/AnciliaInc/status/1831080555292856476

https://x.com/hackenclub/status/1831383106554573099

post-morten: https://x.com/Penpiexyz_io/status/1831462760787452240

---

### 20240902 Pythia - Logic Flaw

### Lost: 21 ETH

```sh
forge test --contracts ./../../src/test/2024-09/Pythia_exp.sol -vvv
```
#### Contract
[Pythia_exp.sol](../../src/test/2024-09/Pythia_exp.sol)
### Link reference

https://x.com/QuillAudits_AI/status/1830976830607892649

---

### 20240828 Unverified_667d - Access control

### Lost: $10k

```sh
forge test --contracts ./../../src/test/2024-08/unverified_667d_exp.sol -vvv
```

#### Contract

[unverified_667d_exp.sol](../../src/test/2024-08/unverified_667d_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1828983569278231038

---

### 20240828 AAVE - Arbitrary Call Error

### Lost: 52000

```sh
forge test --match-contract AAVE_Repay_Adapter -vvv
```

#### Contract

[AAVE_Repay_Adapter.sol](../../src/test/2024-08/AAVE_Repay_Adapter.sol)

### Link reference

https://www.vibraniumaudits.com/post/aave-hacked-via-periphery-contract-56kstolenfromtipjar

---

### 20240820 Coco - Logic flaw

### Lost: 280BNB

```sh
forge test --contracts ./../../src/test/2024-08/COCO_exp.sol -vvv
```
#### Contract

[COCO_exp.sol](../../src/test/2024-08/COCO_exp.sol)

### Link reference

https://x.com/TenArmorAlert/status/1826101724278579639

---

### 20240816 Zenterest - Price Out Of Date

### Lost: ~21000 USD

```sh
forge test --match-contract Zenterest_exp -vvvv --evm-version shanghai
```
#### Contract

[Zenterest_exp.sol](../../src/test/2024-08/Zenterest_exp.sol)

### Link reference

 [Pending]

---

### 20240816 OMPx Contract - FlashLoan

### Lost: 4.37 ETH (~11527 USD)

```sh
forge test --match-contract OMPxContract_exp -vvv
```
#### Contract

[OMPxContract_exp.sol](../../src/test/2024-08/OMPxContract_exp.sol)

### Link reference

 [Pending]

---

### 20240814 YodlRouter - Arbitrary Call

### Lost: ~5k


```sh
forge test --match-contract YodlRouter_exp -vvv
```
#### Contract
[YodlRouter_exp.sol](../../src/test/2024-08/YodlRouter_exp.sol)
### Link reference

 [Pending]

---

### 20240813 VOW - Misconfiguration

### Lost: ~ 1M USD


```sh
forge test --match-contract VOW_exp -vvv
```
#### Contract
[VOW_exp.sol](../../src/test/2024-08/VOW_exp.sol)
### Link reference

https://x.com/Vowcurrency/status/1823407231658025300

---

### 20240812 iVest - Business logic flaw

### Lost: ~338 WBNB

```sh
forge test --match-contract IvestDao_exp -vvv
```

#### Contract

[IvestDao_exp.sol](../../src/test/2024-08/IvestDao_exp.sol)

### Link reference

https://x.com/AnciliaInc/status/1822870201698050064

---


### 20240806 Novax - Price Manipulation

### Lost: ~25K USD

```sh
forge test --match-contract NovaXM2E_exp -vvv
```

#### Contract

[NovaXM2E_exp.sol](../../src/test/2024-08/NovaXM2E_exp.sol)

### Link reference

https://x.com/EXVULSEC/status/1820676684410147276

---

### 20240801 Convergence - Incorrect input validation

### Lost: ~200K USD

```sh
forge test --match-contract Convergence_exp -vvvv --evm-version cancun
```

#### Contract

[Convergence_exp.sol](../../src/test/2024-08/Convergence_exp.sol)

### Link reference

https://x.com/DecurityHQ/status/1819030089012527510

---

### 20240724 Spectra_finance - Incorrect input validation

### Lost: ~73K USD

```sh
forge test --match-contract Spectra_finance_exp -vvv
```

#### Contract

[Spectra_finance_exp.sol](../../src/test/2024-07/Spectra_finance_exp.sol)

### Link reference

https://x.com/shoucccc/status/1815981585637990899

---

### 20240723 MEVbot_0xdd7c - Incorrect input validation

### Lost: ~18k USD

```sh
forge test --match-contract -vvv --evm-version cancun
```

#### Contract

[MEVbot_0xdd7c_exp.sol](../../src/test/2024-07/MEVbot_0xdd7c_exp.sol)

### Link reference

https://x.com/SlowMist_Team/status/1815656653100077532

---

### 20240716 Lifiprotocol - Incorrect input validation

### Lost: ~10M USD

```sh
forge test --match-contract Lifiprotocol_exp -vvv
```

#### Contract

[Lifiprotocol_exp.sol](../../src/test/2024-07/Lifiprotocol_exp.sol)

### Link reference

https://x.com/danielvf/status/1505689981385334784

---

### 20240714 Minterest - Reentrancy

### Lost: ~427 ETH

```sh
forge test --match-contract Minterest_exp -vvv
```

#### Contract

[Minterest_exp.sol](../../src/test/2024-07/Minterest_exp.sol)

### Link reference

 [Pending]

---

### 20240712 DoughFina - Incorrect input validation

### Lost: ~1.8M USD

```sh
forge test --match-contract DoughFina_exp -vvv
```

#### Contract

[DoughFina_exp.sol](../../src/test/2024-07/DoughFina_exp.sol)

### Link reference

https://x.com/CertiKAlert/status/1811668992882307478

---

### 20240711 SBT - business logic flaw

### Lost: ~56K USD

```sh
forge test --match-contract SBT_exp -vvv
```

#### Contract

[SBT_exp.sol](../../src/test/2024-07/SBT_exp.sol)

### Link reference

 [Pending]

---

### 20240711 GAX - Lack of access control

### Lost: ~50K $BUSD

```sh
forge test --match-contract GAX_exp -vvv
```

#### Contract

[GAX_exp.sol](../../src/test/2024-07/GAX_exp.sol)

### Link reference

https://x.com/EXVULSEC/status/1811348160851378333

---

### 20240708 LW - Integer Underflow

### Lost: ~7K USD

```sh
forge test --match-contract LW_exp -vvv
```

#### Contract

[LW_exp.sol](../../src/test/2024-07/LW_exp.sol)

### Link reference

 [Pending]

---

### 20240705 DeFiPlaza - loss of precision

### Lost: ~200K USD

```sh
forge test --match-contract DeFiPlaza_exp -vvv
```

#### Contract

[DeFiPlaza_exp.sol](../../src/test/2024-07/DeFiPlaza_exp.sol)

### Link reference

https://x.com/DecurityHQ/status/1809222922998808760

---

### 20240703 UnverifiedContr_0x452E25 - lack-of-access-control

### Lost: 27 ETH

```sh
forge test --match-contract UnverifiedContr_0x452E25_exp -vvv --evm-version "cancun"
```

#### Contract

[UnverifiedContr_0x452E25_exp.sol](../../src/test/2024-07/UnverifiedContr_0x452E25_exp.sol)

### Link reference

https://x.com/SlowMist_Team/status/1808334870650970514

---

### 20240702 MRP - Reentrancy

### Lost: 17 BNB

```sh
forge test --match-contract MRP_exp -vvv
```

#### Contract

[MRP_exp.sol](../../src/test/2024-07/MRP_exp.sol)

### Link reference

 [Pending]

---

### 20240628 Will - business logic flaw

### Lost: $52K

```sh
forge test --match-contract Will_exp -vvv --evm-version "shanghai"
```

#### Contract

[Will_exp.sol](../../src/test/2024-06/Will_exp.sol)

### Link reference

 [Pending]

---

### 20240627 APEMAGA - business logic flaw

### Lost: ~9 ETH

```sh
forge test --match-contract APEMAGA_exp -vvv --evm-version "shanghai"
```

#### Contract

[APEMAGA_exp.sol](../../src/test/2024-06/APEMAGA_exp.sol)

### Link reference

https://x.com/ChainAegis/status/1806297556852601282

---

### 20240618 INcufi - business logic flaw

### Lost: ~59K USD

```sh
forge test --match-contract INcufi_exp -vvv
```

#### Contract

[INcufi_exp.sol](../../src/test/2024-06/INcufi_exp.sol)

### Link reference

 [Pending]

---

### 20240617 Dyson_money - business logic flaw

### Lost: 52 BNB

```sh
forge test --match-contract Dyson_money_exp -vvv
```

#### Contract

[Dyson_money_exp.sol](../../src/test/2024-06/Dyson_money_exp.sol)

### Link reference

 [Pending]

---

### 20240616 WIFCOIN_ETH - business logic flaw

### Lost: ~3.4 ETH (WIF token)

```sh
forge test --match-contract WIFCOIN_ETH_exp -vvv --evm-version "shanghai"
```

#### Contract

[WIFCOIN_ETH_exp.sol](../../src/test/2024-06/WIFCOIN_ETH_exp.sol)

### Link reference

https://x.com/ChainAegis/status/1802550962977964139

---

### 20240616 Crb2 - business logic flaw

### Lost: ~15K

```sh
forge test --match-contract Crb2_exp -vvv --evm-version shanghai
```

#### Contract

[Crb2_exp.sol](../../src/test/2024-06/Crb2_exp.sol)

### Link reference

---

### 20240611 JokInTheBox - business logic flaw

### Lost: ~9.2 ETH

```sh
forge test --match-contract JokInTheBox_exp -vvv --evm-version cancun
```

#### Contract

[JokInTheBox_exp.sol](../../src/test/2024-06/JokInTheBox_exp.sol)

### Link reference

 [Pending]

---

### 20240610 UwULend - Price Manipulation

### Lost: 19.3M

```sh
forge test --contracts ./../../src/test/2024-06/UwuLend_First_exp.sol -vvv --evm-version shanghai
```

```sh
forge test --contracts ./../../src/test/2024-06/UwuLend_Second_exp.sol -vvv --evm-version shanghai
```

#### Contract

[UwuLend_First_exp.sol](../../src/test/2024-06/UwuLend_First_exp.sol)

[UwuLend_Second_exp.sol](../../src/test/2024-06/UwuLend_Second_exp.sol)

### Link reference

https://x.com/peckshield/status/1800176089316163831

---

### 20240610 Bazaar - Insufficient Permission Check

### Lost: 1.4M

```sh
forge test --match-contract Bazaar_exp -vvv
```

#### Contract

[Bazaar_exp.sol](../../src/test/2024-06/Bazaar_exp.sol)

### Link reference

https://x.com/shoucccc/status/1800353122159833195

---

### 20240608 YYStoken - Business Logic Flaw

### Lost: $28K

```sh
forge test --match-contract YYS_exp -vv
```

#### Contract

[YYS_exp.sol](../../src/test/2024-06/YYS_exp.sol)

### Link reference

 [Pending]

---

### 20240606 SteamSwap - Logic Flaw

### Lost: ~$91k

```sh
forge test --match-contract SteamSwap_exp -vvv --evm-version shanghai
```

#### Contract

[SteamSwap_exp.sol](../../src/test/2024-06/SteamSwap_exp.sol)

### Link reference

https://x.com/SlowMist_Team/status/1798905797440897386

---

### 20240606 MineSTM - Business Logic Flaw

### Lost: $13.8K

```sh
forge test --match-contract MineSTM_exp -vv
```

#### Contract

[MineSTM_exp.sol](../../src/test/2024-06/MineSTM_exp.sol)

### Link reference

 [Pending]

---

### 20240604 NCD - Business Logic Flaw

### Lost: $6.4K

```sh
forge test --match-contract NCD_exp -vv
```

#### Contract

[NCD_exp.sol](../../src/test/2024-06/NCD_exp.sol)

### Link reference

https://x.com/SlowMist_Team/status/1797821034319765604

---

### 20240601 VeloCore - lack-of-access-control

### Lost: $6.88M

```sh
forge test --match-contract Velocore_exp -vv
```

#### Contract

[Velocore_exp.sol](../../src/test/2024-06/Velocore_exp.sol)

### Link reference

https://x.com/BeosinAlert/status/1797247874528645333

---

### 20240531 Liquiditytokens - Business Logic Flaw

### Lost: ~200K USD

```sh
forge test --match-contract Liquiditytokens_exp -vvv
```

#### Contract

[Liquiditytokens_exp.sol](../../src/test/2024-05/Liquiditytokens_exp.sol)

### Link reference

https://x.com/EXVULSEC/status/1796499069583724638

---

### 20240531 MixedSwapRouter - Arbitrary Call

### Lost: >10700USD(WINR token)

```sh
forge test --match-contract MixedSwapRouter_exp -vvv
```

#### Contract

[MixedSwapRouter_exp.sol](../../src/test/2024-05/MixedSwapRouter_exp.sol)

### Link reference

https://x.com/ChainAegis/status/1796484286738227579

---

### 20240529 SCROLL - Integer Underflow

### Lost: 76 ETH

```sh
forge test --match-contract SCROLL_exp -vvv
```

#### Contract

[SCROLL_exp.sol](../../src/test/2024-05/SCROLL_exp.sol)

### Link reference

 [Pending]

---

### 20240529 MetaDragon - Lack of Access Control

### Lost: ~ $180k

```sh
forge test --match-contract MetaDragon_exp -vvvvv --evm-version shanghai
```

#### Contract

[MetaDragon_exp.sol](../../src/test/2024-05/MetaDragon_exp.sol)

### Link reference

https://x.com/Phalcon_xyz/status/1795746828064854497

---

### 20240528 Tradeonorion - Business Logic Flaw

### Lost: ~645K

```sh
forge test --match-contract Tradeonorion_exp -vvv
```

#### Contract

[Tradeonorion_exp.sol](../../src/test/2024-05/Tradeonorion_exp.sol)

### Link reference

https://x.com/MetaSec_xyz/status/1796008961302258001

---

### 20240528 EXcommunity - Business Logic Flaw

### Lost: 33BNB

```sh
forge test --match-contract EXcommunity_exp -vvv
```

#### Contract

[EXcommunity_exp.sol](../../src/test/2024-05/EXcommunity_exp.sol)

### Link reference

https://x.com/SlowMist_Team/status/1795648617530995130

---

### 20240527 RedKeysCoin - Weak RNG

### Lost: $12K

```sh
forge test --match-contract RedKeysCoin_exp -vvv --evm-version shanghai
```

#### Contract

[RedKeysCoin_exp.sol](../../src/test/2024-05/RedKeysCoin_exp.sol)

### Link reference

---

### 20240526 NORMIE - Business Logic Flaw

### Lost: $490K

```sh
forge test --match-contract NORMIE_exp -vv
```

#### Contract

[NORMIE_exp.sol](../../src/test/2024-05/NORMIE_exp.sol)

### Link reference

https://x.com/lookonchain/status/1794680612399542672

---

### 20240522 Burner - sandwich ack

### Lost: 1.7 eth

```sh
forge test --match-contract Burner_exp -vv
```

#### Contract

[Burner_exp.sol](../../src/test/2024-05/Burner_exp.sol)

### Link reference

 [Pending]

---

### 20240516 TCH - Signature Malleability Vulnerability

### Lost: $18K

```sh
forge test --match-contract TCH_exp -vvv
```

#### Contract

[TCH_exp.sol](../../src/test/2024-05/TCH_exp.sol)

### Link reference

https://x.com/DecurityHQ/status/1791180322882629713

---

### 20240514 Sonne Finance - Precision loss

### Lost: $20M

```sh
forge test --match-contract Sonne_exp -vvv
```

#### Contract

[Sonne_exp.sol](../../src/test/2024-05/Sonne_exp.sol)

### Link reference

https://neptunemutual.com/blog/taking-a-closer-look-at-sonne-finance-exploit/

---

### 20240514 PredyFinance - Reentrancy

### Lost: $464K

```sh
forge test --match-contract PredyFinance_exp -vvv
```

#### Contract

[PredyFinance_exp.sol](../../src/test/2024-05/PredyFinance_exp.sol)

### Link reference

https://twitter.com/Phalcon_xyz/status/1790307019590680851

---

### 20240512 TGC - Business Logic Flaw

### Lost: $32K

```sh
forge test --match-contract TGC_exp -vvv
```

#### Contract

[TGC_exp.sol](../../src/test/2024-05/TGC_exp.sol)

### Link reference

https://x.com/ChainAegis/status/1789490986588205529

---

### 20240510 GFOX - lack of access control

### Lost: 330K USD

```sh
forge test --match-contract GFOX_exp -vvv --evm-version shanghai
```

#### Contract

[GFOX_exp.sol](../../src/test/2024-05/GFOX_exp.sol)

### Link reference

https://twitter.com/CertiKAlert/status/1788751142144401886

---

### 20240510 TSURU - Insufficient Validation

### Lost: 140K

```sh
forge test --match-contract TSURU_exp -vvv --evm-version shanghai
```

#### Contract

[TSURU_exp.sol](../../src/test/2024-05/TSURU_exp.sol)

### Link reference

https://base.tsuru.wtf/usdtsuru-exploit-incident-report

---

### 20240508 GPU - self transfer

### Lost: ~32K USD

```sh
forge test --match-contract GPU_exp -vvv
```

#### Contract

[GPU_exp.sol](../../src/test/2024-05/GPU_exp.sol)

### Link reference

https://twitter.com/PeckShieldAlert/status/1788153869987611113

---

### 20240507 SATURN - Price Manipulation

### Lost: ~15 BNB

```sh
forge test --match-contract OSN_exp -vvv
```

#### Contract

[SATURN_exp.sol](../../src/test/2024-05/SATURN_exp.sol)

### Link reference

https://twitter.com/ChainAegis/status/1787667253435195841

---

### 20240506 OSN - Reward Distribution Problem

### Lost: ~109K USD

```sh
forge test --match-contract OSN_exp -vvv --evm-version shanghai
```

#### Contract

[OSN_exp.sol](../../src/test/2024-05/OSN_exp.sol)

### Link reference

https://twitter.com/SlowMist_Team/status/1787330586857861564

---

### 20240430 Yield - Business Logic Flaw

### Lost: 181K

```sh
forge test --match-contract Yield_exp -vvv
```

#### Contract

[Yield_exp.sol](../../src/test/2024-04/Yield_exp.sol)

### Link reference

https://twitter.com/peckshield/status/1785121607192817692

https://medium.com/immunefi/yield-protocol-logic-error-bugfix-review-7b86741e6f50

---

### 20240430 PikeFinance - Uninitialized Proxy

### Lost: 1.4M

```sh
forge test --match-contract PikeFinance_exp -vvv
```

#### Contract

[PikeFinance_exp.sol](../../src/test/2024-04/PikeFinance_exp.sol)

### Link reference

https://twitter.com/Phalcon_xyz/status/1785508900093194591

---

### 20240427 BNBX - precission loss

### Lost: ~75 $BNB

```sh
forge test --match-contract BNBX_exp -vvv --evm-version shanghai
```

#### Contract

[BNBX_exp.sol](../../src/test/2024-04/BNBX_exp.sol)

### Link reference

https://x.com/ChainAegis/status/1784431544557514896

---

### 20240425 NGFS - Bad Access Control

### Lost: ~190K

```sh
forge test --match-contract NGFS_exp -vvv --evm-version shanghai
```

#### Contract

[NGFS_exp.sol](../../src/test/2024-04/NGFS_exp.sol)

### Link reference

https://twitter.com/CertiKAlert/status/1783476515331616847

---

### 20240424 XBridge - Logic Flaw

### Lost: >200k USD(plus a lot of STC, SRLTY, Mazi tokens)

```sh
forge test --match-contract XBridge_exp -vvv
```

#### Contract

[XBridge_exp.sol](../../src/test/2024-04/XBridge_exp.sol)

---

### 20240424 YIEDL - Input Validation

### Lost: 150k USD

```sh
forge test --match-contract YIEDL_exp -vvv
```

#### Contract

[YIEDL_exp.sol](../../src/test/2024-04/YIEDL_exp.sol)

### 20240422 Z123 - price manipulation

### Lost: 136k USD

```sh
forge test --match-contract Z123_exp -vvv
```

#### Contract

[Z123_exp.sol](../../src/test/2024-04/Z123_exp.sol)

### Link reference

https://twitter.com/PeckShieldAlert/status/1782322484911784385

---

### 20240420 Rico - Arbitrary Call

### Lost: 36K

```sh
forge test --match-contract Rico_exp -vvv
```

#### Contract

[Rico_exp.sol](../../src/test/2024-04/Rico_exp.sol)

### Link reference

https://twitter.com/ricocreditsys/status/1781803698940781009

---

### 20240419 HedgeyFinance - Logic Flaw

### Lost: 48M USD

```sh
forge test --match-contract HedgeyFinance_exp -vvv
```

#### Contract

[HedgeyFinance_exp.sol](../../src/test/2024-04/HedgeyFinance_exp.sol)

### Link reference

https://twitter.com/Cube3AI/status/1781294512716820918

---

### 20240417 UnverifiedContr_0x00C409 - unverified external call

### Lost: ~ 18 eth

```sh
forge test --match-contract UnverifiedContr_0x00C409_exp -vvv
```

#### Contract

[UnverifiedContr_0x00C409_exp.sol](../../src/test/2024-04/UnverifiedContr_0x00C409_exp.sol)

### Link reference

https://x.com/CyversAlerts/status/1780593407871635538

---

### 20240416 SATX - Logic Flaw

### Lost: ~ 50 BNB

```sh
forge test --match-contract SATX_exp -vvv
```

#### Contract

[SATX_exp.sol](../../src/test/2024-04/SATX_exp.sol)

### Link reference

https://x.com/bbbb/status/1780341239801393479

---

### 20240416 MARS - Bad Reflection

### Lost: >100K

```sh
forge test --match-contract MARS_exp -vv
```

#### Contract

[MARS_exp.sol](../../src/test/2024-04/MARS_exp.sol)

### Link reference

https://twitter.com/Phalcon_xyz/status/1780150315603701933

---

### 20240415 GFA - business-logic-flaw

### Lost: ~14K USD

```sh
forge test --match-contract GFA_exp -vvv
```

#### Contract

[GFA_exp.sol](../../src/test/2024-04/GFA_exp.sol)

### Link reference

https://x.com/ChainAegis/status/1779809931962827055

---

### 20240415 ChaingeFinance - Arbitrary External Call 

### Lost: ~560K

```sh
forge test --match-contract ChaingeFinance_exp -vvv
```

#### Contract

[ChaingeFinance_exp.sol](../../src/test/2024-04/ChaingeFinance_exp.sol)

### Link reference

https://twitter.com/CyversAlerts/status/1779875922381860920

---

### 20240414 Hackathon - business logic flaw

### Lost: ~20K

```sh
forge test --match-contract Hackathon_exp -vvv
```

#### Contract

[Hackathon_exp.sol](../../src/test/2024-04/Hackathon_exp.sol)

### Link reference

https://x.com/EXVULSEC/status/1779519508375613827

---

### 20240412 FIL314 - Insufficient Validation And Price Manipulation

### Lost: ~14 BNB

```sh
forge test --match-contract FIL314_exp -vvv
```

#### Contract

[FIL314_exp.sol](../../src/test/2024-04/FIL314_exp.sol)

### Link reference

---

### 20240412 SumerMoney - Reentrancy

### Lost: 350K

```sh
forge test --match-contract SumerMoney_exp -vvv
```

#### Contract

[SumerMoney_exp.sol](../../src/test/2024-04/SumerMoney_exp.sol)

### Link reference

 [Pending]

---

### 20240412 GROKD - lack of access control

### Lost: $~150 BNB

```
forge test --match-contract GROKD_exp -vvv
```

#### Contract

[GROKD_exp.sol](../../src/test/2024-04/GROKD_exp.sol)

### Link reference

https://x.com/hipalex921/status/1778482890705416323?t=KvvG83s7SXr9I55aftOc6w&s=05

---

### 20240410 BigBangSwap - precission loss

### Lost: $~5K $BUSD

```
forge test --match-contract BigBangSwap_exp -vvv
```

#### Contract

[BigBangSwap_exp.sol](../../src/test/2024-04/BigBangSwap_exp.sol)

### Link reference

https://x.com/ChainAegis/status/1778254222288621912

---

### 20240409 UPS - business logic flaw

### Lost: $~28K USD

```
forge test --match-contract UPS_exp -vvv
```

#### Contract

[UPS_exp.sol](../../src/test/2024-04/UPS_exp.sol)

### Link reference

 [Pending]

---

### 20240408 SQUID - sandwich attack

### Lost: $~87K USD

```
forge test --match-contract SQUID_exp -vvv
```

#### Contract

[SQUID_exp.sol](../../src/test/2024-04/SQUID_exp.sol)

### Link reference

https://twitter.com/bbbb/status/1777228277415039304

---

### 20240404 wsm - manipulating price

### Lost: $~18K USD

```
forge test --match-contract WSM_exp -vvv
```

#### Contract

[WSM_exp.sol](../../src/test/2024-04/WSM_exp.sol)

### Link reference

https://hacked.slowmist.io/#:~:text=Hacked%20target%3A%20Wall%20Street%20Memes

---

### 20240402 HoppyFrogERC - business logic flaw

### Lost: ~0.3 ETH

```
forge test --match-contract HoppyFrogERC_exp -vvv --evm-version shanghai
```

#### Contract

[HoppyFrogERC_exp.sol](../../src/test/2024-04/HoppyFrogERC_exp.sol)

### Link reference

https://x.com/ChainAegis/status/1775351437410918420

---

### 20240401 ATM - business logic flaw

### Lost: $~182K USD

```
forge test --match-contract ATM_exp -vvv
```

#### Contract

[ATM_exp.sol](../../src/test/2024-04/ATM_exp.sol)

### Link reference

 [Pending]

---

### 20240401 OpenLeverage - business logic flaw

### Lost: ~234K

```
forge test --match-contract OpenLeverage2_exp -vvv
```

#### Contract

[OpenLeverage2_exp.sol](../../src/test/2024-04/OpenLeverage2_exp.sol)

### Link reference

 [Pending]

---

### 20240329 ETHFIN - lack of access control

### Lost: ~$1.24K (2.13 BNB)


```sh
forge test --match-contract ETHFIN_exp -vvv --evm-version shanghai
```
#### Contract

[ETHFIN_exp.sol](../../src/test/2024-03/ETHFIN_exp.sol)

### Link reference

https://app.blocksec.com/explorer/tx/bsc/0xfe031685d84f3bae1785f5b2bd0ed480b87815c3f23ce6ced73b8573b7e367c6

---

### 20240329 PrismaFi - Insufficient Validation

### Lost: $~11M

```sh
forge test --match-contract Prisma_exp -vvv
```

#### Contract

[Prisma_exp.sol](../../src/test/2024-03/Prisma_exp.sol)

### Link reference

https://twitter.com/EXVULSEC/status/1773371049951797485

---

### 20240328 LavaLending - Business Logic Flaw

### Lost: ~340K

```
forge test --match-contract LavaLending_exp -vvv
```

#### Contract

[LavaLending_exp.sol](../../src/test/2024-03/LavaLending_exp.sol)

#### Link reference

 [Pending]

https://twitter.com/Phalcon_xyz/status/1773546399713345965

https://hackmd.io/@LavaSecurity/03282024

---

### 20240325 ZongZi - Price Manipulation

### Lost: ~223K

```
forge test --match-contract ZongZi_exp -vvv
```

#### Contract

[ZongZi_exp.sol](../../src/test/2024-03/ZongZi_exp.sol)

#### Link reference

 [Pending]

---

### 20240323 CGT - Incorrect Access Control

### Lost: 996B (CGT token)

```sh
forge test --match-contract CGT_exp -vvv
```

#### Contract

[CGT_exp.sol](../../src/test/2024-03/CGT_exp.sol)

### Link reference

https://x.com/AnciliaInc/status/1771598968448745536

---

### 20240321 SSS - Token Balance Doubles on Transfer to self

### Lost: 4.8M

```sh
forge test --match-contract SSS_exp -vvv
```

#### Contract

[SSS_exp.sol](../../src/test/2024-03/SSS_exp.sol)

### Link reference

https://twitter.com/dot_pengun/status/1770989208125272481

---

### 20240324 ARK - business logic flaw

### Lost: ~348BNB

```
forge test --match-contract ARK_exp -vvv
```

#### Contract

[ARK_exp.sol](../../src/test/2024-03/ARK_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1771728823534375249

---

### 20240320 Paraswap - Incorrect Access Control

### Lost: ~24K

```
forge test --match-contract Paraswap_exp -vvv --evm-version shanghai
```

#### Contract

[Paraswap_exp.sol](../../src/test/2024-03/Paraswap_exp.sol)

#### Link reference

https://medium.com/neptune-mutual/analysis-of-the-paraswap-exploit-1f97c604b4fe

---

### 20240314 MO - business logic flaw

### Lost: ~413k USDT

```
forge test --match-contract MO_exp -vvv
```

#### Contract

[MO_exp.sol](../../src/test/2024-03/MO_exp.sol)

#### Link reference

 [Pending]

---

### 20240313 IT - business logic flaw

### Lost: ~13k USDT

```
forge test --via-ir ---match-contract IT_exp -vvv
```

#### Contract

[IT_exp.sol](../../src/test/2024-03/IT_exp.sol)

#### Link reference

 [Pending]

---

### 20240312 BBT - business logic flaw

### Lost: ~5.06 ETH

```
forge test --match-contract BBT_exp -vvv
```

#### Contract

[BBT_exp.sol](../../src/test/2024-03/BBT_exp.sol)

#### Link reference

https://x.com/8olidity/status/1767470002566058088

---

### 20240311 Binemon - precission-loss

### Lost: ~0.2 BNB

```
forge test --match-contract Binemon_exp -vvv
```

#### Contract

[Binemon_exp.sol](../../src/test/2024-03/Binemon_exp.sol)

#### Link reference

https://app.blocksec.com/explorer/tx/bsc/0x1999bb5c11a8d8bfa7620fc5cc37f5bc59c1a99d7a9250a8d6076c93bbdbeb5f

---

### 20240309 Juice - Business Logic Flaw

### Lost: ~54 ETH

```sh
forge test --match-contract Juice_exp -vvv --evm-version shanghai
```

#### Contract

[Juice_exp.sol](../../src/test/2024-03/Juice_exp.sol)

### Link reference

https://medium.com/@juicebotapp/juice-staking-exploit-next-steps-95e218b3ec71

---

### 20240309 UnizenIO - unverified external call

### Lost: ~2M

```
forge test --match-contract UnizenIO_exp -vvvv
```

#### Contract

[UnizenIO_exp.sol](../../src/test/2024-03/UnizenIO_exp.sol) | [UnizenIO2_exp.sol](../../src/test/2024-03/UnizenIO2_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1766274000534004187

https://twitter.com/AnciliaInc/status/1766261463025684707

---

### 20240307 GHT - Business Logic Flaw

### Lost: ~57K

```
forge test --match-contract GHT_exp -vvv
```

#### Contract

[GHT_exp.sol](../../src/test/2024-03/GHT_exp.sol)

#### Link reference

---

### 20240306 ALP - Public internal function

### Lost: ~10K

Testing

```
forge test --match-contract ALP_exp -vvv
```

#### Contract

[ALP_exp.sol](../../src/test/2024-03/ALP_exp.sol)

#### Link Reference

 [Pending]

---

### 20240306 TGBS - Business Logic Flaw

### Lost: ~150K

```
forge test --match-contract TGBS_exp -vvv
```

#### Contract

[TGBS_exp.sol](../../src/test/2024-03/TGBS_exp.sol)

#### Link reference

 [Pending]

https://twitter.com/Phalcon_xyz/status/1765285257949974747

---

### 20240305 Woofi - Price Manipulation

### Lost: ~8M

```
forge test --match-contract Woofi_exp -vvv
```

#### Contract

[Woofi_exp.sol](../../src/test/2024-03/Woofi_exp.sol)

#### Link reference

https://twitter.com/spreekaway/status/1765046559832764886
https://twitter.com/PeckShieldAlert/status/1765054155478175943

---

### 20240228 Seneca - Arbitrary External Call Vulnerability

### Lost: ~6M

```
forge test --match-contract Seneca_exp -vvv
```

#### Contract

[Seneca_exp.sol](../../src/test/2024-02/Seneca_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1763045563040411876

---

### 20240228 SMOOFSStaking - Reentrancy

### Lost: Unclear

```
forge test --match-contract SMOOFSStaking_exp -vvv
```

#### Contract

[SMOOFSStaking_exp.sol](../../src/test/2024-02/SMOOFSStaking_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1762893563103428783

 [Pending]

---

### 20240223 Zoomer - Business Logic Flaw

### Lost: ~14 ETH

```
forge test --match-contract Zoomer_exp -vvv --evm-version "shanghai"
```

#### Contract

[Zoomer_exp.sol](../../src/test/2024-02/Zoomer_exp.sol)

#### Link reference

https://x.com/ChainAegis/status/1761246415488225668

---

### 20240223 CompoundUni - Oracle bad price

### Lost: ~439,537 USD

```
forge test --match-contract CompoundUni_exp -vvv
```

#### Contract

[CompoundUni_exp.sol](../../src/test/2024-02/CompoundUni_exp.sol)

#### Link reference

https://twitter.com/0xLEVI104/status/1762092203894276481

---

### 20240223 BlueberryProtocol - logic flaw

### Lost: ~1,400,000 USD

```
forge test --match-contract BlueberryProtocol_exp -vvv
```

#### Contract

[BlueberryProtocol_exp.sol](../../src/test/2024-02/BlueberryProtocol_exp.sol)

#### Link reference

https://twitter.com/blueberryFDN/status/1760865357236211964

---

### 20240222 SwarmMarkets - lack of validation

### Lost: ~7k $DAI

```
forge test --match-contract SwarmMarkets_exp -vvv
```

#### Contract

[SwarmMarkets_exp.sol](../../src/test/2024-02/SwarmMarkets_exp.sol)

#### Link reference

https://app.blocksec.com/explorer/tx/eth/0xa4d7ee2ddb9db06961a17e2a5ae71743a266bcb720be138670f4a10e8dfc13e9

---

### 20240221 DeezNutz 404 - lack of validation

### Lost: ~170k

```
forge test --match-contract DeezNutz404_exp -vvv
```

#### Contract

[DeezNutz404_exp.sol](../../src/test/2024-02/DeezNutz404_exp.sol)

#### Link reference

 [Pending]

---

### 20240221 GAIN - bad function implementation

### Lost: ~6.4 ETH

```
forge test --match-contract GAIN_exp -vvv
```

#### Contract

[GAIN_exp.sol](../../src/test/2024-02/GAIN_exp.sol)

#### Link reference

 [Pending]

---

### 20240220 EGGX - reentrancy

### Lost: ~2 ETH

```
forge test --match-contract EGGX_exp -vvv
```

#### Contract

[EGGX_exp.sol](../../src/test/2024-02/EGGX_exp.sol)

#### Link reference

https://x.com/PeiQi_0/status/1759826303044497726

---

### 20240219 RuggedArt - reentrancy

### Lost: ~10k

```
forge test --match-contract RuggedArt_exp -vvv
```

#### Contract

[RuggedArt_exp.sol](../../src/test/2024-02/RuggedArt_exp.sol)

#### Link reference

https://twitter.com/EXVULSEC/status/1759822545875025953

---

### 20240216 ParticleTrade - lack of validation data

### Lost: ~50k

```
forge test --match-contract ParticleTrade_exp -vvv
```

#### Contract

[ParticleTrade_exp.sol](../../src/test/2024-02/ParticleTrade_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1758028270770250134

---

### 20240215 DualPools - precision truncation

### Lost: ~42k

```
forge test --match-contract DualPools_exp -vvvv
```

#### Contract

[DualPools_exp.sol](../../src/test/2024-02/DualPools_exp.sol)

#### Link reference

https://medium.com/@lunaray/dualpools-hack-analysis-5209233801fa

---

### 20240215 Babyloogn - lack of validation

### Lost: ~2 $BNB

```
forge test --match-contract Babyloogn_exp -vvvv
```

#### Contract

[Babyloogn_exp.sol](../../src/test/2024-02/Babyloogn_exp.sol)

#### Link reference

https://app.blocksec.com/explorer/tx/bsc/0xd081d6bb96326be5305a6c00dd51d1799971794941576554341738abc1ceb202

---

### 20240215 Miner - lack of validation dst address

### Lost: ~150k

```
forge test --match-contract Miner_exp -vvv --evm-version shanghai
```

#### Contract

[Miner_exp.sol](../../src/test/2024-02/Miner_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1757777340002681326

---

### 20240213 MINER - Price Manipulation

### Lost: ~3.5 WBNB


```sh
forge test --match-contract MINER_bsc_exp -vvv --evm-version shanghai
```
#### Contract

[MINER_bsc_exp.sol](../../src/test/2024-02/MINER_bsc_exp.sol)

### Link reference

https://app.blocksec.com/explorer/tx/bsc/0x15ab671c9bf918fa4b6a9eed9ccb527f32aca40e926ede2aec2c84dfa9c30512?line=6

---

### 20240211 Game - Reentrancy && Business Logic Flaw

### Lost: ~20 ETH

```
forge test --match-contract Game_exp -vvv
```

#### Contract

[Game_exp.sol](../../src/test/2024-02/Game_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1757533144033739116

---

### 20240210 FILX DN404 - Access Control

### Lost: 200K

```sh
forge test --match-contract DN404_exp -vvv
```

#### Contract

[DN404_exp.sol](../../src/test/2024-02/DN404_exp.sol)

---

### 20240208 Pandora - interger underflow

### Lost: ~17K USD

```
forge test --match-contract PANDORA_exp -vvv
```

#### Contract

[PANDORA_exp.sol](../../src/test/2024-02/PANDORA_exp.sol)

#### Link reference

https://twitter.com/pennysplayer/status/1766479470058406174

---

### 20240205 BurnsDefi - Price Manipulation

### Lost: ~67K

```
forge test --match-contract BurnsDefi_exp -vvv
```

#### Contract

[BurnsDefi_exp.sol](../../src/test/2024-02/BurnsDefi_exp.sol)

#### Link reference

https://twitter.com/pennysplayer/status/1754342573815238946

https://medium.com/neptune-mutual/how-was-citadel-finance-exploited-a5f9acd0b408 (similar incident)

---

### 20240202 ADC - incorrect-access-control

### Lost: ~20 eth

```
forge test --match-contract ADC_exp -vvv
```

#### Contract

[ADC_exp.sol](../../src/test/2024-02/ADC_exp.sol)

#### Link reference

https://x.com/EXVULSEC/status/1753294675971313790

---

### 20240201 AffineDeFi - lack of validation userData

### Lost: ~88K

```
forge test --match-contract AffineDeFi_exp -vvv
```

#### Contract

[AffineDeFi_exp.sol](../../src/test/2024-02/AffineDeFi_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1753020812284809440

https://twitter.com/CyversAlerts/status/1753040754287513655

---

### 20240130 XSIJ - Business Logic Flaw

### Lost: ~51K USD

```
forge test --match-contract XSIJ_exp -vvv
```

#### Contract

[XSIJ_exp.sol](../../src/test/2024-01/XSIJ_exp.sol)

#### Link reference

https://x.com/CertiKAlert/status/1752384801535918264

---

### 20240130 MIMSpell - Precission Loss

### Lost: ~6,5M

```
forge test --match-contract MIMSpell2_exp -vvv
```

#### Contract

[MIMSpell2_exp.sol](../../src/test/2024-01/MIMSpell2_exp.sol)

#### Link reference

https://twitter.com/kankodu/status/1752581744803680680

https://twitter.com/Phalcon_xyz/status/1752278614551216494

https://twitter.com/peckshield/status/1752279373779194011

https://app.blocksec.com/explorer/security-incidents

---

### 20240129 PeapodsFinance - Reentrancy

### Lost: ~1K $DAI

```
forge test --match-contract PeapodsFinance_exp -vvv
```

#### Contract

[PeapodsFinance_exp.sol](../../src/test/2024-01/PeapodsFinance_exp.sol)

#### Link reference

https://app.blocksec.com/explorer/tx/eth/0x95c1604789c93f41940a7fd9eca11276975a9a65d250b89a247736287dbd2b7e

---

### 20240128 BarleyFinance - Reentrancy

### Lost: ~130K

```
forge test --match-contract BarleyFinance_exp -vvv
```

#### Contract

[BarleyFinance_exp.sol](../../src/test/2024-01/BarleyFinance_exp.sol)

#### Link reference

https://app.blocksec.com/explorer/security-incidents

https://www.bitget.com/news/detail/12560603890246

https://twitter.com/Phalcon_xyz/status/1751788389139992824

---

### 20240127 CitadelFinance - Price Manipulation

### Lost: ~93K

```
forge test --match-contract CitadelFinance_exp -vvv
```

#### Contract

[CitadelFinance_exp.sol](../../src/test/2024-01/CitadelFinance_exp.sol)

#### Link reference

https://medium.com/neptune-mutual/how-was-citadel-finance-exploited-a5f9acd0b408

---

### 20240125 NBLGAME - Reentrancy

### Lost: ~180K

```
forge test --match-contract NBLGAME_exp -vvv
```

#### Contract

[NBLGAME_exp.sol](../../src/test/2024-01/NBLGAME_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1750526097106915453

https://twitter.com/AnciliaInc/status/1750558426382635036

---

### 20240122 DAO_SoulMate - Incorrect Access Control

### Lost: ~319K

```
forge test --match-contract DAO_SoulMate_exp -vvv --evm-version 'shanghai'
```

#### Contract

[DAO_SoulMate_exp.sol](../../src/test/2024-01/DAO_SoulMate_exp.sol)

#### Link reference

https://twitter.com/MetaSec_xyz/status/1749743245599617282

---

### 20240117 BmiZapper - Arbitrary external call vulnerability

### Lost: ~114K

```
forge test --match-contract Bmizapper_exp -vvv
```

#### Contract

[BmiZapper_exp.sol](../../src/test/2024-01/Bmizapper_exp.sol)

#### Link reference

https://x.com/0xmstore/status/1747756898172952725

---

### 20240115 Shell_MEV_0xa898 - lack of access control

### Lost: ~1K $BUSD

```
forge test --match-contract Shell_MEV_0xa898_exp -vvv
```

#### Contract

[Shell_MEV_0xa898_exp.sol](../../src/test/2024-01/Shell_MEV_0xa898_exp.sol)

#### Link reference

https://app.blocksec.com/explorer/tx/bsc/0x24f114c0ef65d39e0988d164e052ce8052fe4a4fd303399a8c1bb855e8da01e9

---

### 20240112 SocketGateway - Lack of calldata validation

### Lost: ~3.3Million $

```
forge test --match-contract SocketGateway_exp -vvv --evm-version shanghai
```

#### Contract

[SocketGateway_exp.sol](../../src/test/2024-01/SocketGateway_exp.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1747450173675196674

https://twitter.com/peckshield/status/1747353782004900274

---

### 20240112 WiseLending - Bad HealthFactor Check

### Lost: ~464K

```
forge test --match-contract WiseLending02_exp -vvv --evm-version shanghai
```

#### Contract

[WiseLending02_exp.sol](../../src/test/2024-01/WiseLending02_exp.sol)

#### Link reference

https://twitter.com/danielvf/status/1746303616778981402

---

### 20240110 Freedom - lack of access control

### Lost: 74 $WBNB

```
forge test --match-contract Freedom_exp -vvv
```

#### Contract

[Freedom_exp.sol](../../src/test/2024-01/Freedom_exp.sol)

#### Link reference

https://app.blocksec.com/explorer/tx/bsc/0x309523343cc1bb9d28b960ebf83175fac941b4a590830caccff44263d9a80ff0

---

### 20240110 LQDX - Unauthorized TransferFrom

### Lost: unknown

```
forge test --match-contract LQDX_alert_exp -vvv
```

#### Contract

[LQDX_alert_exp.sol](../../src/test/2024-01/LQDX_alert_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1744972012865671452

---

### 20240104 Gamma - Price manipulation

### Lost: ~6.3M

```
forge test --match-contract Gamma_exp -vvv
```

#### Contract

[Gamma_exp.sol](../../src/test/2024-01/Gamma_exp.sol)

#### Link reference

https://twitter.com/officer_cia/status/1742772207997050899

https://twitter.com/shoucccc/status/1742765618984829326

---

### 20240102 MIC - Business Logic Flaw

### Lost: ~500K

```
forge test --match-contract MIC_exp -vvv
```

#### Contract

[MIC_exp.sol](../../src/test/2024-01/MIC_exp.sol)

#### Link reference

https://x.com/MetaSec_xyz/status/1742484748239536173

---

### 20240102 RadiantCapital - Loss of Precision

### Lost: ~4,5M

```
forge test --match-contract RadiantCapital_exp -vvv
```

#### Contract

[RadiantCapital_exp.sol](../../src/test/2024-01/RadiantCapital_exp.sol)

#### Link reference

https://neptunemutual.com/blog/how-was-radiant-capital-exploited/

https://twitter.com/BeosinAlert/status/1742389285926678784

---

### 20240101 OrbitChain - Incorrect input validation

### Lost: ~81M

```
forge test --match-contract OrbitChain_exp -vvv
```

#### Contract

[OrbitChain_exp.sol](../../src/test/2024-01/OrbitChain_exp.sol)

#### Link reference

https://blog.solidityscan.com/orbit-chain-hack-analysis-b71c36a54a69
