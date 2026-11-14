# Proyecto #3 – Interfaces Gráficas (INFO1128)
**Visor de Material Particulado MP 2.5 um en Lazarus Free Pascal**

## Tecnologías Utilizadas
- **Lazarus Free Pascal (FPC 3.2.2 / Lazarus 4.8 x64)**
  - Paquete serial **LazSerial** (`components/lazserial/LazSerialPort.lpk`) configurado a **9.600 Bps, 8N1**.
  - Componente **TAChart** (`TChart` + `TLineSeries`).
- **Python 3 (`pyserial`)** – Emisor de muestras MP 2.5 um con **Distribución Normal(80, 5)** cada **1 segundo**.
- **Servidor TCP/IP Lazarus Pascal (Modo Consola)** – Recibe cada muestra MP25 desde el visor gráfico y la registra en tiempo real en **SQLite**.
- **SQLite 3 + HeidiSQL v12.3 x64 Portable** – Base de datos `db/aire.db` con la tabla `Aire` (`id`, `MP25`, `Fecha`, `Hora`).

---

## Estructura del Proyecto

| Componente | Ruta | Descripción |
| :--- | :--- | :--- |
| **Visor Gráfico (GUI Lazarus)** | `visor_mp25/visor_mp25.lpi`<br>`visor_mp25/u_visor_mp25.pas`<br>`visor_mp25/visor_mp25.exe` | Interfaz gráfica con `TChart`, `TLineSeries`, `TLazSerial` (9600 Bps, 8N1), botones `Save` (`camara.png`), `On/off` (`f02.bmp`), `Click` (`pale.png`), `Hint` activado en todos los controles y cliente TCP/IP. |
| **Servidor TCP/IP (Consola Lazarus)** | `server_tcp/servidor_tcp_aire.lpi`<br>`server_tcp/servidor_tcp_aire.lpr`<br>`server_tcp/servidor_tcp_aire.exe` | Servidor TCP/IP en modo consola (puerto `5000`) que muestra las lecturas recibidas en tiempo real e inserta cada registro en SQLite (`Tabla Aire`). |
| **Emisor Serial Python** | `python_sensor/sensor_mp25.py` | Script en Python que modela valores de MP 2.5 um mediante `Normal(80, 5)` y los transmite a **9.600 Bps, 8N1** con sampling de **1 segundo**. |
| **Base de Datos SQLite** | `db/aire.db`<br>`db/crear_tabla_aire.sql` | Base de datos SQLite y script SQL con la tabla `Aire (id, MP25, Fecha, Hora)` lista para abrirse en **HeidiSQL_12.3_64_Portable**. |
| **Paquete LazSerial** | `components/lazserial/LazSerialPort.lpk` | Paquete `TLazSerial` compilado e integrado en el proyecto. |
| **Imágenes e Iconos** | `images/` | Fondos del visor (`img1.png` .. `img6.png`) e iconos de botones (`camara.png`, `f02.bmp`, `pale.png`). |

---

## Cómo Ejecutar el Proyecto Paso a Paso

### 1. Iniciar el Servidor TCP/IP en Modo Consola
Abra una terminal o ejecute directamente:
```powershell
.\server_tcp\servidor_tcp_aire.exe
```
El servidor escuchará en `127.0.0.1:5000`, creará/abrirá automáticamente `db/aire.db` (tabla `Aire`) y mostrará cada muestra recibida con su `MP25`, `Fecha` y `Hora`.

### 2. (Opcional) Iniciar el Script Emisor Serial en Python
Si cuenta con un par de puertos seriales virtuales (por ejemplo `COM1 <-> COM2` con *com0com* o *Virtual Serial Port Driver*):
```powershell
pip install -r .\python_sensor\requirements.txt
python .\python_sensor\sensor_mp25.py COM1
```
> **Nota:** Si no tiene puertos virtuales activos, el visor `visor_mp25.exe` cuenta con respaldo automático integrado a 1 segundo con distribución `Normal(80, 5)`, y conmuta automáticamente a los datos de `TLazSerial` apenas detecta recepción por el puerto serial.

### 3. Iniciar el Visor Gráfico MP 2.5 um
Ejecute la aplicación compilada (o ábrala en Lazarus desde `visor_mp25/visor_mp25.lpi` y presione **F9**):
```powershell
.\visor_mp25\visor_mp25.exe
```
- **Botón `Save` (Cámara Fotográfica):** Guarda una captura del visor en `captura.png`.
- **Botón `On/off`:** Activa o desactiva la grilla punteada (`Grid`) del visor.
- **Botón `Click`:** Cambia la imagen de fondo (`img1.png` a `img6.png`) del visor.

### 4. Visualizar Datos en Tiempo Real con HeidiSQL 12.3 Portable
1. Abra **HeidiSQL_12.3_64_Portable**.
2. Haga clic en **Nueva** sesión y seleccione **Tipo de red:** `SQLite`.
3. En **Archivo de base de datos**, seleccione `db\aire.db` (y si solicita librería, seleccione `sqlite3.dll` en la raíz del proyecto).
4. Haga clic en **Abrir**, seleccione la tabla **`Aire`** y vaya a la pestaña **Datos** (presione **F5** para refrescar en tiempo real).

---

<p align="center">
  <img src=".docs/oguricapdance.gif" alt="Oguri Cap Bailando Lindamente" width="10000"/>
</p>
