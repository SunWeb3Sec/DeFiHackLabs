# DeFi Hacks Reproduce - Foundry
> Reproduce Defi hack incidents via Foundry.

> 25 incidents included.

> This repo is only for the educational purpose.

## Getting Started
This is the easiest option for Linux and macOS users.

Open your terminal and type in the following command:

```sh
curl -L https://foundry.paradigm.xyz | bash
```

This will download `foundryup`. Then install Foundry by running:

```sh
foundryup
```

If everything goes well, you will now have two binaries at your disposal: `forge` and `cast`.

Create an account on [moralis.io](https://moralis.io/) or [alchemy.com](https://www.alchemy.com/) for the mainnet forking.

## Hacks Reproduce
### Transaction debugging tools
https://dashboard.tenderly.co/explorer

https://ethtx.info/

https://versatile.blocksecteam.com/tx

https://github.com/dapphub/dapptools

### 202206016 InverseFinance 
#### Lost: 53.2445 WBTC and 99,976.29 USDT

Testing
```sh
forge test --contracts ./src/test/InverseFinance_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 14972418 -vv
```
#### Link reference
https://twitter.com/peckshield/status/1537382891230883841

https://twitter.com/SlowMist_Team/status/1537602909512376321

https://blocksecteam.medium.com/price-oracle-manipulation-attack-on-inverse-finance-a5544218ea91

https://www.certik.com/resources/blog/6LbL57WA3iMNm8zd7q111R-inverse-finance-incident-analysis

https://etherscan.io/tx/0x958236266991bc3fe3b77feaacea120f172c0708ad01c7a715b255f218f9313c

### 20220608 GYMNetwork 
#### Lost: $2.1 million

Testing
```sh
forge test --contracts ./src/test/Gym_2_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/bsc/mainnet/archive --fork-block-number 18501049 -vv
```
#### Link reference
https://twitter.com/peckshield/status/1534423219607719936

https://twitter.com/1nf0s3cpt/status/1534464698069884929

https://www.jinse.com/news/blockchain/1658455.html

### 20220608 Optimism - Wintermute
#### Lost: 20 million Optimism (OP) tokens returned 17 million of them

Testing
```sh
forge test --contracts ./src/test/Optimism_exp.sol --fork-url https://opt-mainnet.g.alchemy.com/v2/[APIKEY]/ --fork-block-number 10607735 -vv
```
#### Link reference
https://blockworks.co/20m-tokens-lost-as-market-maker-wintermute-takes-blame/

https://optimistic.etherscan.io/tx/0x75a42f240d229518979199f56cd7c82e4fc1f1a20ad9a4864c635354b4a34261

https://optimistic.etherscan.io/tx/0x00a3da68f0f6a69cb067f09c3f7e741a01636cbc27a84c603b468f65271d415b

### 20220606 Discover Flashloan 
#### Lost: 49 BNB

Testing
```sh
forge test --contracts ./src/test/Discover_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/bsc/mainnet/archive --fork-block-number 18446845  -vv
```
#### Link reference
https://www.twitter.com/BeosinAlert/status/1533734518623899648

https://www.anquanke.com/post/id/274003

https://bscscan.com/tx/0x8a33a1f8c7af372a9c81ede9e442114f0aabb537e5c3a22c0fd7231c4820f1e9

https://bscscan.com/tx/0x1dd4989052f69cd388f4dfbeb1690a3f3a323ebb73df816e5ef2466dc98fa4a4


### 20220430 Rari Capital/Fei Protocol
#### Lost: $80 million

Testing
```sh
forge test --contracts ./src/test/Rari_exp.t.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 14684813 -vv
```
#### Link reference
https://certik.medium.com/fei-protocol-incident-analysis-8527440696cc

https://twitter.com/peckshield/status/1520369315698016256

https://etherscan.io/tx/0xab486012f21be741c9e674ffda227e30518e8a1e37a5f1d58d0b0d41f6e76530


### 20220428 DEUS DAO
#### Lost: $13 million

Testing
```sh
forge test --contracts ./src/test/deus_poc.t.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/fantom/mainnet/archive --fork-block-number 37093708 -vv
```
#### Link reference
https://twitter.com/peckshield/status/1519531866109317121

https://ftmscan.com/tx/0xe374495036fac18aa5b1a497a17e70f256c4d3d416dd1408c026f3f5c70a3a9c


### 20220421 Zeed Finance
#### Lost: $1 million

Testing
```sh
forge test --contracts ./src/test/Zeed_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/bsc/mainnet/archive --fork-block-number 17132514 -vv
```
#### Link reference
https://www.cryptotimes.io/hacker-leaves-1m-to-self-destruct-after-zeed-protocol-exploit/

https://medium.com/@zeedcommunity/the-solution-for-the-yeed-lp-pool-attack-a120c53948cd

https://bscscan.com/tx/0x0507476234193a9a5c7ae2c47e4c4b833a7c3923cefc6fd7667b72f3ca3fa83a

### 20220415 Rikkei Finance
#### Lost: $1.1 million (2671 BNB)

Testing
```sh
forge test --contracts ./src/test/Rikkei_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/bsc/mainnet/archive --fork-block-number 16956474 -vv
```
#### Link reference
https://blockmagnates.com/rikkei-finance-hack/

https://knownseclab.com/news/625e865cf1c544005a4bdaf2

https://rikkeifinance.medium.com/rikkei-finance-incident-investigation-report-b5b1745b0155

https://bscscan.com/tx/0x93a9b022df260f1953420cd3e18789e7d1e095459e36fe2eb534918ed1687492

### 20220412 ElephantMoney 
#### Lost: $11.2 million (27,416.46 BNB)

Testing
```sh
forge test --contracts ./src/test/Elephant_Money_poc.t.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/bsc/mainnet/archive --fork-block-number 16886438 -vv
```
#### Link reference
https://medium.com/elephant-money/reserve-exploit-52fd36ccc7e8

https://twitter.com/peckshield/status/1514023036596330496

https://twitter.com/BlockSecTeam/status/1513966074357698563

https://bscscan.com/tx/0xec317deb2f3efdc1dbf7ed5d3902cdf2c33ae512151646383a8cf8cbcd3d4577

### 20220409 GYMNetwork
#### Lost: 1,327 WBNB

Testing
```sh
forge test --contracts ./src/test/Gym_1_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/bsc/mainnet/archive --fork-block-number 16798806 -vv
```
#### Link reference
https://twitter.com/BlockSecTeam/status/1512832398643265537

https://medium.com/@Beosin_com/beosin-analysis-of-the-attack-on-gymdefi-e5a23bfd93fe

https://bscscan.com/tx/0xa5b0246f2f8d238bb56c0ddb500b04bbe0c30db650e06a41e00b6a0fff11a7e5

### 20220327 Revest Finance
#### Lost: $11.2 million 

Testing
```sh
forge test --contracts ./src/test/Revest_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 14465356 -vv
```
#### Link reference
https://blocksecteam.medium.com/revest-finance-vulnerabilities-more-than-re-entrancy-1609957b742f

https://etherscan.io/tx/0xe0b0c2672b760bef4e2851e91c69c8c0ad135c6987bbf1f43f5846d89e691428

### 20220326 Auctus 
#### Lost: $726 k 

Testing
```sh
forge test --contracts ./src/test/Auctus_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 14460635 -vv
```
#### Link reference
https://twitter.com/AuctusOptions/status/1508647849663291398?cxt=HHwWjICzpbzO5e8pAAAA

https://etherscan.io/tx/0x2e7d7e7a6eb157b98974c8687fbd848d0158d37edc1302ea08ee5ddb376befea


### 20220322 CompoundTUSDSweepTokenBypass

Testing
```sh
forge test --contracts ./src/test/CompoundTusd_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 14266479 -vv
```
#### Link reference
https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/

### 20220321 OneRing Finance 
#### Lost: $1.45 million

Testing
```sh
forge test --contracts ./src/test/OneRing_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/fantom/mainnet/archive --fork-block-number 34041499 -vv
```
#### Link reference
https://medium.com/oneringfinance/onering-finance-exploit-post-mortem-after-oshare-hack-602a529db99b

https://ftmscan.com/tx/0xca8dd33850e29cf138c8382e17a19e77d7331b57c7a8451648788bbb26a70145


### 20220313 Paraluni 
#### Lost: $1.7 million

Testing
```sh
forge test --contracts ./src/test/Paraluni_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/bsc/mainnet/archive --fork-block-number 16008280 -vv
```
#### Link reference
https://halborn.com/explained-the-paraluni-hack-march-2022/

https://twitter.com/peckshield/status/1502815435498176514

https://mobile.twitter.com/paraluni/status/1502951606202994694

https://zhuanlan.zhihu.com/p/517535530

https://bscscan.com/tx/0x70f367b9420ac2654a5223cc311c7f9c361736a39fd4e7dff9ed1b85bab7ad54


### 20220309 Fantasm Finance 
#### Lost: $2.6 million

Testing
```sh
forge test --contracts ./src/test/Fantasm_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/fantom/mainnet --fork-block-number 32971742 -vv
```
#### Link reference
https://twitter.com/fantasm_finance/status/1501569232881995785

https://medium.com/quillhash/fantom-based-protocol-fantasm-suffers-2-6m-exploit-32de8191ccd4

https://etherscan.io/tx/0xacfcaa8e1c482148f9f2d592c78ca7a27934c7333dab31978ed0aef333a28ab6


### 20220305 Bacon Protocol 
#### Lost: $1 million

Testing
```sh
forge test --contracts ./src/test/Bacon_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 14326931 -vv
```
#### Link reference
https://twitter.com/peckshield/status/1500105933128495108

https://etherscan.io/tx/0xacfcaa8e1c482148f9f2d592c78ca7a27934c7333dab31978ed0aef333a28ab6

https://etherscan.io/tx/0x7d2296bcb936aa5e2397ddf8ccba59f54a178c3901666b49291d880369dbcf31

### 20220303 TreasureDAO 
#### Lost: $1 million

Testing
```sh
forge test --contracts ./src/test/TreasureDAO_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/arbitrum/mainnet --fork-block-number 7322694 -vv
```
#### Link reference
https://slowmist.medium.com/analysis-of-the-treasuredao-zero-fee-exploit-73791f4b9c14

https://arbiscan.io/tx/0x82a5ff772c186fb3f62bf9a8461aeadd8ea0904025c3330a4d247822ff34bc02


### 20220118 Multichain (Anyswap)
#### Lost: $1.4 million

Testing
```sh
forge test --contracts ./src/test/Anyswap_poc.t.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 14037236 -vv
```
#### Link reference
https://medium.com/zengo/without-permit-multichains-exploit-explained-8417e8c1639b

https://twitter.com/PeckShieldAlert/status/1483363515411099651

https://etherscan.io/tx/0xe50ed602bd916fc304d53c4fed236698b71691a95774ff0aeeb74b699c6227f7


### 20211221 Visor Finance 
#### Lost:  $8.2 million

Testing
```sh
forge test --contracts ./src/test/Visor_exp.t.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 13849006 -vv
```
#### Link reference
https://beosin.medium.com/two-vulnerabilities-in-one-function-the-analysis-of-visor-finance-exploit-a15735e2492

https://twitter.com/GammaStrategies/status/1473306777131405314

https://etherscan.io/tx/0x69272d8c84d67d1da2f6425b339192fa472898dce936f24818fda415c1c1ff3f


### 20211130 MonoX Finance
#### Lost: $31 million

Testing
```sh
forge test --contracts ./src/test/Mono_exp.t.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 13715025 -vv
```
#### Link reference
https://slowmist.medium.com/detailed-analysis-of-the-31-million-monox-protocol-hack-574d8c44a9c8

https://knownseclab.com/news/61a986811992da0067558749

https://www.tuoniaox.com/news/p-521076.html

https://polygonscan.com/tx/0x5a03b9c03eedcb9ec6e70c6841eaa4976a732d050a6218969e39483bb3004d5d

https://etherscan.io/tx/0x9f14d093a2349de08f02fc0fb018dadb449351d0cdb7d0738ff69cc6fef5f299

### 20210830 Cream Finance
#### Lost: $18 million

Testing
```sh
forge test --contracts ./src/test/Cream_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 13125070 -vv
```
#### Link reference
https://twitter.com/peckshield/status/1432249600002478081

https://etherscan.io/tx/0xa9a1b8ea288eb9ad315088f17f7c7386b9989c95b4d13c81b69d5ddad7ffe61e

https://slowmist.medium.com/cream-hacked-analysis-us-130-million-hacked-95c9410320ca


### 20210817 XSURGE
#### Lost: $5 million

Testing
```sh
forge test --contracts ./src/test/XSURGE_exp.t.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/bsc/mainnet/archive --fork-block-number 10087723 -vv
```
#### Link reference
https://beosin.medium.com/a-sweet-blow-fb0a5e08657d

https://medium.com/@Knownsec_Blockchain_Lab/knownsec-blockchain-lab-comprehensive-analysis-of-xsurge-attacks-c83d238fbc55

https://bscscan.com/tx/0x8c93d6e5d6b3ec7478b4195123a696dbc82a3441be090e048fe4b33a242ef09d

### 20210308 DODO Flashloan
#### Lost: $700,000
Testing
```sh
forge test --contracts ./src/test/dodo_flashloan_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 12000000 -vv
```
#### Link reference
https://blog.dodoex.io/dodo-pool-incident-postmortem-with-a-little-help-from-our-friends-327e66872d42

https://halborn.com/explained-the-dodo-dex-hack-march-2021/

https://etherscan.io/tx/0x395675b56370a9f5fe8b32badfa80043f5291443bd6c8273900476880fb5221e

### 20201229 Cover Protocol

Testing
```sh
forge test --contracts ./src/test/Cover_exp.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 11542309 -vv
```
#### Link reference
https://mudit.blog/cover-protocol-hack-analysis-tokens-minted-exploit/

https://slowmist.medium.com/a-brief-analysis-of-the-cover-protocol-hacked-event-700d747b309c

### FlashLoan Testing

DODO FlashLoan Testing
```sh
forge test --contracts ./src/test/dodo_flashloan.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 12000000 -vv
```

AAVE FlashLoan Testing
```sh
forge test --contracts ./src/test/flashloan_aave.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 14972418 -vv

```

Balancer FlashLoan Testing
```sh
forge test --contracts ./src/test/flashloan_balancer.t.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 14684822 -vv
```

Pancakeswap FlashSwap Testing
```sh
forge test --contracts ./src/test/flashswap_pancake.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/bsc/mainnet/archive --fork-block-number 18646610 -v
```

Biswap FlashSwap Testing
```sh
forge test --contracts ./src/test/flashloan_biswap.sol --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/bsc/mainnet/archive --fork-block-number 18671800 -vv
```

UniSwapV2 FlashSwap Testing
```sh
forge test --contracts ./src/test/flashloan_uniswapv2.sol  --fork-url https://speedy-nodes-nyc.moralis.io/[APIKEY]/eth/mainnet/archive --fork-block-number 14971460 -vv
```

#### Some codes refer to Rivaill and W2Ning repo and are rewrote to the foundry version.
