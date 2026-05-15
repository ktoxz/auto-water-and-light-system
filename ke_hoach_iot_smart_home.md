# Kế Hoạch Bài Tập Lớn IoT
## Hệ Thống Chiếu Sáng Thông Minh & Tưới Cây Tự Động Trong Nhà

> **Team:** Hậu & Khôi | **Thời gian:** 3 ngày
> **Hậu:** giữ RPi5, code Flutter app + backend RPi5 | **Khôi:** giữ toàn bộ linh kiện, code ESP32 C++

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
| 1x ESP32 | Khôi |
| Cảm biến nhiệt ẩm DHT11 | Khôi |
| Bộ cảm biến độ ẩm đất LM393 (board + đầu dò) | Khôi |
| Máy bơm | Khôi |
| Máy phun sương | Khôi |
| Relay module 2 kênh (bơm + phun sương) | Khôi |
| Relay module 2 kênh (đèn + dự phòng) | Khôi |
| 2x Breadboard | Khôi |
| Đèn sợi tóc 12V | Khôi |
| Đế pin 3x Li-ion 3.7V (nguồn 12V cho đèn) | Khôi |

---

## Kiến Trúc Hệ Thống

```
┌─────────────────────────────────────────────────────┐
│              Lớp 1 — Edge / Hardware                │
│           ESP32 (Khôi phụ trách phần cứng)          │
│  - LM393 soil sensor (AO + DO)                      │
│  - DHT11 (nhiệt độ + độ ẩm không khí)               │
│  - Relay 2 kênh A → Máy bơm + Phun sương            │
│  - Relay 2 kênh B → Đèn sợi tóc 12V + dự phòng     │
└──────────────────────┬──────────────────────────────┘
                       │  MQTT over WiFi
┌──────────────────────▼──────────────────────────────┐
│         Lớp 2 — Raspberry Pi 5 (Hậu phụ trách)     │
│  Mosquitto Broker  │  Vosk STT     │  Ollama        │
│  Node-RED          │  Gemma 3 4B   │  Telegram Bot  │
│  WebSocket Server  │  AI Alert     │  HiveMQ Bridge │
└──────────────┬──────────────────────────────────────┘
               │  MQTT Bridge (edge-to-cloud)
┌──────────────▼──────────────────────────────────────┐
│              Lớp 3 — HiveMQ Cloud                   │
│         MQTT Broker trung gian (free tier)          │
└──────────────┬──────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────┐
│       Lớp 4 — Flutter App Android (Hậu code)        │
│  Dashboard  │  Điều khiển  │  Voice  │  Cảnh báo   │
└─────────────────────────────────────────────────────┘
```

---

## Stack Công Nghệ Đã Chốt

| Thành phần | Công nghệ | Ghi chú |
|-----------|-----------|---------|
| Speech-to-text (local) | **Vosk** `vosk-model-small-vn-0.4` | Offline, chạy trên RPi5, nhận audio từ mic Flutter |
| Speech-to-text (remote) | **Android STT** built-in | Khi điện thoại khác WiFi, cần internet điện thoại |
| NLU — hiểu ý định | **Gemma 3 4B Q4_K_M** qua **Ollama** | Offline hoàn toàn, chạy local trên RPi5, test 20/20 câu tiếng Việt |
| MQTT local broker | **Mosquitto** trên RPi5 | Giao tiếp ESP32 ↔ RPi5 |
| MQTT cloud broker | **HiveMQ Cloud** free | Edge-to-cloud, điều khiển từ xa |
| Điều phối logic | **Node-RED** | Dashboard web local, automation flow |
| Cảnh báo | **Telegram Bot** | 2 chiều: nhận cảnh báo + gửi lệnh |
| Mobile App | **Flutter** Android | 4 màn hình: Dashboard, Điều khiển, Voice, Cảnh báo |
| Audio transport (local) | **WebSocket** | Flutter gửi audio stream lên RPi5 |
| Audio transport (remote) | **MQTT** qua HiveMQ | Flutter gửi text lệnh lên RPi5 |

---

## Luồng Voice Command

### Chế độ Local (cùng WiFi — offline hoàn toàn)
```
Mic điện thoại (Flutter)
    → WebSocket → RPi5
    → Vosk STT (audio → text tiếng Việt, offline, < 1s)
    → Gemma 4 2B Q4 qua Ollama (text → JSON lệnh, offline, ~5–10s)
    → MQTT → ESP32 thực thi
    → Phản hồi text về Flutter
```

### Chế độ Remote (khác WiFi / 4G)
```
Mic điện thoại (Flutter)
    → Android STT (audio → text, cần internet điện thoại)
    → MQTT → HiveMQ Cloud → RPi5
    → Gemma 4 2B Q4 qua Ollama (text → JSON lệnh, offline, ~5–10s)
    → MQTT → ESP32 thực thi
    → Phản hồi text về Flutter qua MQTT
```

> **Điểm mạnh:** NLU xử lý hoàn toàn offline bằng Gemma 4 local — cả 2 mode đều không phụ thuộc cloud AI

### Tự động detect mode trong Flutter
- Thử kết nối WebSocket tới IP RPi5 → thành công: **Local mode** (Vosk + Gemma)
- Thất bại → **Remote mode** (Android STT + Gemma)
- Người dùng không cần chọn gì, app tự xử lý hoàn toàn

### Bảng các tình huống

| Tình huống | STT | NLU | Hoạt động? |
|-----------|-----|-----|-----------|
| Ở gần, có internet | Vosk offline | Gemma local | ✅ Offline hoàn toàn |
| Ở gần, mất internet | Vosk offline | Gemma local | ✅ Offline hoàn toàn |
| Ở xa, có internet | Android STT | Gemma local | ✅ |
| Ở xa, mất internet | ❌ | — | ❌ |
| Mất WiFi hoàn toàn | ❌ | — | ❌ Future: Bluetooth |

### Gemma 3 2B — Cấu hình tối ưu trên RPi5

| Tối ưu | Cách làm | Lợi ích |
|--------|---------|---------|
| Quantization Q4_K_M | `bartowski/gemma-3-2b-it-GGUF` hoặc tự convert | Nhanh hơn ~1.5x, RAM giảm ~40% |
| Giới hạn context | `PARAMETER num_ctx 512` trong Modelfile | Đủ cho lệnh ngắn, nhanh hơn nhiều |
| Preload model | `OLLAMA_KEEP_ALIVE=-1` | Load 1 lần, các lần sau không chờ |
| Temperature thấp | `PARAMETER temperature 0.1` | Output JSON ổn định, ít sai format |
| Output JSON cố định | System prompt ép format | Sinh ít token → nhanh hơn |

### Modelfile Ollama
```
FROM ~/gemma3-2b-it-q4_K_M.gguf

PARAMETER num_ctx 512
PARAMETER temperature 0.1
PARAMETER stop "}"

SYSTEM """
Bạn là bộ điều khiển nhà thông minh. Phân tích câu người dùng và trả về JSON.

Thiết bị hợp lệ:
- led: đèn, ánh sáng, đèn điện, bóng đèn
- pump: bơm, tưới, tưới cây, tưới nước, máy bơm
- mist: sương, phun sương, phun nước, máy phun, độ ẩm

Hành động:
- ON: bật, mở, khởi động, tưới, tưới đi, bật lên
- OFF: tắt, đóng, dừng, thôi, ngừng, tắt đi, khóa

Lưu ý quan trọng:
- Có từ phủ định (đừng, không, chớ, thôi đừng) → đảo ngược hành động
- Câu mô tả tình trạng dẫn đến hành động → suy ra hành động hợp lý
- Chỉ trả về JSON, không giải thích gì thêm

Format bắt buộc: {"device":"led/pump/mist","action":"ON/OFF"}
Không hiểu hoặc không liên quan: {"action":"unknown"}
"""
```

### Ví dụ Gemma 3 xử lý — đầy đủ 3 thiết bị

| Câu nói | Kết quả |
|---------|---------|
| "bật đèn" | `{"device":"led","action":"ON"}` |
| "hôm nay trời sáng quá đừng có bật đèn nha" | `{"device":"led","action":"OFF"}` |
| "tối quá bật đèn lên đi" | `{"device":"led","action":"ON"}` |
| "tưới cây đi" | `{"device":"pump","action":"ON"}` |
| "cây hơi khô rồi đó" | `{"device":"pump","action":"ON"}` |
| "thôi tắt bơm đi đủ rồi" | `{"device":"pump","action":"OFF"}` |
| "bật phun sương lên" | `{"device":"mist","action":"ON"}` |
| "độ ẩm thấp quá bật sương lên đi" | `{"device":"mist","action":"ON"}` |
| "tắt phun sương đi đủ rồi" | `{"device":"mist","action":"OFF"}` |
| "hôm nay thời tiết đẹp nhỉ" | `{"action":"unknown"}` |

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
Cài xong RPi5 headless + ESP32 hoạt động + luồng MQTT end-to-end thông suốt.

### Phân công

| | Hậu (RPi5 + Flutter) | Khôi (ESP32 + linh kiện) |
|--|---------------------|--------------------------|
| Sáng | Cài RPi5 OS headless, SSH, packages | Nối mạch ESP32, test cảm biến Serial Monitor |
| Chiều | Mosquitto, Node-RED, HiveMQ bridge + **bắt đầu Flutter UI** | Firmware ESP32 + MQTT lên HiveMQ Cloud |
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
pip install paho-mqtt vosk websockets flask pyTelegramBotAPI --break-system-packages

# Cài Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Kiểm tra GGUF sẵn có trên HuggingFace (chạy trước)
huggingface-cli download bartowski/gemma-3-2b-it-GGUF \
  --include "*Q4_K_M*" --local-dir ~/gemma3-2b-gguf --dry-run

# Nếu có → tải thẳng GGUF (không cần convert)
huggingface-cli download bartowski/gemma-3-2b-it-GGUF \
  --include "*Q4_K_M*" --local-dir ~/gemma3-2b-gguf

# Nếu không có → tải model gốc để tự convert qua đêm
huggingface-cli download google/gemma-3-2b-it \
  --include "*.safetensors" "*.json" "*.model" \
  --local-dir ~/gemma3-2b-it

# Giữ model trên RAM
echo "OLLAMA_KEEP_ALIVE=-1" >> ~/.bashrc && source ~/.bashrc

# Model Vosk tiếng Việt (~40MB)
wget https://alphacephei.com/vosk/models/vosk-model-small-vn-0.4.zip
unzip vosk-model-small-vn-0.4.zip
```

---

### Buổi Sáng — Khôi: Nối Mạch Phần Cứng

#### ESP32 — Tất cả trong 1 board

**Bộ cảm biến độ ẩm đất LM393:**
- Đầu dò điện trở (que cắm xuống đất, chữ 土壤湿度检测) → cắm 2 chân vào đầu nối phía trên board LM393
- Board xử lý LM393 (có núm vặn biến trở) → nối vào ESP32

| Linh kiện | Chân ESP32 | Ghi chú |
|-----------|-----------|---------|
| LM393 — AO | GPIO34 (ADC) | Giá trị 0–4095 → map sang 0–100% độ ẩm |
| LM393 — DO | GPIO35 (Digital) | Interrupt khi vượt ngưỡng vật lý |
| LM393 — VCC | 3.3V | |
| LM393 — GND | GND | |
| DHT11 (Data) | GPIO4 | Trở pull-up 10kΩ |
| Relay A — IN1 | GPIO26 | Kênh 1 → Máy bơm |
| Relay A — IN2 | GPIO27 | Kênh 2 → Máy phun sương |
| Relay A — VCC | 5V (VIN) | Relay cần 5V để kéo cuộn dây ổn định |
| Relay A — GND | GND | |
| Relay B — IN1 | GPIO25 | Kênh 1 → Đèn sợi tóc 12V |
| Relay B — IN2 | — | Kênh 2 → Không dùng |
| Relay B — VCC | 5V (VIN) | |
| Relay B — GND | GND | |

**Nối đèn 12V qua Relay B kênh 1:**
```
Relay B — COM → GND chung (GND ESP32 + GND đế pin nối nhau)
Relay B — NO  → Chân âm đèn sợi tóc
Đế pin (+) 12V → Chân dương đèn sợi tóc
```

> ⚠️ **GND của ESP32 và GND của đế pin 12V bắt buộc phải nối chung** — nếu không relay đóng nhưng đèn không sáng
> ⚠️ Dùng chân **NO (Normally Open)** trên relay — đèn chỉ sáng khi ESP32 ra lệnh bật
> ⚠️ Chỉnh núm vặn LM393 ngưỡng DO ~30% độ ẩm cho cây trong nhà
> ⚠️ Test từng linh kiện qua Serial Monitor trước khi nối cả mạch

**Cách dùng AO và DO của LM393:**
- **AO** (polling 5 giây): đọc giá trị % → publish `home/soil` → dashboard + cảnh báo
- **DO** (interrupt): phản hồi tức thì khi đất vượt ngưỡng → bật bơm ngay

---

### Buổi Chiều — Khôi: Firmware + MQTT

#### Cài Arduino IDE & Libraries
- Tải **Arduino IDE** → thêm ESP32 board URL:
  `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
- Vào Library Manager cài: `PubSubClient`, `DHT sensor library` (Adafruit), `ArduinoJson`
- `WiFiClientSecure` đã có sẵn trong ESP32 core, không cần cài thêm
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
- [x] Hậu: Flash RPi OS Lite 64-bit, cấu hình WiFi + SSH headless
- [x] Hậu: SSH vào RPi5 thành công, cài VNC Server
- [x] Hậu: Mosquitto broker cài xong, tự khởi động
- [x] Hậu: Node-RED cài xong, tự khởi động, cài node-red-dashboard
- [x] Hậu: Python packages cài đủ (paho-mqtt, vosk, websockets, v.v.)
- [x] Hậu: Model Vosk tiếng Việt tải và giải nén thành công
- [x] Hậu: HiveMQ Cloud tạo tài khoản + credentials (smart-home-cloud / PUBLISH_SUBSCRIBE)
- [x] Hậu: Mosquitto bridge config không dùng được → thay bằng Python bridge script
- [x] Hậu: `bridge.py` (paho-mqtt) kết nối 2 chiều local Mosquitto ↔ HiveMQ Cloud thành công
- [x] Hậu: `mqtt-bridge.service` systemd tạo xong, enabled, active (running)
- [x] Hậu: Reboot test — Mosquitto, Node-RED, mqtt-bridge tự khởi động hoàn toàn
- [x] Hậu: Ollama cài xong, model Gemma 3 4B kéo và test thành công
- [x] Khôi: ESP32 bật tắt đèn, bơm, phun sương qua relay — test OK
- [x] Khôi: Cảm biến độ ẩm đất đọc được — test OK
- [ ] Khôi: Đổi ESP32 từ Blynk → MQTT HiveMQ Cloud (đúng topics trong plan)
- [ ] Hậu: RPi5 nhận data từ ESP32 qua bridge — test end-to-end
- [x] Hậu: Project Flutter tạo xong, chạy được trên emulator
- [x] Hậu: Telegram Bot tạo xong — có token, chat ID

#### Kiểm tra nhanh khi cần verify hệ thống
```bash
# Xem tất cả services cùng lúc
sudo systemctl status mosquitto mqtt-bridge nodered --no-pager

# Test bridge 2 chiều
mosquitto_pub -h localhost -t "home/test" -m "hello"
# Vào HiveMQ Web Client → Subscribe home/# → thấy "hello" là OK
```

---

## Ngày 2

### Mục tiêu
Hoàn thiện AI voice pipeline + Telegram Bot + AI cảnh báo + Flutter App 4 màn hình.

### Phân công

| | Hậu (RPi5 + Flutter) | Khôi (ESP32 + hỗ trợ test) |
|--|---------------------|---------------------------|
| Sáng | Cài Ollama + Gemma · WebSocket server · Vosk pipeline | Đổi ESP32 sang MQTT HiveMQ · test end-to-end với RPi5 |
| Chiều | **Flutter: cả 4 màn hình** (Dashboard, Điều khiển, Voice, Cảnh báo) | Telegram Bot + AI cảnh báo + Autostart trên RPi5 |
| Tối | **Test tích hợp Flutter ↔ RPi5 ↔ ESP32** | **Test tích hợp Flutter ↔ RPi5 ↔ ESP32** |

---

### Buổi Sáng — Hậu: AI Voice Pipeline trên RPi5

#### Bước 1: WebSocket Server nhận audio
- `websockets` library, port `8765`
- Nhận binary audio: **16kHz, mono, 16-bit PCM**
- Đẩy vào Vosk `KaldiRecognizer` → kết quả text → Ollama

#### Bước 2: Ollama + Gemma 3 2B NLU
- Nhận text từ Vosk → gửi vào Gemma 3 qua Ollama API (localhost:11434)
- Modelfile: system prompt đầy đủ từ khóa 3 thiết bị, context 512, temperature 0.1
- Output: `{"device":"led/pump/mist","action":"ON/OFF"}` hoặc `{"action":"unknown"}`
- Parse JSON → publish MQTT → gửi phản hồi text về Flutter

#### Bước 3: Kiểm tra Gemma 3 hoạt động
```bash
ollama run gemma3-smart-home "hôm nay trời sáng quá đừng có bật đèn nha"
# Phải trả về: {"device":"led","action":"OFF"}

ollama run gemma3-smart-home "tưới cây đi"
# Phải trả về: {"device":"pump","action":"ON"}

ollama run gemma3-smart-home "bật phun sương lên"
# Phải trả về: {"device":"mist","action":"ON"}
```

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
| ESP32 offline | Không nhận MQTT > 30s | Telegram 🔴 |

#### Autostart Services
Tạo systemd `.service` cho: `nodered`, `vosk-websocket`, `telegram-bot`, `ai-alert`

---

### Buổi Chiều — Hậu: Flutter App 4 Màn Hình (việc chính)

> Hậu tập trung toàn bộ buổi chiều cho Flutter. Khôi lo phần Telegram Bot + Autostart trên RPi5 qua SSH.

#### Setup project + Packages `pubspec.yaml`
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
- Subscribe: `home/temp`, `home/humidity`, `home/soil`, `home/led/status`, `home/pump/status`, `home/mist/status`
- Gauge nhiệt độ, độ ẩm, card trạng thái thiết bị
- Indicator online/offline cho ESP32

#### Màn hình 2: Điều Khiển
- Toggle: Đèn, Bơm, Phun sương → publish MQTT lên HiveMQ
- Nút đổi màu ngay theo trạng thái thực

---

### Buổi Chiều — Khôi: Telegram Bot + AI Cảnh Báo + Autostart

Khôi SSH vào RPi5 (qua MobaXterm) để làm phần backend còn lại trong khi Hậu tập trung Flutter.

#### Telegram Bot
1. Tạo bot qua `@BotFather` → lưu token
2. Lấy chat_id: nhắn tin cho bot → gọi API getUpdates
3. Implement các lệnh: `/status`, `/pump_on`, `/pump_off`, `/led_on`, `/led_off`, `/mist_on`, `/mist_off`

#### AI Cảnh Báo + Autostart
- Implement `alert_engine.py` theo bảng 8 loại cảnh báo
- Tạo systemd service files: `vosk-websocket`, `telegram-bot`, `ai-alert`
- Test autostart bằng cách reboot RPi5

---

### Hậu tiếp tục Flutter — Màn hình Voice + Cảnh Báo

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
- [x] Ollama cài xong
- [x] Gemma 3 1B pull về — test, kết quả không ổn
- [x] Chuyển sang Gemma 3 4B — hoạt động tốt hơn
- [x] Tối ưu Modelfile: temperature 0.0, repeat_penalty 1.5, num_predict 25, few-shot examples
- [x] Test 20/20 câu tiếng Việt đúng 100% — đủ 3 thiết bị led/pump/mist
- [x] Xử lý đúng phủ định đơn: "Đừng bật đèn" → OFF
- [x] Xử lý đúng double negation: "Đừng có tắt đèn nha" → unknown
- [x] Xử lý đúng câu mô tả tình trạng: "Cây héo hết rồi" → pump ON
- [x] Modelfile backup vào `raspberry_pi/voice/Modelfile`
- [x] Viết `ollama_nlu.py` — text → Ollama → JSON lệnh → MQTT topic
- [x] Viết `vosk_stt.py` — Vosk model load OK, transcribe_audio sẵn sàng
- [x] Viết `websocket_server.py` — nhận text/audio từ Flutter, pipeline hoàn chỉnh
- [x] Test pipeline: wscat → WebSocket → Ollama → MQTT publish ✅
- [x] `vosk-websocket.service` systemd enabled, active (running)
- [x] Telegram Bot tạo xong — kết nối thẳng HiveMQ Cloud, 7 lệnh hoạt động
- [x] Telegram nhận cảnh báo từ ESP32 qua `home/alerts` ✅
- [x] Flutter project tạo xong, emulator API 33 chạy được
- [x] Flutter kết nối MQTT HiveMQ thành công ✅
- [x] Flutter nhận data sensor từ ESP32 realtime ✅
- [x] Khôi: ESP32 đổi sang MQTT HiveMQ thành công, bỏ Blynk
- [x] Khôi: ESP32 publish đủ topics: home/temp, home/humidity, home/soil, home/led/status, home/pump/status
- [x] Bridge fix vòng lặp — chỉ forward sensor data Local→Cloud, không forward ngược lại
- [x] Pipeline voice: WebSocket server kết nối HiveMQ Cloud thành công
- [x] Viết `alert_engine.py` — 8 loại cảnh báo, kết nối HiveMQ, auto action
- [x] `ai-alert.service` systemd enabled, active (running)
- [x] `telegram-bot.service` systemd enabled, active (running)
- [x] Test cảnh báo Telegram nhận được ✅
- [x] `/status` trả về sensor realtime đúng ✅
- [x] Flutter: màn hình Voice Command — Remote mode hoàn chỉnh ✅
- [x] Pipeline voice Remote: Android STT → addUTF8String → HiveMQ → Gemma → ESP32 ✅
- [x] Gemma hiểu câu tiếng Việt tự nhiên phức tạp: "nóng quá bọc phun sương đi" → mist ON ✅
- [x] `vosk-websocket.service` subscribe HiveMQ nhận voice command remote mode ✅
- [x] Fix UTF-8 encoding: đổi addString → addUTF8String trong mqtt_service.dart ✅
- [x] Đổi STT từ Vosk → PhoWhisper-small (VinAI) — accuracy 100% với giọng người thật ✅
- [x] Test PhoWhisper: "trời nóng quá bật đèn lên đi" → nhận đúng 100% ✅
- [x] Test PhoWhisper: "hãy mở đèn cho tôi" → Gemma → home/led/control ON ✅
- [x] Voice Local mode: WebSocket + PhoWhisper + Gemma pipeline hoàn chỉnh ✅
- [x] Fix Voice Local mode button disable — parse JSON response đúng ✅
- [x] WebSocketService auto-detect host: raspberrypi.local / pi-local / 10.0.2.2 ✅

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
3. **Gemma 4 local NLU** — nói câu phức tạp *"cây có vẻ khô bơm nước một chút"* → Gemma hiểu → bật bơm
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
   4.2 Gemma 4 2B Q4 qua Ollama — NLU local
   4.3 Các tối ưu: quantization, context window, system prompt
   4.4 Luồng Local mode (Vosk + Gemma) vs Remote mode (Android STT + Gemma)
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
   - Nâng cấp lên Gemma 3 4B khi có phần cứng mạnh hơn
   - Streaming response từ Ollama để giảm perceived latency
   - Thử Gemma 4 E2B khi llama.cpp hỗ trợ ổn định hơn
10. Kết luận
```

---

## Checklist 5 Tiêu Chí

### Tiêu chí 1: Tích hợp AI
- [x] Gemma 3 4B qua Ollama — NLU hoàn toàn local, test 20/20 câu tiếng Việt
- [x] Tối ưu: few-shot prompting + temperature 0.0 + repeat_penalty 1.5
- [x] Xử lý phủ định, double negation, câu mô tả tình trạng
- [ ] Vosk nhận dạng giọng nói tiếng Việt offline
- [ ] Điều khiển đủ 3 thiết bị bằng giọng nói: đèn, bơm, phun sương
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

### Phần mềm — Hậu cài
- [ ] Raspberry Pi Imager
- [ ] MobaXterm hoặc Windows Terminal
- [ ] VNC Viewer
- [ ] Advanced IP Scanner
- [ ] Flutter SDK (flutter.dev) + thêm vào PATH
- [ ] Android Studio (để lấy Android SDK + emulator)
- [ ] Plugin Flutter + Dart trong IntelliJ (File → Settings → Plugins)
- [ ] Chạy `flutter doctor --android-licenses` sau khi cài xong

### Phần mềm — Khôi cài
- [ ] Arduino IDE + ESP32 board URL + libraries (PubSubClient, DHT, ArduinoJson)
- [ ] Driver CH340 hoặc CP2102 (xem chip trên board ESP32)
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
├── esp32/                              # C++ (Arduino framework) — Khôi phụ trách
│   └── esp32_smart_home/               # ESP32 duy nhất: tưới cây + chiếu sáng
│       ├── esp32_smart_home.ino        # Entry point (setup + loop)
│       ├── config.h                    # WiFi, MQTT broker, pin, ngưỡng cảm biến
│       ├── mqtt_handler.h/.cpp         # Kết nối & xử lý MQTT (PubSubClient)
│       ├── soil_sensor.h/.cpp          # Đọc LM393: AO→GPIO34 (%), DO→GPIO35 (interrupt)
│       ├── dht_sensor.h/.cpp           # Đọc DHT11: nhiệt độ & độ ẩm (GPIO4)
│       └── relay_control.h/.cpp        # Điều khiển 3 relay: bơm, phun sương, đèn 12V
│
├── raspberry_pi/                   # Python 3 — Hậu phụ trách
│   ├── main.py                     # Khởi động toàn bộ services
│   ├── config.py                   # Cấu hình chung: MQTT, Telegram, API keys
│   │
│   ├── voice/                      # AI Voice pipeline
│   │   ├── websocket_server.py     # Nhận audio stream từ Flutter (port 8765)
│   │   ├── vosk_stt.py             # Speech-to-text tiếng Việt offline
│   │   └── ollama_nlu.py           # Gemma 4 2B Q4 qua Ollama — hiểu ý định, output JSON
│   │
│   ├── mqtt/                       # MQTT handler
│   │   ├── bridge.py               # Python bridge: local Mosquitto ↔ HiveMQ Cloud (2 chiều)
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
│       ├── mqtt-bridge.service     # ✅ Đã tạo và chạy
│       ├── vosk-websocket.service  # ✅ Đã tạo và chạy
│       ├── telegram-bot.service
│       └── ai-alert.service
│
├── flutter_app/                    # Flutter Android — Hậu phụ trách
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
| `esp32/esp32_smart_home/` | **Khôi** | Ngày 1 chiều |
| `raspberry_pi/mqtt/` | **Hậu** | Ngày 1 chiều |
| `raspberry_pi/voice/` | **Hậu** | Ngày 2 sáng |
| `raspberry_pi/alerts/` | **Khôi** (SSH vào RPi5) | Ngày 2 chiều |
| `flutter_app/lib/services/` | **Hậu** | Ngày 1 chiều |
| `flutter_app/lib/screens/dashboard` | **Hậu** | Ngày 1 chiều |
| `flutter_app/lib/screens/control` | **Hậu** | Ngày 2 sáng |
| `flutter_app/lib/screens/voice` | **Hậu** | Ngày 2 chiều |
| `flutter_app/lib/screens/alerts` | **Hậu** | Ngày 2 chiều |
| `nodered/flows.json` | **Hậu** | Ngày 1 chiều |

---

## Lưu Ý ESP32 C++ (Arduino Framework)

**Tool nạp code:** **Arduino IDE** hoặc **VS Code + PlatformIO** (PlatformIO chuyên nghiệp hơn, hỗ trợ chia file .h/.cpp tốt hơn)

**Thư viện cần cài (Library Manager):**

| Thư viện | Dùng cho |
|---------|---------|
| `PubSubClient` | MQTT |
| `DHT sensor library` (Adafruit) | DHT11 |
| `ArduinoJson` | Parse JSON lệnh từ MQTT |
| `WiFiClientSecure` | Kết nối HiveMQ Cloud qua TLS (có sẵn trong ESP32 core) |

**Cấu trúc `.ino` trên ESP32:**
- `setup()`: kết nối WiFi → kết nối MQTT → cấu hình interrupt DO (LM393)
- `loop()`: đọc sensor AO mỗi 5 giây → publish MQTT → kiểm tra lệnh subscribe → điều khiển relay

**`config.h` — tách riêng để dễ thay đổi:**
```cpp
// WiFi
#define WIFI_SSID     "..."
#define WIFI_PASSWORD "..."

// HiveMQ Cloud
#define MQTT_HOST     "xxx.hivemq.cloud"
#define MQTT_PORT     8883
#define MQTT_USER     "..."
#define MQTT_PASSWORD "..."

// Cảm biến LM393
#define SOIL_AO_PIN         34    // ADC — đọc giá trị % thực tế
#define SOIL_DO_PIN         35    // Digital — interrupt ngưỡng vật lý
#define SOIL_DRY_THRESHOLD  20    // % — dưới ngưỡng = khô → bật bơm
#define SOIL_WET_THRESHOLD  80    // % — trên ngưỡng = quá ẩm → tắt bơm
#define PUMP_MAX_RUNTIME    300   // giây — bơm chạy tối đa 5 phút

// Relay
#define RELAY_PUMP_PIN      26    // Relay A kênh 1 → Máy bơm
#define RELAY_MIST_PIN      27    // Relay A kênh 2 → Máy phun sương
#define RELAY_LIGHT_PIN     25    // Relay B kênh 1 → Đèn sợi tóc 12V

// Cảm biến DHT11
#define DHT_PIN             4
#define TEMP_HIGH_THRESHOLD 35    // °C
#define HUMIDITY_LOW        40    // % — dưới ngưỡng → bật phun sương
#define HUMIDITY_HIGH       85    // % — trên ngưỡng → tắt phun sương
```
**`.gitignore` nên có:**
```
*.env
config.h           # Chứa password — không commit lên git
raspberry_pi/models/
__pycache__/
.dart_tool/
build/
```