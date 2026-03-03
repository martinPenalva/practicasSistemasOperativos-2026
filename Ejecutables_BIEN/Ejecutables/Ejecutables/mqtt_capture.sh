#!/bin/bash
set -e

echo "==============================="
echo " Captura automática MQTT"
echo "==============================="

# Pedir tiempo de captura
read -p "Tiempo de captura (segundos): " tiempo

if ! [[ "$tiempo" =~ ^[0-9]+$ ]]; then
    echo "Error: Debes introducir un número válido"
    exit 1
fi

# Número de capturas
num_capturas=3
espera_entre_capturas=20

for captura in {1..3}; do
    echo "==============================="
    echo " CAPTURA $captura de $num_capturas"
    echo "==============================="
    
    echo "[1] Iniciando proceso MQTT..."
    ./mqtt_subscribe_emqx_linux > mqtt_capture_$captura.log 2>&1 &
    PID=$!
    echo "[2] PID del proceso: $PID"
    
    # Verificar proceso activo
    if kill -0 $PID 2>/dev/null; then
        echo "Proceso activo correctamente."
    else
        echo "Error: el proceso no se inició."
        exit 1
    fi
    
    # Esperar tiempo de captura
    echo "[3] Esperando $tiempo segundos..."
    sleep "$tiempo"
    
    # Finalizar proceso
    echo "[4] Finalizando proceso con SIGINT..."
    kill -SIGINT $PID 2>/dev/null
    sleep 2
    
    if kill -0 $PID 2>/dev/null; then
        echo "Proceso sigue activo → enviando SIGTERM..."
        kill -SIGTERM $PID
        sleep 2
    fi
    
    if kill -0 $PID 2>/dev/null; then
        echo "Proceso no responde → enviando SIGKILL..."
        kill -SIGKILL $PID
    fi
    
    echo "[5] Proceso finalizado correctamente."
    
    # Ejecutar análisis para esta captura
    python3 - <<PY
import json
import os
import matplotlib.pyplot as plt

log_file = "mqtt_capture_$captura.log"
output_dir = "plots"

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

gas_data = []

# ===============================
# PARSEO DEL LOG
# ===============================
current_topic = None

with open(log_file, "r") as f:
    lines = f.readlines()

for line in lines:
    line = line.strip()

    if "Topic:" in line:
        if "gas_sensor" in line:
            current_topic = "gas"

    if "Payload:" in line and current_topic == "gas":
        try:
            payload = line.split("Payload:")[1].strip()
            data = json.loads(payload)
            gas_data.append(data)
        except:
            pass

# ===============================
# ASCII TIPO FIGURA
# ===============================

if gas_data and "GM702B" in gas_data[0]:

    values = [d["GM702B"] for d in gas_data if "GM702B" in d]

    y_min = int(min(values))
    y_max = int(max(values))
    samples = len(values)

    print(f"\n=== MQTT Payload Plot (ASCII) - Captura $captura ===")
    print(f"muestras={samples} | y_min={y_min} | y_max={y_max} | archivo={log_file}\n")

    height = 10  # altura del gráfico ASCII
    step = (y_max - y_min) / height if y_max != y_min else 1

    # Dibujar gráfico
    for level in reversed(range(height + 1)):
        threshold = y_min + step * level
        line = f"{int(threshold):4} | "

        for v in values:
            if v >= threshold:
                line += "*  "
            else:
                line += "   "

        print(line)

    # Eje X
    print("     +" + "---" * samples)
    print("       ", end="")
    for i in range(samples):
        print(f"{i%10}  ", end="")
    print("\n")

    print("Últimos valores:", values[-5:])
    print(f"[4/4] Listo ✓")
    print(f"Log guardado en: {log_file}")

else:
    print("No hay datos suficientes para generar gráfico ASCII.")

# ===============================
# GENERAR PNG (opcional)
# ===============================

if gas_data:
    values = [d["GM702B"] for d in gas_data if "GM702B" in d]

    plt.figure()
    plt.plot(values)
    plt.title(f"gas - GM702B - Captura $captura")
    plt.xlabel("Muestras")
    plt.ylabel("GM702B")
    plt.grid(True)
    plt.savefig(f"{output_dir}/gas_GM702B_captura_$captura.png")
    plt.close()
PY

    echo "[6] Análisis Python completado para captura $captura."
    
    # Esperar entre capturas (excepto después de la última)
    if [ $captura -lt $num_capturas ]; then
        echo "[7] Esperando $espera_entre_capturas segundos antes de la siguiente captura..."
        sleep "$espera_entre_capturas"
    fi
done

echo "==============================="
echo " TODAS LAS CAPTURAS COMPLETADAS"
echo "==============================="
echo "Se han generado 3 gráficas individuales en la carpeta plots/"
echo "Logs guardados: mqtt_capture_1.log, mqtt_capture_2.log, mqtt_capture_3.log"

# Generar 3 gráficas acumulativas con todos los datos COMBINADOS en una sola línea
echo "[7] Generando 3 gráficas acumulativas con todos los datos combinados..."
python3 - <<PY
import json
import os
import matplotlib.pyplot as plt
import numpy as np
from collections import defaultdict

output_dir = "plots"
all_data = defaultdict(list)  # Almacenará datos por tipo de sensor/topic

# Combinar datos de todas las capturas manteniendo el orden temporal
for captura in range(1, 4):
    log_file = f"mqtt_capture_{captura}.log"
    
    current_topic = None
    capture_data = defaultdict(list)

    with open(log_file, "r") as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()

        if "Topic:" in line:
            # Extraer el tipo de topic
            if "gas_sensor" in line:
                current_topic = "gas_sensor"
            elif "temperature" in line:
                current_topic = "temperature"
            elif "humidity" in line:
                current_topic = "humidity"
            elif "pressure" in line:
                current_topic = "pressure"
            else:
                current_topic = "other"

        if "Payload:" in line and current_topic:
            try:
                payload = line.split("Payload:")[1].strip()
                data = json.loads(payload)
                
                # Procesar diferentes tipos de datos
                if isinstance(data, dict):
                    for key, value in data.items():
                        if isinstance(value, (int, float)):
                            sensor_key = f"{current_topic}_{key}"
                            capture_data[sensor_key].append(value)
                elif isinstance(data, (int, float)):
                    capture_data[current_topic].append(data)
            except:
                pass
    
    # Añadir datos de esta captura al total
    for key, values in capture_data.items():
        all_data[key].extend(values)

# Combinar todos los datos en una sola línea de evolución
if all_data:
    print(f"Tipos de datos encontrados: {list(all_data.keys())}")
    
    # Combinar todos los valores de todos los sensores en una sola lista
    combined_values = []
    for sensor_key, values in all_data.items():
        combined_values.extend(values)
    
    # Ordenar los valores combinados por tiempo (asumimos que ya están en orden temporal)
    # Si hay diferentes cantidades de datos por sensor, interpolamos al mismo eje temporal
    
    # Calcular el máximo de muestras para el eje temporal
    max_samples = len(combined_values)
    
    # Gráfica 1: 20 segundos (primer tercio)
    samples_20s = max_samples // 3
    time_20s = np.linspace(0, 20, samples_20s)
    data_20s = combined_values[:samples_20s]
    
    plt.figure(figsize=(12, 6))
    plt.plot(time_20s, data_20s, 'b-', linewidth=3, label='Todos los datos combinados')
    plt.title("TODOS LOS DATOS COMBINADOS - 20 segundos", fontsize=16, fontweight='bold')
    plt.xlabel("Tiempo (segundos)", fontsize=14)
    plt.ylabel("Valores Combinados", fontsize=14)
    plt.legend(fontsize=12)
    plt.grid(True, alpha=0.3)
    plt.xlim(0, 20)
    plt.tight_layout()
    plt.savefig(f"{output_dir}/todos_datos_combinados_20s.png", dpi=300, bbox_inches='tight')
    plt.close()
    
    # Gráfica 2: 40 segundos (contiene los 20s anteriores + 20s nuevos)
    samples_40s = 2 * (max_samples // 3)
    time_40s = np.linspace(0, 40, samples_40s)
    data_40s = combined_values[:samples_40s]
    
    plt.figure(figsize=(12, 6))
    plt.plot(time_40s, data_40s, 'g-', linewidth=3, label='Todos los datos combinados')
    # Marcar dónde termina la gráfica de 20s
    plt.axvline(x=20, color='red', linestyle='--', alpha=0.7, linewidth=2, label='Límite 20s')
    plt.title("TODOS LOS DATOS COMBINADOS - 40 segundos (contiene los 20s anteriores)", fontsize=16, fontweight='bold')
    plt.xlabel("Tiempo (segundos)", fontsize=14)
    plt.ylabel("Valores Combinados", fontsize=14)
    plt.legend(fontsize=12)
    plt.grid(True, alpha=0.3)
    plt.xlim(0, 40)
    plt.tight_layout()
    plt.savefig(f"{output_dir}/todos_datos_combinados_40s.png", dpi=300, bbox_inches='tight')
    plt.close()
    
    # Gráfica 3: 60 segundos (contiene los 40s anteriores + 20s nuevos)
    time_60s = np.linspace(0, 60, max_samples)
    
    plt.figure(figsize=(12, 6))
    plt.plot(time_60s, combined_values, 'r-', linewidth=3, label='Todos los datos combinados')
    # Marcar dónde terminan las gráficas anteriores
    plt.axvline(x=20, color='blue', linestyle='--', alpha=0.5, linewidth=2, label='Límite 20s')
    plt.axvline(x=40, color='green', linestyle='--', alpha=0.7, linewidth=2, label='Límite 40s')
    plt.title("TODOS LOS DATOS COMBINADOS - 60 segundos (contiene los 40s anteriores)", fontsize=16, fontweight='bold')
    plt.xlabel("Tiempo (segundos)", fontsize=14)
    plt.ylabel("Valores Combinados", fontsize=14)
    plt.legend(fontsize=12)
    plt.grid(True, alpha=0.3)
    plt.xlim(0, 60)
    plt.tight_layout()
    plt.savefig(f"{output_dir}/todos_datos_combinados_60s.png", dpi=300, bbox_inches='tight')
    plt.close()
    
    print("✓ 3 gráficas acumulativas con datos combinados generadas:")
    print(f"  - {output_dir}/todos_datos_combinados_20s.png (solo 20s)")
    print(f"  - {output_dir}/todos_datos_combinados_40s.png (20s + 20s nuevos)")
    print(f"  - {output_dir}/todos_datos_combinados_60s.png (40s + 20s nuevos)")
    print(f"  - Total de datos combinados: {len(combined_values)} valores")
    print(f"  - Sensores combinados: {len(all_data)} tipos")
else:
    print("No hay datos suficientes para generar las gráficas.")
PY

echo "[8] Proceso completado. Revisa la carpeta plots/ para ver todas las gráficas."