// lib/nouvelle_interface/alertes_accueil.dart
// Alertes « À surveiller » de l'accueil « A · Tableau de bord », avec leur nombre compté À LA DEMANDE seulement
// (décision du pharmacien : ne pas surcharger le serveur). Aucun appel au démarrage, au retour sur l'accueil, à
// l'actualisation des chiffres du jour ni en boucle : seul l'appui sur ⟳ compte.
//
// Depuis la 3.1.0, tout le bloc vient de l'APPEL UNIQUE des alertes du tableau de bord,
// GET /tableau-bord/alertes?per=6&rup=7&ren=7&sug=2&nv=30 (délais réglables, vague1/alertes_vague1.dart : même ⟳,
// mêmes états, même mémoire que l'écran « Alertes ») : un seul ⟳ actualise tout le bloc.
//  - Produits proches de la péremption : nombre de LOTS qui périment dans les N prochains mois (hors lots déjà
//    périmés, que liste aussi le module Suivi Péremption) ; touchée, l'alerte ouvre la liste de ces mêmes lots
//    (GET /tableau-bord/alertes/liste?type=peremptions) ;
//  - Ruptures de stock : produits actifs à stock nul ; touchée, l'alerte ouvre leur liste (…/liste?type=ruptures).
// L'ancienne alerte « Contrôle des bons de livraison » (GET /etat-control-bon/list-annuelle) est retirée de
// l'accueil (décision du pharmacien) ; le module Etat Contrôle Achat est inchangé.
//
// Dernier résultat et heure mémorisés (par serveur et par compte, aussi après redémarrage) et réaffichés au
// retour (« il y a 12 min »). Échecs distincts : serveur injoignable, délai dépassé, session expirée (retour à la
// connexion par le mécanisme existant d'ApiService / AuthProvider), erreur du serveur ; l'accueil reste utilisable.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/ip_config_provider.dart';
import '../services/api_service.dart';
import 'charte.dart';
import 'composants.dart';
import 'vague1/alertes_vague1.dart';
import 'vague1/donnees_vague1.dart';

/// Alertes de l'accueil A : toutes lues dans l'appel unique des alertes du tableau de bord.
enum AlerteAccueil {
  peremption('peremption', 'lot', 'lots'),
  ruptures('ruptures', 'produit', 'produits');

  final String cle;
  final String unite;
  final String unites;
  const AlerteAccueil(this.cle, this.unite, this.unites);

  /// Libellé accessible du bouton ⟳ (infobulle, lecteur d'écran) : il actualise tout le bloc.
  String get libelleBouton => 'Actualiser les alertes (péremption, ruptures, suggestions…)';

  /// « 1 lot », « 12 lots », « 0 produit ».
  String nombre(int n) => '${grouperChiffres(n)} ${n > 1 ? unites : unite}';

  /// Nombre de cette alerte dans la réponse de GET /tableau-bord/alertes.
  int dans(AlertesTableauDeBord r) => switch (this) {
        AlerteAccueil.peremption => r.peremptionsLots,
        AlerteAccueil.ruptures => r.ruptures,
      };
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
      NatureErreur.reseau when e.certificatRefuse => const EchecComptage(CauseEchec.injoignable, 'Certificat du serveur refusé (HTTPS).'),
      NatureErreur.reseau => const EchecComptage(CauseEchec.injoignable, ApiLoadException.messageReseau),
      NatureErreur.delai => const EchecComptage(CauseEchec.delai, 'Le serveur met trop de temps à répondre.'),
      NatureErreur.session => const EchecComptage(CauseEchec.session, 'Session expirée : reconnectez-vous.'),
      NatureErreur.serveur when e.serveurIndisponible => const EchecComptage(CauseEchec.serveur, ApiLoadException.messageServeurIndisponible),
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

/// Alertes de l'accueil A (une seule instance pour toute l'application : l'état survit au passage dans un module
/// ou un autre onglet). Simple vue sur [AlertesTableauBord] : un comptage = un appel, qui met à jour tout le bloc.
class AlertesAccueil extends ChangeNotifier {
  AlertesAccueil._() {
    AlertesTableauBord.instance.addListener(notifyListeners);
  }
  static final instance = AlertesAccueil._();

  /// Délai maximal d'un comptage (le reste de l'accueil n'attend jamais).
  static const delaiParDefaut = Duration(seconds: 20);
  static Duration delaiMax = delaiParDefaut;

  /// Horloge (remplaçable dans les tests).
  static DateTime Function() maintenant = DateTime.now;

  EtatAlerte etat(AlerteAccueil a) {
    final e = AlertesTableauBord.instance.etat;
    final d = e.dernier;
    return EtatAlerte(dernier: d == null ? null : ComptageAlerte(a.dans(d), e.le!), enCours: e.enCours, echec: e.echec);
  }

  /// Clé des résultats mémorisés : serveur visé et compte connecté (jamais les nombres d'un autre compte).
  static String cleDe(BuildContext context) {
    final ip = context.read<IpConfigProvider>();
    final auth = context.read<AuthProvider>();
    return '${ip.activeBaseUrl}|${auth.user?.login ?? ''}';
  }

  /// Prépare l'état pour [cle] (sans aucun appel au serveur) : relit le dernier résultat mémorisé.
  void preparer(String cle) => AlertesTableauBord.instance.preparer(cle);

  /// Oublie tout (tests) : état en mémoire ; les préférences ne sont pas touchées.
  void oublier() => AlertesTableauBord.instance.oublier();

  /// Compte les alertes (appui sur le ⟳ de n'importe quelle alerte) : un seul appel pour tout le bloc ; ignoré si
  /// un comptage est déjà en cours (double appui).
  Future<void> compter(BuildContext context, [AlerteAccueil? a]) => AlertesTableauBord.instance.actualiser(context);
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
