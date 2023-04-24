# OnChain Transaction Debugging: 4. Write your own POC - MEV Bot

저자: [Sun](https://twitter.com/1nf0s3cpt)

한국어 번역: [0xDanielH](https://twitter.com/holyhansss)

커뮤니티 [디스코드](https://discord.gg/Fjyngakf3h)

이 글은 XREX와 [WTF 아카데미](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)에 게재되었습니다.

## 단계별 PoC 작성 - MEV Bot(BNB48)을 예시로 사용

- 요약
    - 2022년 09월 13일에 MEV Bot이 공격자에 의해 익스플로잇되어 컨트랙트의 모든 자산이 전송되었으며, 총 손실액은 약 14만 달러에 달했습니다.
    - 공격자는 Flashbot이 Front-running을 피하기 위해 트랜잭션을 퍼블릭 멤풀에 넣지 않는 것과 유사하게 BNB48 검증자 노드를 통해 프라이빗 트랜잭션을 보냈습니다.
- 분석
    - 공격자의 [TXID](https://bscscan.com/tx/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2)를 확인해보니, MEV 봇 컨트랙트가 오픈소스가 아닌 공개되지 않은(unverify) 컨트랙트임을 알 수 있습니다.
    - [phalcon](https://phalcon.blocksec.com/tx/bsc/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2)을 사용하여 확인해보니，이 트랜잭션 내에서 MEV 봇은 6가지의 자산을 공격자의 지갑으로 전송했습니다. 공격자는 어떻게 이를 악용했을까요?
![圖片](https://user-images.githubusercontent.com/52526645/211201079-e7c5cc3b-64f8-4146-ab0e-7dd46b535cc9.png)
    - 함수 호출의 과정을 살펴보면, `pancakeCall` 함수가 정확히 6번 호출된 것을 확인할 수 있습니다.
        - From: `0xee286554f8b315f0560a15b6f085ddad616d0601`
        - Attacker's contract: `0x5cb11ce550a2e6c24ebfc8df86c5757b596e69c1`
        - MEV Bot contract: `0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d`
 ![圖片](https://user-images.githubusercontent.com/52526645/211201456-8b6f7bca-677d-40a2-b81b-fd6af18f94fd.png)
    - 'pancakeCall' 중 하나를 자세히보면 공격자의 컨트랙트에 대한 콜백이 `token0()`의 값을 BSC-USD에서 읽은 후 공격자의 지갑으로 BSC-USD를 전송하는 것을 볼 수 있습니다. 공격자가 MEV Bot 컨트랙트의 모든 자산을 이동시킬 수 있는 권한을 가지고 있고, 이를 취약점에 사용할 수 있습니다. 다음 단계는 공격자가 이 자금을 어떻게 사용하는지 알아보는 것입니다.
    ![圖片](https://user-images.githubusercontent.com/52526645/211201744-9895803a-5f72-4f14-b147-b67b204bee75.png)
    - 앞서 MEV Bot 컨트랙트가 오픈소스가 아니기 때문에 여기서는 [Lesson 1](https://bscscan.com/address/0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d#code)에서 소개한 디컴파일러 도구인 [Dedaub](https://library.dedaub.com/decompile)를 사용하여 분석해 볼 것입니다. 먼저 [Bscscan](https://bscscan.com/address/0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d#code)에서 컨트랙트의 바이트코드를 복사하여 Dedaub에 붙여넣어 디컴파일을 해보면 아래 그림과 같이 `pancakeCall` 함수의 권한이 public으로 설정되어 누구나 호출할 수 있는 것을 확인할 수 있습니다. 이는 flash loan의 콜백에 사용되기 때문에 큰 문제가 되지 않습니다. `pancakeCall` 마지막에 실행되는 `0x10a` 함수(빨간색 테두리 부분)의 로직을 살펴보도록 하겠습니다.
    ![圖片](https://user-images.githubusercontent.com/52526645/211202573-b4a4847d-a617-42c8-84d0-0f2dbd38a632.png)
    
   - `0x10a` 함수의 로직은 아래 그림과 같습니다. 빨간색 테두리가 있는 부분이 핵심입니다. 먼저 공격자의 컨트랙트에서 token0()가 어떤 token인지 읽습니다. 이후 이를 `transfer`함수를 사용해 자금을 이동시킵니다. 이 `0x10a` 함수에서 첫 번째 매개변수 수신자 주소인 `address(MEM[varg0.data])`가 `pancakeCall()`의 `varg3 (_data)`에 포함되어 있으므로 핵심 취약점이 여기 위치하고 있다는 것을 알 수 있습니다.

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211204177-fbebe377-23b0-4b0c-bb3e-dcb64dba2afc.png" alt="Cover" width="80%"/>
</div>

   - `pancakeCall()`을 호출하는 공격자의 payload를 다시 살펴보면, `_data`에 입력된 값의 첫 32 bytes는 receiver의 지갑 주소입니다.

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211453390-502db65b-cf82-4805-a463-04fc5c7e0dce.png" alt="Cover" width="80%"/>
</div>

- Writing POC
   - 위의 공격 과정을 분석해 본 결과, 취약점의 핵심 로직은 MEV Bot 컨트랙트의 `pancakeCall`을 호출하는 것입니다. PoC의 포인트는 `_data`로 receiver의 지갑 주소를 지정하고, MEV Bot 컨트랙트 로직을 만족하기 위해 컨트랙트에 `token0()`, `token1()` 함수가 있어야 합니다. 한번 PoC를 직접 작성해보세요!
    - Answer: [POC](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/src/test/BNB48MEVBot_exp.sol).
    
<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211204852-4fa65835-17f7-4c91-80ab-79f5b46125df.png" alt="Cover" width="80%"/>
</div>

## Extended learning
- Foundry trace
    - 트랜잭션의 함수 추적은 다음과 같이 Foundry를 사용하여 나열할 수도 있습니다:
    `cast run 0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2 --quick --rpc-url https://rpc.ankr.com/bsc`

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211562868-12fde773-948c-47a9-acaf-6f744438925e.png" alt="Cover" width="80%"/>
</div>

- Foundry debug
    - 다음과 같이 Foundry를 사용하여 트랜잭션을 디버깅할 수도 있습니다:

    `cast run 0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2 --quick --debug  --rpc-url https://rpc.ankr.com/bsc`

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211565713-fdf3784f-da54-42e8-ad60-591ecac38c15.png" alt="Cover" width="80%"/>
</div>

## Resources

[Flashbots: Kings of The Mempool](https://noxx.substack.com/p/flashbots-kings-of-the-mempool?utm_source=profile&utm_medium=reader2)

[MEV Markets Part 1: Proof of Work](https://mirror.xyz/0xshittrader.eth/WiV8DM3I6abNMVsXf-DqioYb2NglnfjmM-zSsw2ruG8)

[MEV Markets Part 2: Proof of Stake](https://mirror.xyz/0xshittrader.eth/c6J_PCK87K3joTWmLEtG6qVN6BFXLBZxQniReYSEjLI)

[MEV Markets Part 3: Payment for Order Flow](https://mirror.xyz/0xshittrader.eth/f2VSuoZ91vAbCv82MtWM-Gosyf_DeUXfPlDx3EYV3RM)
