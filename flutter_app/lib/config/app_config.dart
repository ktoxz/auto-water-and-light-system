class AppConfig {
  // ── HiveMQ Cloud ──────────────────────────────────────────────
  static const String hiveMqHost =
      '516ba4ca2219465e88a2db2e3aa47f21.s1.eu.hivemq.cloud';
  static const int hiveMqPort = 8883;
  static const String hiveMqUsername = 'smart-home-cloud';
  static const String hiveMqPassword = 'Cloud123456';

  // ── Raspberry Pi 5 ────────────────────────────────────────────
  static const int websocketPort = 8765;

  // ── MQTT Topics ───────────────────────────────────────────────
  static const String topicTemp = 'home/temp';
  static const String topicHumidity = 'home/humidity';
  static const String topicSoil = 'home/soil';

  static const String topicPumpStatus = 'home/pump/status';
  static const String topicLedStatus = 'home/led/status';
  static const String topicMistStatus = 'home/mist/status';

  static const String topicPumpControl = 'home/pump/control';
  static const String topicLedControl = 'home/led/control';
  static const String topicMistControl = 'home/mist/control';

  static const String topicAlerts = 'home/alerts';
  static const String topicVoiceCommand = 'home/voice/command';
  static const String topicVoiceResponse = 'home/voice/response';

  // ── Ngưỡng cảnh báo ───────────────────────────────────────────
  static const double tempHigh = 35.0;
  static const double humidityLow = 40.0;
  static const double humidityHigh = 85.0;
  static const int soilDry = 20;
  static const int soilWet = 80;
}