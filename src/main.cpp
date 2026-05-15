#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include "config.h"

// ── Objects ───────────────────────────────────────────────────────────────────
WiFiClientSecure wifiClient;
PubSubClient     mqtt(wifiClient);
DHT              dht(DHT_PIN, DHT11);

// ── State ─────────────────────────────────────────────────────────────────────
bool          isAutoMode          = true;
int           soilThreshold       = SOIL_AUTO_ON;
int           currentSoilMoisture = 0;
bool          pumpFogState        = false;
bool          lightState          = false;
unsigned long pumpStartTime       = 0;
int           lastMqttState       = 0;

unsigned long lastSensorSend = 0;
unsigned long lastMqttRetry  = 0;
unsigned long lastWifiCheck  = 0;

// Cooldown từng loại alert — tránh spam lên MQTT mỗi 2 giây
unsigned long lastAlertSoilDry  = 0;
unsigned long lastAlertSoilWet  = 0;
unsigned long lastAlertTempHigh = 0;
unsigned long lastAlertHumLow   = 0;
unsigned long lastAlertHumHigh  = 0;

// ── Timeout / interval constants ──────────────────────────────────────────────
const unsigned long SENSOR_INTERVAL   =  2000;  // đọc & publish sensor mỗi 2s
const unsigned long WIFI_TIMEOUT_MS   = 15000;  // chờ WiFi connect tối đa 15s
const unsigned long MQTT_TIMEOUT_MS   = 10000;  // chờ MQTT connect tối đa 10s
const unsigned long MQTT_RETRY_MS     =  5000;  // thử lại MQTT sau 5s nếu thất bại
const unsigned long WIFI_CHECK_MS     = 30000;  // kiểm tra WiFi còn sống mỗi 30s
const unsigned long ALERT_COOLDOWN_MS = 60000;  // cùng loại alert tối thiểu cách 60s

// ── Prototypes ────────────────────────────────────────────────────────────────
bool connectWiFi();
bool connectMQTT();
void maintainConnections();
void mqttCallback(char* topic, byte* payload, unsigned int length);
void sendSensorData();
void handleSafety();
void setRelay(uint8_t pin, bool on, const char* name);
void publishPumpFogStatus();
void publishLightStatus();
void publishDeviceStatuses();
void publishAlert(const char* type, const char* title, const char* message,
                  unsigned long& lastSent);

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  pinMode(RELAY_PUMP_FOG, OUTPUT);
  pinMode(RELAY_LIGHT,    OUTPUT);
  digitalWrite(RELAY_PUMP_FOG, HIGH); // OFF — active LOW
  digitalWrite(RELAY_LIGHT,    HIGH); // OFF

  dht.begin();
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);

  wifiClient.setInsecure(); // TLS không verify cert — OK cho lab
  wifiClient.setHandshakeTimeout(30);
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  mqtt.setKeepAlive(60);
  mqtt.setSocketTimeout(30);
  mqtt.setBufferSize(1024);

  if (connectWiFi()) {
    connectMQTT();
  }
}

// ── Loop ──────────────────────────────────────────────────────────────────────
void loop() {
  // 1. Safety luôn chạy đầu tiên — không bị block bởi network
  handleSafety();

  // 2. Duy trì kết nối non-blocking
  maintainConnections();

  // 3. MQTT loop
  if (mqtt.connected()) {
    mqtt.loop();
  }

  // 4. Đọc và gửi sensor theo interval
  if (millis() - lastSensorSend >= SENSOR_INTERVAL) {
    lastSensorSend = millis();
    sendSensorData();
  }
}

// ── WiFi — có timeout, không block vô hạn ────────────────────────────────────
bool connectWiFi() {
  Serial.printf("[WiFi] Connecting to %s ...\n", WIFI_SSID);
  WiFi.disconnect(true);
  delay(200);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - start >= WIFI_TIMEOUT_MS) {
      Serial.println("[WiFi] TIMEOUT — tiep tuc chay offline");
      WiFi.disconnect();
      return false;
    }
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\n[WiFi] OK — IP: %s\n", WiFi.localIP().toString().c_str());
  return true;
}

// ── MQTT — có timeout, không block vô hạn ────────────────────────────────────
bool connectMQTT() {
  Serial.print("[MQTT] Connecting to HiveMQ...");
  wifiClient.stop();

  unsigned long start = millis();
  while (!mqtt.connected()) {
    if (millis() - start >= MQTT_TIMEOUT_MS) {
      Serial.println("\n[MQTT] TIMEOUT — se thu lai sau");
      return false;
    }
    String clientId = String(MQTT_CLIENT_ID) + "-" + WiFi.macAddress();
    clientId.replace(":", "");

    if (mqtt.connect(clientId.c_str(), MQTT_USER, MQTT_PASSWORD)) {
      lastMqttState = 0;
      Serial.println(" connected!");
      mqtt.subscribe(TOPIC_CMD_PUMP_FOG);
      mqtt.subscribe(TOPIC_CMD_MIST);
      mqtt.subscribe(TOPIC_CMD_LIGHT);
      mqtt.publish(TOPIC_STATUS, "online", true); // retained — Hậu detect offline
      publishDeviceStatuses();
      return true;
    }
    lastMqttState = mqtt.state();
    Serial.printf(" rc=%d, tls_connected=%d, retrying...\n", lastMqttState, wifiClient.connected());
    wifiClient.stop();
    delay(1000);
  }
  return true;
}

// ── Maintain connections — non-blocking, gọi trong loop ──────────────────────
void maintainConnections() {
  unsigned long now = millis();

  // Kiểm tra WiFi mỗi 30s
  if (now - lastWifiCheck >= WIFI_CHECK_MS) {
    lastWifiCheck = now;
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WiFi] Disconnected — reconnecting...");
      connectWiFi();
    }
  }

  // Thử lại MQTT mỗi 5s nếu WiFi có nhưng MQTT mất
  if (WiFi.status() == WL_CONNECTED && !mqtt.connected()) {
    if (now - lastMqttRetry >= MQTT_RETRY_MS) {
      lastMqttRetry = now;
      Serial.printf("[MQTT] Reconnecting... last_state=%d\n", lastMqttState);
      connectMQTT();
    }
  }
}

// ── Safety — luôn chạy dù mất mạng ──────────────────────────────────────────
void handleSafety() {
  if (pumpFogState && (millis() - pumpStartTime >= PUMP_MAX_ON_MS)) {
    Serial.println("[SAFETY] Pump on too long — force OFF");
    setRelay(RELAY_PUMP_FOG, false, "pump");
    pumpFogState = false;
    publishPumpFogStatus();
    // Safety alert: dummy lastSent = 0 để luôn gửi được
    unsigned long dummy = 0;
    publishAlert("critical", "Bom tat khan cap",
                 "Bom chay qua 5 phut, tu dong tat", dummy);
  }
}

// ── MQTT Callback ─────────────────────────────────────────────────────────────
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  char msg[length + 1];
  memcpy(msg, payload, length);
  msg[length] = '\0';
  Serial.printf("[MQTT IN] %s -> %s\n", topic, msg);

  bool turnOn = (strcmp(msg, "ON") == 0);

  if (strcmp(topic, TOPIC_CMD_PUMP_FOG) == 0 || strcmp(topic, TOPIC_CMD_MIST) == 0) {
    setRelay(RELAY_PUMP_FOG, turnOn, "pump_fog");
    pumpFogState = turnOn;
    if (turnOn) pumpStartTime = millis();
    publishPumpFogStatus();
  }
  else if (strcmp(topic, TOPIC_CMD_LIGHT) == 0) {
    setRelay(RELAY_LIGHT, turnOn, "light");
    lightState = turnOn;
    publishLightStatus();
  }
}

// ── Đọc sensor & gửi MQTT ────────────────────────────────────────────────────
void sendSensorData() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();

  // Soil — dùng SOIL_RAW_DRY / SOIL_RAW_WET từ config.h sau khi calibrate
  int rawSoil = analogRead(SOIL_PIN);
  currentSoilMoisture = map(rawSoil, 4095, 1500, 0, 100);
  currentSoilMoisture = constrain(currentSoilMoisture, 0, 100);
  Serial.printf("[Sensor] Raw: %d | Soil: %d%%\n", rawSoil, currentSoilMoisture);

  // Chỉ publish khi MQTT đang kết nối
  if (!mqtt.connected()) {
    Serial.println("[Sensor] MQTT offline — skip publish");
    // Vẫn chạy auto mode và safety dù không publish được
    goto run_auto;
  }

  if (!isnan(t)) {
    char buf[8]; dtostrf(t, 4, 1, buf);
    mqtt.publish(TOPIC_TEMP, buf);
    Serial.printf("[Sensor] Temp: %s C\n", buf);
  }
  if (!isnan(h)) {
    char buf[8]; dtostrf(h, 4, 1, buf);
    mqtt.publish(TOPIC_HUMIDITY, buf);
    Serial.printf("[Sensor] Humidity: %s%%\n", buf);
  }
  {
    char buf[8]; itoa(currentSoilMoisture, buf, 10);
    mqtt.publish(TOPIC_SOIL, buf);
  }

  // Alerts với cooldown 60s mỗi loại
  if (currentSoilMoisture < SOIL_ALERT_DRY)
    publishAlert("critical", "Dat qua kho", "Do am dat duoi 20%", lastAlertSoilDry);

  if (currentSoilMoisture > SOIL_ALERT_WET)
    publishAlert("warning", "Dat qua am", "Do am dat tren 80%", lastAlertSoilWet);

  if (!isnan(t) && t > TEMP_ALERT_HIGH) {
    if (lightState) {
      setRelay(RELAY_LIGHT, false, "light");
      lightState = false;
      publishLightStatus();
    }
    publishAlert("critical", "Nhiet do cao", "Nhiet do tren 35C, da tat den", lastAlertTempHigh);
  }

  if (!isnan(h) && h < HUM_ALERT_LOW)
    publishAlert("warning", "Do am KK thap", "Do am khong khi duoi 40%", lastAlertHumLow);

  if (!isnan(h) && h > HUM_ALERT_HIGH)
    publishAlert("warning", "Do am KK cao", "Do am khong khi tren 85%", lastAlertHumHigh);

run_auto:
  // Auto mode logic — chạy dù có hay không có mạng
  if (isAutoMode) {
    if (currentSoilMoisture < soilThreshold && !pumpFogState) {
      setRelay(RELAY_PUMP_FOG, true, "pump_fog");
      pumpFogState  = true;
      pumpStartTime = millis();
      publishPumpFogStatus();
      Serial.println("[AUTO] Soil dry — pump ON");
    } else if (currentSoilMoisture > (soilThreshold + 10) && pumpFogState) {
      setRelay(RELAY_PUMP_FOG, false, "pump_fog");
      pumpFogState = false;
      publishPumpFogStatus();
      Serial.println("[AUTO] Soil OK — pump OFF");
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
void setRelay(uint8_t pin, bool on, const char* name) {
  digitalWrite(pin, on ? LOW : HIGH);
  Serial.printf("[Relay] %s -> %s\n", name, on ? "ON" : "OFF");
}

void publishPumpFogStatus() {
  if (!mqtt.connected()) return;
  const char* state = pumpFogState ? "ON" : "OFF";
  mqtt.publish(TOPIC_STATUS_PUMP, state, true);
  mqtt.publish(TOPIC_STATUS_MIST, state, true);
}

void publishLightStatus() {
  if (!mqtt.connected()) return;
  mqtt.publish(TOPIC_STATUS_LIGHT, lightState ? "ON" : "OFF", true);
}

void publishDeviceStatuses() {
  publishPumpFogStatus();
  publishLightStatus();
}

// lastSent truyền bằng reference — mỗi loại alert dùng biến riêng
void publishAlert(const char* type, const char* title, const char* message,
                  unsigned long& lastSent) {
  unsigned long now = millis();
  if (now - lastSent < ALERT_COOLDOWN_MS) return; // còn trong cooldown
  if (!mqtt.connected()) return;

  lastSent = now;

  StaticJsonDocument<200> doc;
  doc["type"]    = type;
  doc["title"]   = title;
  doc["message"] = message;
  doc["ts"]      = now;
  char buf[200];
  serializeJson(doc, buf);
  mqtt.publish(TOPIC_ALERTS, buf);
  Serial.printf("[Alert] %s: %s\n", title, message);
}
