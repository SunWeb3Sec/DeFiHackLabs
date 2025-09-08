# DeFi Hacks Reproduce - Foundry

## 2023 - List of Past DeFi Incidents

214 incidents included.

[20231231 Channels BUSD&USDC](#20231231-channels---price-manipulation)

[20231230 ChannelsFinance](#20231230-channelsfinance---compoundv2-inflation-attack)

[20231228 CCV](#20231225-CCV---precision-loss)

[20231228 DominoTT](#20231228-dominott---precision-loss) 

[20231225 Telcoin](#20231225-telcoin---storage-collision)

[20231222 PineProtocol](#20231222-pineprotocol---business-logic-flaw)

[20231220 TransitFinance](#20231220-transitfinance---lack-of-validation-pool)

[20231217 Bob](#20231217-bob---price-manipulation)

[20231217 FloorProtocol](#20231217-floorprotocol---business-logic-flaw)

[20231216 GoodDollar](#20231216-gooddollar---lack-of-input-validation--reentrancy)

[20231216 KEST](#20231216-kest---business-logic-flaw)

[20231216 NFTTrader](#20231216-nfttrader---reentrancy)

[20231214 PHIL](#20231214-PHIL---business-logic-flaw)

[20231213 HYPR](#20231213-hypr---business-logic-flaw)

[20231211 GoodCompound](#20231211-goodcompound---price-manipulation)

[20231209 BCT](#20231209-bct---price-manipulation)

[20231207 HNet](#20231207-HNet---business-logic-flaw)

[20231206 TIME](#20231206-time---arbitrary-address-spoofing-attack)

[20231206 ElephantStatus](#20231206-elephantstatus---price-manipulation)

[20231205 MAMO](#20231205-mamo---price-manipulation)

[20231205 BEARNDAO](#20231205-bearndao---business-logic-flaw)

[20231202 bZxProtocol](#20231202-bzxprotocol---inflation-attack)

[20231201 UnverifiedContr_0x431abb](#20231201-unverifiedcontr_0x431abb---business-logic-flaw)

[20231130 EEE](#20231130-eee---price-manipulation)

[20231130 CAROLProtocol](#20231130-carolprotocol---price-manipulation-via-reentrancy)

[20231129 Burntbubba](#20231129-burntbubba---price-manipulation)

[20231129 AIS](#20231129-ais---access-control)

[20231128 FiberRouter](#20231128-FiberRouter---input-validation)

[20231125 MetaLend](#20231125-metalend---compoundv2-inflation-attack)

[20231125 TheNFTV2](#20231125-thenftv2---logic-flaw)

[20231122 KyberSwap](#20231122-kyberswap---precision-loss)

[20231117 Token8633_9419](#20231117-token8633_9419---price-manipulation)

[20231117 ShibaToken](#20231117-shibatoken---business-logic-flaw)

[20231116 WECO](#20231116-weco---business-logic-flaw)

[20231115 EHX](#20231115-ehx---lack-of-slippage-control)

[20231115 XAI](#20231115-xai---business-logic-flaw)

[20231115 LinkDAO](#20231115-linkdao---bad-k-value-verification)

[20231114 OKC Project](#20231114-OKC-Project---Instant-Rewards-Unlocked)

[20231112 MEV_0x8c2d](#20231112-mevbot_0x8c2d---lack-of-access-control)

[20231112 MEV_0xa247](#20231112-mevbot_0xa247---incorrect-access-control)

[20231111 Mahalend](#20231111-mahalend---donate-inflation-exchangerate--rounding-error)

[20231110 Raft_fi](#20231110-raft_fi---donate-inflation-exchangerate--rounding-error)

[20231110 GrokToken](#20231110-grok---lack-of-slippage-protection)

[20231107 RBalancer](#20231107-rbalancer---business-logic-flaw)

[20231107 MEVbot](#20231107-mevbot---lack-of-access-control)

[20231106 TrustPad](#20231106-trustpad---lack-of-msgsender-address-verification)

[20231106 TheStandard_io](#20231106-thestandard_io---lack-of-slippage-protection)

[20231106 KR](#20231106-KR---precission-loss)

[20231102 BRAND](#20231102-brand---lack-of-access-control)

[20231102 3913Token](#20231102-3913token---deflationary-token-attack)

[20231101 SwampFinance](#20231101-swampfinance---business-logic-flaw)

[20231101 OnyxProtocol](#20231101-onyxprotocol---precission-loss-vulnerability)

[20231031 UniBotRouter](#20231031-UniBotRouter---arbitrary-external-call)

[20231030 LaEeb](#20231030-laeeb---lack-slippage-protection)

[20231028 AstridProtocol](#20231028-AstridProtocol---business-logic-flaw)

[20231024 MaestroRouter2](#20231024-maestrorouter2---arbitrary-external-call)

[20231022 OpenLeverage](#20231022-openleverage---business-logic-flaw)

[20231019 kTAF](#20231019-ktaf---compoundv2-inflation-attack)

[20231018 HopeLend](#20231018-hopelend---div-precision-loss)

[20231018 MicDao](#20231018-micdao---price-manipulation)

[20231013 BelugaDex](#20231013-belugadex---price-manipulation)

[20231013 WiseLending](#20231013-wiselending---donate-inflation-exchangerate--rounding-error)

[20231012 Platypus](#20231012-platypus---business-logic-flaw)

[20231011 BH](#20231011-bh---price-manipulation)

[20231008 ZS](#20231008-zs---business-logic-flaw)

[20231008 pSeudoEth](#20231008-pseudoeth---pool-manipulation)

[20231007 StarsArena](#20231007-starsarena---reentrancy)

[20231005 DePayRouter](#20231005-depayrouter---business-logic-flaw)

[20230930 FireBirdPair](#20230930-FireBirdPair---lack-slippage-protection)

[20230929 DEXRouter](#20230929-dexrouter---arbitrary-external-call)

[20230926 XSDWETHpool](#20230926-XSDWETHpool---reentrancy)

[20230924 KubSplit](#20230924-kubsplit---pool-manipulation)

[20230921 CEXISWAP](#20230921-cexiswap---incorrect-access-control)

[20230916 uniclyNFT](#20230916-uniclynft---reentrancy)

[20230911 0x0DEX](#20230911-0x0dex---parameter-manipulation)

[20230909 BFCToken](#20230909-bfctoken---business-logic-flaw)

[20230908 APIG](#20230908-apig---business-logic-flaw)

[20230907 HCT](#20230907-hct---price-manipulation)

[20230905 QuantumWN](#20230905-quantumwn---rebasing-logic-issue)

[20230905 JumpFarm](#20230905-JumpFarm---rebasing-logic-issue)

[20230905 HeavensGate](#20230905-HeavensGate---rebasing-logic-issue)

[20230905 FloorDAO](#20230905-floordao---rebasing-logic-issue)

[20230902 DAppSocial](#20230902-dappsocial---business-logic-flaw)

[20230829 EAC](#20230829-eac---price-manipulation)

[20230827 Balancer](#20230827-balancer---rounding-error--business-logic-flaw)

[20230826 SVT](#20230826-svt---flawed-price-calculation)

[20230824 GSS](#20230824-gss---skim-token-balance)

[20230821 EHIVE](#20230821-ehive---business-logic-flaw)

[20230819 BTC20](#20230819-btc20---price-manipulation)

[20230818 ExactlyProtocol](#20230818-exactlyprotocol---insufficient-validation)

[20230814 ZunamiProtocol](#20230814-zunamiprotocol---price-manipulation)

[20230809 EarningFram](#20230809-earningfram---reentrancy)

[20230802 CurveBurner](#20230802-curveburner---lack-slippage-protection)

[20230802 Uwerx](#20230802-uwerx---fault-logic)

[20230801 NeutraFinance](#20230801-neutrafinance---price-manipulation)

[20230801 LeetSwap](#20230801-leetswap---access-control)

[20230731 GYMNET](#20230731-gymnet---insufficient-validation)

[20230730 Curve](#20230730-curve---vyper-compiler-bug--reentrancy)

[20230726 Carson](#20230726-carson---price-manipulation)

[20230724 Palmswap](#20230724-palmswap---business-logic-flaw)

[20230723 MintoFinance](#20230723-mintofinance---signature-replay)

[20230722 ConicFinance02](#20230722-conic-finance-02---price-manipulation)

[20230721 ConicFinance](#20230721-conic-finance---read-only-reentrancy--misconfiguration)

[20230721 SUT](#20230721-sut---business-logic-flaw)

[20230720 Utopia](#20230720-utopia---business-logic-flaw)

[20230720 FFIST](#20230720-ffist---business-logic-flaw)

[20230718 APEDAO](#20230718-apedao---business-logic-flaw)

[20230718 BNO](#20230718-bno---invalid-emergency-withdraw-mechanism)

[20230717 NewFi](#20230717-newfi---lack-slippage-protection)

[20230715 USDTStakingContract28](#20230715-usdtstakingcontract28---lack-of-access-control)

[20230712 Platypus](#20230712-platypus---bussiness-logic-flaw)

[20230712 WGPT](#20230712-wgpt---business-logic-flaw)

[20230711 RodeoFinance](#20230711-rodeofinance---twap-oracle-manipulation)

[20230711 Libertify](#20230711-libertify---reentrancy)

[20230710 ArcadiaFi](#20230710-arcadiafi---reentrancy)

[20230708 CIVNFT](#20230708-civnft---lack-of-access-control)

[20230708 Civfund](#20230708-civfund---lack-of-access-control)

[20230707 LUSD](#20230707-LUSD---price-manipulation-attack)

[20230704 BambooIA](#20230704-bambooia---price-manipulation-attack)

[20230704 BaoCommunity](#20230704-baocommunity---donate-inflation-exchangerate--rounding-error)

[20230703 AzukiDAO](#20230703-azukidao---invalid-signature-verification)

[20230630 Biswap](#20230630-biswap---v3migrator-exploit)

[20230630 MyAi](#20230630-MyAi---business-loigc)

[20230628 Themis](#20230628-themis---manipulation-of-prices-using-flashloan)

[20230627 UnverifiedContr_9ad32](#20230627-unverifiedcontr_9ad32---business-loigc-flaw)

[20230627 STRAC](#20230627-STRAC---business-loigc)

[20230623 SHIDO](#20230623-shido---business-loigc)

[20230621 BabyDogeCoin02](#20230621-babydogecoin02---lack-slippage-protection)

[20230621 BUNN](#20230621-bunn---reflection-tokens)

[20230620 MIM](#20230620-mimspell---arbitrary-external-call-vulnerability)

[20230619 Contract_0x7657](#20230620-Contract_0x7657---business-loigc)

[20230618 ARA](#20230618-ara---incorrect-handling-of-permissions)

[20230617 MidasCapitalXYZ](#20230617-midascapitalxyz---precision-loss)

[20230617 Pawnfi](#20230617-pawnfi---business-logic-flaw)

[20230615 CFC](#20230615-cfc---uniswap-skim-token-balance-attack)

[20230615 DEPUSDT_LEVUSDC](#20230615-depusdt_levusdc---incorrect-access-control)

[20230612 Sturdy Finance](#20230612-sturdy-finance---read-only-reentrancy)

[20230611 SellToken04](#20230611-sellToken04---Price-Manipulation)

[20230607 CompounderFinance](#20230607-compounderfinance---manipulation-of-funds-through-fluctuations-in-the-amount-of-exchangeable-assets)

[20230606 VINU](#20230606-vinu---price-manipulation)

[20230606 UN](#20230606-un---price-manipulation)

[20230602 NST SimpleSwap](#20230602-nst-simple-swap---unverified-contract-wrong-approval)

[20230601 DDCoin](#20230601-ddcoin---flashloan-attack-and-smart-contract-vulnerability)

[20230601 Cellframenet](#20230601-cellframenet---calculation-issues-during-liquidity-migration)

[20230531 ERC20TokenBank](#20230531-erc20tokenbank---price-manipulation)

[20230529 Jimbo](#20230529-jimbo---protocol-specific-price-manipulation)

[20230529 BabyDogeCoin](#20230529-babydogecoin---lack-slippage-protection)

[20230529 FAPEN](#20230529-fapen---wrong-balance-check)

[20230529 NOON_NO](#20230529-noon-no---wrong-visibility-in-function)

[20230525 GPT](#20230525-gpt-token---fee-machenism-exploitation)

[20230524 LocalTrade](#20230524-local-trade-lct---improper-access-control-of-close-source-contract)

[20230524 CS](#20230524-cs-token---outdated-global-variable)

[20230523 LFI](#20230523-lfi-token---business-logic-flaw)

[20230514 landNFT](#20230514-landNFT---lack-of-permission-control)

[20230514 SellToken03](#20230514-selltoken03---unchecked-user-input)

[20230513 Bitpaidio](#20230513-bitpaidio---business-logic-flaw)

[20230513 SellToken02](#20230513-selltoken02---price-manipulation)

[20230512 LW](#20230512-lw---flashloan-price-manipulation)

[20230511 SellToken01](#20230511-selltoken01---business-logic-flaw)

[20230510 SNK](#20230510-snk---reward-calculation-error)

[20230509 MCC](#20230509-mcc---reflection-token)

[20230509 HODL](#20230509-hodl---reflection-token)

[20230506 Melo](#20230506-melo---access-control)

[20230505 DEI](#20230505-dei---wrong-implemention)

[20230503 NeverFall](#20230503-NeverFall---price-manipulation)

[20230502 Level](#20230502-level---business-logic-flaw)

[20230428 0vix](#20230428-0vix---flashloan-price-manipulation)

[20230427 SiloFinance](#20230427-Silo-finance---Business-Logic-Flaw)

[20230424 Axioma](#20230424-Axioma---business-logic-flaw)

[20230419 OLIFE](#20230419-OLIFE---Reflection-token)

[20230416 Swapos V2](#20230416-swapos-v2---error-k-value-attack)

[20230415 HundredFinance](#20230415-hundredfinance---donate-inflation-exchangerate--rounding-error)

[20230413 yearnFinance](#20230413-yearnFinance---misconfiguration)

[20230412 MetaPoint](#20230412-metapoint---Unrestricted-Approval)

[20230411 Paribus](#20230411-paribus---reentrancy)

[20230409 SushiSwap](#20230409-SushiSwap---Unchecked-User-Input)

[20230405 Sentiment](#20230405-sentiment---read-only-reentrancy)

[20230402 Allbridge](#20230402-allbridge---flashloan-price-manipulation)

[20230328 SafeMoon Hack](#20230328-safemoon-hack)

[20230328 THENA](#20230328---thena---yield-protocol-flaw)

[20230325 DBW](#20230325---dbw--business-logic-flaw)

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

[20230206 FDP Token](#20230206---fdp---reflection-token)

[20230203 Orion Protocol](#20230203---orion-protocol---reentrancy)

[20230203 Spherax USDs](#20230203---spherax-usds---balance-recalculation-bug)

[20230202 BonqDAO](#20230202---BonqDAO---price-oracle-manipulation)

[20230130 BEVO](#20230130---bevo---reflection-token)

[20230126 TomInu Token](#20230126---tinu---reflection-token)

[20230119 SHOCO Token](#20230119---shoco---reflection-token)

[20230119 ThoreumFinance](#20230119---thoreumfinance-business-logic-flaw)

[20230118 QTN Token](#20230118---qtntoken---business-logic-flaw)

[20230118 UPS Token](#20230118---upstoken---business-logic-flaw)

[20230117 OmniEstate](#20230117---OmniEstate---no-input-parameter-check)

[20230116 MidasCapital](#20230116---midascapital---read-only-reentrancy)

[20230111 UFDao](#20230111---ufdao---incorrect-parameter-setting)

[20230111 ROE](#20230111---roefinance---flashloan-price-manipulation)

[20230110 BRA](#20230110---bra---business-logic-flaw)

[20230103 GDS](#20230103---gds---business-logic-flaw)

### 20231231 Channels - Price Manipulation

### Lost: ~$4.4K

```sh
forge test --contracts ./src/test/2023-12/Channels_exp.sol -vvv --evm-version shanghai
```
#### Contract

[Channels_exp.sol](../../src/test/2023-12/Channels_exp.sol)

### Link reference

https://app.blocksec.com/explorer/tx/bsc/0xcf729a9392b0960cd315d7d49f53640f000ca6b8a0bd91866af5821fdf36afc5

---

### 20231230 ChannelsFinance - CompoundV2 Inflation Attack

### Lost: ~320K

```
forge test --contracts src/test/2023-12/ChannelsFinance_exp.sol -vvv
```

#### Contract

[ChannelsFinance_exp.sol](../../src/test/2023-12/ChannelsFinance_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1741353303542501455

---

### 20231228 CCV - Precision loss

### Lost: ~3.2K $BUSD

```
forge test --contracts src/test/2023-12/CCV_exp.sol -vvv
```

#### Contract

[CCV_exp.sol](../../src/test/2023-12/CCV_exp.sol)

#### Link reference

https://app.blocksec.com/explorer/tx/bsc/0x6ba4152db9da45f5751f2c083bf77d4b3385373d5660c51fe2e4382718afd9b4

---

### 20231228 DominoTT - Precision loss

### Lost: ~5 $WBNB

```
forge test --contracts src/test/2023-12/DominoTT_exp.sol -vvv
```

#### Contract

[DominoTT_exp.sol](../../src/test/2023-12/DominoTT_exp.sol)

#### Link reference

https://app.blocksec.com/explorer/tx/bsc/0x1ee617cd739b1afcc673a180e60b9a32ad3ba856226a68e8748d58fcccc877a8

---


### 20231225 Telcoin - Storage Collision

### Lost: ~1,24M

```
forge test --contracts ./src/test/2023-12/Telcoin_exp.sol -vvv
```

#### Contract

[Telcoin_exp.sol](../../src/test/2023-12/Telcoin_exp.sol)

#### Link reference

https://blocksec.com/phalcon/blog/telcoin-security-incident-in-depth-analysis

https://hacked.slowmist.io/?c=&page=2

---

### 20231222 PineProtocol - Business Logic Flaw

### Lost: ~90k

```
forge test --contracts ./src/test/2023-12/PineProtocol_exp.sol -vvv
```

#### Contract

[PineProtocol_exp.sol](../../src/test/2023-12/PineProtocol_exp.sol)

#### Link reference

https://medium.com/neptune-mutual/analysis-of-the-pine-protocol-exploit-e09dbcb80ca0

https://twitter.com/MistTrack_io/status/1738131780459430338

---

### 20231220 TransitFinance - Lack of Validation Pool

### Lost: ~110k

```
forge test --contracts ./src/test/2023-12/TransitFinance_exp.sol -vvv
```

#### Contract

[TransitFinance_exp.sol](../../src/test/2023-12/TransitFinance_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1737355152779030570

https://explorer.phalcon.xyz/tx/bsc/0x93ae5f0a121d5e1aadae052c36bc5ecf2d406d35222f4c6a5d63fef1d6de1081

---

### 20231217 Bob - Price Manipulation

### Lost: ~3BNB


```sh
forge test --contracts ./src/test/2023-12/Bob_exp.sol -vvv --evm-version shanghai
```
#### Contract
[Bob_exp.sol](../../src/test/2023-12/Bob_exp.sol)
### Link reference

https://bscscan.com/tx/0xfb14292a531411f852993e5a3ba4e7eb63ed548220267b9b3f4aacc5572d3a58

---

### 20231217 FloorProtocol - Business Logic Flaw

### Lost: ~$1,6M

```
forge test --contracts ./src/test/2023-12/FloorProtocol_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[FloorProtocol_exp.sol](../../src/test/2023-12/FloorProtocol_exp.sol)

#### Link reference

https://protos.com/floor-protocol-exploited-bored-apes-and-pudgy-penguins-gone/

https://twitter.com/0xfoobar/status/1736190355257627064

https://defimon.xyz/exploit/mainnet/0x7e5433f02f4bf07c4f2a2d341c450e07d7531428

---

### 20231216 GoodDollar - Lack of Input Validation & Reentrancy

### Lost: ~$2M

```
forge test --contracts ./src/test/2023-12/GoodDollar_exp.sol -vvv
```

#### Contract

[GoodDollar_exp.sol](../../src/test/2023-12/GoodDollar_exp.sol)

#### Link reference

https://twitter.com/MetaSec_xyz/status/1736428284756607386

---

### 20231216 KEST - Business Logic Flaw

### Lost: ~$2.3K

```
forge test --contracts src/test/2023-12/KEST_exp.sol -vvv
```

#### Contract

[KEST_exp.sol](../../src/test/2023-12/KEST_exp.sol)

#### Link reference

https://x.com/MetaSec_xyz/status/1736077719849623718

---

### 20231216 NFTTrader - Reentrancy

### Lost: ~$3M

```
forge test --contracts ./src/test/2023-12/NFTTrader_exp.sol -vvv
```

#### Contract

[NFTTrader_exp.sol](../../src/test/2023-12/NFTTrader_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1736263884217139333

https://twitter.com/SlowMist_Team/status/1736005523550646535

https://twitter.com/0xArhat/status/1736038250190651467

---

### 20231214 PHIL - Business Logic Flaw

### Lost: ~$2 $BNB

```
forge test --contracts ./src/test/2023-12/PHIL_exp.sol -vvv
```

#### Contract

[PHIL_exp.sol](../../src/test/2023-12/PHIL_exp.sol)

#### Link reference

https://app.blocksec.com/explorer/tx/bsc/0x20ecd8310a2cc7f7774aa5a045c8a99ad84a8451d6650f24e0911e9f4355b13a

---

### 20231213 HYPR - Business Logic Flaw

### Lost: ~$200k

```
forge test --contracts ./src/test/2023-12/HYPR_exp.sol -vvv
```

#### Contract

[HYPR_exp.sol](../../src/test/2023-12/HYPR_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1735197818883588574

---

### 20231211 GoodCompound - Price Manipulation

### Lost: ~$13K (~250 COMP Token)


```sh
forge test --contracts ./src/test/2023-12/GoodCompound_exp.sol -vvv
```
#### Contract
[GoodCompound_exp.sol](../../src/test/2023-12/GoodCompound_exp.sol)
### Link reference

https://getherscan.io/tx/0x1106418384414ed56cd7cbb9fedc66a02d39b663d580abc618f2d387348354ab

---

### 20231209 BCT - Price Manipulation

### Lost: ~10.2BNB


```sh
forge test --contracts ./src/test/2023-12/BCT_exp.sol -vvv --evm-version shanghai
```
#### Contract
[BCT_exp.sol](../../src/test/2023-12/BCT_exp.sol)
### Link reference

https://bscscan.com/tx/0xdae0b85e01670e6b6b317657a72fb560fc388664cf8bfdd9e1b0ae88e0679103

---

### 20231207 HNet - Business logic flaw

### Lost: ~2.4 $WBNB

```
forge test --contracts src/test/2023-12/HNet_exp.sol -vvv
```

#### Contract

[HNet_exp.sol](../../src/test/2023-12/HNet_exp.sol)

#### Link reference

https://app.blocksec.com/explorer/tx/bsc/0x67af906c1efc05067a01f197bd780ebf4e0a76729d54288a400e715f87ea50c7

---

### 20231206 TIME - Arbitrary Address Spoofing Attack

### Lost: ~84.59 ETH

Test

```
forge test --contracts ./src/test/2023-12/TIME_exp.sol -vvv
```

#### Contract

[TIME_exp.sol](../../src/test/2023-12/TIME_exp.sol)

#### Link reference

https://blog.openzeppelin.com/arbitrary-address-spoofing-vulnerability-erc2771context-multicall-public-disclosure

---

### 20231206 ElephantStatus - Price Manipulation

### Lost: ~$165k

Test

```
forge test --contracts ./src/test/2023-12/ElephantStatus_exp.sol -vvv
```

#### Contract

[ElephantStatus_exp.sol](../../src/test/2023-12/ElephantStatus_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1732354930529435940

---

### 20231205 MAMO - Price Manipulation

### Lost: ~$3.3K


```sh
forge test --contracts ./src/test/2023-12/MAMO_exp.sol -vvv --evm-version shanghai
```
#### Contract
[MAMO_exp.sol](../../src/test/2023-12/MAMO_exp.sol)
### Link reference

https://bscscan.com/tx/0x189a8dc1e0fea34fd7f5fa78c6e9bdf099a8d575ff5c557fa30d90c6acd0b29f

---

### 20231205 BEARNDAO - Business Logic Flaw

### Lost: ~$769k

Test

```
forge test --contracts ./src/test/2023-12/BEARNDAO_exp.sol -vvv
```

#### Contract

[BEARNDAO_exp.sol](../../src/test/2023-12/BEARNDAO_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1732159377749180646

---

### 20231202 bZxProtocol - Inflation Attack

### Lost: ~$208k

Test

```
forge test --contracts ./src/test/2023-12/bZx_exp.sol -vvv
```

#### Contract

[bZx_exp.sol](../../src/test/2023-12/bZx_exp.sol)

#### Link reference

https://x.com/MetaSec_xyz/status/1730811240942088263

---

### 20231201 UnverifiedContr_0x431abb - Business Logic Flaw

### Lost: ~$500k

Test

```
forge test --contracts ./src/test/2023-12/UnverifiedContr_0x431abb_exp.sol -vvv
```

#### Contract

[UnverifiedContr_0x431abb_exp.sol](../../src/test/2023-12/UnverifiedContr_0x431abb_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1730625352953901123

---

### 20231130 EEE - Price Manipulation

### Lost: ~$22.8K

```sh
forge test --contracts ./src/test/2023-11/EEE_exp.sol -vvv --evm-version shanghai
```

#### Contract

[EEE_exp.sol](../../src/test/2023-11/EEE_exp.sol)

### Link reference

https://bscscan.com/tx/0x7312d9f9c13fc69f00f58e92a112a3e7f036ced7e65f7e0fa67382488d5557dc

---

### 20231130 CAROLProtocol - Price Manipulation Via Reentrancy

### Lost: ~$53k

Testing

```sh
forge test --contracts ./src/test/2023-11/CAROLProtocol_exp.sol -vvv
```

#### Contract

[CAROLProtocol_exp.sol](../../src/test/2023-11/CAROLProtocol_exp.sol)

#### Link reference

https://x.com/MetaSec_xyz/status/1730496513359647167

---

### 20231129 Burntbubba - Price Manipulation

### Lost: ~$3K

Testing

```sh
forge test --contracts src/test/2023-11/Burntbubba_exp.sol -vvv
```

#### Contract

[Burntbubba_exp.sol](../../src/test/2023-11/Burntbubba_exp.sol)

#### Link reference

https://x.com/MetaSec_xyz/status/1730044259087315046

---

### 20231129  AIS - Insufficient validation

### Lost: ~$61k

Testing

```sh
forge test --contracts ./src/test/2023-11/AIS_exp.sol -vvv
```

#### Contract

[AIS_exp.sol](../../src/test/2023-11/AIS_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1729861048004391306

---

### 20231128 FiberRouter - input validation

### Lost: 18 eth

Testing

```sh
forge test --contracts ./src/test/2023-11/FiberRouter_exp.sol -vvv
```

#### Contract

[FiberRouter_exp.sol](../../src/test/2023-11/FiberRouter_exp.sol)

#### Link reference

https://x.com/MetaSec_xyz/status/1729323254610002277

---

### 20231125 MetaLend - CompoundV2 Inflation Attack

### Lost: ~$4K

Test

```
forge test --contracts src/test/2023-11/MetaLend_exp.sol -vvv
```

#### Contract

[MetaLend_exp.sol](../../src/test/2023-11/MetaLend_exp.sol)

#### Link Reference

https://x.com/MetaSec_xyz/status/1728424965257691173

---

### 20231125 TheNFTV2 - logic flaw

### Lost: ~$19K

Test

```
forge test --contracts ./src/test/2023-11/TheNFTV2_exp.sol -vvv
```

#### Contract

[TheNFTV2_exp.sol](../../src/test/2023-11/TheNFTV2_exp.sol)

#### Link Reference

https://x.com/MetaTrustAlert/status/1728616715825848377

---

### 20231122 KyberSwap - precision loss

### Lost: ~$48M

The attacks were spread over 6 chains and 17 transactions.

Each transaction targeted and drained up to 5 pools from KyberSwap elastic CLAMM.

### Test

All the pool hacks follow the same scheme as the first:

```
forge test --contracts ./src/test/2023-11/KyberSwap_exp.eth.1.sol -vvv
```

#### Contract

[KyberSwap_exp.eth.1.sol](../../src/test/2023-11/KyberSwap_exp.eth.1.sol)

#### Link Reference

[Quick analysis](https://twitter.com/BlockSecTeam/status/1727560157888942331).

[In depth analysis](https://blocksec.com/blog/yet-another-tragedy-of-precision-loss-an-in-depth-analysis-of-the-kyber-swap-incident-1).

[List of transactions](https://app.blocksec.com/explorer/security-incidents?page=1).

---

### 20231117 Token8633_9419 - Price Manipulation

### Lost: ~$52K

Test

```
forge test --contracts ./src/test/2023-11/Token8633_9419_exp.sol -vvv
```

#### Contract

[Token8633_9419_exp.sol](../../src/test/2023-11/Token8633_9419_exp.sol)

---

### 20231117 ShibaToken - Business Logic Flaw

### Lost: ~$31K

Test

```
forge test --contracts ./src/test/2023-11/ShibaToken_exp.sol -vvv
```

#### Contract

[ShibaToken_exp.sol](../../src/test/2023-11/ShibaToken_exp.sol)

---

### 20231116 WECO - Business Logic Flaw

### Lost: ~$18K

Test

```
forge test --contracts ./src/test/2023-11/WECO_exp.sol -vvv
```

#### Contract

[WECO_exp.sol](../../src/test/2023-11/WECO_exp.sol)

#### Link Reference

https://x.com/MetaSec_xyz/status/1725311048625041887

---

### 20231115 EHX - Lack of Slippage Control

### Lost: Unclear

Test

```
forge test --contracts ./src/test/2023-11/EHX_exp.sol -vvv
```

#### Contract

[EHX_exp.sol](../../src/test/2023-11/EHX_exp.sol)

#### Link Reference

https://x.com/MetaSec_xyz/status/1724691996638618086

---

### 20231115 XAI - Business Logic Flaw

### Lost: Unclear

Test

```
forge test --contracts src/test/2023-11/XAI_exp.sol -vvv
```

#### Contract

[XAI_exp.sol](../../src/test/2023-11/XAI_exp.sol)

#### Link Reference

https://x.com/MetaSec_xyz/status/1724683082064855455

---

### 20231115 LinkDAO - Bad `K` Value Verification

### Lost: ~$30K

Test

```
forge test --contracts ./src/test/2023-11/LinkDao_exp.sol -vvv
```

#### Contract

[LinkDao_exp.sol](../../src/test/2023-11/LinkDao_exp.sol)

#### Link Reference

https://x.com/phalcon_xyz/status/1725058908144746992

---

### 20231114 OKC Project - Instant Rewards, Unlocked

### Lost: ~$6268

Test

```
forge test --contracts ./src/test/2023-11/OKC_exp.sol -vvv
```

#### Contract

[OKC_exp.sol](../../src/test/2023-11/OKC_exp.sol)

#### Link Reference

https://lunaray.medium.com/okc-project-hack-analysis-0907312f519b

---

### 20231112 MEVBot_0x8c2d - Lack of Access Control

### Lost: ~$365K

Test

```
forge test --contracts ./src/test/2023-11/MEV_0x8c2d_exp.sol -vvv
```

#### Contract

[MEV_0x8c2d_exp.sol](../../src/test/2023-11/MEV_0x8c2d_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1723897569661657553

---

### 20231112 MEVBot_0xa247 - Incorrect Access Control

### Lost: ~$150K

Test

```
forge test --contracts ./src/test/2023-11/MEV_0xa247_exp.sol -vvv
```

#### Contract

[MEV_0xa247_exp.sol](../../src/test/2023-11/MEV_0xa247_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1723591214262632562

---

### 20231111 MahaLend - Donate Inflation ExchangeRate & Rounding Error

### Lost: ~$20 K

Test

```
forge test --contracts ./src/test/2023-11/MahaLend_exp.sol -vvv
```

### Contract

[MahaLend_exp.sol](../../src/test/2023-11/MahaLend_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1723223766350832071

---

### 20231110 Raft_fi - Donate Inflation ExchangeRate & Rounding Error

### Lost: ~$3.2 M

Test

```
forge test --contracts ./src/test/2023-11/Raft_exp.sol -vvv
```

### Contract

[Raft_exp.sol](../../src/test/2023-11/Raft_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1723229393529835972

---

### 20231110 grok - Lack of slippage protection

### Lost: ~26 ETH

Test

```
forge test --contracts ./src/test/2023-11/grok_exp.sol -vvv
```

#### Contract

[grok_exp.sol](../../src/test/2023-11/grok_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1722841076120130020

---

### 20231107 RBalancer - Business Logic Flaw

### Lost: ~17 ETH

Test

```
forge test --contracts ./src/test/2023-11/RBalancer_exp.sol -vvv --evm-version "shanghai"
```

#### Contract

[RBalancer_exp.sol](../../src/test/2023-11/RBalancer_exp.sol)

#### Link Reference

https://x.com/AnciliaInc/status/1722121056083943909

---

### 20231107 MEVbot - Lack of access control

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/2023-11/bot_exp.sol -vvv
```

#### Contract

[bot_exp.sol](../../src/test/2023-11/bot_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1722101942061601052

---

### 20231106 TrustPad - Lack of msg.sender address verification

### Lost: ~$155K

Test

```
forge test --contracts ./src/test/2023-11/TrustPad_exp.sol  -vvv
```

#### Contract

[TrustPad_exp.sol](../../src/test/2023-11/TrustPad_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1721800306101793188

---

### 20231106 KR - Precision loss

### Lost: ~$15K

Test

```
forge test --contracts ./src/test/2023-11/KR_exp.sol  -vvv
```

#### Contract

[KR_exp.sol](../../src/test/2023-11/KR_exp.sol)

#### Link Reference

https://app.blocksec.com/explorer/tx/bsc/0x2abf871eb91d03bc8145bf2a415e79132a103ae9f2b5bbf18b8342ea9207ccd7

---

### 20231106 TheStandard_io - Lack of slippage protection

### Lost: ~$290K

Test

```
forge test --contracts ./src/test/2023-11/TheStandard_io_exp.sol -vvv
```

#### Contract

[TheStandard_io_exp.sol](../../src/test/2023-11/TheStandard_io_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1721807569222549518

https://twitter.com/CertiKAlert/status/1721839125836321195

---

### 20231102 BRAND - Lack of access control

### Lost: ~23 WBNB

Test

```
forge test --contracts ./src/test/2023-11/BRAND_exp.sol  -vvv
```

#### Contract

[BRAND_exp.sol](../../src/test/2023-11/BRAND_exp.sol)

#### Link Reference

https://x.com/MetaSec_xyz/status/1720035913009709473

---

### 20231102 3913Token - Deflationary Token Attack

### Lost: ~$31354 USD$

Test

```
forge test --contracts ./src/test/2023-11/3913_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[3913_exp.sol](../../src/test/2023-11/3913_exp.sol)

#### Link Reference

https://defimon.xyz/attack/bsc/0x8163738d6610ca32f048ee9d30f4aa1ffdb3ca1eddf95c0eba086c3e936199ed

---

### 20231101 OnyxProtocol - Precission Loss Vulnerability

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/2023-11/OnyxProtocol_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[OnyxProtocol_exp.sol](../../src/test/2023-11/OnyxProtocol_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1719697319824851051
https://defimon.xyz/attack/mainnet/0xf7c21600452939a81b599017ee24ee0dfd92aaaccd0a55d02819a7658a6ef635
https://twitter.com/DecurityHQ/status/1719657969925677161

---

### 20231101 SwampFinance - Business Logic Flaw

### Lost: Unclear

Test

```
forge test --contracts ./src/test/2023-11/SwampFinance_exp.sol -vvv
```

#### Contract

[SwampFinance_exp.sol](../../src/test/2023-11/SwampFinance_exp.sol)

#### Link Reference

https://x.com/MetaSec_xyz/status/1720373044517208261

---

### 20231031 UniBotRouter - Arbitrary External Call

### Lost: ~$83,944 USD$

Test

```
forge test --contracts ./src/test/2023-10/UniBot_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[UniBot_exp.sol](../../src/test/2023-10/UniBot_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1719251390319796477

---

### 20231030 LaEeb - Lack Slippage Protection

### Lost: ~1.8 WBNB

Test

```
forge test --contracts ./src/test/2023-10/LaEeb_exp.sol -vvv
```

#### Contract

[LaEeb_exp.sol](../../src/test/2023-10/LaEeb_exp.sol)

#### Link Reference

https://x.com/MetaSec_xyz/status/1718964562165420076

---

### 20231028 AstridProtocol - Business Logic Flaw

### Lost: ~$127ETH

Test

```
forge test --contracts ./src/test/2023-10/Astrid_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[Astrid_exp.sol](../../src/test/2023-10/Astrid_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1718454835966775325

---

### 20231024 MaestroRouter2 - Arbitrary External Call

### Lost: ~$280ETH

Test

```
forge test --contracts ./src/test/2023-10/MaestroRouter2_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[MaestroRouter2_exp.sol](../../src/test/2023-10/MaestroRouter2_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1717014871836098663

https://twitter.com/BeosinAlert/status/1717013965203804457

---

### 20231022 OpenLeverage - Business Logic Flaw

### Lost: ~$8K

Test

```
forge test --contracts ./src/test/2023-10/OpenLeverage_exp.sol -vvv
```

#### Contract

[OpenLeverage_exp.sol](../../src/test/2023-10/OpenLeverage_exp.sol)

#### Link Reference

https://defimon.xyz/exploit/bsc/0x5366c6ba729d9cf8d472500afc1a2976ac2fe9ff

---

### 20231019 kTAF - CompoundV2 Inflation Attack

### Lost: ~$8K

Test

```
forge test --contracts ./src/test/2023-10/kTAF_exp.sol -vvv
```

#### Contract

[kTAF_exp.sol](../../src/test/2023-10/kTAF_exp.sol)

#### Link Reference

https://defimon.xyz/attack/mainnet/0x325999373f1aae98db2d89662ff1afbe0c842736f7564d16a7b52bf5c777d3a4

---

### 20231018 Hopelend - Div Precision Loss

### Lost: ~$825K

Test

```
forge test --contracts ./src/test/2023-10/Hopelend_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[HopeLend_exp.sol](../../src/test/2023-10/Hopelend_exp.sol)

#### Link Reference

https://twitter.com/immunefi/status/1722810650387517715

https://lunaray.medium.com/deep-dive-into-hopelend-hack-5962e8b55d3f

---

### 20231018 MicDao - Price Manipulation

### Lost: ~$13K

Test

```
forge test --contracts ./src/test/2023-10/MicDao_exp.sol -vvv
```

#### Contract

[MicDao_exp.sol](../../src/test/2023-10/MicDao_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1714677875427684544

https://twitter.com/ChainAegis/status/1714837519488205276

---

### 20231013 BelugaDex - Price manipulation

### Lost: ~$175K

Test

```
forge test --contracts ./src/test/2023-10/BelugaDex_exp.sol -vvv
```

#### Contract

[BelugaDex_exp.sol](../../src/test/2023-10/BelugaDex_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1712676040471105870

https://twitter.com/CertiKAlert/status/1712707006979613097

---

### 20231013 WiseLending - Donate Inflation ExchangeRate && Rounding Error

### Lost: ~$260K

Test

```
forge test --contracts ./src/test/2023-10/WiseLending_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[WiseLending_exp.sol](../../src/test/2023-10/WiseLending_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1712841315522638034

https://twitter.com/BlockSecTeam/status/1712871304993689709

---

### 20231012 Platypus - Business Logic Flaw

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/2023-10/Platypus03_exp.sol -vvv
```

#### Contract

[Platypus03_exp.sol](../../src/test/2023-10/Platypus03_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1712445197538468298

https://twitter.com/peckshield/status/1712354198246035562

---

### 20231011 BH - Price manipulation

### Lost: ~$1.27M

Test

```
forge test --contracts ./src/test/2023-10/BH_exp.sol -vvv
```

#### Contract

[BH_exp.sol](../../src/test/2023-10/BH_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1712139760813375973

https://twitter.com/DecurityHQ/status/1712118881425203350

---

### 20231008 ZS - Business Logic Flaw

### Lost: ~$14K

Test

```
forge test --contracts ./src/test/2023-10/ZS_exp.sol -vvv
```

#### Contract

[ZS_exp.sol](../../src/test/2023-10/ZS_exp.sol)

#### Link Reference

https://x.com/MetaSec_xyz/status/1711189697534513327

---

### 20231008 pSeudoEth - Pool manipulation

### Lost: ~$2.3K

Test

```
forge test --contracts ./src/test/2023-10/pSeudoEth_exp.sol -vvv
```

#### Contract

[pSeudoEth_exp.sol](../../src/test/2023-10/pSeudoEth_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1710979615164944729

---

### 20231007 StarsArena - Reentrancy

### Lost: ~$3M

Test

```
forge test --contracts ./src/test/2023-10/StarsArena_exp.sol -vvv
```

#### Contract

[StarsArena_exp.sol](../../src/test/2023-10/StarsArena_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1710556926986342911

https://twitter.com/Phalcon_xyz/status/1710554341466395065

https://twitter.com/peckshield/status/1710555944269292009

---

### 20231005 DePayRouter - Business Logic Flaw

### Lost: ~$ 827 USDC

Test

```
forge test --contracts ./src/test/2023-10/DePayRouter_exp.sol -vvv
```

#### Contract

[DePayRouter_exp.sol](../../src/test/2023-10/DePayRouter_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1709764146324009268

---

### 20230930 FireBirdPair - Lack Slippage Protection

### Lost: ~$3.2K MATIC

Test

```
forge test --contracts ./src/test/2023-09/FireBirdPair_exp.sol -vvv
```

#### Contract

[FireBirdPair_exp.sol](../../src/test/2023-09/FireBirdPair_exp.sol)

#### Link Reference

https://explorer.phalcon.xyz/tx/polygon/0x96d80c609f7a39b45f2bb581c6ba23402c20c2b6cd528317692c31b8d3948328

---

### 20230929 DEXRouter - Arbitrary External Call

### Lost: ~$4K

Test

```
forge test --contracts ./src/test/2023-09/DEXRouter_exp.sol -vvv
```

#### Contract

[DEXRouter_exp.sol](../../src/test/2023-09/DEXRouter_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1707851321909428688

---

### 20230926 XSDWETHpool - Reentrancy

### Lost: ~$56.9BNB

Test

```
forge test --contracts ./src/test/2023-09/XSDWETHpool_exp.sol -vvv
```

#### Contract

[XSDWETHpool_exp.sol](../../src/test/2023-09/XSDWETHpool_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1706765042916450781

---

### 20230924 KubSplit - Pool manipulation

### Lost: ~$78K

Test

```
forge test --contracts ./src/test/2023-09/Kub_Split_exp.sol -vvv
```

#### Contract

[Kub_Split_exp.sol](../../src/test/2023-09/Kub_Split_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1705966214319612092

---

### 20230921 CEXISWAP - Incorrect Access Control

### Lost: ~$30K

Test

```
forge test --contracts ./src/test/2023-09/CEXISWAP_exp.sol -vvv
```

#### Contract

[CEXISWAP_exp.sol](../../src/test/2023-09/CEXISWAP_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1704759560614126030

---

### 20230916 uniclyNFT - Reentrancy

### Lost: 1 NFT

Test

```
forge test --contracts ./src/test/2023-09/uniclyNFT_exp.sol -vvv
```

#### Contract

[uniclyNFT_exp.sol](../../src/test/2023-09/uniclyNFT_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1703096116047421863

---

### 20230911 0x0DEX - Parameter manipulation

### Lost: ~$61K

Test

```
forge test --contracts ./src/test/2023-09/0x0DEX_exp.sol -vvv
```

#### Contract

[0x0DEX_exp.sol](../../src/test/2023-09/0x0DEX_exp.sol)

#### Link Reference

https://0x0ai.notion.site/0x0ai/0x0-Privacy-DEX-Exploit-25373263928b4f18b31c438b2a040e33

---

### 20230909 BFCToken - Business Logic Flaw

### Lost: ~$38K

Test

```
forge test --contracts ./src/test/2023-09/BFCToken_exp.sol -vvv
```

#### Contract

[BFCToken_exp.sol](../../src/test/2023-09/BFCToken_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1700621314246017133

---

### 20230908 APIG - Business Logic Flaw

### Lost: ~$169K

Test

```
forge test --contracts ./src/test/2023-09/APIG_exp.sol -vvv
```

#### Contract

[APIG_exp.sol](../../src/test/2023-09/APIG_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1700128158647734745

---

### 20230907 HCT - Price Manipulation

### Lost: ~$30.5BNB

Test

```
forge test --contracts ./src/test/2023-09/HCT_exp.sol -vvv
```

#### Contract

[HCT_exp.sol](../../src/test/2023-09/HCT_exp.sol)

#### Link Reference

https://twitter.com/leovctech/status/1699775506785198499

---

### 20230905 QuantumWN - Rebasing logic issue

### Lost: ~$0.5 ETH

Test

```
forge test --contracts ./src/test/2023-09/QuantumWN_exp.sol -vvv
```

#### Contract

[QuantumWN_exp.sol](../../src/test/2023-09/QuantumWN_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1699384904218202618

---

### 20230905 JumpFarm - Rebasing logic issue

### Lost: ~$2.4ETH

Test

```
forge test --contracts ./src/test/2023-09/JumpFarm_exp.sol -vvv
```

#### Contract

[JumpFarm_exp.sol](../../src/test/2023-09/JumpFarm_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1699384904218202618

---

### 20230905 HeavensGate - Rebasing logic issue

### Lost: ~$8ETH

Test

```
forge test --contracts ./src/test/2023-09/HeavensGate_exp.sol -vvv
```

#### Contract

[HeavensGate_exp.sol](../../src/test/2023-09/HeavensGate_exp.sol)

#### Link Reference

https://explorer.phalcon.xyz/tx/eth/0xe28ca1f43036f4768776805fb50906f8172f75eba3bf1d9866bcd64361fda834

---

### 20230905 FloorDAO - Rebasing logic issue

### Lost: ~$40ETH

Test

```
forge test --contracts ./src/test/2023-09/FloorDAO_exp.sol -vvv
```

#### Contract

[FloorDAO_exp.sol](../../src/test/2023-09/FloorDAO_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1698962105058361392

https://medium.com/floordao/floor-post-mortem-incident-summary-september-5-2023-e054a2d5afa4

---

### 20230902 DAppSocial - Business Logic Flaw

### Lost: ~$16K

Test

```
forge test --contracts ./src/test/2023-09/DAppSocial_exp.sol -vvv
```

#### Contract

[DAppSocial_exp.sol](../../src/test/2023-09/DAppSocial_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1698064511230464310

---

### 20230829 EAC - Price Manipulation

### Lost: ~$29BNB

Test

```
forge test --contracts ./src/test/2023-08/EAC_exp.sol -vvv
```

#### Contract

[EAC_exp.sol](../../src/test/2023-08/EAC_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1696520866564350157

---

### 20230827 Balancer - Rounding Error && Business Logic Flaw

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/2023-08/Balancer_exp.sol -vvv
```

#### Contract

[Balancer_exp.sol](../../src/test/2023-08/Balancer_exp.sol)

#### Link Reference

https://medium.com/balancer-protocol/rate-manipulation-in-balancer-boosted-pools-technical-postmortem-53db4b642492

https://blocksecteam.medium.com/yet-another-risk-posed-by-precision-loss-an-in-depth-analysis-of-the-recent-balancer-incident-fad93a3c75d4

---

### 20230826 SVT - flawed price calculation

### Lost: ~$400K

Test

```
forge test --contracts ./src/test/2023-08/SVT_exp.sol -vvv
```

#### Contract

[SVT_exp.sol](../../src/test/2023-08/SVT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1695285435671392504?s=20

---

### 20230824 GSS - skim token balance

### Lost: ~$25K

Test

```
forge test --contracts ./src/test/2023-08/GSS_exp.sol -vvv
```

#### Contract

[GSS_exp.sol](../../src/test/2023-08/GSS_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1694571228185723099

---

### 20230821 EHIVE - Business Logic Flaw

### Lost: ~$15K

Test

```
forge test --contracts ./src/test/2023-08/EHIVE_exp.sol -vvv
```

#### Contract

[EHIVE_exp.sol](../../src/test/2023-08/EHIVE_exp.sol)

#### Link Reference

https://twitter.com/bulu4477/status/1693636187485872583

---

### 20230819 BTC20 - Price Manipulation

### Lost: ~$18ETH

Test

```
forge test --contracts ./src/test/2023-08/BTC20_exp.sol -vvv
```

#### Contract

[BTC20_exp.sol](../../src/test/2023-08/BTC20_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1692924369662513472

---

### 20230818 ExactlyProtocol - insufficient validation

### Lost: ~$7M

Test

```
forge test --contracts ./src/test/2023-08/Exactly_exp.sol -vvv
```

#### Contract

[Exactly_exp.sol](../../src/test/2023-08/Exactly_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1692533280971936059

https://medium.com/@exactly_protocol/exactly-protocol-incident-post-mortem-b4293d97e3ed

---

### 20230814 ZunamiProtocol - Price Manipulation

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/2023-08/Zunami_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[Zunami_exp.sol](../../src/test/2023-08/Zunami_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1690877589005778945

https://twitter.com/BlockSecTeam/status/1690931111776358400

---

### 20230809 EarningFram - Reentrancy

### Lost: ~$286k

Test

```
forge test --contracts ./src/test/2023-08/EarningFram_exp.sol -vvv
```

#### Contract

[EarningFram_exp.sol](../../src/test/2023-08/EarningFram_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1689182459269644288

---

### 20230802 CurveBurner - Lack Slippage Protection

### Lost: ~$36K

Test

```
forge test --contracts ./src/test/2023-08/CurveBurner_exp.sol -vvv
```

#### Contract

[CurveBurner_exp.sol](../../src/test/2023-08/CurveBurner_exp.sol)

#### Link Reference

https://medium.com/@Hypernative/exotic-culinary-hypernative-systems-caught-a-unique-sandwich-attack-against-curve-finance-6d58c32e436b

---

### 20230802 Uwerx - Fault logic

### Lost: ~$176ETH

Test

```
forge test --contracts ./src/test/2023-08/Uwerx_exp.sol -vvv
```

#### Contract

[Uwerx_exp.sol](../../src/test/2023-08/Uwerx_exp.sol)

#### Link Reference

https://twitter.com/deeberiroz/status/1686683788795846657

https://twitter.com/CertiKAlert/status/1686667720920625152

https://etherscan.io/tx/0x3b19e152943f31fe0830b67315ddc89be9a066dc89174256e17bc8c2d35b5af8

---

### 20230801 NeutraFinance - Price Manipulation

### Lost: ~$23ETH

Test

```
forge test --contracts ./src/test/2023-08/NeutraFinance_exp.sol -vvv
```

#### Contract

[NeutraFinance_exp.sol](../../src/test/2023-08/NeutraFinance_exp.sol)

#### Link Reference

https://twitter.com/phalcon_xyz/status/1686654241111429120

---

### 20230801 LeetSwap - Access Control

### Lost: ~$630K

Test

```
forge test --contracts ./src/test/2023-08/Leetswap_exp.sol -vvv
```

#### Contract

[Leetswap_exp.sol](../../src/test/2023-08/Leetswap_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1686217464051539968

https://twitter.com/peckshield/status/1686209024587710464

---

### 20230731 GYMNET - Insufficient validation

### Lost: Unclear

Test

```
forge test --contracts ./src/test/2023-07/GYMNET_exp.sol -vvv
```

#### Contract

[GYMNET_exp.sol](../../src/test/2023-07/GYMNET_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1686605510655811584

---

### 20230730 Curve - Vyper Compiler Bug && Reentrancy

### Lost: ~ $41M

Test

```
forge test --contracts ./src/test/2023-07/Curve_exp01.sol -vvv
```

#### Contract

[Curve_exp01.sol](../../src/test/2023-07/Curve_exp01.sol) | [Curve_exp02.sol](../../src/test/2023-07/Curve_exp02.sol)

#### Link Reference

https://hackmd.io/@LlamaRisk/BJzSKHNjn

---

### 20230726 Carson - Price manipulation

### Lost: ~$150K

Test

```
forge test --contracts ./src/test/2023-07/Carson_exp.sol -vvv
```

#### Contract

[Carson_exp.sol](../../src/test/2023-07/Carson_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1684393202252402688

https://twitter.com/Phalcon_xyz/status/1684503154023448583

https://twitter.com/hexagate_/status/1684475526663004160

---

### 20230724 Palmswap - Business Logic Flaw

### Lost: ~$900K

Test

```
forge test --contracts ./src/test/2023-07/Palmswap_exp.sol -vvv
```

#### Contract

[Palmswap_exp.sol](../../src/test/2023-07/Palmswap_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1683680026766737408

---

### 20230723 MintoFinance - Signature Replay

### Lost: ~$9K

Test

```
forge test --contracts ./src/test/2023-07/MintoFinance_exp.sol -vvv
```

#### Contract

[MintoFinance_exp.sol](../../src/test/2023-07/MintoFinance_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1683180340548890631

---

### 20230722 Conic Finance 02 - Price Manipulation

### Lost: ~$934K

Test

```
forge test --contracts ./src/test/2023-07/Conic02_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[Conic02_exp.sol](../../src/test/2023-07/Conic02_exp.sol)

#### Link Reference

https://medium.com/@ConicFinance/post-mortem-eth-and-crvusd-omnipool-exploits-c9c7fa213a3d

https://twitter.com/spreekaway/status/1682467603518726144

---

### 20230721 Conic Finance - Read-Only-Reentrancy && MisConfiguration

### Lost: ~$3.25M

Testing

```
forge test --contracts ./src/test/2023-07/Conic_exp.sol -vvv
```

#### Contract

[Conic_exp.sol](../../src/test/2023-07/Conic_exp.sol)|[Conic_exp2.sol](../../src/test/2023-07/Conic_exp2.sol)

#### Link Reference

https://medium.com/@ConicFinance/post-mortem-eth-and-crvusd-omnipool-exploits-c9c7fa213a3d

https://twitter.com/BlockSecTeam/status/1682356244299010049

---

### 20230721 SUT - Business Logic Flaw

### Lost: ~$8k

Testing

```
forge test --contracts ./src/test/2023-07/SUT_exp.sol -vvv
```

#### Contract

[SUT_exp.sol](../../src/test/2023-07/SUT_exp.sol)

#### Link Reference

https://twitter.com/bulu4477/status/1682983956080377857

---

### 20230720 Utopia - Business Logic Flaw

### Lost: ~$119k

Testing

```
forge test --contracts ./src/test/2023-07/Utopia_exp.sol -vvv
```

#### Contract

[Utopia_exp.sol](../../src/test/2023-07/Utopia_exp.sol)

#### Link Reference

https://twitter.com/DeDotFiSecurity/status/1681923729645871104

https://twitter.com/bulu4477/status/1682380542564769793

---

### 20230720 FFIST - Business Logic Flaw

### Lost: ~$110k

Testing

```
forge test --contracts ./src/test/2023-07/FFIST_exp.sol -vvv
```

#### Contract

[FFIST_exp.sol](../../src/test/2023-07/FFIST_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1681869807698984961

https://twitter.com/AnciliaInc/status/1681901107940065280

---

### 20230718 APEDAO - Business Logic Flaw

### Lost: ~$7K

Testing

```
forge test --contracts ./src/test/2023-07/ApeDAO_exp.sol -vvv
```

#### Contract

[ApeDAO_exp.sol](../../src/test/2023-07/ApeDAO_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1681316257034035201

---

### 20230718 BNO - Invalid emergency withdraw mechanism

### Lost: ~$505K

Testing

```
forge test --contracts ./src/test/2023-07/BNO_exp.sol -vvv
```

#### Contract

[BNO_exp.sol](../../src/test/2023-07/BNO_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1681116206663876610

---

### 20230717 NewFi - Lack Slippage Protection

### Lost: ~$31K

Testing

```
forge test --contracts ./src/test/2023-07/NewFi_exp.sol -vvv
```

#### Contract

[NewFi_exp.sol](../../src/test/2023-07/NewFi_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1680961588323557376

---

### 20230715 USDTStakingContract28 - Lack of access control

### Lost: ~20999 USD

Testing

```
forge test --contracts ./src/test/2023-07/USDTStakingContract28_exp.sol -vvv
```

#### Contract

[USDTStakingContract28_exp.sol](../../src/test/2023-07/USDTStakingContract28_exp.sol)

#### Link Reference

https://x.com/DecurityHQ/status/1680117291013267456

---

### 20230712 Platypus - Bussiness Logic Flaw

### Lost: ~$51K

Testing

```
forge test --contracts ./src/test/2023-07/Platypus02_exp.sol -vvv
```

#### Contract

[Platypus02_exp.sol](../../src/test/2023-07/Platypus02_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1678800450303164431

---

### 20230712 WGPT - Business Logic Flaw

### Lost: ~$80k

Testing

```
forge test --contracts ./src/test/2023-07/WGPT_exp.sol -vvv
```

#### Contract

[WGPT_exp.sol](../../src/test/2023-07/WGPT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1679042549946933248

https://twitter.com/BeosinAlert/status/1679028240982368261

---

### 20230711 RodeoFinance - TWAP Oracle Manipulation

### Lost: ~$888k

Testing

```
forge test --contracts ./src/test/2023-07/RodeoFinance_exp.sol -vvv
```

#### Contract

[RodeoFinance_exp.sol](../../src/test/2023-07/RodeoFinance_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1678765773396008967

https://twitter.com/peckshield/status/1678700465587130368

https://medium.com/@Rodeo_Finance/rodeo-post-mortem-overview-f35635c14101

---

### 20230711 Libertify - Reentrancy

### Lost: ~$452k

Testing

```
forge test --contracts ./src/test/2023-07/Libertify_exp.sol -vvv
```

#### Contract

[Libertify_exp.sol](../../src/test/2023-07/Libertify_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1678688731908411393

https://twitter.com/Phalcon_xyz/status/1678694679767031809

---

### 20230710 ArcadiaFi - Reentrancy

### Lost: ~$400k

Testing

```
forge test --contracts ./src/test/2023-07/ArcadiaFi_exp.sol -vvv
```

#### Contract

[ArcadiaFi_exp.so](../../src/test/2023-07/ArcadiaFi_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1678250590709899264

https://twitter.com/peckshield/status/1678265212770693121

---

### 20230708 CIVNFT - Lack of access control

### Lost: ~$180k

Testing

```
forge test --contracts ./src/test/2023-07/CIVNFT_exp.sol -vvv
```

#### Contract

[CIVNFT_exp.sol](../../src/test/2023-07/CIVNFT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1677722208893022210

https://news.civfund.org/civtrade-hack-analysis-9a2398a6bc2e

https://blog.solidityscan.com/civnft-hack-analysis-4ee79b8c33d1

---

### 20230708 Civfund - Lack of access control

### Lost: ~$165k

Testing

```
forge test --contracts ./src/test/2023-07/Civfund_exp.sol -vvv
```

#### Contract

[Civfund_exp.sol](../../src/test/2023-07/Civfund_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1677529544062803969

https://twitter.com/BeosinAlert/status/1677548773269213184

---

### 20230707 LUSD - Price manipulation attack

### Lost: ~9464USDT

Testing

```
forge test --contracts ./src/test/2023-07/LUSD_exp.sol -vvv
```

#### Contract

[LUSD_exp.sol](/src/test/2023-07/LUSD_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1677391242878140417

---

### 20230704 BambooIA - Price manipulation attack

### Lost: ~200BNB

Testing

```
forge test --contracts ./src/test/2023-07/Bamboo_exp.sol -vvv
```

#### Contract

[Bao_exp.sol](../../src/test/2023-07/Bamboo_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1676220090142916611

https://twitter.com/eugenioclrc

---

### 20230704 BaoCommunity - Donate Inflation ExchangeRate && Rounding Error

### Lost: ~$46k

Testing

```
forge test --contracts ./src/test/2023-07/bao_exp.sol -vvv
```

#### Contract

[Bao_exp.sol](../../src/test/2023-07/Bao_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1676224397248454657

---

### 20230703 AzukiDAO - Invalid signature verification

### Lost: ~$69k

Testing

```
forge test --contracts ./src/test/2023-07/AzukiDAO_exp.sol -vvv
```

#### Contract

[AzukiDAO_exp.sol](../../src/test/2023-07/AzukiDAO_exp.sol)

#### Link Reference

https://twitter.com/sharkteamorg/status/1676892088930271232

---

### 20230630 Biswap - V3Migrator Exploit

### Lost: ~$72k

Testing

```
forge test --contracts ./src/test/2023-06/Biswap_exp.sol -vvv
```

#### Contract

[Biswap_exp.sol](../../src/test/2023-06/Biswap_exp.sol)

#### Link Reference

https://twitter.com/MetaTrustAlert/status/1674814217122349056?s=20

---

### 20230630 MyAi - Business Loigc

### Lost: ~2 $BNB

Testing

```
forge test --contracts ./src/test/2023-06/MyAi_exp.sol -vvv
```

#### Contract

[MyAi_exp.sol](../../src/test/2023-06/MyAi_exp.sol)

#### Link Reference

https://x.com/DecurityHQ/status/1674781372182048776

---

### 20230628 Themis - Manipulation of prices using Flashloan

### Lost: ~$370k

Testing

```
forge test --contracts ./src/test/2023-06/Themis_exp.sol -vvv
```

#### Contract

[Themis_exp.sol](../../src/test/2023-06/Themis_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1673930979348717570

https://twitter.com/BlockSecTeam/status/1673897088617426946

---

### 20230627 UnverifiedContr_9ad32 - Business Loigc Flaw

### Lost: ~5955 USD

Testing

```
forge test --contracts ./src/test/2023-06/UnverifiedContr_9ad32_exp.sol -vvv
```

#### Contract

[UnverifiedContr_9ad32_exp.sol](../../src/test/2023-06/UnverifiedContr_9ad32_exp.sol)

#### Link Reference

https://x.com/DecurityHQ/status/1673708133926031360

---

### 20230627 STRAC - Business Loigc Flaw

### Lost: ~12 $ETH

Testing

```
forge test --contracts ./src/test/2023-06/STRAC_exp.sol -vvv
```

#### Contract

[STRAC_exp.sol](../../src/test/2023-06/STRAC_exp.sol)

#### Link Reference

https://x.com/DecurityHQ/status/1673769624611987487

---

### 20230623 SHIDO - Business Loigc

### Lost: ~997 WBNB

Testing

```
forge test --contracts ./src/test/2023-06/SHIDO_exp.sol -vvv
```

#### Contract

[SHIDO_exp.sol](../../src/test/2023-06/SHIDO_exp.sol) | [SHIDO_exp2.sol](../../src/test/2023-06/SHIDO_exp2.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1672473343734480896

https://twitter.com/AnciliaInc/status/1672382613473083393

---

### 20230621 BabyDogeCoin02 - Lack Slippage Protection

### Lost: ~ 441 BNB

Testing

```
forge test --contracts ./src/test/2023-06/BabyDogeCoin02_exp.sol -vvv
```

#### Contract

[BabyDogeCoin02_exp.sol](../../src/test/2023-06/BabyDogeCoin02_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1671517819840745475

---

### 20230621 BUNN - Reflection tokens

### Lost: ~52BNB

Testing

```
forge test --contracts ./src/test/2023-06/BUNN_exp.sol -vvv
```

#### Contract

[BUNN_exp.sol](../../src/test/2023-06//BUNN_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1671803688996806656

---

### 20230620 MIMSpell - Arbitrary External Call Vulnerability

### Lost: ~$17k

Testing

```
forge test --contracts ./src/test/2023-06/MIMSpell_exp.sol -vvv
```

#### Contract

[MIMSpell_exp.sol](../../src/test/2023-06/MIMSpell_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1671188024607100928?cxt=HHwWgMC--e2poLEuAAAA

---

### 20230619 Contract_0x7657 - Business Loigc

### Lost: ~$20k $USDT

Testing

```
forge test --contracts ./src/test/2023-06/Contract_0x7657_exp.sol -vvv
```

#### Contract

[Contract_0x7657_exp.sol](../../src/test/2023-06/Contract_0x7657_exp.sol)

#### Link Reference

https://x.com/DecurityHQ/status/1670806260550184962

---

### 20230618 ARA - Incorrect handling of permissions

### Lost: ~$125k

Testing

```
forge test --contracts ./src/test/2023-06/ARA_exp.sol -vvv
```

#### Contract

[ARA_exp.sol](../../src/test/2023-06/ARA_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1670638160550965248

---

### 20230617 Pawnfi - Business Logic Flaw

### Lost: ~$820K

Testing

```
forge test --contracts ./src/test/2023-06/Pawnfi_exp.sol -vvv
```

#### Contract

[Pawnfi_exp.sol](../../src/test/2023-06/Pawnfi_exp.sol)

#### Link Reference

https://blog.solidityscan.com/pawnfi-hack-analysis-38ac9160cbb4

---

### 20230617 MidasCapitalXYZ - Precision Loss

### Lost: ~$600K

Testing

```
forge test --contracts ./src/test/2023-06/MidasCapitalXYZ_exp.sol -vvv
```

#### Contract

[MidasCapitalXYZ_exp.sol](../../src/test/2023-06/MidasCapitalXYZ_exp.sol)

#### Link Reference

https://medium.com/midas-capital/midas-exploit-post-mortem-1ae266222994

---

### 20230615 CFC - Uniswap Skim() token balance attack

### Lost: ~$16k

Testing

```
forge test --contracts ./src/test/2023-06/CFC_exp.sol -vvv
```

#### Contract

[CFC_exp.sol](../../src/test/2023-06/CFC_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1669280632738906113

---

### 20230615 DEPUSDT_LEVUSDC - Incorrect access control

### Lost: ~$105k

Testing

```
forge test --contracts ./src/test/2023-06/DEPUSDT_LEVUSDC_exp.sol -vvv
```

#### Contract

[DEPUSDT_LEVUSDC_exp.sol](../../src/test/2023-06/DEPUSDT_LEVUSDC_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1669278694744150016?cxt=HHwWgMDS9Z2IvKouAAAA

---

### 20230612 Sturdy Finance - Read-Only-Reentrancy

### Lost: ~$800k

Testing

```
forge test --contracts ./src/test/2023-06/Sturdy_exp.sol -vvv
```

#### contract

[Sturdy_exp.sol](../../src/test/2023-06/Sturdy_exp.sol)

#### Link Reference

https://sturdyfinance.medium.com/exploit-post-mortem-49261493307a

https://twitter.com/AnciliaInc/status/1668081008615325698

https://twitter.com/BlockSecTeam/status/1668084629654638592

---

### 20230611 SellToken04 - Price Manipulation

### Lost: ~$109k

Testing

```
forge test --contracts ./src/test/2023-06/SELLC03_exp.sol -vvv
```

#### Contract

[SELLC03_exp.sol](../../src/test/2023-06/SELLC03_exp.sol)

#### Link Reference

https://twitter.com/EoceneSecurity/status/1668468933723328513

---

### 20230607 CompounderFinance - Manipulation of funds through fluctuations in the amount of exchangeable assets

### Lost: ~$27,174

Testing

```
forge test --contracts ./src/test/2023-06/CompounderFinance_exp.sol -vvv
```

#### Contract

[CompounderFinance_exp.sol](../../src/test/2023-06/CompounderFinance_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1666346419702362112

---

### 20230606 VINU - Price Manipulation

### Lost: ~$6k

Testing

```
forge test --contracts ./src/test/2023-06/VINU_exp.sol -vvv
```

#### Contract

[VINU_exp.sol](../../src/test/2023-06/VINU_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1666051854386511873?cxt=HHwWgoC24bPVgJ8uAAAA

---

### 20230606 UN - Price Manipulation

### Lost: ~$26k

Testing

```
forge test --contracts ./src/test/2023-06/UN_exp.sol -vvv
```

#### Contract

[UN_exp.sol](../../src/test/2023-06/UN_exp.sol)

#### Link Reference

https://twitter.com/MetaTrustAlert/status/1667041877428932608

---

### 20230602 NST Simple Swap - Unverified contract, wrong approval

### Lost: $40k

The hack was executed in a single transaction, resulting in the theft of $40,000 USD worth of USDT from the swap contract.

```
forge test --contracts ./src/test/2023-06/NST_exp.sol -vvv
```

#### Contract

[NST_exp.sol](../../src/test/2023-06/NST_exp.sol)

#### Link reference

https://discord.com/channels/1100129537603407972/1100129538056396870/1114142216923926528

---

### 20230601 DDCoin - Flashloan attack and smart contract vulnerability

### Lost: ~$300k

Testing

```
forge test --contracts ./src/test/2023-06/DDCoin_exp.sol -vvv
```

#### Contract

[DDCoin_exp.sol](../../src/test/2023-06/DDCoin_exp.sol)

#### Link Reference

https://twitter.com/ImmuneBytes/status/1664239580210495489
https://twitter.com/ChainAegis/status/1664192344726581255?cxt=HHwWjsDRldmHs5guAAAA

---

### 20230601 Cellframenet - Calculation issues during liquidity migration

### Lost: ~$76k

Testing

```
forge test --contracts ./src/test/2023-06/Cellframe_exp.sol -vvv
```

#### Contract

[Cellframe_exp.sol](../../src/test/2023-06/Cellframe_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1664132985883615235?cxt=HHwWhoDTqceImJguAAAA

---

### 20230531 ERC20TokenBank - Price Manipulation

### Lost: ~$111k

Testing

```
forge test --contracts ./src/test/2023-05/ERC20TokenBank_exp.sol -vvv
```

#### Contract

[ERC20TokenBank.sol](../../src/test/2023-05/ERC20TokenBank_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1663810037788311561

---

### 20230529 Jimbo - Protocol Specific Price Manipulation

### Lost: ~$8M

Testing

```
forge test --contracts ./src/test/2023-05/Jimbo_exp.sol -vvv
```

#### Contract

[Jimbo_exp.sol](../../src/test/2023-05/Jimbo_exp.sol)

#### Link Reference

https://twitter.com/cryptofishx/status/1662888991446941697

https://twitter.com/yicunhui2/status/1663793958781353985

---

### 20230529 BabyDogeCoin - Lack Slippage Protection

### Lost: ~$135k

Testing

```
forge test --contracts ./src/test/2023-05/BabyDogeCoin_exp.sol -vvv
```

#### Contract

[BabyDogeCoin_exp.sol](../../src/test/2023-05/BabyDogeCoin_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1662744426475831298

---

### 20230529 FAPEN - Wrong balance check

### Lost: ~$600

Testing

```
forge test --contracts ./src/test/2023-05/FAPEN_exp.sol -vvv
```

#### Contract

[FAPEN_exp.sol](../../src/test/2023-05/FAPEN_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1663501550600302601

---

### 20230529 NOON (NO) - Wrong visibility in function

### Lost: ~$2K

Testing

```
forge test --contracts ./src/test/2023-05/NOON_exp.sol -vvv
```

#### Contract

[NOON_exp.sol](../../src/test/2023-05/NOON_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1663501545105702912

---

### 20230525 GPT Token - Fee Machenism Exploitation

### Lost: ~$42k

Testing

```
forge test --contracts ./src/test/2023-05/GPT_exp.sol -vvv
```

#### Contract

[GPT_exp.sol](../../src/test/2023-05/GPT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1661424685320634368

---

### 20230524 Local Trade LCT - Improper Access Control of Close-source contract

### Lost: ~384 BNB

Testing

```
forge test --contracts ./src/test/2023-05/LocalTrader_exp.sol -vvv
```

#### Contract

[LocalTrader_exp.sol](../../src/test/2023-05/LocalTrader_exp.sol) | [LocalTrader2_exp.sol](../../src/test/2023-05/LocalTrader2_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1661213691893944320

---

### 20230524 CS Token - Outdated Global Variable

### Lost: ~714K USD

Testing

```
forge test --contracts ./src/test/2023-05/CS_exp.sol -vvv
```

#### Contract

[CS_exp.sol](../../src/test/2023-05/CS_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1661098394130198528

https://twitter.com/numencyber/status/1661207123102167041

---

### 20230523 LFI Token - Business Logic Flaw

### Lost: ~36K USD

Testing

```
forge test --contracts ./src/test/2023-05/LFI_exp.sol -vvv
```

#### Contract

[LFI_exp.sol](../../src/test/2023-05/LFI_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1660767088699666433

---

### 20230514 landNFT - Lack of permission control

### Lost: 149,616 $BUSD

Testing

```
forge test --contracts ./src/test/2023-05/landNFT_exp.sol -vvv
```

#### Contract

[landNFT_exp.sol](../../src/test/2023-05/landNFT_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1658000784943124480

---

### 20230514 SellToken03 - Unchecked User Input

### Lost: Unclear

Testing

```
forge test --contracts ./src/test/2023-05/SELLC02_exp.sol -vvv
```

#### Contract

[SELLC02_exp.sol](../../src/test/2023-05/SELLC02_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1657715018908180480

---

### 20230513 Bitpaidio - Business Logic Flaw

### Lost: ~$30K

Testing

```
forge test --contracts ./src/test/2023-05/Bitpaidio_exp.sol -vvv
```

#### Contract

[Bitpaidio_exp.sol](../../src/test/2023-05/Bitpaidio_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1657411284076478465

---

### 20230512 LW - FlashLoan Price Manipulation

### Lost: ~$50k

Testing

```
forge test --contracts ./src/test/2023-05/LW_exp.sol -vvv
```

#### Contract

[LW_exp.sol](../../src/test/2023-05/LW_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1656850634312925184

https://twitter.com/hexagate_/status/1657051084131639296

---

### 20230513 SellToken02 - Price Manipulation

### Lost: ~$197k

Testing

```
forge test --contracts ./src/test/2023-05/SellToken_exp.sol -vvv
```

#### Contract

[SellToken_exp.sol](../../src/test/2023-05/SellToken_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1657324561577435136

---

### 20230511 SellToken01 - Business Logic Flaw

### Lost: ~$95k

Testing

```
forge test --contracts ./src/test/2023-05/SELLC_exp.sol -vvv
```

#### Contract

[SELLC_exp.sol](../../src/test/2023-05/SELLC_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1656337400329834496

https://twitter.com/AnciliaInc/status/1656341587054702598

---

### 20230510 SNK - Reward Calculation Error

### Lost: ~$197k

Testing

```
forge test --contracts ./src/test/2023-05/SNK_exp.sol -vvv
```

#### Contract

[SNK_exp.sol](../../src/test/2023-05/SNK_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1656176776425644032

---

### 20230509 MCC - Reflection token

### Lost: ~$10 ETH

Testing

```
forge test --contracts ./src/test/2023-05/MultiChainCapital_exp.sol -vvv
```

#### Contract

[MultiChainCapital_exp.sol](../../src/test/2023-05/MultiChainCapital_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1655846558762692608

---

### 20230509 HODL - Reflection token

### Lost: ~$2.3 ETH

Testing

```
forge test --contracts ./src/test/2023-05/HODLCapital_exp.sol -vvv
```

#### Contract

[HODLCapital_exp.sol](../../src/test/2023-05/HODLCapital_exp.sol)

#### Link Reference

https://explorer.phalcon.xyz/tx/eth/0xedc214a62ff6fd764200ddaa8ceae54f842279eadab80900be5f29d0b75212df

https://x.com/numencyber/status/1655825767392247808

---

### 20230506 Melo - Access Control

### Lost: ~$90k

Testing

```
forge test --contracts ./src/test/2023-05/Melo_exp.sol -vvv
```

#### Contract

[Melo_exp.sol](../../src/test/2023-05/Melo_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1654667621139349505

---

### 20230505 DEI - wrong implemention

#### Lost: ~5.4M USDC

Testing

```
forge test --contracts ./src/test/2023-05/DEI_exp.sol -vvv
```

#### Contract

[DEI_exp.sol](../../src/test/2023-05/DEI_exp.sol)

#### Link Reference

https://twitter.com/eugenioclrc/status/1654576296507088906

---

### 20230503 NeverFall - Price Manipulation

### Lost: ~74K

Testing

```
forge test --contracts ./src/test/2023-05/NeverFall_exp.sol -vvv
```

#### Contract

[NeverFall_exp.sol](../../src/test/2023-05/NeverFall_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1653619782317662211

---

### 20230502 Level - Business Logic Flaw

### Lost: ~$1M

Testing

```
forge test --contracts ./src/test/2023-05/Level_exp.sol -vvv
```

#### Contract

[Level_exp.sol](../../src/test/2023-05/Level_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1653149493133729794

https://twitter.com/BlockSecTeam/status/1653267431127920641

---

### 20230428 0vix - FlashLoan Price Manipulation

### Lost: ~$2M

Testing

```
forge test --contracts ./src/test/2023-04/0vix_exp.sol -vvv
```

#### Contract

[0vix_exp.sol](../../src/test/2023-04/0vix_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1651932529874853888

https://twitter.com/peckshield/status/1651923235603361793

https://twitter.com/Mudit__Gupta/status/1651958883634536448

---

### 20230427 Silo finance - Business Logic Flaw

### Lost: None

Testing

```
forge test --contracts ./src/test/2023-04/silo_finance_exp.sol -vvv
```

#### Contract

[silo_finance_exp.sol](../../src/test/2023-04/silo_finance_exp.sol)

#### Link Reference

https://medium.com/immunefi/silo-finance-logic-error-bugfix-review-35de29bd934a

---

### 20230424 Axioma - Business Logic Flaw

### Lost: ~21 WBNB

Testing

```
forge test --contracts ./src/test/2023-04/Axioma_exp.sol -vvv
```

#### Contract

[Axioma_exp.sol](../../src/test/2023-04/Axioma_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1650382589847302145

---

### 20230419 OLIFE - Reflection token

### Lost: ~32 WBNB

Testing

```
forge test --contracts ./src/test/2023-04/OLIFE_exp.sol -vvv
```

#### Contract

[OLIFE_exp.sol](../../src/test/2023-04/OLIFE_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1648520494516420608

---

### 20230416 Swapos V2 - error k value Attack

### Lost: ~$468k

Testing

```
forge test --contracts ./src/test/2023-04/Swapos_exp.sol -vvv
```

#### Contract

[Swapos_exp.sol](../../src/test/2023-04/Swapos_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1647530789947469825

https://twitter.com/BeosinAlert/status/1647552192243728385

---

### 20230415 HundredFinance - Donate Inflation ExchangeRate && Rounding Error

### Lost: $7M

Testing

```
forge test --contracts ./src/test/2023-04/HundredFinance_2_exp.sol -vvv
```

#### Contract

[HundredFinance_2_exp.sol](../../src/test/2023-04/HundredFinance_2_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1647307128267476992

https://twitter.com/danielvf/status/1647329491788677121

https://twitter.com/hexagate_/status/1647334970258608131

https://blog.hundred.finance/15-04-23-hundred-finance-hack-post-mortem-d895b618cf33

---

### 20230413 yearnFinance - Misconfiguration

### Lost: $11.6M

Testing

```
forge test --contracts ./src/test/2023-04/YearnFinance_exp.sol -vvv
```

#### Contract

[YearnFinance_exp.sol](../../src/test/2023-04/YearnFinance_exp.sol)

#### Link Reference

https://twitter.com/cmichelio/status/1646422861219807233

https://twitter.com/BeosinAlert/status/1646481687445114881

---

### 20230412 MetaPoint - Unrestricted Approval

### Lost: $820k(2500BNB)

Testing

```
forge test --contracts ./src/test/2023-04/MetaPoint_exp.sol -vvv
```

#### Contract

[MetaPoint_exp.sol](../../src/test/2023-04/MetaPoint_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1645980197987192833

https://twitter.com/Phalcon_xyz/status/1645963327502204929

---

### 20230411 Paribus - Reentrancy

### Lost: $100k

Testing

```
forge test --contracts ./src/test/2023-04/Paribus_exp.sol -vvv
```

#### Contract

[Paribus_exp.sol](../../src/test/2023-04/Paribus_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1645742620897955842

https://twitter.com/BlockSecTeam/status/1645744655357575170

https://twitter.com/peckshield/status/1645742296904929280

---

### 20230409 SushiSwap - Unchecked User Input

### Lost: >$3.3M

Testing

```
forge test --contracts ./src/test/2023-04/Sushi_Router_exp.sol -vvv
```

#### Contract

[Sushi_Router_exp.sol](../../src/test/2023-04/Sushi_Router_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1644907207530774530

https://twitter.com/SlowMist_Team/status/1644936375924584449

https://twitter.com/AnciliaInc/status/1644925421006520320

---

### 20230405 Sentiment - Read-Only-Reentrancy

### Lost: $1M

Testing

```
forge test --contracts ./src/test/2023-04/Sentiment_exp.sol -vvv
```

#### Contract

[Sentiment_exp.sol](../../src/test/2023-04/Sentiment_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1643417467879059456

https://twitter.com/spreekaway/status/1643313471180644360

https://medium.com/coinmonks/theoretical-practical-balancer-and-read-only-reentrancy-part-1-d6a21792066c

---

### 20230402 Allbridge - FlashLoan price manipulation

### Lost: $550k

Testing

```
forge test --contracts ./src/test/2023-04/Allbridge_exp.sol -vvv
```

#### Contract

[Allbrideg_exp.sol](../../src/test/2023-04/Allbridge_exp.sol) | [Allbrideg_exp2.sol](../../src/test/2023-04/Allbridge_exp2.sol)

#### Link Reference

https://twitter.com/peckshield/status/1642356701100916736

https://twitter.com/BeosinAlert/status/1642372700726505473

---

### 20230328 SafeMoon Hack - Access Control

### Lost: $8.9M

Testing

```
forge test --contracts ./src/test/2023-03/safeMoon_exp.sol -vvv
```

#### Contract

[safeMoon_exp.sol](../../src/test/2023-03/safeMoon_exp.sol)

#### Link reference

https://twitter.com/zokyo_io/status/1641014520041840640

---

### 20230328 - Thena - Yield Protocol Flaw

### Lost: $10k

Testing

```
forge test --contracts ./src/test/2023-03/Thena_exp.sol -vvv
```

#### Contract

[Thena_exp.sol](../../src/test/2023-03/Thena_exp.sol)

#### Link Reference

https://twitter.com/LTV888/status/1640563457094451214?t=OBHfonYm9yYKvMros6Uw_g&s=19

---

### 20230325 - DBW - Business Logic Flaw

### Lost: $24k

Testing

```
forge test --contracts ./src/test/2023-03/DBW_exp.sol -vvv
```

#### Contract

[DBW_exp.sol](../../src/test/2023-03/DBW_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1639655134232969216

https://twitter.com/AnciliaInc/status/1639289686937210880

---

### 20230322 - BIGFI - Reflection token

### Lost: $30k

Testing

```
forge test --contracts ./src/test/2023-03/BIGFI_exp.sol -vvv
```

#### Contract

[BIGFI_exp.sol](../../src/test/2023-03/BIGFI_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1638522680654675970

---

### 20230317 - ParaSpace NFT - Flashloan + scaledBalanceOf Manipulation

### Rescued: ~2,909 ETH

Testing

```
forge test --contracts ./src/test/2023-03/paraspace_exp.sol -vvv
```

#### Contract

[paraspace_exp.sol](../../src/test/2023-03/paraspace_exp.sol)

[Paraspace_exp_2.sol](../../src/test/2023-03/Paraspace_exp_2.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1636650252844294144

---

### 20230315 - Poolz - integer overflow

### Lost: ~$390K

Testing

```
forge test --contracts ./src/test/2023-03/poolz_exp.sol -vvv
```

#### Contract

[poolz_exp.sol](../../src/test/2023-03/poolz_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1635860470359015425

---

### 20230313 - EulerFinance - Business Logic Flaw

### Lost: ~$200M

Testing

```
forge test --contracts ./src/test/2023-03/Euler_exp.sol -vvv
```

#### Contract

[Euler_exp.sol](../../src/test/2023-03/Euler_exp.sol)

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
forge test --contracts ./src/test/2023-03/DKP_exp.sol -vvv
```

#### Contract

[DKP_exp.sol](../../src/test/2023-03/DKP_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1633421908996763648

---

### 20230307 - Phoenix - Access Control & Arbitrary External Call

### Lost: ~$100k

Testing

```
forge test --contracts src/test/2023-03/Phoenix_exp.sol -vvv
```

#### Contract

[Phoenix_exp.sol](../../src/test/2023-03/Phoenix_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1633090456157401088

---

### 20230227 - LaunchZone - Access Control

### Lost: ~$320,000

Testing

```
forge test  --contracts src/test/2023-02/LaunchZone_exp.sol -vvv
```

#### Contract

[LuanchZone_exp.sol](../../src/test/2023-02/LaunchZone_exp.sol)

#### Link Reference

https://twitter.com/immunefi/status/1630210901360951296

https://twitter.com/launchzoneann/status/1631538253424918528

---

### 20230227 - swapX - Access Control

### Lost: ~$1M

Testing

```
forge test --contracts ./src/test/2023-02/swapX_exp.sol -vvv
```

#### Contract

[SwapX_exp.sol](../../src/test/2023-02/SwapX_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1630111965942018049

https://twitter.com/peckshield/status/1630100506319413250

https://twitter.com/CertiKAlert/status/1630241903839985666

---

### 20230224 - EFVault - Storage Collision

### Lost: ~$5.1M

Testing

```
forge test --contracts ./src/test/2023-02/EFVault_exp.sol -vvv
```

#### Contract

[EFVault_exp.sol](../../src/test/2023-02/EFVault_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1630490333716029440

https://twitter.com/drdr_zz/status/1630500170373685248

https://twitter.com/gbaleeeee/status/1630587522698080257

---

### 20230222 - DYNA - Business Logic Flaw

### Lost: ~$21k

Testing

```
forge test --contracts ./src/test/2023-02/DYNA_exp.sol -vvv
```

#### Contract

[DYNA_exp.sol](../../src/test/2023-02/DYNA_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1628319536117153794

https://twitter.com/BeosinAlert/status/1628301635834486784

---

### 20230218 - RevertFinance - Arbitrary External Call Vulnerability

### Lost: ~$30k

Testing

```
forge test --contracts ./src/test/2023-02/RevertFinance_exp.sol -vvv
```

#### Contract

[RevertFinance_exp.sol](../../src/test/2023-02/RevertFinance_exp.sol)

#### Link Reference

https://mirror.xyz/revertfinance.eth/3sdpQ3v9vEKiOjaHXUi3TdEfhleAXXlAEWeODrRHJtU

---

### 20230217 - Starlink - Business Logic Flaw

### Lost: ~$12k

Testing

```
forge test --contracts ./src/test/2023-02/Starlink_exp.sol -vvv
```

#### Contract

[Starlink_exp.sol](../../src/test/2023-02/Starlink_exp.sol)

#### Link Reference

https://twitter.com/NumenAlert/status/1626447469361102850

https://twitter.com/bbbb/status/1626392605264351235

---

### 20230217 - Dexible - Arbitrary External Call Vulnerability

### Lost: ~$1.5M

Testing

```
forge test --contracts src/test/2023-02/Dexible_exp.sol -vvv
```

#### Contract

[Dexible_exp.sol](../../src/test/2023-02/Dexible_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1626493024879673344

https://twitter.com/MevRefund/status/1626450002254958592

---

### 20230217 - Platypusdefi - Business Logic Flaw

### Lost: ~$8.5M

Testing

```
forge test --contracts src/test/2023-02/Platypus_exp.sol -vvv
```

#### Contract

[Platypus_exp.sol](../../src/test/2023-02/Platypus_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1626367531480125440

https://twitter.com/spreekaway/status/1626319585040338953

---

### 20230210 - Sheep - Reflection token

### Lost: ~$3K

Testing

```
forge test --contracts src/test/2023-02/Sheep_exp.sol -vvv
```

#### Contract

[Sheep_exp.sol](../../src/test/2023-02/Sheep_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1623999717482045440

https://twitter.com/BlockSecTeam/status/1624077078852210691

---

### 20230210 - dForce - Read-Only-Reentrancy

### Lost: ~$3.65M

Testing

```
forge test --contracts ./src/test/2023-02/dForce_exp.sol -vvv
```

#### Contract

[dForce_exp.sol](../../src/test/2023-02/dForce_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1623956763598000129

https://twitter.com/BlockSecTeam/status/1623901011680333824

https://twitter.com/peckshield/status/1623910257033617408

---

### 20230207 - CowSwap - Arbitrary External Call Vulnerability

### Lost: ~$120k

Testing

```
forge test --contracts ./src/test/2023-02/CowSwap_exp.sol -vvv
```

#### Contract

[CowSwap_exp.sol](../../src/test/2023-02/CowSwap_exp.sol)

#### Link reference

https://twitter.com/MevRefund/status/1622793836291407873

https://twitter.com/peckshield/status/1622801412727148544

---

### 20230206 - FDP - Reflection token

### Lost: ~16 WBNB

Testing

```
forge test --contracts src/test/2023-02/FDP_exp.sol -vv
```

#### Contract

[FDP_exp.sol](../../src/test/2023-02/FDP_exp.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1622806011269771266

---

### 20230203 - Spherax USDs - Balance Recalculation Bug

### Lost: ~309k USDs (Stablecoin)

Testing

```
forge test --contracts ./src/test/2023-02/USDs_exp.sol -vv
```

#### Contract

[USDs_exp.sol](../../src/test/2023-02/USDs_exp.sol)

#### Link reference

https://twitter.com/danielvf/status/1621965412832350208

https://medium.com/sperax/usds-feb-3-exploit-report-from-engineering-team-9f0fd3cef00c

---

### 20230203 - Orion Protocol - Reentrancy

### Lost: $3M

Testing

```
forge test --contracts ./src/test/2023-02/Orion_exp.sol -vvv
```

#### Contract

[Orion_exp.sol](../../src/test/2023-02/Orion_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1621337925228306433

https://twitter.com/BlockSecTeam/status/1621263393054420992

https://www.numencyber.com/analysis-of-orionprotocol-reentrancy-attack-with-poc/

---

### 20230202 - BonqDAO - Price Oracle Manipulation

### Lost: BEUR stablecoin and ALBT Token (~88M US$)

Testing

```
forge test --contracts ./src/test/2023-02/BonqDAO_exp.sol -vv
```

#### Contract

[BonqDAO_exp.sol](../../src/test/2023-02/BonqDAO_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1621043757390123008

https://twitter.com/SlowMist_Team/status/1621087651158966274

---

### 20230130 - BEVO - Reflection token

### Lost: 144 BNB

Testing

```sh
forge test --contracts ./src/test/2023-01/BEVO_exp.sol -vvv
```

#### Contract

[BEVO_exp.sol](../../src/test/2023-01/BEVO_exp.sol)

#### Link reference

https://twitter.com/QuillAudits/status/1620377951836708865

---

### 20230126 - TINU - Reflection token

### Lost: 22 ETH

Testing

```sh
forge test --contracts ./src/test/2023-01/TINU_exp.sol -vv
```

#### Contract

[TINU_exp.sol](../../src/test/2023-01/TINU_exp.sol)

#### Link reference

https://twitter.com/libevm/status/1618718156343873536

---

### 20230119 - SHOCO - Reflection token

### Lost: ~4ETH

Testing

```sh
forge test --contracts ./src/test/2023-01/SHOCO_exp.sol -vvvgit
```

#### Contract

[SHOCO_exp.sol](../../src/test/2023-01/SHOCO_exp.sol)

#### Link reference

https://github.com/Autosaida/DeFiHackAnalysis/blob/master/analysis/230119_SHOCO.md

---

### 20230119 - ThoreumFinance - business logic flaw

### Lost: ~2000 BNB

Testing

```sh
forge test --contracts ./src/test/2023-01/ThoreumFinance_exp.sol -vvv
```

#### Contract

[ThoreumFinance_exp.sol](../../src/test/2023-01/ThoreumFinance_exp.sol)

#### Link reference

https://bscscan.com/tx/0x3fe3a1883f0ae263a260f7d3e9b462468f4f83c2c88bb89d1dee5d7d24262b51
https://twitter.com/AnciliaInc/status/1615944396134043648

---

### 20230118 - QTNToken - business logic flaw

### Lost: ~2ETH

Testing

```sh
forge test --contracts ./src/test/2023-01/QTN_exp.sol -vvv
```

#### Contract

[QTN_exp.sol](../../src/test/2023-01/QTN_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1615625901739511809

---

### 20230118 - UPSToken - business logic flaw

### Lost: ~22 ETH

Testing

```sh
forge test --contracts ./src/test/2023-01/Upswing_exp.sol -vvv
```

#### Contract

[Upswing_exp.sol](../../src/test/2023-01/Upswing_exp.sol)

#### Link reference

https://etherscan.io/tx/0x4b3df6e9c68ae482c71a02832f7f599ff58ff877ec05fed0abd95b31d2d7d912
https://twitter.com/QuillAudits/status/1615634917802807297

---

### 20230117 - OmniEstate - No Input Parameter Check

### Lost: $70k(236 BNB)

Testing

```sh
forge test --contracts ./src/test/2023-01/OmniEstate_exp.sol -vvv
```

#### Contract

[OmniEstate_exp.sol](../../src/test/2023-01/OmniEstate_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1615232012834705408

---

### 20230116 - MidasCapital - Read-only Reentrancy

### Lost: $650k

Testing

```sh
forge test --contracts ./src/test/2023-01/Midas_exp.sol -vvv
```

#### Contract

[Midas_exp.sol](../../src/test/2023-01/Midas_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1614774855999844352

https://twitter.com/BlockSecTeam/status/1614864084956254209

---

### 20230111 - UFDao - Incorrect Parameter Setting

### Lost: $90k

Testing

```sh
forge test --contracts ./src/test/2023-01/UFDao_exp.sol -vvv
```

#### Contract

[UFDao_exp.sol](../../src/test/2023-01/UFDao_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1613507804412940289

---

### 20230111 - RoeFinance - FlashLoan price manipulation

### Lost: $80k

Testing

```sh
forge test --contracts ./src/test/2023-01/RoeFinance_exp.sol -vvv
```

#### Contract

[RoeFinance_exp.sol](../../src/test/2023-01/RoeFinance_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1613267000913960976

---

### 20230110 - BRA - Business Logic Flaw

### Lost: 819 BNB (~224k$)

Testing

```sh
forge test --contracts ./src/test/2023-01/BRA_exp.sol -vvv
```

#### Contract

[BRA_exp.sol](../../src/test/2023-01/BRA_exp.sol)

#### Link reference

https://twitter.com/CertiKAlert/status/1612674916070858753

https://twitter.com/BlockSecTeam/status/1612701106982862849

---

### 20230103 - GDS - Business Logic Flaw

### Lost: $180k

Testing

```sh
forge test --contracts ./src/test/2023-01/GDS_exp.sol -vvv
```

#### Contract

[GDS_exp.sol](../../src/test/2023-01/GDS_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1610095490368180224

https://twitter.com/BlockSecTeam/status/1610167174978760704
