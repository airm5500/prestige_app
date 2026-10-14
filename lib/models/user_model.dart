// lib/models/user_model.dart

class AppUser {
  final String userId;
  final String firstName;
  final String lastName;
  final String login;
  final String officineName;
  final String? profilePicUrl;

  /// Profil donné par le serveur à la connexion (« xtypeuser ») : « dashboard » pour l'administrateur et le
  /// pharmacien, « mainmenumanager » pour les autres ; vide si inconnu (nouvelle_interface/vague1/profil_acces.dart).
  final String typeUser;

  AppUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.login,
    required this.officineName,
    this.profilePicUrl,
    this.typeUser = '',
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: json['str_USER_ID'] as String? ?? '',
      firstName: json['str_FIRST_NAME'] as String? ?? 'Utilisateur',
      lastName: json['str_LAST_NAME'] as String? ?? '',
      login: json['str_LOGIN'] as String? ?? '',
      officineName: json['OFFICINE'] as String? ?? 'Pharmacie',
      profilePicUrl: json['str_PIC'] as String?,
      typeUser: json['xtypeuser']?.toString() ?? '',
    );
  }

  String get fullName => '$firstName $lastName';
}
