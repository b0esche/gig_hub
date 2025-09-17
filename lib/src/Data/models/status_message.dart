class StatusMessage {
  final String id;
  final String userId;
  final String message;
  final DateTime createdAt;
  final DateTime expiresAt;

  StatusMessage({
    required this.id,
    required this.userId,
    required this.message,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory StatusMessage.fromJson(String id, Map<String, dynamic> json) =>
      StatusMessage(
        id: id,
        userId: json['userId'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}
