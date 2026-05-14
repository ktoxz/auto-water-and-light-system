#include <Arduino.h>

const int soilPin = 32;

const int DRY_VALUE = 4095;
const int WET_VALUE = 1500;

void setup()
{
    Serial.begin(115200);
    pinMode(soilPin, INPUT);
    Serial.println("--- Soil moisture monitor started (GPIO 32) ---");
}

void loop()
{
    int rawValue = analogRead(soilPin);
    int moisturePercent = map(rawValue, DRY_VALUE, WET_VALUE, 0, 100);
    moisturePercent = constrain(moisturePercent, 0, 100);

    Serial.print("Raw: ");
    Serial.print(rawValue);
    Serial.print(" | Moisture: ");
    Serial.print(moisturePercent);
    Serial.println("%");

    delay(2000);
}
