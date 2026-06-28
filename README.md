# DeFi Hacks Reproduce - Foundry

**Reproduce DeFi hack incidents using Foundry.**


764 incidents included.

Let's make Web3 secure! Join [Discord](https://discord.gg/Fjyngakf3h)

Notion: [101 root cause analysis of past DeFi hacked incidents](https://web3sec.xrex.io/)

[Transaction debugging tools](https://github.com/SunWeb3Sec/DeFiHackLabs/#transaction-debugging-tools)

**Disclaimer:** This content serves solely as a proof of concept showcasing past DeFi hacking incidents. It is strictly intended for educational purposes and should not be interpreted as encouraging or endorsing any form of illegal activities or actual hacking attempts. The provided information is for informational and learning purposes only, and any actions taken based on this content are solely the responsibility of the individual. The usage of this information should adhere to applicable laws, regulations, and ethical standards.

## Table of Contents
* [Getting Started](#getting-started)
* [Who Support Us](#who-support-us-defihacklabs-received-grant-from)
* [Donate Us](#donate-us)
* [List of Past DeFi Incidents](#list-of-past-defi-incidents)
* [Transaction debugging tools](#transaction-debugging-tools)
* [Ethereum Signature Database](#ethereum-signature-database)
* [Useful tools](#useful-tools)
* [Hacks Dashboard](#hacks-dashboard)
* [List of DeFi Hacks & POCs](#list-of-defi-hacks--pocs)
  
## Getting Started

- Follow the [instructions](https://www.getfoundry.sh/introduction/getting-started) to install [Foundry](https://github.com/foundry-rs/foundry).

- Clone and install dependencies:`git submodule update --init --recursive`
- [Contributing Guidelines](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/CONTRIBUTING.md)

## [Web3 Cybersecurity Academy](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy)

All articles are also published on [Substack](https://defihacklabs.substack.com/).

### OnChain transaction debugging

- Lesson 1: Tools ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/en) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools) | [Vietnamese](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/vi) | [Korean](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/ko) | [Spanish](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/es) | [日本語](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/ja) )
- Lesson 2: Warm up ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/02_warmup/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/02_warmup/) | [Korean](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/02_warmup/ko) | [Spanish](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/02_warmup/es) | [日本語](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/02_warmup/ja) )
- Lesson 3: Write Your Own PoC (Price Oracle Manipulation) ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03_write_your_own_poc/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03_write_your_own_poc/) | [Korean](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03_write_your_own_poc/ko) | [Spanish](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03_write_your_own_poc/es) | [日本語](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/03_write_your_own_poc/ja) )
- Lesson 4: Write Your Own PoC (MEV Bot) ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04_write_your_own_poc/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04_write_your_own_poc/) | [Korean](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04_write_your_own_poc/kr/) | [Spanish](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04_write_your_own_poc/es) | [日本語](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/04_write_your_own_poc/ja) )
- Lesson 5: Rugpull Analysis ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/05_Rugpull/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/05_Rugpull/) | [Spanish](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/05_Rugpull/es) | [日本語](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/05_Rugpull/ja)  )
- Lesson 6: Write Your Own PoC (Reentrancy) ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06_write_your_own_poc/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06_write_your_own_poc/) | [Spanish](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06_write_your_own_poc/es) | [日本語](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/06_write_your_own_poc/ja) )
- Lesson 7: Hack Analysis: Nomad Bridge, August 2022 ( [English](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/07_Analysis_nomad_bridge/en/) | [中文](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/07_Analysis_nomad_bridge/) | [Spanish](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/07_Analysis_nomad_bridge/es) | [日本語](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/07_Analysis_nomad_bridge/ja) )

## Donate us

If you appreciate our work, please consider donating. Even a small amount helps us continue developing and improving our projects, and promoting web3 security.

- Gitcoin - [Donate DeFiHackLabs](https://explorer.gitcoin.co/#/projects/0xbea14fd383c20cd085f30b2baa83ce96be83f1b56464bd74fcc00eb85086e280)
- EVM Chains - 0xD7d6215b4EF4b9B5f40baea48F41047Eb67a11D5
- [Giveth](https://giveth.io/donate/defihacklabs)

## List of Past DeFi Incidents
[20260625 LixirPermitDrain](#20260625-lixirpermitdrain---broken-signature-verification)
[20260625 OceanBPoolSideStaking](#20260625-oceanbpoolsidestaking---bpool-single-sided-joinexit-math-with-sidestaking-gulp-accounting)
[20260624 DLMC](#20260624-dlmc---reserve-derived-liveprice-manipulation)
[20260623 RoyalRoyalties](#20260623-royalroyalties---zero-amount-erc1155-batch-transfer-inflated-royal-lda-tier-balance)

[20260622 Aztec Escape Hatch](#20260622-aztec-escape-hatch---proof_id-accounting-bypass-whitehat-reproduction)

[20260622 ATM](#20260622-atm---lp-token-burn)

[20260620 OLPC](#20260620-olpc---olpc-pair-reserve-manipulation)

[20260618 JB](#20260618-jb---jb-helper-repeated-cycle-drains-jbusdt-pair)

[20260617 WHALE](#20260617-whale---transfer-accounting-reserve-desync)

[20260617 LBP](#20260617-lbp---lbp-balanceof-reward-accounting)
[20260617 Aztec V1](#20260617-aztec-v1---escapehatch-proof-forgery-permissionless-rollupprocessor-exit)

[20260616 DIP](#20260616-dip---fee-on-transfer-reserve-manipulation)

[20260615 Thetanuts](#20260615-thetanuts---index-vault-component-share-accounting-flaw)

[20260614 Aztec Connect](#20260614-aztec-connect---numrealtxs-proofsettlement-mismatch-permissionless-rollupprocessorv3)

[20260609 TOPBPool](#20260609-topbpool---governance-controlled-token-mint-and-balancer-pool-drain)

[20260609 NovaBox](#20260609-novabox---constructor-dividend-checkpoint-bypass)

[20260607 AmbientCrocSwapDex](#20260607-ambientcrocswapdex---native-surplus-accounting-flaw)

[20260606 BOSS](#20260606-boss---boss-helper-mintburn-and-transfer-tax-pool-skew)

[20260605 DTXT](#20260605-dtxt---liquidity-misclassification-fee-bypass)

[20260605 AISOTHPresale](#20260605-aisothpresale---fixed-price-presale-arbitrage)

[20260604 BYToken](#20260604-bytoken---permissionless-triggerautoburn-reserve-manipulation)

[20260604 ATM Token](#20260604-atm-token---hidden-transferfrom-auto-swap-drain)

[20260530 AROS](#20260530-aros---signature-replay)

[20260529 YSDAO](#20260529-ysdao---price-manipulation-and-tax-bypass)

[20260528 LegendaryMoneyMonNft](#20260528-legendarymoneymon---ecrecover-address0-signature-bypass)

[20260528 DxSale](#20260528-dxsale---ownership-override-attack)

[20260527 Joe Agent](#20260527-joe-agent---reentrancy-in-removeliquidityviacontract)

[20260526 SKP Token](#20260526-skp-token---owner-backdoor-lp-burn--price-manipulation)

[20260526 SKP Token](#20260526-skp-token---deliberately-engineered-drain-insider-exploit--rug-pull)

[20260525 SquidRouterModule](#20260525-squidroutermodule---missing-caller-check)

[20260525 New Market Trading](#20260525-new-market-trading---squidroutermodule-missing-caller-check)

[20260525 WUSD.fi](#20260525-wusdfi---englove-sybil-incentive-abuse)

[20260522 FractalProtocol](#20260522-fractalprotocol---business-logic-flaw)

[20260521 MureDistribution](#20260521-muredistribution---signature-verification-bypass)

[20260520 MAPProtocol](#20260520-mapprotocol---arbitrary-mint)

[20260519 ElevateFi](#20260519-elevatefi---reserve-price-manipulation)

[20260518 TesseraSwap](#20260518-tesseraswap---callback-repayment-price-spread)

[20260517 VerusBridge](#20260517-verusbridge---insufficient-validation)

[20260517 SEAToken](#20260517-seatoken---business-logic-flaw)

[20260515 AdsharesBridge](#20260515-adsharesbridge---insufficient-validation)

[20260512 SQTokenStaking](#20260512-sqtokenstaking---access-control)

[20260511 INKFinance](#20260511-inkfinance---business-logic-flaw)
[20260511 HumaFinance](#20260511-humafinance---credit-approval-bypass)

[20260510 Renegade](#20260510-renegade---uninitialized-proxy)

[20260507 TrustedVolumes](#20260507-trustedvolumes---signature-replay)

[20260505 Ekubo](#20260505-ekubo---business-logic-flaw)

[20260501 SharwaMarginTrading](#20260501-sharwamargintrading---hegic-collateral-spot-price-manipulation)

[20260428 RWAVault](#20260428-rwavault---missing-erc4626-allowance-check)

[20260428 JUDAO](#20260428-judao---judao-sell-hook-reserve-drain)

[20260427 Unverified_a152](#20260427-unverified_a152---allowancetarget-approval-drain)

[20260425 SingularityDynaVault](#20260425-singularitydynavault---oracle-misconfiguration--share-inflation)

[20260423 GiddyVaultV3](#20260423-giddyvaultv3---incomplete-signature-coverage)

[20260421 KipseliPropAMM](#20260421-kipselipropamm---pricing--decimals-mismatch)

[20260420 JuiceboxREVLoans](#20260420-juiceboxrevloans---fake-terminal-loan-source-validation-bypass)

[20260420 ThetanutsVaultShareRounding](#20260420-thetanutsvaultsharerounding---vault-share-rounding-manipulation)

[20260419 AaveRebalancerCreditDelegation](#20260419-aaverebalancercreditdelegation---arbitrary-external-call--credit-delegation-abuse)

[20260415 XLootStaking](#20260415-xlootstaking---duplicate-xloot-redemption)

[20260414 MONA LisaVault](#20260414-mona-lisavault---reward-farming--burnaddress-accounting-exploit)

[20260414 Saturn Protocol](#20260414-saturn-protocol---vulnerability-disclosure)

[20260412 SubQuerySettings](#20260412-subquerysettings---settings-access-control)

[20260407 SquidMulticallAllowanceDrain](#20260407-squidmulticallallowancedrain---arbitrary-call--wrong-approval)

[20260405 PerpPair](#20260405-perppair---virtual-amm-manipulation)

[20260331 WhalebitOracleManipulation](#20260331-whalebitoraclemanipulation---algebra-spot-price-oracle-manipulation)

[20260328 VTSwapHook](#20260328-vtswaphook---pricing-error-in-uniswapv4-hook)
[20260327 EST Token](#20260327-est-token---incorrect-token-burn-mechanism)

[20260324 XocolatlLiquidator](#20260324-xocolatlliquidator---access-control--input-validation)

[20260324 Univ3CollateralToken](#20260324-univ3collateraltoken---logic-error)

[20260323 BCE](#20260323-bce---deflationary-token-logic-error)

[20260319 ATMBlindBox](#20260319-atmblindbox---weak-randomness--predictable-rng)

[20260319 Revamp](#20260319-revamp---reward-accounting-drain)
[20260316 unverified](#20260316-unverified---checkoutpool-old-boc-missing-access-control)
[20260315 Venus THE](#20260315-venus-the---borrowbehalf--donation-attack)

[20260315 StakeOnMe](#20260315-stakeonme---owner-privileged-jake-burn-reserve-drain)
[20260310 AlkemiEarn](#20260310-alkemiearn---business-logic)

[20260302 Curve LlamaLend](#20260302-curve-llamalend---share-price-manipulation)

[20260222 LAXO Token](#20260222-laxo-token---incorrect-burn-logic)

[20260216 XDKRecycle](#20260216-xdkrecycle---xdk-recycle-reserve-manipulation)

[20260215 Moonwell](#20260215-moonwell---faulty-oracle)

[20260120 Makina](#20260120-makina---price-oracle-manipulation)

[20260120 SynapLogic](#20260120-synaplogic---business-logic-flaw)

[20260112 MTToken](#20260112-mttoken---incorrect-fee-logic)

[20260110 FutureSwap](#20260110-futureswap---unit-mismatch)

[20260109 TRU](#20260109-truebit---overflow)

[20260101 PRXVT](#20260101-PRXVT---bussiness-logic-flaw)

<details> <summary> 2025 </summary>

[20251201 yETH](past/2025/README.md#20251201-yeth---unsafe-math)

[20251110 DRLVaultV3](past/2025/README.md#20251110-drlvaultv3---price-manipulation)

[20251104 Moonwell](past/2025/README.md#20251104-moonwell---faulty-oracle)

[20251103 BalancerV2](past/2025/README.md#20251103-balancerv2---precision-loss)

[20251020 SharwaFinance](past/2025/README.md#20251020-sharwafinance---post-insolvency-check)

[20251007 TokenHolder](past/2025/README.md#20251007-tokenholder---access-control)

[20251004 MIMSpell3](past/2025/README.md#20251004-mimspell3---bypassed-insolvency-check)

[20250918 NGP](past/2025/README.md#20250918-ngp---price-manipulation)

[20250913 Kame](past/2025/README.md#20250913-kame---arbitary-external-call)

[20250830 EverValueCoin](past/2025/README.md#20250830-evervaluecoin---arbitrage)

[20250831 Hexotic](past/2025/README.md#20250831-hexotic---incorrect-input-validation)

[20250827 0xf340](past/2025/README.md#20250827-0xf340---access-control)

[20250823 ABCCApp](past/2025/README.md#20250823-abccapp---lack-of-access-control)

[20250820 MulticallWithXera](past/2025/README.md#20250820-multicallwithxera---access-control)

[20250820 0x8d2e](past/2025/README.md#20250820-0x8d2e---access-control)

[20250816 d3xai](past/2025/README.md#20250816-d3xai---price-manipulation)

[20250815 PDZ](past/2025/README.md#20250815-pdz---price-manipulation)

[20250815 SizeCredit](past/2025/README.md#20250815-sizecredit---access-control)

[20250813 YuliAI](past/2025/README.md#20250813-yuliai---price-manipulation)

[20250813 coinbase](past/2025/README.md#20250813-coinbase---misconfiguration)

[20250813 Grizzifi](past/2025/README.md#20250813-grizzifi---logic-flaw)

[20250812 Bebop](past/2025/README.md#20250812-bebop---arbitrary-user-input)

[20250811 WXC](past/2025/README.md#20250811-wxc---incorrect-token-burn-mechanism)

[20250728 SuperRare](past/2025/README.md#20250728-superrare---access-control)

[20250726 MulticallWithETH](past/2025/README.md#20250726-multicallwitheth---arbitrary-call)

[20250724 SWAPPStaking](past/2025/README.md#20250724-swappstaking---incorrect-reward-calculation)

[20250720 Stepp2p](past/2025/README.md#20250720-stepp2p---logic-flaw)

[20250716 VDS](past/2025/README.md#20250716-vds---logic-flaw)

[20250709 GMX](past/2025/README.md#20250709-gmx---share-price-manipulation)

[20250705 Unverified_54cd](past/2025/README.md#20250705-unverified---access-control)

[20250705 RANT](past/2025/README.md#20250705-rant---logic-flaw)

[20250702 FPC](past/2025/README.md#20250702-fpc---logic-flaw)

[20250629 Stead](past/2025/README.md#20250629-stead---access-control)

[20250626 ResupplyFi](past/2025/README.md#20250626-resupplyfi---share-price-manipulation)

[20250625 Unverified_b5cb](past/2025/README.md#20250625-unverified_b5cb---access-control)

[20250623 GradientMakerPool](past/2025/README.md#20250623-gradientmakerpool---price-oracle-manipulation)

[20250620 Gangsterfinance](past/2025/README.md#20250620-gangsterfinance---incorrect-dividends)

[20250619 BankrollStack](past/2025/README.md#20250619-bankrollstack---incorrect-dividends-calculation)

[20250619 BankrollNetwork](past/2025/README.md#20250619-bankrollnetwork---incorrect-dividends-calculation)

[20250617 MetaPool](past/2025/README.md#20250617-metapool---access-control)

[20250612 AAVEBoost](past/2025/README.md#20250612-aaveboost---logic-flaw)

[20250610 unverified_8490](past/2025/README.md#20250610-unverified_8490---access-control)

[20250528 Corkprotocol](past/2025/README.md#20250528-corkprotocol---access-control)

[20250527 UsualMoney](past/2025/README.md#20250527-usualmoney---arbitrage)

[20250526 YDT](past/2025/README.md#20250526-ydt---logic-flaw)

[20250524 RICE](past/2025/README.md#20250524-rice---lack-of-access-control)

[20250520 IRYSAI](past/2025/README.md#20250520-irysai---rug-pull)

[20250518 KRC](past/2025/README.md#20250518-krc---deflationary-token)

[20250514 Unwarp](past/2025/README.md#20250514-unwarp---lack-of-access-control)

[20250511 MBUToken](past/2025/README.md#20250511-mbutoken---price-manipulation-not-confirmed)

[20250509 Nalakuvara_LotteryTicket50](past/2025/README.md#20250509-nalakuvara_lotteryticket50---price-manipulation)

[20250426 Lifeprotocol](past/2025/README.md#20250426-lifeprotocol---price-manipulation)

[20250426 ImpermaxV3](past/2025/README.md#20250426-impermaxv3---flashloan-price-oracle-manipulation)

[20250416 Roar](past/2025/README.md#20250416-roar---rug-pull)

[20250408 Laundromat](past/2025/README.md#20250408-laundromat---logic-flaw)

[20250404 AIRWA](past/2025/README.md#20250404-airwa---access-control)

[20250418 BTNFT](past/2025/README.md#20250418-btnft---claim-rewards-without-protection)

[20250416 YVToken](past/2025/README.md#20250416-yvtoken---not-slippage-protection)

[20250411 Unverified 0x6077](past/2025/README.md#20250411-unverified-0x6077---lack-of-access-control)

[20250330 LeverageSIR](past/2025/README.md#20250330-leveragesir---storage-slot1-collision)

[20250328 Alkimiya_IO](past/2025/README.md#20250328-alkimiya_io---unsafecast)

[20250327 YziAIToken](past/2025/README.md#20250327-yziai---rug-pull)

[20250320 BBXToken](past/2025/README.md#20250320-bbxtoken---price-manipulation)

[20250318 DCFToken](past/2025/README.md#20250318-dcftoken---lack-of-slippage-protection)

[20250316 wKeyDAO](past/2025/README.md#20250316-wkeydao---unprotected-function)

[20250314 H2O](past/2025/README.md#20250314-h2o---weak-random-mint)

[20250311 DUCKVADER](past/2025/README.md#20250311-duckvader---free-mint-bug)

[20250307 UNI](past/2025/README.md#20250307-uni---logic-flaw)

[20250307 SBRToken](past/2025/README.md#20250307-sbr-token---price-manipulation)

[20250305 1inch Fusion V1 Settlement](past/2025/README.md#20250305-1inch-fusionv1-settlement---arbitrary-yul-calldata)

[20250304 Pump](past/2025/README.md#20250304-pump---not-slippage-protection)

[20250227 Venus_ZKSync](past/2025/README.md#20250227-venus_zksync---donation-attack)

[20250224 INVISTECH](past/2025/README.md#20250224-invistech---pair-tax-price-manipulation)

[20250223 HegicOptions](past/2025/README.md#20250223-hegicoptions---business-logic-flaw)

[20250222 Unverified_35bc](past/2025/README.md#20250222-unverified_35bc---reentrancy)

[20250221 StepHeroNFTs](past/2025/README.md#20250221-stepheronfts---reentrancy-on-sell-nft)

[20250221 Bybit](past/2025/README.md#20250221-bybit---phishing-attack)

[20250215 unverified_d4f1](past/2025/README.md#20250215-unverified_d4f1---access-control)

[20250211 FourMeme](past/2025/README.md#20250211-fourmeme---logic-flaw)

[20250208 Peapods Finance](past/2025/README.md#20250208-peapods-finance---price-manipulation)

[20250126 AIXBTForcedSwap](past/2025/README.md#20250126-aixbtforcedswap---hardcoded-auth-key)

[20250123 ODOS](past/2025/README.md#20250123-odos---invalid-signature-verification)

[20250121 Ast](past/2025/README.md#20250121-ast---price-manipulation)

[20250118 Paribus](past/2025/README.md#20250118-paribus---bad-oracle)

[20250114 IdolsNFT](past/2025/README.md#20250114-idolsnft---logic-flaw)

[20250113 Mosca2](past/2025/README.md#20250113-mosca2---logic-flaw)

[20250112 Unilend](past/2025/README.md#20250112-unilend---logic-flaw)

[20250111 RoulettePotV2](past/2025/README.md#20250111-roulettepotv2---price-manipulation)

[20250110 JPulsepot](past/2025/README.md#20250110-jpulsepot---logic-flaw)

[20250108 HORS](past/2025/README.md#20250108-hors---access-control)

[20250108 LPMine](past/2025/README.md#20250108-lpmine---incorrect-reward-calculation)

[20250107 IPC](past/2025/README.md#20250107-ipc-incorrect-burn-pairs---logic-flaw)

[20250106 Mosca](past/2025/README.md#20250106-mosca---logic-flaw)

[20250104 SorStaking](past/2025/README.md#20250104-sorstaking---incorrect-reward-calculation)

[20250104 98#Token](past/2025/README.md#20250104-98token---unprotected-public-function)

[20250101 LAURAToken](past/2025/README.md#20250101-lauratoken---pair-balance-manipulation)

</details>

<details> <summary> 2024 </summary>

[20241227 Bizness](past/2024/README.md#20241227-bizness---reentrancy)

[20241223 Moonhacker](past/2024/README.md#20241223-moonhacker---improper-input-validation)

[20241218 Slurpy](past/2024/README.md#20241218-slurpycoin---logic-flaw)

[20241216 BTC24H](past/2024/README.md#20241216-btc24h---logic-flaw)

[20241214 JHY](past/2024/README.md#20241214-jhy---logic-flaw)

[20241210 LABUBUToken](past/2024/README.md#20241210-labubu-token---logic-flaw)

[20241210 CloberDEX](past/2024/README.md#20241210-cloberdex---reentrancy)

[20241203 Pledge](past/2024/README.md#20241203-pledge---access-control)

[20241126 NFTG](past/2024/README.md#20241126-NFTG---access-control)

[20241124 Proxy_b7e1](past/2024/README.md#20241124-proxy_b7e1---logic-flaw)

[20241123 Ak1111](past/2024/README.md#20241123-ak1111---access-control)

[20241121 Matez](past/2024/README.md#20241121-matez---integer-truncation)

[20241120 MainnetSettler](past/2024/README.md#20241120-mainnetsettler---access-control)

[20241119 PolterFinance](past/2024/README.md#20241119-polterfinance---flashloan-attack)

[20241117 MFT](past/2024/README.md#20241117-mft---logic-flaw)

[20241114 vETH](past/2024/README.md#20241114-veth---vulnerable-price-dependency)

[20241111 DeltaPrime](past/2024/README.md#20241111-deltaprime---reentrancy)

[20241109 X319](past/2024/README.md#20241109-X319---access-control)

[20241107 ChiSale](past/2024/README.md#20241107-ChiSale---logic-flaw)

[20241107 CoW](past/2024/README.md#20241107-CoW---access-control)

[20241107 UniV2](past/2024/README.md#20241107-UniV2---rug-pull)

[20241105 RPP](past/2024/README.md#20241105-rpp---logic-flaw)

[20241029 BUBAI](past/2024/README.md#20241029-BUBAI---rug-pull)

[20241026 CompoundFork](past/2024/README.md#20241026-compoundfork---flashloan-attack)

[20241022 Erc20transfer](past/2024/README.md#20241022-erc20transfer---access-control)

[20241022 VISTA](past/2024/README.md#20241022-vista---flashmint-receive-error)

[20241013 MorphoBlue](past/2024/README.md#20241013-morphoblue---overpriced-asset-in-oracle)

[20241011 P719Token](past/2024/README.md#20241011-p719token---price-manipulation-inflate-attack)

[20241006 HYDT](past/2024/README.md#20241010-hydt---oracle-price-manipulation)

[20241006 SASHAToken](past/2024/README.md#20241006-sashatoken---price-manipulation)

[20241005 AIZPTToken](past/2024/README.md#20241005-AIZPTToken---wrong-price-calculation)

[20241002 LavaLending](past/2024/README.md#20241002-LavaLending---price-manipulation)

[20241001 FireToken](past/2024/README.md#20241001-firetoken---pair-manipulation-with-transfer-function)

[20240926 OnyxDAO](past/2024/README.md#20240926-OnyxDAO---fake-market)

[20240926 Bedrock_DeFi](past/2024/README.md#20240926-Bedrock_DeFi---swap-eth/btc-1/1-in-mint-function)

[20240924 MARA](past/2024/README.md#20240924-MARA---price-manipulation)

[20240923 PestoToken](past/2024/README.md#20240923-PestoToken---price-manipulation)

[20240923 Bankroll_Network](past/2024/README.md#20240923-Bankroll_Network---incorrect-input-validation)

[20240920 DOGGO](past/2024/README.md#20240920-DOGGO---logic-flaw)

[20240920 Shezmu](past/2024/README.md#20240920-shezmu---access-control)

[20240918 Unverified_766a](past/2024/README.md#20240918-unverified_766a---access-control)

[20240915 WXETA](past/2024/README.md#20240915-WXETA---Logic-Flaw)

[20240913 Unverified_5697](past/2024/README.md#20240913-unverified_5697---access-control)

[20240913 OTSeaStaking](past/2024/README.md#20240913-OTSeaStaking---Logic-Flaw)

[20240912 Unverified_03f9](past/2024/README.md#20240912-Unverified_03f9---access-control)

[20240911 INUMI](past/2024/README.md#20240911-INUMI---access-control)

[20240911 INUMI_db27](past/2024/README.md#20240911-INUMI_db27---access-control)

[20240911 AIRBTC](past/2024/README.md#20240911-AIRBTC---access-control)

[20240910 Caterpillar_Coin_CUT](past/2024/README.md#20240910-Caterpillar_Coin_CUT---price-manipulation)

[20240905 Unverified_a89f](past/2024/README.md#20240905-unverified_a89f---access-control)

[20240905 PLN](past/2024/README.md#20240905-PLN---access-control)

[20240905 HANAToken](past/2024/README.md#20240905-HANAToken---price-manipulation)

[20240904 Unverified_16d0](past/2024/README.md#20240904-unverified_16d0---access-control)

[20240903 Penpiexyz_io](past/2024/README.md#20240903-Penpiexyz_io---reentrancy-and-reward-manipulation)

[20240902 Pythia](past/2024/README.md#20240902-pythia---logic-flaw)

[20240828 Unverified_667d](past/2024/README.md#20240828-unverified_667d---access-control)

[20240828 AAVE](past/2024/README.md#20240828-aave---arbitrary-call-error)

[20240820 COCO](past/2024/README.md#20240820-coco---logic-flaw)

[20240816 Zenterest](past/2024/README.md#20240816-Zenterest---price-out-of-date)

[20240816 OMPxContract](past/2024/README.md#20240816-ompx-contract---flashloan)

[20240814 YodlRouter](past/2024/README.md#20240814-yodlrouter---arbitrary-call)

[20240813 VOW](past/2024/README.md#20240813-vow---misconfiguration)

[20240812 iVest](past/2024/README.md#20240812-iVest---business-logic-flaw)

[20240806 Novax](past/2024/README.md#20240806-Novax---price-manipulation)

[20240801 Convergence](past/2024/README.md#20240801-Convergence---incorrect-input-validation)

[20240724 Spectra_finance](past/2024/README.md#20240724-spectra_finance---incorrect-input-validation)

[20240723 MEVbot_0xdd7c](past/2024/README.md#20240723-mevbot_0xdd7c---incorrect-input-validation)

[20250717 WETC](#20250717-wetc---incorrect-burn-logic)

[20240716 Lifiprotocol](past/2024/README.md#20240716-lifiprotocol---incorrect-input-validation)

[20240714 Minterest](past/2024/README.md#20240714-minterest---Reentrancy)

[20240712 DoughFina](past/2024/README.md#20240712-doughfina---incorrect-input-validation)

[20240711 SBT](past/2024/README.md#20240711-sbt---business-logic-flaw)

[20240711 GAX](past/2024/README.md#20240711-GAX---lack-of-access-control)

[20240708 LW](past/2024/README.md#20240708-Lw---integer-underflow)

[20240705 DeFiPlaza](past/2024/README.md#20240705-defiplaza---loss-of-precision)

[20240703 UnverifiedContr_0x452E25](past/2024/README.md#20240703-UnverifiedContr_0x452E25---lack-of-access-control)

[20240702 MRP](past/2024/README.md#20240702-mrp---reentrancy)

[20240628 Will](past/2024/README.md#20240628-Will---business-logic-flaw)

[20240627 APEMAGA](past/2024/README.md#20240627-APEMAGA---business-logic-flaw)

[20240618 INcufi](past/2024/README.md#20240618-incufi---business-logic-flaw)

[20240617 Dyson_money](past/2024/README.md#20240617-dyson_money---business-logic-flaw)

[20240616 WIFCOIN_ETH](past/2024/README.md#20240616-WIFCOIN_ETH---business-logic-flaw)

[20240611 Crb2](past/2024/README.md#20240616-Crb2---business-logic-flaw)

[20240611 JokInTheBox](past/2024/README.md#20240611-JokInTheBox---business-logic-flaw)

[20240610 UwuLend - Price Manipulation](past/2024/README.md#20240610-UwuLend---Price-Manipulation)

[20240610 Bazaar](past/2024/README.md#20240610-bazaar---insufficient-permission-check)

[20240608 YYStoken](past/2024/README.md#20240608-YYStoken---business-logic-flaw)

[20240606 SteamSwap](past/2024/README.md#20240606-steamswap---logic-flaw)

[20240606 MineSTM](past/2024/README.md#20240606-MineSTM---business-logic-flaw)

[20240604 NCD](past/2024/README.md#20240604-NCD---business-logic-flaw)

[20240601 VeloCore](past/2024/README.md#20240601-VeloCore---lack-of-access-control)

[20240531 Liquiditytokens](past/2024/README.md#20240531-liquiditytokens---business-logic-flaw)

[20240531 MixedSwapRouter](past/2024/README.md#20240531-MixedSwapRouter---arbitrary-call)

[20240529 SCROLL](past/2024/README.md#20240529-SCROLL---integer-underflow)

[20240529 MetaDragon](past/2024/README.md#20240529-metadragon---lack-of-access-control)

[20240528 Tradeonorion](past/2024/README.md#20240528-Tradeonorion---business-logic-flaw)

[20240528 EXcommunity](past/2024/README.md#20240528-EXcommunity---business-logic-flaw)

[20240527 RedKeysCoin](past/2024/README.md#20240527-redkeyscoin---weak-rng)

[20240526 NORMIE](past/2024/README.md#20240526-normie---business-logic-flaw)

[20240522 Burner](past/2024/README.md#20240522-Burner---sandwich-ack)

[20240516 TCH](past/2024/README.md#20240516-tch---signature-malleability-vulnerability)

[20240514 Sonne Finance](past/2024/README.md#20240514-sonne-finance---precision-loss)

[20240514 PredyFinance](past/2024/README.md#20240514-predyfinance---reentrancy)

[20240512 TGC](past/2024/README.md#20240512-tgc---business-logic-flaw)

[20240510 GFOX](past/2024/README.md#20240510-gfox---lack-of-access-control)

[20240510 TSURU](past/2024/README.md#20240510-tsuru---insufficient-validation)

[20240508 GPU](past/2024/README.md#20240508-GPU---self-transfer)

[20240507 SATURN](past/2024/README.md#20240507-saturn---price-manipulation)

[20240506 OSN](past/2024/README.md#20240506-osn---reward-distribution-problem)

[20240430 Yield](past/2024/README.md#20240430-yield---business-logic-flaw)

[20240430 PikeFinance](past/2024/README.md#20240430-pikefinance---uninitialized-proxy)

[20240427 BNBX](past/2024/README.md#20240427-BNBX---precision-loss)

[20240425 NGFS](past/2024/README.md#20240425-ngfs---bad-access-control)

[20240424 XBridge](past/2024/README.md#20240424-xbridge---logic-flaw)

[20240424 YIEDL](past/2024/README.md#20240424-yiedl---input-validation)

[20240422 Z123](past/2024/README.md#20240422-z123---price-manipulation)

[20240420 Rico](past/2024/README.md#20240420-rico---arbitrary-call)

[20240419 HedgeyFinance](past/2024/README.md#20240419-hedgeyfinance---logic-flaw)

[20240417 UnverifiedContr_0x00C409](past/2024/README.md#20240417-UnverifiedContr_0x00C409---unverified-external-call)

[20240416 SATX](past/2024/README.md#20240416-satx---logic-flaw)

[20240416 MARS_DEFI](past/2024/README.md#20240416-mars---bad-reflection)

[20240415 GFA](past/2024/README.md#20240415-gfa---business-logic-flaw)

[20240415 ChaingeFinance](past/2024/README.md#20240415-chaingeFinance---arbitrary-external-call)

[20240414 Hackathon](past/2024/README.md#20240414-hackathon---business-logic-flaw)

[20240412 FIL314](past/2024/README.md#20240412-fil314---insufficient-validation-and-price-manipulation)

[20240412 SumerMoney](past/2024/README.md#20240412-sumermoney---Reentrancy)

[20240412 GROKD](past/2024/README.md#20240412-grokd---lack-of-access-control)

[20240410 BigBangSwap](past/2024/README.md#20240410-BigBangSwap---precision-loss)

[20240409 UPS](past/2024/README.md#20240409-ups---business-logic-flaw)

[20240408 SQUID](past/2024/README.md#20240408-squid---sandwich-attack)

[20240404 WSM](past/2024/README.md#20240404-wsm---manipulating-price)

[20240402 HoppyFrogERC](past/2024/README.md#20240402-hoppyfrogerc---business-logic-flaw)

[20240401 ATM](past/2024/README.md#20240401-atm---business-logic-flaw)

[20240401 OpenLeverage](past/2024/README.md#20240401-openleverage---business-logic-flaw)

[20240329 ETHFIN](past/2024/README.md#20240329-ethfin---lack-of-access-control)

[20240329 PrismaFi](past/2024/README.md#20240329-prismaFi---insufficient-validation)

[20240328 LavaLending](past/2024/README.md#20240328-lavalending---business-logic-flaw)

[20240325 ZongZi](past/2024/README.md#20240325-zongzi---price-manipulation)

[20240314 ARK](past/2024/README.md#20240324-ark---business-logic-flaw)

[20240323 CGT](past/2024/README.md#20240323-cgt---incorrect-access-control)

[20240321 SSS](past/2024/README.md#20240321-sss---token-balance-doubles-on-transfer-to-self)

[20240320 Paraswap](past/2024/README.md#20240320-paraswap---incorrect-access-control)

[20240314 MO](past/2024/README.md#20240314-mo---business-logic-flaw)

[20240313 IT](past/2024/README.md#20240313-it---business-logic-flaw)

[20240312 BBT](past/2024/README.md#20240312-bbt---business-logic-flaw)

[20240311 Binemon](past/2024/README.md#20240311-Binemon---precission-loss)

[20240309 Juice](past/2024/README.md#20240309-juice---business-logic-flaw)

[20240309 UnizenIO](past/2024/README.md#20240309-unizenio---unverified-external-call)

[20240307 GHT](past/2024/README.md#20240307-ght---business-logic-flaw)

[20240306 ALP](past/2024/README.md#20240306-alp---public-internal-function)

[20240306 TGBS](past/2024/README.md#20240306-tgbs---business-logic-flaw)

[20240305 Woofi](past/2024/README.md#20240305-woofi---price-manipulation)

[20240228 Seneca](past/2024/README.md#20240228-seneca---arbitrary-external-call-vulnerability)

[20240228 SMOOFSStaking](past/2024/README.md#20240228-smoofsstaking---reentrancy)

[20240223 Zoomer](past/2024/README.md#20240223-zoomer---business-logic-flaw)

[20240223 CompoundUni](past/2024/README.md#20240223-CompoundUni---Oracle-bad-price)

[20240223 BlueberryProtocol](past/2024/README.md#20240223-BlueberryProtocol---logic-flaw)

[20240222 SwarmMarkets](past/2024/README.md#20240222-SwarmMarkets---lack-of-validation)

[20240221 DeezNutz404](past/2024/README.md#20240221-deeznutz-404---lack-of-validation)

[20240221 GAIN](past/2024/README.md#20240221-GAIN---bad-function-implementation)

[20240220 EGGX](past/2024/README.md#20240220-EGGX---reentrancy)

[20240219 RuggedArt](past/2024/README.md#20240219-RuggedArt---reentrancy)

[20240216 ParticleTrade](past/2024/README.md#20240216-ParticleTrade---lack-of-validation-data)

[20240215 DualPools](past/2024/README.md#20240215-DualPools---precision-truncation)

[20240215 Babyloogn](past/2024/README.md#20240215-Babyloogn---lack-of-validation)

[20240215 Miner](past/2024/README.md#20240215-Miner---lack-of-validation-dst-address)

[20240213 MINER BSC](past/2024/README.md#20240213-miner---price-manipulation)

[20240211 Game](past/2024/README.md#20240211-game---reentrancy--business-logic-flaw)

[20240210 FILX DN404](past/2024/README.md#20240210-filx-dn404---access-control)

[20240208 Pandora404](past/2024/README.md#20240208-pandora---interger-underflow)

[20240205 BurnsDefi](past/2024/README.md#20240205-burnsdefi---price-manipulation)

[20240202 ADC](past/2024/README.md#20240202-adc---incorrect-access-control)

[20240201 AffineDeFi](past/2024/README.md#20240201-affinedefi---lack-of-validation-userData)

[20240130 XSIJ](past/2024/README.md#20240130-xsij---business-logic-flaw)

[20240130 MIMSpell](past/2024/README.md#20240130-mimspell---precission-loss)

[20240129 PeapodsFinance](past/2024/README.md#20240128-PeapodsFinance---reentrancy)

[20240128 BarleyFinance](past/2024/README.md#20240128-barleyfinance---reentrancy)

[20240127 CitadelFinance](past/2024/README.md#20240127-citadelfinance---price-manipulation)

[20240125 NBLGAME](past/2024/README.md#20240125-nblgame---reentrancy)

[20240122 DAO_SoulMate](past/2024/README.md#20240122-dao_soulmate---incorrect-access-control)

[20240117 BmiZapper](past/2024/README.md#20240117-bmizapper---arbitrary-external-call-vulnerability)

[20240117 SocketGateway](past/2024/README.md#20240112-socketgateway---lack-of-calldata-validation)

[20240115 Shell_MEV_0xa898](past/2024/README.md#20240115-Shell_MEV_0xa898---lack-of-access-control)

[20240112 WiseLending](past/2024/README.md#20240112-wiselending---bad-healthfactor-check)

[20240110 Freedom](past/2024/README.md#20240110-Freedom---lack-of-access-control)

[20240110 LQDX Alert](past/2024/README.md#20240110-lqdx---unauthorized-transferfrom)

[20240104 Gamma](past/2024/README.md#20240104-gamma---price-manipulation)

[20240102 MIC](past/2024/README.md#20240102-mic---business-logic-flaw)

[20240102 RadiantCapital](past/2024/README.md#20240102-radiantcapital---loss-of-precision)

[20240101 OrbitChain](past/2024/README.md#20240101-orbitchain---incorrect-input-validation)

</details>

<details> <summary> 2023 </summary>

[20231231 Channels BUSD&USDC](past/2023/README.md#20231231-channels---price-manipulation)

[20231230 ChannelsFinance](past/2023/README.md#20231230-channelsfinance---compoundv2-inflation-attack)

[20231228 CCV](past/2023/README.md#20231225-CCV---precision-loss)

[20231228 DominoTT](past/2023/README.md#20231228-dominott---precision-loss) 

[20231225 Telcoin](past/2023/README.md#20231225-telcoin---storage-collision)

[20231222 PineProtocol](past/2023/README.md#20231222-pineprotocol---business-logic-flaw)

[20231220 TransitFinance](past/2023/README.md#20231220-transitfinance---lack-of-validation-pool)

[20231217 Bob](past/2023/README.md#20231217-bob---price-manipulation)

[20231217 FloorProtocol](past/2023/README.md#20231217-floorprotocol---business-logic-flaw)

[20231216 GoodDollar](past/2023/README.md#20231216-gooddollar---lack-of-input-validation--reentrancy)

[20231216 KEST](past/2023/README.md#20231216-kest---business-logic-flaw)

[20231216 NFTTrader](past/2023/README.md#20231216-nfttrader---reentrancy)

[20231214 PHIL](past/2023/README.md#20231214-PHIL---business-logic-flaw)

[20231213 HYPR](past/2023/README.md#20231213-hypr---business-logic-flaw)

[20231211 GoodCompound](past/2023/README.md#20231211-goodcompound---price-manipulation)

[20231209 BCT](past/2023/README.md#20231209-bct---price-manipulation)

[20231207 HNet](past/2023/README.md#20231207-HNet---business-logic-flaw)

[20231206 TIME](past/2023/README.md#20231206-time---arbitrary-address-spoofing-attack)

[20231206 ElephantStatus](past/2023/README.md#20231206-elephantstatus---price-manipulation)

[20231205 MAMO](past/2023/README.md#20231205-mamo---price-manipulation)

[20231205 BEARNDAO](past/2023/README.md#20231205-bearndao---business-logic-flaw)

[20231202 bZxProtocol](past/2023/README.md#20231202-bzxprotocol---inflation-attack)

[20231201 UnverifiedContr_0x431abb](past/2023/README.md#20231201-unverifiedcontr_0x431abb---business-logic-flaw)

[20231130 EEE](past/2023/README.md#20231130-eee---price-manipulation)

[20231130 CAROLProtocol](past/2023/README.md#20231130-carolprotocol---price-manipulation-via-reentrancy)

[20231129 Burntbubba](past/2023/README.md#20231129-burntbubba---price-manipulation)

[20231129 AIS](past/2023/README.md#20231129-ais---access-control)

[20231128 FiberRouter](past/2023/README.md#20231128-FiberRouter---input-validation)

[20231125 MetaLend](past/2023/README.md#20231125-metalend---compoundv2-inflation-attack)

[20231125 TheNFTV2](past/2023/README.md#20231125-thenftv2---logic-flaw)

[20231122 KyberSwap](past/2023/README.md#20231122-kyberswap---precision-loss)

[20231117 Token8633_9419](past/2023/README.md#20231117-token8633_9419---price-manipulation)

[20231117 ShibaToken](past/2023/README.md#20231117-shibatoken---business-logic-flaw)

[20231116 WECO](past/2023/README.md#20231116-weco---business-logic-flaw)

[20231115 EHX](past/2023/README.md#20231115-ehx---lack-of-slippage-control)

[20231115 XAI](past/2023/README.md#20231115-xai---business-logic-flaw)

[20231115 LinkDAO](past/2023/README.md#20231115-linkdao---bad-k-value-verification)

[20231114 OKC Project](past/2023/README.md#20231114-OKC-Project---Instant-Rewards-Unlocked)

[20231112 MEV_0x8c2d](past/2023/README.md#20231112-mevbot_0x8c2d---lack-of-access-control)

[20231112 MEV_0xa247](past/2023/README.md#20231112-mevbot_0xa247---incorrect-access-control)

[20231111 Mahalend](past/2023/README.md#20231111-mahalend---donate-inflation-exchangerate--rounding-error)

[20231110 Raft_fi](past/2023/README.md#20231110-raft_fi---donate-inflation-exchangerate--rounding-error)

[20231110 GrokToken](past/2023/README.md#20231110-grok---lack-of-slippage-protection)

[20231107 RBalancer](past/2023/README.md#20231107-rbalancer---business-logic-flaw)

[20231107 MEVbot](past/2023/README.md#20231107-mevbot---lack-of-access-control)

[20231106 TrustPad](past/2023/README.md#20231106-trustpad---lack-of-msgsender-address-verification)

[20231106 TheStandard_io](past/2023/README.md#20231106-thestandard_io---lack-of-slippage-protection)

[20231106 KR](past/2023/README.md#20231106-KR---precission-loss)

[20231102 BRAND](past/2023/README.md#20231102-brand---lack-of-access-control)

[20231102 3913Token](past/2023/README.md#20231102-3913token---deflationary-token-attack)

[20231101 SwampFinance](past/2023/README.md#20231101-swampfinance---business-logic-flaw)

[20231101 OnyxProtocol](past/2023/README.md#20231101-onyxprotocol---precission-loss-vulnerability)

[20231031 UniBotRouter](past/2023/README.md#20231031-UniBotRouter---arbitrary-external-call)

[20231030 LaEeb](past/2023/README.md#20231030-laeeb---lack-slippage-protection)

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

[20231008 ZS](past/2023/README.md#20231008-zs---business-logic-flaw)

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

[20230905 QuantumWN](past/2023/README.md#20230905-quantumwn---rebasing-logic-issue)

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

[20230715 USDTStakingContract28](past/2023/README.md#20230715-usdtstakingcontract28---lack-of-access-control)

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

[20230630 MyAi](past/2023/README.md#20230630-MyAi---business-loigc)

[20230628 Themis](past/2023/README.md#20230628-themis---manipulation-of-prices-using-flashloan)

[20230627 UnverifiedContr_9ad32](past/2023/README.md#20230627-unverifiedcontr_9ad32---business-loigc-flaw)

[20230627 STRAC](past/2023/README.md#20230627-STRAC---business-loigc)

[20230623 SHIDO](past/2023/README.md#20230623-shido---business-loigc)

[20230621 BabyDogeCoin02](past/2023/README.md#20230621-babydogecoin02---lack-slippage-protection)

[20230621 BUNN](past/2023/README.md#20230621-bunn---reflection-tokens)

[20230620 MIM](past/2023/README.md#20230620-mimspell---arbitrary-external-call-vulnerability)

[20230619 Contract_0x7657](past/2023/README.md#20230620-Contract_0x7657---business-loigc)

[20230618 ARA](past/2023/README.md#20230618-ara---incorrect-handling-of-permissions)

[20230617 MidasCapitalXYZ](past/2023/README.md#20230617-midascapitalxyz---precision-loss)

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

[20221211 MEVbot_0x28d9](past/2022/README.md#20221211---MEVbot_0x28d9---insufficient-validation)

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

[20221118 Polynomial](past/2022/README.md#20221118---polynomial---no-input-validation)

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

[20221019 BEGO Token](past/2022/README.md#20221020-bego---incorrect-signature-verification)

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

[20220828 DDC](past/2022/README.md#20220828-ddc)

[20220824 LuckyTiger NFT](past/2022/README.md#20220824-luckytiger-nft---predicting-random-numbers)

[20220816 Circle_2](past/2022/README.md#20220816-circle---price-manipulation)

[20220813 Circle](past/2022/README.md#20220813-circle---price-manipulation)

[20220810 XSTABLE Protocol](past/2022/README.md#20220810-xstable-protocol---incorrect-logic-check)

[20220809 ANCH](past/2022/README.md#20220809-anch---skim-token-balance)

[20220807 EGD Finance](past/2022/README.md#20220807-egd-finance---flashloans--price-manipulation)

[20220804 EtnProduct](past/2022/README.md#20220804-etnproduct---business-logic-flaw)

[20220803 Qixi](past/2022/README.md#20220803-qixi---underflow)

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

[20220315 Agave Finance](past/2022/README.md#20220315-agave-finance---erc667-reentrancy)

[20220315 Hundred Finance](past/2022/README.md#20220313-hundred-finance---erc667-reentrancy)

[20220313 Paraluni](past/2022/README.md#20220313-paraluni---flashloan--reentrancy)

[20220309 Fantasm Finance](past/2022/README.md#20220309-fantasm-finance---business-logic-in-mint)

[20220305 Bacon Protocol](past/2022/README.md#20220305-bacon-protocol---reentrancy)

[20220303 TreasureDAO](past/2022/README.md#20220303-treasuredao---zero-fee)

[20220214 BuildFinance - DAO](past/2022/README.md#20220214-buildfinance---dao)

[20220208 Sandbox LAND](past/2022/README.md#20220208-sandbox-land---access-control)

[20220205 Meter](past/2022/README.md#20220205-Meter---bridge)

[20220204 TecraSpace](past/2022/README.md#20220204-TecraSpace---Any-token-is-destroyed)

[20220128 Qubit Finance](past/2022/README.md#20220128-qubit-finance---bridge-address0safetransferfrom-does-not-revert)

[20220118 Multichain (Anyswap)](past/2022/README.md#20220118-multichain-anyswap---insufficient-token-validation)

</details>
<details> <summary> 2021 </summary>

[20211221 Visor Finance](past/2021/README.md#20211221-visor-finance---reentrancy)

[20211218 Grim Finance](past/2021/README.md#20211218-grim-finance---flashloan--reentrancy)

[20211214 Nerve Bridge](past/2021/README.md#20211214-nerve-bridge---swap-metapool-attack)

[20211130 MonoX Finance](past/2021/README.md#20211130-monox-finance---price-manipulation)

[20211123 Ploutoz Finance](past/2021/README.md#20211123-ploutoz---flash-loan)

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

[20210804 Popsicle](past/2021/README.md#20210804-popsicle---repeated-reward-claim---logic-flaw)

[20210728 Levyathan Finance](past/2021/README.md#20210728-levyathan-finance---i-lost-keys-and-minting-ii-vulnerable-emergencywithdraw)

[20210710 Chainswap](past/2021/README.md#20210710-chainswap---bridge-logic-flaw)

[20210702 Chainswap](past/2021/README.md#20210702-chainswap---bridge-logic-flaw)

[20210628 SafeDollar](past/2021/README.md#20210628-safedollar---deflationary-token-uncompatible)

[20210625 xWin Finance](past/2021/README.md#20210625-xwin-finance---subscription-incentive-mechanism)

[20210622 Eleven Finance](past/2021/README.md#20210622-eleven-finance---doesnt-burn-shares)

[20210607 88mph NFT](past/2021/README.md#20210607-88mph-nft---access-control)

[20210603 PancakeHunny](past/2021/README.md#20210603-pancakehunny---incorrect-calculation)

[20210527 JulSwap](past/2021/README.md#20210527-julswap---flash-loan)

[20210527 BurgerSwap](past/2021/README.md#20210527-burgerswap---mathematical-flaw--reentrancy)

[20210519 PancakeBunny](past/2021/README.md#20210519-pancakebunny---price-oracle-manipulation)

[20210516 bEarn](past/2021/README.md#20210516-bearn---logic-flaw)

[20210508 Rari Capital](past/2021/README.md#20210509-raricapital---cross-contract-reentrancy)

[20210508 Value Defi](past/2021/README.md#20210508-value-defi---cross-contract-reentrancy)

[20210502 Spartan](past/2021/README.md#20210502-spartan---logic-flaw)

[20210428 Uranium](past/2021/README.md#20210428-uranium---miscalculation)

[20210308 DODO](past/2021/README.md#20210308-dodo---flashloan-attack)

[20210305 Paid Network](past/2021/README.md#20210305-paid-network---private-key-compromised)

[20210204 Yearn YDai](past/2021/README.md#20210204-yearn-ydai---Slippage-proection-absent)

[20210125 Sushi Badger Digg](past/2021/README.md#20210125-sushi-badger-digg---sandwich-attack)

</details>
<details> <summary> Before 2020 </summary>

[20201229 Cover Protocol](past/2021/README.md#20201229-cover-protocol)

[20201121 Pickle Finance](past/2021/README.md#20201121-pickle-finance)

[20201026 Harvest Finance](past/2021/README.md#20201026-harvest-finance---flashloan-attack)

[20200912 bzx](past/2021/README.md#20200912-bzx---incorrect-transfer)

[20200804 Opyn Protocol](past/2021/README.md#20200804-opyn-protocol---msgValue-in-loop)

[20200628 Balancer Protocol](past/2021/README.md#20200628-balancer-protocol---token-incompatible)

[20200618 Bancor Protocol](past/2021/README.md#20200618-bancor-protocol---access-control)

[20200419 LendfMe](past/2021/README.md#20200419-lendfme---erc777-reentrancy)

[20200418 UniSwapV1](past/2021/README.md#20200418-uniswapv1---erc777-reentrancy)

[20181007 SpankChain](past/2021/README.md#20181007-spankchain---reentrancy)

[20180424 SmartMesh](past/2021/README.md#20180424-smartmesh---overflow)

[20180422 Beauty Chain](past/2021/README.md##20180422-beauty-chain---integer-overflow)

[20171106 Parity - 'Accidentally Killed It'](past/2021/README.md##20171106-parity---accidentally-killed-it)

[20170719 Parity Multisig](past/2021/README.md#20170719-parity-multisig---delegatecall-to-unprotected-initwallet)

</details>

---

### Transaction debugging tools

[Phalcon](https://explorer.phalcon.xyz/) | [Tx tracer](https://openchain.xyz/trace) | [Cruise](https://cruise.supremacy.team/) | [Ethtx](https://ethtx.info/) | [Tenderly](https://dashboard.tenderly.co/explorer) | [eigenphi](https://tx.eigenphi.io/analyseTransaction)

### Ethereum Signature Database

[4byte](https://www.4byte.directory/) | [sig db](https://openchain.xyz/signatures) | [etherface](https://www.etherface.io/hash)

### Useful tools

[ABI to interface](https://gnidan.github.io/abi-to-sol/) | [Get ABI for unverified contracts](https://abi.w1nt3r.xyz/) | [ETH Calldata Decoder](https://apoorvlathey.com/eth-calldata-decoder/) | [ETHCMD - Guess ABI](https://www.ethcmd.com/tools/decode-calldata/) | [Abi tools](https://openchain.xyz/tools/abi)

### Hacks Dashboard

[Slowmist](https://hacked.slowmist.io/) | [Defillama](https://defillama.com/hacks) | [De.Fi](https://de.fi/rekt-database) | [Rekt](https://rekt.news/) | [Cryptosec](https://cryptosec.info/defi-hacks/) | [BlockSec](https://app.blocksec.com/explorer/security-incidents)

---

### List of DeFi Hacks & POCs

### 20260625 LixirPermitDrain - Broken Signature Verification

### Lost: 2.60 ETH, 4,477.72 USDC, 3,609.95 USDT, 24,182.56 LIX


```sh
forge test --contracts ./src/test/2026-06/LixirPermitDrain_exp.sol -vvv
```
#### Contract
[LixirPermitDrain_exp.sol](src/test/2026-06/LixirPermitDrain_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2070362661691207935

---

### 20260625 OceanBPoolSideStaking - BPool single-sided join/exit math with SideStaking gulp accounting

### Lost: 127.86K mOCEAN


```sh
forge test --contracts ./src/test/2026-06/OceanBPoolSideStaking_exp.sol -vvv
```
#### Contract
[OceanBPoolSideStaking_exp.sol](src/test/2026-06/OceanBPoolSideStaking_exp.sol)
### Link reference

http://x.com/defimonalerts/status/2070362661540286735

---

### 20260624 DLMC - Reserve-derived livePrice manipulation

### Lost: 222,560.22 USDT


```sh
forge test --contracts ./src/test/2026-06/DLMC_exp.sol -vvv --evm-version cancun
```
#### Contract
[DLMC_exp.sol](src/test/2026-06/DLMC_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/2069957542109958498

---

### 20260623 RoyalRoyalties - Zero-amount ERC1155 batch transfer inflated Royal LDA tier balance

### Lost: 261,162.93 USDC


```sh
forge test --contracts ./src/test/2026-06/RoyalRoyalties_exp.sol -vvv
```
#### Contract
[RoyalRoyalties_exp.sol](src/test/2026-06/RoyalRoyalties_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/2069596801725002121

---

### 20260622 Aztec Escape Hatch - proof_id Accounting Bypass (whitehat reproduction)
### Lost: N/A (purely educational; worst-case impact would have been ~$2M, matching the separate vulnerability that actually drained the contracts)
```sh
forge test --contracts src/test/2026-06/AztecEscapeHatch_exp.sol -vvv
```
#### Contract
[AztecEscapeHatch_exp.sol](src/test/2026-06/AztecEscapeHatch_exp.sol)

### Link reference

https://github.com/AztecProtocol/aztec-2.0

https://x.com/ivanbogatyy/status/2069159603942596830

### 20260622 ATM - LP Token Burn

### Lost: 1,603.99 WBNB


```sh
forge test --contracts ./src/test/2026-06/ATM_LP_Burn_exp.sol -vvv --evm-version shanghai
```
#### Contract
[ATM_LP_Burn_exp.sol](src/test/2026-06/ATM_LP_Burn_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/2068993748936151209

---

### 20260620 OLPC - OLPC pair reserve manipulation

### Lost: 1,115,903.66 USDT


```sh
forge test --contracts ./src/test/2026-06/OLPC_exp.sol --evm-version shanghai -vvv
```
#### Contract
[OLPC_exp.sol](src/test/2026-06/OLPC_exp.sol)
### Link reference

https://x.com/exvulsec/status/2068308334512365924

---

### 20260618 JB - JB helper repeated cycle drains JB/USDT pair

### Lost: 49,958.06 USDT


```sh
forge test --contracts ./src/test/2026-06/JB_exp.sol -vvv --evm-version cancun
```
#### Contract
[JB_exp.sol](src/test/2026-06/JB_exp.sol)
### Link reference

https://x.com/audit_911/status/2067943961327763788

---

### 20260617 Aztec V1 - escapeHatch Proof-Forgery (permissionless RollupProcessor exit)
### Lost: ~$2.2M (1158 ETH + 150,000 DAI + 0.4696 renBTC)
```sh
forge test --contracts src/test/2026-06/AztecEscapeHatch_exp.sol -vvv
```
#### Contract
[AztecEscapeHatch_exp.sol](src/test/2026-06/AztecEscapeHatch_exp.sol)


---

### 20260617 WHALE - Transfer Accounting Reserve Desync

### Lost: 3,460.41 USDT


```sh
forge test --contracts ./src/test/2026-06/WHALE_exp.sol -vvv --evm-version cancun
```
#### Contract
[WHALE_exp.sol](src/test/2026-06/WHALE_exp.sol)
### Link reference

https://x.com/audit_911/status/2067451654694412720

---

### 20260617 LBP - LBP balanceOf reward accounting

### Lost: 610.56 BNB


```sh
forge test --contracts ./src/test/2026-06/LBP_exp.sol -vvv --evm-version cancun
```
#### Contract
[LBP_exp.sol](src/test/2026-06/LBP_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2067329401977532429

---

### 20260616 DIP - Fee-on-Transfer Reserve Manipulation

### Lost: 111,097.59 USDC


```sh
forge test --contracts ./src/test/2026-06/DIP_exp.sol -vvv --evm-version shanghai
```
#### Contract
[DIP_exp.sol](src/test/2026-06/DIP_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/2067059314519417163

---

### 20260615 Thetanuts - Index vault component-share accounting flaw

### Lost: 105471.50 USDC


```sh
forge test --contracts ./src/test/2026-06/Thetanuts_exp.sol -vvv
```
#### Contract
[Thetanuts_exp.sol](src/test/2026-06/Thetanuts_exp.sol)
### Link reference

https://x.com/PeckShieldAlert/status/2066540451126190312

---

### 20260614 Aztec Connect - numRealTxs Proof/Settlement Mismatch (permissionless RollupProcessorV3)
### Lost: ~$2.19M (this PoC reproduces the 908.99 ETH leg)
```sh
forge test --contracts src/test/2026-06/AztecConnect_exp.sol -vvv
```
#### Contract
[AztecConnect_exp.sol](src/test/2026-06/AztecConnect_exp.sol)
### Link reference
https://www.cryptotimes.io/2026/06/15/aztec-exploit-drains-2-19m-from-dormant-privacy-protocol/

https://dev.to/cryip/how-a-single-validation-mismatch-can-drain-millions-lessons-from-the-aztec-connect-exploit-2598

---

### 20260609 TOPBPool - Governance-controlled token mint and Balancer pool drain

### Lost: 944.20 WETH


```sh
forge test --contracts ./src/test/2026-06/TOPBPool_exp.sol -vvv
```
#### Contract
[TOPBPool_exp.sol](src/test/2026-06/TOPBPool_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2064616112822583505

---

### 20260609 NovaBox - Constructor Dividend Checkpoint Bypass

### Lost: 56.73 ETH


```sh
forge test --contracts ./src/test/2026-06/NovaBox_exp.sol --evm-version prague -vvv
```
#### Contract
[NovaBox_exp.sol](src/test/2026-06/NovaBox_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2064616360466919793

---

### 20260607 AmbientCrocSwapDex - Native surplus accounting flaw

### Lost: 67.85 ETH


```sh
forge test --contracts ./src/test/2026-06/AmbientCrocSwapDex_exp.sol -vvv
```
#### Contract
[AmbientCrocSwapDex_exp.sol](src/test/2026-06/AmbientCrocSwapDex_exp.sol)
### Link reference

https://x.com/TenArmorAlert/status/2063816231023427861

---

### 20260606 BOSS - BOSS helper mint/burn and transfer-tax pool skew

### Lost: 10,207.54 USDT


```sh
forge test --contracts ./src/test/2026-06/BOSS_exp.sol -vvv --evm-version shanghai
```
#### Contract
[BOSS_exp.sol](src/test/2026-06/BOSS_exp.sol)
### Link reference

https://x.com/audit_911/status/2063819348305985748

---

### 20260605 DTXT - Liquidity Misclassification Fee Bypass

### Lost: 35,041.11 USDT


```sh
forge test --contracts ./src/test/2026-06/DTXT_exp.sol -vvv --evm-version shanghai
```
#### Contract
[DTXT_exp.sol](src/test/2026-06/DTXT_exp.sol)
### Link reference

https://x.com/audit_911/status/2063793931138347015

---

### 20260605 AISOTHPresale - Fixed-price presale arbitrage

### Lost: 30,314.76 USDT


```sh
forge test --contracts ./src/test/2026-06/AISOTHPresale_exp.sol -vvv --evm-version shanghai
```
#### Contract
[AISOTHPresale_exp.sol](src/test/2026-06/AISOTHPresale_exp.sol)
### Link reference

https://x.com/audit_911/status/2063565495073415618

---

### 20260604 BYToken - Permissionless triggerAutoBurn Reserve Manipulation
### Lost: ~$87,402 (146.60 WBNB)
```sh
forge test --contracts src/test/2026-06/BYToken_exp.sol -vvv
```
#### Contract
[BYToken_exp.sol](src/test/2026-06/BYToken_exp.sol)
### Link reference
https://hacked.slowmist.io

### 20260604 ATM Token - Hidden transferFrom Auto-Swap Drain
### Lost: ~$243,543 USDT
```sh
forge test --contracts src/test/2026-06/ATM_exp.sol -vvv
```
#### Contract
[ATM_exp.sol](src/test/2026-06/ATM_exp.sol)
### Link reference
https://hacked.slowmist.io

---

### 20260530 AROS - Signature Replay
### Lost: ~$295K
```sh
forge test --contracts src/test/2026-05/AROS_exp.sol -vvv --evm-version prague
```
#### Contract
[AROS_exp.sol](src/test/2026-05/AROS_exp.sol)
### Link reference
https://bscscan.com/tx/0xe89fe640ec5241edfca7d8dcae77a0a4270dee15e4bbd043fc60e393aabf41e1
https://x.com/TenArmorAlert/status/2061289921990570349

---

### 20260529 YSDAO - Price Manipulation and Tax Bypass

### Lost: ~19.49K USDT

```sh
forge test --contracts src/test/2026-05/YSDAO_exp.sol -vvv
```

#### Contract
[YSDAO_exp.sol](src/test/2026-05/YSDAO_exp.sol)

### Link reference
https://bscscan.com/tx/0x91f26d96373bbec6a6a8517c7be995a739d65f20fed589d53bc47d8140f91907

---

### 20260528 LegendaryMoneyMonNft - ecrecover address(0) Signature Bypass
### Lost: ~$85.5K USD (85,519 USDT)
```sh
forge test --contracts src/test/2026-05/LegendaryMoneyMonNft_exp.sol -vvv
```
#### Contract
[LegendaryMoneyMonNft_exp.sol](src/test/2026-05/LegendaryMoneyMonNft_exp.sol)
### Link reference
https://x.com/SlowMist_Team/status/2060205558687486441

---

### 20260528 DxSale - Ownership Override Attack
### Lost: ~7.3M USD
```sh
forge test --contracts src/test/2026-05/DxSale_exp.sol -vvv
```
#### Contract
[DxSale_exp.sol](src/test/2026-05/DxSale_exp.sol)
### Link reference
https://crypto.news/dxsale-exploit-drains-7-3m-in-bnb-through-hidden-contract-backdoor/
https://x.com/Tahax1/status/1928169316736651568
https://x.com/CoinsultAudits/status/1928203831996297670

---

### 20260527 Joe Agent - Reentrancy in removeLiquidityViaContract
### Lost: ~$45K USD (62.5 BNB + ~1.196M JOE)
```sh
forge test --contracts src/test/2026-05/JoeAgent_exp.sol -vvv
```
#### Contract
[JoeAgent_exp.sol](src/test/2026-05/JoeAgent_exp.sol)
### Link reference
https://x.com/SlowMist_Team/status/2059887450663551352

---
### 20260525 SquidRouterModule - Missing caller check

### Lost: 0.25 WBTC + 0.29 wTAO + 0.02 WETH


```sh
FOUNDRY_EVM_VERSION=cancun forge test --contracts ./src/test/2026-05/SquidRouterModule_exp.sol -vvv
```
#### Contract
[SquidRouterModule_exp.sol](src/test/2026-05/SquidRouterModule_exp.sol)
### Link reference

https://t.me/defimon_alerts/3045

---

### 20260525 New Market Trading - SquidRouterModule Missing Caller Check
### Lost: ~$3.98M USD
```sh
FOUNDRY_EVM_VERSION=cancun forge test --contracts src/test/2026-05/NewMarketTrading_exp.sol --match-contract NewMarketTradingExploit -vv
```
#### Contract
[NewMarketTrading_exp.sol](src/test/2026-05/NewMarketTrading_exp.sol)
### Link reference
https://rekt.news/newmarkettrading-rekt

---

### 20260526 SKP Token - Owner Backdoor LP Burn + Price Manipulation
### Lost: ~$212K USD
```sh
forge test --contracts src/test/2026-05/SKP_exp.sol -vvv
```
#### Contract
[SKP_exp.sol](src/test/2026-05/SKP_exp.sol)
### Link reference
https://www.cryptotimes.io/2026/05/27/skp-liquidity-exploit-drains-212k-across-bnb-chain-defi-protocols/

## 20260526 SKP Token - Deliberately Engineered Drain (Insider Exploit / Rug Pull)

### Lost ~$212,195 USDT

**Classification: Premeditated insider exploit — NOT a conventional external hack.**

```sh
forge test --contracts src/test/2026-05/SKP_exp2.sol -vvv
```

#### Contract
[SKP_exp.sol](src/test/2026-05/SKP_exp2.sol)

### Link reference
- https://bscscan.com/tx/0xbc01ea37bd2ff8f6aa6afcfbe0406114ff27a01e9aa56102bfa4ad8a0c2f25ee
- https://bscscan.com/tx/0xadf1b6ff02a917043c816bc8bd1ed67038d64a19d06544b09ceeb872518fda37
- https://www.bitget.com/amp/news/detail/12560605230076

---

---
### 20260525 WUSD.fi - _englove Sybil Incentive Abuse
### Lost: ~$200K USD (GLOVE emissions + LP drain)
```sh
forge test --contracts src/test/2026-05/WUSD_exp.sol -vvv
```
#### Contract
[WUSD_exp.sol](src/test/2026-05/WUSD_exp.sol)
### Link reference
https://x.com/exvulsec/status/2058803971947385330

---

### 20260522 FractalProtocol - Business Logic Flaw
### Lost: ~$13.7K
```sh
forge test --contracts src/test/2026-05/FractalProtocol_exp.sol -vvv
```
#### Contract
[FractalProtocol_exp.sol](src/test/2026-05/FractalProtocol_exp.sol)
### Link reference
https://arbiscan.io/tx/0x20db78913a51c3b3aece860ea142c240f3f8fa3b5bbf533a3d1d48eed857e10f
https://x.com/DefimonAlerts/status/2058619391776878967

---

### 20260521 MureDistribution - Signature Verification Bypass
### Lost: ~5.45 ETH
```sh
forge test --contracts src/test/2026-05/MureDistribution_exp.sol -vvv
```
#### Contract
[MureDistribution_exp.sol](src/test/2026-05/MureDistribution_exp.sol)
### Link reference
https://etherscan.io/tx/0xb83040361a0ec72fa2d06ad69493226518a5f8b5d96c19b400626248f9c5b798
https://x.com/DefimonAlerts/status/2058211424761942226

---

### 20260520 MAPProtocol - Arbitrary Mint
### Lost: ~$180K
```sh
forge test --contracts src/test/2026-05/MAPProtocol_exp.sol -vvv
```
#### Contract
[MAPProtocol_exp.sol](src/test/2026-05/MAPProtocol_exp.sol)
### Link reference
https://etherscan.io/tx/0x31e56b4737649e0acdb0ebb4eca44d16aeca25f60c022cbde85f092bde27664a
https://x.com/MapProtocol/status/2059587998409490510

---

### 20260519 ElevateFi - Reserve Price Manipulation

### Lost: ~16,000 USD

```sh
forge test --contracts ./src/test/2026-05/ElevateFi_exp.sol -vvv --evm-version cancun
```
#### Contract
[ElevateFi_exp.sol](src/test/2026-05/ElevateFi_exp.sol)
### Link reference

https://t.me/defimon_alerts/3040

---

### 20260518 TesseraSwap - Callback Repayment Price Spread
### Lost: ~$20K
```sh
forge test --contracts ./src/test/2026-05/TesseraSwap_exp.sol -vvv --evm-version shanghai
```
#### Contract
[TesseraSwap_exp.sol](src/test/2026-05/TesseraSwap_exp.sol)
### Link reference
https://t.me/defimon_alerts/3038

---

### 20260517 VerusBridge - Insufficient Validation
### Lost: ~$11.58M
```sh
forge test --contracts src/test/2026-05/VerusBridge_exp.sol -vvv
```
#### Contract
[VerusBridge_exp.sol](src/test/2026-05/VerusBridge_exp.sol)
### Link reference
https://etherscan.io/tx/0x6990f01720f57fc515d0e976a0c4f8157e0a9529194c4c15d190e98d087eb321
https://x.com/VerusCoin/status/2057465214975492358

---

### 20260517 SEAToken - Business Logic Flaw
### Lost: ~$110K
```sh
forge test --contracts src/test/2026-05/SEAToken_exp.sol -vvv
```
#### Contract
[SEAToken_exp.sol](src/test/2026-05/SEAToken_exp.sol)
### Link reference
https://arbiscan.io/tx/0x001cb16e17c4c5a5c4d02423c9e9b2f2b11ab6b2a1baf2ba53b8fcaf06167716
https://anomly.rs/metasea-redeemposition-distributor-drain-arb-2026-05-17

---

### 20260515 AdsharesBridge - Insufficient Validation
### Lost: ~$628K
```sh
forge test --contracts src/test/2026-05/AdsharesBridge_exp.sol -vvv
```
#### Contract
[AdsharesBridge_exp.sol](src/test/2026-05/AdsharesBridge_exp.sol)
### Link reference
https://etherscan.io/tx/0x8844b4ec371c4b13d7fac701b5d546a7c2fba12621a9596dd14b662b14408789
https://etherscan.io/tx/0xfba82bb34515d7aefbf0c89582b71d915ec8861c96babaafdc882743dbc23509
https://etherscan.io/tx/0xa3476575183204b4a662dd6ee56f6499d806e4f41ce83d98366752d31e9e9ca3
https://x.com/DefimonAlerts/status/2055751467579936770

---

### 20260512 SQTokenStaking - Access Control
### Lost: ~$346.1K
```sh
forge test --contracts src/test/2026-05/SQTokenStaking_exp.sol -vvv --evm-version prague
```
#### Contract
[SQTokenStaking_exp.sol](src/test/2026-05/SQTokenStaking_exp.sol)
### Link reference
https://bscscan.com/tx/0x1bae633eda9b3d98999ea116bc403712eaa07093ec32bd6d559085cc4607f5b8
https://x.com/Defi_Nerd_sec/status/2054425936746148148

---

### 20260511 INKFinance - Business Logic Flaw
### Lost: ~$140K
```sh
forge test --contracts src/test/2026-05/INKFinance_exp.sol -vvv
```
#### Contract
[INKFinance_exp.sol](src/test/2026-05/INKFinance_exp.sol)
### Link reference
https://polygonscan.com/tx/0xb469a24ec737be16fe41367a7b5b315c7f03b4e0ff3af50b3a2db03b3066b982
https://www.cryptotimes.io/2026/05/11/ink-finance-exploited-on-polygon-140k-usdt-drained-in-flash-loan-attack/

---

### 20260511 HumaFinance - Credit Approval Bypass
### Lost: ~$101K (82,315 USDC + 19,074 USDC.e)
```sh
forge test --contracts src/test/2026-05/HumaCreditApprovalBypass_exp.sol -vv
```
#### Contract
[HumaCreditApprovalBypass_exp.sol](src/test/2026-05/HumaCreditApprovalBypass_exp.sol)
### Link reference
https://www.cryptotimes.io/2026/05/11/huma-finance-v1-exploit-on-polygon-drains-101k-in-usdc/

---

### 20260510 Renegade - Uninitialized Proxy
### Lost: ~$209K
```sh
forge test --contracts src/test/2026-05/Renegade_exp.sol -vvv
```
#### Contract
[Renegade_exp.sol](src/test/2026-05/Renegade_exp.sol)
### Link reference
https://arbiscan.io/tx/0x0e494685ace16d372066c5b4db959b58ebac6d88166c2d9d618e0e421dc0c77e
https://x.com/renegade_fi/status/2053531772634427599
https://x.com/DefimonAlerts/status/2053538325969977801

---

### 20260507 TrustedVolumes - Signature Replay
### Lost: ~$5.87M
```sh
forge test --contracts src/test/2026-05/TrustedVolumes_exp.sol --match-contract TrustedVolumesExploit -vv
```
#### Contract
[TrustedVolumes_exp.sol](src/test/2026-05/TrustedVolumes_exp.sol)
### Link reference
https://rekt.news/trustedvolumes-rekt
https://www.darknavy.org/web3/exploits/trustedvolumes-rfq-proxy-drain/
https://blog.verichains.io/p/trustedvolumes-exploit-analysis

---

### 20260505 Ekubo - Business Logic Flaw
### Lost: ~$1.4M
```sh
forge test --contracts src/test/2026-05/Ekubo_exp.sol -vvv
```
#### Contract
[Ekubo_exp.sol](src/test/2026-05/Ekubo_exp.sol)
### Link reference
https://etherscan.io/tx/0x770bc9a1f7c32cb63a5002b9ceb5c7994cd3af0fc6b2309cb32d3c46f629daa0
https://x.com/EkuboProtocol/status/2051754481465856038
https://x.com/blockaid_/status/2051757787714118125

---

### 20260501 SharwaMarginTrading - Hegic collateral spot price manipulation

### Lost: 32.85K USDC


```sh
forge test --contracts ./src/test/2026-05/SharwaMarginTrading_exp.sol -vvv
```
#### Contract
[SharwaMarginTrading_exp.sol](src/test/2026-05/SharwaMarginTrading_exp.sol)
### Link reference

https://t.me/defimon_alerts/2975

---

### 20260428 RWAVault - Missing ERC4626 allowance check

### Lost: 398,655.47 USDC


```sh
forge test --contracts ./src/test/2026-04/RWAVault_exp.sol -vvv
```
#### Contract
[RWAVault_exp.sol](src/test/2026-04/RWAVault_exp.sol)
### Link reference

https://t.me/defimon_alerts/2958

---

### 20260428 JUDAO - JUDAO sell-hook reserve drain

### Lost: 205K USDT + 36 BNB


```sh
forge test --contracts ./src/test/2026-04/JUDAO_exp.sol -vvv --evm-version shanghai
```
#### Contract
[JUDAO_exp.sol](src/test/2026-04/JUDAO_exp.sol)
### Link reference

https://t.me/defimon_alerts/2955

---

### 20260427 Unverified_a152 - AllowanceTarget approval drain

### Lost: 229K USDT


```sh
forge test --contracts ./src/test/2026-04/unverified_a152_exp.sol -vvv
```
#### Contract
[unverified_a152_exp.sol](src/test/2026-04/unverified_a152_exp.sol)
### Link reference

https://t.me/defimon_alerts/2987

---

### 20260425 SingularityDynaVault - Oracle Misconfiguration / Share Inflation

### Lost: 413.13K USDC


```sh
forge test --contracts ./src/test/2026-04/SingularityDynaVault_exp.sol -vvv --evm-version shanghai
```
#### Contract
[SingularityDynaVault_exp.sol](src/test/2026-04/SingularityDynaVault_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2048698708309705069

---

### 20260423 GiddyVaultV3 - Incomplete Signature Coverage

### Lost: $1.3M


```sh
forge test --contracts ./src/test/2026-04/giddyvaultv3_compound_auth_exp.sol -vvv --evm-version cancun
```
#### Contract
[giddyvaultv3_compound_auth_exp.sol](src/test/2026-04/giddyvaultv3_compound_auth_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2047334517535642024

---

### 20260421 KipseliPropAMM - Pricing / Decimals Mismatch

### Lost: 0.93 cbBTC


```sh
forge test --contracts ./src/test/2026-04/KipseliPropAMM_exp.sol -vvv --evm-version cancun
```
#### Contract
[KipseliPropAMM_exp.sol](src/test/2026-04/KipseliPropAMM_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2046873857571934254

---

### 20260420 JuiceboxREVLoans - Fake terminal loan source validation bypass

### Lost: 21.77 ETH


```sh
forge test --contracts ./src/test/2026-04/JuiceboxREVLoans_exp.sol -vvv
```
#### Contract
[JuiceboxREVLoans_exp.sol](src/test/2026-04/JuiceboxREVLoans_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2046862935650345139

---

### 20260420 ThetanutsVaultShareRounding - Vault Share Rounding Manipulation

### Lost: 0.15 WBTC


```sh
forge test --contracts ./src/test/2026-04/ThetanutsVaultShareRounding_exp.sol -vvv
```
#### Contract
[ThetanutsVaultShareRounding_exp.sol](src/test/2026-04/ThetanutsVaultShareRounding_exp.sol)
### Link reference

https://t.me/defimon_alerts/2933

---

### 20260419 AaveRebalancerCreditDelegation - Arbitrary External Call / Credit Delegation Abuse

### Lost: 6,999.91 WAVAX


```sh
forge test --contracts ./src/test/2026-04/AaveRebalancerCreditDelegation_exp.sol -vvv
```
#### Contract
[AaveRebalancerCreditDelegation_exp.sol](src/test/2026-04/AaveRebalancerCreditDelegation_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2046504796463808991

---

### 20260415 XLootStaking - Duplicate xLOOT Redemption

### Lost: 6.21 ETH


```sh
forge test --contracts ./src/test/2026-04/XLootStaking_exp.sol -vvv
```
#### Contract
[XLootStaking_exp.sol](src/test/2026-04/XLootStaking_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2044709964091187660

---

## 20260414 MONA LisaVault - reward-farming / BurnAddress accounting exploit!

### Lost  ~60.95K USDT

```sh
forge test --contracts src/test/2026-04/MONA_LisaVault_exp.sol -vvv
```
#### Contract
[MONA_LisaVault_exp.sol](src/test/2026-04/MONA_LisaVault_exp.sol)

### Link reference
https://x.com/exvulsec/status/2043928546662592949

---

### 20260414 Saturn Protocol - Vulnerability Disclosure

### Lost: 0 (Disclosure only; no exploit occurred)

TVL at Risk: ~$35.7M

```sh
forge test --contracts src/test/2026-04/SaturnProtocol_exp.sol -vvv --fork-url https://rpc.ankr.com/eth
```

#### Contract

[SaturnProtocol_exp.sol](src/test/2026-04/SaturnProtocol_exp.sol)

### Link reference

https://gist.github.com/sgInnora/b70ad98327649ed4ab976a122f45e485

Note: Vendor states SAT-001 (underflow) is mitigated by `_validateTotals`, and SAT-002 (tolerance compound) is a trusted-role design observation.

---

### 20260412 SubQuerySettings - Settings access control

### Lost: 218.07M SQT

```sh
forge test --contracts ./src/test/2026-04/SubQuerySettings_exp.sol -vvv --evm-version shanghai
```
#### Contract
[SubQuerySettings_exp.sol](src/test/2026-04/SubQuerySettings_exp.sol)
### Link reference

https://t.me/defimon_alerts/2909

---

### 20260407 SquidMulticallAllowanceDrain - Arbitrary Call / Wrong Approval

### Lost: 1 ETH

```sh
forge test --contracts ./src/test/2026-04/SquidMulticallAllowanceDrain_exp.sol -vvv --evm-version shanghai
```

#### Contract

[SquidMulticallAllowanceDrain_exp.sol](src/test/2026-04/SquidMulticallAllowanceDrain_exp.sol)

### Link reference

https://x.com/DefimonAlerts/status/2041530294369386806

---

### 20260405 PerpPair - Virtual AMM Manipulation

### Lost: 165K USDC


```sh
forge test --contracts ./src/test/2026-04/PerpPair_exp.sol -vvv --evm-version prague
```
#### Contract
[PerpPair_exp.sol](src/test/2026-04/PerpPair_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2041070927908126897

---

### 20260331 WhalebitOracleManipulation - Algebra spot-price oracle manipulation

### Lost: 824K USD


```sh
forge test --contracts ./src/test/2026-03/WhalebitOracleManipulation_exp.sol -vvv
```
#### Contract
[WhalebitOracleManipulation_exp.sol](src/test/2026-03/WhalebitOracleManipulation_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2039372077686251787

---

### 20260328 VTSwapHook - Pricing Error in UniswapV4 Hook

### Lost: 4,507,034.03 vATH + 2,007,935.14 ATH


```sh
forge test --contracts ./src/test/2026-03/VTSwapHook_exp.sol -vvv --evm-version cancun
```
#### Contract
[VTSwapHook_exp.sol](src/test/2026-03/VTSwapHook_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2038647146098954283

---

### 20260327 EST Token - Incorrect Token Burn Mechanism

### Lost: 150.2 WBNB

```sh
forge test --contracts src/test/2026-03/EST_exp.sol -vvv --evm-version shanghai
```

#### Contract
[EST_exp.sol](src/test/2026-03/EST_exp.sol)

### Link reference
https://bscscan.com/address/0xD4524Be41cd452576aB9FF7b68a0b89aF8498a91

---

### 20260324 XocolatlLiquidator - Access Control / Input Validation

### Lost: 3.25 cbETH and 0.22 WETH


```sh
forge test --contracts ./src/test/2026-03/XocolatlLiquidator_exp.sol -vvv --evm-version shanghai
```
#### Contract
[XocolatlLiquidator_exp.sol](src/test/2026-03/XocolatlLiquidator_exp.sol)
### Link reference

https://t.me/defimon_alerts/2834

---

### 20260324 Univ3CollateralToken - Logic Error

### Lost: 57K USD


```sh
forge test --contracts ./src/test/2026-03/Univ3CollateralToken_exp.sol -vvv --evm-version shanghai
```
#### Contract
[Univ3CollateralToken_exp.sol](src/test/2026-03/Univ3CollateralToken_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2036449500512891317

---

### 20260323 BCE - Deflationary Token Logic Error

### Lost: ~800,000 USDT


```sh
forge test --contracts ./src/test/2026-03/bce_exp.sol -vvv --evm-version cancun
```
#### Contract
[bce_exp.sol](src/test/2026-03/bce_exp.sol)
### Link reference

https://t.me/defimon_alerts/2814

---

### 20260319 ATMBlindBox - Weak Randomness / Predictable RNG

### Lost: 99K USD


```sh
forge test --contracts ./src/test/2026-03/ATMBlindBox_exp.sol -vvv --evm-version shanghai
```
#### Contract
[ATMBlindBox_exp.sol](src/test/2026-03/ATMBlindBox_exp.sol)
### Link reference

https://t.me/defimon_alerts/2808

---

### 20260319 Revamp - Reward Accounting Drain

### Lost: 2.99 BNB


```sh
forge test --contracts ./src/test/2026-03/Revamp_exp.sol -vvv --evm-version cancun
```
#### Contract
[Revamp_exp.sol](src/test/2026-03/Revamp_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2034532544239088053

---

### 20260316 unverified - CheckoutPool Old BOC Missing Access Control

### Lost: 85,730 USDC


```sh
forge test --contracts ./src/test/2026-03/unverified_1304_exp.sol -vvv --evm-version cancun
```
#### Contract
[unverified_1304_exp.sol](src/test/2026-03/unverified_1304_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2034532547191820390

---

### 20260315 Venus THE - BorrowBehalf + Donation Attack

### Lost: 913,858.263360521396654198 CAKE + 1,972.530910582753621682 WBNB

```sh
forge test --contracts src/test/2026-03/Venus_THE_exp.sol --match-test testTraceDrivenPoC -vvv
```
#### Contract
[Venus_THE_exp.sol](src/test/2026-03/Venus_THE_exp.sol)

### Link reference
https://bscscan.com/tx/0x4f477e941c12bbf32a58dc12db7bb0cb4d31d41ff25b2457e6af3c15d7f5663f

---

### 20260315 StakeOnMe - Owner-privileged JAKE burn reserve drain

### Lost: 0.28 ETH


```sh
forge test --contracts ./src/test/2026-03/unverified_237d_exp.sol -vvv
```
#### Contract
[unverified_237d_exp.sol](src/test/2026-03/unverified_237d_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2034532549905580417

---

### 20260310 AlkemiEarn - Business Logic

### Lost: 43.45 ETH


```sh
forge test --contracts ./src/test/2026-03/AlkemiEarn_exp.sol -vvv
```
#### Contract
[AlkemiEarn_exp.sol](src/test/2026-03/AlkemiEarn_exp.sol)
### Link reference

https://x.com/blockaid_/status/2031351881029546194

---

### 20260302 Curve LlamaLend - Share price manipulation

### Lost: ~240,000 US$

```sh
forge test -vvv --contracts ./src/test/2026-03/Curve_LlamaLend_exp.sol
```
#### Contract
[Curve_LlamaLend_exp.sol](src/test/2026-03/Curve_LlamaLend_exp.sol)

### Link reference
https://x.com/yieldsandmore/status/2028368378457362629

---

### 20260222 LAXO Token - Incorrect Burn Logic

### Lost: ~137,000 US$

```sh
forge test src/test/2026-02/LAXO_Token_exp.sol -vvv
```

#### Contract
[LAXO_Token_exp.sol](src/test/2026-02/LAXO_Token_exp.sol)

### Link reference
https://x.com/CertiKAlert/status/2027317095420072317

---

### 20260216 XDKRecycle - XDK recycle reserve manipulation

### Lost: 6.84 WBNB


```sh
forge test --contracts ./src/test/2026-02/XDKRecycle_exp.sol -vvv --evm-version shanghai
```
#### Contract
[XDKRecycle_exp.sol](src/test/2026-02/XDKRecycle_exp.sol)
### Link reference

https://x.com/DefimonAlerts/status/2024163654631882916

---

### 20260215 Moonwell - Faulty Oracle

### Lost: 1.78M USD

```sh
forge test --contracts ./src/test/2026-02/Moonwell_exp.sol -vvv
```

#### Contract
[Moonwell_exp.sol](src/test/2026-02/Moonwell_exp.sol)

### Link reference
https://forum.moonwell.fi/t/mip-x43-cbeth-oracle-incident-summary/2068

https://forum.moonwell.fi/t/recovery-plan-cbeth-incident-and-moonwell-apollo-onboarding/2084

https://x.com/pashov/status/2023872510077616223

https://x.com/moo9000/status/2024040101982990534

---

### 20260120 SynapLogic - Business Logic Flaw

NOTICE: SynapLogic is totally a cheat contract, with backdoors, vulnerabilities and rug pulls.

### Lost: 27.6 ETH & 3450 USDC

```sh
forge test -vvv --contracts ./src/test/2026-01/SynapLogic_exp.sol
```
#### Contract
[SynapLogic_exp.sol](src/test/2026-01/SynapLogic_exp.sol)

### Link reference
https://x.com/TenArmorAlert/status/2013432861366292520?s=20

https://x.com/hklst4r/status/2013440353844461979?s=20

https://x.com/CertiKAlert/status/2013440963851755610?s=20

https://x.com/nn0b0dyyy/status/2013445844394279260?s=20

### 20260120 Makina - Price Oracle Manipulation

### Lost: 5.1M USD

```sh
forge test -vvv --contracts ./src/test/2026-01/makina_exp.sol --evm-version cancun
# MUST use evm >= cancun
```

#### Contract
[makina_exp.sol](src/test/2026-01/makina_exp.sol)

### Link reference
https://x.com/nn0b0dyyy/status/2013472538832314630

https://x.com/TenArmorAlert/status/2013460083078836342

https://x.com/CertiKAlert/status/2013473512116363734


### 20260112 MTToken - Incorrect Fee Logic

### Lost: 37K USD

```sh
forge test -vvv --contracts ./src/test/2026-01/MTToken_exp.sol
```
#### Contract
[MTToken_exp.sol](src/test/2026-01/MTToken_exp.sol)
### Link reference
https://x.com/TenArmorAlert/status/2010630024274010460?s=20

https://x.com/nn0b0dyyy/status/2010638145155661942?s=20


---

### 20260110 FutureSwap - Unit Mismatch

### Lost: 433K USD

```sh
forge test -vvv --contracts ./src/test/2026-01/futureswap_exp.sol.sol
```
#### Contract
[futureswap_exp.sol](src/test/2026-01/futureswap_exp.sol)
### Link reference

https://x.com/nn0b0dyyy/status/2009922304927731717?s=20

---

### 20260109 Truebit - OverFlow

### Lost: 8540ETH


```sh
forge test --contracts ./src/test/2026-01/Truebit_exp.sol -vvv
```
#### Contract
[Truebit_exp.sol](src/test/2026-01/Truebit_exp.sol)
### Link reference

https://www.certik.com/zh-CN/resources/blog/truebit-incident-analysis

---

### 20260101 PRXVT - Bussiness Logic Flaw

### Lost: 32.8 ETH

```sh
forge test --contracts ./src/test/2026-01/PRXVT_exp.sol -vvv --block-gas-limit 60000000 # use gas limit control iterations
```
#### Contract
[PRXVT_exp.sol](src/test/2026-01/PRXVT_exp.sol)
### Link reference
https://x.com/CertiKAlert/status/2006685174587605315

---



### View Gas Reports

Foundry also has the ability to [report](https://book.getfoundry.sh/forge/gas-reports) the `gas` used per function call which mimics the behavior of [hardhat-gas-reporter](https://github.com/cgewecke/hardhat-gas-reporter). Generally speaking if gas costs per function call is very high, then the likelihood of its success is reduced. Gas optimization is an important activity done by smart contract developers.

Every poc in this repository can produce a gas report like this:

```bash
forge test --gas-report --contracts <contract> -vvv
```

For Example:
Let us find out the gas used in the [Audius poc](src/test/2022-07/Audius_exp.sol)

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

## License

This project is licensed under the [Apache License 2.0](LICENSE).
