# Debugging/Análisis OnChain de Transacciones: 2. Calentamiento

Autor: [Sun](https://twitter.com/1nf0s3cpt)

Traducción: [JP](https://x.com/CanonicalJP)

Comunidad [Discord](https://discord.gg/Fjyngakf3h)

Este artículo ha sido publicado en XREX y [WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)

Los datos on-chain pueden incluir transferencias simples de una interacción, interacciones con uno o múltiples contratos DeFi, arbitraje de préstamos flash, propuestas de gobernanza, transacciones entre cadenas y más. En esta sección, comencemos con un inicio simple.
Introduciré en el Explorador de BlockChain - Etherscan lo que nos interesa, y luego usaré [Phalcon](https://phalcon.blocksec.com/) para comparar las diferencias entre estas transacciones que llaman funciones: Transferencia de activos, swap en UniSWAP, aumento de liquidez en Curve 3pool, propuestas de Compound, Uniswap Flash Swap.

## Comencemos el calentamiento

- El primer paso es instalar [Foundry](https://github.com/foundry-rs/foundry) en el entorno. Por favor, sigue las [instrucciones](https://book.getfoundry.sh/getting-started/installation) de instalación.
  - Forge es la utilidad principal para realizar tests en la plataforma Foundry. Si es tu primera vez usando Foundry, puedes consultar el [Foundry Book](https://book.getfoundry.sh/), [Foundry @EthCC](https://www.youtube.com/watch?v=wJnywGB33O4), [WTF Solidity - Foundry](https://github.com/AmazingAng/WTF-Solidity/blob/main/Topics/Tools/TOOL07_Foundry/readme.md).
- Cada blockchain tiene su propio explorador de blockchain. En esta sección, usaremos la red blockchain de Ethereum como caso de estudio.
- La información típica a la que suelo referirme incluye:
  - Transaction Action: Dado que la transferencia de tokens ERC-20 complejos puede ser difícil de discernir, el Transaction Action puede proporcionar el comportamiento clave de la transferencia. Sin embargo, no todas las transacciones incluyen esta información.
  - From: msg.sender, la dirección de la cartera de origen que ejecuta esta transacción.
  - Interacted With (To): Con qué contrato interactuar
  - ERC-20 Token Transfer: Proceso de Transferencia de Token
  - Input Data: Los datos de entrada sin procesar de la transacción. Puedes ver qué Función fue llamada y qué Valor se introdujo.
- Si no sabes qué herramientas se usan comúnmente, puedes ver las herramientas de análisis de transacciones en [la primera lección](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools/es).

## Transferencia de activos

![圖片](https://user-images.githubusercontent.com/52526645/211021954-6c5828be-7293-452b-8ef6-a268db54b932.png)
De el ejemplo anterior en [Etherscan](https://etherscan.io/tx/0x836ef3d01a52c4b9304c3d683f6ff2b296c7331b6fee86e3b116732ce1d5d124) se puede derivar lo siguiente:

- From: La dirección de la cartera EOA de origen de esta transacción
- Interacted With (To): Contrato de Tether USD (USDT)
- ERC-20 Token Transfer: Transferencia de 651.13 USDT de la cartera del usuario A a la del usuario B
- Input Data: Función de transferencia llamada

Según el "Invocation Flow" de [Phalcon](https://phalcon.blocksec.com/tx/eth/0x836ef3d01a52c4b9304c3d683f6ff2b296c7331b6fee86e3b116732ce1d5d124):

- Solo hay un "Call USDT.transfer". Sin embargo, debes prestar atención al "Value". Debido a que la Máquina Virtual de Ethereum (EVM) no admite operaciones de punto flotante, se utiliza la representación decimal en su lugar.
- Cada token tiene su propia precisión, el número de decimales utilizados para representar el valor del token. En los tokens ERC-20, los decimales suelen ser 18 dígitos, mientras que USDT tiene 6 dígitos. Si la precisión del token no se maneja adecuadamente, surgirán problemas.
- Puedes consultarlo en el [contrato del token](https://etherscan.io/token/0xdac17f958d2ee523a2206206994597c13d831ec7) de Etherscan.

![圖片](https://user-images.githubusercontent.com/52526645/211123692-d7224ced-bc0b-47a1-a876-2af086e2fce9.png)

![圖片](https://user-images.githubusercontent.com/52526645/211022964-f819b35c-d442-488c-9645-7733af219d1c.png)

## Swap en Uniswap

![圖片](https://user-images.githubusercontent.com/52526645/211029091-c24963c7-d2f8-44f4-ad6a-a9185f98ec85.png)

De el ejemplo anterior en [Etherscan](https://etherscan.io/tx/0x1cd5ceda7e2b2d8c66f8c5657f27ef6f35f9e557c8d1532aa88665a37130da84) se puede derivar lo siguiente:

- Transaction Action: Un usuario realiza un Swap en Uniswap V2, intercambiando 12,716 USDT por 7,118 UNDEAD.
- From: La dirección de la cartera de origen de esta transacción
- Interacted With (To): Un contrato de Bot MEV llamó al contrato de Uniswap para Swap.
- ERC-20 Token Transfer: Proceso de swap de tokens

Según el "Invocation Flow" de [Phalcon](https://phalcon.blocksec.com/tx/eth/0x1cd5ceda7e2b2d8c66f8c5657f27ef6f35f9e557c8d1532aa88665a37130da84):

- El Bot MEV llama al contrato del par de trading USDT/UNDEAD de Uniswap V2 para llamar a la función swap para realizar el swap de tokens.

![圖片](https://user-images.githubusercontent.com/52526645/211029737-4a606d32-2c96-41e9-aef7-82fe1fb4b21d.png)

### Foundry

Usamos Foundry para simular la operación de usar 1BTC para intercambiar por DAI en Uniswap.

- [Código de ejemplo de referencia](https://github.com/SunWeb3Sec/DeFiLabs/blob/main/src/test/Uniswapv2.sol), ejecuta el siguiente comando:

```sh
forge test --contracts ./src/test/Uniswapv2_flashswap.sol -vvvv
```

![圖片](https://user-images.githubusercontent.com/52526645/211125357-695c3fd0-4a56-4a70-9c98-80bac65586b8.png)

- En este ejemplo, se realiza un préstamo flashloan de 100 WETH a través del swap UNI/WETH de Uniswap. Ten en cuenta que se debe pagar una comisión del 0.3% en los reembolsos.
- Según la figura - flujo de llamadas, flash swap llama a swap, y luego reembolsa llamando de vuelta a uniswapV2Call.

![圖片](https://user-images.githubusercontent.com/52526645/211038895-a1bc681a-41cd-4900-a745-3d3ddd0237d4.png)

- Introducción adicional a Flash Loan y Flash Swap:

  - A. Puntos en común:
Ambos pueden prestar Tokens sin colateralizar activos, y deben ser devueltos en el mismo bloque, de lo contrario la transacción falla.

  - B. La diferencia:
Si se toma prestado token0 a través de Flashloan token0/token1, se debe devolver token0. Flash Swap presta token0, y puedes devolver token0 o token1, lo que es más flexible.

Para más operaciones básicas de DeFi, consulta [DeFiLab](https://github.com/SunWeb3Sec/DeFiLabs).

## Foundry cheatcodes

Los cheatcodes de Foundry son esenciales para realizar análisis de blockchain. Aquí, introduciré algunas funciones comúnmente utilizadas. Puedes encontrar más información en la [Cheatcodes Reference](https://book.getfoundry.sh/cheatcodes/).

- createSelectFork: Especifica una red y altura de bloque para copiar para pruebas. Debe incluir el RPC para cada blockchain en [foundry.toml](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/foundry.toml).
- deal: Establece el saldo de una cartera de prueba.
  - Establecer saldo de ETH:  `deal(address(this), 3 ether);`
  - Establecer saldo de Token: `deal(address(USDC), address(this), 1 * 1e18);`
- prank: Especifica la dirección de la cartera a simular. Solo es efectivo para la siguiente llamada y establecerá el msg.sender a la dirección de cartera especificada. Como simular una transferencia desde una cartera whale.
- startPrank: Especifica la dirección de la cartera a simular. Establecerá el msg.sender a la dirección de cartera especificada para todas las llamadas hasta que se ejecute `stopPrank()`.
- label: Etiqueta una dirección de cartera para mejorar la legibilidad al usar el debug de Foundry.
- roll: Ajusta la altura del bloque.
- warp: Ajusta el timestamp del bloque.

¡Gracias por seguir! Es hora de pasar a la siguiente lección.

## Recursos (en Inglés)

[Foundry book](https://book.getfoundry.sh/)

[Awesome-foundry](https://github.com/crisgarner/awesome-foundry)

[Flash Loan vs Flash Swap](https://blog.infura.io/post/build-a-flash-loan-arbitrage-bot-on-infura-part-i)
