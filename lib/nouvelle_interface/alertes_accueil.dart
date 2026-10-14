// lib/nouvelle_interface/alertes_accueil.dart
// Alertes « À surveiller » de l'accueil « A · Tableau de bord », avec leur nombre compté À LA DEMANDE seulement
// (décision du pharmacien : ne pas surcharger le serveur). Aucun appel au démarrage, au retour sur l'accueil, à
// l'actualisation des chiffres du jour ni en boucle : seul l'appui sur ⟳ d'une alerte la compte.
//
//  - Produits proches de la péremption : depuis la vague 1, nombre de LOTS qui périment d'ici 6 mois lu dans
//    l'appel unique des alertes du tableau de bord, GET /tableau-bord/alertes?per=6&rup=7&ren=7&sug=2&nv=30
//    (vague1/alertes_vague1.dart : même ⟳, mêmes états, même mémoire que l'écran « Alertes ») ; touchée, l'alerte
//    ouvre la liste de ces mêmes lots (GET /tableau-bord/alertes/liste?type=peremptions). Les lots déjà périmés,
//    que liste aussi le module Suivi Péremption, n'y sont pas comptés (d'où le libellé « d'ici 6 mois ») ;
//  - Etat Contrôle Achat : GET /etat-control-bon/list-annuelle?dtStart=<jour>&dtEnd=<jour>&groupeId=&groupBy=GROUP
//    &limit=9999 (filtres par défaut de l'écran : période du jour, tous les groupes) → « Total Bons » (metaData).
//    L'appel des alertes du tableau de bord ne compte pas les bons contrôlés : cette alerte garde sa route.
// Cette route renvoie toute la liste pour compter (voir docs/serveur/ROUTES_DE_COMPTAGE.md).
//
// Dernier résultat et heure mémorisés (par serveur et par compte, aussi après redémarrage) et réaffichés au
// retour (« il y a 12 min »). Échecs distincts : serveur injoignable, délai dépassé, session expirée (retour à la
// connexion par le mécanisme existant d'ApiService / AuthProvider), erreur du serveur ; l'accueil reste utilisable.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/etat_controle_achat_meta_model.dart';
import '../models/etat_controle_achat_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ip_config_provider.dart';
import '../screens/etat_controle_achat_screen.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'charte.dart';
import 'composants.dart';
import 'vague1/alertes_vague1.dart';

/// Alertes de l'accueil A dont le nombre se compte à la demande.
enum AlerteAccueil {
  peremption('peremption', 'lot', 'lots', 'Actualiser les alertes (péremption, ruptures, suggestions…)'),
  controleAchat('controle', 'bon', 'bons', 'Actualiser le nombre de bons de livraison contrôlés');

  final String cle;
  final String unite;
  final String unites;

  /// Libellé accessible du bouton ⟳ (infobulle, lecteur d'écran).
  final String libelleBouton;
  const AlerteAccueil(this.cle, this.unite, this.unites, this.libelleBouton);

  /// « 1 lot », « 12 lots », « 0 bon ».
  String nombre(int n) => '${grouperChiffres(n)} ${n > 1 ? unites : unite}';
}

/// « 1 245 » (espaces insécables entre les milliers).
String grouperChiffres(int n) {
  final t = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < t.length; i++) {
    if (i > 0 && (t.length - i) % 3 == 0) b.write('\u00a0');
    b.write(t[i]);
  }
  return b.toString();
}

/// Résultat d'un comptage : le nombre et l'heure où il a été obtenu.
class ComptageAlerte {
  final int nombre;
  final DateTime le;
  const ComptageAlerte(this.nombre, this.le);

  Map<String, Object> versJson() => {'n': nombre, 'le': le.millisecondsSinceEpoch};

  static ComptageAlerte? depuisJson(Object? j) {
    if (j is! Map || j['n'] is! int || j['le'] is! int) return null;
    return ComptageAlerte(j['n'] as int, DateTime.fromMillisecondsSinceEpoch(j['le'] as int));
  }
}

/// Cause d'un comptage impossible (affichée sur l'alerte, sans toucher au reste de l'accueil).
enum CauseEchec { injoignable, delai, session, serveur, droit, autre }

class EchecComptage {
  final CauseEchec cause;
  final String message;
  const EchecComptage(this.cause, this.message);

  static EchecComptage depuis(Object e) {
    if (e is TimeoutException) return const EchecComptage(CauseEchec.delai, 'Le serveur met trop de temps à répondre.');
    if (e is! ApiLoadException) return const EchecComptage(CauseEchec.autre, 'Comptage impossible.');
    return switch (e.nature) {
      NatureErreur.reseau => const EchecComptage(CauseEchec.injoignable, 'Serveur injoignable. Vérifiez le réseau.'),
      NatureErreur.delai => const EchecComptage(CauseEchec.delai, 'Le serveur met trop de temps à répondre.'),
      NatureErreur.session => const EchecComptage(CauseEchec.session, 'Session expirée : reconnectez-vous.'),
      NatureErreur.serveur => EchecComptage(CauseEchec.serveur, 'Erreur du serveur${e.code == null ? '' : ' (code ${e.code})'}.'),
      NatureErreur.droit => const EchecComptage(CauseEchec.droit, 'Accès refusé pour ce compte.'),
      NatureErreur.refus || NatureErreur.reponse => const EchecComptage(CauseEchec.autre, 'Réponse inattendue du serveur.'),
    };
  }
}

/// État d'une alerte : dernier résultat (éventuellement ancien), comptage en cours, dernier échec.
class EtatAlerte {
  final ComptageAlerte? dernier;
  final bool enCours;
  final EchecComptage? echec;
  const EtatAlerte({this.dernier, this.enCours = false, this.echec});
}

/// Moment d'un comptage : « à 14:32 » (moins d'une minute), « il y a 12 min », « il y a 2 h (à 14:32) » le même
/// jour, sinon « le 12/10 à 14:32 ».
String momentComptage(DateTime le, DateTime maintenant) {
  String deux(int v) => v.toString().padLeft(2, '0');
  final heure = '${deux(le.hour)}:${deux(le.minute)}';
  final age = maintenant.difference(le);
  if (age.inMinutes < 1) return 'à $heure';
  if (age.inMinutes < 60) return 'il y a ${age.inMinutes} min';
  final memeJour = le.year == maintenant.year && le.month == maintenant.month && le.day == maintenant.day;
  if (memeJour) return 'il y a ${age.inHours} h (à $heure)';
  return 'le ${deux(le.day)}/${deux(le.month)} à $heure';
}

/// « Total Bons » que l'écran Etat Contrôle Achat affiche pour cette réponse (aucune ligne : « Aucune donnée »,
/// soit 0) ; sans metaData, la somme de la colonne « Nb Bons ».
int compterBonsControle(dynamic reponse) {
  if (reponse is! Map) return 0;
  final data = reponse['data'];
  if (data is! List || data.isEmpty) return 0;
  try {
    final meta = reponse['metaData'];
    if (meta is Map) return EtatControleAchatMeta.fromJson(Map<String, dynamic>.from(meta)).totalNbreBon;
    return data.fold<int>(0, (s, e) => s + EtatControleAchat.fromJson(Map<String, dynamic>.from(e as Map)).nbreBon);
  } catch (_) {
    throw const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse);
  }
}

/// Comptages à la demande des alertes de l'accueil A (un seul pour toute l'application : l'état survit au
/// passage dans un module ou un autre onglet).
class AlertesAccueil extends ChangeNotifier {
  AlertesAccueil._() {
    // L'alerte péremption suit l'appel unique des alertes du tableau de bord (comptage fait ici ou sur l'écran Alertes).
    AlertesTableauBord.instance.addListener(notifyListeners);
  }
  static final instance = AlertesAccueil._();

  /// Délai maximal d'un comptage (le reste de l'accueil n'attend jamais).
  static const delaiParDefaut = Duration(seconds: 20);
  static Duration delaiMax = delaiParDefaut;

  /// Horloge (remplaçable dans les tests).
  static DateTime Function() maintenant = DateTime.now;

  static const clePreferences = 'alertes_accueil_comptages';

  final _etats = <AlerteAccueil, EtatAlerte>{};
  String? _cle;
  int _generation = 0;

  EtatAlerte etat(AlerteAccueil a) {
    if (a == AlerteAccueil.peremption) {
      final e = AlertesTableauBord.instance.etat;
      final d = e.dernier;
      return EtatAlerte(dernier: d == null ? null : ComptageAlerte(d.peremptionsLots, e.le!), enCours: e.enCours, echec: e.echec);
    }
    return _etats[a] ?? const EtatAlerte();
  }

  /// Clé des résultats mémorisés : serveur visé et compte connecté (jamais les nombres d'un autre compte).
  static String cleDe(BuildContext context) {
    final ip = context.read<IpConfigProvider>();
    final auth = context.read<AuthProvider>();
    return '${ip.activeBaseUrl}|${auth.user?.login ?? ''}';
  }

  /// Prépare l'état pour [cle] (sans aucun appel au serveur) : relit les derniers résultats mémorisés.
  /// Peut être appelé pendant la construction de l'accueil (ne notifie qu'après la lecture).
  void preparer(String cle) {
    AlertesTableauBord.instance.preparer(cle);
    if (cle == _cle) return;
    _cle = cle;
    _etats.clear();
    final generation = ++_generation;
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final brut = prefs.getString(clePreferences);
        if (brut == null || generation != _generation) return;
        final j = jsonDecode(brut);
        if (j is! Map || j['cle'] != cle) return;
        var change = false;
        for (final a in AlerteAccueil.values.where((a) => a != AlerteAccueil.peremption)) {
          final c = ComptageAlerte.depuisJson(j[a.cle]);
          if (c != null && _etats[a]?.dernier == null && !(etat(a).enCours)) {
            _etats[a] = EtatAlerte(dernier: c, echec: etat(a).echec);
            change = true;
          }
        }
        if (change) notifyListeners();
      } catch (_) {
        // Mémoire illisible ou indisponible : on repart de « Touchez ⟳ pour compter ».
      }
    }();
  }

  /// Oublie tout (tests) : état en mémoire ; les préférences ne sont pas touchées.
  void oublier() {
    AlertesTableauBord.instance.oublier();
    _generation++;
    _cle = null;
    _etats.clear();
    notifyListeners();
  }

  /// Compte [a] (appui sur ⟳). Ignoré si un comptage de cette alerte est déjà en cours (double appui).
  Future<void> compter(BuildContext context, AlerteAccueil a) async {
    if (a == AlerteAccueil.peremption) return AlertesTableauBord.instance.actualiser(context);
    if (etat(a).enCours) return;
    preparer(cleDe(context));
    final generation = _generation;
    final cle = _cle!;
    _etats[a] = EtatAlerte(dernier: etat(a).dernier, enCours: true);
    notifyListeners();
    EtatAlerte suivant;
    try {
      final n = await _appel(context, a).timeout(delaiMax);
      final c = ComptageAlerte(n, maintenant());
      suivant = EtatAlerte(dernier: c);
      if (generation == _generation) unawaited(_memoriser(cle, a, c));
    } catch (e) {
      suivant = EtatAlerte(dernier: etat(a).dernier, echec: EchecComptage.depuis(e));
    }
    if (generation != _generation) return; // compte ou serveur changé entre-temps
    _etats[a] = suivant;
    notifyListeners();
  }

  /// MÊMES route et paramètres que le module à son ouverture.
  static Future<int> _appel(BuildContext context, AlerteAccueil a) async {
    switch (a) {
      case AlerteAccueil.peremption:
        throw StateError('compté par AlertesTableauBord');
      case AlerteAccueil.controleAchat:
        final jour = DateTime.now();
        final r = await ApiService().get(context, AppConstants.etatControleAchatEndpoint, queryParams: parametresEtatControleAchat(jour, jour));
        return compterBonsControle(r);
    }
  }

  static Future<void> _memoriser(String cle, AlerteAccueil a, ComptageAlerte c) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, Object?> j = {};
      final brut = prefs.getString(clePreferences);
      if (brut != null) {
        final ancien = jsonDecode(brut);
        if (ancien is Map && ancien['cle'] == cle) j = Map<String, Object?>.from(ancien);
      }
      j['cle'] = cle;
      j[a.cle] = c.versJson();
      await prefs.setString(clePreferences, jsonEncode(j));
    } catch (_) {
      // Non mémorisé : le nombre reste affiché jusqu'à la fermeture de l'application.
    }
  }
}

/// Une alerte de l'accueil A : touchée, elle ouvre le module ; son bouton ⟳ (48 dp, libellé) compte à la demande.
class AlerteComptee extends StatefulWidget {
  final AlerteAccueil alerte;
  final Color bande;
  final String titre;
  final String detail;
  final VoidCallback onTap;
  const AlerteComptee({super.key, required this.alerte, required this.bande, required this.titre, required this.detail, required this.onTap});

  @override
  State<AlerteComptee> createState() => _AlerteCompteeState();
}

class _AlerteCompteeState extends State<AlerteComptee> {
  Timer? _minute;

  @override
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }

  /// « il y a X min » avance tant que l'alerte est affichée (aucun appel au serveur).
  void _suivreLHeure(bool resultat) {
    if (resultat && _minute == null) {
      _minute = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    } else if (!resultat) {
      _minute?.cancel();
      _minute = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertes = AlertesAccueil.instance;
    context.watch<IpConfigProvider>();
    context.watch<AuthProvider>();
    alertes.preparer(AlertesAccueil.cleDe(context));
    return ListenableBuilder(
      listenable: alertes,
      builder: (context, _) {
        final e = alertes.etat(widget.alerte);
        final d = e.dernier;
        _suivreLHeure(d != null);
        final cleTest = widget.alerte.cle;
        const petit = TextStyle(fontSize: 13, color: Charte.gris);
        final lignes = <Widget>[];
        if (e.enCours) {
          lignes.add(Text('Comptage en cours…', key: Key('alerte_${cleTest}_encours'), style: petit));
        } else if (e.echec != null) {
          lignes.add(Text(e.echec!.message, key: Key('alerte_${cleTest}_echec'), style: const TextStyle(fontSize: 13, color: Charte.rougeTexte, fontWeight: FontWeight.w600)));
        }
        if (d != null) {
          lignes.add(Text.rich(
            key: Key('alerte_${cleTest}_nombre'),
            TextSpan(children: [
              TextSpan(text: widget.alerte.nombre(d.nombre), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Charte.encre)),
              TextSpan(text: ' · ${momentComptage(d.le, AlertesAccueil.maintenant())}', style: petit),
            ]),
          ));
        } else if (!e.enCours && e.echec == null) {
          lignes.add(Text.rich(
            key: Key('alerte_${cleTest}_invite'),
            const TextSpan(style: petit, children: [
              TextSpan(text: 'Touchez '),
              WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.refresh, size: 16, color: Charte.gris)),
              TextSpan(text: ' pour compter'),
            ]),
            semanticsLabel: 'Touchez Actualiser pour compter',
          ));
        }
        return CarteBande(
          bande: widget.bande,
          onTap: widget.onTap,
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(widget.titre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Charte.encre)),
                Text(widget.detail, style: petit),
                const SizedBox(height: 2),
                ...lignes,
              ]),
            ),
            SizedBox(
              width: 48,
              height: 48,
              child: e.enCours
                  ? Semantics(
                      label: 'Comptage en cours',
                      child: const Center(
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Charte.navy)),
                      ),
                    )
                  : IconButton(
                      key: Key('alerte_${cleTest}_actualiser'),
                      tooltip: widget.alerte.libelleBouton,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      padding: EdgeInsets.zero,
                      onPressed: () => alertes.compter(context, widget.alerte),
                      icon: const Icon(Icons.refresh, color: Charte.navy),
                    ),
            ),
            const Icon(Icons.chevron_right, color: Charte.gris),
          ]),
        );
      },
    );
  }
}
