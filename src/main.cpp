#include <Arduino.h>
#include "DHT.h"

// --- KHAI BÁO CHÂN ---
#define SOIL_PIN 32   // Cảm biến độ ẩm đất
#define DHT_PIN 26    // Cảm biến nhiệt độ, độ ẩm không khí
#define FOG_RELAY 25  // Relay 1: Máy phun sương
#define PUMP_RELAY 27 // Relay 2: Máy bơm

// --- CẤU HÌNH ---
#define DHTTYPE DHT11
DHT dht(DHT_PIN, DHTTYPE);

// Hiệu chuẩn cảm biến đất (số này thay đổi tùy loại đất và cảm biến)
const int DRY_VAL = 4095;
const int WET_VAL = 1500;

void setup()
{
  Serial.begin(115200);
  dht.begin();

  pinMode(SOIL_PIN, INPUT);

  // Thiết lập Relay
  pinMode(FOG_RELAY, OUTPUT);
  pinMode(PUMP_RELAY, OUTPUT);

  // Tắt Relay khi khởi động (Mức HIGH là OFF với module Relay tích cực mức thấp)
  digitalWrite(FOG_RELAY, HIGH);
  digitalWrite(PUMP_RELAY, HIGH);

  Serial.println("He thong Cham soc Cay trong san sang!");
}

void loop()
{
  // 1. Đọc dữ liệu từ DHT11
  float humidityAir = dht.readHumidity();
  float tempAir = dht.readTemperature();

  // 2. Đọc độ ẩm đất
  int soilRaw = analogRead(SOIL_PIN);
  int soilPercent = map(soilRaw, DRY_VAL, WET_VAL, 0, 100);
  soilPercent = constrain(soilPercent, 0, 100);

  // Kiểm tra cảm biến DHT
  if (isnan(humidityAir) || isnan(tempAir))
  {
    Serial.println("Loi: Khong doc duoc DHT11!");
  }
  else
  {
    Serial.printf("T: %.1fC | Am KK: %.1f%% | Am Dat: %d%%\n", tempAir, humidityAir, soilPercent);
  }

  // 3. Logic điều khiển Máy Phun Sương (Relay 1 - GPIO 25)
  // Bật khi độ ẩm không khí dưới 60%, tắt khi trên 75%
  if (humidityAir < 60.0)
  {
    digitalWrite(FOG_RELAY, LOW); // Bật phun sương
    Serial.println("-> Dang PHUN SUONG...");
  }
  else if (humidityAir > 75.0)
  {
    digitalWrite(FOG_RELAY, HIGH); // Tắt phun sương
  }

  // 4. Logic điều khiển Máy Bơm (Relay 2 - GPIO 27)
  // Bật khi độ ẩm đất dưới 40%, tắt khi trên 80%
  if (soilPercent < 40)
  {
    digitalWrite(PUMP_RELAY, LOW); // Bật máy bơm
    Serial.println("-> Dang BOM NUOC...");
  }
  else if (soilPercent > 80)
  {
    digitalWrite(PUMP_RELAY, HIGH); // Tắt máy bơm
  }

  Serial.println("-----------------------------------");
  delay(2000); // Đợi 2 giây giữa các lần đo
}