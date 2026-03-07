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
# ANÁLISIS TERMINADO - solo gráficas combinadas
# ===============================
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
combined_values = []

for captura in range(1, 4):
    log_file = f"mqtt_capture_{captura}.log"
    current_topic = None

    with open(log_file, "r") as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()

        if "Topic:" in line:
            if "sensor/data/sen55" in line:
                current_topic = "sen55"
            elif "sensor/data/gas_sensor" in line:
                current_topic = "gas"
            else:
                current_topic = None

        if "Payload:" in line and current_topic:
            try:
                payload = line.split("Payload:")[1].strip()
                data = json.loads(payload)

                if isinstance(data, dict):
                    for key, value in data.items():
                        if isinstance(value, (int, float)):
                            combined_values.append(value)

            except:
                pass

# Generar 3 gráficas: 20s, 40s y 60s
total_samples = len(combined_values)

# Gráfica 1: 20 segundos (primer tercio)
samples_20s = total_samples // 3
data_20s = combined_values[:samples_20s]

plt.figure(figsize=(12,6))
plt.plot(data_20s, linewidth=2)
plt.title("Todos los datos recogidos - 20 segundos")
plt.xlabel("Índice")
plt.ylabel("Valor")
plt.grid(True)
plt.savefig("plots/dos_sensores_reales_20s.png")
plt.close()

# ASCII de 20 segundos
if data_20s:
    y_min = int(min(data_20s))
    y_max = int(max(data_20s))
    samples = len(data_20s)

    print(f"\n=== 2 SENSORES JUNTOS (ASCII) - 20 segundos ===")
    print(f"muestras={samples} | y_min={y_min} | y_max={y_max}\n")

    height = 8  # altura reducida para simplificar
    step = (y_max - y_min) / height if y_max != y_min else 1

    # Crear matriz vacía para el gráfico de puntos
    grid = [['  ' for _ in range(samples)] for _ in range(height + 1)]
    
    # Colocar puntos en las posiciones correctas
    for i, v in enumerate(data_20s):
        if y_max != y_min:
            level = int((v - y_min) / step)
            level = min(max(level, 0), height)
            grid[height - level][i] = '* '
        else:
            grid[height // 2][i] = '* '

    # Dibujar gráfico con puntos
    for level in range(height + 1):
        threshold = y_min + step * (height - level)
        line = f"{int(threshold):4} | "
        for col in grid[level]:
            line += col
        print(line)

    # Eje X simplificado
    print("     +" + "---" * samples)
    print("       ", end="")
    for i in range(samples):
        print(f"{i%10}  ", end="")
    print("\n")

    print("Últimos valores:", data_20s[-5:])
    print(f"ASCII de 20s generado ✓\n")

# Gráfica 2: 40 segundos (dos tercios)
samples_40s = 2 * (total_samples // 3)
data_40s = combined_values[:samples_40s]

plt.figure(figsize=(12,6))
plt.plot(data_40s, linewidth=2)
plt.title("Todos los datos recogidos - 40 segundos")
plt.xlabel("Índice")
plt.ylabel("Valor")
plt.grid(True)
plt.savefig("plots/dos_sensores_reales_40s.png")
plt.close()

# Gráfica 3: 60 segundos (todos los datos)
data_60s = combined_values

plt.figure(figsize=(12,6))
plt.plot(data_60s, linewidth=2)
plt.title("Todos los datos recogidos - 60 segundos")
plt.xlabel("Índice")
plt.ylabel("Valor")
plt.grid(True)
plt.savefig("plots/dos_sensores_reales_60s.png")
plt.close()

print("✓ 3 gráficas con los 2 sensores reales generadas:")
print(f"  - plots/dos_sensores_reales_20s.png (primer tercio)")
print(f"  - plots/dos_sensores_reales_40s.png (dos tercios)")
print(f"  - plots/dos_sensores_reales_60s.png (todos los datos)")
print(f"  - Total de datos combinados: {len(combined_values)} valores")
PY

echo "[8] Proceso completado. Revisa la carpeta plots/ para ver todas las gráficas."