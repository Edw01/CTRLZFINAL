# Proyecto #3 – Interfaces Gráficas (INFO1128)
**Visor de Material Particulado MP 2.5 um en Lazarus Free Pascal**

---

## 📂 Organización de Carpetas del Proyecto

| Carpeta / Archivo | Descripción |
| :--- | :--- |
| **`INICIAR_PROYECTO.bat`** | Lanzador automático: abre con doble clic el **Servidor TCP/IP Consola** y el **Visor Gráfico MP 2.5 um**. |
| **`documentos_pdf/`** | **Los 3 manuales en PDF para ejecución y defensa:**<br>• `1_Guia_Ejecucion_Paso_a_Paso.pdf`<br>• `2_Explicacion_Codigo_y_Preguntas_Defensa.pdf`<br>• `3_Que_Son_Los_Baudios_y_Comunicacion_Serial.pdf` |
| **`visor_mp25/`** | Aplicación GUI en Lazarus Free Pascal (`visor_mp25.lpi`, `u_visor_mp25.pas`, `u_visor_mp25.lfm`, `visor_mp25.exe`). |
| **`server_tcp/`** | Servidor TCP/IP en modo consola en Lazarus (`servidor_tcp_aire.lpi`, `servidor_tcp_aire.lpr`, `servidor_tcp_aire.exe`). |
| **`python_sensor/`** | Script emisor serial en Python (`sensor_mp25.py`) con **Distribución Normal(80, 5)** a **9.600 Bps, 8N1** y sampling de **1 segundo**. |
| **`db/`** | Base de datos SQLite (`aire.db`), script SQL (`crear_tabla_aire.sql`) y librería `sqlite3.dll` para **HeidiSQL 12.3 Portable**. |
| **`images/`** | Imágenes de fondo del visor (`img1.png` a `img6.png`) e iconos de los botones (`camara.png`, `f02.bmp`, `pale.png`). |
| **`components/lazserial/`** | Paquete del componente serial `TLazSerial` (`LazSerialPort.lpk`). |

---

## 🚀 Inicio Rápido

1. Haz doble clic en **`INICIAR_PROYECTO.bat`** (o ejecuta primero `server_tcp\servidor_tcp_aire.exe` y luego `visor_mp25\visor_mp25.exe`).
2. Para revisar los datos en tiempo real en **HeidiSQL_12.3_64_Portable**, abre el archivo `db\aire.db` (tipo de red **SQLite**, librería `db\sqlite3.dll`) y selecciona la tabla **`Aire`**.
3. Revisa la carpeta **`documentos_pdf/`** para la guía detallada paso a paso, la explicación del código para la defensa y el documento sobre los baudios.

---

<p align="center">
  <img src=".docs/oguricapdance.gif" alt="Oguri Cap Bailando Lindamente" width="10000"/>
</p>
