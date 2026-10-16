// lib/nouvelle_interface/vague4/tableau_bord_vague4.dart
// 3.11.0 (décision du pharmacien) — le TABLEAU DE BORD, page d'accueil par défaut, inspiré du tableau de bord web de
// Prestige (view/tableaubord/TableauBord.js) et choisi pour un écran de téléphone. Cartes (chacune affichable /
// masquable et déplaçable, choix mémorisé sur l'appareil) :
//  - Chiffres du jour : CA net, marge, panier moyen, achats du jour — GET /tableau-bord/tuiles?date= ; serveur sans
//    cette route (branche dev) : GET /recap/dashboard/daily (tableau de bord web historique) ;
//  - Évolution du mois par pas de 5 jours — GET /ws/ca-achats-ventes?dtStart=1er du mois&dtEnd=aujourd'hui (chiffre
//    jour par jour, regroupé par l'application) ;
//  - Fréquentation horaire : Aujourd'hui / Hier / Personnaliser (une date) — GET /pilotage/suivi/frequentation
//    (axe PERSO du jour au jour, comparé à la veille) ; sans droit Pilotage ou sans cette route : GET
//    /tableau-bord/frequentation?date= (semaine du lundi au jour choisi) ;
//  - Valorisation du stock — GET /tableau-bord/valorisation ; sinon GET /produit/valorisation (calcul du jour) ;
//  - Encaissements du jour — GET /tableau-bord/encaissements?date= ;
//  - Top 10 des ventes du mois par emplacement / par famille — GET /tableau-bord/emplacements?date=&limite=10&axe= ;
//  - Ventes du mois par taux de TVA — GET /api/v3/tvas (Stat TVA).
// Une carte dont la route manque sur le serveur (404) affiche « Indisponible sur ce serveur » ; une erreur d'une carte
// ne gêne jamais les autres. Chaque carte ne charge qu'à son affichage (liste construite à la demande) ; ⟳ recharge
// tout. L'accès aux menus reste : bouton « Tous les menus » en haut et barre du bas.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../donnees/analyses_ventes_donnees.dart';
import '../../donnees/tableau_bord_donnees.dart';
import '../../models/stat_tva_model.dart';
import '../../models/tableau_bord_achats_ventes_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/date_formatter.dart';
import '../accueil_nouveau.dart' show BoutonDeconnexion, BoutonReglages, PastilleServeur, TousLesMenusScreen;
import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/commun_lot3.dart' show CadreGraphique, GraphiqueCourbes, SerieGraphique;
import '../modules/periode.dart';
import '../vague1/donnees_vague1.dart' show ApiValorisation, ModeValorisation, Valorisation, getVague1;
import '../vague2/commun_vague2.dart' show BarresHorizontales, Variation;
import '../vague2/donnees_vague2.dart' show ApiVague2, decimalOuNull, entierTolerant, grouperMilliers, pourcentTexte, texteTolerant;

// ---------------------------------------------------------------------------------------------------------------
// Cartes et préférences
// ---------------------------------------------------------------------------------------------------------------

enum CarteTableauBord {
  chiffres('Chiffres du jour', Icons.dashboard_outlined),
  evolution('Évolution du mois', Icons.show_chart),
  frequentation('Fréquentation horaire', Icons.schedule),
  valorisation('Valorisation du stock', Icons.inventory_2_outlined),
  encaissements('Encaissements du jour', Icons.payments_outlined),
  top('Top 10 des ventes du mois', Icons.emoji_events_outlined),
  tva('Ventes du mois par taux de TVA', Icons.pie_chart_outline);

  final String titre;
  final IconData icone;
  const CarteTableauBord(this.titre, this.icone);
}

/// Une carte et son affichage.
typedef ChoixCarte = ({CarteTableauBord carte, bool visible});

/// Cartes du tableau de bord : ordre et visibilité, mémorisés sur l'appareil.
class CartesTableauBordPrefs {
  CartesTableauBordPrefs._();
  static const cle = 'tableau_bord_cartes_v1';

  static List<ChoixCarte> get defaut => [for (final c in CarteTableauBord.values) (carte: c, visible: true)];

  static final cartes = ValueNotifier<List<ChoixCarte>>(defaut);

  /// « chiffres:1,evolution:0,… » → liste ; cartes inconnues ignorées, cartes absentes ajoutées à la fin (visibles).
  static List<ChoixCarte> lire(String? texte) {
    if (texte == null || texte.trim().isEmpty) return defaut;
    final noms = CarteTableauBord.values.asNameMap();
    final l = <ChoixCarte>[];
    for (final morceau in texte.split(',')) {
      final p = morceau.split(':');
      final c = noms[p.first.trim()];
      if (c == null || l.any((x) => x.carte == c)) continue;
      l.add((carte: c, visible: p.length < 2 || p[1].trim() != '0'));
    }
    for (final c in CarteTableauBord.values) {
      if (!l.any((x) => x.carte == c)) l.add((carte: c, visible: true));
    }
    return l;
  }

  static String ecrire(List<ChoixCarte> l) => [for (final x in l) '${x.carte.name}:${x.visible ? 1 : 0}'].join(',');

  static Future<void> charger() async {
    try {
      cartes.value = lire((await SharedPreferences.getInstance()).getString(cle));
    } catch (_) {
      cartes.value = defaut;
    }
  }

  static Future<void> enregistrer(List<ChoixCarte> l) async {
    cartes.value = List.unmodifiable(l);
    try {
      await (await SharedPreferences.getInstance()).setString(cle, ecrire(l));
    } catch (_) {}
  }
}

/// Route absente sur ce serveur (404 « métier » : Prestige répond, la route n'existe pas).
bool routeAbsente(Object e) => e is ApiLoadException && e.code == 404 && !e.serveurIndisponible;

/// Lecture d'un nombre affiché par le serveur (« 1 245 300 », « 12,5 »).
double nombreAffiche(Object? v) {
  if (v is num) return v.toDouble();
  final t = '${v ?? ''}'.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.');
  return double.tryParse(t) ?? 0;
}

// ---------------------------------------------------------------------------------------------------------------
// Données
// ---------------------------------------------------------------------------------------------------------------

class ChiffresTableauBord {
  final int ca;
  final int clients;
  final double? evolutionVeille;
  final int marge;
  final double? tauxMarge;
  final int panier;
  final int achats;
  final int bons;

  /// Lu sur l'ancienne route (/recap/dashboard/daily).
  final bool ancienneRoute;
  const ChiffresTableauBord(this.ca, this.clients, this.evolutionVeille, this.marge, this.tauxMarge, this.panier, this.achats, this.bons,
      {this.ancienneRoute = false});
}

class ApiTableauBord {
  ApiTableauBord._();

  static const routeTuiles = '/tableau-bord/tuiles';
  static const routeDaily = '/recap/dashboard/daily';
  static const routeFrequentation = '/tableau-bord/frequentation';
  static const routeFrequentationPilotage = '/pilotage/suivi/frequentation';
  static const routeEncaissements = '/tableau-bord/encaissements';
  static const routeEmplacements = '/tableau-bord/emplacements';

  static String jour(DateTime d) => DateFormatter.toApiFormat(d);

  static Future<ChiffresTableauBord> chiffres(BuildContext context, DateTime maintenant) async {
    try {
      final j = await ApiVague2.get(context, routeTuiles, {'date': jour(maintenant)}, 'les chiffres du jour');
      final a = j['achats'] is Map ? Map<String, dynamic>.from(j['achats'] as Map) : const <String, dynamic>{};
      return ChiffresTableauBord(entierTolerant(j['ca']), entierTolerant(j['clients']), decimalOuNull(j['evolutionVeille']), entierTolerant(j['marge']),
          decimalOuNull(j['tauxMarge']), entierTolerant(j['panier']), entierTolerant(a['ttc']), entierTolerant(a['bl']));
    } catch (e) {
      if (!routeAbsente(e)) rethrow;
    }
    if (!context.mounted) throw const ApiLoadException('Écran fermé.', nature: NatureErreur.refus);
    // Serveur sans /tableau-bord (branche dev) : la route du tableau de bord web historique (aujourd'hui seulement).
    final r = await ApiService().get(context, routeDaily);
    final d = r is Map ? r : const {};
    return ChiffresTableauBord(nombreAffiche(d['DailyCA']).round(), nombreAffiche(d['DailyCount']).round(), null, nombreAffiche(d['MARGENET']).round(),
        null, nombreAffiche(d['PanierMY']).round(), nombreAffiche(d['DailyAchatAmount']).round(), nombreAffiche(d['DailyAchatCount']).round(),
        ancienneRoute: true);
  }

  /// Chiffre d'affaires du mois par pas de 5 jours : (premier jour de la tranche, dernier jour, ventes, achats).
  static List<(DateTime, DateTime, double, double)> parCinqJours(List<TableauBordAchatsVentes> lignes, DateTime maintenant) {
    final fin = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final tranches = <(DateTime, DateTime, double, double)>[];
    for (var debut = DateTime(fin.year, fin.month, 1); !debut.isAfter(fin); debut = DateTime(debut.year, debut.month, debut.day + 5)) {
      // La dernière tranche du mois absorbe le 31 (26 → 31) plutôt que de laisser une tranche d'un jour.
      var f = DateTime(debut.year, debut.month, debut.day + 4);
      if (debut.day == 26) f = DateTime(debut.year, debut.month + 1, 0);
      if (f.isAfter(fin)) f = fin;
      var v = 0.0, a = 0.0;
      for (final l in lignes) {
        final d = l.dateMvt;
        if (d == null || d.isBefore(debut) || d.isAfter(f)) continue;
        v += l.montantVente;
        a += l.montantAchat;
      }
      tranches.add((debut, f, v, a));
      if (debut.day == 26) break;
    }
    return tranches;
  }

  static Future<List<(DateTime, DateTime, double, double)>> evolution(BuildContext context, DateTime maintenant) async {
    final l = await TableauBord.charger(context, DateTime(maintenant.year, maintenant.month, 1), maintenant) ?? const [];
    return parCinqJours(l, maintenant);
  }

  /// Fréquentation d'une journée : ventes par heure (24) et celles du jour de comparaison ; [semaine] : repli sur la
  /// route du tableau de bord (semaine du lundi au jour choisi).
  static Future<({List<int> ventes, List<int>? reference, String libelle, bool semaine})> frequentation(BuildContext context, DateTime jourChoisi) async {
    List<int> heures(Object? v) => v is List ? [for (final x in v) entierTolerant(x)] : const [];
    try {
      final j = await ApiVague2.get(context, routeFrequentationPilotage,
          {'axe': 'PERSO', 'dtStart': jour(jourChoisi), 'dtEnd': jour(jourChoisi)}, 'la fréquentation');
      final c = j['courante'] is Map ? Map<String, dynamic>.from(j['courante'] as Map) : const <String, dynamic>{};
      final r = j['reference'] is Map ? Map<String, dynamic>.from(j['reference'] as Map) : null;
      return (ventes: heures(c['ventesH']), reference: r == null ? null : heures(r['ventesH']), libelle: 'comparé à la veille', semaine: false);
    } catch (e) {
      final repli = routeAbsente(e) || (e is ApiLoadException && e.nature == NatureErreur.droit);
      if (!repli) rethrow;
    }
    if (!context.mounted) throw const ApiLoadException('Écran fermé.', nature: NatureErreur.refus);
    final j = await ApiVague2.get(context, routeFrequentation, {'date': jour(jourChoisi)}, 'la fréquentation');
    final s = j['semaine'] is Map ? Map<String, dynamic>.from(j['semaine'] as Map) : const <String, dynamic>{};
    final p = j['precedente'] is Map ? Map<String, dynamic>.from(j['precedente'] as Map) : null;
    return (ventes: heures(s['ventesH']), reference: p == null ? null : heures(p['ventesH']), libelle: 'semaine du lundi au jour choisi', semaine: true);
  }

  static Future<Valorisation> valorisation(BuildContext context, DateTime maintenant) async {
    try {
      final j = await getVague1(context, ApiValorisation.routeTableauDeBord, {'frais': '0'}, 'la valorisation du stock');
      return Valorisation.depuisTableauDeBord(j);
    } catch (e) {
      if (!routeAbsente(e)) rethrow;
    }
    if (!context.mounted) throw const ApiLoadException('Écran fermé.', nature: NatureErreur.refus);
    final j = await getVague1(context, ApiValorisation.routeProduit, ApiValorisation.parametresProduit(ModeValorisation.simple, maintenant, const []),
        'la valorisation du stock');
    return Valorisation.depuisProduit(j, duJour: true);
  }

  static Future<List<(String, int)>> encaissements(BuildContext context, DateTime maintenant) async {
    final j = await ApiVague2.get(context, routeEncaissements, {'date': jour(maintenant)}, 'les encaissements');
    final m = j['modes'];
    return [
      if (m is List)
        for (final x in m)
          if (x is Map) (texteTolerant(x['libelle']), entierTolerant(x['montant'])),
    ];
  }

  static Future<List<(String, int)>> top(BuildContext context, DateTime maintenant, {required bool famille}) async {
    final j = await ApiVague2.get(context, routeEmplacements, {'date': jour(maintenant), 'limite': '10', 'axe': famille ? 'famille' : 'emplacement'},
        'le top des ventes');
    final d = j['data'];
    return [
      if (d is List)
        for (final x in d)
          if (x is Map) (texteTolerant(x['libelle']), entierTolerant(x['valeur'])),
    ];
  }

  static Future<List<StatTva>> tva(BuildContext context, DateTime maintenant) async =>
      await StatTvaDonnees.charger(context, DateTime(maintenant.year, maintenant.month, 1), maintenant, TypeVente.tout) ?? const [];
}

// ---------------------------------------------------------------------------------------------------------------
// Écran
// ---------------------------------------------------------------------------------------------------------------

/// Signal « tout recharger » (⟳ de l'en-tête).
class ActualisationTableauBord extends ValueNotifier<int> {
  ActualisationTableauBord() : super(0);
  void lancer() => value++;
}

class AccueilTableauPrestige extends StatefulWidget {
  final DateTime Function() maintenant;
  const AccueilTableauPrestige({super.key, this.maintenant = DateTime.now});

  @override
  State<AccueilTableauPrestige> createState() => _AccueilTableauPrestigeState();
}

class _AccueilTableauPrestigeState extends State<AccueilTableauPrestige> {
  final _actualisation = ActualisationTableauBord();

  @override
  void initState() {
    super.initState();
    CartesTableauBordPrefs.charger();
  }

  @override
  void dispose() {
    _actualisation.dispose();
    super.dispose();
  }

  Future<void> _personnaliser() async {
    var l = [...CartesTableauBordPrefs.cartes.value];
    final ok = await ouvrirFeuilleFiltres(
      context,
      titre: 'Cartes du tableau de bord',
      libelleEffacer: 'Tout afficher',
      libelleAppliquer: 'Enregistrer',
      effacer: () => l = CartesTableauBordPrefs.defaut,
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Cochez les cartes à afficher ; les flèches changent leur ordre.', style: TextStyle(color: Charte.gris, fontSize: 13)),
        for (var i = 0; i < l.length; i++)
          Row(key: Key('carte_choix_${l[i].carte.name}'), children: [
            Expanded(
              child: CheckboxListTile(
                key: Key('carte_visible_${l[i].carte.name}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: l[i].visible,
                title: Text(l[i].carte.titre),
                onChanged: (v) => setState(() => l[i] = (carte: l[i].carte, visible: v ?? true)),
              ),
            ),
            IconButton(
              key: Key('carte_monter_${l[i].carte.name}'),
              tooltip: 'Monter',
              onPressed: i == 0 ? null : () => setState(() => l.insert(i - 1, l.removeAt(i))),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              key: Key('carte_descendre_${l[i].carte.name}'),
              tooltip: 'Descendre',
              onPressed: i == l.length - 1 ? null : () => setState(() => l.insert(i + 1, l.removeAt(i))),
              icon: const Icon(Icons.arrow_downward),
            ),
          ]),
      ]),
    );
    if (ok) await CartesTableauBordPrefs.enregistrer(l);
  }

  Widget _carte(CarteTableauBord c) => switch (c) {
        CarteTableauBord.chiffres => _CarteChiffres(maintenant: widget.maintenant, actualisation: _actualisation),
        CarteTableauBord.evolution => _CarteEvolution(maintenant: widget.maintenant, actualisation: _actualisation),
        CarteTableauBord.frequentation => _CarteFrequentation(maintenant: widget.maintenant, actualisation: _actualisation),
        CarteTableauBord.valorisation => _CarteValorisation(maintenant: widget.maintenant, actualisation: _actualisation),
        CarteTableauBord.encaissements => _CarteEncaissements(maintenant: widget.maintenant, actualisation: _actualisation),
        CarteTableauBord.top => _CarteTop(maintenant: widget.maintenant, actualisation: _actualisation),
        CarteTableauBord.tva => _CarteTva(maintenant: widget.maintenant, actualisation: _actualisation),
      };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return ValueListenableBuilder<List<ChoixCarte>>(
      valueListenable: CartesTableauBordPrefs.cartes,
      builder: (context, choix, _) {
        final visibles = [for (final x in choix) if (x.visible) x.carte];
        final entete = EnTeteNavy(
          titre: auth.officine?.nomComplet ?? 'Prestige Pharmacien',
          sousTitre: '${auth.user?.fullName ?? 'Utilisateur'} · ${dateLisible(widget.maintenant())}',
          retour: false,
          actions: [
            IconButton(
              key: const Key('tableau_bord_actualiser'),
              tooltip: 'Actualiser',
              onPressed: _actualisation.lancer,
              icon: const Icon(Icons.refresh, color: Charte.blanc),
            ),
            const BoutonReglages(),
            const BoutonDeconnexion(),
          ],
          enfants: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              PastilleServeur(apres: _actualisation.lancer),
              PastilleEntete('Tous les menus',
                  icone: Icons.apps,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TousLesMenusScreen()))),
              PastilleEntete('Cartes', icone: Icons.tune, onTap: _personnaliser),
            ]),
          ],
        );
        // Liste construite à la demande : une carte ne charge ses données qu'à son arrivée à l'écran.
        return RefreshIndicator(
          onRefresh: () async => _actualisation.lancer(),
          child: ListView.builder(
            key: const Key('defilement_tableau_bord'),
            padding: EdgeInsets.zero,
            itemCount: 1 + visibles.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return entete;
              if (i == visibles.length + 1) {
                return visibles.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: EtatVide(titre: 'Aucune carte affichée', texte: 'Touchez « Cartes » pour en afficher.', icone: Icons.tune),
                      )
                    : const SizedBox(height: 16);
              }
              final c = visibles[i - 1];
              // Gardée en vie hors de l'écran : une carte chargée ne relit rien quand elle revient à l'écran (seul
              // ⟳ recharge) — relevé par test/performance/retours_3_11_0_test.dart (17 lectures au lieu de 7).
              return _GardeEnVie(
                key: Key('carte_tableau_bord_${c.name}'),
                child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _carte(c)),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Cartes
// ---------------------------------------------------------------------------------------------------------------

/// Garde une carte (et ses données) en vie quand elle sort de l'écran.
class _GardeEnVie extends StatefulWidget {
  final Widget child;
  const _GardeEnVie({super.key, required this.child});

  @override
  State<_GardeEnVie> createState() => _GardeEnVieState();
}

class _GardeEnVieState extends State<_GardeEnVie> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Chargement d'une carte : à l'affichage, puis à chaque ⟳ ; états (chargement, erreur, indisponible).
mixin ChargementCarte<W extends StatefulWidget, T> on State<W> {
  T? donnees;
  Object? erreur;
  bool enCours = false;
  int _gen = 0;

  ActualisationTableauBord get actualisation;
  Future<T> lire(BuildContext context);

  @override
  void initState() {
    super.initState();
    actualisation.addListener(recharger);
    WidgetsBinding.instance.addPostFrameCallback((_) => recharger());
  }

  @override
  void dispose() {
    actualisation.removeListener(recharger);
    super.dispose();
  }

  Future<void> recharger() async {
    if (!mounted) return;
    final g = ++_gen;
    setState(() {
      enCours = true;
      erreur = null;
    });
    try {
      final d = await lire(context);
      if (!mounted || g != _gen) return;
      setState(() {
        donnees = d;
        enCours = false;
      });
    } catch (e) {
      if (!mounted || g != _gen) return;
      setState(() {
        erreur = e;
        enCours = false;
      });
    }
  }

  /// Corps commun : chargement, indisponible, erreur, sinon [contenu].
  Widget corps(Widget Function(T d) contenu) {
    if (enCours && donnees == null) return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator());
    final e = erreur;
    if (e != null) {
      if (routeAbsente(e)) {
        return const Text('Indisponible sur ce serveur (mise à jour de Prestige nécessaire).',
            key: Key('carte_indisponible'), style: TextStyle(color: Charte.gris, fontSize: 13.5));
      }
      final d = DiagnosticErreur.de(e);
      return Row(children: [
        Expanded(child: Text('${d.titre} : ${d.message}', style: const TextStyle(color: Charte.rougeTexte, fontSize: 13.5))),
        TextButton(onPressed: recharger, child: const Text('Réessayer')),
      ]);
    }
    final d = donnees;
    if (d == null) return const SizedBox.shrink();
    return contenu(d);
  }
}

/// Cadre d'une carte : titre, icône, contenu.
class _Cadre extends StatelessWidget {
  final CarteTableauBord carte;
  final Widget child;
  final Widget? action;
  const _Cadre({required this.carte, required this.child, this.action});

  @override
  Widget build(BuildContext context) => CarteSection(titre: carte.titre, icone: carte.icone, enfants: [
        if (action != null) action!,
        child,
      ]);
}

class _CarteChiffres extends StatefulWidget {
  final DateTime Function() maintenant;
  final ActualisationTableauBord actualisation;
  const _CarteChiffres({required this.maintenant, required this.actualisation});

  @override
  State<_CarteChiffres> createState() => _CarteChiffresState();
}

class _CarteChiffresState extends State<_CarteChiffres> with ChargementCarte<_CarteChiffres, ChiffresTableauBord> {
  @override
  ActualisationTableauBord get actualisation => widget.actualisation;

  @override
  Future<ChiffresTableauBord> lire(BuildContext context) => ApiTableauBord.chiffres(context, widget.maintenant());

  @override
  Widget build(BuildContext context) => _Cadre(
        carte: CarteTableauBord.chiffres,
        child: corps((c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              GrilleKpi([
                ChiffreCle(
                    libelle: 'CA net', valeur: formaterMontant(c.ca), id: 'tb_ca', enAvant: true, detail: '${grouperMilliers(c.clients)} client${c.clients > 1 ? 's' : ''}'),
                ChiffreCle(libelle: 'Marge', valeur: formaterMontant(c.marge), id: 'tb_marge', detail: c.tauxMarge == null ? null : 'taux ${pourcentTexte(c.tauxMarge)}'),
                ChiffreCle(libelle: 'Panier moyen', valeur: formaterMontant(c.panier), id: 'tb_panier'),
                ChiffreCle(libelle: 'Achats du jour', valeur: formaterMontant(c.achats), id: 'tb_achats', detail: '${grouperMilliers(c.bons)} BL'),
              ]),
              if (c.evolutionVeille != null) ...[const SizedBox(height: 6), Variation(c.evolutionVeille, suffixe: 'CA vs la veille')],
            ])),
      );
}

class _CarteEvolution extends StatefulWidget {
  final DateTime Function() maintenant;
  final ActualisationTableauBord actualisation;
  const _CarteEvolution({required this.maintenant, required this.actualisation});

  @override
  State<_CarteEvolution> createState() => _CarteEvolutionState();
}

class _CarteEvolutionState extends State<_CarteEvolution> with ChargementCarte<_CarteEvolution, List<(DateTime, DateTime, double, double)>> {
  @override
  ActualisationTableauBord get actualisation => widget.actualisation;

  @override
  Future<List<(DateTime, DateTime, double, double)>> lire(BuildContext context) => ApiTableauBord.evolution(context, widget.maintenant());

  @override
  Widget build(BuildContext context) {
    String j(DateTime d) => d.day.toString().padLeft(2, '0');
    return _Cadre(
      carte: CarteTableauBord.evolution,
      child: corps((t) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (t.length >= 2) ...[
              CadreGraphique(
                hauteur: 200,
                child: GraphiqueCourbes(
                  libelle: 'Chiffre d\'affaires du mois par tranche de 5 jours',
                  jours: [for (final x in t) x.$1],
                  series: [(const SerieGraphique('Ventes', Charte.navy), [for (final x in t) x.$3])],
                ),
              ),
              const SizedBox(height: 6),
            ],
            for (final x in t) LigneDetail(x.$1 == x.$2 ? 'Le ${j(x.$1)}' : 'Du ${j(x.$1)} au ${j(x.$2)}', formaterMontant(x.$3)),
          ])),
    );
  }
}

class _CarteFrequentation extends StatefulWidget {
  final DateTime Function() maintenant;
  final ActualisationTableauBord actualisation;
  const _CarteFrequentation({required this.maintenant, required this.actualisation});

  @override
  State<_CarteFrequentation> createState() => _CarteFrequentationState();
}

class _CarteFrequentationState extends State<_CarteFrequentation>
    with ChargementCarte<_CarteFrequentation, ({List<int> ventes, List<int>? reference, String libelle, bool semaine})> {
  late DateTime _jour = Periode.jour(widget.maintenant());

  @override
  ActualisationTableauBord get actualisation => widget.actualisation;

  @override
  Future<({List<int> ventes, List<int>? reference, String libelle, bool semaine})> lire(BuildContext context) =>
      ApiTableauBord.frequentation(context, _jour);

  void _choisir(DateTime j) {
    setState(() => _jour = j);
    recharger();
  }

  @override
  Widget build(BuildContext context) {
    final aujourdhui = Periode.jour(widget.maintenant());
    final hier = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - 1);
    final choix = _jour == aujourdhui ? 0 : (_jour == hier ? 1 : 2);
    String date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return _Cadre(
      carte: CarteTableauBord.frequentation,
      action: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PucesChoix<int>(
          choix: const [(0, 'Aujourd\'hui'), (1, 'Hier'), (2, 'Personnaliser')],
          valeur: choix,
          cle: (i, _) => Key('frequentation_${['aujourdhui', 'hier', 'personnaliser'][i]}'),
          onChanged: (i) async {
            if (i == 0) return _choisir(aujourdhui);
            if (i == 1) return _choisir(hier);
            final d = await choisirJour(context, _jour, aide: 'Jour de la fréquentation', maintenant: widget.maintenant);
            if (d != null && mounted) _choisir(d);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(date(_jour), key: const Key('frequentation_jour'), style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
      child: corps((f) {
        final heures = [for (var h = 0; h < f.ventes.length; h++) if (f.ventes[h] > 0 || (f.reference != null && h < f.reference!.length && f.reference![h] > 0)) h];
        if (heures.isEmpty) return const Text('Aucune vente sur ce jour.', style: TextStyle(color: Charte.gris));
        final total = f.ventes.fold<int>(0, (s, v) => s + v);
        final pointe = heures.reduce((a, b) => f.ventes[a] >= f.ventes[b] ? a : b);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              '${grouperMilliers(total)} vente${total > 1 ? 's' : ''} · pointe à ${pointe.toString().padLeft(2, '0')} h'
              '${f.semaine ? ' · ${f.libelle}' : ''}',
              key: const Key('frequentation_resume'),
              style: const TextStyle(color: Charte.encre, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          BarresHorizontales(
            largeurLibelle: 64,
            enAvant: heures.indexOf(pointe),
            barres: [
              for (final h in heures)
                ('${h.toString().padLeft(2, '0')} h', f.ventes[h].toDouble(),
                    '${grouperMilliers(f.ventes[h])}${f.reference != null && h < f.reference!.length ? ' (${grouperMilliers(f.reference![h])})' : ''}'),
            ],
          ),
          if (f.reference != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Entre parenthèses : ${f.semaine ? 'semaine précédente' : 'la veille'}.', style: const TextStyle(color: Charte.gris, fontSize: 12.5)),
            ),
        ]);
      }),
    );
  }
}

class _CarteValorisation extends StatefulWidget {
  final DateTime Function() maintenant;
  final ActualisationTableauBord actualisation;
  const _CarteValorisation({required this.maintenant, required this.actualisation});

  @override
  State<_CarteValorisation> createState() => _CarteValorisationState();
}

class _CarteValorisationState extends State<_CarteValorisation> with ChargementCarte<_CarteValorisation, Valorisation> {
  @override
  ActualisationTableauBord get actualisation => widget.actualisation;

  @override
  Future<Valorisation> lire(BuildContext context) => ApiTableauBord.valorisation(context, widget.maintenant());

  @override
  Widget build(BuildContext context) => _Cadre(
        carte: CarteTableauBord.valorisation,
        child: corps((v) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              LigneDetail('Valeur d\'achat', formaterMontant(v.total.achat), gras: true),
              LigneDetail('Valeur de vente', formaterMontant(v.total.vente)),
              LigneDetail('Rayon (achat)', formaterMontant(v.rayon.achat)),
              LigneDetail('Réserve (achat)', formaterMontant(v.reserve.achat)),
            ])),
      );
}

class _CarteEncaissements extends StatefulWidget {
  final DateTime Function() maintenant;
  final ActualisationTableauBord actualisation;
  const _CarteEncaissements({required this.maintenant, required this.actualisation});

  @override
  State<_CarteEncaissements> createState() => _CarteEncaissementsState();
}

class _CarteEncaissementsState extends State<_CarteEncaissements> with ChargementCarte<_CarteEncaissements, List<(String, int)>> {
  @override
  ActualisationTableauBord get actualisation => widget.actualisation;

  @override
  Future<List<(String, int)>> lire(BuildContext context) => ApiTableauBord.encaissements(context, widget.maintenant());

  @override
  Widget build(BuildContext context) => _Cadre(
        carte: CarteTableauBord.encaissements,
        child: corps((l) => l.isEmpty
            ? const Text('Aucun encaissement aujourd\'hui.', style: TextStyle(color: Charte.gris))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (libelle, montant) in l) LigneDetail(libelle, formaterMontant(montant)),
                const Divider(height: 12),
                LigneDetail('Total', formaterMontant(l.fold<int>(0, (s, x) => s + x.$2)), gras: true),
              ])),
      );
}

class _CarteTop extends StatefulWidget {
  final DateTime Function() maintenant;
  final ActualisationTableauBord actualisation;
  const _CarteTop({required this.maintenant, required this.actualisation});

  @override
  State<_CarteTop> createState() => _CarteTopState();
}

class _CarteTopState extends State<_CarteTop> with ChargementCarte<_CarteTop, List<(String, int)>> {
  bool _famille = false;

  @override
  ActualisationTableauBord get actualisation => widget.actualisation;

  @override
  Future<List<(String, int)>> lire(BuildContext context) => ApiTableauBord.top(context, widget.maintenant(), famille: _famille);

  @override
  Widget build(BuildContext context) => _Cadre(
        carte: CarteTableauBord.top,
        action: PucesChoix<bool>(
          choix: const [(false, 'Emplacements'), (true, 'Familles')],
          valeur: _famille,
          cle: (f, _) => Key(f ? 'top_familles' : 'top_emplacements'),
          onChanged: (f) {
            setState(() => _famille = f);
            recharger();
          },
        ),
        child: corps((l) => l.isEmpty
            ? const Text('Aucune vente ce mois-ci.', style: TextStyle(color: Charte.gris))
            : BarresHorizontales(
                largeurLibelle: 110,
                barres: [for (var i = 0; i < l.length; i++) ('${i + 1}. ${l[i].$1}', l[i].$2.toDouble(), formaterMontant(l[i].$2))],
              )),
      );
}

class _CarteTva extends StatefulWidget {
  final DateTime Function() maintenant;
  final ActualisationTableauBord actualisation;
  const _CarteTva({required this.maintenant, required this.actualisation});

  @override
  State<_CarteTva> createState() => _CarteTvaState();
}

class _CarteTvaState extends State<_CarteTva> with ChargementCarte<_CarteTva, List<StatTva>> {
  @override
  ActualisationTableauBord get actualisation => widget.actualisation;

  @override
  Future<List<StatTva>> lire(BuildContext context) => ApiTableauBord.tva(context, widget.maintenant());

  @override
  Widget build(BuildContext context) => _Cadre(
        carte: CarteTableauBord.tva,
        child: corps((l) {
          if (l.isEmpty) return const Text('Aucune vente ce mois-ci.', style: TextStyle(color: Charte.gris));
          final total = StatTvaDonnees.totalTtc(l);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final t in l)
              LigneDetail('TVA ${t.taux} % (${pourcentTexte(total == 0 ? 0 : t.totalTtc * 100 / total)})', formaterMontant(t.totalTtc)),
            const Divider(height: 12),
            LigneDetail('Total TTC', formaterMontant(total), gras: true),
          ]);
        }),
      );
}
