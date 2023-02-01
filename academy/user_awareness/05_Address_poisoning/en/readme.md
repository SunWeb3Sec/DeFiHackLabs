# Lesson 5: Address poisoning scam

Author: [SlowMist](https://twitter.com/SlowMist_Team)

Recently, several users reported that their assets had been stolen. At first, they were unsure how their funds had been stolen, but upon closer inspection, we discovered that this was a new type of airdrop scam.

Many of the victims’ addresses were constantly airdropped with tiny amounts of tokens (0.01 USDT, 0.001 USDT, etc.), and they were most likely targeted because their addresses were involved in high-value transactions and trade volume. The last few digits of the attacker’s address are nearly identical to the last few digits of the user’s address. This is done to deceive the user into accidentally copying the wrong address from the transaction history and sending the funds to the incorrect address.

<div align=center>
<img src="https://miro.medium.com/max/700/1*9jTHmgC086JmnEEgwhaLTQ.png" alt="Cover" width="60%"/>
</div>
<p align="center">(Image from https://twitter.com/TokenPocket_TP)</p>

**Related Information**

Attacker Address 1: TX…dWfKz  
User address 1: TW…dWfKz  
Attacker address 2: TK…Qw5oH  
User address 2: TW…Qw5oH

**MistTrack Analysis**

Let’s start with an overview of the two attacker addresses:

<div align=center>
<img src="https://miro.medium.com/max/700/1*ppNv7g_k1Xvt0TQTB_luyg.png" alt="Cover" width="80%"/>
</div>

The attacker’s address (TX…..dWfKz) and the user’s address (TW…..dWfKz) both end in dWfKz. Even after the user mistakenly sent 115,193 USDT to the wrong address, the attacker still airdrops 0.01 USDT and 0.001 USDT to the victim address using two new addresses that also end in dWfKz.

<div align=center>
<img src="https://miro.medium.com/max/700/1*Qq2mL2WeEobbIgXfNCBQLw.png" alt="Cover" width="80%"/>
</div>
    
The same thing happened to our second victim. The attacker’s address (TK…. .Qw5oH) and the user’s address ( (TW…. .Qw5oH) both end in Qw5oH. The victim mistakenly sent 345,940 USDT to the wrong address, and the attacker continues to airdrop 0.01 USDT to the victim address using a new addresses that also end in Qw5oH.

<div align=center>
<img src="https://miro.medium.com/max/700/1*0SDtcCXO6ACupCsNcnMTuw.png" alt="Cover" width="80%"/>
</div>


<div align=center>
<img src="https://miro.medium.com/max/700/1*g6LPcUbeRRU_YzrLKha9lw.png" alt="Cover" width="80%"/>
</div>

Next, we’ll examine attacker address 1 using our AML platform [MistTrack](https://dashboard.misttrack.io/) (tx.. .dWfKz). As shown in the figure below, attacker address 1 airdrops 0.01 USDT and 0.02 USDT to various target addresses, all of which have interacted with the address that ends in dWfKz.

<div align=center>
<img src="https://miro.medium.com/max/600/1*3hTDwB_YqJrMim7DO2sYtQ.png" alt="Cover" width="80%"/>
</div>

Looking back, we can see the initial transfers for these airdrops came from the address TF…. J5Jo8 on October 10, when 0.5 USDT was transferred to it.

<div align=center>
<img src="https://miro.medium.com/max/700/1*T-i34u5j9Qc-RYekfpwr5w.png" alt="Cover" width="80%"/>
</div>

Preliminary analysis of TF… .J5Jo8:

<div align=center>
<img src="https://miro.medium.com/max/700/1*sdurmkYOi5fq3CvlLGW8Gw.png" alt="Cover" width="80%"/>
</div>

This address sent 0.5 USDT to nearly 3300 addresses, indicating that each of these receiving addresses could be an address used by the attacker to airdrop. So we decided to select one address at random to verify our theory.

MistTrack was used to analyze the last address on the above chart, TX…..4yBmC. As shown in the figure below, the address TX….4yBmC is used by the attacker to airdrop 0.01 USDT to multiple addresses that end in 4yBmC.

<div align=center>
<img src="https://miro.medium.com/max/700/1*0FqpB9-EkUZ3qwr70c0Iqw.png" alt="Cover" width="80%"/>
</div>

Let’s look at the attacker’s address 2 (TK…. .Qw5oH): 0.01 USDT was airdropped to multiple addresses, and the initial funding of 0.6 USDT was sent from TD…. .psxmk.

<div align=center>
<img src="https://miro.medium.com/max/700/1*HEduXw9NiiRDpnwmtRH5Zw.png" alt="Cover" width="80%"/>
</div>

As you can see from the graph below, the attacker sent 0.06 USDT to TD…. .kXbFq and it also interacted with a FTX user’s deposit address that ends in Qw5oH.

<div align=center>
<img src="https://miro.medium.com/max/700/1*-xmQghtaYkiC3yADAWEkNA.png" alt="Cover" width="80%"/>
</div>

So let’s reverse the process and see if other addresses have interacted with TD… .kXbFq. Are there any other addresses with the same ending characters as the ones that were airdropped to them?

Once again, we’ll choose two addresses at random and test our theory. (for example, the Kraken deposit address TU… .hhcWoT and Binance deposit address TM…. .QM7me).

<div align=center>
<img src="https://miro.medium.com/max/700/1*QtgDWNmo0HRf3N2S6k8QKA.png" alt="Cover" width="80%"/>
</div>



<div align=center>
<img src="https://miro.medium.com/max/700/1*3LZYzgnVN2tEh5OyMl9E7A.png" alt="Cover" width="80%"/>
</div>

Unfortunately, the scammer was able to deceive some unsuspecting user into sending them their funds.

**Summary**

This article focuses on how a scammer exploits users who copy the address from the transaction history without verifying the entire address. They accomplish this by generating a similar address that ends in the same way as the user’s address and airdropping small amounts of funds to the user’s address on a regular basis. All of this is done in the hope that users will copy the fake address and send their funds to the scammer the next time.

SlowMist would like to remind everyone that due to the immutability of blockchain technology and the irreversibility of on-chain operations, please double check the address before proceeding. Users are also encouraged to use the address book feature in their wallet so that they don’t need to copy and address each time.
