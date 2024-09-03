# Debugging/Análisis OnChain de Transacciones: 4. Escribe tu propio PoC - Bot MEV

Autor: [Sun](https://twitter.com/1nf0s3cpt)

Traducción: [JP](https://x.com/CanonicalJP) 

Comunidad [Discord](https://discord.gg/Fjyngakf3h)

Este artículo está publicado en XREX y [WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)

## Escribir PoC paso a paso - Tomando el Bot MEV (BNB48) como ejemplo

- Recapitulación
    - El 20220913, un Bot MEV fue explotado por un atacante y todos los activos en el contrato fueron transferidos, con una pérdida total de aproximadamente $140K.
    - El atacante envía una transacción privada a través del nodo validador BNB48, similar a Flashbot, sin poner la transacción en el mempool público para evitar ser adelantado (Front-running).
- Análisis
    - [TXID](https://bscscan.com/tx/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2) del atacante. Podemos ver que el contrato del Bot MEV no estaba verificado, lo que significa que no era de código abierto. ¿Cómo se aprovechó de esto el atacante?
    - Usando [phalcon](https://phalcon.blocksec.com/tx/bsc/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2) para verificar, desde la parte del flujo de funciones dentro de esta transacción, el bot MEV transfirió 6 tipos de activos a la billetera del atacante. ¿Cómo se aprovechó de esto el atacante?
![imagen](https://user-images.githubusercontent.com/52526645/211201079-e7c5cc3b-64f8-4146-ab0e-7dd46b535cc9.png)
    - Al ver el proceso de invocación de la llamada a función, detectamos que la función `pancakeCall` fue llamada exactamente 6 veces.
        - Desde: `0xee286554f8b315f0560a15b6f085ddad616d0601`
        - Contrato del atacante: `0x5cb11ce550a2e6c24ebfc8df86c5757b596e69c1`
        - Contrato del Bot MEV: `0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d`
 ![imagen](https://user-images.githubusercontent.com/52526645/211201456-8b6f7bca-677d-40a2-b81b-fd6af18f94fd.png)
    - Expandamos uno de los `pancakeCall` para analizarlo, podemos ver que la devolución de llamada al contrato del atacante lee el valor de token0() como BSC-USD, y luego transfiere BSC-USD a la billetera del atacante. Viendo esto, podemos saber que el atacante puede tener el permiso o usar una vulnerabilidad para mover todos los activos en el contrato del Bot MEV, el siguiente paso que necesitamos averiguar es ¿cómo lo usa el atacante?
    ![imagen](https://user-images.githubusercontent.com/52526645/211201744-9895803a-5f72-4f14-b147-b67b204bee75.png)
    - Debido a que se mencionó anteriormente que el contrato del Bot MEV no es de código abierto, aquí podemos usar la [Lección 1](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/01_tools) que introdujo la herramienta decompiladora [Dedaub](https://library.dedaub.com/decompile). Analicemos y veamos si podemos encontrar algo. Primero copiamos los bytecodes del contrato desde [Bscscan](https://bscscan.com/address/0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d#code) y los pegamos en Dedaub para decompilarlo. Como se muestra en la figura de abajo, podemos ver que el permiso de la función `pancakeCall` está configurado como público, y todos pueden llamarla. Es normal y no debería ser un gran problema en la devolución de llamada de un Flash Loan, pero puedes ver en el lugar enmarcado en rojo que ejecuta una función `0x10a`, y luego veamos hacia abajo.
    ![imagen](https://user-images.githubusercontent.com/52526645/211202573-b4a4847d-a617-42c8-84d0-0f2dbd38a632.png)
   - La lógica de la función `0x10a` es como se muestra en la figura de abajo. Puedes ver el punto clave en el lugar enmarcado en rojo. Primero lee qué token está en token0 en el contrato del atacante y luego lo lleva a la función de transferencia `transfer`. En la función, el primer parámetro de la dirección del receptor `address(MEM[varg0.data])` está en `pancakeCall` `varg3 (_data)` que puede ser controlado, así que el problema clave de vulnerabilidad está aquí.
          
<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211204177-fbebe377-23b0-4b0c-bb3e-dcb64dba2afc.png" alt="Cover" width="80%"/>
</div>

   - Mirando de nuevo el payload del atacante llamando a `pancakeCall`, los primeros 32 bytes del valor de entrada en `_data` es la dirección de la billetera del beneficiario.

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211453390-502db65b-cf82-4805-a463-04fc5c7e0dce.png" alt="Cover" width="80%"/>
</div>

- Escribiendo PoC
   - Después de analizar el proceso de ataque anterior, la lógica de escribir el PoC es llamar al `pancakeCall` del contrato del bot MEV y luego introducir los parámetros correspondientes. La clave es `_data` para especificar la dirección de la billetera receptora, y luego el contrato debe tener las funciones token0, token1 para satisfacer la lógica del contrato. Puedes intentar escribirlo tú mismo.
    - Respuesta: [PoC](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/src/test/BNB48MEVBot_exp.sol).
    
<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211204852-4fa65835-17f7-4c91-80ab-79f5b46125df.png" alt="Cover" width="80%"/>
</div>

## Aprendizaje extendido
- Traza de Foundry
    - Las trazas de función de la transacción también se pueden listar usando Foundry, de la siguiente manera:
    
    `cast run 0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2 --quick --rpc-url https://rpc.ankr.com/bsc`

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211562868-12fde773-948c-47a9-acaf-6f744438925e.png" alt="Cover" width="80%"/>
</div>

- Depuración de Foundry
    - También puedes usar Foundry para depurar transacciones, de la siguiente manera:
    
    `cast run 0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2 --quick --debug  --rpc-url https://rpc.ankr.com/bsc`

<div align=center>
<img src="https://user-images.githubusercontent.com/52526645/211565713-fdf3784f-da54-42e8-ad60-591ecac38c15.png" alt="Cover" width="80%"/>
</div>

## Recursos (en Inglés)

[Flashbots: Reyes del Mempool](https://noxx.substack.com/p/flashbots-kings-of-the-mempool?utm_source=profile&utm_medium=reader2)

[Mercados MEV Parte 1: Prueba de Trabajo](https://mirror.xyz/0xshittrader.eth/WiV8DM3I6abNMVsXf-DqioYb2NglnfjmM-zSsw2ruG8)

[Mercados MEV Parte 2: Prueba de Participación](https://mirror.xyz/0xshittrader.eth/c6J_PCK87K3joTWmLEtG6qVN6BFXLBZxQniReYSEjLI)

[Mercados MEV Parte 3: Pago por Flujo de Órdenes](https://mirror.xyz/0xshittrader.eth/f2VSuoZ91vAbCv82MtWM-Gosyf_DeUXfPlDx3EYV3RM)
