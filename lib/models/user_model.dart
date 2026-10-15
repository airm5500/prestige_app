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

  /// Rôle donné par les serveurs récents à la connexion (`role {code, libelle}`, demande serveur 10, branche du
  /// 15/10/2026) : SYSTEME, SUPER_ADMINISTRATEUR, ADMINISTRATEUR, PHARMACIEN ou AUTRE ; vide sur un serveur plus
  /// ancien (champ absent). Sa présence signale aussi un serveur qui connaît les routes et paramètres livrés avec lui
  /// (vague1/profil_acces.dart, ProfilAcces.serveurRecent).
  final String roleCode;
  final String roleLibelle;

  AppUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.login,
    required this.officineName,
    this.profilePicUrl,
    this.typeUser = '',
    this.roleCode = '',
    this.roleLibelle = '',
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    String texte(Object? v) => v == null ? '' : v.toString().trim();
    return AppUser(
      userId: json['str_USER_ID'] as String? ?? '',
      firstName: json['str_FIRST_NAME'] as String? ?? 'Utilisateur',
      lastName: json['str_LAST_NAME'] as String? ?? '',
      login: json['str_LOGIN'] as String? ?? '',
      officineName: json['OFFICINE'] as String? ?? 'Pharmacie',
      profilePicUrl: json['str_PIC'] as String?,
      typeUser: json['xtypeuser']?.toString() ?? '',
      roleCode: role is Map ? texte(role['code']).toUpperCase() : '',
      roleLibelle: role is Map ? texte(role['libelle']) : '',
    );
  }

  String get fullName => '$firstName $lastName';
}
