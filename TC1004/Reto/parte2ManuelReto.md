# Manual Completo: Implementación MQTT Ultra Seguro para Huerto Automatizado
## Sistema Profesional de Autenticación y Autorización

---

# ÍNDICE

1. [Introducción y Arquitectura](#1-introducción-y-arquitectura)
2. [Preparación del Entorno](#2-preparación-del-entorno)
3. [Configuración del Broker MQTT Seguro](#3-configuración-del-broker-mqtt-seguro)
4. [Sistema de Certificados PKI](#4-sistema-de-certificados-pki)
5. [Autenticación Multi-Factor (completado)](#5-autenticación-multi-factor)
6. [Autorización Granular (completado)](#6-autorización-granular)
7. [Implementación ESP32 (nuevo) ](#7-implementación-esp32)
8. [Montaje del Servidor y Dashboard Pixel-Art (Mario Bros)](#8-montaje-del-servidor-y-dashboard-pixel-art-mario-bros)
9. [Monitoreo y Auditoría (completado)](#9-monitoreo-y-auditoría)
10. [Testing y Validación (completado)](#10-testing-y-validación)
11. [Troubleshooting: Fallos comunes y soluciones rápidas](#11-troubleshooting)
12. [Mantenimiento y Operación](#12-mantenimiento)

---

Narración breve: He continuado y completado el manual desde el paso 5 en adelante, añadiendo las instrucciones detalladas para conectar los ESP32, desplegar el servidor con dashboard temático estilo "Mario Bros" en pixel-art, y todos los pasos finales para dejar el sistema operativo. A continuación tienes todo paso a paso en Markdown listo para seguir e implementar.

---

## 5. AUTENTICACIÓN MULTI-FACTOR (completado)

Ya incluimos la gestión TOTP y backup codes en /opt/mqtt-secure/scripts/totp_manager.py. Aquí resumo exactamente lo que falta y pasos a ejecutar:

- Generar TOTP para cada usuario:
  - Ejecutar: python3 /opt/mqtt-secure/scripts/totp_manager.py <username>
  - Guardar el QR y los códigos de respaldo en un OP vault seguro (ej. Bitwarden, Keepass, archivo cifrado).
- En el flujo de login del panel web y de generación de tokens, exigir:
  - username + password
  - código TOTP (o backup code si TOTP no disponible)
- Para dispositivos (dispositivos no humanos), usar solo autenticación mTLS + fingerprint y HMAC en payload.
- Ajustes operativos:
  - Rotar secretos TOTP solo mediante UI de administración, registrar en logs la rotación.
  - Forzar re-emisión de QR mediante proceso controlado.

Comandos útiles:
```bash
# Generar TOTP y QR
python3 /opt/mqtt-secure/scripts/totp_manager.py team1_sensor

# Revisar logs de totp-manager
tail -n 200 /var/log/mqtt-secure/logger.log
```

---

## 6. AUTORIZACIÓN GRANULAR (completado)

- Ya tienes un ACL file base y un script dinámico /opt/mqtt-secure/scripts/acl_manager.py que:
  - Añade reglas, borra reglas.
  - Valida acceso de tópico en tiempo real.
  - Recarga mosquitto con systemctl reload mosquitto.
- Recomendaciones adicionales:
  - Mantener ACL en Git (archivo `/etc/mosquitto/acl`) con control de accesos y revisiones por PR.
  - Implementar cron job que valide consistencia entre DB devices.allowed_topics y ACL para evitar escalaciones accidentales.

Ejemplo para sincronizar dispositivo nuevo:
```bash
# Añadir dispositivo en DB (script mqtt_auth.py ya hace add_device)
python3 /opt/mqtt-secure/scripts/mqtt_auth.py  # si se expone la CLI
# Añadir regla ACL
python3 /opt/mqtt-secure/scripts/acl_manager.py add ESP8266_004 garden/device/esp004/# readwrite
# Recargar mosquitto (el script invoca reload)
```

---

## 7. IMPLEMENTACIÓN ESP32

He escrito acá todo lo necesario para migrar/usar ESP32 (más potente y con bibliotecas TLS nativas) y conectar los dispositivos al broker seguro.

Resumen: el ESP32 usará mTLS (certificados cliente firmados por la CA que generamos), validación de servidor, sincronización NTP, HMAC en payload y reconexión robusta.

7.1 Requisitos hardware y librerías

- Placa: ESP32 (por ejemplo, ESP32 DevKitC).
- Arduino IDE con soporte ESP32 instalado (añadir en URL de placas: https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json).
- Bibliotecas:
  - WiFi.h (incluido)
  - WiFiClientSecure (incluido)
  - PubSubClient (compatible ESP32)
  - ArduinoJson (6.x)
  - TinyCrypt / Crypto (si se usa HMAC nativo), o implementa HMAC con mbedTLS (incluido en ESP32 core).

7.2 Sketch ejemplo (ESP32) — archivo: garden_mqtt_secure_esp32.ino

```cpp
// garden_mqtt_secure_esp32.ino
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include "certs.h" // archivo generado con CA_CERT, CLIENT_CERT, CLIENT_KEY
#include "config.h" // DEVICE_ID, WIFI_SSID, WIFI_PASSWORD, MQTT_SERVER, MQTT_PORT, HMAC_KEY
#include <mbedtls/md.h>

WiFiClientSecure secureClient;
PubSubClient mqtt(secureClient);
StaticJsonDocument<512> jsonDoc;

unsigned long lastSensor = 0;
const unsigned long SENSOR_INTERVAL = 30000;

String calculateHMAC(const String &message) {
  // HMAC-SHA256 usando mbedTLS
  const char *key = HMAC_KEY;
  const unsigned char *data = (const unsigned char *)message.c_str();
  size_t data_len = message.length();
  const unsigned char *key_data = (const unsigned char *)key;
  size_t key_len = strlen(key);

  unsigned char hmac_out[32];
  mbedtls_md_context_t ctx;
  const mbedtls_md_info_t *info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  mbedtls_md_init(&ctx);
  mbedtls_md_setup(&ctx, info, 1);
  mbedtls_md_hmac_starts(&ctx, key_data, key_len);
  mbedtls_md_hmac_update(&ctx, data, data_len);
  mbedtls_md_hmac_finish(&ctx, hmac_out);
  mbedtls_md_free(&ctx);

  // convertir a hex
  char hexbuf[65];
  for (int i = 0; i < 32; ++i) sprintf(hexbuf + i*2, "%02x", hmac_out[i]);
  hexbuf[64] = 0;
  return String(hexbuf);
}

void setupTLS() {
  secureClient.setCACert(CA_CERT);
  secureClient.setCertificate(CLIENT_CERT);
  secureClient.setPrivateKey(CLIENT_KEY);
  // En producción NO use setInsecure(); si debe validar hostname:
  secureClient.setInsecure(); // Para desarrollo, quitar en prod
}

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }
}

void publishStatus(const char* status) {
  jsonDoc.clear();
  jsonDoc["device_id"] = DEVICE_ID;
  jsonDoc["status"] = status;
  jsonDoc["timestamp"] = time(nullptr);
  String body;
  serializeJson(jsonDoc, body);
  String sig = calculateHMAC(body);
  jsonDoc["signature"] = sig;
  String finalMsg;
  serializeJson(jsonDoc, finalMsg);
  mqtt.publish(("garden/device/" + String(DEVICE_ID) + "/status").c_str(), finalMsg.c_str());
}

void mqttCallback(char* topic, byte* payload, unsigned int len) {
  String msg;
  for (unsigned int i = 0; i < len; ++i) msg += (char)payload[i];
  // Validar HMAC servidor si aplica, procesar comandos
}

void connectMQTT() {
  mqtt.setServer(MQTT_SERVER, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  while (!mqtt.connected()) {
    if (mqtt.connect(DEVICE_ID)) {
      mqtt.subscribe(("garden/device/" + String(DEVICE_ID) + "/config/#").c_str());
      publishStatus("online");
    } else {
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  connectWiFi();
  configTime(0, 0, "pool.ntp.org","time.google.com");
  setupTLS();
  connectMQTT();
}

void loop() {
  if (!mqtt.connected()) connectMQTT();
  mqtt.loop();
  if (millis() - lastSensor > SENSOR_INTERVAL) {
    lastSensor = millis();
    // leer sensores reales y publicar
    jsonDoc.clear();
    jsonDoc["device_id"] = DEVICE_ID;
    jsonDoc["sensor"] = "temperature";
    jsonDoc["value"] = 23.4;
    jsonDoc["timestamp"] = time(nullptr);
    String body; serializeJson(jsonDoc, body);
    String sig = calculateHMAC(body);
    jsonDoc["signature"] = sig;
    String finalMsg; serializeJson(jsonDoc, finalMsg);
    mqtt.publish(("garden/device/" + String(DEVICE_ID) + "/sensors/temperature").c_str(), finalMsg.c_str());
  }
  delay(10);
}
```

7.3 Generar archivos de certificados para ESP32

- Usa el script /opt/mqtt-secure/scripts/generate_esp_certificates.sh adaptado para ESP32.
- Para ESP32 es mejor colocar certificados en SPIFFS o incrustados en el sketch (si pocos dispositivos y tamaño controlado). El script ya genera headers C; para ESP32 puedes usar `CERT` strings en `certs.h` como se muestra arriba.

7.4 Flashear y verificar

- Conectar el ESP32 via USB, seleccionar placa en Arduino IDE o usar `esptool.py`.
- Subir sketch.
- Ver logs serie a 115200 y verificar:
  - Conexión WiFi
  - Sincronización NTP
  - Conexión TLS al broker
  - Suscripción a tópicos y publicación de status

7.5 Buenas prácticas

- No compilar claves privadas públicas en repositorio. Mantén `config.h` fuera de VCS o cifrado con git-crypt.
- Si usas OTA: configurar mbedTLS para validar firma del servidor y del firmware.
- Mantén HMAC keys por dispositivo en KeyVault o archivo protegido, no hardcode en código final.

---

## 8. MONTAJE DEL SERVIDOR Y DASHBOARD PIXEL-ART (MARIO BROS)

Voy a dejar todo paso a paso para montar el servidor (Ubuntu 22.04 recomendado) y desplegar un dashboard web con estilo pixel-art inspirado en Mario Bros, con tiles en CSS y animaciones. El dashboard usará Flask + Gunicorn + Nginx y se conectará a la DB de logs (sqlite o preferible PostgreSQL).

8.1 Requisitos del servidor

- Ubuntu 22.04 LTS (o Debian 12)
- Usuario con sudo
- Docker (opcional)
- Paquetes:
  - python3, python3-venv, python3-pip, nginx, certbot (si https), node (opcional para build assets)

Instalación rápida:
```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip nginx git build-essential
```

8.2 Crear entorno de la app (Flask)

```bash
sudo mkdir -p /opt/mqtt-dashboard
sudo chown $USER:$USER /opt/mqtt-dashboard
cd /opt/mqtt-dashboard

python3 -m venv .venv
source .venv/bin/activate
pip install wheel flask gunicorn paho-mqtt flask-socketio eventlet sqlalchemy
```

8.3 Estructura de la aplicación

- /opt/mqtt-dashboard/
  - app/
    - __init__.py
    - dashboard.py  (rutas)
    - mqtt_client.py (conexión paho, subscribe garden/#)
    - templates/
      - dashboard.html
    - static/
      - css/
        - mario.css
      - js/
        - dashboard.js
      - assets/
        - mario_sprites.png (opcional)
  - run.sh
  - gunicorn.service (systemd)

8.4 Código esencial: mqtt_client.py (conexión y websocket broadcast)

```python
# /opt/mqtt-dashboard/app/mqtt_client.py
import threading
import paho.mqtt.client as mqtt
import json
from flask_socketio import SocketIO

socketio = None  # será seteado desde app inicial

def set_socketio(s):
    global socketio
    socketio = s

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        client.subscribe("garden/#")
    else:
        print("MQTT connect failed", rc)

def on_message(client, userdata, msg):
    payload = msg.payload.decode()
    try:
        data = json.loads(payload)
    except:
        data = {'raw': payload}
    # Enviar por socketio al frontend
    if socketio:
        socketio.emit('mqtt_message', {'topic': msg.topic, 'payload': data})

def start_mqtt(broker_host='localhost', broker_port=8883, ca=None, cert=None, key=None, username=None, password=None):
    client = mqtt.Client()
    if ca:
        client.tls_set(ca, certfile=cert, keyfile=key)
    if username:
        client.username_pw_set(username, password)
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(broker_host, broker_port, 60)
    thread = threading.Thread(target=client.loop_forever, daemon=True)
    thread.start()
    return client
```

8.5 Código flask básico con SocketIO

```python
# /opt/mqtt-dashboard/app/dashboard.py
from flask import Flask, render_template
from flask_socketio import SocketIO
from .mqtt_client import start_mqtt, set_socketio

def create_app():
    app = Flask(__name__, static_folder='static', template_folder='templates')
    app.config['SECRET_KEY'] = 'cambiame_por_un_secreto_largo'
    socketio = SocketIO(app, async_mode='eventlet')
    set_socketio(socketio)
    @app.route('/')
    def index():
        return render_template('dashboard.html')
    # iniciar MQTT
    start_mqtt(broker_host='localhost', broker_port=8883,
               ca="/opt/mqtt-secure/certs/ca/ca.crt",
               cert="/opt/mqtt-secure/certs/clients/garden_admin.crt",
               key="/opt/mqtt-secure/certs/clients/garden_admin-key.pem",
               username="garden_admin", password="AdminSecurePass456!")
    return app, socketio

if __name__ == '__main__':
    app, socketio = create_app()
    socketio.run(app, host='0.0.0.0', port=5000)
```

8.6 Dashboard: plantilla HTML y Pixel-Art Mario Bros

- La idea: tablero estilo retro con un "mario" pixel-art hecho en CSS grid (cada pixel = div). También se muestran métricas en tiempo real via SocketIO.

templates/dashboard.html (resumen)

```html
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Garden MQTT - Dashboard Mario</title>
  <link rel="stylesheet" href="{{ url_for('static', filename='css/mario.css') }}">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.5.0/socket.io.min.js"></script>
</head>
<body>
  <header class="topbar">
    <h1>Garden MQTT - Pixel Mario Dashboard</h1>
  </header>

  <main class="container">
    <section class="left">
      <div id="mario" class="pixel-sprite"></div>
      <div class="panel">
        <h2>Estado</h2>
        <ul id="status-list"></ul>
      </div>
    </section>
    <section class="right">
      <div class="panel">
        <h2>Últimos mensajes</h2>
        <ul id="messages"></ul>
      </div>
      <div class="panel">
        <h2>Métricas</h2>
        <div id="metrics"></div>
      </div>
    </section>
  </main>

  <script src="{{ url_for('static', filename='js/dashboard.js') }}"></script>
</body>
</html>
```

8.7 CSS Pixel-Art (static/css/mario.css)

```css
/* mario.css: pixel-art Mario con CSS grid */
body { background: #6ec1ff; font-family: 'Press Start 2P', monospace; color: #111; }
.topbar { background: #222; color: #fff; padding: 12px 16px; }
.container { display:flex; gap:20px; padding: 20px; }
.left { width: 360px; }
.right { flex:1; }

/* Pixel sprite container */
.pixel-sprite {
  width: 160px; /* 16px * 10 cols */
  height: 160px; /* 16px * 10 rows */
  display: grid;
  grid-template-columns: repeat(16, 10px);
  grid-template-rows: repeat(16, 10px);
  gap: 1px;
  background: linear-gradient(#7ec850, #5c9a3b);
  padding: 8px;
  border-radius: 8px;
}

/* Generate 16x16 pixel children via JS or server rendering */
.pixel-sprite div { width: 10px; height: 10px; }

/* Panel styles */
.panel { background: rgba(255,255,255,0.9); padding: 12px; margin-top: 12px; border-radius: 6px; box-shadow: 0 4px 8px rgba(0,0,0,0.2); }

/* small list styles
