// lib/models/log_user_model.dart

class LogUser {
  final String fullName;
  final String lgUserID;

  LogUser({required this.fullName, required this.lgUserID});

  factory LogUser.fromJson(Map<String, dynamic> json) {
    return LogUser(
      fullName: json['fullName'] as String? ?? 'N/A',
      lgUserID: json['lgUSERID'] as String? ?? '',
    );
  }
}