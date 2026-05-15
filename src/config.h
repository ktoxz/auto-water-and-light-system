#pragma once

// WiFi — giữ nguyên từ code Blynk cũ
#define WIFI_SSID "Ktoxz"
#define WIFI_PASSWORD "12345678"

// HiveMQ Cloud — lấy từ Hậu
#define MQTT_HOST "516ba4ca2219465e88a2db2e3aa47f21.s1.eu.hivemq.cloud"
#define MQTT_PORT 8883
#define MQTT_USER "smart-home-cloud"
#define MQTT_PASSWORD "Cloud123456"
#define MQTT_CLIENT_ID "esp32-smarthome-khoi"

// MQTT Topics — Flutter app dùng cùng các topic này
#define TOPIC_TEMP "home/temp"
#define TOPIC_HUMIDITY "home/humidity"
#define TOPIC_SOIL "home/soil"
#define TOPIC_CMD_PUMP_FOG "home/pump/control"
#define TOPIC_CMD_MIST "home/mist/control"
#define TOPIC_CMD_LIGHT "home/led/control"
#define TOPIC_STATUS "home/status/esp32"
#define TOPIC_STATUS_PUMP "home/pump/status"
#define TOPIC_STATUS_MIST "home/mist/status"
#define TOPIC_STATUS_LIGHT "home/led/status"

// Pin map — GIỮ NGUYÊN từ code Blynk cũ
#define SOIL_PIN 32
#define DHT_PIN 26
#define RELAY_PUMP_FOG 25 // Relay bơm + phun sương
#define RELAY_LIGHT 27    // Relay đèn

// Ngưỡng cảnh báo — giữ logic auto từ code Blynk cũ
#define SOIL_AUTO_ON 40         // % — bật bơm khi đất khô hơn này
#define SOIL_AUTO_OFF 50        // % — tắt bơm khi đủ ẩm (40+10 như cũ)
#define SOIL_ALERT_DRY 20       // %
#define SOIL_ALERT_WET 80       // %
#define TEMP_ALERT_HIGH 35      // °C
#define HUM_ALERT_LOW 40        // %
#define HUM_ALERT_HIGH 85       // %
#define PUMP_MAX_ON_MS 300000UL // 5 phút safety cutoff
