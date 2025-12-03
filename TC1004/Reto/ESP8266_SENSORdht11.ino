#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
// estos se cambian we
const char* WIFI_SSID = "INFINITUMExcesosdeLENTITUD"; 
const char* WIFI_PASSWORD = "123434";
const char* MQTT_SERVER = "123.123.123.123";  // IP de tu Raspberry Pi
const int MQTT_PORT = 1883;

const char* NOMBRE = "IleanaTapiaCastillo";  // Cambiar por tu nombre
const char* MATRICULA = "A01773374";         // Cambiar por tu matrícula

#define DHTPIN D3        // Pin donde está conectado el DHT11
#define DHTTYPE DHT11    // Tipo de sensor
DHT dht(DHTPIN, DHTTYPE);

// CONFIGURACIÓN MQTT
const char* MQTT_TOPIC = "garden/sensors/data";
WiFiClient espClient;
PubSubClient client(espClient);

// INTERVALO DE PUBLICACIÓN (milisegundos)
const unsigned long INTERVALO_LECTURA = 3000; 
unsigned long ultimaLectura = 0;

// SETUP - SE EJECUTA UNA VEZ AL INICIO
void setup() {
  Serial.begin(115200);
  delay(100);
  
  Serial.println("\n");
  Serial.println("  JARDÍN IoT - ESP8266 + DHT11");
  
  // Inicializar sensor DHT11
  dht.begin();
  Serial.println("✓ Sensor DHT11 inicializado");
  
  // Conectar a WiFi
  conectarWiFi();
  
  // Configurar MQTT
  client.setServer(MQTT_SERVER, MQTT_PORT);
  client.setKeepAlive(120);
  client.setSocketTimeout(30);
  
  Serial.println("Sistema listo. Enviando datos...\n");
}


void conectarWiFi() {
  Serial.print("Conectando a WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int intentos = 0;
  while (WiFi.status() != WL_CONNECTED && intentos < 20) {
    delay(500);
    Serial.print(".");
    intentos++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✓ WiFi conectado");
    Serial.print("✓ IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n✗ Error al conectar WiFi");
    Serial.println("Reiniciando...");
    delay(3000);
    ESP.restart();
  }
}

void reconnectMQTT() {
  if (client.connected()) return;
  
  Serial.print("Conectando a MQTT broker... ");
  
  // Intentar conexión
  String clientId = "ESP8266-" + String(NOMBRE);
  
  if (client.connect(clientId.c_str())) {
    Serial.println("✓ Conectado");
  } else {
    Serial.print("✗ Error (");
    Serial.print(client.state());
    Serial.println(")");
  }
}

void leerYPublicar() {
  // Leer sensor
  float temp = dht.readTemperature();
  float hum = dht.readHumidity();
  
  // Validar lecturas
  if (isnan(temp) || isnan(hum)) {
    Serial.println("⚠ Error al leer sensor DHT11");
    return;
  }
  
  // Construir mensaje: Nombre-Matricula-Temperatura-Humedad
  char mensaje[100];
  snprintf(mensaje, sizeof(mensaje), "%s-%s-%.2f-%.2f", 
           NOMBRE, MATRICULA, temp, hum);
  
  // Publicar por MQTT
  if (client.publish(MQTT_TOPIC, mensaje)) {
    Serial.print("📤 Enviado: ");
    Serial.println(mensaje);
  } else {
    Serial.println("✗ Error al publicar");
  }
}

void loop() {
  // Verificar conexión WiFi
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠ WiFi desconectado. Reconectando...");
    conectarWiFi();
  }
  
  // Mantener conexión MQTT
  if (!client.connected()) {
    reconnectMQTT();
  }
  client.loop();
  
  // Leer y publicar según el intervalo configurado
  unsigned long ahora = millis();
  if (ahora - ultimaLectura >= INTERVALO_LECTURA) {
    ultimaLectura = ahora;
    leerYPublicar();
  }
  
  delay(100);  // Pequeña pausa para estabilidad
}
