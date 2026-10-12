// lib/models/licence_lookup.dart
// Résultat détaillé de la vérification de licence : distingue un problème de connexion d'un problème
// de licence (copie de prestige_vente_app).
import 'licence_model.dart';

enum LicenceIssue {
  /// Aucun serveur ne répond à l'adresse configurée (Wi-Fi, IP, serveur éteint, délai).
  unreachable,

  /// Un serveur répond, mais l'application Prestige n'est pas déployée à cette adresse
  /// (nom d'application ou port incorrect, application arrêtée).
  appNotFound,

  /// L'application Prestige répond avec une erreur (500, 401...).
  serverError,

  /// Réponse illisible (ce n'est probablement pas un serveur Prestige).
  unexpectedResponse,
}

class LicenceLookup {
  final LicenceModel? licence;
  final LicenceIssue? issue;
  final String? detail;

  const LicenceLookup.found(LicenceModel this.licence)
      : issue = null,
        detail = null;

  /// Le serveur Prestige a répondu : aucune licence enregistrée.
  const LicenceLookup.noLicence()
      : licence = null,
        issue = null,
        detail = null;

  const LicenceLookup.failure(LicenceIssue this.issue, this.detail) : licence = null;

  bool get isConnectionProblem => issue != null;
}
