// lib/models/user_model.dart

class AppUser {
  final String userId;
  final String firstName;
  final String lastName;
  final String login;
  final String officineName;
  final String? profilePicUrl;

  AppUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.login,
    required this.officineName,
    this.profilePicUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: json['str_USER_ID'] as String? ?? '',
      firstName: json['str_FIRST_NAME'] as String? ?? 'Utilisateur',
      lastName: json['str_LAST_NAME'] as String? ?? '',
      login: json['str_LOGIN'] as String? ?? '',
      officineName: json['OFFICINE'] as String? ?? 'Pharmacie',
      profilePicUrl: json['str_PIC'] as String?,
    );
  }

  String get fullName => '$firstName $lastName';
}
