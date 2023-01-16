# Lesson 4: NFT airdrop phishing case study_ how the victims are targeted and scam is conducted

Author: [Scam Sniffer](https://twitter.com/scamsniffer_)

Community: [Discord](https://discord.gg/Fjyngakf3h)

Published on: [Scam Sniffer](https://twitter.com/scamsniffer_/status/1601779473036316674)

## Blackboard
There have been lots of airdrop phishing scams targeting specific NFT holder groups lately, let’s have a deep dive case study and see how the scam is conducted.
It all started from Dec.3 , our Scam Sniffer Alert Bot detected there was a phishing incident that ended up with 21 CloneX being stolen, totally worth 168 ETH.

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598204-a2855b53-dc9a-4902-941a-bc48c4ff0dc1.png" alt="Cover" width="60%"/>
</div>

After discussed with [Cos(余弦)](https://twitter.com/evilcos) in a white hat group chat, we successfully identified the [initial malicious Tx](https://etherscan.io/tx/0xbf2542540ce22abe7a1822e15d67a50b73a7ba18e036bb305103e51606122b69), which happened on 8th Dec. After that, the stolen NFT assets were transferred to a flagged phishing address `0xa0b2ebf28b621fd925a2f809378a3dbc066c28f6` in ScamSniffer database and then sold in the market gradually. 
First, let’s look into the malicious Tx in detail.

### Malicious Tx

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598316-865e82d6-feb7-4ab8-b6d1-050b8a1ec9ef.png" alt="Cover" width="80%"/>
</div>

This is a Seaport Tx, 134 NFT were sold with 0 ETH price in this Tx:
* `0xabeaa3375534d2931b2149067af3e7b8458d2f0c` - victim
* `0x4574043b6423953723356237042bf6df2304f297` - malicious Tx originator
* `0xc0fdf4fa92f88b82ccbebfc80fbe4eb7e5a8e0ca` - malicous assets taker

`The victim` signed the malicious Seaport Tx in his wallet so `the malicious Tx originator` got the victims signature and then bought the assets with 0 cost.
For anyone who is not familiar with Seaport protocol, you can find more information in the next section.

### Seaport Protocol
<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598354-10dc6320-8744-4dce-ac52-de3d0f8314f5.png" alt="Cover" width="80%"/>
</div>

