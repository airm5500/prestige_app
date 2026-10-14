// lib/nouvelle_interface/vague1/alertes_vague1.dart
// Alertes du tableau de bord (vague 1) : UN SEUL appel GET /tableau-bord/alertes?per=6&rup=7&ren=7&sug=2&nv=30,
// À LA DEMANDE seulement (bouton ⟳ ; jamais au démarrage, au retour sur l'accueil ni en boucle). Le résultat et
// son heure sont mémorisés (par serveur et par compte, aussi après redémarrage) et partagés par :
//  - l'écran « Alertes » (toutes les alertes en cartes ; une alerte listable ouvre sa liste
//    GET /tableau-bord/alertes/liste?type=…&limite=500, sinon le module mobile correspondant s'il existe, sinon
//    le nombre seul) ;
//  - l'accueil A : l'alerte « Produits proches de la péremption » (alertes_accueil.dart) et la carte
//    « Toutes les alertes ».
// Mêmes états que les autres alertes de l'accueil : invitation « Touchez ⟳ », comptage en cours, nombre + « il y a
// X min », échecs distincts (injoignable, délai borné, session expirée → connexion, erreur du serveur, droit
// manquant).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presences/presences_modeles.dart' show sansAccents;
import '../../providers/home_settings_provider.dart';
import '../../providers/ip_config_provider.dart';
import '../../services/api_service.dart';
import '../alertes_accueil.dart';
import '../charte.dart';
import '../composants.dart';
import '../menus.dart';
import 'commun_vague1.dart';
import 'donnees_vague1.dart';

/// État des alertes : dernier résultat (éventuellement ancien) et son heure, comptage en cours, dernier échec.
class EtatAlertesTableauDeBord {
  final AlertesTableauDeBord? dernier;
  final DateTime? le;
  final bool enCours;
  final EchecComptage? echec;
  const EtatAlertesTableauDeBord({this.dernier, this.le, this.enCours = false, this.echec});
}

/// Échec d'un comptage d'alertes : comme les alertes de l'accueil, mais le droit manquant garde son message.
EchecComptage echecAlertes(Object e) {
  if (e is ApiLoadException && e.nature == NatureErreur.droit) return EchecComptage(CauseEchec.droit, e.message);
  return EchecComptage.depuis(e);
}

/// Alertes du tableau de bord comptées à la demande (une seule instance pour toute l'application).
class AlertesTableauBord extends ChangeNotifier {
  AlertesTableauBord._();
  static final instance = AlertesTableauBord._();

  static const clePreferences = 'alertes_tableau_bord_v1';

  EtatAlertesTableauDeBord _etat = const EtatAlertesTableauDeBord();
  String? _cle;
  int _generation = 0;

  EtatAlertesTableauDeBord get etat => _etat;

  /// Clé des résultats mémorisés : serveur visé et compte connecté (même règle que les alertes de l'accueil).
  static String cleDe(BuildContext context) => AlertesAccueil.cleDe(context);

  /// Prépare l'état pour [cle] sans appel au serveur : relit le dernier résultat mémorisé.
  void preparer(String cle) {
    if (cle == _cle) return;
    _cle = cle;
    _etat = const EtatAlertesTableauDeBord();
    final generation = ++_generation;
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final brut = prefs.getString(clePreferences);
        if (brut == null || generation != _generation) return;
        final j = jsonDecode(brut);
        if (j is! Map || j['cle'] != cle || j['le'] is! int || j['reponse'] is! Map) return;
        if (_etat.dernier != null || _etat.enCours) return;
        _etat = EtatAlertesTableauDeBord(
          dernier: AlertesTableauDeBord(Map<String, dynamic>.from(j['reponse'] as Map)),
          le: DateTime.fromMillisecondsSinceEpoch(j['le'] as int),
          echec: _etat.echec,
        );
        notifyListeners();
      } catch (_) {
        // Mémoire illisible : on repart de « Touchez ⟳ ».
      }
    }();
  }

  /// Oublie l'état en mémoire (tests) ; les préférences ne sont pas touchées.
  void oublier() {
    _generation++;
    _cle = null;
    _etat = const EtatAlertesTableauDeBord();
    notifyListeners();
  }

  /// Compte les alertes (appui sur ⟳). Ignoré si un comptage est déjà en cours (double appui).
  /// Délai borné par [AlertesAccueil.delaiMax] (le reste de l'application n'attend jamais).
  Future<void> actualiser(BuildContext context) async {
    if (_etat.enCours) return;
    preparer(cleDe(context));
    final generation = _generation;
    final cle = _cle!;
    _etat = EtatAlertesTableauDeBord(dernier: _etat.dernier, le: _etat.le, enCours: true);
    notifyListeners();
    EtatAlertesTableauDeBord suivant;
    try {
      final r = await ApiAlertes.compter(context).timeout(AlertesAccueil.delaiMax);
      final le = AlertesAccueil.maintenant();
      suivant = EtatAlertesTableauDeBord(dernier: r, le: le);
      if (generation == _generation) unawaited(_memoriser(cle, r, le));
    } catch (e) {
      suivant = EtatAlertesTableauDeBord(dernier: _etat.dernier, le: _etat.le, echec: echecAlertes(e));
    }
    if (generation != _generation) return; // compte ou serveur changé entre-temps
    _etat = suivant;
    notifyListeners();
  }

  static Future<void> _memoriser(String cle, AlertesTableauDeBord r, DateTime le) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(clePreferences, jsonEncode({'cle': cle, 'le': le.millisecondsSinceEpoch, 'reponse': r.brut}));
    } catch (_) {
      // Non mémorisé : le résultat reste affiché jusqu'à la fermeture de l'application.
    }
  }
}

/// Fait avancer « il y a X min » tant qu'un résultat est affiché (aucun appel au serveur).
mixin SuiviHeureAlertes<T extends StatefulWidget> on State<T> {
  Timer? _minute;

  void suivreLHeure(bool resultat) {
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
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Écran « Alertes »
// ---------------------------------------------------------------------------------------------------------------

Color _bande(Alerte a) {
  if (a.nombre == 0) return Charte.vert;
  return switch (a.type) {
    TypeAlerte.ruptures || TypeAlerte.peremptions => Charte.rouge,
    TypeAlerte.negatifs || TypeAlerte.nonVendus || TypeAlerte.avoirs => Charte.ambre,
    _ => Charte.navy2,
  };
}

/// Ouvre ce qui correspond à une alerte : sa liste, le module mobile (suggestions de commande) ou rien.
VoidCallback? actionAlerte(BuildContext context, Alerte a, {bool suggestionsVisibles = true}) {
  if (a.type.listable) {
    return () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlerteListeScreen(type: a.type)));
  }
  if (a.type == TypeAlerte.suggestionsCommande && suggestionsVisibles) {
    final menu = menusModules.where((m) => m.titre == 'Suggestions').firstOrNull;
    if (menu != null) return () => ouvrirModule(context, menu);
  }
  return null;
}

class AlertesScreen extends StatefulWidget {
  const AlertesScreen({super.key});

  @override
  State<AlertesScreen> createState() => _AlertesScreenState();
}

class _AlertesScreenState extends State<AlertesScreen> with SuiviHeureAlertes {
  @override
  Widget build(BuildContext context) {
    final alertes = AlertesTableauBord.instance;
    context.watch<IpConfigProvider>();
    alertes.preparer(AlertesTableauBord.cleDe(context));
    final suggestionsVisibles =
        menusVisibles(context.watch<HomeSettingsProvider>()).any((m) => m.titre == 'Suggestions');
    return ListenableBuilder(
      listenable: alertes,
      builder: (context, _) {
        final e = alertes.etat;
        suivreLHeure(e.dernier != null);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Alertes'),
            actions: [
              e.enCours
                  ? Semantics(
                      label: 'Comptage en cours',
                      child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Charte.blanc)))),
                    )
                  : IconButton(
                      key: const Key('alertes_actualiser'),
                      tooltip: 'Actualiser les alertes',
                      onPressed: () => alertes.actualiser(context),
                      icon: const Icon(Icons.refresh),
                    ),
            ],
          ),
          body: LayoutBuilder(builder: (context, c) {
            final colonnes = c.maxWidth >= 640 ? 2 : 1;
            final largeur = (c.maxWidth - 32 - (colonnes - 1) * 10) / colonnes;
            final d = e.dernier;
            return ListView(key: const Key('defilement_alertes'), padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
              _EnTeteAlertes(etat: e, compter: () => alertes.actualiser(context)),
              if (d != null) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final a in d.toutes)
                    SizedBox(
                      width: largeur,
                      child: CarteAlerte(alerte: a, onTap: actionAlerte(context, a, suggestionsVisibles: suggestionsVisibles)),
                    ),
                ]),
              ],
            ]);
          }),
        );
      },
    );
  }
}

/// Bandeau d'état des alertes : invitation, comptage en cours, échec, moment du dernier comptage.
class _EnTeteAlertes extends StatelessWidget {
  final EtatAlertesTableauDeBord etat;
  final VoidCallback compter;
  const _EnTeteAlertes({required this.etat, required this.compter});

  @override
  Widget build(BuildContext context) {
    final e = etat;
    final d = e.dernier;
    final enfants = <Widget>[];
    if (e.enCours) {
      enfants.add(const Row(key: Key('alertes_encours'), children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
        SizedBox(width: 10),
        Expanded(child: Text('Comptage en cours…', style: TextStyle(color: Charte.gris))),
      ]));
    }
    if (e.echec != null) {
      final droit = e.echec!.cause == CauseEchec.droit;
      enfants.add(Padding(
        padding: EdgeInsets.only(top: enfants.isEmpty ? 0 : 8),
        child: Encadre(
          key: const Key('alertes_echec'),
          titre: droit ? 'Droit manquant' : 'Comptage impossible',
          texte: e.echec!.message,
          icone: droit ? Icons.lock_outline : Icons.cloud_off,
          avertissement: droit,
        ),
      ));
    }
    if (d != null) {
      final n = d.typesAlerte;
      enfants.add(Padding(
        padding: EdgeInsets.only(top: enfants.isEmpty ? 0 : 8),
        child: Text.rich(
          key: const Key('alertes_moment'),
          TextSpan(children: [
            TextSpan(
                text: n == 0 ? 'Aucune alerte' : '$n ${n > 1 ? 'alertes' : 'alerte'} à surveiller',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Charte.encre)),
            TextSpan(
                text: ' · comptées ${momentComptage(e.le!, AlertesAccueil.maintenant())}', style: const TextStyle(color: Charte.gris, fontSize: 14)),
          ]),
        ),
      ));
    } else if (!e.enCours) {
      enfants.add(Padding(
        padding: EdgeInsets.only(top: enfants.isEmpty ? 0 : 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(
            'Pour ménager le serveur, les alertes sont comptées seulement à votre demande : ruptures, péremptions, '
            'stocks négatifs, produits jamais vendus, suggestions, ordonnances à renouveler, avoirs.',
            key: Key('alertes_invite'),
            style: TextStyle(color: Charte.gris, fontSize: 14),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            key: const Key('alertes_compter'),
            onPressed: compter,
            icon: const Icon(Icons.refresh),
            label: const Text('Compter les alertes'),
          ),
        ]),
      ));
    }
    return CarteBande(bande: Charte.navy, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: enfants));
  }
}

/// Carte d'une alerte : titre, nombre, précisions ; touchable si une liste ou un module y correspond.
class CarteAlerte extends StatelessWidget {
  final Alerte alerte;
  final VoidCallback? onTap;
  const CarteAlerte({super.key, required this.alerte, this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = alerte;
    final suite = a.type.listable
        ? 'Voir la liste'
        : (onTap != null ? 'Ouvrir les suggestions' : null);
    return CarteBande(
      key: Key('carte_alerte_${a.type.name}'),
      bande: _bande(a),
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.type.titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Charte.encre)),
            const SizedBox(height: 2),
            Text(a.nombreTexte,
                key: Key('nombre_alerte_${a.type.name}'),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: a.nombre == 0 ? Charte.vertTexte : Charte.encre)),
            Text(a.detail, style: const TextStyle(fontSize: 13, color: Charte.gris)),
            if (suite != null && a.nombre > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(suite, style: const TextStyle(fontSize: 13, color: Charte.navy, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        if (onTap != null) const Icon(Icons.chevron_right, color: Charte.gris),
      ]),
    );
  }
}

/// Carte « Toutes les alertes » de l'accueil A : résumé du dernier comptage (même mémoire que l'écran Alertes),
/// touchée, elle ouvre l'écran Alertes. Aucun appel au serveur.
class CarteToutesAlertes extends StatefulWidget {
  const CarteToutesAlertes({super.key});

  @override
  State<CarteToutesAlertes> createState() => _CarteToutesAlertesState();
}

class _CarteToutesAlertesState extends State<CarteToutesAlertes> with SuiviHeureAlertes {
  @override
  Widget build(BuildContext context) {
    final alertes = AlertesTableauBord.instance;
    context.watch<IpConfigProvider>();
    alertes.preparer(AlertesTableauBord.cleDe(context));
    return ListenableBuilder(
      listenable: alertes,
      builder: (context, _) {
        final e = alertes.etat;
        final d = e.dernier;
        suivreLHeure(d != null);
        final String resume;
        if (d == null) {
          resume = 'Ruptures, stocks négatifs, suggestions, renouvellements…';
        } else {
          final n = d.typesAlerte;
          resume = '${n == 0 ? 'Aucune alerte' : '$n ${n > 1 ? 'alertes' : 'alerte'} à surveiller'} · ${momentComptage(e.le!, AlertesAccueil.maintenant())}';
        }
        return CarteBande(
          key: const Key('alerte_toutes'),
          bande: Charte.navy,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertesScreen())),
          child: Row(children: [
            const IconeMenu(Icons.notifications_active_outlined, taille: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Toutes les alertes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Charte.encre)),
                Text(resume, key: const Key('alerte_toutes_resume'), style: const TextStyle(fontSize: 13, color: Charte.gris)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Charte.gris),
          ]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Liste d'une alerte
// ---------------------------------------------------------------------------------------------------------------

class AlerteListeScreen extends StatefulWidget {
  final TypeAlerte type;
  const AlerteListeScreen({super.key, required this.type});

  @override
  State<AlerteListeScreen> createState() => _AlerteListeScreenState();
}

class _AlerteListeScreenState extends State<AlerteListeScreen> {
  List<LigneAlerte>? _lignes;
  Object? _erreur;
  bool _chargement = false;
  String _filtre = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() async {
    if (_chargement) return;
    final generation = ++_generation;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final l = await ApiAlertes.liste(context, widget.type);
      if (!mounted || generation != _generation) return;
      setState(() {
        _lignes = l;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _erreur = e;
        _chargement = false;
      });
    }
  }

  List<LigneAlerte> get _visibles {
    final q = sansAccents(_filtre);
    final l = _lignes ?? const <LigneAlerte>[];
    if (q.isEmpty) return l;
    return [for (final x in l) if (sansAccents('${x.libelle} ${x.cip}').contains(q)) x];
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.type;
    final lignes = _lignes;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.titre),
        actions: [
          IconButton(
            key: const Key('liste_alerte_actualiser'),
            tooltip: 'Actualiser la liste',
            onPressed: _chargement ? null : _charger,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, c) {
        final tableau = c.maxWidth >= largeurTableauVague1;
        final visibles = _visibles;
        return ListView(key: const Key('defilement_liste_alerte'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          if (_chargement && lignes == null) const ChargementVague1(texte: 'Chargement de la liste…'),
          if (_erreur != null) ErreurVague1(_erreur!, reessayer: _charger),
          if (lignes != null) ...[
            ChampRechercheVague1(indication: 'Filtrer par produit ou CIP', onRecherche: (q) => setState(() => _filtre = q)),
            const SizedBox(height: 10),
            Text(
              key: const Key('liste_alerte_total'),
              lignes.length >= ReglagesAlertes.limiteListe
                  ? '${grouperMilliers(lignes.length)} lignes (les ${ReglagesAlertes.limiteListe} premières)'
                  : '${grouperMilliers(lignes.length)} ${lignes.length > 1 ? 'lignes' : 'ligne'}',
              style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (lignes.isEmpty)
              const VideVague1('Aucune ligne pour cette alerte.', icone: Icons.check_circle_outline)
            else if (visibles.isEmpty)
              const VideVague1('Aucune ligne ne correspond au filtre.')
            else if (tableau)
              TableauVague1<LigneAlerte>(
                colonnes: [
                  ColonneVague1('Produit', (l) => l.libelle, flex: 4),
                  ColonneVague1('CIP', (l) => l.cip),
                  for (final (i, (titre, _)) in (visibles.first.details(t)).indexed)
                    ColonneVague1(titre, (l) => l.details(t).length > i ? l.details(t)[i].$2 : '', nombre: titre.startsWith('Quantit') || titre == 'Stock'),
                ],
                lignes: visibles,
              )
            else
              for (final l in visibles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CarteBande(
                    bande: t == TypeAlerte.peremptions || t == TypeAlerte.ruptures ? Charte.rouge : Charte.ambre,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(l.libelle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Charte.encre)),
                      if (l.cip.isNotEmpty) Text('CIP ${l.cip}', style: const TextStyle(color: Charte.gris, fontSize: 13)),
                      for (final (titre, valeur) in l.details(t)) LigneValeurVague1(titre, valeur),
                    ]),
                  ),
                ),
          ],
        ]);
      }),
    );
  }
}
