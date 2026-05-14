/*
 * Cấu hình Blynk 2.0 - Lấy từ Dashboard của bạn
 */
#define BLYNK_TEMPLATE_ID "TMPL6HyHLPGIw"
#define BLYNK_TEMPLATE_NAME "auto water and light system"
#define BLYNK_AUTH_TOKEN "DEUYGMq7XZ8hzkqMlaryN_voFi3SGTrK"

#include <WiFi.h>
#include <WiFiClient.h>
#include <BlynkSimpleEsp32.h>
#include "DHT.h"

// --- KHAI BÁO CHÂN ---
#define SOIL_PIN 32
#define DHT_PIN 26
#define RELAY_PUMP_FOG 25 // Relay 1
#define RELAY_LIGHT 27    // Relay 2

#define DHTTYPE DHT11
DHT dht(DHT_PIN, DHTTYPE);

// --- BIẾN TOÀN CỤC ---
char auth[] = BLYNK_AUTH_TOKEN;
char ssid[] = "Ktoxz";
char pass[] = "12345678";

bool isAutoMode = true;
int soilThreshold = 40; // Ngưỡng mặc định
int currentSoilMoisture = 0;

BlynkTimer timer;

// --- ĐỌC DỮ LIỆU CẢM BIẾN ---
void sendSensorData()
{
  float h = dht.readHumidity();
  float t = dht.readTemperature();

  int rawSoil = analogRead(SOIL_PIN);
  currentSoilMoisture = map(rawSoil, 4095, 1500, 0, 100);
  currentSoilMoisture = constrain(currentSoilMoisture, 0, 100);

  // Gửi lên Blynk
  Blynk.virtualWrite(V0, t);
  Blynk.virtualWrite(V1, h);
  Blynk.virtualWrite(V2, currentSoilMoisture);

  // Logic Tự động cho Relay 1 (Bơm & Phun sương)
  if (isAutoMode)
  {
    if (currentSoilMoisture < soilThreshold)
    {
      digitalWrite(RELAY_PUMP_FOG, LOW); // Bật
      Blynk.virtualWrite(V4, 1);         // Cập nhật nút nhấn trên App
    }
    else if (currentSoilMoisture > (soilThreshold + 10))
    {                                     // Chống nhiễu nhảy relay liên tục
      digitalWrite(RELAY_PUMP_FOG, HIGH); // Tắt
      Blynk.virtualWrite(V4, 0);
    }
  }
}

// --- NHẬN LỆNH TỪ APP BLYNK ---

// Chế độ Auto/Manual
BLYNK_WRITE(V3)
{
  isAutoMode = param.asInt();
}

// Điều khiển Bơm & Phun sương (Chỉ có tác dụng khi ở Manual)
BLYNK_WRITE(V4)
{
  if (!isAutoMode)
  {
    int relayState = param.asInt();
    digitalWrite(RELAY_PUMP_FOG, relayState == 1 ? LOW : HIGH);
  }
}

// Điều khiển Đèn (Luôn điều khiển bằng tay)
BLYNK_WRITE(V5)
{
  int lightState = param.asInt();
  digitalWrite(RELAY_LIGHT, lightState == 1 ? LOW : HIGH);
}

// Cài đặt ngưỡng độ ẩm từ App
BLYNK_WRITE(V6)
{
  soilThreshold = param.asInt();
}

void setup()
{
  Serial.begin(115200);

  pinMode(RELAY_PUMP_FOG, OUTPUT);
  pinMode(RELAY_LIGHT, OUTPUT);
  digitalWrite(RELAY_PUMP_FOG, HIGH);
  digitalWrite(RELAY_LIGHT, HIGH);

  dht.begin();

  // Kết nối Blynk
  Blynk.begin(auth, ssid, pass);

  // Thiết lập gửi dữ liệu mỗi 2 giây
  timer.setInterval(2000L, sendSensorData);
}

void loop()
{
  Blynk.run();
  timer.run();
}