# 온체인 트랜잭션 디버깅: 2. 워밍업

저자: [Sun](https://twitter.com/1nf0s3cpt)

한국어 번역: [uj](https://twitter.com/uj_uuverse)

커뮤니티 [디스코드](https://discord.gg/Fjyngakf3h)

이 기사는 XREX 및 [WTF 아카데미](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)에 게시됩니다.

온체인 데이터에는 간단한 일회성 전송, 하나의 DeFi 컨트랙트 또는 여러 DeFi 컨트랙트와의 상호 작용, 플래시론 차익 거래, 거버넌스 제안, 크로스체인 거래 등이 포함될 수 있습니다. 이 섹션에서는 간단한 것부터 시작하겠습니다. 블록체인 탐색기인 Etherscan에서 우리가 관심 있는 것을 소개하고 Phalcon을 사용하여 이러한 트랜잭션 함수 호출 간의 차이점을 비교할 것입니다: 자산 전송, 유니스왑을 통한 Swap, 커브 3pool의 유동성 추가, 컴파운드 제안, 유니스왑의 FlashSwap.


## 워밍업 시작

- 첫 번째 단계는 [Foundry](https://github.com/foundry-rs/foundry)를 설치하는 것입니다. 설치 [지침](https://book.getfoundry.sh/getting-started/installation)을 따르십시오.
  - Forge는 Foundry 플랫폼의 주요 테스트 도구 입니다. Foundry를 처음 사용하는 경우, [Foundry book](https://book.getfoundry.sh/), [Foundry @EthCC](https://www.youtube.com/watch?v=wJnywGB33O4), [WTF Solidity - Foundry](https://github.com/AmazingAng/WTF-Solidity/blob/main/Topics/Tools/TOOL07_Foundry/readme.md)를 참조할 수 있습니다.
- 각 체인에는 자체 블록체인 탐색기가 있습니다. 이 섹션에서는 이더리움의 블록체인 네트워크를 케이스 스터디로 사용합니다.
- 내가 일반적으로 참조하는 정보는 다음과 같습니다.
  - Transaction Action: 복잡한 ERC-20 토큰의 전송은 식별하기 어려울 수 있으므로 트랜잭션 액션은 전송의 핵심 동작을 제공할 수 있습니다. 그러나 모든 거래에 이 정보가 포함되는 것은 아닙니다.
  - From: msg.sender, 이 트랜잭션을 실행하는 소스 지갑 주소
  - Interacted With (To): 상호 작용할 계약
  - ERC-20 Token Transfer: 토큰 전송 프로세스
  - Input Data: 트랜잭션의 raw 입력 데이터 입니다. 어떤 Function이 호출되었고 어떤 Value가 들어왔는지 알 수 있습니다.
- 일반적으로 어떤 도구를 사용하는지 잘 모르겠다면 [첫 번째 강의](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/en)에서 트랜잭션 분석 도구를 볼 수 있습니다.

## 자산 전송

![圖片](https://user-images.githubusercontent.com/52526645/211021954-6c5828be-7293-452b-8ef6-a268db54b932.png)
위의 [이더스캔](https://etherscan.io/tx/0x836ef3d01a52c4b9304c3d683f6ff2b296c7331b6fee86e3b116732ce1d5d124) 예제에서 다음을 도출할 수 있습니다.

- From: 이 트랜잭션의 소스 EOA 지갑 주소
- Interacted With (To): Tether USD (USDT) 계약
- ERC-20 Tokens Transferred: 사용자 A의 지갑에서 사용자 B로 651.13 USDT 전송
- Input Data: transfer 함수를 호출함

[Phalcon](https://phalcon.blocksec.com/tx/eth/0x836ef3d01a52c4b9304c3d683f6ff2b296c7331b6fee86e3b116732ce1d5d124)의 "Invocation Flow"에 따르면 :

- 'Call USDT.transfer'는 하나입니다. 그러나 "Value"에 주의해야 합니다. 이더리움 가상머신(EVM)은 부동 소수점(floating-point) 연산을 지원하지 않기 때문에 10진수로 소수점 자릿수를 표현하는 decimal이 대신 사용됩니다.
- 각 토큰에는 토큰 값을 나타내는 데 사용되는 소수점 자릿수인 자체 정밀도가 있습니다. ERC-20 토큰의 decimal은 일반적으로 18자리인 반면 USDT는 6자리입니다. 토큰의 정밀도가 제대로 처리되지 않으면 문제가 발생합니다.
- 이더스캔 [token contract](https://etherscan.io/token/0xdac17f958d2ee523a2206206994597c13d831ec7)에서 쿼리할 수 있습니다.

![圖片](https://user-images.githubusercontent.com/52526645/211123692-d7224ced-bc0b-47a1-a876-2af086e2fce9.png)

![圖片](https://user-images.githubusercontent.com/52526645/211022964-f819b35c-d442-488c-9645-7733af219d1c.png)

## 유니스왑 Swap

![圖片](https://user-images.githubusercontent.com/52526645/211029091-c24963c7-d2f8-44f4-ad6a-a9185f98ec85.png)

위의 [이더스캔](https://etherscan.io/tx/0x1cd5ceda7e2b2d8c66f8c5657f27ef6f35f9e557c8d1532aa88665a37130da84) 예제에서 다음을 도출할 수 있습니다.

- Transaction Action: 사용자가 유니스왑 V2에서 스왑을 수행하여 12,716 USDT를 7,118 UNDEAD로 교환
- From: 이 트랜잭션의 소스 지갑 주소
- Interacted With (To): MEV 봇이 스왑을 위한 유니스왑 컨트랙트를 호출함
- ERC-20 Tokens Transferred: 토큰 교환 프로세스

[Phalcon](https://phalcon.blocksec.com/tx/eth/0x1cd5ceda7e2b2d8c66f8c5657f27ef6f35f9e557c8d1532aa88665a37130da84)의 "Invocation Flow"에 따르면:

- MEV Bot은 유니스왑 V2 USDT/UNDEAD 거래 페어 컨트랙트를 호출하여 스왑 기능을 호출하여 토큰 교환을 수행합니다.

![圖片](https://user-images.githubusercontent.com/52526645/211029737-4a606d32-2c96-41e9-aef7-82fe1fb4b21d.png)

### Foundry

Foundry를 사용하여 1BTC를 사용하여 Uniswap에서 DAI로 교환하는 작업을 시뮬레이션합니다.

- [샘플 코드](https://github.com/SunWeb3Sec/DeFiLabs/blob/main/src/test/Uniswapv2.sol)를 참조하여, 다음 명령을 실행합니다.
```sh
forge test --contracts ./src/test/Uniswapv2.sol -vvvv
```
- Uniswap\_v2\_router.[swapExactTokensForTokens](https://docs.uniswap.org/contracts/v2/reference/smart-contracts/router-02#swapexacttokensfortokens) 함수를 호출하여 1 BTC를 16,788 DAI로 교환합니다.

![圖片](https://user-images.githubusercontent.com/52526645/211143644-6ed295f0-e0d8-458b-a6a7-71b2da8a5baa.png)

## 커브 3pool - DAI/USDC/USDT 유동성 추가

![圖片](https://user-images.githubusercontent.com/52526645/211030934-14fccba9-5239-480c-b431-21de393a6308.png)

위의 [이더스캔](https://etherscan.io/tx/0x667cb82d993657f2779507a0262c9ed9098f5a387e8ec754b99f6e1d61d92d0b) 예제에서 다음을 도출할 수 있습니다.

- 이 거래의 목적은 커브 3pool에 유동성을 추가하는 것
- From: 이 트랜잭션의 소스 지갑 주소
- Interacted With (To): Curve.fi: DAI/USDC/USDT 풀
- ERC-20 Tokens Transferred: A가 3,524,968.44 USDT를 커브 3pool로 전송한 다음 커브가 사용자 A를 위해 3,447,897.54 3Crv 토큰을 발행함

[Phalcon](https://phalcon.blocksec.com/tx/eth/0x667cb82d993657f2779507a0262c9ed9098f5a387e8ec754b99f6e1d61d92d0b)의 "Invocation Flow"에 따르면 :

- 호출 순서에 따라 다음 세 단계가 실행 되었습니다
1.add\_liquidity 2.transferFrom 3.mint.

![圖片](https://user-images.githubusercontent.com/52526645/211032540-b8ad83af-44cf-48ea-b22c-6c79d4dac1af.png)


## 컴파운드 제안

![圖片](https://user-images.githubusercontent.com/52526645/211033609-60713c9d-1760-45d4-957f-a74e08abf9a5.png)

위의 [이더스캔](https://etherscan.io/tx/0xba69b455c511c500e0be9453cf70319bc61e29eb4235a6e5ca5fe6ddf1934159) 예제에서 다음을 도출할 수 있습니다.

- 사용자가 컴파운드에 대한 제안서를 제출했습니다. 제안 내용은 이더스캔에서 "Decode Input Data"를 클릭하면 볼 수 있습니다.

![圖片](https://user-images.githubusercontent.com/52526645/211033906-e3446f69-404e-4347-a0c6-e1b622039c5a.png)

[Phalcon](https://phalcon.blocksec.com/tx/eth/0xba69b455c511c500e0be9453cf70319bc61e29eb4235a6e5ca5fe6ddf1934159)의 "Invocation Flow"에 따르면 :

- Propose 함수를 통해 제안을 제출하여 제안 번호 44가 생성되었습니다.

![圖片](https://user-images.githubusercontent.com/52526645/211034346-a600cbf4-eed9-47ca-8b5a-88232808f3a3.png)

## 유니스왑의 FlashSwap

여기에서는 Foundry를 사용하여 작업을 시뮬레이션합니다. 유니스왑에서 플래시론을 사용하는 방법입니다. [Official Flash swap introduction](https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps)

- [샘플 코드](https://github.com/SunWeb3Sec/DeFiLabs/blob/main/src/test/Uniswapv2_flashswap.sol)를 참조하여, 다음 명령을 실행합니다.

```sh
forge test --contracts ./src/test/Uniswapv2_flashswap.sol -vvvv
```

![圖片](https://user-images.githubusercontent.com/52526645/211125357-695c3fd0-4a56-4a70-9c98-80bac65586b8.png)

- 이 예시에서는 유니스왑 UNI/WETH 교환을 통해 100 WETH의 플래시론을 빌립니다. 상환 시 0.3%의 수수료를 지불해야 합니다.
- 아래 호출 흐름에 따르면, flashswap은 swap을 호출한 다음 uniswapV2Call을 다시 호출하여 상환합니다.

![圖片](https://user-images.githubusercontent.com/52526645/211038895-a1bc681a-41cd-4900-a745-3d3ddd0237d4.png)

- Flashloan과 Flashswap에 대한 추가 설명:

  - A. 공통점:
둘 다 자산을 담보하지 않고 토큰을 빌려줄 수 있으며 동일한 블록에서 반환되어야 합니다. 그렇지 않으면 거래가 실패합니다.

  - B. 차이점:
Flashloan token0/token1을 통해 token0을 빌린 경우 token0을 반환해야 합니다. Flashswap은 token0을 빌려주고 token0 또는 token1을 반환할 수 있어 더 유연합니다.

DeFi 기본 동작에 대한 자세한 내용은, [DeFiLab](https://github.com/SunWeb3Sec/DeFiLabs)을 참조하십시오.

## Foundry cheatcodes

Foundry의 치트코드는 체인 분석을 수행하는 데 필수적입니다. 여기서는 일반적으로 사용되는 몇 가지 기능을 소개합니다. 더 많은 정보는 [Cheatcodes Reference](https://book.getfoundry.sh/cheatcodes/)에서 찾을 수 있습니다.

- createSelectFork: 테스트를 위해 복사할 네트워크 및 블록 높이를 지정합니다. [foundry.toml](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/foundry.toml)에 각 체인에 대한 RPC를 포함해야 합니다.
- deal: 테스트 지갑의 잔액을 설정합니다.
  - ETH 잔액 설정:  `deal(address(this), 3 ether);`
  - 토큰 잔액 설정: `deal(address(USDC), address(this), 1 * 1e18);`
- prank: 시뮬레이션할 지갑을 설정합니다.(고래 지갑에서의 전송을 시뮬레이션 하는 등) 다음 호출의 msg.sender를 지정한 지갑 주소로 설정합니다.(다음호출에만 유효함)
- startPrank: 시뮬레이션할 지갑을 설정합니다. `stopPrank()`가 실행될 때까지 모든 호출에 대한 msg.sender를 지정한 지갑 주소로 설정합니다.
- label: Foundry 디버그를 사용할 때 가독성을 높이기 위해 지갑 주소에 레이블을 지정합니다.
- roll: 블록 높이를 조정합니다.
- warp: 블록 타임스탬프를 조정합니다.

따라와 주셔서 감사합니다! 다음 강의로 넘어갈 시간입니다.

## Resources

[Foundry book](https://book.getfoundry.sh/)

[Awesome-foundry](https://github.com/crisgarner/awesome-foundry)

[Flashloan vs Flashswap](https://blog.infura.io/post/build-a-flash-loan-arbitrage-bot-on-infura-part-i)
