# ==============================================================================
# Proyecto #3 - INFO1128 Interfaces Gráficas
# Emulador de Sensor de Material Particulado MP 2.5 um
# Transmite datos por puerto serial (9600 Bps, 8N1) con un sampling de 1 segundo
# Distribución Normal(media = 80, desviación estándar = 5)
# ==============================================================================

import time
import random
import argparse
import sys

try:
    import serial
    import serial.tools.list_ports
    TIENE_PYSERIAL = True
except ImportError:
    TIENE_PYSERIAL = False


def listar_puertos_disponibles():
    if not TIENE_PYSERIAL:
        print("[AVISO] La librería 'pyserial' no está instalada. Ejecute: pip install pyserial")
        return []

    puertos = serial.tools.list_ports.comports()
    lista_nombres = []
    for puerto in puertos:
        lista_nombres.append(puerto.device)
    return lista_nombres


def generar_valor_mp25(media_normal=80.0, desviacion_estandar=5.0):
    """
    Genera una lectura simulada de MP 2.5 um modelada con una
    Distribución Normal(80, 5), redondeada a entero.
    """
    valor_continuo = random.gauss(media_normal, desviacion_estandar)
    valor_entero = int(round(valor_continuo))

    if valor_entero < 0:
        valor_entero = 0

    return valor_entero


def iniciar_transmision_serial(nombre_puerto, velocidad_baudios=9600, intervalo_segundos=1.0):
    if not TIENE_PYSERIAL:
        print("[ERROR] No se encontró pyserial. Instálelo con: pip install pyserial")
        sys.exit(1)

    print("==============================================================")
    print("  SENSOR PYTHON MP 2.5 um - DISTRIBUCIÓN NORMAL(80, 5)")
    print("==============================================================")
    print(f"  Puerto Serial     : {nombre_puerto}")
    print(f"  Configuración     : {velocidad_baudios} Bps, 8 bits, Paridad N, 1 bit parada (8N1)")
    print(f"  Sampling          : {intervalo_segundos} segundo(s)")
    print("==============================================================")

    try:
        conexion_serial = serial.Serial(
            port=nombre_puerto,
            baudrate=velocidad_baudios,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1.0
        )
    except Exception as error_apertura:
        print(f"\n[ERROR] No se pudo abrir el puerto {nombre_puerto}: {error_apertura}")
        puertos_actuales = listar_puertos_disponibles()
        print(f"Puertos detectados en el sistema: {puertos_actuales}")
        print("Sugerencia: Verifique que el par de puertos virtuales (ej. com0com COM1<->COM2) esté activo")
        print("o indique otro puerto con: python sensor_mp25.py --puerto COM2")
        sys.exit(1)

    contador_muestras = 0

    try:
        while True:
            valor_mp25 = generar_valor_mp25(80.0, 5.0)
            mensaje_serial = f"{valor_mp25}\r\n"
            bytes_mensaje = mensaje_serial.encode("utf-8")

            conexion_serial.write(bytes_mensaje)
            conexion_serial.flush()

            hora_actual = time.strftime("%H:%M:%S")
            print(f"[{hora_actual}] Muestra #{contador_muestras:02d} enviada -> MP2.5 = {valor_mp25} [ug/m3]")

            contador_muestras = contador_muestras + 1
            time.sleep(intervalo_segundos)

    except KeyboardInterrupt:
        print("\n[INFO] Transmisión finalizada por el usuario.")
    finally:
        if conexion_serial.is_open:
            conexion_serial.close()
            print(f"[INFO] Puerto {nombre_puerto} cerrado correctamente.")


if __name__ == "__main__":
    analizador_argumentos = argparse.ArgumentParser(
        description="Emulador de Sensor MP 2.5 um por Puerto Serial (9600 Bps, 8N1)"
    )
    analizador_argumentos.add_argument(
        "--puerto",
        type=str,
        default="COM1",
        help="Nombre del puerto serial a utilizar (por defecto: COM1)"
    )
    analizador_argumentos.add_argument(
        "--baudios",
        type=int,
        default=9600,
        help="Velocidad en baudios (por defecto: 9600)"
    )
    analizador_argumentos.add_argument(
        "--sampling",
        type=float,
        default=1.0,
        help="Tiempo de muestreo en segundos (por defecto: 1.0)"
    )

    argumentos = analizador_argumentos.parse_args()

    iniciar_transmision_serial(
        nombre_puerto=argumentos.puerto,
        velocidad_baudios=argumentos.baudios,
        intervalo_segundos=argumentos.sampling
    )

