#!/usr/bin/env bash
set -euo pipefail

# install_paho_mqtt.sh
# Instala Eclipse Paho MQTT C (libpaho-mqtt3as) y Paho MQTT C++ (libpaho-mqttpp3) en Ubuntu.
#
# Uso:
#   chmod +x install_paho_mqtt.sh
#   ./install_paho_mqtt.sh
#
# Opcional:
#   PAHO_C_VER=v1.3.13 PAHO_CPP_VER=v1.4.1 CMAKE_POLICY_MIN=3.5 ./install_paho_mqtt.sh
#
# Nota:
# - Si te da el error "Compatibility with CMake < 3.5 has been removed from CMake",
#   este script fuerza la policy mínima con -DCMAKE_POLICY_VERSION_MINIMUM=3.5 (configurable).

PAHO_C_VER="${PAHO_C_VER:-v1.3.13}"
PAHO_CPP_VER="${PAHO_CPP_VER:-v1.4.1}"
CMAKE_POLICY_MIN="${CMAKE_POLICY_MIN:-3.5}"

echo "[1/6] Instalando dependencias..."
sudo apt update
sudo apt install -y build-essential cmake git libssl-dev

WORKDIR="${HOME}/paho_build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[2/6] Clonando/actualizando Paho MQTT C ($PAHO_C_VER)..."
if [[ -d paho.mqtt.c ]]; then
  echo "  - Repo paho.mqtt.c ya existe, actualizando..."
  cd paho.mqtt.c
  git fetch --all --tags
else
  git clone https://github.com/eclipse/paho.mqtt.c.git
  cd paho.mqtt.c
fi

git checkout "$PAHO_C_VER"

echo "[3/6] Compilando e instalando Paho MQTT C (shared, SSL, async)..."
rm -rf build
cmake -B build -S . \
  -DCMAKE_POLICY_VERSION_MINIMUM="${CMAKE_POLICY_MIN}" \
  -DPAHO_WITH_SSL=ON \
  -DPAHO_BUILD_SHARED=ON \
  -DPAHO_BUILD_STATIC=OFF \
  -DPAHO_ENABLE_TESTING=OFF
cmake --build build -j"$(nproc)"
sudo cmake --install build
sudo ldconfig

echo "[4/6] Clonando/actualizando Paho MQTT C++ ($PAHO_CPP_VER)..."
cd "$WORKDIR"
if [[ -d paho.mqtt.cpp ]]; then
  echo "  - Repo paho.mqtt.cpp ya existe, actualizando..."
  cd paho.mqtt.cpp
  git fetch --all --tags
else
  git clone https://github.com/eclipse/paho.mqtt.cpp.git
  cd paho.mqtt.cpp
fi

git checkout "$PAHO_CPP_VER"

echo "[5/6] Compilando e instalando Paho MQTT C++ (shared, SSL)..."
rm -rf build
cmake -B build -S . \
  -DCMAKE_POLICY_VERSION_MINIMUM="${CMAKE_POLICY_MIN}" \
  -DPAHO_BUILD_SHARED=ON \
  -DPAHO_BUILD_STATIC=OFF \
  -DPAHO_MQTT_C_PATH=/usr/local \
  -DPAHO_WITH_SSL=ON
cmake --build build -j"$(nproc)"
sudo cmake --install build
sudo ldconfig

echo "[6/6] Verificando instalación..."
echo "  - Librerías instaladas en el sistema:"
ldconfig -p | grep -E "paho-mqtt3as|paho-mqttpp3" || true

cat <<'EOF'

OK ✅

Ejemplo de compilación (tu código del suscriptor):
  g++ -std=c++17 mqtt_subscribe_emqx.cpp -o mqtt_subscribe_emqx \
    -I/usr/local/include -L/usr/local/lib \
    -lpaho-mqttpp3 -lpaho-mqtt3as -pthread

Notas:
- Si quieres async SIN SSL, usa -lpaho-mqtt3a (sin la 's').
EOF
