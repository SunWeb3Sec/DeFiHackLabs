# DeFi Hacks Reproduce - Foundry
**Reproduce DeFi hack incidents using Foundry.**

51 incidents included.

This repo is only for the educational purpose.

Let's make Web3 secure!

## Getting Started

* Follow the [instructions](https://book.getfoundry.sh/getting-started/installation.html) to install [Foundry](https://github.com/foundry-rs/foundry).

* Clone and install dependencies:```git submodule update --init --recursive```

## List of DeFi Hacks & Exploits

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

[20220624 Harmony's Horizon Bridge](#20220624-harmonys-horizon-bridge)

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

[20220421 Zeed Finance](#20220421-zeed-finance)

[20220416 BeanstalkFarms](#20220416-beanstalkfarms---dao--flashloan)

[20220415 Rikkei Finance](#20220415-rikkei-finance---accesscontrol--price-oracle-manipulation)

[20220412 ElephantMoney](#20220412-elephantmoney---flashloan--price-oracle-manipulation)

[20220409 GYMNetwork](#20220409-gymnetwork)

[20220327 Revest Finance](#20220327-revest-finance---reentrancy)

[20220326 Auctus](#20220326-auctus)

[20220322 CompoundTUSDSweepTokenBypass](#20220322-compoundtusdsweeptokenbypass)

[20220321 OneRing Finance](#20220321-onering-finance---flashloan--price-oracle-manipulation)

[20220320 LI.FI](#20220320-Li.Fi---bridges)

[20220313 Paraluni](#20220313-paraluni---flashloan--reentrancy)

[20220309 Fantasm Finance](#20220309-fantasm-finance)

[20220305 Bacon Protocol](#20220305-bacon-protocol---reentrancy)

[20220303 TreasureDAO](#20220303-treasuredao---zero-fee)

[20220214 BuildFinance - DAO](#20220214-buildfinance---dao)

[20220208 Sandbox LAND](#20220208-sandbox-land---access-control)

[20220118 Multichain (Anyswap)](#20220118-multichain-anyswap---bridge, insufficient-token-validation)

[20211221 Visor Finance](#20211221-visor-finance---reentrancy)

[20211218 Grim Finance](#20211218-grim-finance---flashloan--reentrancy)

[20211130 MonoX Finance](#20211130-monox-finance---price-manipulation)

[20210916 SushiSwap Miso](#20210916-sushiswap-miso)

[20210830 Cream Finance](#20210830-cream-finance---flashloan-attack--reentrancy)

[20210811 Poly Network](#20210811-poly-network---bridge)

[20210817 XSURGE](#20210817-xsurge---flashloan-attack--reentrancy)

[20210607 88mph NFT](#20210607-88mph-nft---access-control)

[20210308 DODO](#20210308-dodo---flashloan-attack)

[20201229 Cover Protocol](#20201229-cover-protocol)

[20201026 Harvest Finance](#20201026-harvest-finance---flashloan-attack)

[20171106 Parity - 'Accidentally Killed It'](#20171106-parity---accidentally-killed-it)

### Transaction debugging tools
https://dashboard.tenderly.co/explorer

https://ethtx.info/

https://versatile.blocksecteam.com/tx

### 20220807 EGD Finance - Flashloans & Price Manipulation
#### Lost: 36,044 USDT

Testing
```sh
forge test --contracts ./src/test/EGD-Finance.exp.sol -vvv 
```
#### Link reference

https://twitter.com/BlockSecTeam/status/1556483435388350464

https://twitter.com/PeckShieldAlert/status/1556486817406283776

### 20220802 Nomad Bridge - Business Logic Flaw : Incorrect acceptable merkle-root checks
#### Lost: Multiple ERC-20 Tokens (~152M US$)

Testing
```sh
forge test --contracts ./src/test/NomadBridge.exp.sol -vvv 
```
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
#### Link reference

https://twitter.com/Reaper_Farm/status/1554500909740302337

https://twitter.com/BeosinAlert/status/1554476940593340421

### 20220725 LPC - Business Logic Flaw : Incorrect recipient balance check, did not check sender!=recipient in transfer
#### Lost: 178 BNB (~45,715 US$)

Testing
```sh
forge test --contracts ./src/test/LPC.exp.sol -vvv 
```
#### Link reference

https://www.panewslab.com/zh_hk/articledetails/uwv4sma2.html

https://twitter.com/BeosinAlert/status/1551535854681718784

### 20220723 Audius - Storage Collision & Malicious Proposal, storage collision of proxy and implementation contracts
#### Lost: 704 ETH (~1.08M US$)

Testing
```sh
forge test --contracts ./src/test/Audius.exp.sol -vvv 
```
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
#### Link reference
https://etherscan.io/tx/0xeb8c3bebed11e2e4fcd30cbfc2fb3c55c4ca166003c7f7d319e78eaab9747098

https://news.coincu.com/73892-the-flashloan-attack-on-the-ape-airdrop-to-claim-1-1-million-of-ape-tokens/

### 20220508 Fortress Loans - Malicious Proposal & Price Oracle Manipulation
#### Lost: 1,048.1 ETH + 400,000 DAI (~$3.00M)

Testing
```sh
forge test --contracts ./src/test/FortressLoans.exp.sol -vvv
```
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
#### Link reference
https://twitter.com/peckshield/status/1519531866109317121

https://ftmscan.com/tx/0xe374495036fac18aa5b1a497a17e70f256c4d3d416dd1408c026f3f5c70a3a9c


### 20220421 Zeed Finance - Reward distribution flaw
#### Lost: $1 million

Testing
```sh
forge test --contracts ./src/test/Zeed_exp.sol -vv
```
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
#### Link reference
https://blockmagnates.com/rikkei-finance-hack/

https://knownseclab.com/news/625e865cf1c544005a4bdaf2

https://rikkeifinance.medium.com/rikkei-finance-incident-investigation-report-b5b1745b0155

https://bscscan.com/tx/0x93a9b022df260f1953420cd3e18789e7d1e095459e36fe2eb534918ed1687492

### 20220412 ElephantMoney - Flashloan & Price Oracle Manipulation
#### Lost: $11.2 million (27,416.46 BNB)

Testing
```sh
forge test --contracts ./src/test/Elephant_Money_poc.t.sol -vv
```
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
#### Link reference
https://twitter.com/BlockSecTeam/status/1512832398643265537

https://medium.com/@Beosin_com/beosin-analysis-of-the-attack-on-gymdefi-e5a23bfd93fe

https://bscscan.com/tx/0xa5b0246f2f8d238bb56c0ddb500b04bbe0c30db650e06a41e00b6a0fff11a7e5

### 20220327 Revest Finance - Reentrancy
#### Lost: $11.2 million

Testing
```sh
forge test --contracts ./src/test/Revest_exp.sol -vv
```
#### Link reference
https://blocksecteam.medium.com/revest-finance-vulnerabilities-more-than-re-entrancy-1609957b742f

https://etherscan.io/tx/0xe0b0c2672b760bef4e2851e91c69c8c0ad135c6987bbf1f43f5846d89e691428

### 20220326 Auctus
#### Lost: $726 k

Testing
```sh
forge test --contracts ./src/test/Auctus_exp.sol -vv
```
#### Link reference
https://twitter.com/AuctusOptions/status/1508647849663291398?cxt=HHwWjICzpbzO5e8pAAAA

https://etherscan.io/tx/0x2e7d7e7a6eb157b98974c8687fbd848d0158d37edc1302ea08ee5ddb376befea


### 20220322 CompoundTUSDSweepTokenBypass

Testing
```sh
forge test --contracts ./src/test/CompoundTusd_exp.sol -vv
```
#### Link reference
https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/

### 20220321 OneRing Finance - Flashloan & Price Oracle Manipulation
#### Lost: $1.45 million

Testing
```sh
forge test --contracts ./src/test/OneRing_exp.sol -vv
```
#### Link reference
https://medium.com/oneringfinance/onering-finance-exploit-post-mortem-after-oshare-hack-602a529db99b

https://ftmscan.com/tx/0xca8dd33850e29cf138c8382e17a19e77d7331b57c7a8451648788bbb26a70145

### 20220320 Li.Fi - Bridges
#### Lost: $570K

Testing
```sh
forge test --contracts ./src/test/LiFi_exp.sol -vvvv
```
#### Link reference
https://blog.li.fi/20th-march-the-exploit-e9e1c5c03eb9

https://twitter.com/lifiprotocol/status/1505738407938387971

https://etherscan.io/tx/0x4b4143cbe7f5475029cf23d6dcbb56856366d91794426f2e33819b9b1aac4e96

#### Fix
implemented a whitelist to only allow calls to approved DEXs. 

### 20220313 Paraluni - Flashloan & Reentrancy
#### Lost: $1.7 million

Testing
```sh
forge test --contracts ./src/test/Paraluni_exp.sol -vv
```
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
#### Link reference
https://slowmist.medium.com/analysis-of-the-treasuredao-zero-fee-exploit-73791f4b9c14

https://arbiscan.io/tx/0x82a5ff772c186fb3f62bf9a8461aeadd8ea0904025c3330a4d247822ff34bc02

### 20220214 BuildFinance - DAO
#### Lost: $470k

Testing
```sh
forge test --contracts ./src/test/BuildF_exp.sol -vv
```
#### Link reference
https://twitter.com/finance_build/status/1493223190071554049

https://www.cryptotimes.io/build-finance-suffered-hostile-governance-takeover-lost-470k/

https://etherscan.io/tx/0x544e5849b71b98393f41d641683586d0b519c46a2eeac9bcb351917f40258a85

### 20220208 Sandbox LAND - Access control

Testing
```sh
forge test --contracts ./src/test/Sandbox_exp.sol -vv
```
#### Link reference
https://slowmist.medium.com/the-vulnerability-behind-the-sandbox-land-migration-2abf68933170

https://etherscan.io/tx/0x34516ee081c221d8576939f68aee71e002dd5557180d45194209d6692241f7b1

### 20220118 Multichain (Anyswap) - Insufficient Token Validation
#### Lost: $1.4 million

Testing
```sh
forge test --contracts ./src/test/Anyswap_poc.t.sol -vv
```
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
#### Link reference
https://www.paradigm.xyz/2021/08/two-rights-might-make-a-wrong

https://etherscan.io/tx/0x78d6355703507f88f2090eb780d245b0ab26bf470eabdb004761cedf3b1cda44


### 20210830 Cream Finance - Flashloan Attack + Reentrancy
#### Lost: $18 million

Testing
```sh
forge test --contracts ./src/test/Cream_exp.sol -vv
```
#### Link reference
https://twitter.com/peckshield/status/1432249600002478081

https://etherscan.io/tx/0xa9a1b8ea288eb9ad315088f17f7c7386b9989c95b4d13c81b69d5ddad7ffe61e

https://slowmist.medium.com/cream-hacked-analysis-us-130-million-hacked-95c9410320ca

### 20210811 Poly Network - Bridge
#### Lost: $611 million

Testing
```sh
forge test --contracts ./src/test/PolyNetwork/PolyNetwork_exp.sol -vv
```
#### Link reference
https://rekt.news/polynetwork-rekt/

https://medium.com/breadcrumbsapp/the-600m-poly-network-hack-the-biggest-hack-in-defi-history-e2efe56cf3a8

https://etherscan.io/tx/0xb1f70464bd95b774c6ce60fc706eb5f9e35cb5f06e6cfe7c17dcda46ffd59581/advanced

https://github.com/polynetwork/eth-contracts/tree/d16252b2b857eecf8e558bd3e1f3bb14cff30e9b

### 20210817 XSURGE - Flashloan Attack + Reentrancy
#### Lost: $5 million

Testing
```sh
forge test --contracts ./src/test/XSURGE_exp.t.sol -vv
```
#### Link reference
https://beosin.medium.com/a-sweet-blow-fb0a5e08657d

https://medium.com/@Knownsec_Blockchain_Lab/knownsec-blockchain-lab-comprehensive-analysis-of-xsurge-attacks-c83d238fbc55

https://bscscan.com/tx/0x8c93d6e5d6b3ec7478b4195123a696dbc82a3441be090e048fe4b33a242ef09d

### 20210607 88mph NFT - Access control
Testing
```sh
forge test --contracts ./src/test/88mph_exp.sol -vv
```
#### Link reference
https://medium.com/immunefi/88mph-function-initialization-bug-fix-postmortem-c3a2282894d3

### 20210308 DODO - Flashloan Attack
#### Lost: $700,000
Testing
```sh
forge test --contracts ./src/test/dodo_flashloan_exp.sol -vv
```
#### Link reference
https://blog.dodoex.io/dodo-pool-incident-postmortem-with-a-little-help-from-our-friends-327e66872d42

https://halborn.com/explained-the-dodo-dex-hack-march-2021/

https://etherscan.io/tx/0x395675b56370a9f5fe8b32badfa80043f5291443bd6c8273900476880fb5221e

### 20201229 Cover Protocol

Testing
```sh
forge test --contracts ./src/test/Cover_exp.sol -vv
```
#### Link reference
https://mudit.blog/cover-protocol-hack-analysis-tokens-minted-exploit/

https://slowmist.medium.com/a-brief-analysis-of-the-cover-protocol-hacked-event-700d747b309c

### 20201026 Harvest Finance - Flashloan Attack
#### Lost: $33.8 million
Testing
```sh
forge test --contracts ./src/test/HarvestFinance_exp.sol -vv

```
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