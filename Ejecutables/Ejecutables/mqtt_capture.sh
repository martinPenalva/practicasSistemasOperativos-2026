#!/bin/bash
set -e

echo "==============================="
echo " Captura automática MQTT"
echo "==============================="

read -p "Tiempo de captura (segundos): " tiempo

if ! [[ "$tiempo" =~ ^[0-9]+$ ]]; then
    echo "Error: Debes introducir un número válido"
    exit 1
fi

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
# ASCII TIPO FIGURA CON PUNTOS (no líneas)
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

    # Crear matriz vacía para el gráfico de puntos
    grid = [['  ' for _ in range(samples)] for _ in range(height + 1)]
    
    # Colocar puntos en las posiciones correctas
    for i, v in enumerate(values):
        if y_max != y_min:
            # Calcular en qué nivel va este punto
            level = int((v - y_min) / step)
            level = min(max(level, 0), height)  # Asegurar que esté en rango
            grid[height - level][i] = '* '
        else:
            # Si todos los valores son iguales, ponerlos en el medio
            grid[height // 2][i] = '* '

    # Dibujar gráfico con puntos
    for level in range(height + 1):
        threshold = y_min + step * (height - level)
        line = f"{int(threshold):4} | "
        for col in grid[level]:
            line += col
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

# Generar 3 gráficas acumulativas con los 2 sensores reales en una sola línea
echo "[7] Generando 3 gráficas acumulativas con los 2 sensores reales juntos..."
python3 - <<PY
import json
import os
import matplotlib.pyplot as plt
import numpy as np
from collections import defaultdict

output_dir = "plots"
all_data = defaultdict(list)  # Almacenará datos por tipo de sensor/topic

# Combinar datos de todas las capturas - SOLO LOS 2 SENSORES REALES ESPECÍFICOS
for captura in range(1, 4):
    log_file = f"mqtt_capture_{captura}.log"
    
    current_topic = None
    capture_data = defaultdict(list)

    with open(log_file, "r") as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()

        if "Topic:" in line:
            # Detectar SOLO los 2 sensores reales específicos
            if "sensor/data/sen55" in line:
                current_topic = "sensor/data/sen55"
            elif "sensor/data/gas_sensor" in line:
                current_topic = "sensor/data/gas_sensor"
            else:
                current_topic = None  # Ignorar otros topics

        if "Payload:" in line and current_topic:
            try:
                payload = line.split("Payload:")[1].strip()
                data = json.loads(payload)
                
                # SOLO procesar los 2 sensores reales
                if isinstance(data, (int, float)):
                    capture_data[current_topic].append(data)
                elif isinstance(data, dict):
                    # Si es diccionario, buscar valores numéricos
                    for key, value in data.items():
                        if isinstance(value, (int, float)):
                            capture_data[current_topic].append(value)
            except:
                pass
    
    # Añadir datos de esta captura al total
    for key, values in capture_data.items():
        if values:  # Solo añadir si hay datos
            all_data[key].extend(values)

# Combinar los 2 sensores en una sola línea de evolución
if all_data and len(all_data) <= 2:
    print(f"Sensores reales detectados: {list(all_data.keys())}")
    
    # Combinar todos los valores de los 2 sensores en una sola lista
    combined_values = []
    for sensor_key, values in all_data.items():
        combined_values.extend(values)
    
    # Calcular el máximo de muestras para el eje temporal
    max_samples = len(combined_values)
    
    # Gráfica 1: Primer tercio de los datos
    samples_20s = max_samples // 3
    data_20s = combined_values[:samples_20s]
    
    plt.figure(figsize=(12, 6))
    plt.plot(range(len(data_20s)), data_20s, 'b-', linewidth=3, label='2 sensores combinados')
    plt.title("Todos los datos recogidos - 20 segundos", fontsize=16, fontweight='bold')
    plt.xlabel("Índice", fontsize=14)
    plt.ylabel("Valor", fontsize=14)
    plt.legend(fontsize=12)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(f"{output_dir}/dos_sensores_reales_20s.png", dpi=300, bbox_inches='tight')
    plt.close()
    
    # Gráfica 2: Dos tercios de los datos
    samples_40s = 2 * (max_samples // 3)
    data_40s = combined_values[:samples_40s]
    
    plt.figure(figsize=(12, 6))
    plt.plot(range(len(data_40s)), data_40s, 'g-', linewidth=3, label='2 sensores combinados')
    plt.title("Todos los datos recogidos - 40 segundos (acumulativo)", fontsize=16, fontweight='bold')
    plt.xlabel("Índice", fontsize=14)
    plt.ylabel("Valor", fontsize=14)
    plt.legend(fontsize=12)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(f"{output_dir}/dos_sensores_reales_40s.png", dpi=300, bbox_inches='tight')
    plt.close()
    
    # Gráfica 3: 60 segundos (todos los datos)
    data_60s = combined_values
    
    plt.figure(figsize=(12, 6))
    plt.plot(range(len(data_60s)), data_60s, 'r-', linewidth=3, label='2 sensores combinados')
    plt.title("Todos los datos recogidos - 60 segundos (acumulativo)", fontsize=16, fontweight='bold')
    plt.xlabel("Índice", fontsize=14)
    plt.ylabel("Valor", fontsize=14)
    plt.legend(fontsize=12)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(f"{output_dir}/dos_sensores_reales_60s.png", dpi=300, bbox_inches='tight')
    plt.close()
    
    print("✓ 3 gráficas con los 2 sensores reales en una sola línea generadas:")
    print(f"  - {output_dir}/dos_sensores_reales_20s.png (solo 20s)")
    print(f"  - {output_dir}/dos_sensores_reales_40s.png (20s + 20s nuevos)")
    print(f"  - {output_dir}/dos_sensores_reales_60s.png (40s + 20s nuevos)")
    print(f"  - Sensores reales: {len(all_data)} tipos")
    print(f"  - Total de datos combinados: {len(combined_values)} valores")
else:
    print("No se detectaron los 2 sensores reales o hay datos insuficientes.")
    if all_data:
        print(f"Sensores encontrados: {list(all_data.keys())}")
PY

echo "[8] Proceso completado. Revisa la carpeta plots/ para ver todas las gráficas."