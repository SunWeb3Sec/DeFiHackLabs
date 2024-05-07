# DeFi Hacks Reproduce - Foundry

## 2023 - List of Past DeFi Incidents

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

### 20231213 HYPR - Business Logic Flaw

### Lost: ~$200k

```
forge test --contracts ./src/test/2023-12/HYPR_exp.sol -vvv
```

#### Contract

[HYPR_exp.sol](../../src/test/2023-12/HYPR_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1735197818883588574

https://twitter.com/MevRefund/status/1734791082376941810

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

### 20231129 AIS - Access Control

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

[List of transactions](https://phalcon.blocksec.com/explorer/security-incidents?page=1).

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

### 20231115 LinkDAO - Bad `K` Value Verification

### Lost: ~$30K

Test

```
forge test --contracts ./src/test/others/LinkDao_exp.sol -vvv
```

#### Contract

[LinkDao_exp.sol](../../src/test/others/LinkDao_exp.sol)

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
forge test --contracts ./src/test/others/MEV_0x8c2d_exp.sol -vvv
```

#### Contract

[MEV_0x8c2d_exp.sol](../../src/test/others/MEV_0x8c2d_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1723897569661657553

---

### 20231112 MEVBot_0xa247 - Incorrect Access Control

### Lost: ~$150K

Test

```
forge test --contracts ./src/test/others/MEV_0xa247_exp.sol -vvv
```

#### Contract

[MEV_0xa247_exp.sol](../../src/test/others/MEV_0xa247_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1723591214262632562

---

### 20231111 MahaLend - Donate Inflation ExchangeRate & Rounding Error

### Lost: ~$20 K

Test

```
forge test --contracts ./src/test/others/MahaLend_exp.sol -vvv
```

### Contract

[MahaLend_exp.sol](../../src/test/others/MahaLend_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1723223766350832071

---

### 20231110 Raft_fi - Donate Inflation ExchangeRate & Rounding Error

### Lost: ~$3.2 M

Test

```
forge test --contracts ./src/test/others/Raft_exp.sol -vvv
```

### Contract

[Raft_exp.sol](../../src/test/others/Raft_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1723229393529835972

---

### 20231110 grok - Lack of slippage protection

### Lost: ~26 ETH

Test

```
forge test --contracts ./src/test/others/grok_exp.sol -vvv
```

#### Contract

[grok_exp.sol](../../src/test/others/grok_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1722841076120130020

---

### 20231107 MEVbot - Lack of access control

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/others/bot_exp.sol -vvv
```

#### Contract

[bot_exp.sol](../../src/test/others/bot_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1722101942061601052

---

### 20231106 TrustPad - Lack of msg.sender address verification

### Lost: ~$155K

Test

```
forge test --contracts ./src/test/others/TrustPad_exp.sol  -vvv
```

#### Contract

[TrustPad_exp.sol](../../src/test/others/TrustPad_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1721800306101793188

---

### 20231106 TheStandard_io - Lack of slippage protection

### Lost: ~$290K

Test

```
forge test --contracts ./src/test/others/TheStandard_io_exp.sol -vvv
```

#### Contract

[TheStandard_io_exp.sol](../../src/test/others/TheStandard_io_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1721807569222549518

https://twitter.com/CertiKAlert/status/1721839125836321195

---

### 20231102 3913Token - Deflationary Token Attack

### Lost: ~$31354 USD$

Test

```
forge test --contracts ./src/test/others/3913_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[3913_exp.sol](../../src/test/others/3913_exp.sol)

#### Link Reference

https://defimon.xyz/attack/bsc/0x8163738d6610ca32f048ee9d30f4aa1ffdb3ca1eddf95c0eba086c3e936199ed

---

### 20231101 OnyxProtocol - Precission Loss Vulnerability

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/others/OnyxProtocol_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[OnyxProtocol_exp.sol](../../src/test/others/OnyxProtocol_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1719697319824851051
https://defimon.xyz/attack/mainnet/0xf7c21600452939a81b599017ee24ee0dfd92aaaccd0a55d02819a7658a6ef635
https://twitter.com/DecurityHQ/status/1719657969925677161

---

### 20231031 UniBotRouter - Arbitrary External Call

### Lost: ~$83,944 USD$

Test

```
forge test --contracts ./src/test/others/UniBot_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[UniBot_exp.sol](../../src/test/others/UniBot_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1719251390319796477

---

### 20231028 AstridProtocol - Business Logic Flaw

### Lost: ~$127ETH

Test

```
forge test --contracts ./src/test/others/Astrid_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[Astrid_exp.sol](../../src/test/others/Astrid_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1718454835966775325

---

### 20231024 MaestroRouter2 - Arbitrary External Call

### Lost: ~$280ETH

Test

```
forge test --contracts ./src/test/others/MaestroRouter2_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[MaestroRouter2_exp.sol](../../src/test/others/MaestroRouter2_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1717014871836098663

https://twitter.com/BeosinAlert/status/1717013965203804457

---

### 20231022 OpenLeverage - Business Logic Flaw

### Lost: ~$8K

Test

```
forge test --contracts ./src/test/others/OpenLeverage_exp.sol -vvv
```

#### Contract

[OpenLeverage_exp.sol](../../src/test/others/OpenLeverage_exp.sol)

#### Link Reference

https://defimon.xyz/exploit/bsc/0x5366c6ba729d9cf8d472500afc1a2976ac2fe9ff

---

### 20231019 kTAF - CompoundV2 Inflation Attack

### Lost: ~$8K

Test

```
forge test --contracts ./src/test/others/kTAF_exp.sol -vvv
```

#### Contract

[kTAF_exp.sol](../../src/test/others/kTAF_exp.sol)

#### Link Reference

https://defimon.xyz/attack/mainnet/0x325999373f1aae98db2d89662ff1afbe0c842736f7564d16a7b52bf5c777d3a4

---

### 20231018 Hopelend - Div Precision Loss

### Lost: ~$825K

Test

```
forge test --contracts ./src/test/others/Hopelend_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[HopeLend_exp.sol](../../src/test/others/Hopelend_exp.sol)

#### Link Reference

https://twitter.com/immunefi/status/1722810650387517715

https://lunaray.medium.com/deep-dive-into-hopelend-hack-5962e8b55d3f

---

### 20231018 MicDao - Price Manipulation

### Lost: ~$13K

Test

```
forge test --contracts ./src/test/others/MicDao_exp.sol -vvv
```

#### Contract

[MicDao_exp.sol](../../src/test/others/MicDao_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1714677875427684544

https://twitter.com/ChainAegis/status/1714837519488205276

---

### 20231013 BelugaDex - Price manipulation

### Lost: ~$175K

Test

```
forge test --contracts ./src/test/others/BelugaDex_exp.sol -vvv
```

#### Contract

[BelugaDex_exp.sol](../../src/test/others/BelugaDex_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1712676040471105870

https://twitter.com/CertiKAlert/status/1712707006979613097

---

### 20231013 WiseLending - Donate Inflation ExchangeRate && Rounding Error

### Lost: ~$260K

Test

```
forge test --contracts ./src/test/others/WiseLending_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[WiseLending_exp.sol](../../src/test/others/WiseLending_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1712841315522638034

https://twitter.com/BlockSecTeam/status/1712871304993689709

---

### 20231012 Platypus - Business Logic Flaw

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/others/Platypus03_exp.sol -vvv
```

#### Contract

[Platypus03_exp.sol](../../src/test/others/Platypus03_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1712445197538468298

https://twitter.com/peckshield/status/1712354198246035562

---

### 20231011 BH - Price manipulation

### Lost: ~$1.27M

Test

```
forge test --contracts ./src/test/others/BH_exp.sol -vvv
```

#### Contract

[BH_exp.sol](../../src/test/others/BH_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1712139760813375973

https://twitter.com/DecurityHQ/status/1712118881425203350

---

### 20231008 pSeudoEth - Pool manipulation

### Lost: ~$2.3K

Test

```
forge test --contracts ./src/test/others/pSeudoEth_exp.sol -vvv
```

#### Contract

[pSeudoEth_exp.sol](../../src/test/others/pSeudoEth_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1710979615164944729

---

### 20231007 StarsArena - Reentrancy

### Lost: ~$3M

Test

```
forge test --contracts ./src/test/others/StarsArena_exp.sol -vvv
```

#### Contract

[StarsArena_exp.sol](../../src/test/others/StarsArena_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1710556926986342911

https://twitter.com/Phalcon_xyz/status/1710554341466395065

https://twitter.com/peckshield/status/1710555944269292009

---

### 20231005 DePayRouter - Business Logic Flaw

### Lost: ~$ 827 USDC

Test

```
forge test --contracts ./src/test/others/DePayRouter_exp.sol -vvv
```

#### Contract

[DePayRouter_exp.sol](../../src/test/others/DePayRouter_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1709764146324009268

---

### 20230930 FireBirdPair - Lack Slippage Protection

### Lost: ~$3.2K MATIC

Test

```
forge test --contracts ./src/test/others/FireBirdPair_exp.sol -vvv
```

#### Contract

[FireBirdPair_exp.sol](../../src/test/others/FireBirdPair_exp.sol)

#### Link Reference

https://explorer.phalcon.xyz/tx/polygon/0x96d80c609f7a39b45f2bb581c6ba23402c20c2b6cd528317692c31b8d3948328

---

### 20230929 DEXRouter - Arbitrary External Call

### Lost: ~$4K

Test

```
forge test --contracts ./src/test/others/DEXRouter_exp.sol -vvv
```

#### Contract

[DEXRouter_exp.sol](../../src/test/others/DEXRouter_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1707851321909428688

---

### 20230926 XSDWETHpool - Reentrancy

### Lost: ~$56.9BNB

Test

```
forge test --contracts ./src/test/others/XSDWETHpool_exp.sol -vvv
```

#### Contract

[XSDWETHpool_exp.sol](../../src/test/others/XSDWETHpool_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1706765042916450781

---

### 20230924 KubSplit - Pool manipulation

### Lost: ~$78K

Test

```
forge test --contracts ./src/test/others/Kub_Split_exp.sol -vvv
```

#### Contract

[Kub_Split_exp.sol](../../src/test/others/Kub_Split_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1705966214319612092

---

### 20230921 CEXISWAP - Incorrect Access Control

### Lost: ~$30K

Test

```
forge test --contracts ./src/test/others/CEXISWAP_exp.sol -vvv
```

#### Contract

[CEXISWAP_exp.sol](../../src/test/others/CEXISWAP_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1704759560614126030

---

### 20230916 uniclyNFT - Reentrancy

### Lost: 1 NFT

Test

```
forge test --contracts ./src/test/others/uniclyNFT_exp.sol -vvv
```

#### Contract

[uniclyNFT_exp.sol](../../src/test/others/uniclyNFT_exp.sol)

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
forge test --contracts ./src/test/others/BFCToken_exp.sol -vvv
```

#### Contract

[BFCToken_exp.sol](../../src/test/others/BFCToken_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1700621314246017133

---

### 20230908 APIG - Business Logic Flaw

### Lost: ~$169K

Test

```
forge test --contracts ./src/test/others/APIG_exp.sol -vvv
```

#### Contract

[APIG_exp.sol](../../src/test/others/APIG_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1700128158647734745

---

### 20230907 HCT - Price Manipulation

### Lost: ~$30.5BNB

Test

```
forge test --contracts ./src/test/others/HCT_exp.sol -vvv
```

#### Contract

[HCT_exp.sol](../../src/test/others/HCT_exp.sol)

#### Link Reference

https://twitter.com/leovctech/status/1699775506785198499

---

### 20230905 JumpFarm - Rebasing logic issue

### Lost: ~$2.4ETH

Test

```
forge test --contracts ./src/test/others/JumpFarm_exp.sol -vvv
```

#### Contract

[JumpFarm_exp.sol](../../src/test/others/JumpFarm_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1699384904218202618

---

### 20230905 HeavensGate - Rebasing logic issue

### Lost: ~$8ETH

Test

```
forge test --contracts ./src/test/others/HeavensGate_exp.sol -vvv
```

#### Contract

[HeavensGate_exp.sol](../../src/test/others/HeavensGate_exp.sol)

#### Link Reference

https://explorer.phalcon.xyz/tx/eth/0xe28ca1f43036f4768776805fb50906f8172f75eba3bf1d9866bcd64361fda834

---

### 20230905 FloorDAO - Rebasing logic issue

### Lost: ~$40ETH

Test

```
forge test --contracts ./src/test/others/FloorDAO_exp.sol -vvv
```

#### Contract

[FloorDAO_exp.sol](../../src/test/others/FloorDAO_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1698962105058361392

https://medium.com/floordao/floor-post-mortem-incident-summary-september-5-2023-e054a2d5afa4

---

### 20230902 DAppSocial - Business Logic Flaw

### Lost: ~$16K

Test

```
forge test --contracts ./src/test/others/DAppSocial_exp.sol -vvv
```

#### Contract

[DAppSocial_exp.sol](../../src/test/others/DAppSocial_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1698064511230464310

---

### 20230827 Balancer - Rounding Error && Business Logic Flaw

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/others/Balancer_exp.sol -vvv
```

#### Contract

[Balancer_exp.sol](../../src/test/others/Balancer_exp.sol)

#### Link Reference

https://medium.com/balancer-protocol/rate-manipulation-in-balancer-boosted-pools-technical-postmortem-53db4b642492

https://blocksecteam.medium.com/yet-another-risk-posed-by-precision-loss-an-in-depth-analysis-of-the-recent-balancer-incident-fad93a3c75d4

---

### 20230829 EAC - Price Manipulation

### Lost: ~$29BNB

Test

```
forge test --contracts ./src/test/others/EAC_exp.sol -vvv
```

#### Contract

[EAC_exp.sol](../../src/test/others/EAC_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1696520866564350157

---

### 20230826 SVT - flawed price calculation

### Lost: ~$400K

Test

```
forge test --contracts ./src/test/others/SVT_exp.sol -vvv
```

#### Contract

[SVT_exp.sol](../../src/test/others/SVT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1695285435671392504?s=20

---

### 20230824 GSS - skim token balance

### Lost: ~$25K

Test

```
forge test --contracts ./src/test/others/GSS_exp.sol -vvv
```

#### Contract

[GSS_exp.sol](../../src/test/others/GSS_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1694571228185723099

---

### 20230821 EHIVE - Business Logic Flaw

### Lost: ~$15K

Test

```
forge test --contracts ./src/test/others/EHIVE_exp.sol -vvv
```

#### Contract

[EHIVE_exp.sol](../../src/test/others/EHIVE_exp.sol)

#### Link Reference

https://twitter.com/bulu4477/status/1693636187485872583

---

### 20230819 BTC20 - Price Manipulation

### Lost: ~$18ETH

Test

```
forge test --contracts ./src/test/others/BTC20_exp.sol -vvv
```

#### Contract

[BTC20_exp.sol](../../src/test/others/BTC20_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1692924369662513472

---

### 20230818 ExactlyProtocol - insufficient validation

### Lost: ~$7M

Test

```
forge test --contracts ./src/test/others/Exactly_exp.sol -vvv
```

#### Contract

[Exactly_exp.sol](../../src/test/others/Exactly_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1692533280971936059

https://medium.com/@exactly_protocol/exactly-protocol-incident-post-mortem-b4293d97e3ed

---

### 20230814 ZunamiProtocol - Price Manipulation

### Lost: ~$2M

Test

```
forge test --contracts ./src/test/others/Zunami_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[Zunami_exp.sol](../../src/test/others/Zunami_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1690877589005778945

https://twitter.com/BlockSecTeam/status/1690931111776358400

---

### 20230809 EarningFram - Reentrancy

### Lost: ~$286k

Test

```
forge test --contracts ./src/test/others/EarningFram_exp.sol -vvv
```

#### Contract

[EarningFram_exp.sol](../../src/test/others/EarningFram_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1689182459269644288

---

### 20230802 CurveBurner - Lack Slippage Protection

### Lost: ~$36K

Test

```
forge test --contracts ./src/test/others/CurveBurner_exp.sol -vvv
```

#### Contract

[CurveBurner_exp.sol](../../src/test/others/CurveBurner_exp.sol)

#### Link Reference

https://medium.com/@Hypernative/exotic-culinary-hypernative-systems-caught-a-unique-sandwich-attack-against-curve-finance-6d58c32e436b

---

### 20230802 Uwerx - Fault logic

### Lost: ~$176ETH

Test

```
forge test --contracts ./src/test/others/Uwerx_exp.sol -vvv
```

#### Contract

[Uwerx_exp.sol](../../src/test/others/Uwerx_exp.sol)

#### Link Reference

https://twitter.com/deeberiroz/status/1686683788795846657

https://twitter.com/CertiKAlert/status/1686667720920625152

https://etherscan.io/tx/0x3b19e152943f31fe0830b67315ddc89be9a066dc89174256e17bc8c2d35b5af8

---

### 20230801 NeutraFinance - Price Manipulation

### Lost: ~$23ETH

Test

```
forge test --contracts ./src/test/others/NeutraFinance_exp.sol -vvv
```

#### Contract

[NeutraFinance_exp.sol](../../src/test/others/NeutraFinance_exp.sol)

#### Link Reference

https://twitter.com/phalcon_xyz/status/1686654241111429120

---

### 20230801 LeetSwap - Access Control

### Lost: ~$630K

Test

```
forge test --contracts ./src/test/others/Leetswap_exp.sol -vvv
```

#### Contract

[Leetswap_exp.sol](../../src/test/others/Leetswap_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1686217464051539968

https://twitter.com/peckshield/status/1686209024587710464

---

### 20230731 GYMNET - Insufficient validation

### Lost: Unclear

Test

```
forge test --contracts ./src/test/others/GYMNET_exp.sol -vvv
```

#### Contract

[GYMNET_exp.sol](../../src/test/others/GYMNET_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1686605510655811584

---

### 20230730 Curve - Vyper Compiler Bug && Reentrancy

### Lost: ~ $41M

Test

```
forge test --contracts ./src/test/others/Curve_exp01.sol -vvv
```

#### Contract

[Curve_exp01.sol](../../src/test/others/Curve_exp01.sol) | [Curve_exp02.sol](../../src/test/others/Curve_exp02.sol)

#### Link Reference

https://hackmd.io/@LlamaRisk/BJzSKHNjn

---

### 20230726 Carson - Price manipulation

### Lost: ~$150K

Test

```
forge test --contracts ./src/test/others/Carson_exp.sol -vvv
```

#### Contract

[Carson_exp.sol](../../src/test/others/Carson_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1684393202252402688

https://twitter.com/Phalcon_xyz/status/1684503154023448583

https://twitter.com/hexagate_/status/1684475526663004160

---

### 20230724 Palmswap - Business Logic Flaw

### Lost: ~$900K

Test

```
forge test --contracts ./src/test/others/Palmswap_exp.sol -vvv
```

#### Contract

[Palmswap_exp.sol](../../src/test/others/Palmswap_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1683680026766737408

---

### 20230723 MintoFinance - Signature Replay

### Lost: ~$9K

Test

```
forge test --contracts ./src/test/others/MintoFinance_exp.sol -vvv
```

#### Contract

[MintoFinance_exp.sol](../../src/test/others/MintoFinance_exp.sol)

#### Link Reference

https://twitter.com/bbbb/status/1683180340548890631

---

### 20230722 Conic Finance 02 - Price Manipulation

### Lost: ~$934K

Test

```
forge test --contracts ./src/test/others/Conic02_exp.sol --evm-version 'shanghai' -vvv
```

#### Contract

[Conic02_exp.sol](../../src/test/others/Conic02_exp.sol)

#### Link Reference

https://medium.com/@ConicFinance/post-mortem-eth-and-crvusd-omnipool-exploits-c9c7fa213a3d

https://twitter.com/spreekaway/status/1682467603518726144

---

### 20230721 Conic Finance - Read-Only-Reentrancy && MisConfiguration

### Lost: ~$3.25M

Testing

```
forge test --contracts ./src/test/others/Conic_exp.sol -vvv
```

#### Contract

[Conic_exp.sol](../../src/test/others/Conic_exp.sol)|[Conic_exp2.sol](../../src/test/others/Conic_exp2.sol)

#### Link Reference

https://medium.com/@ConicFinance/post-mortem-eth-and-crvusd-omnipool-exploits-c9c7fa213a3d

https://twitter.com/BlockSecTeam/status/1682356244299010049

---

### 20230721 SUT - Business Logic Flaw

### Lost: ~$8k

Testing

```
forge test --contracts ./src/test/others/SUT_exp.sol -vvv
```

#### Contract

[SUT_exp.sol](../../src/test/others/SUT_exp.sol)

#### Link Reference

https://twitter.com/bulu4477/status/1682983956080377857

---

### 20230720 Utopia - Business Logic Flaw

### Lost: ~$119k

Testing

```
forge test --contracts ./src/test/others/Utopia_exp.sol -vvv
```

#### Contract

[Utopia_exp.sol](../../src/test/others/Utopia_exp.sol)

#### Link Reference

https://twitter.com/DeDotFiSecurity/status/1681923729645871104

https://twitter.com/bulu4477/status/1682380542564769793

---

### 20230720 FFIST - Business Logic Flaw

### Lost: ~$110k

Testing

```
forge test --contracts ./src/test/others/FFIST_exp.sol -vvv
```

#### Contract

[FFIST_exp.sol](../../src/test/others/FFIST_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1681869807698984961

https://twitter.com/AnciliaInc/status/1681901107940065280

---

### 20230718 APEDAO - Business Logic Flaw

### Lost: ~$7K

Testing

```
forge test --contracts ./src/test/others/ApeDAO_exp.sol -vvv
```

#### Contract

[ApeDAO_exp.sol](../../src/test/others/ApeDAO_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1681316257034035201

---

### 20230718 BNO - Invalid emergency withdraw mechanism

### Lost: ~$505K

Testing

```
forge test --contracts ./src/test/others/BNO_exp.sol -vvv
```

#### Contract

[BNO_exp.sol](../../src/test/others/BNO_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1681116206663876610

---

### 20230717 NewFi - Lack Slippage Protection

### Lost: ~$31K

Testing

```
forge test --contracts ./src/test/others/NewFi_exp.sol -vvv
```

#### Contract

[NewFi_exp.sol](../../src/test/others/NewFi_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1680961588323557376

---

### 20230712 Platypus - Bussiness Logic Flaw

### Lost: ~$51K

Testing

```
forge test --contracts ./src/test/others/Platypus02_exp.sol -vvv
```

#### Contract

[Platypus02_exp.sol](../../src/test/others/Platypus02_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1678800450303164431

---

### 20230712 WGPT - Business Logic Flaw

### Lost: ~$80k

Testing

```
forge test --contracts ./src/test/others/WGPT_exp.sol -vvv
```

#### Contract

[WGPT_exp.sol](../../src/test/others/WGPT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1679042549946933248

https://twitter.com/BeosinAlert/status/1679028240982368261

---

### 20230711 RodeoFinance - TWAP Oracle Manipulation

### Lost: ~$888k

Testing

```
forge test --contracts ./src/test/others/RodeoFinance_exp.sol -vvv
```

#### Contract

[RodeoFinance_exp.sol](../../src/test/others/RodeoFinance_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1678765773396008967

https://twitter.com/peckshield/status/1678700465587130368

https://medium.com/@Rodeo_Finance/rodeo-post-mortem-overview-f35635c14101

---

### 20230711 Libertify - Reentrancy

### Lost: ~$452k

Testing

```
forge test --contracts ./src/test/others/Libertify_exp.sol -vvv
```

#### Contract

[Libertify_exp.sol](../../src/test/others/Libertify_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1678688731908411393

https://twitter.com/Phalcon_xyz/status/1678694679767031809

---

### 20230710 ArcadiaFi - Reentrancy

### Lost: ~$400k

Testing

```
forge test --contracts ./src/test/others/ArcadiaFi_exp.sol -vvv
```

#### Contract

[ArcadiaFi_exp.so](../../src/test/others/ArcadiaFi_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1678250590709899264

https://twitter.com/peckshield/status/1678265212770693121

---

### 20230708 CIVNFT - Lack of access control

### Lost: ~$180k

Testing

```
forge test --contracts ./src/test/others/CIVNFT_exp.sol -vvv
```

#### Contract

[CIVNFT_exp.sol](../../src/test/others/CIVNFT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1677722208893022210

https://news.civfund.org/civtrade-hack-analysis-9a2398a6bc2e

https://blog.solidityscan.com/civnft-hack-analysis-4ee79b8c33d1

---

### 20230708 Civfund - Lack of access control

### Lost: ~$165k

Testing

```
forge test --contracts ./src/test/others/Civfund_exp.sol -vvv
```

#### Contract

[Civfund_exp.sol](../../src/test/others/Civfund_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1677529544062803969

https://twitter.com/BeosinAlert/status/1677548773269213184

---

### 20230707 LUSD - Price manipulation attack

### Lost: ~9464USDT

Testing

```
forge test --contracts ./src/test/others/LUSD_exp.sol -vvv
```

#### Contract

[LUSD_exp.sol](/src/test/others/LUSD_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1677391242878140417

---

### 20230704 BambooIA - Price manipulation attack

### Lost: ~200BNB

Testing

```
forge test --contracts ./src/test/others/Bamboo_exp.sol -vvv
```

#### Contract

[Bao_exp.sol](../../src/test/others/Bamboo_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1676220090142916611

https://twitter.com/eugenioclrc

---

### 20230704 BaoCommunity - Donate Inflation ExchangeRate && Rounding Error

### Lost: ~$46k

Testing

```
forge test --contracts ./src/test/others/bao_exp.sol -vvv
```

#### Contract

[Bao_exp.sol](../../src/test/others/Bao_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1676224397248454657

---

### 20230703 AzukiDAO - Invalid signature verification

### Lost: ~$69k

Testing

```
forge test --contracts ./src/test/others/AzukiDAO_exp.sol -vvv
```

#### Contract

[AzukiDAO_exp.sol](../../src/test/others/AzukiDAO_exp.sol)

#### Link Reference

https://twitter.com/sharkteamorg/status/1676892088930271232

---

### 20230630 Biswap - V3Migrator Exploit

### Lost: ~$72k

Testing

```
forge test --contracts ./src/test/others/Biswap_exp.sol -vvv
```

#### Contract

[Biswap_exp.sol](../../src/test/others/Biswap_exp.sol)

#### Link Reference

https://twitter.com/MetaTrustAlert/status/1674814217122349056?s=20

---

### 20230628 Themis - Manipulation of prices using Flashloan

### Lost: ~$370k

Testing

```
forge test --contracts ./src/test/others/Themis_exp.sol -vvv
```

#### Contract

[Themis_exp.sol](../../src/test/others/Themis_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1673930979348717570

https://twitter.com/BlockSecTeam/status/1673897088617426946

---

### 20230623 SHIDO - Business Loigc

### Lost: ~997 WBNB

Testing

```
forge test --contracts ./src/test/others/SHIDO_exp.sol -vvv
```

#### Contract

[SHIDO_exp.sol](../../src/test/others/SHIDO_exp.sol) | [SHIDO_exp2.sol](../../src/test/others/SHIDO_exp2.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1672473343734480896

https://twitter.com/AnciliaInc/status/1672382613473083393

---

### 20230621 BabyDogeCoin02 - Lack Slippage Protection

### Lost: ~ 441 BNB

Testing

```
forge test --contracts ./src/test/others/BabyDogeCoin02_exp.sol -vvv
```

#### Contract

[BabyDogeCoin02_exp.sol](../../src/test/others/BabyDogeCoin02_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1671517819840745475

---

### 20230621 BUNN - Reflection tokens

### Lost: ~52BNB

Testing

```
forge test --contracts ./src/test/others/BUNN_exp.sol -vvv
```

#### Contract

[BUNN_exp.sol](../../src/test/others//BUNN_exp.sol)

#### Link Reference

https://twitter.com/DecurityHQ/status/1671803688996806656

---

### 20230620 MIMSpell - Arbitrary External Call Vulnerability

### Lost: ~$17k

Testing

```
forge test --contracts ./src/test/others/MIMSpell_exp.sol -vvv
```

#### Contract

[MIMSpell_exp.sol](../../src/test/others/MIMSpell_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1671188024607100928?cxt=HHwWgMC--e2poLEuAAAA

---

### 20230618 ARA - Incorrect handling of permissions

### Lost: ~$125k

Testing

```
forge test --contracts ./src/test/others/ARA_exp.sol -vvv
```

#### Contract

[ARA_exp.sol](../../src/test/others/ARA_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1670638160550965248

---

### 20230617 Pawnfi - Business Logic Flaw

### Lost: ~$820K

Testing

```
forge test --contracts ./src/test/others/Pawnfi_exp.sol -vvv
```

#### Contract

[Pawnfi_exp.sol](../../src/test/others/Pawnfi_exp.sol)

#### Link Reference

https://blog.solidityscan.com/pawnfi-hack-analysis-38ac9160cbb4

---

### 20230615 CFC - Uniswap Skim() token balance attack

### Lost: ~$16k

Testing

```
forge test --contracts ./src/test/others/CFC_exp.sol -vvv
```

#### Contract

[CFC_exp.sol](../../src/test/others/CFC_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1669280632738906113

---

### 20230615 DEPUSDT_LEVUSDC - Incorrect access control

### Lost: ~$105k

Testing

```
forge test --contracts ./src/test/others/DEPUSDT_LEVUSDC_exp.sol -vvv
```

#### Contract

[DEPUSDT_LEVUSDC_exp.sol](../../src/test/others/DEPUSDT_LEVUSDC_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1669278694744150016?cxt=HHwWgMDS9Z2IvKouAAAA

---

### 20230612 Sturdy Finance - Read-Only-Reentrancy

### Lost: ~$800k

Testing

```
forge test --contracts ./src/test/others/Sturdy_exp.sol -vvv
```

#### contract

[Sturdy_exp.sol](../../src/test/others/Sturdy_exp.sol)

#### Link Reference

https://sturdyfinance.medium.com/exploit-post-mortem-49261493307a

https://twitter.com/AnciliaInc/status/1668081008615325698

https://twitter.com/BlockSecTeam/status/1668084629654638592

---

### 20230611 SellToken04 - Price Manipulation

### Lost: ~$109k

Testing

```
forge test --contracts ./src/test/others/SELLC03_exp.sol -vvv
```

#### Contract

[SELLC03_exp.sol](../../src/test/others/SELLC03_exp.sol)

#### Link Reference

https://twitter.com/EoceneSecurity/status/1668468933723328513

---

### 20230607 CompounderFinance - Manipulation of funds through fluctuations in the amount of exchangeable assets

### Lost: ~$27,174

Testing

```
forge test --contracts ./src/test/others/CompounderFinance_exp.sol -vvv
```

#### Contract

[CompounderFinance_exp.sol](../../src/test/others/CompounderFinance_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1666346419702362112

---

### 20230606 VINU - Price Manipulation

### Lost: ~$6k

Testing

```
forge test --contracts ./src/test/others/VINU_exp.sol -vvv
```

#### Contract

[VINU_exp.sol](../../src/test/others/VINU_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1666051854386511873?cxt=HHwWgoC24bPVgJ8uAAAA

---

### 20230606 UN - Price Manipulation

### Lost: ~$26k

Testing

```
forge test --contracts ./src/test/others/UN_exp.sol -vvv
```

#### Contract

[UN_exp.sol](../../src/test/others/UN_exp.sol)

#### Link Reference

https://twitter.com/MetaTrustAlert/status/1667041877428932608

---

### 20230602 NST Simple Swap - Unverified contract, wrong approval

### Lost: $40k

The hack was executed in a single transaction, resulting in the theft of $40,000 USD worth of USDT from the swap contract.

```
forge test --contracts ./src/test/others/NST_exp.sol -vvv
```

#### Contract

[NST_exp.sol](../../src/test/others/NST_exp.sol)

#### Link reference

https://discord.com/channels/1100129537603407972/1100129538056396870/1114142216923926528

---

### 20230601 DDCoin - Flashloan attack and smart contract vulnerability

### Lost: ~$300k

Testing

```
forge test --contracts ./src/test/others/DDCoin_exp.sol -vvv
```

#### Contract

[DDCoin_exp.sol](../../src/test/others/DDCoin_exp.sol)

#### Link Reference

https://twitter.com/ImmuneBytes/status/1664239580210495489
https://twitter.com/ChainAegis/status/1664192344726581255?cxt=HHwWjsDRldmHs5guAAAA

---

### 20230601 Cellframenet - Calculation issues during liquidity migration

### Lost: ~$76k

Testing

```
forge test --contracts ./src/test/others/Cellframe_exp.sol -vvv
```

#### Contract

[Cellframe_exp.sol](../../src/test/others/Cellframe_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1664132985883615235?cxt=HHwWhoDTqceImJguAAAA

---

### 20230531 ERC20TokenBank - Price Manipulation

### Lost: ~$111k

Testing

```
forge test --contracts ./src/test/others/ERC20TokenBank_exp.sol -vvv
```

#### Contract

[ERC20TokenBank.sol](../../src/test/others/ERC20TokenBank_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1663810037788311561

---

### 20230529 Jimbo - Protocol Specific Price Manipulation

### Lost: ~$8M

Testing

```
forge test --contracts ./src/test/others/Jimbo_exp.sol -vvv
```

#### Contract

[Jimbo_exp.sol](../../src/test/others/Jimbo_exp.sol)

#### Link Reference

https://twitter.com/cryptofishx/status/1662888991446941697

https://twitter.com/yicunhui2/status/1663793958781353985

---

### 20230529 BabyDogeCoin - Lack Slippage Protection

### Lost: ~$135k

Testing

```
forge test --contracts ./src/test/others/BabyDogeCoin_exp.sol -vvv
```

#### Contract

[BabyDogeCoin_exp.sol](../../src/test/others/BabyDogeCoin_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1662744426475831298

---

### 20230529 FAPEN - Wrong balance check

### Lost: ~$600

Testing

```
forge test --contracts ./src/test/others/FAPEN_exp.sol -vvv
```

#### Contract

[FAPEN_exp.sol](../../src/test/others/FAPEN_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1663501550600302601

---

### 20230529 NOON (NO) - Wrong visibility in function

### Lost: ~$2K

Testing

```
forge test --contracts ./src/test/others/NOON_exp.sol -vvv
```

#### Contract

[NOON_exp.sol](../../src/test/others/NOON_exp.sol)

#### Link Reference

https://twitter.com/hexagate_/status/1663501545105702912

---

### 20230525 GPT Token - Fee Machenism Exploitation

### Lost: ~$42k

Testing

```
forge test --contracts ./src/test/others/GPT_exp.sol -vvv
```

#### Contract

[GPT_exp.sol](../../src/test/others/GPT_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1661424685320634368

---

### 20230524 Local Trade LCT - Improper Access Control of Close-source contract

### Lost: ~384 BNB

Testing

```
forge test --contracts ./src/test/others/LocalTrader_exp.sol -vvv
```

#### Contract

[LocalTrader_exp.sol](../../src/test/others/LocalTrader_exp.sol) | [LocalTrader2_exp.sol](../../src/test/others/LocalTrader2_exp.sol)

#### Link Reference

https://twitter.com/numencyber/status/1661213691893944320

---

### 20230524 CS Token - Outdated Global Variable

### Lost: ~714K USD

Testing

```
forge test --contracts ./src/test/others/CS_exp.sol -vvv
```

#### Contract

[CS_exp.sol](../../src/test/others/CS_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1661098394130198528

https://twitter.com/numencyber/status/1661207123102167041

---

### 20230523 LFI Token - Business Logic Flaw

### Lost: ~36K USD

Testing

```
forge test --contracts ./src/test/others/LFI_exp.sol -vvv
```

#### Contract

[LFI_exp.sol](../../src/test/others/LFI_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1660767088699666433

---

### 20230514 landNFT - Lack of permission control

### Lost: 149,616 $BUSD

Testing

```
forge test --contracts ./src/test/others/landNFT_exp.sol -vvv
```

#### Contract

[landNFT_exp.sol](../../src/test/others/landNFT_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1658000784943124480

---

### 20230514 SellToken03 - Unchecked User Input

### Lost: Unclear

Testing

```
forge test --contracts ./src/test/others/SELLC02_exp.sol -vvv
```

#### Contract

[SELLC02_exp.sol](../../src/test/others/SELLC02_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1657715018908180480

---

### 20230513 Bitpaidio - Business Logic Flaw

### Lost: ~$30K

Testing

```
forge test --contracts ./src/test/others/Bitpaidio_exp.sol -vvv
```

#### Contract

[Bitpaidio_exp.sol](../../src/test/others/Bitpaidio_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1657411284076478465

---

### 20230512 LW - FlashLoan Price Manipulation

### Lost: ~$50k

Testing

```
forge test --contracts ./src/test/others/LW_exp.sol -vvv
```

#### Contract

[LW_exp.sol](../../src/test/others/LW_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1656850634312925184

https://twitter.com/hexagate_/status/1657051084131639296

---

### 20230513 SellToken02 - Price Manipulation

### Lost: ~$197k

Testing

```
forge test --contracts ./src/test/others/SellToken_exp.sol -vvv
```

#### Contract

[SellToken_exp.sol](../../src/test/others/SellToken_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1657324561577435136

---

### 20230511 SellToken01 - Business Logic Flaw

### Lost: ~$95k

Testing

```
forge test --contracts ./src/test/others/SELLC_exp.sol -vvv
```

#### Contract

[SELLC_exp.sol](../../src/test/others/SELLC_exp.sol)

#### Link Reference

https://twitter.com/AnciliaInc/status/1656337400329834496

https://twitter.com/AnciliaInc/status/1656341587054702598

---

### 20230510 SNK - Reward Calculation Error

### Lost: ~$197k

Testing

```
forge test --contracts ./src/test/others/SNK_exp.sol -vvv
```

#### Contract

[SNK_exp.sol](../../src/test/others/SNK_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1656176776425644032

---

### 20230509 MCC - Reflection token

### Lost: ~$10 ETH

Testing

```
forge test --contracts ./src/test/others/MultiChainCapital_exp.sol -vvv
```

#### Contract

[MultiChainCapital_exp.sol](../../src/test/others/MultiChainCapital_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1655846558762692608

---

### 20230509 HODL - Reflection token

### Lost: ~$2.3 ETH

Testing

```
forge test --contracts ./src/test/others/HODLCapital_exp.sol -vvv
```

#### Contract

[HODLCapital_exp.sol](../../src/test/others/HODLCapital_exp.sol)

#### Link Reference

https://explorer.phalcon.xyz/tx/eth/0xedc214a62ff6fd764200ddaa8ceae54f842279eadab80900be5f29d0b75212df

---

### 20230506 Melo - Access Control

### Lost: ~$90k

Testing

```
forge test --contracts ./src/test/others/Melo_exp.sol -vvv
```

#### Contract

[Melo_exp.sol](../../src/test/others/Melo_exp.sol)

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

[DEI_exp.sol](../../src/test/others/DEI_exp.sol)

#### Link Reference

https://twitter.com/eugenioclrc/status/1654576296507088906

---

### 20230503 NeverFall - Price Manipulation

### Lost: ~74K

Testing

```
forge test --contracts ./src/test/others/NeverFall_exp.sol -vvv
```

#### Contract

[NeverFall_exp.sol](../../src/test/others/NeverFall_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1653619782317662211

---

### 20230502 Level - Business Logic Flaw

### Lost: ~$1M

Testing

```
forge test --contracts ./src/test/others/Level_exp.sol -vvv
```

#### Contract

[Level_exp.sol](../../src/test/others/Level_exp.sol)

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
forge test --contracts ./src/test/others/silo_finance.t.sol -vvv
```

#### Contract

[silo_finance.t.sol](../../src/test/others/silo_finance.t.sol)

#### Link Reference

https://medium.com/immunefi/silo-finance-logic-error-bugfix-review-35de29bd934a

---

### 20230424 Axioma - Business Logic Flaw

### Lost: ~21 WBNB

Testing

```
forge test --contracts ./src/test/others/Axioma_exp.sol -vvv
```

#### Contract

[Axioma_exp.sol](../../src/test/others/Axioma_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1650382589847302145

---

### 20230419 OLIFE - Reflection token

### Lost: ~32 WBNB

Testing

```
forge test --contracts ./src/test/others/OLIFE_exp.sol -vvv
```

#### Contract

[OLIFE_exp.sol](../../src/test/others/OLIFE_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1648520494516420608

---

### 20230416 Swapos V2 - error k value Attack

### Lost: ~$468k

Testing

```
forge test --contracts ./src/test/others/Swapos_exp.sol -vvv
```

#### Contract

[Swapos_exp.sol](../../src/test/others/Swapos_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1647530789947469825

https://twitter.com/BeosinAlert/status/1647552192243728385

---

### 20230415 HundredFinance - Donate Inflation ExchangeRate && Rounding Error

### Lost: $7M

Testing

```
forge test --contracts ./src/test/others/HundredFinance_2_exp.sol -vvv
```

#### Contract

[HundredFinance_2_exp.sol](../../src/test/others/HundredFinance_2_exp.sol)

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
forge test --contracts ./src/test/others/YearnFinance_exp.sol -vvv
```

#### Contract

[YearnFinance_exp.sol](../../src/test/others/YearnFinance_exp.sol)

#### Link Reference

https://twitter.com/cmichelio/status/1646422861219807233

https://twitter.com/BeosinAlert/status/1646481687445114881

---

### 20230412 MetaPoint - Unrestricted Approval

### Lost: $820k(2500BNB)

Testing

```
forge test --contracts ./src/test/others/MetaPoint_exp.sol -vvv
```

#### Contract

[MetaPoint_exp.sol](../../src/test/others/MetaPoint_exp.sol)

#### Link Reference

https://twitter.com/PeckShieldAlert/status/1645980197987192833

https://twitter.com/Phalcon_xyz/status/1645963327502204929

---

### 20230411 Paribus - Reentrancy

### Lost: $100k

Testing

```
forge test --contracts ./src/test/others/Paribus_exp.sol -vvv
```

#### Contract

[Paribus_exp.sol](../../src/test/others/Paribus_exp.sol)

#### Link Reference

https://twitter.com/Phalcon_xyz/status/1645742620897955842

https://twitter.com/BlockSecTeam/status/1645744655357575170

https://twitter.com/peckshield/status/1645742296904929280

---

### 20230409 SushiSwap - Unchecked User Input

### Lost: >$3.3M

Testing

```
forge test --contracts ./src/test/others/Sushi_Router_exp.sol -vvv
```

#### Contract

[Sushi_Router_exp.sol](../../src/test/others/Sushi_Router_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1644907207530774530

https://twitter.com/SlowMist_Team/status/1644936375924584449

https://twitter.com/AnciliaInc/status/1644925421006520320

---

### 20230405 Sentiment - Read-Only-Reentrancy

### Lost: $1M

Testing

```
forge test --contracts ./src/test/others/Sentiment_exp.sol -vvv
```

#### Contract

[Sentiment_exp.sol](../../src/test/others/Sentiment_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1643417467879059456

https://twitter.com/spreekaway/status/1643313471180644360

https://medium.com/coinmonks/theoretical-practical-balancer-and-read-only-reentrancy-part-1-d6a21792066c

---

### 20230402 Allbridge - FlashLoan price manipulation

### Lost: $550k

Testing

```
forge test --contracts ./src/test/others/Allbridge_exp.sol -vvv
```

#### Contract

[Allbrideg_exp.sol](../../src/test/others/Allbridge_exp.sol) | [Allbrideg_exp2.sol](../../src/test/others/Allbridge_exp2.sol)

#### Link Reference

https://twitter.com/peckshield/status/1642356701100916736

https://twitter.com/BeosinAlert/status/1642372700726505473

---

### 20230328 SafeMoon Hack

### Lost: $8.9M

Testing

```
forge test --contracts ./src/test/others/safeMoon_exp.sol -vvv
```

#### Contract

[safeMoon_exp.sol](../../src/test/others/safeMoon_exp.sol)

#### Link reference

https://twitter.com/zokyo_io/status/1641014520041840640

---

### 20230328 - Thena - Yield Protocol Flaw

### Lost: $10k

Testing

```
forge test --contracts ./src/test/others/Thena_exp.sol -vvv
```

#### Contract

[Thena_exp.sol](../../src/test/others/Thena_exp.sol)

#### Link Reference

https://twitter.com/LTV888/status/1640563457094451214?t=OBHfonYm9yYKvMros6Uw_g&s=19

---

### 20230325 - DBW- Business Logic Flaw

### Lost: $24k

Testing

```
forge test --contracts ./src/test/others/DBW_exp.sol -vvv
```

#### Contract

[DBW_exp.sol](../../src/test/others/DBW_exp.sol)

#### Link Reference

https://twitter.com/BeosinAlert/status/1639655134232969216

https://twitter.com/AnciliaInc/status/1639289686937210880

---

### 20230322 - BIGFI - Reflection token

### Lost: $30k

Testing

```
forge test --contracts ./src/test/others/BIGFI_exp.sol -vvv
```

#### Contract

[BIGFI_exp.sol](../../src/test/others/BIGFI_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1638522680654675970

---

### 20230317 - ParaSpace NFT - Flashloan + scaledBalanceOf Manipulation

### Rescued: ~2,909 ETH

Testing

```
forge test --contracts ./src/test/others/paraspace_exp.sol -vvv
```

#### Contract

[paraspace_exp.sol](../../src/test/others/paraspace_exp.sol)

[Paraspace_exp_2.sol](../../src/test/others/Paraspace_exp_2.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1636650252844294144

---

### 20230315 - Poolz - integer overflow

### Lost: ~$390K

Testing

```
forge test --contracts ./src/test/others/poolz_exp.sol -vvv
```

#### Contract

[poolz_exp.sol](../../src/test/others/poolz_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1635860470359015425

---

### 20230313 - EulerFinance - Business Logic Flaw

### Lost: ~$200M

Testing

```
forge test --contracts ./src/test/others/Euler_exp.sol -vvv
```

#### Contract

[Euler_exp.sol](../../src/test/others/Euler_exp.sol)

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
forge test --contracts ./src/test/others/DKP_exp.sol -vvv
```

#### Contract

[DKP_exp.sol](../../src/test/others/DKP_exp.sol)

#### Link Reference

https://twitter.com/CertiKAlert/status/1633421908996763648

---

### 20230307 - Phoenix - Access Control & Arbitrary External Call

### Lost: ~$100k

Testing

```
forge test --contracts src/test/others/Phoenix_exp.sol -vvv
```

#### Contract

[Phoenix_exp.sol](../../src/test/others/Phoenix_exp.sol)

#### Link Reference

https://twitter.com/HypernativeLabs/status/1633090456157401088

---

### 20230227 - LaunchZone - Access Control

### Lost: ~$320,000

Testing

```
forge test  --contracts src/test/others/LaunchZone_exp.sol -vvv
```

#### Contract

[LuanchZone_exp.sol](../../src/test/others/LaunchZone_exp.sol)

#### Link Reference

https://twitter.com/immunefi/status/1630210901360951296

https://twitter.com/launchzoneann/status/1631538253424918528

---

### 20230227 - swapX - Access Control

### Lost: ~$1M

Testing

```
forge test --contracts ./src/test/others/swapX_exp.sol -vvv
```

#### Contract

[SwapX_exp.sol](../../src/test/others/SwapX_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1630111965942018049

https://twitter.com/peckshield/status/1630100506319413250

https://twitter.com/CertiKAlert/status/1630241903839985666

---

### 20230224 - EFVault - Storage Collision

### Lost: ~$5.1M

Testing

```
forge test --contracts ./src/test/others/EFVault_exp.sol -vvv
```

#### Contract

[EFVault_exp.sol](../../src/test/others/EFVault_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1630490333716029440

https://twitter.com/drdr_zz/status/1630500170373685248

https://twitter.com/gbaleeeee/status/1630587522698080257

---

### 20230222 - DYNA - Business Logic Flaw

### Lost: ~$21k

Testing

```
forge test --contracts ./src/test/others/DYNA_exp.sol -vvv
```

#### Contract

[DYNA_exp.sol](../../src/test/others/DYNA_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1628319536117153794

https://twitter.com/BeosinAlert/status/1628301635834486784

---

### 20230218 - RevertFinance - Arbitrary External Call Vulnerability

### Lost: ~$30k

Testing

```
forge test --contracts ./src/test/others/RevertFinance_exp.sol -vvv
```

#### Contract

[RevertFinance_exp.sol](../../src/test/others/RevertFinance_exp.sol)

#### Link Reference

https://mirror.xyz/revertfinance.eth/3sdpQ3v9vEKiOjaHXUi3TdEfhleAXXlAEWeODrRHJtU

---

### 20230217 - Starlink - Business Logic Flaw

### Lost: ~$12k

Testing

```
forge test --contracts ./src/test/others/Starlink_exp.sol -vvv
```

#### Contract

[Starlink_exp.sol](../../src/test/others/Starlink_exp.sol)

#### Link Reference

https://twitter.com/NumenAlert/status/1626447469361102850

https://twitter.com/bbbb/status/1626392605264351235

---

### 20230217 - Dexible - Arbitrary External Call Vulnerability

### Lost: ~$1.5M

Testing

```
forge test --contracts src/test/others/Dexible_exp.sol -vvv
```

#### Contract

[Dexible_exp.sol](../../src/test/others/Dexible_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1626493024879673344

https://twitter.com/MevRefund/status/1626450002254958592

---

### 20230217 - Platypusdefi - Business Logic Flaw

### Lost: ~$8.5M

Testing

```
forge test --contracts src/test/others/Platypus_exp.sol -vvv
```

#### Contract

[Platypus_exp.sol](../../src/test/others/Platypus_exp.sol)

#### Link Reference

https://twitter.com/peckshield/status/1626367531480125440

https://twitter.com/spreekaway/status/1626319585040338953

---

### 20230210 - Sheep - Reflection token

### Lost: ~$3K

Testing

```
forge test --contracts src/test/others/Sheep_exp.sol -vvv
```

#### Contract

[Sheep_exp.sol](../../src/test/others/Sheep_exp.sol)

#### Link Reference

https://twitter.com/BlockSecTeam/status/1623999717482045440

https://twitter.com/BlockSecTeam/status/1624077078852210691

---

### 20230210 - dForce - Read-Only-Reentrancy

### Lost: ~$3.65M

Testing

```
forge test --contracts ./src/test/others/dForce_exp.sol -vvv
```

#### Contract

[dForce_exp.sol](../../src/test/others/dForce_exp.sol)

#### Link reference

https://twitter.com/SlowMist_Team/status/1623956763598000129

https://twitter.com/BlockSecTeam/status/1623901011680333824

https://twitter.com/peckshield/status/1623910257033617408

---

### 20230207 - CowSwap - Arbitrary External Call Vulnerability

### Lost: ~$120k

Testing

```
forge test --contracts ./src/test/others/CowSwap_exp.sol -vvv
```

#### Contract

[CowSwap_exp.sol](../../src/test/others/CowSwap_exp.sol)

#### Link reference

https://twitter.com/MevRefund/status/1622793836291407873

https://twitter.com/peckshield/status/1622801412727148544

---

### 20230206 - FDP - Reflection token

### Lost: ~16 WBNB

Testing

```
forge test --contracts src/test/others/FDP_exp.t.sol -vv
```

#### Contract

[FDP_exp.t.sol](../../src/test/others/FDP_exp.t.sol)

#### Link reference

https://twitter.com/BeosinAlert/status/1622806011269771266

---

### 20230203 - Spherax USDs - Balance Recalculation Bug

### Lost: ~309k USDs (Stablecoin)

Testing

```
forge test --contracts ./src/test/others/USDs_exp.sol -vv
```

#### Contract

[USDs_exp.sol](../../src/test/others/USDs_exp.sol)

#### Link reference

https://twitter.com/danielvf/status/1621965412832350208

https://medium.com/sperax/usds-feb-3-exploit-report-from-engineering-team-9f0fd3cef00c

---

### 20230203 - Orion Protocol - Reentrancy

### Lost: $3M

Testing

```
forge test --contracts ./src/test/others/Orion_exp.sol -vvv
```

#### Contract

[Orion_exp.sol](../../src/test/others/Orion_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1621337925228306433

https://twitter.com/BlockSecTeam/status/1621263393054420992

https://www.numencyber.com/analysis-of-orionprotocol-reentrancy-attack-with-poc/

---

### 20230202 - BonqDAO - Price Oracle Manipulation

### Lost: BEUR stablecoin and ALBT Token (~88M US$)

Testing

```
forge test --contracts ./src/test/others/BonqDAO_exp.sol -vv
```

#### Contract

[BonqDAO_exp.sol](../../src/test/others/BonqDAO_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1621043757390123008

https://twitter.com/SlowMist_Team/status/1621087651158966274

---

### 20230130 - BEVO - Reflection token

### Lost: 144 BNB

Testing

```sh
forge test --contracts ./src/test/others/BEVO_exp.sol -vvv
```

#### Contract

[BEVO_exp.sol](../../src/test/others/BEVO_exp.sol)

#### Link reference

https://twitter.com/QuillAudits/status/1620377951836708865

---

### 20230126 - TINU - Reflection token

### Lost: 22 ETH

Testing

```sh
forge test --contracts ./src/test/others/TINU_exp.t.sol -vv
```

#### Contract

[TINU_exp.t.sol](../../src/test/others/TINU_exp.t.sol)

#### Link reference

https://twitter.com/libevm/status/1618718156343873536

---

### 20230119 - SHOCO - Reflection token

### Lost: ~4ETH

Testing

```sh
forge test --contracts ./src/test/others/SHOCO_exp.sol -vvvgit
```

#### Contract

[SHOCO_exp.sol](../../src/test/others/SHOCO_exp.sol)

#### Link reference

https://github.com/Autosaida/DeFiHackAnalysis/blob/master/analysis/230119_SHOCO.md

---

### 20230119 - ThoreumFinance-business logic flaw

### Lost: ~2000 BNB

Testing

```sh
forge test --contracts ./src/test/others/ThoreumFinance_exp.sol -vvv
```

#### Contract

[ThoreumFinance_exp.sol](../../src/test/others/ThoreumFinance_exp.sol)

#### Link reference

https://bscscan.com/tx/0x3fe3a1883f0ae263a260f7d3e9b462468f4f83c2c88bb89d1dee5d7d24262b51
https://twitter.com/AnciliaInc/status/1615944396134043648

---

### 20230118 - QTNToken - business logic flaw

### Lost: ~2ETH

Testing

```sh
forge test --contracts ./src/test/others/QTN_exp.sol -vvv
```

#### Contract

[QTN_exp.sol](../../src/test/others/QTN_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1615625901739511809

---

### 20230118 - UPSToken - business logic flaw

### Lost: ~22 ETH

Testing

```sh
forge test --contracts ./src/test/others/Upswing_exp.sol -vvv
```

#### Contract

[Upswing_exp.sol](../../src/test/others/Upswing_exp.sol)

#### Link reference

https://etherscan.io/tx/0x4b3df6e9c68ae482c71a02832f7f599ff58ff877ec05fed0abd95b31d2d7d912
https://twitter.com/QuillAudits/status/1615634917802807297

---

### 20230117 - OmniEstate - No Input Parameter Check

### Lost: $70k(236 BNB)

Testing

```sh
forge test --contracts ./src/test/others/OmniEstate_exp.sol -vvv
```

#### Contract

[OmniEstate_exp.sol](../../src/test/others/OmniEstate_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1615232012834705408

---

### 20230116 - MidasCapital - Read-only Reentrancy

### Lost: $650k

Testing

```sh
forge test --contracts ./src/test/others/Midas_exp.sol -vvv
```

#### Contract

[Midas_exp.sol](../../src/test/others/Midas_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1614774855999844352

https://twitter.com/BlockSecTeam/status/1614864084956254209

---

### 20230111 - UFDao - Incorrect Parameter Setting

### Lost: $90k

Testing

```sh
forge test --contracts ./src/test/others/UFDao_exp.sol -vvv
```

#### Contract

[UFDao_exp.sol](../../src/test/others/UFDao_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1613507804412940289

---

### 20230111 - RoeFinance - FlashLoan price manipulation

### Lost: $80k

Testing

```sh
forge test --contracts ./src/test/others/RoeFinance_exp.sol -vvv
```

#### Contract

[RoeFinance_exp.sol](../../src/test/others/RoeFinance_exp.sol)

#### Link reference

https://twitter.com/BlockSecTeam/status/1613267000913960976

---

### 20230110 - BRA - Business Logic Flaw

### Lost: 819 BNB (~224k$)

Testing

```sh
forge test --contracts ./src/test/others/BRA.exp.sol -vvv
```

#### Contract

[BRA.exp.sol](../../src/test/others/BRA.exp.sol)

#### Link reference

https://twitter.com/CertiKAlert/status/1612674916070858753

https://twitter.com/BlockSecTeam/status/1612701106982862849

---

### 20230103 - GDS - Business Logic Flaw

### Lost: $180k

Testing

```sh
forge test --contracts ./src/test/others/GDS_exp.sol -vvv
```

#### Contract

[GDS_exp.sol](../../src/test/others/GDS_exp.sol)

#### Link reference

https://twitter.com/peckshield/status/1610095490368180224

https://twitter.com/BlockSecTeam/status/1610167174978760704
