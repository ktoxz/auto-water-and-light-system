#include <Arduino.h>
const int soilPin = 32;

// Các giá trị này bạn cần hiệu chuẩn thực tế:
// 1. Nhúng cảm biến vào nước để lấy giá trị "Ướt" (thường khoảng 1500)
// 2. Để cảm biến ngoài không khí để lấy giá trị "Khô" (thường khoảng 4095)
const int DRY_VALUE = 4095;
const int WET_VALUE = 1500;

void setup()
{
  Serial.begin(115200);
  pinMode(soilPin, INPUT);
  Serial.println("--- Bắt đầu đo độ ẩm đất (GPIO 32) ---");
}

void loop()
{
  // Đọc giá trị Analog thô (0 - 4095)
  int rawValue = analogRead(soilPin);

  // Chuyển đổi sang phần trăm
  // map(giá trị, khô, ướt, 0%, 100%)
  int moisturePercent = map(rawValue, DRY_VALUE, WET_VALUE, 0, 100);

  // Đảm bảo giá trị luôn nằm trong khoảng 0 - 100
  moisturePercent = constrain(moisturePercent, 0, 100);

  // Xuất dữ liệu ra Serial Monitor
  Serial.print("Giá trị thô: ");
  Serial.print(rawValue);
  Serial.print(" | Độ ẩm: ");
  Serial.print(moisturePercent);
  Serial.println("%");

  delay(2000); // Đợi 2 giây đo một lần cho ổn định
}