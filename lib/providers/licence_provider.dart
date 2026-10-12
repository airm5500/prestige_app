import 'package:flutter/material.dart';
import 'package:prestige_app/models/licence_model.dart';
import 'package:prestige_app/services/api_service.dart';

/// `error` : le serveur n'a pas pu être interrogé (injoignable, délai, erreur) — la licence n'est PAS en cause.
enum LicenceStatus { unknown, valid, expired, notFound, checking, error }

class LicenceProvider extends ChangeNotifier {
  LicenceModel? _licence;
  LicenceStatus _status = LicenceStatus.unknown;
  String? _errorMessage;
  LicenceLookup? _dernierEchec;
  bool _verificationEnCours = false;

  LicenceModel? get licence => _licence;
  LicenceStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// Cause du dernier échec de vérification (serveur injoignable, application absente, erreur serveur).
  LicenceLookup? get dernierEchec => _dernierEchec;

  /// Une vérification est en cours (y compris un réessai silencieux).
  bool get verificationEnCours => _verificationEnCours;

  // Vérifier la licence au démarrage. Serveur injoignable ≠ licence introuvable (même principe que
  // prestige_vente_app). [silencieux] : réessai depuis l'écran « serveur injoignable », qui reste affiché
  // pendant la vérification (pas de retour à l'écran de démarrage).
  Future<void> checkLicence(BuildContext context, {bool silencieux = false}) async {
    if (_verificationEnCours) return;
    _verificationEnCours = true;
    if (!silencieux) _status = LicenceStatus.checking;
    notifyListeners();

    try {
      final apiService = ApiService(); // Ou via Provider si injecté
      final result = await apiService.lookupLicence(context);

      if (result.isConnectionProblem) {
        // Le serveur n'a pas répondu normalement : on ne conclut RIEN sur la licence.
        _dernierEchec = result;
        _status = LicenceStatus.error;
      } else if (result.licence != null) {
        _dernierEchec = null;
        _licence = result.licence;
        if (_licence!.isValid) {
          _status = LicenceStatus.valid;
        } else {
          _status = LicenceStatus.expired;
        }
      } else {
        _dernierEchec = null;
        _licence = null;
        _status = LicenceStatus.notFound;
      }
    } catch (e) {
      _dernierEchec = LicenceLookup.failure(LicenceIssue.unexpectedResponse, e.toString());
      _status = LicenceStatus.error;
    } finally {
      _verificationEnCours = false;
    }
    notifyListeners();
  }

  // Enregistrer une nouvelle licence
  Future<bool> registerLicence(BuildContext context, String key) async {
    try {
      final apiService = ApiService();
      await apiService.registerLicence(context, key);

      // Si succès, on revérifie immédiatement le statut
      await checkLicence(context);
      return _status == LicenceStatus.valid;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Logique des alertes périodiques
  String? getAlertMessage() {
    if (_licence == null) return null;

    final days = _licence!.daysRemaining;

    // La veille (1 jour ou 0 jour si c'est aujourd'hui)
    if (days <= 1 && days >= 0) {
      return "Attention : Votre licence expire ${days == 0 ? "aujourd'hui" : "demain"} !";
    }
    // 1 Semaine (entre 2 et 7 jours)
    if (days <= 7 && days > 1) {
      return "Rappel : Votre licence expire dans moins d'une semaine ($days jours).";
    }
    // 1 Mois (environ 30 jours, disons entre 25 et 30 pour cibler la notif)
    if (days <= 30 && days > 25) {
      return "Information : Il vous reste environ 1 mois de licence.";
    }
    // 3 Mois (environ 90 jours, disons entre 85 et 90)
    if (days <= 90 && days > 85) {
      return "Information : Échéance de licence dans 3 mois.";
    }

    return null;
  }

  // ... code existant ...

  // Méthode rapide pour vérifier si la date locale est dépassée
  // Utile quand l'app revient au premier plan
  void revalidateLocalStatus() {
    if (_licence != null) {
      if (!_licence!.isValid) {
        // Si la date est dépassée localement, on force le statut expiré
        _status = LicenceStatus.expired;
        notifyListeners();
      }
    }
  }
}