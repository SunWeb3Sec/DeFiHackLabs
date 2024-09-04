# Debugging/Análisis OnChain de Transacciones: 5. Análisis del Rugpull del Proyecto CirculateBUSD, Pérdida de $2.27 Millones!

Autor: [Numen Cyber Technology](https://twitter.com/numencyber)

Traducción: [JP](https://x.com/CanonicalJP) 

Comunidad [Discord](https://discord.gg/Fjyngakf3h)

El 12 de enero de 2023 a las 07:22:39 AM UTC, según el monitoreo en cadena de NUMEN, el proyecto CirculateBUSD ha sido vaciado por el creador del contrato, causando una pérdida de 2.27 millones de dólares.

La transferencia de fondos de este proyecto se debe principalmente a que el administrador llama a CirculateBUSD.startTrading, y el principal parámetro de juicio en startTrading es el valor devuelto por el contrato no de código abierto SwapHelper.TradingInfo establecido por el administrador, y luego llama a SwapHelper.swaptoToken para transferir fondos.

Transacción: [https://bscscan.com/tx/0x3475278b4264d4263309020060a1af28d7be02963feaf1a1e97e9830c68834b3](https://bscscan.com/tx/0x3475278b4264d4263309020060a1af28d7be02963feaf1a1e97e9830c68834b3)

<div align=center>
<img src="https://miro.medium.com/max/1400/1*fLhvqu5spyN0EIycnFNqiw.png" alt="Cover" width="80%"/>
</div>
