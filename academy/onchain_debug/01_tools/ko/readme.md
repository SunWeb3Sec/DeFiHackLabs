# 온체인 트랜잭션 디버깅: 1. 도구

저자: [Sun](https://twitter.com/1nf0s3cpt)  
한국어 번역: [uj](https://twitter.com/uj_uuverse)

커뮤니티 [디스코드](https://discord.gg/Fjyngakf3h)

이 아티클은 XREX와 [WTF 아카데미](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)에 게시되었습니다.

온체인 트랜잭션 분석을 배우기 시작했을 때 온라인 리소스가 부족했습니다. 비록 느리기는 했지만, 테스트와 분석을 수행하기 위해 정보의 조각 조각을 함께 모을 수 있었습니다.

내 연구를 통해 Web3 보안 아티클 시리즈를 시작하여 더 많은 사람들이 Web3 보안에 참여하고 함께 보안 네트워크를 만들도록 유도할 것입니다.

첫 번째 시리즈에서는 온체인 분석을 수행하는 방법을 소개하고 온체인 공격을 재현합니다. 이 기술은 공격 프로세스, 취약성(vulnerability)의 근본 원인, 차익 거래 로봇의 차익 거래 방식을 이해하는 데 도움이 될 것입니다!

## 도구는 효율성을 크게 향상시킨다
분석에 들어가기 전에 일반적으로 사용되는 도구 몇가지를 소개하겠습니다. 올바른 도구를 사용하면 리서치를 보다 효율적으로 수행할 수 있습니다.

### 트랜잭션 디버깅 도구
[Phalcon](https://phalcon.blocksec.com/) | [Tx.viewer](https://tx.eth.samczsun.com/) | [Cruise](https://cruise.supremacy.team/) | [Ethtx](https://ethtx.info/) | [Tenderly](https://dashboard.tenderly.co/explorer)

트랜잭션 뷰어는 가장 일반적으로 사용되는 도구로, function call의 스택 추적 및 각 함수의 입력 데이터를 나열할 수 있습니다. 트랜잭션 뷰어 도구는 모두 비슷합니다. 주요 차이점은 지원하는 체인 및 보조 기능 지원입니다. 저는 개인적으로 Phalcon과 Sam's Transaction Viewer를 사용합니다. 지원되지 않는 체인이 있으면 Tenderly를 사용합니다. Tenderly는 대부분의 체인을 지원하지만 가독성이 제한되고 디버그 기능을 사용하면 분석이 느려질 수 있습니다. 그러나 Ethtx와 함께 배운 첫 번째 도구 중 하나입니다.

#### 도구별 지원하는 체인 비교

Phalcon： `Ethereum、BSC、Avalanche C-Chain、Polygon、Solana、Arbitrum、Fantom、Optimism、Base、Linea、zkSync Era、Kava、Evmos、Merlin、Manta、Mantle、Holesky testnet、Sepolia testnet`

Sam's Transaction viewer： `Ethereum、Polygon、BSC、Avalanche C-Chain、Fantom、Arbitrum、Optimism`

Cruise： `Ethereum、BSC 、Polygon、Arbitrum、Fantom、Optimism、Avalanche、Celo、Gnosis`

Ethtx： `Ethereum、Goerli testnet`

Tenderly： `Ethereum、Polygon、BSC、Sepolia、Goerli、Gnosis、POA、RSK、Avalanche C-Chain、Arbitrum、Optimism
、Fantom、Moonbeam、Moonriver`

#### Lab

JayPeggers - 불충분한 유효성 검증(Insufficient validation) + 재진입(Reentrancy) [사건](https://github.com/SunWeb3Sec/DeFiHackLabs/#20221229---jay---insufficient-validation--reentrancy)을 분석할 트랜잭션 [TXID](https://phalcon.blocksec.com/tx/eth/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6)의 예로 살펴보겠습니다.

먼저 Blocksec에서 개발한 Phalcon 도구를 사용하여 설명합니다. 트랜잭션의 기본 정보(Basic Info) 및 잔액 변화(Balance Changes)를 아래 그림에서 확인할 수 있습니다. Balance Changes에서 공격자가 얼마나 많은 이익을 얻었는지 빠르게 확인할 수 있습니다. 이번 예시에서 공격자는 15.32 ETH의 이익을 얻었습니다.

![210571234-402d96aa-fe5e-4bc4-becc-190bd5a78e68-2](https://user-images.githubusercontent.com/107249780/210686382-cc02cc6a-b8ec-4cb7-ac19-402cd8ff86f6.png)

호출 흐름 시각화(Invocation Flow)는 트레이스 레벨 정보 및 이벤트 로그를 포함하는 function invocation을 보여줍니다. call invocation, 트랜잭션의 function call 레벨 , 플래시 론 사용 여부, 관련된 프로젝트, 호출된 함수, 가져온 매개변수 및 raw 데이터 등을 보여줍니다.

![圖片](https://user-images.githubusercontent.com/52526645/210572053-eafdf62a-7ebe-4caa-a905-045e792add2b.png)

Palcon 2.0은 자금 흐름 시각화(Fund Flow)를 추가하였으며, 디버그 + 소스 코드 분석은 소스 코드, 파라미터, 리턴 값을 트레이스와 함께 직접 보여주어 분석에 더욱 편리합니다.

![image](https://user-images.githubusercontent.com/107249780/210821062-d1da8d1a-9615-4f1f-838d-34f27b9c3f41.png)

이제 동일한 [TXID](https://tx.eth.samczsun.com/ethereum/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6)에서 Sam의 트랜잭션 뷰어를 사용해 보겠습니다. Sam은 아래 그림과 같이 많은 도구를 통합하여 각 콜에서 소비되는 스토리지 및 가스의 변화를 볼 수 있습니다.

![210574290-790f6129-aa82-4152-b3e1-d21820524a0a-2](https://user-images.githubusercontent.com/107249780/210686653-f964a682-d2a7-4b49-bafc-c9a2b0fa2c55.png)

Raw 입력 데이터를 디코딩하려면 왼쪽에서 콜을 클릭합니다.

![圖片](https://user-images.githubusercontent.com/52526645/210575619-89c8e8de-e2f9-4243-9646-0661b9483913.png)

이제 Tenderly로 전환하여 동일한 [TXID](https://dashboard.tenderly.co/tx/mainnet/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6)를 분석하면 다른 도구와 마찬가지로 기본 정보를 볼 수 있습니다. 그러나 디버그 기능을 사용하면 시각화되지 않고 단계별로 분석해야 합니다. 하지만 디버깅 중에 코드와 입력 데이터의 변환 과정을 볼 수 있다는 장점이 있습니다.

![圖片](https://user-images.githubusercontent.com/52526645/210577802-c455545c-80d7-4f35-974a-dadbe59c626e.png)

이것은 우리가 이 거래가 한 모든 일을 명확히 하는 데 도움이 될 수 있습니다. POC를 작성하기 전에 리플레이 어택을 실행할 수 있습니까? 예! Tenderly 또는 Phalcon 모두 시뮬레이션 트랜잭션을 지원하며, 위 그림의 오른쪽 상단 모서리에서 Re-Simulate 버튼을 찾을 수 있습니다. 이 도구는 아래 그림과 같이 트랜잭션의 매개변수 값을 자동으로 채웁니다. 매개변수는 블록 번호 변경, 시작, 가스, 입력 데이터 등과 같은 시뮬레이션 요구에 따라 임의로 변경할 수 있습니다.

![圖片](https://user-images.githubusercontent.com/52526645/210580340-f2abf864-e540-4881-8482-f28030e5e35b.png)

### Ethereum Signature Database

[4byte](https://www.4byte.directory/) | [sig.eth](https://sig.eth.samczsun.com/) | [etherface](https://www.etherface.io/hash)

Raw 입력 데이터에서 처음 4바이트는 함수 서명입니다. 때때로 Etherscan 또는 분석 도구가 기능을 식별할 수 없는 경우 서명 데이터베이스를 통해 가능한 기능을 확인할 수 있습니다.

다음 예제는 `0xac9650d8` 함수가 무엇인지 모른다고 가정합니다.

![image](https://user-images.githubusercontent.com/107249780/211152650-bfe5ca56-971c-4f38-8407-8ca795fd5b73.png)

sig.eth 쿼리를 통해 4바이트 서명이 `multicall(bytes[])`임을 알 수 있습니다

![圖片](https://user-images.githubusercontent.com/52526645/210583416-c31bbe07-fa03-4701-880d-0ae485b171f7.png)

### 유용한 도구

[ABI to interface](https://gnidan.github.io/abi-to-sol/) | [Get ABI for unverified contracts](https://abi.w1nt3r.xyz/) | [ETH Calldata Decoder](https://apoorvlathey.com/eth-calldata-decoder/) | [ETHCMD - Guess ABI](https://www.ethcmd.com/)

인터페이스에 대한 ABI: POC를 개발할 때 다른 계약을 호출하기 위한 인터페이스가 필요합니다. 이 도구를 사용하여 인터페이스를 빠르게 생성할 수 있습니다. Etherscan으로 이동하여 ABI를 복사하고 도구에 붙여넣으면 생성된 인터페이스를 볼 수 있습니다. [Example](https://etherscan.io/address/0xb3da8d6da3ede239ccbf576ca0eaa74d86f0e9d3#code).

![圖片](https://user-images.githubusercontent.com/52526645/210587442-e7853d8b-0613-426e-8a27-d70c80e2a42d.png)
![圖片](https://user-images.githubusercontent.com/52526645/210587682-5fb07a01-2b21-41fa-9ed5-e7f45baa0b3e.png)

ETH Calldata Decoder: ABI 없이 입력 데이터를 디코딩하려는 경우 필요한 도구입니다. 앞서 소개한 Sam의 트랜잭션 뷰어도 입력 데이터 디코딩을 지원합니다.

![圖片](https://user-images.githubusercontent.com/52526645/210585761-efd8b6f1-b901-485f-ae66-efaf9c84869c.png)

확인되지 않은 계약에 대한 ABI 얻기: 확인되지 않은 계약이 발생하면 이 도구를 사용하여 함수 서명을 해결할 수 있습니다. [Example](https://abi.w1nt3r.xyz/mainnet/0xaE9C73fd0Fd237c1c6f66FE009d24ce969e98704)

![圖片](https://user-images.githubusercontent.com/52526645/210588945-701b0e22-7390-4539-9d2f-e13479b52824.png)

### 디컴파일 도구
[Etherscan-decompile bytecode](https://etherscan.io/address/0xaE9C73fd0Fd237c1c6f66FE009d24ce969e98704#code) | [Dedaub](https://library.dedaub.com/decompile) | [heimdall-rs](https://github.com/Jon-Becker/heimdall-rs)

Etherscan에는 디컴파일 기능이 내장되어 있지만 결과의 가독성이 떨어지는 경우가 많습니다. 개인적으로 더 나은 디컴파일된 코드를 생성하는 Dedaub를 자주 사용합니다. 제가 추천하는 디컴파일러입니다. 공격을 받는 MEV Bot을 예로 들어 보겠습니다. 이것을 사용하여 직접 디컴파일할 수 있습니다.
[contract](https://twitter.com/1nf0s3cpt/status/1577594615104172033).

먼저 미확인 컨트랙트의 Bytecodes를 복사하여 Dedaub에 붙여넣고 Decompile을 클릭합니다.

![截圖 2023-01-05 上午10 33 15](https://user-images.githubusercontent.com/107249780/210688395-927c6126-b6c1-4c6d-a0c7-a3fea3db9cdb.png)

![圖片](https://user-images.githubusercontent.com/52526645/210591478-6fa928f3-455d-42b5-a1ac-6694f97386c2.png)

더 자세히 알고 싶다면 다음 비디오를 참조하십시오.

## Resources
[samczsun's eth txn explorer and vscode extension](https://www.youtube.com/watch?v=HXgu239mPBc)

[Vulnerabilities in DeFi by Daniel V.F.](https://www.youtube.com/watch?v=9fcOffCg2ig)

[Tenderly.co - Debug Transaction](https://www.youtube.com/watch?v=90GN9Ut8LhU)

[Reversing The EVM: Raw Calldata](https://degatchi.com/articles/reading-raw-evm-calldata)

https://web3sec.xrex.io/

