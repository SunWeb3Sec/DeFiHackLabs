# Debugging/Análisis OnChain de Transacciones: 5. Análisis del Rugpull del Proyecto CirculateBUSD, Pérdida de $2.27 Millones!

Autor: [Numen Cyber Technology](https://twitter.com/numencyber)

Traducción: [JP](https://x.com/CanonicalJP) 

Comunidad [Discord](https://discord.gg/Fjyngakf3h)

El 12 de enero de 2023 a las 07:22:39 AM UTC, según el monitoreo en cadena de NUMEN, el proyecto CirculateBUSD ha sido vaciado por el creador del contrato, causando una pérdida de 2.27 millones de dólares.

La transferencia de fondos de este proyecto se debe principalmente a que el administrador llama a CirculateBUSD.startTrading, y el principal parámetro en startTrading es el valor devuelto por el contrato SwapHelper.TradingInfo (de código no abierto) establecido por el administrador, y luego llama a SwapHelper.swaptoToken para transferir fondos.

Transacción: [https://bscscan.com/tx/0x3475278b4264d4263309020060a1af28d7be02963feaf1a1e97e9830c68834b3](https://bscscan.com/tx/0x3475278b4264d4263309020060a1af28d7be02963feaf1a1e97e9830c68834b3)

<div align=center>
<img src="https://miro.medium.com/max/1400/1*fLhvqu5spyN0EIycnFNqiw.png" alt="Cover" width="80%"/>
</div>

**Análisis:**
=============

En primer lugar, se llama a la función startTrading del contrato ([https://bscscan.com/address/0x9639d76092b2ae074a7e2d13ac030b4b6a0313ff](https://bscscan.com/address/0x9639d76092b2ae074a7e2d13ac030b4b6a0313ff)), y dentro de la función se llama a la función TradingInfo del contrato SwapHelper, con los siguientes detalles. El código es el siguiente:

<div align=center>
<img src="https://miro.medium.com/max/1400/1*2LithcaYFRGcqls5IY_83g.png" alt="Cover" width="80%"/>
</div>

---

<div align=center>
<img src="https://miro.medium.com/max/1400/1*XbJHPldO3T-9frrr0SQrHA.png" alt="Cover" width="80%"/>
</div>

La figura anterior muestra la pila de llamadas de la transacción. Combinado con el código, podemos ver que TradingInfo solo contiene algunas llamadas estáticas, el problema clave no está en esta función. Continuando con el análisis, encontramos que la pila de llamadas corresponde a la operación approve y safeapprove. Luego se llamó a la función swaptoToken de SwapHelper, que se descubrió que era una función clave en combinación con la pila de llamadas, y la transacción de transferencia se ejecutó en esta llamada. El contrato SwapHelper no es de código abierto según la información en cadena en la siguiente dirección.

[https://bscscan.com/address/0x112f8834cd3db8d2dded90be6ba924a88f56eb4b#code](https://bscscan.com/address/0x112f8834cd3db8d2dded90be6ba924a88f56eb4b#code)

Intentemos hacer un análisis inverso, primero localizamos la firma de la función 0x63437561.

<div align=center>
<img src="https://miro.medium.com/max/1400/1*i7kEvPo_8gYbNs9UGlo-KA.png" alt="Cover" width="80%"/>
</div>

Después, localizamos esta función tras descompilar e intentamos encontrar palabras clave como transfer porque vemos que la pila de llamadas activa una transferencia.

<div align=center>
<img src="https://miro.medium.com/max/1400/1*n8BEIqfn0tZ6plky2MFd7w.png" alt="Cover" width="80%"/>
</div>

Así que localizamos esta rama de la función, primero stor_6_0_19, y leemos esa parte primero.

<div align=center>
<img src="https://miro.medium.com/max/1400/1*ZGTqmc1sIz2_onKUT6-56Q.png" alt="Cover" width="80%"/>
</div>

En este punto, se obtuvo la dirección de transferencia, 0x0000000000000000000000005695ef5f2e997b2e142b38837132a6c3ddc463b7, que se encontró que era la misma que la dirección de transferencia de la pila de llamadas.

<div align=center>
<img src="https://miro.medium.com/max/1400/1*v37FEiN6L-0Nwn5OtbDgxQ.png" alt="Cover" width="80%"/>
</div>

Cuando analizamos cuidadosamente las ramas if y else de esta función, encontramos que si se cumple la condición if, entonces se realizará un rescate normal. Porque a través del slot para obtener stor5 es 0x00000000000000000000000010ed43c718714eb63d5aa57b78b54704e256024e, este contrato es pancakerouter. La función de puerta trasera está en la rama else, se activa siempre que los parámetros pasados sean iguales al valor almacenado en el slot stor7.

<div align=center>
<img src="https://miro.medium.com/max/1400/1*xlYEmp6nsdLA85FUmANxfw.png" alt="Cover" width="80%"/>
</div>

La función de abajo es para modificar el valor de la posición del slot 7, y el permiso de llamada solo lo tiene el propietario del contrato.

<div align=center>
<img src="https://miro.medium.com/max/1400/1*lHLaCA9HM1HtmL3pXYxltw.png" alt="Cover" width="80%"/>
</div>

Todo el análisis anterior es suficiente para determinar que este es un evento de rugpull por parte del proyecto.

Resumen
=======

Numen Cyber Labs recuerda a los usuarios que al realizar inversiones, es necesario llevar a cabo auditorías de seguridad en los contratos del proyecto. Puede haber funciones en el contrato no verificado donde la autoridad del proyecto es demasiado grande o afecta directamente la seguridad de los activos del usuario. Los problemas con este proyecto son solo la punta del iceberg de todo el ecosistema blockchain. Cuando los usuarios invierten, siempren deben verificar las auditorías de seguridad realizadas en el código.

Numen Cyber Labs está comprometido con la protección de la seguridad ecológica de Web3. Por favor, manténganse atentos para más noticias y análisis de ataques recientes.
