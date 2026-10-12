// lib/utils/saisie.dart
// Contrôles de saisie communs (même principe que prestige_vente_app, lib/ventes/core/vente_input.dart) :
// rien d'absurde ne part au serveur. Longueurs maximales, caractères autorisés, bornes des nombres,
// périodes dans le bon ordre.
import 'package:flutter/services.dart';

class Saisie {
  Saisie._();

  /// Recherches (produit, fournisseur, client, n° de vente…).
  static const int maxRecherche = 60;

  /// Identifiant de connexion / mot de passe.
  static const int maxIdentifiant = 50;
  static const int maxMotDePasse = 128;

  /// Clé de licence.
  static const int maxCleLicence = 256;

  /// Quantités (filtre de stock, quantité à commander).
  static const int maxQuantite = 99999;

  /// Mois avant péremption.
  static const int maxMois = 120;

  /// Nombre de lignes du suivi 20/80.
  static const int maxLignes = 9999;

  /// Montants (FCFA) des calculs de ratio.
  static const double maxMontant = 999999999999;

  /// Marge (%) du filtre « Marge produits vendus ».
  static const int maxMarge = 999;

  /// Port du serveur, délai de déconnexion (minutes, 0 = désactivé, 24 h max).
  static const int portMin = 1, portMax = 65535;
  static const int maxDelaiDeconnexion = 1440;

  /// Nom de l'application serveur (contexte Payara, ex. « prestige »).
  static const int maxNomApplication = 50;
  static final RegExp _nomApplication = RegExp(r'^[A-Za-z0-9._-]+$');

  static final RegExp _controle = RegExp(r'[\x00-\x1F\x7F]');

  /// Texte de recherche nettoyé (caractères de contrôle retirés, espaces aux bords, longueur limitée).
  static String recherche(String? texte) {
    final t = (texte ?? '').replaceAll(_controle, '').trim();
    return t.length > maxRecherche ? t.substring(0, maxRecherche) : t;
  }

  /// Entier dans [min, max] (null si vide ou invalide).
  static int? entier(String? texte, {required int min, required int max}) {
    final v = int.tryParse((texte ?? '').trim());
    if (v == null || v < min || v > max) return null;
    return v;
  }

  /// Montant positif (virgule ou point décimal acceptés), null si invalide ou hors bornes.
  static double? montant(String? texte) {
    final v = double.tryParse((texte ?? '').trim().replaceAll(',', '.').replaceAll(' ', ''));
    if (v == null || v.isNaN || v < 0 || v > maxMontant) return null;
    return v;
  }

  /// Période : la date de fin n'est jamais avant la date de début (la date modifiée est gardée).
  static (DateTime, DateTime) periode(DateTime debut, DateTime fin, {required bool debutModifie}) {
    if (!fin.isBefore(debut)) return (debut, fin);
    return debutModifie ? (debut, debut) : (fin, fin);
  }

  /// Motif de refus du port, ou null.
  static String? erreurPort(String? texte) {
    final t = (texte ?? '').trim();
    if (t.isEmpty) return 'Le port est requis.';
    return entier(t, min: portMin, max: portMax) == null ? 'Port invalide ($portMin à $portMax).' : null;
  }

  /// Motif de refus du délai de déconnexion, ou null.
  static String? erreurDelai(String? texte) {
    final t = (texte ?? '').trim();
    if (t.isEmpty) return 'Le délai est requis.';
    return entier(t, min: 0, max: maxDelaiDeconnexion) == null ? 'Valeur invalide (0 à $maxDelaiDeconnexion minutes).' : null;
  }

  /// Motif de refus du nom de l'application serveur, ou null.
  static String? erreurNomApplication(String? texte) {
    final t = (texte ?? '').trim();
    if (t.isEmpty) return 'Le nom est requis.';
    if (t.length > maxNomApplication || !_nomApplication.hasMatch(t)) {
      return 'Lettres, chiffres, point, tiret ou souligné uniquement.';
    }
    return null;
  }

  /// Motif de refus de l'identifiant, ou null.
  static String? erreurIdentifiant(String? texte) {
    final t = (texte ?? '').trim();
    if (t.isEmpty) return 'Veuillez entrer un identifiant.';
    if (_controle.hasMatch(t)) return 'Identifiant invalide.';
    return null;
  }

  /// Motif de refus du mot de passe (envoyé tel quel, espaces compris), ou null.
  static String? erreurMotDePasse(String? texte) {
    if (texte == null || texte.isEmpty) return 'Veuillez entrer un mot de passe.';
    if (_controle.hasMatch(texte)) return 'Mot de passe invalide.';
    return null;
  }

  /// Clé de licence nettoyée (espaces aux bords et caractères de contrôle retirés).
  static String cleLicence(String? texte) => (texte ?? '').replaceAll(_controle, '').trim();

  /// N'accepte la nouvelle valeur que si elle respecte [motif] (sinon l'ancienne est gardée).
  static TextInputFormatter motif(RegExp motif) =>
      TextInputFormatter.withFunction((ancien, nouveau) => motif.hasMatch(nouveau.text) ? nouveau : ancien);

  static List<TextInputFormatter> get rechercheFormatters =>
      [FilteringTextInputFormatter.deny(_controle), LengthLimitingTextInputFormatter(maxRecherche)];
  static List<TextInputFormatter> get identifiantFormatters =>
      [FilteringTextInputFormatter.deny(_controle), LengthLimitingTextInputFormatter(maxIdentifiant)];
  static List<TextInputFormatter> get motDePasseFormatters =>
      [FilteringTextInputFormatter.deny(_controle), LengthLimitingTextInputFormatter(maxMotDePasse)];
  static List<TextInputFormatter> get cleLicenceFormatters =>
      [FilteringTextInputFormatter.deny(_controle), LengthLimitingTextInputFormatter(maxCleLicence)];

  /// Entier positif de [chiffres] chiffres au plus.
  static List<TextInputFormatter> entierFormatters(int chiffres) =>
      [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(chiffres)];

  /// Entier éventuellement négatif (« -12 »).
  static List<TextInputFormatter> entierSigneFormatters(int chiffres) =>
      [motif(RegExp(r'^-?\d*$')), LengthLimitingTextInputFormatter(chiffres + 1)];

  /// Montant : chiffres et un séparateur décimal (2 décimales au plus).
  static List<TextInputFormatter> get montantFormatters =>
      [motif(RegExp(r'^\d*([.,]\d{0,2})?$')), LengthLimitingTextInputFormatter(15)];

  static List<TextInputFormatter> get nomApplicationFormatters =>
      [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._-]')), LengthLimitingTextInputFormatter(maxNomApplication)];
}
