# Debugging/Análisis Onchain de Transacciones: 1. Herramientas

Autor original: [Sun](https://twitter.com/1nf0s3cpt)

Traducción al español: [Eloi](https://twitter.com/eloi_manuel)

Comunidad [Discord](https://discord.gg/Fjyngakf3h)

Este artículo ha sido publicado en XREX y [WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90).

Los recursos en línea eran escasos cuando empecé a aprender sobre análisis de transacciones onchain. Aun así, lentamente fui capaz de reunir información de diferentes fuentes para realizar pruebas y análisis.

A partir de mis estudios, lanzaremos una serie de artículos sobre seguridad Web3. El objetivo es atraer a más gente a la seguridad Web3 y crear juntos una red más segura.

En la primera serie, presentaremos cómo realizar un análisis (o debugging) onchain y, a continuación, reproduciremos ataques pasados. Esta habilidad nos ayudará a entender el proceso de ataque, la causa principal de la vulnerabilidad, ¡e incluso cómo arbitra un robot de arbitraje!

## Las Herramientas Pueden Mejorar Mucho la Eficacia y Eficiencia del Análisis
Antes de entrar en el análisis, permíteme presentarte algunas herramientas habituales. Las herramientas adecuadas pueden ayudarte a investigar de forma más eficaz y eficiente.

### Herramientas de Inspección o Análisis de Transacciones
[Phalcon](https://phalcon.blocksec.com/) | [Tx.viewer](https://tx.eth.samczsun.com/) | [Cruise](https://cruise.supremacy.team/) | [Ethtx](https://ethtx.info/) | [Tenderly](https://dashboard.tenderly.co/explorer)

Transaction Viewer (`Tx.viewer`) es la herramienta más utilizada, es capaz de listar el "stack trace" de las llamadas a funciones y los datos de entrada en cada función durante la transacción. Las herramientas de inspección o análisis de transacciones son todas similares; la mayor diferencia es el soporte de diferentes cadenas y el soporte de funciones auxiliares. Yo personalmente uso `Phalcon` y el Transaction Viewer de Sam. Si encuentro cadenas no soportadas, utilizo `Tenderly`. Tenderly soporta la mayoría de las cadenas, pero la legibilidad es más limitada, y el análisis puede ser lento usando su función de "Debug". Sin embargo, es una de las primeras herramientas que aprendí junto con `Ethtx`.

#### Comparación del Soporte de Diferentes Cadenas
- Phalcon： `Ethereum、BSC、Avalanche C-Chain、Polygon、Solana、Arbitrum、Fantom、Optimism、Base、Linea、zkSync Era、Kava、Evmos、Merlin、Manta、Mantle、Holesky testnet、Sepolia testnet`

- Sam's Transaction viewer： `Ethereum, Polygon, BSC, Avalanche C-Chain, Fantom, Arbitrum, Optimism`

- Cruise： `Ethereum, BSC, Polygon, Arbitrum, Fantom, Optimism, Avalanche, Celo, Gnosis`

- Ethtx： `Ethereum, Goerli testnet`

- Tenderly：`Ethereum, Polygon, BSC, Sepolia, Goerli, Gnosis, POA, RSK, Avalanche C-Chain, Arbitrum, Optimism, Fantom, Moonbeam, Moonriver`


#### Laboratorio / Ejemplo
Vamos a ver el [incidente de JayPeggers (Validación insuficiente + Reentrada)](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/past/2022/README.md#20221229---jay---insufficient-validation--reentrancy) como [ejemplo de transacción a diseccionar](https://phalcon.blocksec.com/tx/eth/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6).

Primero utilizaremos la herramienta Phalcon desarrollada por Blocksec. La información básica ("Basic Info") y los cambios de saldo ("Balance Changes") de la transacción se pueden ver en la siguiente figura. A partir de los cambios de saldo, podemos ver rápidamente cuánto beneficio ha obtenido el atacante. En este ejemplo, el atacante obtuvo un beneficio de 15,32 ETH.

![210571234-402d96aa-fe5e-4bc4-becc-190bd5a78e68-2](https://user-images.githubusercontent.com/107249780/210686382-cc02cc6a-b8ec-4cb7-ac19-402cd8ff86f6.png)

Visualización del flujo de invocación ("Invocation Flow") - Contiene la llamada de funciones con sus argumentos, valores devueltos y registro de eventos. Nos muestra la invocación de las funciones, el nivel de llamada a la función de esta transacción, si se utilizan flashloans, qué proyectos están involucrados, qué funciones se llaman, parámetros, datos en bruto, etc.

![圖片](https://user-images.githubusercontent.com/52526645/210572053-eafdf62a-7ebe-4caa-a905-045e792add2b.png)

Phalcon 2.0 ha añadido el flujo de fondos y el análisis debug + código fuente. Estos muestran directamente el código fuente, los parámetros y los valores de retorno junto con la traza, lo que resulta más cómodo para el análisis.

![image](https://user-images.githubusercontent.com/107249780/210821062-d1da8d1a-9615-4f1f-838d-34f27b9c3f41.png)

Ahora vamos a probar el Visor de Transacciones de Sam en la misma [transacción](https://tx.eth.samczsun.com/ethereum/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6). Sam integra muchas herramientas en él, como se muestra en la imagen de abajo, se pueden ver los cambios en el almacenamiento y el gas consumido por cada llamada.

![210574290-790f6129-aa82-4152-b3e1-d21820524a0a-2](https://user-images.githubusercontent.com/107249780/210686653-f964a682-d2a7-4b49-bafc-c9a2b0fa2c55.png)

Puedes hacer clic en "call" (a la izquierda) para ver los datos de entrada ("Input data") sin procesar.

![圖片](https://user-images.githubusercontent.com/52526645/210575619-89c8e8de-e2f9-4243-9646-0661b9483913.png)

Cambiemos ahora a Tenderly para analizar la misma [transacción](https://dashboard.tenderly.co/tx/mainnet/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6). Se puede ver la información básica como con las otras herramientas. Pero usando la función "Debugger", no se visualizan todas las interacciones directamente sino que se necesita analizar paso a paso cada llamada. Sin embargo, la ventaja es que puedes ver el código y el proceso de conversión de los datos de entrada mientras lo analizas.

![圖片](https://user-images.githubusercontent.com/52526645/210577802-c455545c-80d7-4f35-974a-dadbe59c626e.png)

Esto puede ayudarnos a aclarar todo lo que hizo la transacción. Antes de escribir el PoC, ¿podemos simular una repetición del ataque? Sí. Tanto Tenderly como Phalcon soportan transacciones simuladas, puedes encontrar un botón "Re-Simulate" en la esquina superior derecha en la figura de arriba. La herramienta rellenará automáticamente los valores de los parámetros de la transacción como se muestra en la figura de abajo. Los parámetros pueden cambiarse arbitrariamente según las necesidades de la simulación, como cambiar el número de bloque, Desde, Gas, Datos de entrada, etc.

![圖片](https://user-images.githubusercontent.com/52526645/210580340-f2abf864-e540-4881-8482-f28030e5e35b.png)

### Ethereum Signature Database

[4byte](https://www.4byte.directory/) | [sig.eth](https://sig.eth.samczsun.com/) | [etherface](https://www.etherface.io/hash)

En los campos "Input Data", los primeros 4 bytes son las "Function Signatures" o firmas de las funciones. A veces, si Etherscan o las herramientas de análisis no pueden identificar la función, podemos comprobar las posibles funciones a través de las bases de datos de firmas.

El siguiente ejemplo supone que no sabemos qué es la función `0xac9650d8`.

![image](https://user-images.githubusercontent.com/107249780/211152650-bfe5ca56-971c-4f38-8407-8ca795fd5b73.png)

Mediante una consulta en `sig.eth`, encontramos que la firma de 4 bytes es `multicall(bytes[])`.

![圖片](https://user-images.githubusercontent.com/52526645/210583416-c31bbe07-fa03-4701-880d-0ae485b171f7.png)

### Herramientas Útiles

[ABI to interface](https://gnidan.github.io/abi-to-sol/) | [Get ABI for unverified contracts](https://abi.w1nt3r.xyz/) | [ETH Calldata Decoder](https://apoorvlathey.com/eth-calldata-decoder/) | [ETHCMD - Guess ABI](https://www.ethcmd.com/)

De ABI a interfaz (interface): Cuando se desarrolla un PoC, es necesario tener interfaces para llamar a otros contratos. Podemos usar esta herramienta para ayudarnos a generar rápidamente las interfaces. Puedes ir a Etherscan para copiar la ABI, y pegarla en la herramienta para ver la interfaz generada. [Ejemplo](https://etherscan.io/address/0xb3da8d6da3ede239ccbf576ca0eaa74d86f0e9d3#code).

![圖片](https://user-images.githubusercontent.com/52526645/210587442-e7853d8b-0613-426e-8a27-d70c80e2a42d.png)
![圖片](https://user-images.githubusercontent.com/52526645/210587682-5fb07a01-2b21-41fa-9ed5-e7f45baa0b3e.png)

ETH Calldata Decoder: Si quieres decodificar datos de entrada sin la ABI, esta es la herramienta que necesitas. El visor de transacciones de Sam que vimos antes también soporta la decodificación de datos de entrada.

![圖片](https://user-images.githubusercontent.com/52526645/210585761-efd8b6f1-b901-485f-ae66-efaf9c84869c.png)

Obtener la ABI para contratos no verificados: Si te encuentras con un contrato que no está verificado, puedes utilizar esta herramienta para intentar averiguar las firmas de las funciones. [Ejemplo](https://abi.w1nt3r.xyz/mainnet/0xaE9C73fd0Fd237c1c6f66FE009d24ce969e98704)

![圖片](https://user-images.githubusercontent.com/52526645/210588945-701b0e22-7390-4539-9d2f-e13479b52824.png)

### Herramientas de Decompilación
[Etherscan-decompile bytecode](https://etherscan.io/address/0xaE9C73fd0Fd237c1c6f66FE009d24ce969e98704#code) | [Dedaub](https://library.dedaub.com/decompile) | [heimdall-rs](https://github.com/Jon-Becker/heimdall-rs)

Etherscan tiene una función de decompilación incorporada, pero la legibilidad del resultado es a menudo pobre. Personalmente, suelo utilizar Dedaub, que produce mejor código descompilado. Es mi descompilador recomendado. Usemos un Bot de MEV siendo atacado como ejemplo. Puedes intentar descompilarlo por ti mismo usando este [contrato](https://twitter.com/1nf0s3cpt/status/1577594615104172033).

Primero, copia el `Bytecode` del contrato no verificado y pégalo en Dedaub. Después haz clic en "Decompile" (Decompilar).

![截圖 2023-01-05 上午10 33 15](https://user-images.githubusercontent.com/107249780/210688395-927c6126-b6c1-4c6d-a0c7-a3fea3db9cdb.png)

![圖片](https://user-images.githubusercontent.com/52526645/210591478-6fa928f3-455d-42b5-a1ac-6694f97386c2.png)

Si quieres saber más, puedes consultar los siguientes recursos.

## Recursos (en Inglés)

[samczsun's eth txn explorer and vscode extension](https://www.youtube.com/watch?v=HXgu239mPBc)

[Vulnerabilities in DeFi by Daniel V.F.](https://www.youtube.com/watch?v=9fcOffCg2ig)

[Tenderly.co - Debug Transaction](https://www.youtube.com/watch?v=90GN9Ut8LhU)

[Reversing The EVM: Raw Calldata](https://degatchi.com/articles/reading-raw-evm-calldata)

https://web3sec.xrex.io/
