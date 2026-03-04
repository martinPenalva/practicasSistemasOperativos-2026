# 📊 Práctica de Captura MQTT y Visualización

## 🎯 Objetivo
Sistema completo para capturar datos de sensores mediante protocolo MQTT y visualizarlos en tiempo real.

---

## 🔧 ¿Qué hace el script?

### Funcionamiento Principal
1. **Captura datos** de 2 sensores MQTT durante 60 segundos
2. **Combina los datos** de ambos sensores en una sola línea
3. **Genera 3 gráficas PNG** (20s, 40s, 60s)
4. **Muestra visualización ASCII** tipo "Montaña Rusa"

### Sensores Monitoreados
- `sensor/data/sen55` - Sensor ambiental
- `sensor/data/gas_sensor` - Sensor de gas

---

## 💻 Requisitos para Ejecutar

### Dependencias Necesarias
```bash
# Python
pip install matplotlib numpy

# Sistema
sudo apt install mosquitto-clients  # Ubuntu/Debian
# o
brew install mosquitto-clients  # macOS
```

### Archivos Necesarios
- `mqtt_subscribe_emqx_linux` - Cliente MQTT
- `mqtt_capture.sh` - Script principal
- Acceso a broker MQTT

---

## 🚀 Cómo Ejecutarlo

### Paso 1: Preparar
```bash
chmod +x mqtt_capture.sh
chmod +x mqtt_subscribe_emqx_linux
```

### Paso 2: Ejecutar
```bash
./mqtt_capture.sh
```

### Paso 3: Seguir Instrucciones
1. **Introduce tiempo** de captura (ej: 10)
2. **Espera** a que se completen las 3 capturas
3. **Revisa resultados** en carpeta `plots/`

---

## 📁 Archivos Generados

### Logs
- `mqtt_capture_1.log` - Primera captura
- `mqtt_capture_2.log` - Segunda captura  
- `mqtt_capture_3.log` - Tercera captura

### Gráficas PNG
- `plots/dos_sensores_reales_20s.png` - Primer tercio
- `plots/dos_sensores_reales_40s.png` - Dos tercios
- `plots/dos_sensores_reales_60s.png` - Todos los datos

---

## 🖼️ Ejemplo de Ejecución

```
===============================
 Captura automática MQTT
===============================
Tiempo de captura (segundos): 10

===============================
 CAPTURA 1 de 3
===============================
[1] Iniciando proceso MQTT...
[2] PID del proceso: 1234
[3] Esperando 10 segundos...
[4] Finalizando proceso con SIGINT...
[5] Proceso finalizado correctamente.

=== 2 SENSORES JUNTOS (ASCII) ===
 494 |             *                       *
   1 | * * * * *   * * *     * * * * *
     +----------------------------------------
       0  1  2  3  4  5  6  7  8  9

✓ 3 gráficas con los 2 sensores reales generadas:
  - plots/dos_sensores_reales_20s.png
  - plots/dos_sensores_reales_40s.png  
  - plots/dos_sensores_reales_60s.png
```

---

## 🎯 Resultado Final

**✅ Captura completa** de datos MQTT  
**✅ Visualización profesional** en PNG y ASCII  
**✅ Control de procesos** con gestión de señales  
**✅ Combinación de sensores** en una sola visualización

---

**Autor:** Martin Peñalva  
**Asignatura:** Sistemas Operativos  
**Fecha:** Marzo 2026
