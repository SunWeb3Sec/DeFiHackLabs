# DeFi Hacks Reproduce - Foundry

**Reproduce DeFi hack incidents using Foundry.**

371 incidents included.

Let's make Web3 secure! Join [Discord](https://discord.gg/Fjyngakf3h)

Notion: [101 root cause analysis of past DeFi hacked incidents](https://web3sec.xrex.io/)

[Transaction debugging tools](https://github.com/SunWeb3Sec/DeFiHackLabs/#transaction-debugging-tools)

**Disclaimer:** This content serves solely as a proof of concept showcasing past DeFi hacking incidents. It is strictly intended for educational purposes and should not be interpreted as encouraging or endorsing any form of illegal activities or actual hacking attempts. The provided information is for informational and learning purposes only, and any actions taken based on this content are solely the responsibility of the individual. The usage of this information should adhere to applicable laws, regulations, and ethical standards.

## Getting Started

- Follow the [instructions](https://book.getfoundry.sh/getting-started/installation.html) to install [Foundry](https://github.com/foundry-rs/foundry).

- Clone and install dependencies:`git submodule update --init --recursive`

## [Web3 Cybersecurity Academy](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy)

All articles are also published on [Substack](https://defihacklabs.substack.com/).

### OnChain transaction debugging (Ongoing)

- Lesson 1: Tools ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/en) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools) | [Vietnamese](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/vi) | [Korean](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/ko) | [Spanish](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/es) )
- Lesson 2: Warm up ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/02_warmup/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/02_warmup/) | [Korean](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/02_warmup/ko) )
- Lesson 3: Write Your Own PoC (Price Oracle Manipulation) ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03_write_your_own_poc/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03_write_your_own_poc/) | [Korean](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03_write_your_own_poc/ko) )
- Lesson 4: Write Your Own PoC (MEV Bot) ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04_write_your_own_poc/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04_write_your_own_poc/) | [Korean](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04_write_your_own_poc/kr/) )
- Lesson 5: Rugpull Analysis ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/05_Rugpull/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/05_Rugpull/) )
- Lesson 6: Write Your Own PoC (Reentrancy) ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06_write_your_own_poc/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06_write_your_own_poc/) )
- Lesson 7: Hack Analysis: Nomad Bridge, August 2022 ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/07_Analysis_nomad_bridge/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/07_Analysis_nomad_bridge/) )

## List of Past DeFi Incidents

[20240314 MO](#20240314-mo---business-logic-flaw)

[20240308 UnizenIO](#20240309-unizenio---unverified-external-call)

[20240307 GHT](#20240307-ght---business-logic-flaw)

[20240306 ALP](#20240306-alp---public-internal-function)

[20240306 TGBS](#20240306-tgbs---business-logic-flaw)

[20240305 Woofi](#20240305-woofi---price-manipulation)

[20240228 Seneca](#20240228-seneca---arbitrary-external-call-vulnerability)

[20240228 SMOOFSStaking](#20240228-smoofsstaking---reentrancy)

[20240223 CompoundUni](#20240223-CompoundUni---Oracle-bad-price)

[20240223 BlueberryProtocol](#20240223-BlueberryProtocol---logic-flaw)

[20240221 DeezNutz404](#20240221-deeznutz-404---lack-of-validation)

[20240221 GAIN](#20240221-GAIN---bad-function-implementation)

[20240219 RuggedArt](#20240219-RuggedArt---reentrancy)

[20240216 ParticleTrade](#20240216-ParticleTrade---lack-of-validation-data)

[20240215 DualPools](#20240215-DualPools---precision-truncation)

[20240215 Miner](#20240215-Miner---lack-of-validation-dst-address)

[20240211 Game](#20240211-game---reentrancy--business-logic-flaw)

[20240208 Pandora404](#20240208-pandora---interger-underflow)

[20240205 BurnsDefi](#20240205-burnsdefi---price-manipulation)

[20240201 AffineDeFi](#20240201-affinedefi---lack-of-validation-userData)

[20240130 MIMSpell](#20240130-mimspell---precission-loss)

[20240128 BarleyFinance](#20240128-barleyfinance---reentrancy)

[20240127 CitadelFinance](#20240127-citadelfinance---price-manipulation)

[20240125 NBLGAME](#20240125-nblgame---reentrancy)

[20240117 BmiZapper](#20240117-bmizapper---arbitrary-external-call-vulnerability)

[20240117 SocketGateway](#20240112-socketgateway---lack-of-calldata-validation)

[20240112 WiseLending](#20240112-wiselending---loss-of-precision)

[20240110 LQDX Alert](#20240110-lqdx---unauthorized-transferfrom)

[20240104 Gamma](#20240104-gamma---price-manipulation)

[20240102 RadiantCapital](#20240102-radiantcapital---loss-of-precision)

[20240101 OrbitChain](#20240101-orbitchain---incorrect-input-validation)

[20231225 Telcoin](#20231225-telcoin---storage-collision)

[20231222 PineProtocol](#20231222-pineprotocol---business-logic-flaw)

[20231220 TransitFinance](#20231220-transitfinance---lack-of-validation-pool)

[20231217 FloorProtocol](#20231217-floorprotocol---business-logic-flaw)

[20231216 NFTTrader](#20231216-nfttrader---reentrancy)

[20231213 HYPR](#20231213-hypr---business-logic-flaw)

[20231206 TIME](#20231206-time---arbitrary-address-spoofing-attack)

[20231206 ElephantStatus](#20231206-elephantstatus---price-manipulation)

[20231205 BEARNDAO](#20231205-bearndao---business-logic-flaw)

[20231201 UnverifiedContr_0x431abb](#20231201-unverifiedcontr_0x431abb---business-logic-flaw)

[20231129 AIS](#20231129-ais---access-control)

[20231125 TheNFTV2](#20231125-thenftv2---logic-flaw)

[20231122 KyberSwap](#20231122-kyberswap---precision-loss)

[20231117 Token8633_9419](#20231117-token8633_9419---price-manipulation)

[20231117 ShibaToken](#20231117-shibatoken---business-logic-flaw)

[20231115 LinkDAO](#20231115-linkdao---bad-k-value-verification)

[20231114 OKC Project](#20231114-OKC-Project---Instant-Rewards-Unlocked)

[20231112 MEV_0x8c2d](#20231112-mevbot_0x8c2d---lack-of-access-control)

[20231112 MEV_0xa247](#20231112-mevbot_0xa247---incorrect-access-control)

[20231111 Mahalend](#20231111-mahalend---donate-inflation-exchangerate--rounding-error)

[20231110 Raft_fi](#20231110-raft_fi---donate-inflation-exchangerate--rounding-error)

[20231110 GrokToken](#20231110-grok---lack-of-slippage-protection)

[20231107 MEVbot](#20231107-mevbot---lack-of-access-control)

[20231106 TrustPad](#20231106-trustpad---lack-of-msgsender-address-verification)

[20231106 TheStandard_io](#20231106-thestandard_io---lack-of-slippage-protection)

[20231102 3913Token](#20231102-3913token---deflationary-token-attack)

[20231101 OnyxProtocol](#20231101-onyxprotocol---precission-loss-vulnerability)

[20231031 UniBotRouter](#20231031-UniBotRouter---arbitrary-external-call)

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

[20230628 Themis](#20230628-themis---manipulation-of-prices-using-flashloan)

[20230623 SHIDO](#20230623-shido---business-loigc)

[20230621 BabyDogeCoin02](#20230621-babydogecoin02---lack-slippage-protection)

[20230621 BUNN](#20230621-bunn---reflection-tokens)

[20230620 MIM](#20230620-mimspell---arbitrary-external-call-vulnerability)

[20230618 ARA](#20230618-ara---incorrect-handling-of-permissions)

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

[20230524 LocalTrade](#20230524-local-trade-lct---inproper-access-control-of-close-source-contract)

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

[20230416 Swapos V2](#20230416-swapos-v2----error-k-value-attack)

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

<details> <summary> 2022 </summary>

[20221230 DFS](past/2022/README.md#20221230---dfs---insufficient-validation--flashloan)

[20221229 JAY](past/2022/README.md#20221229---jay---insufficient-validation--reentrancy)

[20221225 Rubic](past/2022/README.md#20221225---rubic---arbitrary-external-call-vulnerability)

[20221223 Defrost](past/2022/README.md#20221223---defrost---reentrancy)

[20221214 Nmbplatform](past/2022/README.md#20221214---nmbplatform---flashloan-price-manipulation)

[20221214 FPR](past/2022/README.md#20221214---fpr---access-control)

[20221213 ElasticSwap](past/2022/README.md#20221213---elasticswap---business-logic-flaw)

[20221212 BGLD](past/2022/README.md#20221212---bgld-deflationary-token---flashloan-price-manipulation)

[20221211 Lodestar](past/2022/README.md#20221211---lodestar---flashloan-price-manipulation)

[20221210 MUMUG](past/2022/README.md#20221210---mumug---flashloan-price-manipulation)

[20221210 TIFIToken](past/2022/README.md#20221210---tifitoken---flashloan-price-manipulation)

[20221209 NOVAToken](past/2022/README.md#20221209---novatoken---malicious-unlimted-minting-rugged)

[20221207 AES](past/2022/README.md#20221207---aes-deflationary-token----business-logic-flaw--flashloan-price-manipulation)

[20221205 RFB](past/2022/README.md#20221205---rfb---predicting-random-numbers)

[20221205 BBOX](past/2022/README.md#20221205---bbox---flashloan-price-manipulation)

[20221202 OverNight](past/2022/README.md#20221202---overnight---flashloan-attack)

[20221201 APC](past/2022/README.md#20221201---apc---flashloan--price-manipulation)

[20221129 MBC & ZZSH](past/2022/README.md#20221129---mbc--zzsh---business-logic-flaw--access-control)

[20221129 SEAMAN](past/2022/README.md#20221129---seaman---business-logic-flaw)

[20221123 NUM](past/2022/README.md#20221123---num---protocol-token-incompatible)

[20221122 AUR](past/2022/README.md#20221122---aur---lack-of-permission-check)

[20221121 SDAO](past/2022/README.md#20221121---sdao---business-logic-flaw)

[20221119 AnnexFinance](past/2022/README.md#20221119---annexfinance---verify-flashloan-callback)

[20221117 UEarnPool](past/2022/README.md#20221117---uearnpool---flashloan-attack)

[20221116 SheepFarm](past/2022/README.md#20221116---sheepfarm---no-input-validation)

[20221110 DFXFinance](past/2022/README.md#20221110---dfxfinance---reentrancy)

[20221109 brahTOPG](past/2022/README.md#20221109-brahtopg---arbitrary-external-call-vulnerability)

[20221108 MEV_0ad8](past/2022/README.md#20221108-mev_0ad8---arbitrary-call)

[20221108 Kashi](past/2022/README.md#20221108-kashi---price-caching-design-defect)

[20221107 MooCAKECTX](past/2022/README.md#20221107-moocakectx---flashloan-attack)

[20221105 BDEX](past/2022/README.md#20221105-bdex---business-logic-flaw)

[20221027 VTF](past/2022/README.md#20221027-vtf-token---incorrect-reward-calculation)

[20221027 Team Finance](past/2022/README.md#20221027-team-finance---liquidity-migration-exploit)

[20221026 N00d Token](past/2022/README.md#20221026-n00d-token---reentrancy)

[20221025 ULME](past/2022/README.md#20221025-ulme---access-control)

[20221024 Market](past/2022/README.md#20221024-market---read-only-reentrancy)

[20221024 MulticallWithoutCheck](past/2022/README.md#20221024-multicallwithoutcheck---arbitrary-external-call-vulnerability)

[20221021 OlympusDAO](past/2022/README.md#20221021-olympusdao---no-input-validation)

[20221020 HEALTH Token](past/2022/README.md#20221020-health---transfer-logic-flaw)

[20221020 BEGO Token](past/2022/README.md#20221020-bego---incorrect-signature-verification)

[20221018 HPAY](past/2022/README.md#20221018-hpay---access-control)

[20221018 PLTD Token](past/2022/README.md#20221018-pltd---transfer-logic-flaw)

[20221017 Uerii Token](past/2022/README.md#20221017-uerii-token---access-control)

[20221014 INUKO Token](past/2022/README.md#20221014-inuko---flashloan-price-manipulation)

[20221014 EFLeverVault](past/2022/README.md#20221014-eflevervault---verify-flashloan-callback)

[20221014 MEVBOT a47b](past/2022/README.md#20221014-mevbota47b---mevbot-a47b)

[20221012 ATK](past/2022/README.md#20221012-atk---flashloan-manipulate-price)

[20221011 Rabby Wallet SwapRouter](past/2022/README.md#20221011-rabby-wallet-swaprouter---arbitrary-external-call-vulnerability)

[20221011 Templedao](past/2022/README.md#20221011-templedao---insufficient-access-control)

[20221010 Carrot](past/2022/README.md#20221010-carrot---public-functioncall)

[20221009 Xave Finance](past/2022/README.md#20221009-xave-finance---malicious-proposal-mint--transfer-ownership)

[20221006 RES-Token](past/2022/README.md#20221006-RES-Token---pair-manipulate)

[20221002 Transit Swap](past/2022/README.md#20221002-transit-swap---incorrect-owner-address-validation)

[20221001 BabySwap](past/2022/README.md#20221001-babyswap---parameter-access-control)

[20221001 RL](past/2022/README.md#20221001-RL-Token---Incorrect-Reward-calculation)

[20221001 Thunder Brawl](past/2022/README.md#20221001-thunder-brawl---reentrancy)

[20220929 BXH](past/2022/README.md#20220928-bxh---flashloan--price-oracle-manipulation)

[20220928 MEVBOT Badc0de](past/2022/README.md#20220928-MEVBOT---Badc0de)

[20220923 RADT-DAO](past/2022/README.md#20220923-RADT-DAO---pair-manipulate)

[20220913 MevBot Private TX](past/2022/README.md#20220913-mevbot-private-tx)

[20220909 DPC](past/2022/README.md#20220909-dpc---Incorrect-Reward-calculation)

[20220908 YYDS](past/2022/README.md#20220908-YYDS---pair-manipulate)

[20220908 NewFreeDAO](past/2022/README.md#20220908-newfreedao---flashloans-attack)

[20220908 Ragnarok Online Invasion](past/2022/README.md#20220908-ragnarok-online-invasion---broken-access-control)

[20220906 NXUSD](past/2022/README.md#20220906-NXUSD---flashloan-price-oracle-manipulation)

[20220905 ZoomproFinance](past/2022/README.md#20220905-zoomprofinance---flashloans--price-manipulation)

[20220902 ShadowFi](past/2022/README.md#20220902-shadowfi---access-control)

[20220902 Bad Guys by RPF](past/2022/README.md#20220902-bad-guys-by-rpf---business-logic-flaw--missing-check-for-number-of-nft-to-mint)

[20220824 LuckyTiger NFT](past/2022/README.md#20220824-luckytiger-nft---predicting-random-numbers)

[20220810 XSTABLE Protocol](past/2022/README.md#20220810-xstable-protocol---incorrect-logic-check)

[20220809 ANCH](past/2022/README.md#20220809-anch---skim-token-balance)

[20220807 EGD Finance](past/2022/README.md#20220807-egd-finance---flashloans--price-manipulation)

[20220802 Nomad Bridge](past/2022/README.md#20220802-nomad-bridge---business-logic-flaw--incorrect-acceptable-merkle-root-checks)

[20220801 Reaper Farm](past/2022/README.md#20220801-reaper-farm---business-logic-flaw--lack-of-access-control-mechanism)

[20220725 LPC](past/2022/README.md#20220725-lpc---business-logic-flaw--incorrect-recipient-balance-check-did-not-check-senderrecipient-in-transfer)

[20220723 Audius](past/2022/README.md#20220723-audius---storage-collision--malicious-proposal)

[20220713 SpaceGodzilla](past/2022/README.md#20220713-spacegodzilla---flashloans--price-manipulation)

[20220710 Omni NFT](past/2022/README.md#20220710-omni-nft---reentrancy)

[20220706 FlippazOne NFT](past/2022/README.md#20220706-flippazone-nft----accesscontrol)

[20220701 Quixotic - Optimism NFT Marketplace](past/2022/README.md#20220701-quixotic---optimism-nft-marketplace)

[20220626 XCarnival](past/2022/README.md#20220626-xcarnival---infinite-number-of-loans)

[20220624 Harmony's Horizon Bridge](past/2022/README.md#20220624-harmonys-horizon-bridge---private-key-compromised)

[20220618 SNOOD](past/2022/README.md#20220618-snood---miscalculation-on-_spendallowance)

[20220616 InverseFinance](past/2022/README.md#20220616-inversefinance---flashloan--price-oracle-manipulation)

[20220608 GYMNetwork](past/2022/README.md#20220608-gymnetwork---accesscontrol)

[20220608 Optimism - Wintermute](past/2022/README.md#20220608-optimism---wintermute)

[20220606 Discover](past/2022/README.md#20220606-discover---flashloan--price-oracle-manipulation)

[20220529 NOVO Protocol](past/2022/README.md#20220529-novo-protocol---flashloan--price-oracle-manipulation)

[20220524 HackDao](past/2022/README.md#20220524-HackDao---Skim-token-balance)

[20220517 ApeCoin](past/2022/README.md#20220517-apecoin-ape---flashloan)

[20220508 Fortress Loans](past/2022/README.md#20220508-fortress-loans---malicious-proposal--price-oracle-manipulation)

[20220430 Saddle Finance](past/2022/README.md#20220430-saddle-finance---swap-metapool-attack)

[20220430 Rari Capital/Fei Protocol](past/2022/README.md#20220430-rari-capitalfei-protocol---flashloan-attack--reentrancy)

[20220428 DEUS DAO](past/2022/README.md#20220428-deus-dao---flashloan--price-oracle-manipulation)

[20220424 Wiener DOGE](past/2022/README.md#20220424-wiener-doge---flashloan)

[20220423 Akutar NFT](past/2022/README.md#20220423-akutar-nft---denial-of-service)

[20220421 Zeed Finance](past/2022/README.md#20220421-zeed-finance)

[20220416 BeanstalkFarms](past/2022/README.md#20220416-beanstalkfarms---dao--flashloan)

[20220415 Rikkei Finance](past/2022/README.md#20220415-rikkei-finance---accesscontrol--price-oracle-manipulation)

[20220412 ElephantMoney](past/2022/README.md#20220412-elephantmoney---flashloan--price-oracle-manipulation)

[20220411 Creat Future](past/2022/README.md#20220411-creat-future)

[20220409 GYMNetwork](past/2022/README.md#20220409-gymnetwork)

[20220329 Ronin Network](past/2022/README.md#20220329-ronin-network---Bridge)

[20220329 Redacted Cartel](past/2022/README.md#20220329-redacted-cartel---custom-approval-logic)

[20220327 Revest Finance](past/2022/README.md#20220327-revest-finance---reentrancy)

[20220326 Auctus](past/2022/README.md#20220326-auctus)

[20220322 CompoundTUSDSweepTokenBypass](past/2022/README.md#20220322-compoundtusdsweeptokenbypass)

[20220321 OneRing Finance](past/2022/README.md#20220321-onering-finance---flashloan--price-oracle-manipulation)

[20220320 LI.FI](past/2022/README.md#20220320-LiFi---bridges)

[20220320 Umbrella Network](past/2022/README.md#20220320-umbrella-network---underflow)

[20220315 Hundred Finance](past/2022/README.md#20220313-hundred-finance---erc667-reentrancy)

[20220313 Paraluni](past/2022/README.md#20220313-paraluni---flashloan--reentrancy)

[20220309 Fantasm Finance](past/2022/README.md#20220309-fantasm-finance)

[20220305 Bacon Protocol](past/2022/README.md#20220305-bacon-protocol---reentrancy)

[20220303 TreasureDAO](past/2022/README.md#20220303-treasuredao---zero-fee)

[20220214 BuildFinance - DAO](past/2022/README.md#20220214-buildfinance---dao)

[20220208 Sandbox LAND](past/2022/README.md#20220208-sandbox-land---access-control)

[20220206 Meter](past/2022/README.md#20220206-Meter---bridge)

[20220206 TecraSpace](past/2022/README.md#20220204-TecraSpace---Any-token-is-destroyed)

[20220128 Qubit Finance](past/2022/README.md#20220128-qubit-finance---bridge-address0safetransferfrom-does-not-revert)

[20220118 Multichain (Anyswap)](past/2022/README.md#20220118-multichain-anyswap---insufficient-token-validation)

</details>
<details> <summary> 2021 </summary>

[20211221 Visor Finance](past/2021/README.md#20211221-visor-finance---reentrancy)

[20211218 Grim Finance](past/2021/README.md#20211218-grim-finance---flashloan--reentrancy)

[20211214 Nerve Bridge](past/2021/README.md#20211214-nerve-bridge---swap-metapool-attack)

[20211130 MonoX Finance](past/2021/README.md#20211130-monox-finance---price-manipulation)

[20211027 Cream Finance](past/2021/README.md#20211027-creamfinance---price-manipulation)

[20211015 Indexed Finance](past/2021/README.md#20211015-indexed-finance---price-manipulation)

[20210916 SushiSwap Miso](past/2021/README.md#20210916-sushiswap-miso)

[20210915 Nimbus Platform](past/2021/README.md#20210915-nimbus-platform)

[20210915 NowSwap Platform](past/2021/README.md#20210915-nowswap-platform)

[20210912 ZABU Finance](past/2021/README.md#20210912-ZABU-Finance---Deflationary-token-uncompatible)

[20210903 DAO Maker](past/2021/README.md#20210903-dao-maker---bad-access-controal)

[20210830 Cream Finance](past/2021/README.md#20210830-cream-finance---flashloan-attack--reentrancy)

[20210817 XSURGE](past/2021/README.md#20210817-xsurge---flashloan-attack--reentrancy)

[20210811 Poly Network](past/2021/README.md#20210811-poly-network---bridge-getting-around-modifier-through-cross-chain-message)

[20210804 WaultFinance](past/2021/README.md#20210804-waultfinace---flashloan-price-manipulation)

[20210728 Levyathan Finance](past/2021/README.md#20210728-levyathan-finance---i-lost-keys-and-minting-ii-vulnerable-emergencywithdraw)

[20210710 Chainswap](past/2021/README.md#20210710-chainswap---bridge-logic-flaw)

[20210702 Chainswap](past/2021/README.md#20210702-chainswap---bridge-logic-flaw)

[20210628 SafeDollar](past/2021/README.md#20210628-safedollar---deflationary-token-uncompatible)

[20210625 xWin Finance](past/2021/README.md#20210625-xwin-finance---subscription-incentive-mechanism)

[20210622 Eleven Finance](past/2021/README.md#20210622-eleven-finance---doesnt-burn-shares)

[20210607 88mph NFT](past/2021/README.md#20210607-88mph-nft---access-control)

[20210603 PancakeHunny](past/2021/README.md#20210603-pancakehunny---incorrect-calculation)

[20210527 BurgerSwap](past/2021/README.md#20210527-burgerswap---mathematical-flaw--reentrancy)

[20210519 PancakeBunny](past/2021/README.md#20210519-pancakebunny---price-oracle-manipulation)

[20210508 Rari Capital](past/2021/README.md#20210509-raricapital---cross-contract-reentrancy)

[20210508 Value Defi](past/2021/README.md#20210508-value-defi---cross-contract-reentrancy)

[20210502 Spartan](past/2021/README.md#20210502-spartan---logic-flaw)

[20210428 Uranium](past/2021/README.md#20210428-uranium---miscalculation)

[20210308 DODO](past/2021/README.md#20210308-dodo---flashloan-attack)

[20210305 Paid Network](past/2021/README.md#20210305-paid-network---private-key-compromised)

[20210125 Sushi Badger Digg](past/2021/README.md#20210125-sushi-badger-digg---sandwich-attack)

</details>
<details> <summary> Before 2020 </summary>

[20201229 Cover Protocol](past/2021/README.md#20201229-cover-protocol)

[20201121 Pickle Finance](past/2021/README.md#20201121-pickle-finance)

[20201026 Harvest Finance](past/2021/README.md#20201026-harvest-finance---flashloan-attack)

[20200804 Opyn Protocol](past/2021/README.md#20200804-opyn-protocol---msgValue-in-loop)

[20200618 Bancor Protocol](past/2021/README.md#20200618-bancor-protocol---access-control)

[20200418 UniSwapV1](past/2021/README.md#20200418-uniswapv1---erc777-reentrancy)

[20180422 Beauty Chain](past/2021/README.md#20180422-beauty-chain---integer-overflow)

[20171106 Parity - 'Accidentally Killed It'](past/2021/README.md#20171106-parity---accidentally-killed-it)

</details>

---

### Transaction debugging tools

[Phalcon](https://explorer.phalcon.xyz/) | [Tx tracer](https://openchain.xyz/trace) | [Cruise](https://cruise.supremacy.team/) | [Ethtx](https://ethtx.info/) | [Tenderly](https://dashboard.tenderly.co/explorer) | [eigenphi](https://tx.eigenphi.io/analyseTransaction)

### Ethereum Signature Database

[4byte](https://www.4byte.directory/) | [sig db](https://openchain.xyz/signatures) | [etherface](https://www.etherface.io/hash)

### Useful tools

[ABI to interface](https://gnidan.github.io/abi-to-sol/) | [Get ABI for unverified contracts](https://abi.w1nt3r.xyz/) | [ETH Calldata Decoder](https://apoorvlathey.com/eth-calldata-decoder/) | [ETHCMD - Guess ABI](https://www.ethcmd.com/tools/decode-calldata/) | [Abi tools](https://openchain.xyz/tools/abi)

### Hacks Dashboard

[Slowmist](https://hacked.slowmist.io/) | [Defillama](https://defillama.com/hacks) | [De.Fi](https://de.fi/rekt-database) | [Rekt](https://rekt.news/) | [Cryptosec](https://cryptosec.info/defi-hacks/)

---

### List of DeFi Hacks & POCs

### 20240314 MO - business logic flaw

### Lost: ~413k USDT

```
forge test --contracts src/test/MO_exp.sol -vvv
```

#### Contract

[MO_exp.sol](src/test/MO_exp.sol)

#### Link reference

https://twitter.com/0xNickLFranklin/status/1768184024483430523

---

### 20240309 UnizenIO - unverified external call

### Lost: ~2M

```
forge test --contracts src/test/UnizenIO_exp.sol -vvvv
```

#### Contract

[UnizenIO_exp.sol](src/test/UnizenIO_exp.sol) | [UnizenIO2_exp.sol](src/test/UnizenIO2_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1766274000534004187

https://twitter.com/AnciliaInc/status/1766261463025684707

---

### 20240307 GHT - Business Logic Flaw

### Lost: ~57K

```
forge test --contracts ./src/test/GHT_exp.sol -vvv
```

#### Contract

[GHT_exp.sol](src/test/GHT_exp.sol)

#### Link reference

---

### 20240306 ALP - Public internal function

### Lost: ~10K

Testing

```
forge test --contracts ./src/test/ALP_exp.sol -vvv
```

#### Contract

[ALP_exp.sol](src/test/ALP_exp.sol)

#### Link Reference

https://twitter.com/0xNickLFranklin/status/1765296663667875880

---

### 20240306 TGBS - Business Logic Flaw

### Lost: ~150K

```
forge test --contracts ./src/test/TGBS_exp.sol -vvv
```

#### Contract

[TGBS_exp.sol](src/test/TGBS_exp.sol)

#### Link reference

https://twitter.com/0xNickLFranklin/status/1765290290083144095

https://twitter.com/Phalcon_xyz/status/1765285257949974747

---

### 20240305 Woofi - Price Manipulation

### Lost: ~8M

```
forge test --contracts ./src/test/Woofi_exp.sol -vvv
```

#### Contract

[Woofi_exp.sol](src/test/Woofi_exp.sol)

#### Link reference

https://twitter.com/spreekaway/status/1765046559832764886
https://twitter.com/PeckShieldAlert/status/1765054155478175943

---

### 20240228 Seneca - Arbitrary External Call Vulnerability

### Lost: ~6M

```
forge test --contracts ./src/test/Seneca_exp.sol -vvv
```

#### Contract

[Seneca_exp.sol](src/test/Seneca_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1763045563040411876

---

### 20240228 SMOOFSStaking - Reentrancy

### Lost: Unclear

```
forge test --contracts ./src/test/SMOOFSStaking_exp.sol -vvv
```

#### Contract

[SMOOFSStaking_exp.sol](src/test/SMOOFSStaking_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1762893563103428783

https://twitter.com/0xNickLFranklin/status/1762895774311178251

---

### 20240223 CompoundUni - Oracle bad price

### Lost: ~439,537 USD

```
forge test --contracts ./src/test/CompoundUni_exp.sol -vvv
```

#### Contract

[CompoundUni_exp.sol](src/test/CompoundUni_exp.sol)

#### Link reference

https://twitter.com/0xLEVI104/status/1762092203894276481

---

### 20240223 BlueberryProtocol - logic flaw

### Lost: ~1,400,000 USD

```
forge test --contracts ./src/test/BlueberryProtocol_exp.sol -vvv
```

#### Contract

[BlueberryProtocol_exp.sol](src/test/BlueberryProtocol_exp.sol)

#### Link reference

https://twitter.com/blueberryFDN/status/1760865357236211964

---

### 20240221 DeezNutz 404 - lack of validation

### Lost: ~170k

```
forge test --contracts ./src/test/DeezNutz404_exp.sol -vvv
```

#### Contract

[DeezNutz404_exp.sol](src/test/DeezNutz404_exp.sol)

#### Link reference

https://twitter.com/0xNickLFranklin/status/1760481343161700523

---

### 20240221 GAIN - bad function implementation

### Lost: ~6.4 ETH

```
forge test --contracts ./src/test/GAIN_exp.sol -vvv
```

#### Contract

[GAIN_exp.sol](src/test/GAIN_exp.sol)

#### Link reference

https://twitter.com/0xNickLFranklin/status/1760559768241160679

---

### 20240219 RuggedArt - reentrancy

### Lost: ~10k

```
forge test --contracts ./src/test/RuggedArte_exp.sol -vvv
```

#### Contract

[RuggedArte_exp.sol](src/test/RuggedArt_exp.sol)

#### Link reference

https://twitter.com/EXVULSEC/status/1759822545875025953

---

### 20240216 ParticleTrade - lack of validation data

### Lost: ~50k

```
forge test --contracts ./src/test/ParticleTrade_exp.sol -vvv
```

#### Contract

[ParticleTrade_exp.sol](src/test/ParticleTrade_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1758028270770250134

---

### 20240215 DualPools - precision truncation

### Lost: ~42k

```
forge test --contracts ./src/test/DualPools_exp.sol -vvvv
```

#### Contract

[DualPools_exp.sol](src/test/DualPools_exp.sol)

#### Link reference

https://medium.com/@lunaray/dualpools-hack-analysis-5209233801fa

---

### 20240215 Miner - lack of validation dst address

### Lost: ~150k

```
forge test --contracts ./src/test/Miner_exp.sol -vvv --evm-version shanghai
```

#### Contract

[Miner_exp.sol](src/test/Miner_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1757777340002681326

---

### 20240211 Game - Reentrancy && Business Logic Flaw

### Lost: ~20 ETH

```
forge test --contracts ./src/test/Game_exp.sol -vvv
```

#### Contract

[Game_exp.sol](src/test/Game_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1757533144033739116

---

### 20240208 Pandora - interger underflow

### Lost: ~17K USD

```
forge test --contracts ./src/test/PANDORA_exp.sol -vvv
```

#### Contract

[PANDORA_exp.sol](src/test/PANDORA_exp.sol)

#### Link reference

https://twitter.com/pennysplayer/status/1766479470058406174

---

### 20240205 BurnsDefi - Price Manipulation

### Lost: ~67K

```
forge test --contracts ./src/test/BurnsDefi_exp.sol -vvv
```

#### Contract

[BurnsDefi_exp.sol](src/test/BurnsDefi_exp.sol)

#### Link reference

https://twitter.com/pennysplayer/status/1754342573815238946

https://medium.com/neptune-mutual/how-was-citadel-finance-exploited-a5f9acd0b408 (similar incident)

---

### 20240201 AffineDeFi - lack of validation userData

### Lost: ~88K

```
forge test --contracts ./src/test/AffineDeFi_exp.sol -vvv
```

#### Contract

[AffineDeFi_exp.sol](src/test/AffineDeFi_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1753020812284809440

https://twitter.com/CyversAlerts/status/1753040754287513655

---

### 20240130 MIMSpell - Precission Loss

### Lost: ~6,5M

```
forge test --contracts ./src/test/MIMSpell2_exp.sol -vvv
```

#### Contract

[MIMSpell2_exp.sol](src/test/MIMSpell2_exp.sol)

#### Link reference

https://twitter.com/kankodu/status/1752581744803680680

https://twitter.com/Phalcon_xyz/status/1752278614551216494

https://twitter.com/peckshield/status/1752279373779194011

https://phalcon.blocksec.com/explorer/security-incidents

---

### 20240128 BarleyFinance - Reentrancy

### Lost: ~130K

```
forge test --contracts ./src/test/BarleyFinance_exp.sol -vvv
```

#### Contract

[BarleyFinance_exp.sol](src/test/BarleyFinance_exp.sol)

#### Link reference

https://phalcon.blocksec.com/explorer/security-incidents

https://www.bitget.com/news/detail/12560603890246

https://twitter.com/Phalcon_xyz/status/1751788389139992824

---

### 20240127 CitadelFinance - Price Manipulation

### Lost: ~93K

```
forge test --contracts ./src/test/CitadelFinance_exp.sol -vvv
```

#### Contract

[CitadelFinance_exp.sol](src/test/CitadelFinance_exp.sol)

#### Link reference

https://medium.com/neptune-mutual/how-was-citadel-finance-exploited-a5f9acd0b408

---

### 20240125 NBLGAME - Reentrancy

### Lost: ~180K

```
forge test --contracts ./src/test/NBLGAME_exp.sol -vvv
```

#### Contract

[NBLGAME_exp.sol](src/test/NBLGAME_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1750526097106915453

https://twitter.com/AnciliaInc/status/1750558426382635036

---

### 20240117 BmiZapper - Arbitrary external call vulnerability

### Lost: ~114K

```
forge test --contracts ./src/test/Bmizapper_exp.sol -vvv
```

#### Contract

[BmiZapper_exp.sol](src/test/BmiZapper_exp.sol)

#### Link reference

https://x.com/0xmstore/status/1747756898172952725

---

### 20240112 SocketGateway - Lack of calldata validation

### Lost: ~3.3Million $

```
forge test --contracts ./src/test/SocketGateway_exp.sol -vvv --evm-version shanghai
```

#### Contract

[SocketGateway_exp.sol](src/test/SocketGateway_exp.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1747450173675196674

https://twitter.com/peckshield/status/1747353782004900274

---

### 20240112 WiseLending - Loss of Precision

### Lost: ~464K

```
forge test --contracts ./src/test/WiseLending02_exp.sol -vvv --evm-version shanghai
```

#### Contract

[WiseLending02_exp.sol](src/test/WiseLending02_exp.sol)

#### Link reference

https://twitter.com/EXVULSEC/status/1746829519334650018

https://twitter.com/peckshield/status/1745907642118123774

---

### 20240110 LQDX - Unauthorized TransferFrom

### Lost: unknown

```
forge test --contracts src/test/LQDX_alert_exp.sol -vvv
```

#### Contract

[LQDX_alert_exp.sol](src/test/LQDX_alert_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1744972012865671452

---

### 20240104 Gamma - Price manipulation

### Lost: ~6.3M

```
forge test --contracts ./src/test/Gamma_exp.sol -vvv
```

#### Contract

[Gamma_exp.sol](src/test/Gamma_exp.sol)

#### Link reference

https://twitter.com/officer_cia/status/1742772207997050899

https://twitter.com/shoucccc/status/1742765618984829326

---

### 20240102 RadiantCapital - Loss of Precision

### Lost: ~4,5M

```
forge test --contracts ./src/test/RadiantCapital_exp.sol -vvv
```

#### Contract

[RadiantCapital_exp.sol](src/test/RadiantCapital_exp.sol)

#### Link reference

https://neptunemutual.com/blog/how-was-radiant-capital-exploited/

https://twitter.com/BeosinAlert/status/1742389285926678784

---

### 20240101 OrbitChain - Incorrect input validation

### Lost: ~81M

```
forge test --contracts ./src/test/OrbitChain_exp.sol -vvv
```

#### Contract

[OrbitChain_exp.sol](src/test/OrbitChain_exp.sol)

#### Link reference

https://blog.solidityscan.com/orbit-chain-hack-analysis-b71c36a54a69

---

### 20231225 Telcoin - Storage Collision

### Lost: ~1,24M

```
forge test --contracts ./src/test/Telcoin_exp.sol -vvv
```

#### Contract

[Telcoin_exp.sol](src/test/Telcoin_exp.sol)

#### Link reference

https://blocksec.com/phalcon/blog/telcoin-security-incident-in-depth-analysis

https://hacked.slowmist.io/?c=&page=2

---

### 20231222 PineProtocol - Business Logic Flaw

### Lost: ~90k

```
forge test --contracts ./src/test/PineProtocol_exp.sol -vvv

```

#### Contract

[PineProtocol_exp.sol](src/test/PineProtocol_exp.sol)

#### Link reference

https://medium.com/neptune-mutual/analysis-of-the-pine-protocol-exploit-e09dbcb80ca0

https://twitter.com/MistTrack_io/status/1738131780459430338

---

### 20231220 TransitFinance - Lack of Validation Pool

### Lost: ~110k

```
forge test --contracts ./src/test/TransitFinance_exp.sol -vvv

```

#### Contract

[TransitFinance_exp.sol](src/test/TransitFinance_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1737355152779030570

https://explorer.phalcon.xyz/tx/bsc/0x93ae5f0a121d5e1aadae052c36bc5ecf2d406d35222f4c6a5d63fef1d6de1081

### 20231217 FloorProtocol - Business Logic Flaw

### Lost: ~$1,6M

```
forge test --contracts ./src/test/FloorProtocol_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[FloorProtocol_exp.sol](src/test/FloorProtocol_exp.sol)

#### Link reference

https://protos.com/floor-protocol-exploited-bored-apes-and-pudgy-penguins-gone/

https://twitter.com/0xfoobar/status/1736190355257627064

https://defimon.xyz/exploit/mainnet/0x7e5433f02f4bf07c4f2a2d341c450e07d7531428

---

### 20231216 NFTTrader - Reentrancy

### Lost: ~$3M

```
forge test --contracts ./src/test/NFTTrader_exp.sol -vvv
```

#### Contract

[NFTTrader_exp.sol](src/test/NFTTrader_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1736263884217139333

https://twitter.com/SlowMist_Team/status/1736005523550646535

https://twitter.com/0xArhat/status/1736038250190651467

---

### 20231213 HYPR - Business Logic Flaw

### Lost: ~$200k

```
forge test --contracts ./src/test/HYPR_exp.sol -vvv
```

#### Contract

[HYPR_exp.sol](src/test/HYPR_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1735197818883588574

https://twitter.com/MevRefund/status/1734791082376941810

---

### 20231206 TIME - Arbitrary Address Spoofing Attack

### Lost: ~84.59 ETH

Test

```
forge test --contracts ./src/test/TIME_exp.sol -vvv
```

#### Contract

[TIME_exp.sol](src/test/TIME_exp.sol)

#### Link reference

https://blog.openzeppelin.com/arbitrary-address-spoofing-vulnerability-erc2771context-multicall-public-disclosure

---

### 20231206 ElephantStatus - Price Manipulation

### Lost: ~$165k

Test

```
forge test --contracts ./src/test/ElephantStatus_exp.sol -vvv
```

#### Contract

[ElephantStatus_exp.sol](src/test/ElephantStatus_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1732354930529435940

---

### 20231205 BEARNDAO - Business Logic Flaw

### Lost: ~$769k

Test

```
forge test --contracts ./src/test/BEARNDAO_exp.sol -vvv
```

#### Contract

[BEARNDAO_exp.sol](src/test/BEARNDAO_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1732159377749180646

---

### 20231201 UnverifiedContr_0x431abb - Business Logic Flaw

### Lost: ~$500k

Test

```
forge test --contracts ./src/test/UnverifiedContr_0x431abb_exp.sol -vvv
```

#### Contract

[UnverifiedContr_0x431abb_exp.sol](src/test/UnverifiedContr_0x431abb_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1730625352953901123

---

### 20231129 AIS - Access Control

### Lost: ~$61k

Testing

```sh
forge test --contracts ./src/test/AIS_exp.sol -vvv
```

#### Contract

[AIS_exp.sol](src/test/AIS_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1729861048004391306

---

### 20231125 TheNFTV2 - logic flaw

### Lost: ~$19K

Test

```
forge test --contracts ./src/test/TheNFTV2_exp.sol -vvv
```

#### Contract

[TheNFTV2_exp.sol](src/test/TheNFTV2_exp.sol)

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
forge test --contracts ./src/test/KyberSwap_exp.eth.1.sol -vvv
```

#### Contract

[KyberSwap_exp.eth.1.sol](src/test/KyberSwap_exp.eth.1.sol)

#### Link Reference

[Quick analysis](https://twitter.com/BlockSecTeam/status/1727560157888942331).

[In depth analysis](https://blocksec.com/blog/yet-another-tragedy-of-precision-loss-an-in-depth-analysis-of-the-kyber-swap-incident-1).

[List of transactions](https://phalcon.blocksec.com/explorer/security-incidents?page=1).

---

### 20231117 Token8633_9419 - Price Manipulation

### Lost: ~$52K

Test

```
forge test --contracts ./src/test/Token8633_9419_exp.sol -vvv
```

#### Contract

[Token8633_9419_exp.sol](src/test/Token8633_9419_exp.sol)

---

### 20231117 ShibaToken - Business Logic Flaw

### Lost: ~$31K

Test

```
forge test --contracts ./src/test/ShibaToken_exp.sol -vvv
```

#### Contract

[ShibaToken_exp.sol](src/test/ShibaToken_exp.sol)

---

### 20231115 LinkDAO - Bad `K` Value Verification

### Lost: ~$30K

Test

```
forge test --contracts ./src/test/LinkDao_exp.sol -vvv
```

#### Contract

[LinkDao_exp.sol](src/test/LinkDao_exp.sol)

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

[OKC_exp.sol](src/test/2023-11/OKC_exp.sol)

#### Link Reference

https://lunaray.medium.com/okc-project-hack-analysis-0907312f519b

---

### 20231112 MEVBot_0x8c2d - Lack of Access Control

### Lost: ~$365K

Test

```
forge test --contracts ./src/test/MEV_0x8c2d_exp.sol -vvv
```

#### Contract

[MEV_0x8c2d_exp.sol](src/test/MEV_0x8c2d_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1723897569661657553

---

### 20231112 MEVBot_0xa247 - Incorrect Access Control

### Lost: ~$150K

Test

```
forge test --contracts ./src/test/MEV_0xa247_exp.sol -vvv
```

#### Contract

[MEV_0xa247_exp.sol](src/test/MEV_0xa247_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1723591214262632562

---

### 20231111 MahaLend - Donate Inflation ExchangeRate & Rounding Error

### Lost: ~$20 K

Test

```
forge test --contracts ./src/test/MahaLend_exp.sol -vvv
```

### Contract

[MahaLend_exp.sol](src/test/MahaLend_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1723223766350832071

---

### 20231110 Raft_fi - Donate Inflation ExchangeRate & Rounding Error

### Lost: ~$3.2 M

Test

```
forge test --contracts ./src/test/Raft_exp.sol -vvv
```

### Contract

[Raft_exp.sol](src/test/Raft_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1723229393529835972

---

### 20231110 grok - Lack of slippage protection

### Lost: ~26 ETH

Test

```
forge test --contracts ./src/test/grok_exp.sol -vvv
```

#### Contract

[grok_exp.sol](src/test/grok_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1722841076120130020

---

### 20231107 MEVbot - Lack of access control

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/bot_exp.sol -vvv
```

#### Contract

[bot_exp.sol](src/test/bot_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1722101942061601052

---

### 20231106 TrustPad - Lack of msg.sender address verification

### Lost: ~$155K

Test

```
forge test --contracts ./src/test/TrustPad_exp.sol  -vvv
```

#### Contract

[TrustPad_exp.sol](src/test/TrustPad_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1721800306101793188

---

### 20231106 TheStandard_io - Lack of slippage protection

### Lost: ~$290K

Test

```
forge test --contracts ./src/test/TheStandard_io_exp.sol -vvv
```

#### Contract

[TheStandard_io_exp.sol](src/test/TheStandard_io_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1721807569222549518

https://twitter.com/CertiKAlert/status/1721839125836321195

---

### 20231102 3913Token - Deflationary Token Attack

### Lost: ~$31354 USD$

Test

```
forge test --contracts ./src/test/3913_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[3913_exp.sol](src/test/3913_exp.sol)

#### Link Reference

https://defimon.xyz/attack/bsc/0x8163738d6610ca32f048ee9d30f4aa1ffdb3ca1eddf95c0eba086c3e936199ed

---

### 20231101 OnyxProtocol - Precission Loss Vulnerability

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/OnyxProtocol_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[OnyxProtocol_exp.sol](src/test/OnyxProtocol_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1719697319824851051
https://defimon.xyz/attack/mainnet/0xf7c21600452939a81b599017ee24ee0dfd92aaaccd0a55d02819a7658a6ef635
https://twitter.com/DecurityHQ/status/1719657969925677161

---

### 20231031 UniBotRouter - Arbitrary External Call

### Lost: ~$83,944 USD$

Test

```
forge test --contracts .\src\test\UniBot_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[UniBot_exp.sol](src/test/UniBot_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1719251390319796477

---

### 20231028 AstridProtocol - Business Logic Flaw

### Lost: ~$127ETH

Test

```
forge test --contracts .\src\test\Astrid_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[Astrid_exp.sol](src/test/Astrid_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1718454835966775325

---

### 20231024 MaestroRouter2 - Arbitrary External Call

### Lost: ~$280ETH

Test

```
forge test --contracts .\src\test\MaestroRouter2_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[MaestroRouter2_exp.sol](src/test/MaestroRouter2_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1717014871836098663

https://twitter.com/BeosinAlert/status/1717013965203804457

---

### 20231022 OpenLeverage - Business Logic Flaw

### Lost: ~$8K

Test

```
forge test --contracts ./src/test/OpenLeverage_exp.sol -vvv
```

#### Contract

[OpenLeverage_exp.sol](src/test/OpenLeverage_exp.sol)

#### Link Reference

https://defimon.xyz/exploit/bsc/0x5366c6ba729d9cf8d472500afc1a2976ac2fe9ff

---

### 20231019 kTAF - CompoundV2 Inflation Attack

### Lost: ~$8K

Test

```
forge test --contracts ./src/test/kTAF_exp.sol -vvv
```

#### Contract

[kTAF_exp.sol](src/test/kTAF_exp.sol)

#### Link Reference

https://defimon.xyz/attack/mainnet/0x325999373f1aae98db2d89662ff1afbe0c842736f7564d16a7b52bf5c777d3a4

---

### 20231018 Hopelend - Div Precision Loss

### Lost: ~$825K

Test

```
forge test --contracts ./src/test/Hopelend_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[HopeLend_exp.sol](src/test/Hopelend_exp.sol)

#### Link Reference

https://twitter.com/immunefi/status/1722810650387517715

https://lunaray.medium.com/deep-dive-into-hopelend-hack-5962e8b55d3f

---

### 20231018 MicDao - Price Manipulation

### Lost: ~$13K

Test

```
forge test --contracts ./src/test/MicDao_exp.sol -vvv
```

#### Contract

[MicDao_exp.sol](src/test/MicDao_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1714677875427684544

https://twitter.com/ChainAegis/status/1714837519488205276

---

### 20231013 BelugaDex - Price manipulation

### Lost: ~$175K

Test

```
forge test --contracts ./src/test/BelugaDex_exp.sol -vvv
```

#### Contract

[BelugaDex_exp.sol](src/test/BelugaDex_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1712676040471105870

https://twitter.com/CertiKAlert/status/1712707006979613097

---

### 20231013 WiseLending - Donate Inflation ExchangeRate && Rounding Error

### Lost: ~$260K

Test

```
forge test --contracts ./src/test/WiseLending_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[WiseLending_exp.sol](src/test/WiseLending_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1712841315522638034

https://twitter.com/BlockSecTeam/status/1712871304993689709

---

### 20231012 Platypus - Business Logic Flaw

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/Platypus03_exp.sol -vvv
```

#### Contract

[Platypus03_exp.sol](src/test/Platypus03_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1712445197538468298

https://twitter.com/peckshield/status/1712354198246035562

---

### 20231011 BH - Price manipulation

### Lost: ~$1.27M

Test

```
forge test --contracts ./src/test/BH_exp.sol -vvv
```

#### Contract

[BH_exp.sol](src/test/BH_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1712139760813375973

https://twitter.com/DecurityHQ/status/1712118881425203350

---

### 20231008 pSeudoEth - Pool manipulation

### Lost: ~$2.3K

Test

```
forge test --contracts ./src/test/pSeudoEth_exp.sol -vvv
```

#### Contract

[pSeudoEth_exp.sol](src/test/pSeudoEth_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1710979615164944729

---

### 20231007 StarsArena - Reentrancy

### Lost: ~$3M

Test

```
forge test --contracts ./src/test/StarsArena_exp.sol -vvv
```

#### Contract

[StarsArena_exp.sol](src/test/StarsArena_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1710556926986342911

https://twitter.com/Phalcon_xyz/status/1710554341466395065

https://twitter.com/peckshield/status/1710555944269292009

---

### 20231005 DePayRouter - Business Logic Flaw

### Lost: ~$ 827 USDC

Test

```
forge test --contracts ./src/test/DePayRouter_exp.sol -vvv
```

#### Contract

[DePayRouter_exp.sol](src/test/DePayRouter_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1709764146324009268

---

### 20230930 FireBirdPair - Lack Slippage Protection

### Lost: ~$3.2K MATIC

Test

```
forge test --contracts ./src/test/FireBirdPair_exp.sol -vvv
```

#### Contract

[FireBirdPair_exp.sol](src/test/FireBirdPair_exp.sol)

#### Link Reference

https://explorer.phalcon.xyz/tx/polygon/0x96d80c609f7a39b45f2bb581c6ba23402c20c2b6cd528317692c31b8d3948328

---

### 20230929 DEXRouter - Arbitrary External Call

### Lost: ~$4K

Test

```
forge test --contracts ./src/test/DEXRouter_exp.sol -vvv
```

#### Contract

[DEXRouter_exp.sol](src/test/DEXRouter_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1707851321909428688

---

### 20230926 XSDWETHpool - Reentrancy

### Lost: ~$56.9BNB

Test

```
forge test --contracts ./src/test/XSDWETHpool_exp.sol -vvv
```

#### Contract

[XSDWETHpool_exp.sol](src/test/XSDWETHpool_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1706765042916450781

---

### 20230924 KubSplit - Pool manipulation

### Lost: ~$78K

Test

```
forge test --contracts ./src/test/Kub_Split_exp.sol -vvv
```

#### Contract

[Kub_Split_exp.sol](src/test/Kub_Split_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1705966214319612092

---

### 20230921 CEXISWAP - Incorrect Access Control

### Lost: ~$30K

Test

```
forge test --contracts ./src/test/CEXISWAP_exp.sol -vvv
```

#### Contract

[CEXISWAP_exp.sol](src/test/CEXISWAP_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1704759560614126030

---

### 20230916 uniclyNFT - Reentrancy

### Lost: 1 NFT

Test

```
forge test --contracts ./src/test/uniclyNFT_exp.sol -vvv
```

#### Contract

[uniclyNFT_exp.sol](src/test/uniclyNFT_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1703096116047421863

---

### 20230911 0x0DEX - Parameter manipulation

### Lost: ~$61K

Test

```
forge test --contracts ./src/test/0x0DEX_exp.sol -vvv
```

#### Contract

[0x0DEX_exp.sol](src/test/0x0DEX_exp.sol)

#### Link Reference

https://0x0ai.notion.site/0x0ai/0x0-Privacy-DEX-Exploit-25373263928b4f18b31c438b2a040e33

---

### 20230909 BFCToken - Business Logic Flaw

### Lost: ~$38K

Test

```
forge test --contracts ./src/test/BFCToken_exp.sol -vvv
```

#### Contract

[BFCToken_exp.sol](src/test/BFCToken_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1700621314246017133

---

### 20230908 APIG - Business Logic Flaw

### Lost: ~$169K

Test

```
forge test --contracts ./src/test/APIG_exp.sol -vvv
```

#### Contract

[APIG_exp.sol](src/test/APIG_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1700128158647734745

---

### 20230907 HCT - Price Manipulation

### Lost: ~$30.5BNB

Test

```
forge test --contracts ./src/test/HCT_exp.sol -vvv
```

#### Contract

[HCT_exp.sol](src/test/HCT_exp.sol)

#### Link Reference

https://twitter.com/leovctech/status/1699775506785198499

---

### 20230905 JumpFarm - Rebasing logic issue

### Lost: ~$2.4ETH

Test

```
forge test --contracts ./src/test/JumpFarm_exp.sol -vvv
```

#### Contract

[JumpFarm_exp.sol](src/test/JumpFarm_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1699384904218202618

---

### 20230905 HeavensGate - Rebasing logic issue

### Lost: ~$8ETH

Test

```
forge test --contracts ./src/test/HeavensGate_exp.sol -vvv
```

#### Contract

[HeavensGate_exp.sol](src/test/HeavensGate_exp.sol)

#### Link Reference

https://explorer.phalcon.xyz/tx/eth/0xe28ca1f43036f4768776805fb50906f8172f75eba3bf1d9866bcd64361fda834

---

### 20230905 FloorDAO - Rebasing logic issue

### Lost: ~$40ETH

Test

```
forge test --contracts ./src/test/FloorDAO_exp.sol -vvv
```

#### Contract

[FloorDAO_exp.sol](src/test/FloorDAO_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1698962105058361392

https://medium.com/floordao/floor-post-mortem-incident-summary-september-5-2023-e054a2d5afa4

---

### 20230902 DAppSocial - Business Logic Flaw

### Lost: ~$16K

Test

```
forge test --contracts ./src/test/DAppSocial_exp.sol -vvv
```

#### Contract

[DAppSocial_exp.sol](src/test/DAppSocial_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1698064511230464310

---

### 20230827 Balancer - Rounding Error && Business Logic Flaw

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/Balancer_exp.sol -vvv
```

#### Contract

[Balancer_exp.sol](src/test/Balancer_exp.sol)

#### Link Reference

https://medium.com/balancer-protocol/rate-manipulation-in-balancer-boosted-pools-technical-postmortem-53db4b642492

https://blocksecteam.medium.com/yet-another-risk-posed-by-precision-loss-an-in-depth-analysis-of-the-recent-balancer-incident-fad93a3c75d4

---

### 20230829 EAC - Price Manipulation

### Lost: ~$29BNB

Test

```
forge test --contracts ./src/test/EAC_exp.sol -vvv
```

#### Contract

[EAC_exp.sol](src/test/EAC_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1696520866564350157

---

### 20230826 SVT - flawed price calculation

### Lost: ~$400K

Test

```
forge test --contracts ./src/test/SVT_exp.sol -vvv
```

#### Contract

[SVT_exp.sol](src/test/SVT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1695285435671392504?s=20

---

### 20230824 GSS - skim token balance

### Lost: ~$25K

Test

```
forge test --contracts ./src/test/GSS_exp.sol -vvv
```

#### Contract

[GSS_exp.sol](src/test/GSS_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1694571228185723099

---

### 20230821 EHIVE - Business Logic Flaw

### Lost: ~$15K

Test

```
forge test --contracts ./src/test/EHIVE_exp.sol -vvv
```

#### Contract

[EHIVE_exp.sol](src/test/EHIVE_exp.sol)

#### Link Reference

https://twitter.com/bulu4477/status/1693636187485872583

---

### 20230819 BTC20 - Price Manipulation

### Lost: ~$18ETH

Test

```
forge test --contracts ./src/test/BTC20_exp.sol -vvv
```

#### Contract

[BTC20_exp.sol](src/test/BTC20_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1692924369662513472

---

### 20230818 ExactlyProtocol - insufficient validation

### Lost: ~$7M

Test

```
forge test --contracts ./src/test/Exactly_exp.sol -vvv
```

#### Contract

[Exactly_exp.sol](src/test/Exactly_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1692533280971936059

https://medium.com/@exactly_protocol/exactly-protocol-incident-post-mortem-b4293d97e3ed

---

### 20230814 ZunamiProtocol - Price Manipulation

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/Zunami_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[Zunami_exp.sol](src/test/Zunami_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1690877589005778945

https://twitter.com/BlockSecTeam/status/1690931111776358400

---

### 20230809 EarningFram - Reentrancy

### Lost: ~$286k

Test

```
forge test --contracts ./src/test/EarningFram_exp.sol -vvv
```

#### Contract

[EarningFram_exp.sol](src/test/EarningFram_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1689182459269644288

---

### 20230802 CurveBurner - Lack Slippage Protection

### Lost: ~$36K

Test

```
forge test --contracts ./src/test/CurveBurner_exp.sol -vvv
```

#### Contract

[CurveBurner_exp.sol](src/test/CurveBurner_exp.sol)

#### Link Reference

https://medium.com/@Hypernative/exotic-culinary-hypernative-systems-caught-a-unique-sandwich-attack-against-curve-finance-6d58c32e436b

---

### 20230802 Uwerx - Fault logic

### Lost: ~$176ETH

Test

```
forge test --contracts ./src/test/Uwerx_exp.sol -vvv
```

#### Contract

[Uwerx_exp.sol](src/test/Uwerx_exp.sol)

#### Link Reference

https://twitter.com/deeberiroz/status/1686683788795846657

https://twitter.com/CertiKAlert/status/1686667720920625152

https://etherscan.io/tx/0x3b19e152943f31fe0830b67315ddc89be9a066dc89174256e17bc8c2d35b5af8

---

### 20230801 NeutraFinance - Price Manipulation

### Lost: ~$23ETH

Test

```
forge test --contracts ./src/test/NeutraFinance_exp.sol -vvv
```

#### Contract

[NeutraFinance_exp.sol](src/test/NeutraFinance_exp.sol)

#### Link Reference

https://twitter.com/phalcon_xyz/status/1686654241111429120

---

### 20230801 LeetSwap - Access Control

### Lost: ~$630K

Test

```
forge test --contracts ./src/test/Leetswap_exp.sol -vvv
```

#### Contract

[Leetswap_exp.sol](src/test/Leetswap_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1686217464051539968

https://twitter.com/peckshield/status/1686209024587710464

---

### 20230731 GYMNET - Insufficient validation

### Lost: Unclear

Test

```
forge test --contracts ./src/test/GYMNET_exp.sol -vvv
```

#### Contract

[GYMNET_exp.sol](src/test/GYMNET_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1686605510655811584

---

### 20230730 Curve - Vyper Compiler Bug && Reentrancy

### Lost: ~ $41M

Test

```
forge test --contracts ./src/test/Curve_exp01.sol -vvv
```

#### Contract

[Curve_exp01.sol](src/test/Curve_exp01.sol) | [Curve_exp02.sol](src/test/Curve_exp02.sol)

#### Link Reference

https://hackmd.io/@LlamaRisk/BJzSKHNjn

---

### 20230726 Carson - Price manipulation

### Lost: ~$150K

Test

```
forge test --contracts ./src/test/Carson_exp.sol -vvv
```

#### Contract

[Carson_exp.sol](src/test/Carson_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1684393202252402688

https://twitter.com/Phalcon_xyz/status/1684503154023448583

https://twitter.com/hexagate_/status/1684475526663004160

---

### 20230724 Palmswap - Business Logic Flaw

### Lost: ~$900K

Test

```
forge test --contracts ./src/test/Palmswap_exp.sol -vvv
```

#### Contract

[Palmswap_exp.sol](src/test/Palmswap_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1683680026766737408

---

### 20230723 MintoFinance - Signature Replay

### Lost: ~$9K

Test

```
forge test --contracts ./src/test/MintoFinance_exp.sol -vvv
```

#### Contract

[MintoFinance_exp.sol](src/test/MintoFinance_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1683180340548890631

---

### 20230722 Conic Finance 02 - Price Manipulation

### Lost: ~$934K

Test

```
forge test --contracts ./src/test/Conic02_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[Conic02_exp.sol](src/test/Conic02_exp.sol)

#### Link Reference

https://medium.com/@ConicFinance/post-mortem-eth-and-crvusd-omnipool-exploits-c9c7fa213a3d

https://twitter.com/spreekaway/status/1682467603518726144

---

### 20230721 Conic Finance - Read-Only-Reentrancy && MisConfiguration

### Lost: ~$3.25M

Testing

```
forge test --contracts ./src/test/Conic_exp.sol -vvv
```

#### Contract

[Conic_exp.sol](src/test/Conic_exp.sol)|[Conic_exp2.sol](src/test/Conic_exp2.sol)

#### Link Reference

https://medium.com/@ConicFinance/post-mortem-eth-and-crvusd-omnipool-exploits-c9c7fa213a3d

https://twitter.com/BlockSecTeam/status/1682356244299010049

---

### 20230721 SUT - Business Logic Flaw

### Lost: ~$8k

Testing

```
forge test --contracts ./src/test/SUT_exp.sol -vvv
```

#### Contract

[SUT_exp.sol](src/test/SUT_exp.sol)

#### Link Reference

https://twitter.com/bulu4477/status/1682983956080377857

---

### 20230720 Utopia - Business Logic Flaw

### Lost: ~$119k

Testing

```
forge test --contracts ./src/test/Utopia_exp.sol -vvv
```

#### Contract

[Utopia_exp.sol](src/test/Utopia_exp.sol)

#### Link Reference

https://twitter.com/DeDotFiSecurity/status/1681923729645871104

https://twitter.com/bulu4477/status/1682380542564769793

---

### 20230720 FFIST - Business Logic Flaw

### Lost: ~$110k

Testing

```
forge test --contracts ./src/test/FFIST_exp.sol -vvv
```

#### Contract

[FFIST_exp.sol](src/test/FFIST_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1681869807698984961

https://twitter.com/AnciliaInc/status/1681901107940065280

---

### 20230718 APEDAO - Business Logic Flaw

### Lost: ~$7K

Testing

```
forge test --contracts ./src/test/ApeDAO_exp.sol -vvv
```

#### Contract

[ApeDAO_exp.sol](src/test/ApeDAO_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1681316257034035201

---

### 20230718 BNO - Invalid emergency withdraw mechanism

### Lost: ~$505K

Testing

```
forge test --contracts ./src/test/BNO_exp.sol -vvv
```

#### Contract

[BNO_exp.sol](src/test/BNO_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1681116206663876610

---

### 20230717 NewFi - Lack Slippage Protection

### Lost: ~$31K

Testing

```
forge test --contracts ./src/test/NewFi_exp.sol -vvv
```

#### Contract

[NewFi_exp.sol](src/test/NewFi_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1680961588323557376

---

### 20230712 Platypus - Bussiness Logic Flaw

### Lost: ~$51K

Testing

```
forge test --contracts ./src/test/Platypus02_exp.sol -vvv
```

#### Contract

[Platypus02_exp.sol](src/test/Platypus02_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1678800450303164431

---

### 20230712 WGPT - Business Logic Flaw

### Lost: ~$80k

Testing

```
forge test --contracts ./src/test/WGPT_exp.sol -vvv
```

#### Contract

[WGPT_exp.sol](src/test/WGPT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1679042549946933248

https://twitter.com/BeosinAlert/status/1679028240982368261

---

### 20230711 RodeoFinance - TWAP Oracle Manipulation

### Lost: ~$888k

Testing

```
forge test --contracts ./src/test/RodeoFinance_exp.sol -vvv
```

#### Contract

[RodeoFinance_exp.sol](src/test/RodeoFinance_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1678765773396008967

https://twitter.com/peckshield/status/1678700465587130368

https://medium.com/@Rodeo_Finance/rodeo-post-mortem-overview-f35635c14101

---

### 20230711 Libertify - Reentrancy

### Lost: ~$452k

Testing

```
forge test --contracts ./src/test/Libertify_exp.sol -vvv
```

#### Contract

[Libertify_exp.sol](src/test/Libertify_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1678688731908411393

https://twitter.com/Phalcon_xyz/status/1678694679767031809

---

### 20230710 ArcadiaFi - Reentrancy

### Lost: ~$400k

Testing

```
forge test --contracts ./src/test/ArcadiaFi_exp.sol -vvv
```

#### Contract

[ArcadiaFi_exp.so](src/test/ArcadiaFi_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1678250590709899264

https://twitter.com/peckshield/status/1678265212770693121

---

### 20230708 CIVNFT - Lack of access control

### Lost: ~$180k

Testing

```
forge test --contracts ./src/test/CIVNFT_exp.sol -vvv
```

#### Contract

[CIVNFT_exp.sol](src/test/CIVNFT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1677722208893022210

https://news.civfund.org/civtrade-hack-analysis-9a2398a6bc2e

https://blog.solidityscan.com/civnft-hack-analysis-4ee79b8c33d1

---

### 20230708 Civfund - Lack of access control

### Lost: ~$165k

Testing

```
forge test --contracts ./src/test/Civfund_exp.sol -vvv
```

#### Contract

[Civfund_exp.sol](src/test/Civfund_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1677529544062803969

https://twitter.com/BeosinAlert/status/1677548773269213184

---

### 20230707 LUSD - Price manipulation attack

### Lost: ~9464USDT

Testing

```
forge test --contracts ./src/test/LUSD_exp.sol -vvv
```

#### Contract

[LUSD_exp.sol](/src/test/LUSD_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1677391242878140417

---

### 20230704 BambooIA - Price manipulation attack

### Lost: ~200BNB

Testing

```
forge test --contracts ./src/test/Bamboo_exp.sol -vvv
```

#### Contract

[Bao_exp.sol](src/test/Bamboo_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1676220090142916611

https://twitter.com/eugenioclrc

---

### 20230704 BaoCommunity - Donate Inflation ExchangeRate && Rounding Error

### Lost: ~$46k

Testing

```
forge test --contracts ./src/test/bao_exp.sol -vvv
```

#### Contract

[Bao_exp.sol](src/test/Bao_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1676224397248454657

---

### 20230703 AzukiDAO - Invalid signature verification

### Lost: ~$69k

Testing

```
forge test --contracts ./src/test/AzukiDAO_exp.sol -vvv
```

#### Contract

[AzukiDAO_exp.sol](src/test/AzukiDAO_exp.sol)

#### Link Reference

https://twitter.com/sharkteamorg/status/1676892088930271232

---

### 20230630 Biswap - V3Migrator Exploit

### Lost: ~$72k

Testing

```
forge test --contracts ./src/test/Biswap_exp.sol -vvv
```

#### Contract

[Biswap_exp.sol](src/test/Biswap_exp.sol)

#### Link Reference

https://twitter.com/MetaTrustAlert/status/1674814217122349056?s=20

---

### 20230628 Themis - Manipulation of prices using Flashloan

### Lost: ~$370k

Testing

```
forge test --contracts ./src/test/Themis_exp.sol -vvv
```

#### Contract

[Themis_exp.sol](src/test/Themis_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1673930979348717570

https://twitter.com/BlockSecTeam/status/1673897088617426946

---

### 20230623 SHIDO - Business Loigc

### Lost: ~997 WBNB

Testing

```
forge test --contracts ./src/test/SHIDO_exp.sol -vvv
```

#### Contract

[SHIDO_exp.sol](src/test/SHIDO_exp.sol) | [SHIDO_exp2.sol](src/test/SHIDO_exp2.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1672473343734480896

https://twitter.com/AnciliaInc/status/1672382613473083393

---

### 20230621 BabyDogeCoin02 - Lack Slippage Protection

### Lost: ~ 441 BNB

Testing

```
forge test --contracts ./src/test/BabyDogeCoin02_exp.sol -vvv
```

#### Contract

[BabyDogeCoin02_exp.sol](src/test/BabyDogeCoin02_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1671517819840745475

---

### 20230621 BUNN - Reflection tokens

### Lost: ~52BNB

Testing

```
forge test --contracts ./src/test/BUNN_exp.sol -vvv
```

#### Contract

[BUNN_exp.sol](src/test//BUNN_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1671803688996806656

---

### 20230620 MIMSpell - Arbitrary External Call Vulnerability

### Lost: ~$17k

Testing

```
forge test --contracts ./src/test/MIMSpell_exp.sol -vvv
```

#### Contract

[MIMSpell_exp.sol](src/test/MIMSpell_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1671188024607100928?cxt=HHwWgMC--e2poLEuAAAA

---

### 20230618 ARA - Incorrect handling of permissions

### Lost: ~$125k

Testing

```
forge test --contracts ./src/test/ARA_exp.sol -vvv
```

#### Contract

[ARA_exp.sol](src/test/ARA_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1670638160550965248

---

### 20230617 Pawnfi - Business Logic Flaw

### Lost: ~$820K

Testing

```
forge test --contracts ./src/test/Pawnfi_exp.sol -vvv
```

#### Contract

[Pawnfi_exp.sol](src/test/Pawnfi_exp.sol)

#### Link Reference

https://blog.solidityscan.com/pawnfi-hack-analysis-38ac9160cbb4

---

### 20230615 CFC - Uniswap Skim() token balance attack

### Lost: ~$16k

Testing

```
forge test --contracts ./src/test/CFC_exp.sol -vvv
```

#### Contract

[CFC_exp.sol](src/test/CFC_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1669280632738906113

---

### 20230615 DEPUSDT_LEVUSDC - Incorrect access control

### Lost: ~$105k

Testing

```
forge test --contracts ./src/test/DEPUSDT_LEVUSDC_exp.sol -vvv
```

#### Contract

[DEPUSDT_LEVUSDC_exp.sol](src/test/DEPUSDT_LEVUSDC_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1669278694744150016?cxt=HHwWgMDS9Z2IvKouAAAA

---

### 20230612 Sturdy Finance - Read-Only-Reentrancy

### Lost: ~$800k

Testing

```
forge test --contracts ./src/test/Sturdy_exp.sol -vvv
```

#### contract

[Sturdy_exp.sol](src/test/Sturdy_exp.sol)

#### Link Reference

https://sturdyfinance.medium.com/exploit-post-mortem-49261493307a

https://twitter.com/AnciliaInc/status/1668081008615325698

https://twitter.com/BlockSecTeam/status/1668084629654638592

---

### 20230611 SellToken04 - Price Manipulation

### Lost: ~$109k

Testing

```
forge test --contracts ./src/test/SELLC03_exp.sol -vvv
```

#### Contract

[SELLC03_exp.sol](src/test/SELLC03_exp.sol)

#### Link Reference

https://twitter.com/EoceneSecurity/status/1668468933723328513

---

### 20230607 CompounderFinance - Manipulation of funds through fluctuations in the amount of exchangeable assets

### Lost: ~$27,174

Testing

```
forge test --contracts ./src/test/CompounderFinance_exp.sol -vvv
```

#### Contract

[CompounderFinance_exp.sol](src/test/CompounderFinance_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1666346419702362112

---

### 20230606 VINU - Price Manipulation

### Lost: ~$6k

Testing

```
forge test --contracts ./src/test/VINU_exp.sol -vvv
```

#### Contract

[VINU_exp.sol](src/test/VINU_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1666051854386511873?cxt=HHwWgoC24bPVgJ8uAAAA

---

### 20230606 UN - Price Manipulation

### Lost: ~$26k

Testing

```
forge test --contracts ./src/test/UN_exp.sol -vvv
```

#### Contract

[UN_exp.sol](src/test/UN_exp.sol)

#### Link Reference

https://twitter.com/MetaTrustAlert/status/1667041877428932608

---

### 20230602 NST Simple Swap - Unverified contract, wrong approval

### Lost: $40k

The hack was executed in a single transaction, resulting in the theft of $40,000 USD worth of USDT from the swap contract.

```
forge test --contracts ./src/test/NST_exp.sol -vvv
```

#### Contract

[NST_exp.sol](src/test/NST_exp.sol)

#### Link reference

https://discord.com/channels/1100129537603407972/1100129538056396870/1114142216923926528

---

### 20230601 DDCoin - Flashloan attack and smart contract vulnerability

### Lost: ~$300k

Testing

```
forge test --contracts ./src/test/DDCoin_exp.sol -vvv
```

#### Contract

[DDCoin_exp.sol](src/test/DDCoin_exp.sol)

#### Link Reference

https://twitter.com/ImmuneBytes/status/1664239580210495489
https://twitter.com/ChainAegis/status/1664192344726581255?cxt=HHwWjsDRldmHs5guAAAA

---

### 20230601 Cellframenet - Calculation issues during liquidity migration

### Lost: ~$76k

Testing

```
forge test --contracts ./src/test/Cellframe_exp.sol -vvv
```

#### Contract

[Cellframe_exp.sol](src/test/Cellframe_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1664132985883615235?cxt=HHwWhoDTqceImJguAAAA

---

### 20230531 ERC20TokenBank - Price Manipulation

### Lost: ~$111k

Testing

```
forge test --contracts ./src/test/ERC20TokenBank_exp.sol -vvv
```

#### Contract

[ERC20TokenBank.sol](src/test/ERC20TokenBank_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1663810037788311561

---

### 20230529 Jimbo - Protocol Specific Price Manipulation

### Lost: ~$8M

Testing

```
forge test --contracts ./src/test/Jimbo_exp.sol -vvv
```

#### Contract

[Jimbo_exp.sol](src/test/Jimbo_exp.sol)

#### Link Reference

https://twitter.com/cryptofishx/status/1662888991446941697

https://twitter.com/yicunhui2/status/1663793958781353985

---

### 20230529 BabyDogeCoin - Lack Slippage Protection

### Lost: ~$135k

Testing

```
forge test --contracts ./src/test/BabyDogeCoin_exp.sol -vvv
```

#### Contract

[BabyDogeCoin_exp.sol](src/test/BabyDogeCoin_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1662744426475831298

---

### 20230529 FAPEN - Wrong balance check

### Lost: ~$600

Testing

```
forge test --contracts ./src/test/FAPEN_exp.sol -vvv
```

#### Contract

[FAPEN_exp.sol](src/test/FAPEN_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1663501550600302601

---

### 20230529 NOON (NO) - Wrong visibility in function

### Lost: ~$2K

Testing

```
forge test --contracts ./src/test/NOON_exp.sol -vvv
```

#### Contract

[NOON_exp.sol](src/test/NOON_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1663501545105702912

---

### 20230525 GPT Token - Fee Machenism Exploitation

### Lost: ~$42k

Testing

```
forge test --contracts ./src/test/GPT_exp.sol -vvv
```

#### Contract

[GPT_exp.sol](src/test/GPT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1661424685320634368

---

### 20230524 Local Trade LCT - Improper Access Control of Close-source contract

### Lost: ~384 BNB

Testing

```
forge test --contracts ./src/test/LocalTrader_exp.sol -vvv
```

#### Contract

[LocalTrader_exp.sol](src/test/LocalTrader_exp.sol) | [LocalTrader2_exp.sol](src/test/LocalTrader2_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1661213691893944320

---

### 20230524 CS Token - Outdated Global Variable

### Lost: ~714K USD

Testing

```
forge test --contracts ./src/test/CS_exp.sol -vvv
```

#### Contract

[CS_exp.sol](src/test/CS_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1661098394130198528

https://twitter.com/numencyber/status/1661207123102167041

---

### 20230523 LFI Token - Business Logic Flaw

### Lost: ~36K USD

Testing

```
forge test --contracts ./src/test/LFI_exp.sol -vvv
```

#### Contract

[LFI_exp.sol](src/test/LFI_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1660767088699666433

---

### 20230514 landNFT - Lack of permission control

### Lost: 149,616 $BUSD

Testing

```
forge test --contracts ./src/test/landNFT_exp.sol -vvv
```

#### Contract

[landNFT_exp.sol](src/test/landNFT_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1658000784943124480

---

### 20230514 SellToken03 - Unchecked User Input

### Lost: Unclear

Testing

```
forge test --contracts ./src/test/SELLC02_exp.sol -vvv
```

#### Contract

[SELLC02_exp.sol](src/test/SELLC02_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1657715018908180480

---

### 20230513 Bitpaidio - Business Logic Flaw

### Lost: ~$30K

Testing

```
forge test --contracts ./src/test/Bitpaidio_exp.sol -vvv
```

#### Contract

[Bitpaidio_exp.sol](src/test/Bitpaidio_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1657411284076478465

---

### 20230512 LW - FlashLoan Price Manipulation

### Lost: ~$50k

Testing

```
forge test --contracts ./src/test/LW_exp.sol -vvv
```

#### Contract

[LW_exp.sol](src/test/LW_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1656850634312925184

https://twitter.com/hexagate_/status/1657051084131639296

---

### 20230513 SellToken02 - Price Manipulation

### Lost: ~$197k

Testing

```
forge test --contracts ./src/test/SellToken_exp.sol -vvv
```

#### Contract

[SellToken_exp.sol](src/test/SellToken_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1657324561577435136

---

### 20230511 SellToken01 - Business Logic Flaw

### Lost: ~$95k

Testing

```
forge test --contracts ./src/test/SELLC_exp.sol -vvv
```

#### Contract

[SELLC_exp.sol](src/test/SELLC_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1656337400329834496

https://twitter.com/AnciliaInc/status/1656341587054702598

---

### 20230510 SNK - Reward Calculation Error

### Lost: ~$197k

Testing

```
forge test --contracts ./src/test/SNK_exp.sol -vvv
```

#### Contract

[SNK_exp.sol](src/test/SNK_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1656176776425644032

---

### 20230509 MCC - Reflection token

### Lost: ~$10 ETH

Testing

```
forge test --contracts ./src/test/MultiChainCapital_exp.sol -vvv
```

#### Contract

[MultiChainCapital_exp.sol](src/test/MultiChainCapital_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1655846558762692608

---

### 20230509 HODL - Reflection token

### Lost: ~$2.3 ETH

Testing

```
forge test --contracts ./src/test/HODLCapital_exp.sol -vvv
```

#### Contract

[HODLCapital_exp.sol](src/test/HODLCapital_exp.sol)

#### Link Reference

https://explorer.phalcon.xyz/tx/eth/0xedc214a62ff6fd764200ddaa8ceae54f842279eadab80900be5f29d0b75212df

---

### 20230506 Melo - Access Control

### Lost: ~$90k

Testing

```
forge test --contracts ./src/test/Melo_exp.sol -vvv
```

#### Contract

[Melo_exp.sol](src/test/Melo_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1654667621139349505

---

### 20230505 DEI - wrong implemention

#### Lost: ~5.4M USDC

Testing

```
forge test --mc DEIPocTest -vvv
```

#### Contract

[DEI_exp.sol](src/test/DEI_exp.sol)

#### Link Reference

https://twitter.com/eugenioclrc/status/1654576296507088906

---

### 20230503 NeverFall - Price Manipulation

### Lost: ~74K

Testing

```
forge test --contracts ./src/test/NeverFall_exp.sol -vvv
```

#### Contract

[NeverFall_exp.sol](src/test/NeverFall_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1653619782317662211

---

### 20230502 Level - Business Logic Flaw

### Lost: ~$1M

Testing

```
forge test --contracts ./src/test/Level_exp.sol -vvv
```

#### Contract

[Level_exp.sol](src/test/Level_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1653149493133729794

https://twitter.com/BlockSecTeam/status/1653267431127920641

---

### 20230428 0vix - FlashLoan Price Manipulation

### Lost: ~$2M

Testing

```
forge test --contracts ./src/test/0vix_exp.sol -vvv
```

#### Contract

[0vix_exp.sol](src/test/0vix_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1651932529874853888

https://twitter.com/peckshield/status/1651923235603361793

https://twitter.com/Mudit__Gupta/status/1651958883634536448

---

### 20230427 Silo finance - Business Logic Flaw

### Lost: None

Testing

```
forge test --contracts ./src/test/silo_finance.t.sol -vvv
```

#### Contract

[silo_finance.t.sol](src/test/silo_finance.t.sol)

#### Link Reference

https://medium.com/immunefi/silo-finance-logic-error-bugfix-review-35de29bd934a

---

### 20230424 Axioma - Business Logic Flaw

### Lost: ~21 WBNB

Testing

```
forge test --contracts ./src/test/Axioma_exp.sol -vvv
```

#### Contract

[Axioma_exp.sol](src/test/Axioma_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1650382589847302145

---

### 20230419 OLIFE - Reflection token

### Lost: ~32 WBNB

Testing

```
forge test --contracts ./src/test/OLIFE_exp.sol -vvv
```

#### Contract

[OLIFE_exp.sol](src/test/OLIFE_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1648520494516420608

---

### 20230416 Swapos V2 - error k value Attack

### Lost: ~$468k

Testing

```
forge test --contracts ./src/test/Swapos_exp.sol -vvv
```

#### Contract

[Swapos_exp.sol](src/test/Swapos_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1647530789947469825

https://twitter.com/BeosinAlert/status/1647552192243728385

---

### 20230415 HundredFinance - Donate Inflation ExchangeRate && Rounding Error

### Lost: $7M

Testing

```
forge test --contracts ./src/test/HundredFinance_2_exp.sol -vvv
```

#### Contract

[HundredFinance_2_exp.sol](src/test/HundredFinance_2_exp.sol)

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
forge test --contracts ./src/test/YearnFinance_exp.sol -vvv
```

#### Contract

[YearnFinance_exp.sol](src/test/YearnFinance_exp.sol)

#### Link Reference

https://twitter.com/cmichelio/status/1646422861219807233

https://twitter.com/BeosinAlert/status/1646481687445114881

---

### 20230412 MetaPoint - Unrestricted Approval

### Lost: $820k(2500BNB)

Testing

```
forge test --contracts ./src/test/MetaPoint_exp.sol -vvv
```

#### Contract

[MetaPoint_exp.sol](src/test/MetaPoint_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1645980197987192833

https://twitter.com/Phalcon_xyz/status/1645963327502204929

---

### 20230411 Paribus - Reentrancy

### Lost: $100k

Testing

```
forge test --contracts ./src/test/Paribus_exp.sol -vvv
```

#### Contract

[Paribus_exp.sol](src/test/Paribus_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1645742620897955842

https://twitter.com/BlockSecTeam/status/1645744655357575170

https://twitter.com/peckshield/status/1645742296904929280

---

### 20230409 SushiSwap - Unchecked User Input

### Lost: >$3.3M

Testing

```
forge test --contracts ./src/test/Sushi_Router_exp.sol -vvv
```

#### Contract

[Sushi_Router_exp.sol](src/test/Sushi_Router_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1644907207530774530

https://twitter.com/SlowMist_Team/status/1644936375924584449

https://twitter.com/AnciliaInc/status/1644925421006520320

---

### 20230405 Sentiment - Read-Only-Reentrancy

### Lost: $1M

Testing

```
forge test --contracts ./src/test/Sentiment_exp.sol -vvv
```

#### Contract

[Sentiment_exp.sol](src/test/Sentiment_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1643417467879059456

https://twitter.com/spreekaway/status/1643313471180644360

https://medium.com/coinmonks/theoretical-practical-balancer-and-read-only-reentrancy-part-1-d6a21792066c

---

### 20230402 Allbridge - FlashLoan price manipulation

### Lost: $550k

Testing

```
forge test --contracts ./src/test/Allbridge_exp.sol -vvv
```

#### Contract

[Allbrideg_exp.sol](src/test/Allbridge_exp.sol) | [Allbrideg_exp2.sol](src/test/Allbridge_exp2.sol)

#### Link Reference

https://twitter.com/peckshield/status/1642356701100916736

https://twitter.com/BeosinAlert/status/1642372700726505473

---

### 20230328 SafeMoon Hack

### Lost: $8.9M

Testing

```
forge test --contracts ./src/test/safeMoon_exp.sol -vvv
```

#### Contract

[safeMoon_exp.sol](src/test/safeMoon_exp.sol)

#### Link reference

https://twitter.com/zokyo_io/status/1641014520041840640

---

### 20230328 - Thena - Yield Protocol Flaw

### Lost: $10k

Testing

```
forge test --contracts ./src/test/Thena_exp.sol -vvv
```

#### Contract

[Thena_exp.sol](src/test/Thena_exp.sol)

#### Link Reference

https://twitter.com/LTV888/status/1640563457094451214?t=OBHfonYm9yYKvMros6Uw_g&s=19

---

### 20230325 - DBW- Business Logic Flaw

### Lost: $24k

Testing

```
forge test --contracts ./src/test/DBW_exp.sol -vvv
```

#### Contract

[DBW_exp.sol](src/test/DBW_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1639655134232969216

https://twitter.com/AnciliaInc/status/1639289686937210880

---

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

### 20230206 - FDP - Reflection token

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

### 20230130 - BEVO - Reflection token

### Lost: 144 BNB

Testing

```sh
forge test --contracts ./src/test/BEVO_exp.t.sol -vvv
```

#### Contract

[BEVO_exp.sol](src/test/BEVO_exp.sol)

#### Link reference

https://twitter.com/QuillAudits/status/1620377951836708865

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

### 20230119 - SHOCO - Reflection token

### Lost: ~4ETH

Testing

```sh
forge test --contracts ./src/test/SHOCO_exp.sol -vvvgit
```

#### Contract

[SHOCO_exp.sol](src/test/SHOCO_exp.sol)

#### Link reference

https://github.com/Autosaida/DeFiHackAnalysis/blob/master/analysis/230119_SHOCO.md

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

### 20230111 - UFDao - Incorrect Parameter Setting

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

### 20230111 - RoeFinance - FlashLoan price manipulation

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

### View Gas Reports

Foundry also has the ability to [report](https://book.getfoundry.sh/forge/gas-reports) the `gas` used per function call which mimics the behavior of [hardhat-gas-reporter](https://github.com/cgewecke/hardhat-gas-reporter). Generally speaking if gas costs per function call is very high, then the likelihood of its success is reduced. Gas optimization is an important activity done by smart contract developers.

Every poc in this repository can produce a gas report like this:

```bash
forge test --gas-report --contracts <contract> -vvv
```

For Example:
Let us find out the gas used in the [Audius poc](past/2022/README.md#20220723-audius---storage-collision--malicious-proposal)

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
