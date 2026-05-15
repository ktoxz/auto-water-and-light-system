#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include "config.h"

// ── Objects ──────────────────────────────────────────────────────────────────
WiFiClientSecure wifiClient;
PubSubClient mqtt(wifiClient);
DHT dht(DHT_PIN, DHT11);

// ── State — giữ nguyên biến từ code Blynk cũ ────────────────────────────────
bool isAutoMode = true;
int soilThreshold = SOIL_AUTO_ON;
int currentSoilMoisture = 0;
bool pumpFogState = false;
bool lightState = false;
unsigned long pumpStartTime = 0;

unsigned long lastSensorSend = 0;
const unsigned long SENSOR_INTERVAL = 2000; // 2 giây — giữ nguyên như Blynk

// ── Prototypes ────────────────────────────────────────────────────────────────
void connectWiFi();
void connectMQTT();
void mqttCallback(char *topic, byte *payload, unsigned int length);
void sendSensorData();
void setRelay(uint8_t pin, bool on, const char *name);
void publishAlert(const char *type, const char *title, const char *message);

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup()
{
  Serial.begin(115200);

  pinMode(RELAY_PUMP_FOG, OUTPUT);
  pinMode(RELAY_LIGHT, OUTPUT);
  // Active-LOW relay — giữ nguyên như code Blynk cũ
  digitalWrite(RELAY_PUMP_FOG, HIGH); // OFF
  digitalWrite(RELAY_LIGHT, HIGH);    // OFF

  dht.begin();
  connectWiFi();

  wifiClient.setInsecure(); // TLS không verify cert — OK cho lab
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  mqtt.setKeepAlive(60);
  mqtt.setBufferSize(512);

  connectMQTT();
}

// ── Loop ──────────────────────────────────────────────────────────────────────
void loop()
{
  if (!mqtt.connected())
    connectMQTT();
  mqtt.loop();

  // Đọc và gửi sensor mỗi 2 giây — giống BlynkTimer cũ
  if (millis() - lastSensorSend >= SENSOR_INTERVAL)
  {
    lastSensorSend = millis();
    sendSensorData();
  }

  // Safety: tắt bơm nếu chạy quá 5 phút
  if (pumpFogState && (millis() - pumpStartTime >= PUMP_MAX_ON_MS))
  {
    Serial.println("[SAFETY] Pump on too long — force OFF");
    setRelay(RELAY_PUMP_FOG, false, "pump");
    pumpFogState = false;
    publishAlert("critical", "Bom tat khan cap", "Bom chay qua 5 phut, tu dong tat");
  }
}

// ── WiFi ──────────────────────────────────────────────────────────────────────
void connectWiFi()
{
  Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\n[WiFi] OK — IP: %s\n", WiFi.localIP().toString().c_str());
}

// ── MQTT connect ──────────────────────────────────────────────────────────────
void connectMQTT()
{
  while (!mqtt.connected())
  {
    Serial.print("[MQTT] Connecting to HiveMQ...");
    if (mqtt.connect(MQTT_CLIENT_ID, MQTT_USER, MQTT_PASSWORD))
    {
      Serial.println(" connected!");

      // Subscribe lệnh điều khiển — tương đương BLYNK_WRITE(V4/V5) cũ
      mqtt.subscribe(TOPIC_CMD_PUMP_FOG);
      mqtt.subscribe(TOPIC_CMD_LIGHT);
      // Nếu sau này tách mist riêng:
      // mqtt.subscribe(TOPIC_CMD_MIST);

      // Báo online (retained — Hậu dùng để detect ESP32 offline)
      mqtt.publish(TOPIC_STATUS, "online", true);
    }
    else
    {
      Serial.printf(" failed (rc=%d), retry in 5s\n", mqtt.state());
      delay(5000);
    }
  }
}

// ── MQTT Callback — thay thế BLYNK_WRITE(V4) và BLYNK_WRITE(V5) ──────────────
void mqttCallback(char *topic, byte *payload, unsigned int length)
{
  char msg[length + 1];
  memcpy(msg, payload, length);
  msg[length] = '\0';
  Serial.printf("[MQTT IN] %s → %s\n", topic, msg);

  bool turnOn = (strcmp(msg, "ON") == 0);

  // home/cmd/pump → tương đương BLYNK_WRITE(V4) cũ
  if (strcmp(topic, TOPIC_CMD_PUMP_FOG) == 0)
  {
    // Nếu đang auto mode, lệnh manual vẫn được chấp nhận (giống Blynk cũ)
    setRelay(RELAY_PUMP_FOG, turnOn, "pump_fog");
    pumpFogState = turnOn;
    if (turnOn)
      pumpStartTime = millis();
  }

  // home/cmd/led → tương đương BLYNK_WRITE(V5) cũ
  else if (strcmp(topic, TOPIC_CMD_LIGHT) == 0)
  {
    setRelay(RELAY_LIGHT, turnOn, "light");
    lightState = turnOn;
  }
}

// ── Đọc sensor & gửi MQTT — thay thế sendSensorData() + Blynk.virtualWrite() ─
void sendSensorData()
{
  // DHT11 — giống code cũ
  float h = dht.readHumidity();
  float t = dht.readTemperature();

  // Soil — GIỮ NGUYÊN công thức map từ code Blynk cũ
  int rawSoil = analogRead(SOIL_PIN);
  currentSoilMoisture = map(rawSoil, 4095, 1500, 0, 100);
  currentSoilMoisture = constrain(currentSoilMoisture, 0, 100);

  // Publish từng giá trị — thay Blynk.virtualWrite bằng mqtt.publish
  if (!isnan(t))
  {
    char buf[8];
    dtostrf(t, 4, 1, buf);
    mqtt.publish(TOPIC_TEMP, buf);
    Serial.printf("[Sensor] Temp: %s C\n", buf);
  }
  if (!isnan(h))
  {
    char buf[8];
    dtostrf(h, 4, 1, buf);
    mqtt.publish(TOPIC_HUMIDITY, buf);
    Serial.printf("[Sensor] Humidity: %s %%\n", buf);
  }
  {
    char buf[8];
    itoa(currentSoilMoisture, buf, 10);
    mqtt.publish(TOPIC_SOIL, buf);
    Serial.printf("[Sensor] Soil: %d %%\n", currentSoilMoisture);
  }

  // Logic Auto — GIỮ NGUYÊN từ code Blynk cũ, chỉ bỏ Blynk.virtualWrite
  if (isAutoMode)
  {
    if (currentSoilMoisture < soilThreshold)
    {
      if (!pumpFogState)
      { // Chỉ bật nếu chưa bật — tránh reset timer
        setRelay(RELAY_PUMP_FOG, true, "pump_fog");
        pumpFogState = true;
        pumpStartTime = millis();
        Serial.println("[AUTO] Soil dry — pump ON");
      }
    }
    else if (currentSoilMoisture > (soilThreshold + 10))
    {
      if (pumpFogState)
      {
        setRelay(RELAY_PUMP_FOG, false, "pump_fog");
        pumpFogState = false;
        Serial.println("[AUTO] Soil wet enough — pump OFF");
      }
    }
  }

  // Cảnh báo ngưỡng — gửi lên home/alerts để Hậu xử lý
  if (currentSoilMoisture < SOIL_ALERT_DRY)
  {
    publishAlert("critical", "Dat qua kho", "Do am dat duoi 20%");
  }
  if (currentSoilMoisture > SOIL_ALERT_WET)
  {
    publishAlert("warning", "Dat qua am", "Do am dat tren 80%");
  }
  if (!isnan(t) && t > TEMP_ALERT_HIGH)
  {
    // Tắt đèn tự động khi nhiệt độ cao — theo plan
    if (lightState)
    {
      setRelay(RELAY_LIGHT, false, "light");
      lightState = false;
    }
    publishAlert("critical", "Nhiet do cao", "Nhiet do tren 35C, da tat den");
  }
  if (!isnan(h) && h < HUM_ALERT_LOW)
  {
    publishAlert("warning", "Do am KK thap", "Do am khong khi duoi 40%");
  }
  if (!isnan(h) && h > HUM_ALERT_HIGH)
  {
    publishAlert("warning", "Do am KK cao", "Do am khong khi tren 85%");
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
void setRelay(uint8_t pin, bool on, const char *name)
{
  // Active-LOW — giữ nguyên như code Blynk cũ
  digitalWrite(pin, on ? LOW : HIGH);
  Serial.printf("[Relay] %s → %s\n", name, on ? "ON" : "OFF");
}

void publishAlert(const char *type, const char *title, const char *message)
{
  StaticJsonDocument<200> doc;
  doc["type"] = type;
  doc["title"] = title;
  doc["message"] = message;
  doc["ts"] = millis(); // Hậu có thể dùng để dedup alert liên tiếp
  char buf[200];
  serializeJson(doc, buf);
  mqtt.publish(TOPIC_ALERTS, buf);
  Serial.printf("[Alert] %s: %s\n", title, message);
}