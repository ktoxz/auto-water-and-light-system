class AlertModel {
  final String id;
  final String title;
  final String message;
  final AlertType type;
  final DateTime timestamp;
  final bool isRead;

  const AlertModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    final timestamp = rawTimestamp is String
        ? DateTime.tryParse(rawTimestamp) ?? DateTime.now()
        : DateTime.now();

    return AlertModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: AlertType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['type'] ?? 'warning'),
        orElse: () => AlertType.warning,
      ),
      timestamp: timestamp,
      isRead: json['is_read'] ?? false,
    );
  }
}

enum AlertType {
  critical,
  warning,
  info,
}
