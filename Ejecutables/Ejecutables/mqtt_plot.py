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