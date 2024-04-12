# Lesson 4: NFT airdrop phishing case study how the victims are targeted and scam is conducted

Author: [Scam Sniffer](https://twitter.com/scamsniffer_)

## Blackboard
There have been lots of airdrop phishing scams targeting specific NFT holder groups lately, let’s have a deep dive case study and see how the scam is conducted.
It all started from Dec.3 , our Scam Sniffer Alert Bot detected there was a phishing incident that ended up with 21 CloneX being stolen, totally worth 168 ETH.

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598204-a2855b53-dc9a-4902-941a-bc48c4ff0dc1.png" alt="Cover" width="60%"/>
</div>

After discussed with [Cos(余弦)](https://twitter.com/evilcos) in a white hat group chat, we successfully identified the [initial malicious Tx](https://etherscan.io/tx/0xbf2542540ce22abe7a1822e15d67a50b73a7ba18e036bb305103e51606122b69), which happened on 8th Dec. After that, the stolen NFT assets were transferred to a flagged phishing address `0xa0b2ebf28b621fd925a2f809378a3dbc066c28f6` in ScamSniffer database and then sold in the market gradually. 

First, let’s look into the malicious Tx in detail.

## Case Analysis
### Malicious Tx

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598316-865e82d6-feb7-4ab8-b6d1-050b8a1ec9ef.png" alt="Cover" width="80%"/>
</div>

This is a Seaport Tx, 134 NFT were sold with 0 ETH price in this Tx:
* `0xabeaa3375534d2931b2149067af3e7b8458d2f0c` - victim
* `0x4574043b6423953723356237042bf6df2304f297` - malicious Tx originator
* `0xc0fdf4fa92f88b82ccbebfc80fbe4eb7e5a8e0ca` - malicious assets taker

`The victim` signed the malicious Seaport Tx in his wallet so `the malicious Tx originator` got the victims signature and then bought the assets with 0 cost.
For anyone who is not familiar with Seaport protocol, you can find more information in the next section.

### Seaport Protocol
<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598354-10dc6320-8744-4dce-ac52-de3d0f8314f5.png" alt="Cover" width="80%"/>
</div>

Seaport is a very popular NFT trading protocol that was adapted by major marketplaces like Opensea, you should have seen it many times before if you are a NFT trader.

In the following example of Seaport Tx:
* Consideration `startAmount` is 92500000000000000 (0.0925 ETH)
* Token is `0x0000000000000000000000000000000000000000`(ETH)
* This means the bidder need to pay at least 0.0925 ETH to purchase the assets

Unfortunately, most of the users, especially non-dev users, didn’t know the significance of the info or didn’t pay enough attention to them. The malicious groups use that to conduct fishing scams.
Since July 2021, MetaMask improved its UI to highlight the risk of Approve Tx users being requested to sign, this reduced a certain level of phishing scams.

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212599038-7b3a7fba-6234-49da-bae3-27be2f39317d.png" alt="Cover" width="70%"/>
</div>

So after that, many malicious groups turned to Seaport as a new way to scam users. As default protocol for NFT marketplaces, almost every user has been authorized to use Seaport with their NFT assets since its launch in May 2021.

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598432-e99f5574-7de4-4c5d-b8e6-b08572ff2b69.png" alt="Cover" width="80%"/>
</div>

We have found many phishing scams using Seaport protocol since July 2021. Lots of users fall into it, because there is no warning from the wallet and again, most of the users don't pay much attention to  what they are signing.

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598499-63d1a8b2-21b5-4f71-9530-2dff912244b4.png" alt="Cover" width="70%"/>
</div>

**<p align="center">The malicious Seaport Tx**</p>

Tips for anyone who want to identify malicious Seaport signature request:
* Pay attention to signature request `consideration` section.
* Token `0x0000000000000000000000000000000000000000` (ETH) is low risk, other than that is malicious.
* Super cautious with startAmount 1 or extremely small.
MetaMask should also improve UI to highlight the risk for end users, like what they did for Approval functions.

### How they targeting the victims

So after learning the mechanism behind Seaport, the next crucial question is: how do the malicious groups target the victims, and in the end, how do they trick the victims to sign the malicious Seaport signature request?

Thanks the hints from [Cos(余弦)](https://twitter.com/evilcos), there are lots of malicious NFT airdrops in Polygon lately, so I checked the Tx history from victim’s address `0xabeaa3375534d2931b2149067af3e7b8458d2f0c`:

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598554-619196b9-c100-47d8-a947-0074db016e51.png" alt="Cover" width="70%"/>
</div>

There are several [RTFKT related NFT airdrops](https://polygonscan.com/tx/0xcf2f993113a4d558801e60f8790390c1c45085bcee717e7ed8b4a67e2e8c705d)!

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598606-442647a7-30c7-48ef-abfc-1b6a9a8827f9.png" alt="Cover" width="70%"/>
</div>

So the malicious groups send airdrops using Seaport, apparently this way can bypass the NFT marketplaces’ garbage airdrop detection, so the end user can see the malicious airdrops and click into the fishing sites.
Totally 883 addresses are targeted and received the malicious airdrops.

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598659-9527183c-0997-4b1c-a357-99c4e36a3796.png" alt="Cover" width="70%"/>
</div>

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/213104333-32cb879f-1a81-47e1-a34e-0afcfaaed1fa.png" alt="Cover" width="70%"/>
</div>
<p align="center""> Call Trace </p>

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/213104607-aa91daf7-4821-4df7-8db2-3c01e70d7b83.png" alt="Cover" width="70%"/>
</div>
<p align="center""> Decompiled snippet </p>

### Phishing Websites
We have flagged hundreds of RTFKT related websites in [Scam Sniffer database](https://github.com/scamsniffer/scam-database/blob/main/blacklist/domains.json), lots of them are still functioning, those websites are the final destinations which the scammers are tricking users into.

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598712-66b28c26-145a-4ccf-a45d-e4767d29ed3c.png" alt="Cover" width="70%"/>
</div>

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598744-61409da7-f04d-4e95-930b-a4f01b4ef776.png" alt="Cover" width="70%"/>
</div>

**<p align="center">Some sites still work**</p>

On 7th Dec. 2021, there was an airdrop announcement from RTFKT official twitter.
Apparently they are front runed by the scammers.

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/212598893-b383afcd-1841-47d7-9044-0a773de95ba2.png" alt="Cover" width="70%"/>
</div>

### Timeline
So far we have step by step went through how the scammers are combining social engineering, Seaport Protocol and vulnerability of marketplaces/wallet to trick users into signing malicious signatures, let’s list the timeline below:

* 06:50 7th Dec – RTFKT announced airdrop within 1 week in their official Twitter account
    * Malicious group sorted RTFKT holder addresses and frontruned the airdrop in Polygon
    * RTFKT also saw the announcement and lowed their guard
* 20:00 7th Dec – 883 RTFKT holder addresses received the malicious airdrop
* 18:58 8th Dec – the victim saw the airdrop NFT, clicked into the fishing website and signed the Seaport Tx
* 18:59 8th Dec – 137 NFT were stolen 1 min after the victim signed the signature request
* 9th - 11th Dec – stolen NFT were sold in the market

## Summary
Web3 is a dark forest.
Blockchain is natively transparent, malicious groups can easily target the victims based on their assets. Web3 scams are highly contextual and relevant, it is extremely difficult to distinguish the legitimate airdrops from the malicious ones.

However, we are also confident that, with the further growth of the Web3 security ecosystem and increased safety awareness of users, we can improve the status quo and be ready for the next billion users.

Don't trust, Verify! Stay safe!


