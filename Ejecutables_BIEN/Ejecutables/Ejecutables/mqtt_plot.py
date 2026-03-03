import json
import os
import matplotlib.pyplot as plt

log_file = "mqtt_capture.log"
output_dir = "plots"

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

sen55_data = []
gas_data = []

with open(log_file, "r") as f:
    lines = f.readlines()

current_topic = None

# ===============================
# PARSEO DEL LOG
# ===============================
for line in lines:
    line = line.strip()

    if "Topic:" in line:
        if "sen55" in line:
            current_topic = "sen55"
        elif "gas_sensor" in line:
            current_topic = "gas"

    if "Payload:" in line:
        try:
            payload = line.split("Payload:")[1].strip()
            data = json.loads(payload)

            if current_topic == "sen55":
                sen55_data.append(data)
            elif current_topic == "gas":
                gas_data.append(data)

        except json.JSONDecodeError:
            print("Error parseando JSON")

# ===============================
# REPRESENTACIÓN ASCII ESTILO FIGURA
# ===============================

def print_ascii_plot(data_list, sensor_name, variable):
    if not data_list:
        print(f"\nNo hay datos para {sensor_name}")
        return

    values = [d[variable] for d in data_list if variable in d]

    if not values:
        print(f"No hay valores para {variable}")
        return

    y_min = int(min(values))
    y_max = int(max(values))
    samples = len(values)

    print("\n=== MQTT Payload Plot (ASCII) ===")
    print(f"Sensor={sensor_name} | Variable={variable}")
    print(f"muestras={samples} | y_min={y_min} | y_max={y_max}\n")

    height = 10
    step = (y_max - y_min) / height if y_max != y_min else 1

    # Dibujo del gráfico
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
    print("[✓] Representación completada\n")


# 🔵 Gráfico ASCII (elige variable existente en tu log)
# Ejemplo típico del sensor de gas:
print_ascii_plot(gas_data, "gas", "GM702B")

# ===============================
# GENERACIÓN DE GRÁFICAS PNG
# ===============================

def plot_sensor(data_list, sensor_name):
    if not data_list:
        return

    keys = set()
    for d in data_list:
        for k, v in d.items():
            if isinstance(v, (int, float)):
                keys.add(k)

    for key in keys:
        values = [d[key] for d in data_list if key in d]

        if values:
            plt.figure()
            plt.plot(values)
            plt.title(f"{sensor_name} - {key}")
            plt.xlabel("Muestras")
            plt.ylabel(key)
            plt.grid(True)

            filename = f"{output_dir}/{sensor_name}_{key}.png"
            plt.savefig(filename)
            plt.close()
            print(f"Gráfica guardada en {filename}")


plot_sensor(sen55_data, "sen55")
plot_sensor(gas_data, "gas")

print("\nProceso terminado correctamente.")