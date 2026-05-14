# Kế Hoạch Bài Tập Lớn IoT
## Hệ Thống Chiếu Sáng Thông Minh & Tưới Cây Tự Động Trong Nhà

> **Team:** Hậu & Khôi | **Thời gian:** 3 ngày
> **Hậu:** giữ Raspberry Pi 5 | **Khôi:** giữ toàn bộ linh kiện còn lại

---

## Mục Lục

1. [Linh kiện & Phân công](#linh-kiện--phân-công)
2. [Kiến trúc hệ thống](#kiến-trúc-hệ-thống)
3. [Stack công nghệ đã chốt](#stack-công-nghệ-đã-chốt)
4. [Luồng voice command](#luồng-voice-command)
5. [Hệ thống cảnh báo](#hệ-thống-cảnh-báo)
6. [Ngày 1 — Cài đặt RPi5 + Phần cứng + MQTT](#ngày-1)
7. [Ngày 2 — AI Voice + Telegram Bot + Flutter App](#ngày-2)
8. [Ngày 3 — Tích hợp + Đo thực nghiệm + Demo + Báo cáo](#ngày-3)
9. [Checklist 5 tiêu chí](#checklist-5-tiêu-chí)
10. [Cần chuẩn bị trước Ngày 1](#cần-chuẩn-bị-trước-ngày-1)

---

## Linh Kiện & Phân Công

| Linh kiện | Ai giữ |
|-----------|--------|
| Raspberry Pi 5 8GB + thẻ nhớ 32GB | **Hậu** |
| 2x ESP32 | Khôi |
| Cảm biến nhiệt ẩm DHT11 | Khôi |
| Cảm biến độ ẩm đất | Khôi |
| Máy bơm | Khôi |
| Máy phun sương | Khôi |
| 2x Relay module | Khôi |
| 2x Breadboard | Khôi |
| Cụm pin 3V | Khôi |
| Đèn LED 2 chân + trở | Khôi |

---

## Kiến Trúc Hệ Thống

```
┌─────────────────────────────────────────────────────┐
│              Lớp 1 — Edge / Hardware                │
│  ESP32 #1 (Tưới cây)      ESP32 #2 (Chiếu sáng)    │
│  - Soil sensor            - DHT11                   │
│  - Relay → Máy bơm        - Relay → LED             │
│  - Relay → Phun sương                               │
└──────────────┬──────────────────────┬───────────────┘
               │     MQTT over WiFi   │
┌──────────────▼──────────────────────▼───────────────┐
│         Lớp 2 — Raspberry Pi 5 (Hậu phụ trách)     │
│  Mosquitto Broker  │  Vosk STT     │  Intent Parser │
│  Node-RED          │  Gemini API   │  Telegram Bot  │
│  WebSocket Server  │  AI Alert     │  HiveMQ Bridge │
└──────────────┬──────────────────────────────────────┘
               │  MQTT Bridge (edge-to-cloud)
┌──────────────▼──────────────────────────────────────┐
│              Lớp 3 — HiveMQ Cloud                   │
│         MQTT Broker trung gian (free tier)          │
└──────────────┬──────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────┐
│       Lớp 4 — Flutter App Android (Khôi code)       │
│  Dashboard  │  Điều khiển  │  Voice  │  Cảnh báo   │
└─────────────────────────────────────────────────────┘
```

---

## Stack Công Nghệ Đã Chốt

| Thành phần | Công nghệ | Ghi chú |
|-----------|-----------|---------|
| Speech-to-text (local) | **Vosk** `vosk-model-small-vn-0.4` | Offline, chạy trên RPi5, nhận audio từ mic Flutter |
| Speech-to-text (remote) | **Android STT** built-in | Khi điện thoại khác WiFi, cần internet |
| Intent parsing | **Local intent parser** Python | Offline, xử lý phủ định tiếng Việt |
| NLU fallback | **Gemini API** free tier | Chỉ gọi khi câu mơ hồ + có internet |
| MQTT local broker | **Mosquitto** trên RPi5 | Giao tiếp ESP32 ↔ RPi5 |
| MQTT cloud broker | **HiveMQ Cloud** free | Edge-to-cloud, điều khiển từ xa |
| Điều phối logic | **Node-RED** | Dashboard web local, automation flow |
| Cảnh báo | **Telegram Bot** | 2 chiều: nhận cảnh báo + gửi lệnh |
| Mobile App | **Flutter** Android | 4 màn hình: Dashboard, Điều khiển, Voice, Cảnh báo |
| Audio transport (local) | **WebSocket** | Flutter gửi audio stream lên RPi5 |
| Audio transport (remote) | **MQTT** qua HiveMQ | Flutter gửi text lệnh lên RPi5 |

---

## Luồng Voice Command

### Chế độ Local (cùng WiFi)
```
Mic điện thoại (Flutter)
    → WebSocket → RPi5
    → Vosk nhận dạng tiếng Việt (offline)
    → Local intent parser (xử lý phủ định)
    → [nếu mơ hồ + có internet] Gemini API
    → MQTT → ESP32 thực thi
    → Phản hồi text về Flutter
```

### Chế độ Remote (khác WiFi / 4G)
```
Mic điện thoại (Flutter)
    → Android STT (cần internet điện thoại)
    → MQTT → HiveMQ Cloud → RPi5
    → Local intent parser
    → [nếu mơ hồ] Gemini API
    → MQTT → ESP32 thực thi
    → Phản hồi text về Flutter qua MQTT
```

### Tự động detect mode trong Flutter
- Thử kết nối WebSocket tới IP RPi5 → thành công: **Local mode**
- Thất bại → **Remote mode**
- Người dùng không cần chọn gì, app tự xử lý hoàn toàn

### Bảng các tình huống

| Tình huống | Speech-to-text | Truyền lệnh | Hoạt động? |
|-----------|---------------|------------|-----------|
| Ở gần, có internet | Vosk (RPi5) | WebSocket local | ✅ |
| Ở gần, mất internet | Vosk (RPi5) | WebSocket local | ✅ |
| Ở xa, có internet | Android STT | HiveMQ Cloud | ✅ |
| Ở xa, mất internet | ❌ | ❌ | ❌ |
| Mất WiFi hoàn toàn | ❌ | ❌ | ❌ Future: Bluetooth |

### Xử lý phủ định trong Local Intent Parser

| Câu nói | Xử lý | Kết quả |
|---------|-------|---------|
| "bật đèn" | Rõ ràng | BẬT đèn ✅ |
| "chói quá đừng bật đèn" | Phủ định + bật | Không làm gì ✅ |
| "tối quá rồi bật lên đi" | Không phủ định | BẬT đèn ✅ |
| "cây hơi khô rồi đó" | Confidence thấp | → Gemini API ✅ |
| "thôi tắt bơm đi đủ rồi" | Rõ ràng | TẮT bơm ✅ |

---

## Hệ Thống Cảnh Báo

Tất cả cảnh báo: gửi qua **Telegram** + publish `home/alerts` → Flutter hiển thị trong màn hình Cảnh báo.

### Cảnh báo liên quan đến cây

| Tình huống | Ngưỡng | Hành động tự động | Mức độ |
|-----------|--------|------------------|--------|
| Đất quá khô | Soil < 20% quá 10 phút | Tự động bật bơm | 🔴 Cao |
| Đất quá ẩm | Soil > 80% | Tắt bơm nếu đang chạy | 🟡 Trung bình |
| Tưới tự động kích hoạt | — | Thông báo cho Hậu & Khôi | 🟢 Thông tin |
| Bơm chạy quá lâu | > 5 phút liên tục | Tắt bơm khẩn cấp | 🔴 Cao |

### Cảnh báo liên quan đến môi trường

| Tình huống | Ngưỡng | Hành động tự động | Mức độ |
|-----------|--------|------------------|--------|
| Nhiệt độ quá cao | Temp > 35°C | Tự động tắt đèn | 🔴 Cao |
| Độ ẩm không khí thấp | Humidity < 40% | Tự động bật phun sương | 🟡 Trung bình |
| Độ ẩm không khí cao | Humidity > 85% | Tắt phun sương, cảnh báo nấm mốc | 🟡 Trung bình |

### Cảnh báo hệ thống

| Tình huống | Điều kiện | Mức độ |
|-----------|-----------|--------|
| ESP32 #1 mất kết nối | Không nhận MQTT > 30 giây | 🔴 Cao |
| ESP32 #2 mất kết nối | Không nhận MQTT > 30 giây | 🔴 Cao |

### Format tin nhắn Telegram

```
🔴 [CẢNH BÁO CAO]
📍 Độ ẩm đất quá thấp
💧 Soil: 15% (ngưỡng: 20%)
⏱ 10 phút chưa được tưới
✅ Đã tự động bật máy bơm
🕐 14:32:05 - 13/05/2026
```

```
🟡 [CẢNH BÁO]
🌡 Độ ẩm không khí thấp
💨 Humidity: 35% (ngưỡng: 40%)
✅ Đã tự động bật phun sương
🕐 14:45:10 - 13/05/2026
```

```
🔴 [HỆ THỐNG]
📡 ESP32 #1 mất kết nối
⏱ Không nhận dữ liệu 35 giây
❗ Kiểm tra thiết bị
🕐 15:10:22 - 13/05/2026
```

---

## Ngày 1

### Mục tiêu
Cài xong RPi5 headless + 2 ESP32 hoạt động + luồng MQTT end-to-end thông suốt.

### Phân công

| | Hậu (RPi5) | Khôi (ESP32 + linh kiện) |
|--|-----------|--------------------------|
| Sáng | Cài RPi5 OS headless, SSH, packages | Nối mạch 2 ESP32, test cảm biến Serial Monitor |
| Chiều | Mosquitto, Node-RED, HiveMQ bridge | Firmware MQTT, kết nối HiveMQ Cloud |
| Tối | **Ghép hệ thống, test end-to-end** | **Ghép hệ thống, test end-to-end** |

---

### Buổi Sáng — Hậu: Cài RPi5 Headless

#### Bước 1: Flash Raspberry Pi OS Lite 64-bit
> ⚠️ Làm đúng bước này, sai phải flash lại từ đầu

1. Tải **Raspberry Pi Imager** trên laptop Windows
2. Chọn `Raspberry Pi OS Lite (64-bit)` — không chọn bản có desktop
3. Nhấn biểu tượng **bánh răng → Advanced Settings**:
   - ✅ Enable SSH → Use password authentication
   - Username: `pi` / password tự chọn
   - Hostname: `raspberrypi.local`
   - ✅ Configure wireless LAN → nhập SSID + password WiFi
   - Wireless LAN country: `VN`
4. Flash vào thẻ 32GB → cắm vào RPi5 → bật nguồn → **chờ 60–90 giây**

#### Bước 2: SSH từ laptop vào RPi5
```bash
# Cách 1
ssh pi@raspberrypi.local

# Cách 2: nếu cách 1 không được → dùng Advanced IP Scanner tìm IP
ssh pi@[IP-tìm-được]
```

#### Bước 3: Cài VNC Server (để có desktop khi debug)
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install realvnc-vnc-server -y
sudo raspi-config
# Interface Options → VNC → Enable
```

#### Bước 4: Cài toàn bộ packages
```bash
# Mosquitto
sudo apt install mosquitto mosquitto-clients -y
sudo systemctl enable mosquitto && sudo systemctl start mosquitto

# Node-RED
bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
sudo systemctl enable nodered

# Python
pip install paho-mqtt vosk websockets flask requests pyTelegramBotAPI --break-system-packages

# Model Vosk tiếng Việt (~40MB)
wget https://alphacephei.com/vosk/models/vosk-model-small-vn-0.4.zip
unzip vosk-model-small-vn-0.4.zip
```

---

### Buổi Sáng — Khôi: Nối Mạch Phần Cứng

#### ESP32 #1 — Tưới cây

**Bộ cảm biến độ ẩm đất gồm 2 phần:**
- Đầu dò điện trở (que cắm xuống đất, chữ 土壤湿度检测) → cắm 2 chân vào đầu nối phía trên board LM393
- Board xử lý LM393 (có núm vặn biến trở) → nối vào ESP32

| Linh kiện | Chân ESP32 | Ghi chú |
|-----------|-----------|---------|
| Board LM393 — AO | GPIO34 (ADC) | Giá trị analog 0–4095 → map sang 0–100% độ ẩm |
| Board LM393 — DO | GPIO35 (Digital input) | Interrupt khi vượt ngưỡng vật lý (chỉnh bằng núm vặn) |
| Board LM393 — VCC | 3.3V | |
| Board LM393 — GND | GND | |
| Relay 1 (IN) | GPIO26 | → Máy bơm (nguồn pin 3V) |
| Relay 2 (IN) | GPIO27 | → Máy phun sương |
| LED báo trạng thái | GPIO2 | + trở 220Ω |

> ⚠️ Chỉnh núm vặn biến trở trên board LM393 để đặt ngưỡng DO — khuyến nghị ~30% độ ẩm (đất hơi khô) cho cây trong nhà

**Cách dùng AO và DO:**
- **AO** (polling mỗi 5 giây): đọc giá trị % thực tế → publish `home/soil` → dashboard + cảnh báo thông minh
- **DO** (interrupt): phản hồi tức thì khi đất vượt ngưỡng vật lý → bật bơm ngay không cần chờ polling

#### ESP32 #2 — Chiếu sáng

| Linh kiện | Chân ESP32 | Ghi chú |
|-----------|-----------|---------|
| DHT11 (Data) | GPIO4 | Trở pull-up 10kΩ |
| Relay (IN) | GPIO25 | → LED + trở 220Ω |

> ⚠️ Test từng linh kiện qua Serial Monitor trước khi nối cả mạch

---

### Buổi Chiều — Khôi: Firmware + MQTT

#### Cài Thonny IDE & MicroPython (thay Arduino IDE)
- Tải **Thonny IDE** — miễn phí, hỗ trợ MicroPython sẵn
- Flash MicroPython firmware vào ESP32: vào Tools → Options → Interpreter → MicroPython (ESP32) → Install or update firmware
- Thư viện cần dùng: `umqtt.simple` (có sẵn), `dht` (có sẵn), `json` (built-in) — **không cần cài thêm gì**
- Cấu hình broker: **HiveMQ Cloud** (để Khôi test độc lập không cần RPi5)

#### MQTT Topics

| Topic | Hướng | Mô tả |
|-------|-------|-------|
| `home/soil` | ESP32 → Cloud | Độ ẩm đất (0–100%) |
| `home/temp` | ESP32 → Cloud | Nhiệt độ (°C) |
| `home/humidity` | ESP32 → Cloud | Độ ẩm không khí (%) |
| `home/pump/status` | ESP32 → Cloud | Trạng thái bơm |
| `home/led/status` | ESP32 → Cloud | Trạng thái đèn |
| `home/pump/control` | Cloud → ESP32 | Lệnh điều khiển bơm |
| `home/led/control` | Cloud → ESP32 | Lệnh điều khiển đèn |
| `home/mist/control` | Cloud → ESP32 | Lệnh điều khiển phun sương |
| `home/alerts` | RPi5 → Cloud | Cảnh báo hệ thống |
| `home/voice/command` | Flutter → RPi5 | Text lệnh (remote mode) |
| `home/voice/response` | RPi5 → Flutter | Phản hồi lệnh |

---

### Buổi Chiều — Hậu: HiveMQ Bridge + Node-RED

#### Cấu hình Mosquitto bridge
Thêm vào `/etc/mosquitto/conf.d/bridge.conf`:
```
connection hivemq-bridge
address [YOUR-HIVEMQ-HOST]:8883
bridge_protocol_version mqttv311
remote_username [USERNAME]
remote_password [PASSWORD]
bridge_tls_version tlsv1.3
topic home/# both 0
```

#### Node-RED Dashboard
- Truy cập: `http://[IP-RPi5]:1880`
- Cài thêm: `node-red-dashboard`
- Dashboard: `http://[IP-RPi5]:1880/ui`

### ✅ Checkpoint Ngày 1
- [ ] Hậu SSH vào RPi5 thành công
- [ ] Mosquitto broker chạy ổn định
- [ ] Khôi: ESP32 #1 đọc soil sensor, publish MQTT lên HiveMQ
- [ ] Khôi: ESP32 #2 đọc DHT11, điều khiển LED qua relay
- [ ] Hậu: RPi5 nhận data từ 2 ESP32 qua HiveMQ bridge
- [ ] Node-RED hiển thị dashboard
- [ ] Gửi lệnh từ RPi5 bật tắt relay thành công

---

## Ngày 2

### Mục tiêu
Hoàn thiện AI voice pipeline + Telegram Bot + AI cảnh báo + Flutter App 4 màn hình.

### Phân công

| | Hậu (RPi5) | Khôi (Flutter) |
|--|-----------|----------------|
| Sáng | WebSocket server + Vosk + Intent parser + Gemini | Setup Flutter, màn hình Dashboard + Điều khiển |
| Chiều | Telegram Bot + AI cảnh báo + Autostart | Màn hình Voice + Cảnh báo |
| Tối | **Test tích hợp Flutter ↔ RPi5** | **Test tích hợp Flutter ↔ RPi5** |

---

### Buổi Sáng — Hậu: AI Voice Pipeline

#### Bước 1: WebSocket Server nhận audio
- `websockets` library, port `8765`
- Nhận binary audio: **16kHz, mono, 16-bit PCM**
- Đẩy vào Vosk `KaldiRecognizer` → kết quả text → intent parser

#### Bước 2: Local Intent Parser
```python
NEGATIONS = ["đừng", "không", "thôi", "chưa", "thôi đừng", "chớ"]
DEVICES   = {"đèn": "led", "bơm": "pump", "sương": "mist"}
ACTIONS   = {"bật": "ON", "tắt": "OFF", "tưới": "ON", "mở": "ON", "đóng": "OFF"}
```

| Trường hợp | Xử lý |
|-----------|-------|
| Không phủ định + từ khóa rõ | Thực thi ngay |
| Có phủ định + hành động rõ | Đảo ngược hành động |
| Không khớp / mơ hồ | Confidence thấp → gọi Gemini |

#### Bước 3: Gemini API Fallback
- Chỉ gọi khi confidence thấp **VÀ** có internet
- Timeout: 3 giây → nếu lỗi: `{"action": "unknown"}`
- API key: [aistudio.google.com](https://aistudio.google.com) (miễn phí)

---

### Buổi Chiều — Hậu: Telegram Bot + AI Cảnh Báo + Autostart

#### Telegram Bot — Các lệnh

| Lệnh | Chức năng |
|------|-----------|
| `/status` | Xem toàn bộ sensor realtime |
| `/pump_on` | Bật máy bơm |
| `/pump_off` | Tắt máy bơm |
| `/led_on` | Bật đèn |
| `/led_off` | Tắt đèn |
| `/mist_on` | Bật phun sương |
| `/mist_off` | Tắt phun sương |

#### AI Cảnh Báo — Logic Subscribe MQTT

**Cảnh báo cây:**

| Điều kiện | Ngưỡng | Hành động |
|-----------|--------|-----------|
| Đất quá khô | Soil < 20% / 10 phút | Bật bơm + Telegram 🔴 |
| Đất quá ẩm | Soil > 80% | Tắt bơm + Telegram 🟡 |
| Bơm chạy quá lâu | > 5 phút liên tục | Tắt bơm khẩn cấp + Telegram 🔴 |

**Cảnh báo môi trường:**

| Điều kiện | Ngưỡng | Hành động |
|-----------|--------|-----------|
| Nhiệt độ quá cao | Temp > 35°C | Tắt đèn + Telegram 🔴 |
| Độ ẩm KK thấp | Humidity < 40% | Bật phun sương + Telegram 🟡 |
| Độ ẩm KK cao | Humidity > 85% | Tắt phun sương + Telegram 🟡 |

**Cảnh báo hệ thống:**

| Điều kiện | Ngưỡng | Hành động |
|-----------|--------|-----------|
| ESP32 #1 offline | Không nhận MQTT > 30s | Telegram 🔴 |
| ESP32 #2 offline | Không nhận MQTT > 30s | Telegram 🔴 |

#### Autostart Services
Tạo systemd `.service` cho: `nodered`, `vosk-websocket`, `telegram-bot`, `ai-alert`

---

### Buổi Sáng — Khôi: Flutter Setup + Dashboard + Điều Khiển

#### Packages `pubspec.yaml`
```yaml
dependencies:
  mqtt_client: ^9.7.4
  record: ^5.0.4
  speech_to_text: ^6.6.0
  web_socket_channel: ^2.4.0
  permission_handler: ^11.0.0
  fl_chart: ^0.66.0
  provider: ^6.1.1
```

#### Màn hình 1: Dashboard
- Subscribe: `home/temp`, `home/humidity`, `home/soil`, `home/led/status`, `home/pump/status`
- Gauge nhiệt độ, độ ẩm, card trạng thái thiết bị
- Indicator online/offline cho từng ESP32

#### Màn hình 2: Điều Khiển
- Toggle: Đèn, Bơm, Phun sương → publish MQTT lên HiveMQ
- Nút đổi màu ngay theo trạng thái thực

---

### Buổi Chiều — Khôi: Voice + Cảnh Báo

#### Màn hình 3: Voice Command
```
Thử kết nối WebSocket → IP_RPi5:8765
├── Thành công → LOCAL MODE
│   record package → PCM 16kHz → WebSocket → Vosk RPi5
│   Hiển thị text nhận dạng + phản hồi
└── Thất bại → REMOTE MODE
    speech_to_text → text → MQTT home/voice/command
    Đợi phản hồi từ home/voice/response
```
- Nút mic lớn ở giữa màn hình
- Badge LOCAL / REMOTE hiện mode đang dùng

#### Màn hình 4: Cảnh Báo
- Subscribe `home/alerts`
- List log: timestamp, loại cảnh báo, giá trị sensor, mức độ 🔴🟡🟢
- Badge số đỏ khi có cảnh báo chưa đọc

### ✅ Checkpoint Ngày 2
- [ ] Voice local: "bật đèn" → đèn sáng
- [ ] Voice local: "chói quá đừng bật đèn" → không bật
- [ ] Gemini xử lý câu mơ hồ đúng
- [ ] Đủ 8 loại cảnh báo gửi đúng qua Telegram
- [ ] Telegram `/status` trả về data realtime
- [ ] Flutter dashboard hiển thị sensor realtime
- [ ] Flutter điều khiển đèn/bơm từ xa thành công
- [ ] Voice hoạt động cả local lẫn remote mode

---

## Ngày 3

### Mục tiêu
Tích hợp hoàn chỉnh, đo thực nghiệm, quay demo, viết báo cáo.

### Phân công

| | Hậu | Khôi |
|--|-----|------|
| Sáng | Fix bug, autostart, đo thực nghiệm | Test phần cứng lần cuối, chuẩn bị kịch bản demo |
| Chiều | Viết phần AI + Cloud trong báo cáo | Quay video demo, viết phần cứng + thực nghiệm |

---

### Buổi Sáng — Đo Lường Thực Nghiệm

| Chỉ số | Phương pháp | Kết quả mong đợi |
|--------|------------|-----------------|
| Latency MQTT local | Timestamp publish → subscribe | < 50ms |
| Latency MQTT cloud | Timestamp publish → HiveMQ → nhận | < 300ms |
| Vosk accuracy | Test 10 câu lệnh tiếng Việt | > 75% |
| Intent parser accuracy | Test 10 câu có phủ định | > 90% |
| Gemini fallback accuracy | Test 5 câu mơ hồ | > 90% |
| Telegram cảnh báo | Trigger → nhận tin | < 3 giây |
| Local vs Remote latency | So sánh 2 mode voice | Ghi thực tế |
| Độ chính xác cảnh báo | Trigger 5 lần mỗi loại | 100% |
| Uptime hệ thống | Chạy liên tục 30 phút | 100% |

---

### Buổi Chiều — Kịch Bản Demo (3–5 phút)

1. **AI Voice local** — Hậu nói `"chói quá đừng bật đèn"` → không bật
2. **AI Voice local** — nói `"tưới cây đi"` → máy bơm chạy
3. **Gemini fallback** — nói câu mơ hồ → hiển thị Gemini xử lý
4. **Cảnh báo đất khô** — để soil < 20% → tự tưới + Telegram
5. **Cảnh báo nhiệt độ** — mô phỏng > 35°C → tắt đèn + Telegram
6. **Telegram Bot** — Khôi gõ `/status` → nhận data realtime
7. **Flutter Dashboard** — sensor realtime
8. **Flutter Điều khiển** — Khôi tắt đèn từ điện thoại (khác WiFi)
9. **Flutter Voice remote** — nói lệnh qua 4G → thực thi
10. **Node-RED Dashboard** — biểu đồ lịch sử sensor

---

### Cấu Trúc Báo Cáo

```
1. Giới thiệu đề tài
2. Kiến trúc hệ thống (sơ đồ 4 lớp)
3. Phần cứng
   3.1 Danh sách linh kiện
   3.2 Sơ đồ nối dây ESP32 #1 — tưới cây
   3.3 Sơ đồ nối dây ESP32 #2 — chiếu sáng
4. Tích hợp AI                             ← TIÊU CHÍ 1
   4.1 Vosk speech-to-text tiếng Việt offline
   4.2 Local intent parser (xử lý phủ định)
   4.3 Gemini API NLU fallback
   4.4 Luồng Local mode vs Remote mode
   4.5 AI cảnh báo tự động rule-based
5. Tích hợp IoT & Telegram                 ← TIÊU CHÍ 2
   5.1 MQTT topics và luồng dữ liệu
   5.2 Telegram Bot: 7 lệnh điều khiển
   5.3 Bảng 8 loại cảnh báo tự động
6. Cloud & Edge-to-Cloud                   ← TIÊU CHÍ 3
   6.1 HiveMQ Cloud broker
   6.2 Mosquitto bridge RPi5 → HiveMQ
   6.3 Luồng edge → cloud → app
7. Mobile App Flutter                      ← TIÊU CHÍ 4
   7.1 Kiến trúc app
   7.2 Màn hình Dashboard
   7.3 Màn hình Điều khiển
   7.4 Màn hình Voice (local/remote tự động)
   7.5 Màn hình Cảnh báo
8. Đánh giá kết quả thực nghiệm            ← TIÊU CHÍ 5
   8.1 Bảng đo 9 chỉ số
   8.2 Nhận xét kết quả
9. Giới hạn & Hướng phát triển
   - Bluetooth fallback khi mất WiFi
   - Local LLM (Ollama) thay Gemini — hoàn toàn offline
10. Kết luận
```

---

## Checklist 5 Tiêu Chí

### Tiêu chí 1: Tích hợp AI
- [ ] Vosk nhận dạng giọng nói tiếng Việt offline
- [ ] Local intent parser xử lý phủ định
- [ ] Gemini API NLU fallback khi câu mơ hồ
- [ ] AI cảnh báo tự động rule-based (8 loại)

### Tiêu chí 2: Tích hợp IoT — Telegram
- [ ] 8 loại cảnh báo tự động qua Telegram
- [ ] 7 lệnh điều khiển 2 chiều qua Telegram
- [ ] Theo dõi sensor từ xa realtime

### Tiêu chí 3: Cloud & Edge-to-Cloud
- [ ] HiveMQ Cloud làm MQTT broker trung gian
- [ ] Mosquitto bridge RPi5 → HiveMQ
- [ ] Luồng: ESP32 (edge) → HiveMQ (cloud) → Flutter app

### Tiêu chí 4: Mobile App
- [ ] Flutter Android app hoàn chỉnh
- [ ] 4 màn hình: Dashboard, Điều khiển, Voice, Cảnh báo
- [ ] Tự động chuyển local/remote mode

### Tiêu chí 5: Đánh giá thực nghiệm
- [ ] Bảng đo 9 chỉ số đầy đủ
- [ ] Video demo cover 10 tính năng
- [ ] Nhận xét kết quả và giới hạn hệ thống

---

## Cần Chuẩn Bị Trước Ngày 1

### Tài khoản — Hậu tạo, gửi thông tin cho Khôi
- [ ] **HiveMQ Cloud** — [hivemq.com/mqtt-cloud-broker](https://www.hivemq.com/mqtt-cloud-broker/) — lưu host/port/username/password
- [ ] **Telegram Bot** — nhắn `@BotFather`, tạo bot, lưu token
- [ ] **Google AI Studio** — [aistudio.google.com](https://aistudio.google.com) — lấy Gemini API key

### Phần mềm — Hậu cài
- [ ] Raspberry Pi Imager
- [ ] MobaXterm hoặc Windows Terminal
- [ ] VNC Viewer
- [ ] Advanced IP Scanner

### Phần mềm — Khôi cài
- [ ] Arduino IDE + ESP32 board + libraries
- [ ] Flutter SDK + Android Studio
- [ ] Bật Developer Mode + USB Debugging trên điện thoại Android của bạn

### Lưu ý nguồn điện RPi5
> ⚠️ RPi5 cần nguồn **5V / 5A (27W)**. Không dùng sạc điện thoại — hệ thống không ổn định, có thể hỏng thẻ nhớ.

---

*Cập nhật lần cuối theo các quyết định thiết kế của Hậu & Khôi.*

---

## Cấu Trúc Thư Mục Source Code

```
smart-home-iot/
│
├── esp32/                          # MicroPython — Khôi phụ trách
│   ├── esp32_1_tuoi_cay/           # ESP32 #1: Tưới cây
│   │   ├── main.py                 # Entry point, vòng lặp chính
│   │   ├── config.py               # WiFi, MQTT broker, ngưỡng cảm biến
│   │   ├── mqtt_client.py          # Kết nối & xử lý MQTT (umqtt.simple)
│   │   ├── soil_sensor.py          # Đọc LM393: AO→GPIO34 (giá trị %), DO→GPIO35 (interrupt ngưỡng)
│   │   └── relay_control.py        # Điều khiển relay bơm & phun sương
│   │
│   └── esp32_2_chieu_sang/         # ESP32 #2: Chiếu sáng
│       ├── main.py                 # Entry point, vòng lặp chính
│       ├── config.py               # WiFi, MQTT broker, ngưỡng cảm biến
│       ├── mqtt_client.py          # Kết nối & xử lý MQTT (umqtt.simple)
│       ├── dht_sensor.py           # Đọc DHT11: nhiệt độ & độ ẩm (GPIO4)
│       └── relay_control.py        # Điều khiển relay LED (GPIO25)
│
├── raspberry_pi/                   # Python 3 — Hậu phụ trách
│   ├── main.py                     # Khởi động toàn bộ services
│   ├── config.py                   # Cấu hình chung: MQTT, Telegram, API keys
│   │
│   ├── voice/                      # AI Voice pipeline
│   │   ├── websocket_server.py     # Nhận audio stream từ Flutter (port 8765)
│   │   ├── vosk_stt.py             # Speech-to-text tiếng Việt offline
│   │   ├── intent_parser.py        # Xử lý phủ định, parse lệnh local
│   │   └── gemini_nlu.py           # Gemini API fallback khi câu mơ hồ
│   │
│   ├── mqtt/                       # MQTT handler
│   │   ├── broker_config.py        # Cấu hình Mosquitto + HiveMQ bridge
│   │   ├── publisher.py            # Publish lệnh xuống ESP32
│   │   └── subscriber.py          # Subscribe data từ ESP32, trigger cảnh báo
│   │
│   ├── alerts/                     # Hệ thống cảnh báo
│   │   ├── alert_engine.py         # Logic kiểm tra ngưỡng, phát sinh cảnh báo
│   │   ├── alert_rules.py          # Định nghĩa 8 loại cảnh báo & ngưỡng
│   │   └── telegram_bot.py         # Gửi cảnh báo + xử lý lệnh Telegram
│   │
│   ├── models/                     # Vosk model (không commit lên git)
│   │   └── vosk-model-small-vn-0.4/
│   │
│   └── systemd/                    # Service files để autostart
│       ├── vosk-websocket.service
│       ├── telegram-bot.service
│       └── ai-alert.service
│
├── flutter_app/                    # Flutter Android — Khôi phụ trách
│   ├── lib/
│   │   ├── main.dart               # Entry point
│   │   ├── config/
│   │   │   └── app_config.dart     # HiveMQ host, RPi5 IP, topics
│   │   │
│   │   ├── services/
│   │   │   ├── mqtt_service.dart   # Kết nối HiveMQ Cloud, pub/sub
│   │   │   ├── websocket_service.dart  # Gửi audio local lên RPi5
│   │   │   └── stt_service.dart    # Tự detect local/remote, xử lý voice
│   │   │
│   │   ├── screens/
│   │   │   ├── dashboard_screen.dart   # Màn hình 1: sensor realtime
│   │   │   ├── control_screen.dart     # Màn hình 2: bật tắt thiết bị
│   │   │   ├── voice_screen.dart       # Màn hình 3: voice command
│   │   │   └── alerts_screen.dart      # Màn hình 4: lịch sử cảnh báo
│   │   │
│   │   ├── widgets/
│   │   │   ├── sensor_card.dart        # Card hiển thị 1 sensor
│   │   │   ├── device_toggle.dart      # Nút toggle thiết bị
│   │   │   ├── alert_item.dart         # Item 1 cảnh báo trong list
│   │   │   └── mode_badge.dart         # Badge LOCAL / REMOTE
│   │   │
│   │   └── models/
│   │       ├── sensor_data.dart        # Model dữ liệu sensor
│   │       └── alert_model.dart        # Model cảnh báo
│   │
│   └── pubspec.yaml
│
├── nodered/                        # Node-RED — Hậu phụ trách
│   └── flows.json                  # Export flow Node-RED dashboard
│
├── docs/                           # Tài liệu
│   ├── architecture.png            # Sơ đồ kiến trúc 4 lớp
│   ├── wiring_esp32_1.png          # Sơ đồ nối dây ESP32 #1
│   └── wiring_esp32_2.png          # Sơ đồ nối dây ESP32 #2
│
├── .env.example                    # Mẫu biến môi trường (không commit .env thật)
├── .gitignore
└── README.md
```

---

## Phân Công Code Theo File

| File / Thư mục | Người làm | Ưu tiên |
|---------------|-----------|---------|
| `esp32/esp32_1_tuoi_cay/` | Khôi | Ngày 1 chiều |
| `esp32/esp32_2_chieu_sang/` | Khôi | Ngày 1 chiều |
| `raspberry_pi/mqtt/` | Hậu | Ngày 1 chiều |
| `raspberry_pi/voice/` | Hậu | Ngày 2 sáng |
| `raspberry_pi/alerts/` | Hậu | Ngày 2 chiều |
| `flutter_app/services/` | Khôi | Ngày 2 sáng |
| `flutter_app/screens/` | Khôi | Ngày 2 |
| `nodered/flows.json` | Hậu | Ngày 1 chiều |

---

## Lưu Ý MicroPython (Thay Arduino C++)

**Tool nạp code:** dùng **Thonny IDE** (miễn phí, thân thiện) hoặc `mpremote`

**Thư viện MQTT:** `umqtt.simple` — có sẵn trong MicroPython firmware, không cần cài thêm

**Thư viện DHT:** module `dht` — có sẵn trong MicroPython

**JSON:** dùng module `json` built-in, không cần ArduinoJson

**Cấu trúc `main.py` trên ESP32:**
- Kết nối WiFi
- Kết nối MQTT broker (HiveMQ Cloud)
- Vòng lặp chính: đọc sensor → publish → kiểm tra lệnh subscribe → điều khiển relay

**`config.py` — tách riêng để dễ thay đổi:**
```
WIFI_SSID     = "..."
WIFI_PASSWORD = "..."
MQTT_HOST     = "xxx.hivemq.cloud"
MQTT_PORT     = 8883
MQTT_USER     = "..."
MQTT_PASSWORD = "..."

# Cảm biến LM393
SOIL_AO_PIN         = 34   # ADC — đọc giá trị % thực tế
SOIL_DO_PIN         = 35   # Digital — interrupt ngưỡng vật lý (chỉnh bằng núm vặn)
SOIL_DRY_THRESHOLD  = 20   # % — dưới ngưỡng này = khô → bật bơm
SOIL_WET_THRESHOLD  = 80   # % — trên ngưỡng này = quá ẩm → tắt bơm
PUMP_MAX_RUNTIME    = 300  # giây — bơm chạy tối đa 5 phút

# Cảm biến DHT11
TEMP_HIGH_THRESHOLD = 35   # °C
HUMIDITY_LOW        = 40   # % — dưới ngưỡng → bật phun sương
HUMIDITY_HIGH       = 85   # % — trên ngưỡng → tắt phun sương
```

**`.gitignore` nên có:**
```
*.env
config.py          # Chứa password — không commit lên git
raspberry_pi/models/
__pycache__/
.dart_tool/
build/
```
