# DeFi Hacks Reproduce - Foundry

**Reproduce DeFi hack incidents using Foundry.**

401 incidents included.

Let's make Web3 secure! Join [Discord](https://discord.gg/Fjyngakf3h)

Notion: [101 root cause analysis of past DeFi hacked incidents](https://web3sec.xrex.io/)

[Transaction debugging tools](https://github.com/SunWeb3Sec/DeFiHackLabs/#transaction-debugging-tools)

**Disclaimer:** This content serves solely as a proof of concept showcasing past DeFi hacking incidents. It is strictly intended for educational purposes and should not be interpreted as encouraging or endorsing any form of illegal activities or actual hacking attempts. The provided information is for informational and learning purposes only, and any actions taken based on this content are solely the responsibility of the individual. The usage of this information should adhere to applicable laws, regulations, and ethical standards.

## Getting Started

- Follow the [instructions](https://book.getfoundry.sh/getting-started/installation.html) to install [Foundry](https://github.com/foundry-rs/foundry).

- Clone and install dependencies:`git submodule update --init --recursive`
- [Contributing Guidelines](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/CONTRIBUTING.md)

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

[20240430 PikeFinance](#20240430-pikefinance---uninitialized-proxy)

[20240425 NGFS](#20240425-ngfs---bad-access-control)

[20240424 XBridge](#20240424-xbridge---logic-flaw)

[20240424 YIEDL](#20240424-yiedl---input-validation)

[20240422 Z123](#20240422-z123---price-manipulation)

[20240420 Rico](#20240420-rico---arbitrary-call)

[20240419 HedgeyFinance](#20240419-hedgeyfinance---logic-flaw)

[20240416 SATX](#20240416-satx---logic-flaw)

[20240416 MARS_DEFI](#20240416-mars---bad-reflection)

[20240415 Chainge](#20240415-chainge---input-validation)

[20240412 FIL314](#20240412-fil314---insufficient-validation-and-price-manipulation)

[20240412 SumerMoney](#20240412-sumermoney---Reentrancy)

[20240412 GROKD](#20240412-grokd---lack-of-access-control)

[20240409 UPS](#20240409-ups---business-logic-flaw)

[20240408 SQUID](#20240408-squid---sandwich-attack)

[20240404 WSM](#20240404-wsm---manipulating-price)

[20240401 ATM](#20240401-atm---business-logic-flaw)

[20240401 OpenLeverage](#20240401-openleverage---reentrancy)

[20240329 PrismaFi](#20240329-prismaFi---insufficient-validation)

[20240328 LavaLending](#20240328-lavalending---business-logic-flaw)

[20240325 ZongZi](#20240325-zongzi---price-manipulation)

[20240314 ARK](#20240324-ark---business-logic-flaw)

[20240321 SSS](#20240321-sss---token-balance-doubles-on-transfer-to-self)

[20240320 Paraswap](#20240320-paraswap---incorrect-access-control)

[20240314 MO](#20240314-mo---business-logic-flaw)

[20240313 IT](#20240313-it---business-logic-flaw)

[20240309 Juice](#20240309-juice---business-logic-flaw)

[20240309 UnizenIO](#20240309-unizenio---unverified-external-call)

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

[20240210 FILX DN404](#20240210-filx-dn404---access-control)

[20240208 Pandora404](#20240208-pandora---interger-underflow)

[20240205 BurnsDefi](#20240205-burnsdefi---price-manipulation)

[20240201 AffineDeFi](#20240201-affinedefi---lack-of-validation-userData)

[20240130 MIMSpell](#20240130-mimspell---precission-loss)

[20240128 BarleyFinance](#20240128-barleyfinance---reentrancy)

[20240127 CitadelFinance](#20240127-citadelfinance---price-manipulation)

[20240125 NBLGAME](#20240125-nblgame---reentrancy)

[20240122 DAO_SoulMate](#20240122-dao_soulmate---incorrect-access-control)

[20240117 BmiZapper](#20240117-bmizapper---arbitrary-external-call-vulnerability)

[20240117 SocketGateway](#20240112-socketgateway---lack-of-calldata-validation)

[20240112 WiseLending](#20240112-wiselending---bad-healthfactor-check)

[20240110 LQDX Alert](#20240110-lqdx---unauthorized-transferfrom)

[20240104 Gamma](#20240104-gamma---price-manipulation)

[20240102 RadiantCapital](#20240102-radiantcapital---loss-of-precision)

[20240101 OrbitChain](#20240101-orbitchain---incorrect-input-validation)

<details> <summary> 2023 </summary>

[20231230 ChannelsFinance](past/2023/README.md#20231230-channelsfinance---compoundv2-inflation-attack)

[20231225 Telcoin](past/2023/README.md#20231225-telcoin---storage-collision)

[20231222 PineProtocol](past/2023/README.md#20231222-pineprotocol---business-logic-flaw)

[20231220 TransitFinance](past/2023/README.md#20231220-transitfinance---lack-of-validation-pool)

[20231217 FloorProtocol](past/2023/README.md#20231217-floorprotocol---business-logic-flaw)

[20231216 GoodDollar](past/2023/README.md#20231216-gooddollar---lack-of-input-validation--reentrancy)

[20231216 NFTTrader](past/2023/README.md#20231216-nfttrader---reentrancy)

[20231213 HYPR](past/2023/README.md#20231213-hypr---business-logic-flaw)

[20231206 TIME](past/2023/README.md#20231206-time---arbitrary-address-spoofing-attack)

[20231206 ElephantStatus](past/2023/README.md#20231206-elephantstatus---price-manipulation)

[20231205 BEARNDAO](past/2023/README.md#20231205-bearndao---business-logic-flaw)

[20231201 UnverifiedContr_0x431abb](past/2023/README.md#20231201-unverifiedcontr_0x431abb---business-logic-flaw)

[20231129 AIS](past/2023/README.md#20231129-ais---access-control)

[20231125 TheNFTV2](past/2023/README.md#20231125-thenftv2---logic-flaw)

[20231122 KyberSwap](past/2023/README.md#20231122-kyberswap---precision-loss)

[20231117 Token8633_9419](past/2023/README.md#20231117-token8633_9419---price-manipulation)

[20231117 ShibaToken](past/2023/README.md#20231117-shibatoken---business-logic-flaw)

[20231115 LinkDAO](past/2023/README.md#20231115-linkdao---bad-k-value-verification)

[20231114 OKC Project](past/2023/README.md#20231114-OKC-Project---Instant-Rewards-Unlocked)

[20231112 MEV_0x8c2d](past/2023/README.md#20231112-mevbot_0x8c2d---lack-of-access-control)

[20231112 MEV_0xa247](past/2023/README.md#20231112-mevbot_0xa247---incorrect-access-control)

[20231111 Mahalend](past/2023/README.md#20231111-mahalend---donate-inflation-exchangerate--rounding-error)

[20231110 Raft_fi](past/2023/README.md#20231110-raft_fi---donate-inflation-exchangerate--rounding-error)

[20231110 GrokToken](past/2023/README.md#20231110-grok---lack-of-slippage-protection)

[20231107 MEVbot](past/2023/README.md#20231107-mevbot---lack-of-access-control)

[20231106 TrustPad](past/2023/README.md#20231106-trustpad---lack-of-msgsender-address-verification)

[20231106 TheStandard_io](past/2023/README.md#20231106-thestandard_io---lack-of-slippage-protection)

[20231102 3913Token](past/2023/README.md#20231102-3913token---deflationary-token-attack)

[20231101 OnyxProtocol](past/2023/README.md#20231101-onyxprotocol---precission-loss-vulnerability)

[20231031 UniBotRouter](past/2023/README.md#20231031-UniBotRouter---arbitrary-external-call)

[20231028 AstridProtocol](past/2023/README.md#20231028-AstridProtocol---business-logic-flaw)

[20231024 MaestroRouter2](past/2023/README.md#20231024-maestrorouter2---arbitrary-external-call)

[20231022 OpenLeverage](past/2023/README.md#20231022-openleverage---business-logic-flaw)

[20231019 kTAF](past/2023/README.md#20231019-ktaf---compoundv2-inflation-attack)

[20231018 HopeLend](past/2023/README.md#20231018-hopelend---div-precision-loss)

[20231018 MicDao](past/2023/README.md#20231018-micdao---price-manipulation)

[20231013 BelugaDex](past/2023/README.md#20231013-belugadex---price-manipulation)

[20231013 WiseLending](past/2023/README.md#20231013-wiselending---donate-inflation-exchangerate--rounding-error)

[20231012 Platypus](past/2023/README.md#20231012-platypus---business-logic-flaw)

[20231011 BH](past/2023/README.md#20231011-bh---price-manipulation)

[20231008 pSeudoEth](past/2023/README.md#20231008-pseudoeth---pool-manipulation)

[20231007 StarsArena](past/2023/README.md#20231007-starsarena---reentrancy)

[20231005 DePayRouter](past/2023/README.md#20231005-depayrouter---business-logic-flaw)

[20230930 FireBirdPair](past/2023/README.md#20230930-FireBirdPair---lack-slippage-protection)

[20230929 DEXRouter](past/2023/README.md#20230929-dexrouter---arbitrary-external-call)

[20230926 XSDWETHpool](past/2023/README.md#20230926-XSDWETHpool---reentrancy)

[20230924 KubSplit](past/2023/README.md#20230924-kubsplit---pool-manipulation)

[20230921 CEXISWAP](past/2023/README.md#20230921-cexiswap---incorrect-access-control)

[20230916 uniclyNFT](past/2023/README.md#20230916-uniclynft---reentrancy)

[20230911 0x0DEX](past/2023/README.md#20230911-0x0dex---parameter-manipulation)

[20230909 BFCToken](past/2023/README.md#20230909-bfctoken---business-logic-flaw)

[20230908 APIG](past/2023/README.md#20230908-apig---business-logic-flaw)

[20230907 HCT](past/2023/README.md#20230907-hct---price-manipulation)

[20230905 JumpFarm](past/2023/README.md#20230905-JumpFarm---rebasing-logic-issue)

[20230905 HeavensGate](past/2023/README.md#20230905-HeavensGate---rebasing-logic-issue)

[20230905 FloorDAO](past/2023/README.md#20230905-floordao---rebasing-logic-issue)

[20230902 DAppSocial](past/2023/README.md#20230902-dappsocial---business-logic-flaw)

[20230829 EAC](past/2023/README.md#20230829-eac---price-manipulation)

[20230827 Balancer](past/2023/README.md#20230827-balancer---rounding-error--business-logic-flaw)

[20230826 SVT](past/2023/README.md#20230826-svt---flawed-price-calculation)

[20230824 GSS](past/2023/README.md#20230824-gss---skim-token-balance)

[20230821 EHIVE](past/2023/README.md#20230821-ehive---business-logic-flaw)

[20230819 BTC20](past/2023/README.md#20230819-btc20---price-manipulation)

[20230818 ExactlyProtocol](past/2023/README.md#20230818-exactlyprotocol---insufficient-validation)

[20230814 ZunamiProtocol](past/2023/README.md#20230814-zunamiprotocol---price-manipulation)

[20230809 EarningFram](past/2023/README.md#20230809-earningfram---reentrancy)

[20230802 CurveBurner](past/2023/README.md#20230802-curveburner---lack-slippage-protection)

[20230802 Uwerx](past/2023/README.md#20230802-uwerx---fault-logic)

[20230801 NeutraFinance](past/2023/README.md#20230801-neutrafinance---price-manipulation)

[20230801 LeetSwap](past/2023/README.md#20230801-leetswap---access-control)

[20230731 GYMNET](past/2023/README.md#20230731-gymnet---insufficient-validation)

[20230730 Curve](past/2023/README.md#20230730-curve---vyper-compiler-bug--reentrancy)

[20230726 Carson](past/2023/README.md#20230726-carson---price-manipulation)

[20230724 Palmswap](past/2023/README.md#20230724-palmswap---business-logic-flaw)

[20230723 MintoFinance](past/2023/README.md#20230723-mintofinance---signature-replay)

[20230722 ConicFinance02](past/2023/README.md#20230722-conic-finance-02---price-manipulation)

[20230721 ConicFinance](past/2023/README.md#20230721-conic-finance---read-only-reentrancy--misconfiguration)

[20230721 SUT](past/2023/README.md#20230721-sut---business-logic-flaw)

[20230720 Utopia](past/2023/README.md#20230720-utopia---business-logic-flaw)

[20230720 FFIST](past/2023/README.md#20230720-ffist---business-logic-flaw)

[20230718 APEDAO](past/2023/README.md#20230718-apedao---business-logic-flaw)

[20230718 BNO](past/2023/README.md#20230718-bno---invalid-emergency-withdraw-mechanism)

[20230717 NewFi](past/2023/README.md#20230717-newfi---lack-slippage-protection)

[20230712 Platypus](past/2023/README.md#20230712-platypus---bussiness-logic-flaw)

[20230712 WGPT](past/2023/README.md#20230712-wgpt---business-logic-flaw)

[20230711 RodeoFinance](past/2023/README.md#20230711-rodeofinance---twap-oracle-manipulation)

[20230711 Libertify](past/2023/README.md#20230711-libertify---reentrancy)

[20230710 ArcadiaFi](past/2023/README.md#20230710-arcadiafi---reentrancy)

[20230708 CIVNFT](past/2023/README.md#20230708-civnft---lack-of-access-control)

[20230708 Civfund](past/2023/README.md#20230708-civfund---lack-of-access-control)

[20230707 LUSD](past/2023/README.md#20230707-LUSD---price-manipulation-attack)

[20230704 BambooIA](past/2023/README.md#20230704-bambooia---price-manipulation-attack)

[20230704 BaoCommunity](past/2023/README.md#20230704-baocommunity---donate-inflation-exchangerate--rounding-error)

[20230703 AzukiDAO](past/2023/README.md#20230703-azukidao---invalid-signature-verification)

[20230630 Biswap](past/2023/README.md#20230630-biswap---v3migrator-exploit)

[20230628 Themis](past/2023/README.md#20230628-themis---manipulation-of-prices-using-flashloan)

[20230623 SHIDO](past/2023/README.md#20230623-shido---business-loigc)

[20230621 BabyDogeCoin02](past/2023/README.md#20230621-babydogecoin02---lack-slippage-protection)

[20230621 BUNN](past/2023/README.md#20230621-bunn---reflection-tokens)

[20230620 MIM](past/2023/README.md#20230620-mimspell---arbitrary-external-call-vulnerability)

[20230618 ARA](past/2023/README.md#20230618-ara---incorrect-handling-of-permissions)

[20230617 Pawnfi](past/2023/README.md#20230617-pawnfi---business-logic-flaw)

[20230615 CFC](past/2023/README.md#20230615-cfc---uniswap-skim-token-balance-attack)

[20230615 DEPUSDT_LEVUSDC](past/2023/README.md#20230615-depusdt_levusdc---incorrect-access-control)

[20230612 Sturdy Finance](past/2023/README.md#20230612-sturdy-finance---read-only-reentrancy)

[20230611 SellToken04](past/2023/README.md#20230611-sellToken04---Price-Manipulation)

[20230607 CompounderFinance](past/2023/README.md#20230607-compounderfinance---manipulation-of-funds-through-fluctuations-in-the-amount-of-exchangeable-assets)

[20230606 VINU](past/2023/README.md#20230606-vinu---price-manipulation)

[20230606 UN](past/2023/README.md#20230606-un---price-manipulation)

[20230602 NST SimpleSwap](past/2023/README.md#20230602-nst-simple-swap---unverified-contract-wrong-approval)

[20230601 DDCoin](past/2023/README.md#20230601-ddcoin---flashloan-attack-and-smart-contract-vulnerability)

[20230601 Cellframenet](past/2023/README.md#20230601-cellframenet---calculation-issues-during-liquidity-migration)

[20230531 ERC20TokenBank](past/2023/README.md#20230531-erc20tokenbank---price-manipulation)

[20230529 Jimbo](past/2023/README.md#20230529-jimbo---protocol-specific-price-manipulation)

[20230529 BabyDogeCoin](past/2023/README.md#20230529-babydogecoin---lack-slippage-protection)

[20230529 FAPEN](past/2023/README.md#20230529-fapen---wrong-balance-check)

[20230529 NOON_NO](past/2023/README.md#20230529-noon-no---wrong-visibility-in-function)

[20230525 GPT](past/2023/README.md#20230525-gpt-token---fee-machenism-exploitation)

[20230524 LocalTrade](past/2023/README.md#20230524-local-trade-lct---improper-access-control-of-close-source-contract)

[20230524 CS](past/2023/README.md#20230524-cs-token---outdated-global-variable)

[20230523 LFI](past/2023/README.md#20230523-lfi-token---business-logic-flaw)

[20230514 landNFT](past/2023/README.md#20230514-landNFT---lack-of-permission-control)

[20230514 SellToken03](past/2023/README.md#20230514-selltoken03---unchecked-user-input)

[20230513 Bitpaidio](past/2023/README.md#20230513-bitpaidio---business-logic-flaw)

[20230513 SellToken02](past/2023/README.md#20230513-selltoken02---price-manipulation)

[20230512 LW](past/2023/README.md#20230512-lw---flashloan-price-manipulation)

[20230511 SellToken01](past/2023/README.md#20230511-selltoken01---business-logic-flaw)

[20230510 SNK](past/2023/README.md#20230510-snk---reward-calculation-error)

[20230509 MCC](past/2023/README.md#20230509-mcc---reflection-token)

[20230509 HODL](past/2023/README.md#20230509-hodl---reflection-token)

[20230506 Melo](past/2023/README.md#20230506-melo---access-control)

[20230505 DEI](past/2023/README.md#20230505-dei---wrong-implemention)

[20230503 NeverFall](past/2023/README.md#20230503-NeverFall---price-manipulation)

[20230502 Level](past/2023/README.md#20230502-level---business-logic-flaw)

[20230428 0vix](past/2023/README.md#20230428-0vix---flashloan-price-manipulation)

[20230427 SiloFinance](past/2023/README.md#20230427-Silo-finance---Business-Logic-Flaw)

[20230424 Axioma](past/2023/README.md#20230424-Axioma---business-logic-flaw)

[20230419 OLIFE](past/2023/README.md#20230419-OLIFE---Reflection-token)

[20230416 Swapos V2](past/2023/README.md#20230416-swapos-v2---error-k-value-attack)

[20230415 HundredFinance](past/2023/README.md#20230415-hundredfinance---donate-inflation-exchangerate--rounding-error)

[20230413 yearnFinance](past/2023/README.md#20230413-yearnFinance---misconfiguration)

[20230412 MetaPoint](past/2023/README.md#20230412-metapoint---Unrestricted-Approval)

[20230411 Paribus](past/2023/README.md#20230411-paribus---reentrancy)

[20230409 SushiSwap](past/2023/README.md#20230409-SushiSwap---Unchecked-User-Input)

[20230405 Sentiment](past/2023/README.md#20230405-sentiment---read-only-reentrancy)

[20230402 Allbridge](past/2023/README.md#20230402-allbridge---flashloan-price-manipulation)

[20230328 SafeMoon Hack](past/2023/README.md#20230328-safemoon-hack)

[20230328 THENA](past/2023/README.md#20230328---thena---yield-protocol-flaw)

[20230325 DBW](past/2023/README.md#20230325---dbw--business-logic-flaw)

[20230322 BIGFI](past/2023/README.md#20230322---bigfi---reflection-token)

[20230317 ParaSpace NFT](past/2023/README.md#20230317---paraspace-nft---flashloan--scaledbalanceof-manipulation)

[20230315 Poolz](past/2023/README.md#20230315---poolz---integer-overflow)

[20230313 EulerFinance](past/2023/README.md#20230313---eulerfinance---business-logic-flaw)

[20230308 DKP](past/2023/README.md#20230308---dkp---flashloan-price-manipulation)

[20230307 Phoenix](past/2023/README.md#20230307---phoenix---access-control--arbitrary-external-call)

[20230227 LaunchZone](past/2023/README.md#20230227---launchzone---access-control)

[20230227 SwapX](past/2023/README.md#20230227---swapx---access-control)

[20230224 EFVault](past/2023/README.md#20230224---efvault---storage-collision)

[20230222 DYNA](past/2023/README.md#20230222---dyna---business-logic-flaw)

[20230218 RevertFinance](past/2023/README.md#20230218---revertfinance---arbitrary-external-call-vulnerability)

[20230217 Starlink](past/2023/README.md#20230217---starlink---business-logic-flaw)

[20230217 Dexible](past/2023/README.md#20230217---dexible---arbitrary-external-call-vulnerability)

[20230217 Platypusdefi](past/2023/README.md#20230217---platypusdefi---business-logic-flaw)

[20230210 Sheep Token](past/2023/README.md#20230210---sheep---reflection-token)

[20230210 dForce](past/2023/README.md#20230210---dforce---read-only-reentrancy)

[20230207 CowSwap](past/2023/README.md#20230207---cowswap---arbitrary-external-call-vulnerability)

[20230206 FDP Token](past/2023/README.md#20230206---fdp---reflection-token)

[20230203 Orion Protocol](past/2023/README.md#20230203---orion-protocol---reentrancy)

[20230203 Spherax USDs](past/2023/README.md#20230203---spherax-usds---balance-recalculation-bug)

[20230202 BonqDAO](past/2023/README.md#20230202---BonqDAO---price-oracle-manipulation)

[20230130 BEVO](past/2023/README.md#20230130---bevo---reflection-token)

[20230126 TomInu Token](past/2023/README.md#20230126---tinu---reflection-token)

[20230119 SHOCO Token](past/2023/README.md#20230119---shoco---reflection-token)

[20230119 ThoreumFinance](past/2023/README.md#20230119---thoreumfinance-business-logic-flaw)

[20230118 QTN Token](past/2023/README.md#20230118---qtntoken---business-logic-flaw)

[20230118 UPS Token](past/2023/README.md#20230118---upstoken---business-logic-flaw)

[20230117 OmniEstate](past/2023/README.md#20230117---OmniEstate---no-input-parameter-check)

[20230116 MidasCapital](past/2023/README.md#20230116---midascapital---read-only-reentrancy)

[20230111 UFDao](past/2023/README.md#20230111---ufdao---incorrect-parameter-setting)

[20230111 ROE](past/2023/README.md#20230111---roefinance---flashloan-price-manipulation)

[20230110 BRA](past/2023/README.md#20230110---bra---business-logic-flaw)

[20230103 GDS](past/2023/README.md#20230103---gds---business-logic-flaw)

</details>

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

[20221207 AES](past/2022/README.md#20221207---aes-deflationary-token---business-logic-flaw--flashloan-price-manipulation)

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

[20220706 FlippazOne NFT](past/2022/README.md#20220706-flippazone-nft---accesscontrol)

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

[20220415 Rikkei Finance](past/2022/README.md#20220415-rikkei-finance---access-control--price-oracle-manipulation)

[20220412 ElephantMoney](past/2022/README.md#20220412-elephantmoney---flashloan--price-oracle-manipulation)

[20220411 Creat Future](past/2022/README.md#20220411-creat-future)

[20220409 GYMNetwork](past/2022/README.md#20220409-gymnetwork---flashloan--token-migrate-flaw)

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

[20220309 Fantasm Finance](past/2022/README.md#20220309-fantasm-finance---business-logic-in-mint)

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

### 20240430 PikeFinance - Uninitialized Proxy

### Lost: 1.4M


```sh
forge test --contracts ./src/test/PikeFinance_exp.sol -vvv
```
#### Contract
[PikeFinance_exp.sol](src/test/PikeFinance_exp.sol)
### Link reference

https://twitter.com/Phalcon_xyz/status/1785508900093194591

---

### 20240425 NGFS - Bad Access Control

### Lost: ~190K

```sh
forge test --contracts ./src/test/NGFS_exp.sol -vvv --evm-version shanghai
```

#### Contract

[NGFS_exp.sol](src/test/NGFS_exp.sol)

### Link reference

https://twitter.com/CertiKAlert/status/1783476515331616847

---

### 20240424 XBridge - Logic Flaw

### Lost: >200k USD(plus a lot of STC, SRLTY, Mazi tokens)

```sh
forge test --contracts ./src/test/XBridge_exp.sol -vvv
```

#### Contract

[XBridge_exp.sol](src/test/XBridge_exp.sol)

---

### 20240424 YIEDL - Input Validation

### Lost: 150k USD

```sh
forge test --contracts ./src/test/YIEDL_exp.sol -vvv
```

### 20240422 Z123 - price manipulation

### Lost: 136k USD

```sh
forge test --contracts ./src/test/Z123_exp.sol -vvv
```

#### Contract

[Z123_exp.sol](src/test/Z123_exp.sol)

### Link reference

https://twitter.com/PeckShieldAlert/status/1782322484911784385

---

### 20240420 Rico - Arbitrary Call

### Lost: 36K

```sh
forge test --contracts ./src/test/2024-04/Rico_exp.sol -vvv
```

#### Contract

[Rico_exp.sol](src/test/Rico_exp.sol)

### Link reference

https://twitter.com/ricocreditsys/status/1781803698940781009

---

### 20240419 HedgeyFinance - Logic Flaw

### Lost: 48M USD

```sh
forge test --contracts ./src/test/others/HedgeyFinance_exp.sol -vvv
```

#### Contract

[HedgeyFinance_exp.sol](src/test/others/HedgeyFinance_exp.sol)

### Link reference

https://twitter.com/Cube3AI/status/1781294512716820918

---

### 20240416 SATX - Logic Flaw

### Lost: ~ 50 BNB

```sh
forge test --contracts src/test/others/SATX_exp.sol -vvv
```

#### Contract

[SATX_exp.sol](src/test/others/SATX_exp.sol)

### Link reference

https://x.com/bbbb/status/1780341239801393479

---

### 20240416 MARS - Bad Reflection

### Lost: >100K

```sh
forge test --contracts src/test/others/MARS_exp.sol -vv
```

#### Contract

[MARS_exp.sol](src/test/others/MARS_exp.sol)

### Link reference

https://twitter.com/Phalcon_xyz/status/1780150315603701933

### 20240415 Chainge - Input Validation

### Lost: ~200K

```sh
forge test --contracts ./src/test/others/Chainge_exp.sol -vvv
```

#### Contract

[Chainge_exp.sol](src/test/others/Chainge_exp.sol)

### Link reference

https://twitter.com/CyversAlerts/status/1779875922381860920

---

### 20240412 FIL314 - Insufficient Validation And Price Manipulation

### Lost: ~14 BNB

```sh
forge test --contracts ./src/test/2024-04/FIL314_exp.sol -vvv
```

#### Contract

[FIL314_exp.sol](src/test/2024-04/FIL314_exp.sol)

### Link reference

---

### 20240412 SumerMoney - Reentrancy

### Lost: 350K

```sh
forge test --contracts ./src/test/2024-04/SumerMoney_exp.sol -vvv
```

#### Contract

[SumerMoney_exp.sol](src/test/2024-04/SumerMoney_exp.sol)

### Link reference

https://twitter.com/0xNickLFranklin/status/1778986926705672698

---

### 20240412 GROKD - lack of access control

### Lost: $~150 BNB

```
forge test --contracts ./src/test/2024-04/GROKD_exp.sol -vvv
```

#### Contract

[GROKD_exp.sol](src/test/2024-04/GROKD_exp.sol)

### Link reference

https://x.com/hipalex921/status/1778482890705416323?t=KvvG83s7SXr9I55aftOc6w&s=05

---

### 20240409 UPS - business logic flaw

### Lost: $~28K USD

```
forge test --contracts ./src/test/2024-04/UPS_exp.sol -vvv
```

#### Contract

[UPS_exp.sol](src/test/2024-04/UPS_exp.sol)

### Link reference

https://twitter.com/0xNickLFranklin/status/1777589021058728214

---

### 20240408 SQUID - sandwich attack

### Lost: $~87K USD

```
forge test --contracts ./src/test/2024-04/SQUID_exp.sol -vvv
```

#### Contract

[SQUID_exp.sol](src/test/2024-04/SQUID_exp.sol)

### Link reference

https://twitter.com/bbbb/status/1777228277415039304

---

### 20240404 wsm - manipulating price

### Lost: $~18K USD

```
forge test --contracts ./src/test/2024-04/WSM_exp.sol -vvv
```

#### Contract

[WSM_exp.sol](src/test/2024-04/WSM_exp.sol)

### Link reference

https://hacked.slowmist.io/#:~:text=Hacked%20target%3A%20Wall%20Street%20Memes

---

### 20240401 ATM - business logic flaw

### Lost: $~182K USD

```
forge test --contracts ./src/test/2024-04/ATM_exp.sol -vvv
```

#### Contract

[ATM_exp.sol](src/test/2024-04/ATM_exp.sol)

### Link reference

https://twitter.com/0xNickLFranklin/status/1775008489569718508

---

### 20240401 OpenLeverage - Reentrancy

### Lost: ~234K

```
forge test --contracts src/test/2024-04/OpenLeverage2_exp.sol -vvv
```

#### Contract

[OpenLeverage2_exp.sol](src/test/2024-04/OpenLeverage2_exp.sol)

### Link reference

https://twitter.com/0xNickLFranklin/status/1774727539975672136

---

### 20240329 PrismaFi - Insufficient Validation

### Lost: $~11M

```sh
forge test --contracts ./src/test/2024-03/Prisma_exp.sol -vvv
```

#### Contract

[Prisma_exp.sol](src/test/2024-03/Prisma_exp.sol)

### Link reference

https://twitter.com/EXVULSEC/status/1773371049951797485

---

### 20240328 LavaLending - Business Logic Flaw

### Lost: ~340K

```
forge test --contracts src/test/2024-03/LavaLending_exp.sol -vvv
```

#### Contract

[LavaLending_exp.sol](src/test/2024-03/LavaLending_exp.sol)

#### Link reference

https://twitter.com/0xNickLFranklin/status/1774727539975672136

https://twitter.com/Phalcon_xyz/status/1773546399713345965

https://hackmd.io/@LavaSecurity/03282024

---

### 20240325 ZongZi - Price Manipulation

### Lost: ~223K

```
forge test --contracts src/test/2024-03/ZongZi_exp.sol -vvv
```

#### Contract

[ZongZi_exp.sol](src/test/2024-03/ZongZi_exp.sol)

#### Link reference

https://twitter.com/0xNickLFranklin/status/1772195949638775262

---

### 20240321 SSS - Token Balance Doubles on Transfer to self

### Lost: 4.8M

```sh
forge test --contracts ./src/test/2024-03/SSS_exp.sol -vvv
```

#### Contract

[SSS_exp.sol](src/test/2024-03/SSS_exp.sol)

### Link reference

https://twitter.com/dot_pengun/status/1770989208125272481

---

### 20240324 ARK - business logic flaw

### Lost: ~348BNB

```
forge test --contracts src/test/2024-03/ARK_exp.sol -vvv
```

#### Contract

[ARK_exp.sol](src/test/2024-03/ARK_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1771728823534375249

---

### 20240320 Paraswap - Incorrect Access Control

### Lost: ~24K

```
forge test --contracts src/test/2024-03/Paraswap_exp.sol -vvv --evm-version shanghai
```

#### Contract

[Paraswap_exp.sol](src/test/2024-03/Paraswap_exp.sol)

#### Link reference

https://medium.com/neptune-mutual/analysis-of-the-paraswap-exploit-1f97c604b4fe

---

### 20240314 MO - business logic flaw

### Lost: ~413k USDT

```
forge test --contracts src/test/2024-03/MO_exp.sol -vvv
```

#### Contract

[MO_exp.sol](src/test/2024-03/MO_exp.sol)

#### Link reference

https://twitter.com/0xNickLFranklin/status/1768184024483430523

---

### 20240313 IT - business logic flaw

### Lost: ~13k USDT

```
forge test --via-ir  --contracts src/test/2024-03/IT_exp.sol -vvv
```

#### Contract

[IT_exp.sol](src/test/2024-03/IT_exp.sol)

#### Link reference

https://twitter.com/0xNickLFranklin/status/1768171595561046489

---

### 20240309 Juice - Business Logic Flaw

### Lost: ~54 ETH

```sh
forge test --contracts ./src/test/2024-03/Juice_exp.sol -vvv
```

#### Contract

[Juice_exp.sol](src/test/2024-03/Juice_exp.sol)

### Link reference

https://medium.com/@juicebotapp/juice-staking-exploit-next-steps-95e218b3ec71

---

### 20240309 UnizenIO - unverified external call

### Lost: ~2M

```
forge test --contracts src/test/2024-03/UnizenIO_exp.sol -vvvv
```

#### Contract

[UnizenIO_exp.sol](src/test/2024-03/UnizenIO_exp.sol) | [UnizenIO2_exp.sol](src/test/2024-03/UnizenIO2_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1766274000534004187

https://twitter.com/AnciliaInc/status/1766261463025684707

---

### 20240307 GHT - Business Logic Flaw

### Lost: ~57K

```
forge test --contracts ./src/test/2024-03/GHT_exp.sol -vvv
```

#### Contract

[GHT_exp.sol](src/test/2024-03/GHT_exp.sol)

#### Link reference

---

### 20240306 ALP - Public internal function

### Lost: ~10K

Testing

```
forge test --contracts ./src/test/2024-03/ALP_exp.sol -vvv
```

#### Contract

[ALP_exp.sol](src/test/2024-03/ALP_exp.sol)

#### Link Reference

https://twitter.com/0xNickLFranklin/status/1765296663667875880

---

### 20240306 TGBS - Business Logic Flaw

### Lost: ~150K

```
forge test --contracts ./src/test/2024-03/TGBS_exp.sol -vvv
```

#### Contract

[TGBS_exp.sol](src/test/2024-03/TGBS_exp.sol)

#### Link reference

https://twitter.com/0xNickLFranklin/status/1765290290083144095

https://twitter.com/Phalcon_xyz/status/1765285257949974747

---

### 20240305 Woofi - Price Manipulation

### Lost: ~8M

```
forge test --contracts ./src/test/2024-03/Woofi_exp.sol -vvv
```

#### Contract

[Woofi_exp.sol](src/test/2024-03/Woofi_exp.sol)

#### Link reference

https://twitter.com/spreekaway/status/1765046559832764886
https://twitter.com/PeckShieldAlert/status/1765054155478175943

---

### 20240228 Seneca - Arbitrary External Call Vulnerability

### Lost: ~6M

```
forge test --contracts ./src/test/2024-02/Seneca_exp.sol -vvv
```

#### Contract

[Seneca_exp.sol](src/test/2024-02/Seneca_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1763045563040411876

---

### 20240228 SMOOFSStaking - Reentrancy

### Lost: Unclear

```
forge test --contracts ./src/test/2024-02/SMOOFSStaking_exp.sol -vvv
```

#### Contract

[SMOOFSStaking_exp.sol](src/test/2024-02/SMOOFSStaking_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1762893563103428783

https://twitter.com/0xNickLFranklin/status/1762895774311178251

---

### 20240223 CompoundUni - Oracle bad price

### Lost: ~439,537 USD

```
forge test --contracts ./src/test/2024-02/CompoundUni_exp.sol -vvv
```

#### Contract

[CompoundUni_exp.sol](src/test/2024-02/CompoundUni_exp.sol)

#### Link reference

https://twitter.com/0xLEVI104/status/1762092203894276481

---

### 20240223 BlueberryProtocol - logic flaw

### Lost: ~1,400,000 USD

```
forge test --contracts ./src/test/2024-02/BlueberryProtocol_exp.sol -vvv
```

#### Contract

[BlueberryProtocol_exp.sol](src/test/2024-02/BlueberryProtocol_exp.sol)

#### Link reference

https://twitter.com/blueberryFDN/status/1760865357236211964

---

### 20240221 DeezNutz 404 - lack of validation

### Lost: ~170k

```
forge test --contracts ./src/test/2024-02/DeezNutz404_exp.sol -vvv
```

#### Contract

[DeezNutz404_exp.sol](src/test/2024-02/DeezNutz404_exp.sol)

#### Link reference

https://twitter.com/0xNickLFranklin/status/1760481343161700523

---

### 20240221 GAIN - bad function implementation

### Lost: ~6.4 ETH

```
forge test --contracts ./src/test/2024-02/GAIN_exp.sol -vvv
```

#### Contract

[GAIN_exp.sol](src/test/2024-02/GAIN_exp.sol)

#### Link reference

https://twitter.com/0xNickLFranklin/status/1760559768241160679

---

### 20240219 RuggedArt - reentrancy

### Lost: ~10k

```
forge test --contracts ./src/test/others/RuggedArt_exp.sol -vvv
```

#### Contract

[RuggedArt_exp.sol](src/test/others/RuggedArt_exp.sol)

#### Link reference

https://twitter.com/EXVULSEC/status/1759822545875025953

---

### 20240216 ParticleTrade - lack of validation data

### Lost: ~50k

```
forge test --contracts ./src/test/2024-02/ParticleTrade_exp.sol -vvv
```

#### Contract

[ParticleTrade_exp.sol](src/test/2024-02/ParticleTrade_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1758028270770250134

---

### 20240215 DualPools - precision truncation

### Lost: ~42k

```
forge test --contracts ./src/test/2024-02/DualPools_exp.sol -vvvv
```

#### Contract

[DualPools_exp.sol](src/test/2024-02/DualPools_exp.sol)

#### Link reference

https://medium.com/@lunaray/dualpools-hack-analysis-5209233801fa

---

### 20240215 Miner - lack of validation dst address

### Lost: ~150k

```
forge test --contracts ./src/test/2024-02/Miner_exp.sol -vvv --evm-version shanghai
```

#### Contract

[Miner_exp.sol](src/test/2024-02/Miner_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1757777340002681326

---

### 20240211 Game - Reentrancy && Business Logic Flaw

### Lost: ~20 ETH

```
forge test --contracts ./src/test/2024-02/Game_exp.sol -vvv
```

#### Contract

[Game_exp.sol](src/test/2024-02/Game_exp.sol)

#### Link reference

https://twitter.com/AnciliaInc/status/1757533144033739116

---

### 20240210 FILX DN404 - Access Control

### Lost: 200K


```sh
forge test --contracts ./src/test/2024-02/DN404_exp.sol -vvv
```
#### Contract
[DN404_exp.sol](src/test/2024-02/DN404_exp.sol)

---
### 20240208 Pandora - interger underflow

### Lost: ~17K USD

```
forge test --contracts ./src/test/2024-02/PANDORA_exp.sol -vvv
```

#### Contract

[PANDORA_exp.sol](src/test/2024-02/PANDORA_exp.sol)

#### Link reference

https://twitter.com/pennysplayer/status/1766479470058406174

---

### 20240205 BurnsDefi - Price Manipulation

### Lost: ~67K

```
forge test --contracts ./src/test/2024-02/BurnsDefi_exp.sol -vvv
```

#### Contract

[BurnsDefi_exp.sol](src/test/2024-02/BurnsDefi_exp.sol)

#### Link reference

https://twitter.com/pennysplayer/status/1754342573815238946

https://medium.com/neptune-mutual/how-was-citadel-finance-exploited-a5f9acd0b408 (similar incident)

---

### 20240201 AffineDeFi - lack of validation userData

### Lost: ~88K

```
forge test --contracts ./src/test/2024-02/AffineDeFi_exp.sol -vvv
```

#### Contract

[AffineDeFi_exp.sol](src/test/2024-02/AffineDeFi_exp.sol)

#### Link reference

https://twitter.com/Phalcon_xyz/status/1753020812284809440

https://twitter.com/CyversAlerts/status/1753040754287513655

---

### 20240130 MIMSpell - Precission Loss

### Lost: ~6,5M

```
forge test --contracts ./src/test/2024-01/MIMSpell2_exp.sol -vvv
```

#### Contract

[MIMSpell2_exp.sol](src/test/2024-01/MIMSpell2_exp.sol)

#### Link reference

https://twitter.com/kankodu/status/1752581744803680680

https://twitter.com/Phalcon_xyz/status/1752278614551216494

https://twitter.com/peckshield/status/1752279373779194011

https://phalcon.blocksec.com/explorer/security-incidents

---

### 20240128 BarleyFinance - Reentrancy

### Lost: ~130K

```
forge test --contracts ./src/test/2024-01/BarleyFinance_exp.sol -vvv
```

#### Contract

[BarleyFinance_exp.sol](src/test/2024-01/BarleyFinance_exp.sol)

#### Link reference

https://phalcon.blocksec.com/explorer/security-incidents

https://www.bitget.com/news/detail/12560603890246

https://twitter.com/Phalcon_xyz/status/1751788389139992824

---

### 20240127 CitadelFinance - Price Manipulation

### Lost: ~93K

```
forge test --contracts ./src/test/2024-01/CitadelFinance_exp.sol -vvv
```

#### Contract

[CitadelFinance_exp.sol](src/test/2024-01/CitadelFinance_exp.sol)

#### Link reference

https://medium.com/neptune-mutual/how-was-citadel-finance-exploited-a5f9acd0b408

---

### 20240125 NBLGAME - Reentrancy

### Lost: ~180K

```
forge test --contracts ./src/test/2024-01/NBLGAME_exp.sol -vvv
```

#### Contract

[NBLGAME_exp.sol](src/test/2024-01/NBLGAME_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1750526097106915453

https://twitter.com/AnciliaInc/status/1750558426382635036

---

### 20240122 DAO_SoulMate - Incorrect Access Control

### Lost: ~319K

```
forge test --contracts ./src/test/2024-01/DAO_SoulMate_exp.sol -vvv --evm-version 'shanghai'
```

#### Contract

[DAO_SoulMate_exp.sol](src/test/2024-01/DAO_SoulMate_exp.sol)

#### Link reference

https://twitter.com/MetaSec_xyz/status/1749743245599617282

---

### 20240117 BmiZapper - Arbitrary external call vulnerability

### Lost: ~114K

```
forge test --contracts ./src/test/2024-01/Bmizapper_exp.sol -vvv
```

#### Contract

[BmiZapper_exp.sol](src/test/2024-01/BmiZapper_exp.sol)

#### Link reference

https://x.com/0xmstore/status/1747756898172952725

---

### 20240112 SocketGateway - Lack of calldata validation

### Lost: ~3.3Million $

```
forge test --contracts ./src/test/2024-01/SocketGateway_exp.sol -vvv --evm-version shanghai
```

#### Contract

[SocketGateway_exp.sol](src/test/2024-01/SocketGateway_exp.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1747450173675196674

https://twitter.com/peckshield/status/1747353782004900274

---

### 20240112 WiseLending - Bad HealthFactor Check

### Lost: ~464K

```
forge test --contracts ./src/test/others/WiseLending02.exp.sol -vvv --evm-version shanghai
```

#### Contract

[WiseLending02_exp.sol](src/test/others/WiseLending02_exp.sol)

[WiseLending02.exp.sol](src/test/others/WiseLending02.exp.sol)

#### Link reference

https://twitter.com/danielvf/status/1746303616778981402

---

### 20240110 LQDX - Unauthorized TransferFrom

### Lost: unknown

```
forge test --contracts src/test/2024-01/LQDX_alert_exp.sol -vvv
```

#### Contract

[LQDX_alert_exp.sol](src/test/2024-01/LQDX_alert_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1744972012865671452

---

### 20240104 Gamma - Price manipulation

### Lost: ~6.3M

```
forge test --contracts ./src/test/2024-01/Gamma_exp.sol -vvv
```

#### Contract

[Gamma_exp.sol](src/test/2024-01/Gamma_exp.sol)

#### Link reference

https://twitter.com/officer_cia/status/1742772207997050899

https://twitter.com/shoucccc/status/1742765618984829326

---

### 20240102 RadiantCapital - Loss of Precision

### Lost: ~4,5M

```
forge test --contracts ./src/test/2024-01/RadiantCapital_exp.sol -vvv
```

#### Contract

[RadiantCapital_exp.sol](src/test/2024-01/RadiantCapital_exp.sol)

#### Link reference

https://neptunemutual.com/blog/how-was-radiant-capital-exploited/

https://twitter.com/BeosinAlert/status/1742389285926678784

---

### 20240101 OrbitChain - Incorrect input validation

### Lost: ~81M

```
forge test --contracts ./src/test/2024-01/OrbitChain_exp.sol -vvv
```

#### Contract

[OrbitChain_exp.sol](src/test/2024-01/OrbitChain_exp.sol)

#### Link reference

https://blog.solidityscan.com/orbit-chain-hack-analysis-b71c36a54a69

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
