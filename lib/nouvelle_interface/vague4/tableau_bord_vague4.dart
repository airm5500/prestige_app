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

bool memeJour(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Plage d'heures affichée par la fréquentation (3.11.1).
enum PlageHoraire {
  ouverture('Heures d\'ouverture'),
  septVingtDeux('De 7 h à 22 h'),
  journee('Toute la journée');

  final String libelle;
  const PlageHoraire(this.libelle);
}

/// Une tranche horaire : [debut] inclus, [fin] exclue ; ventes et CA de la tranche, ventes du jour de comparaison.
class TrancheHoraire {
  final int debut;
  final int fin;
  final int ventes;
  final int ca;
  final int? ventesReference;

  /// Part de la tranche dans le CA de la journée (en %), null si la journée n'a pas de CA.
  final double? partCa;
  const TrancheHoraire(this.debut, this.fin, this.ventes, this.ca, this.ventesReference, this.partCa);

  /// Écart du nombre de ventes avec le jour de comparaison (null : pas de comparaison).
  int? get ecart => ventesReference == null ? null : ventes - ventesReference!;

  String get libelle {
    String h(int x) => x.toString().padLeft(2, '0');
    return fin - debut == 1 ? '${h(debut)} h' : '${h(debut)}-${h(fin)} h';
  }
}

/// Fréquentation d'une journée (ou d'une semaine, en repli) : 24 cases par heure.
class FrequentationJour {
  final List<int> ventes;
  final List<int> ca;
  final List<int>? reference;
  final String libelle;
  final bool semaine;
  const FrequentationJour({required this.ventes, this.ca = const [], this.reference, required this.libelle, required this.semaine});

  static int _de(List<int>? l, int h) => l == null || h >= l.length ? 0 : l[h];

  int get totalVentes => ventes.fold(0, (s, v) => s + v);
  int get totalCa => ca.fold(0, (s, v) => s + v);

  /// Heures [début, fin[ de la plage : « heures d'ouverture » = de la première à la dernière heure avec une vente,
  /// ce jour ou le jour de comparaison ; null si aucune vente.
  (int, int)? bornes(PlageHoraire p) => switch (p) {
        PlageHoraire.septVingtDeux => (7, 22),
        PlageHoraire.journee => (0, 24),
        PlageHoraire.ouverture => () {
            final h = [for (var i = 0; i < 24; i++) if (_de(ventes, i) > 0 || _de(reference, i) > 0) i];
            return h.isEmpty ? null : (h.first, h.last + 1);
          }(),
      };

  /// Tranches de [largeur] heures (1 ou 2) sur la plage choisie ; la dernière est coupée à la fin de la plage.
  List<TrancheHoraire> tranches({int largeur = 1, PlageHoraire plage = PlageHoraire.ouverture}) {
    final b = bornes(plage);
    if (b == null) return const [];
    final total = totalCa;
    final l = <TrancheHoraire>[];
    for (var d = b.$1; d < b.$2; d += largeur) {
      final f = d + largeur > b.$2 ? b.$2 : d + largeur;
      var v = 0, c = 0, r = 0;
      for (var h = d; h < f; h++) {
        v += _de(ventes, h);
        c += _de(ca, h);
        r += _de(reference, h);
      }
      l.add(TrancheHoraire(d, f, v, c, reference == null ? null : r, total <= 0 ? null : c * 100 / total));
    }
    return l;
  }
}

/// Choix d'affichage de la fréquentation (largeur des tranches et plage d'heures), mémorisé sur l'appareil.
class AffichageFrequentationPrefs {
  AffichageFrequentationPrefs._();
  static const cle = 'tableau_bord_frequentation_v1';

  /// « 2:septVingtDeux » → (2, PlageHoraire.septVingtDeux) ; valeur inconnue → (1 h, heures d'ouverture).
  static (int, PlageHoraire) lire(String? texte) {
    final p = (texte ?? '').split(':');
    final largeur = p.first == '2' ? 2 : 1;
    final plage = p.length > 1 ? (PlageHoraire.values.asNameMap()[p[1]] ?? PlageHoraire.ouverture) : PlageHoraire.ouverture;
    return (largeur, plage);
  }

  static String ecrire(int largeur, PlageHoraire plage) => '$largeur:${plage.name}';

  static Future<(int, PlageHoraire)> charger() async {
    try {
      return lire((await SharedPreferences.getInstance()).getString(cle));
    } catch (_) {
      return lire(null);
    }
  }

  static Future<void> enregistrer(int largeur, PlageHoraire plage) async {
    try {
      await (await SharedPreferences.getInstance()).setString(cle, ecrire(largeur, plage));
    } catch (_) {}
  }
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

  /// Chiffres d'un jour ([jourChoisi], aujourd'hui par défaut ; 3.11.1 : Aujourd'hui / Hier / Personnaliser). Le
  /// serveur donne aussi l'évolution par rapport à la veille de ce jour : aucune requête de plus.
  static Future<ChiffresTableauBord> chiffres(BuildContext context, DateTime maintenant, {DateTime? jour}) async {
    final jourChoisi = jour ?? maintenant;
    try {
      final j = await ApiVague2.get(context, routeTuiles, {'date': ApiTableauBord.jour(jourChoisi)}, 'les chiffres du jour');
      final a = j['achats'] is Map ? Map<String, dynamic>.from(j['achats'] as Map) : const <String, dynamic>{};
      return ChiffresTableauBord(entierTolerant(j['ca']), entierTolerant(j['clients']), decimalOuNull(j['evolutionVeille']), entierTolerant(j['marge']),
          decimalOuNull(j['tauxMarge']), entierTolerant(j['panier']), entierTolerant(a['ttc']), entierTolerant(a['bl']));
    } catch (e) {
      // Serveur sans /tableau-bord (branche dev) : la route du tableau de bord web historique, qui ne connaît
      // qu'aujourd'hui. Pour un autre jour (3.11.1 : Hier / Personnaliser), le 404 est gardé : la carte dit
      // « Indisponible sur ce serveur ».
      if (!routeAbsente(e) || !memeJour(jourChoisi, maintenant)) rethrow;
    }
    if (!context.mounted) throw const ApiLoadException('Écran fermé.', nature: NatureErreur.refus);
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

  /// Fréquentation d'une journée : ventes et CA par heure (24) et ceux du jour de comparaison (la veille) — dans la
  /// MÊME réponse (aucune requête de plus pour la veille) ; [FrequentationJour.semaine] : repli sur la route du tableau
  /// de bord (semaine du lundi au jour choisi).
  static Future<FrequentationJour> frequentation(BuildContext context, DateTime jourChoisi) async {
    List<int> heures(Object? v) => v is List ? [for (final x in v) entierTolerant(x)] : const [];
    try {
      final j = await ApiVague2.get(context, routeFrequentationPilotage,
          {'axe': 'PERSO', 'dtStart': jour(jourChoisi), 'dtEnd': jour(jourChoisi)}, 'la fréquentation');
      final c = j['courante'] is Map ? Map<String, dynamic>.from(j['courante'] as Map) : const <String, dynamic>{};
      final r = j['reference'] is Map ? Map<String, dynamic>.from(j['reference'] as Map) : null;
      return FrequentationJour(
          ventes: heures(c['ventesH']), ca: heures(c['caH']), reference: r == null ? null : heures(r['ventesH']), libelle: 'comparé à la veille', semaine: false);
    } catch (e) {
      final repli = routeAbsente(e) || (e is ApiLoadException && e.nature == NatureErreur.droit);
      if (!repli) rethrow;
    }
    if (!context.mounted) throw const ApiLoadException('Écran fermé.', nature: NatureErreur.refus);
    final j = await ApiVague2.get(context, routeFrequentation, {'date': jour(jourChoisi)}, 'la fréquentation');
    final s = j['semaine'] is Map ? Map<String, dynamic>.from(j['semaine'] as Map) : const <String, dynamic>{};
    final p = j['precedente'] is Map ? Map<String, dynamic>.from(j['precedente'] as Map) : null;
    return FrequentationJour(
        ventes: heures(s['ventesH']), ca: heures(s['caH']), reference: p == null ? null : heures(p['ventesH']), libelle: 'semaine du lundi au jour choisi', semaine: true);
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

/// Aujourd'hui / Hier / Personnaliser (une date) et le jour choisi, sous les puces (fréquentation et chiffres).
class _ChoixJour extends StatelessWidget {
  /// Préfixe des clés : « <prefixe>_aujourdhui », « <prefixe>_hier », « <prefixe>_personnaliser », « <prefixe>_jour ».
  final String prefixe;
  final DateTime jour;
  final DateTime Function() maintenant;
  final String aide;
  final ValueChanged<DateTime> onChanged;
  const _ChoixJour({required this.prefixe, required this.jour, required this.maintenant, required this.aide, required this.onChanged});

  static String date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final aujourdhui = Periode.jour(maintenant());
    final hier = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - 1);
    final choix = jour == aujourdhui ? 0 : (jour == hier ? 1 : 2);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PucesChoix<int>(
        choix: const [(0, 'Aujourd\'hui'), (1, 'Hier'), (2, 'Personnaliser')],
        valeur: choix,
        cle: (i, _) => Key('${prefixe}_${['aujourdhui', 'hier', 'personnaliser'][i]}'),
        onChanged: (i) async {
          if (i == 0) return onChanged(aujourdhui);
          if (i == 1) return onChanged(hier);
          final d = await choisirJour(context, jour, aide: aide, maintenant: maintenant);
          if (d != null) onChanged(d);
        },
      ),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(date(jour), key: Key('${prefixe}_jour'), style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

class _CarteChiffres extends StatefulWidget {
  final DateTime Function() maintenant;
  final ActualisationTableauBord actualisation;
  const _CarteChiffres({required this.maintenant, required this.actualisation});

  @override
  State<_CarteChiffres> createState() => _CarteChiffresState();
}

class _CarteChiffresState extends State<_CarteChiffres> with ChargementCarte<_CarteChiffres, ChiffresTableauBord> {
  /// 3.11.1 : jour choisi (Aujourd'hui / Hier / Personnaliser), comme la fréquentation.
  late DateTime _jour = Periode.jour(widget.maintenant());

  @override
  ActualisationTableauBord get actualisation => widget.actualisation;

  @override
  Future<ChiffresTableauBord> lire(BuildContext context) => ApiTableauBord.chiffres(context, widget.maintenant(), jour: _jour);

  void _choisir(DateTime j) {
    if (!mounted) return;
    setState(() {
      _jour = j;
      donnees = null; // les chiffres d'un autre jour ne restent pas affichés pendant le chargement
    });
    recharger();
  }

  @override
  Widget build(BuildContext context) {
    final duJour = memeJour(_jour, widget.maintenant());
    return _Cadre(
      carte: CarteTableauBord.chiffres,
      action: _ChoixJour(prefixe: 'chiffres', jour: _jour, maintenant: widget.maintenant, aide: 'Jour des chiffres', onChanged: _choisir),
      child: corps((c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GrilleKpi([
              ChiffreCle(
                  libelle: 'CA net', valeur: formaterMontant(c.ca), id: 'tb_ca', enAvant: true, detail: '${grouperMilliers(c.clients)} client${c.clients > 1 ? 's' : ''}'),
              ChiffreCle(libelle: 'Marge', valeur: formaterMontant(c.marge), id: 'tb_marge', detail: c.tauxMarge == null ? null : 'taux ${pourcentTexte(c.tauxMarge)}'),
              ChiffreCle(libelle: 'Panier moyen', valeur: formaterMontant(c.panier), id: 'tb_panier'),
              ChiffreCle(libelle: duJour ? 'Achats du jour' : 'Achats', valeur: formaterMontant(c.achats), id: 'tb_achats', detail: '${grouperMilliers(c.bons)} BL'),
            ]),
            if (c.evolutionVeille != null) ...[const SizedBox(height: 6), Variation(c.evolutionVeille, key: const Key('tb_evolution_veille'), suffixe: 'CA vs la veille')],
          ])),
    );
  }
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

class _CarteFrequentationState extends State<_CarteFrequentation> with ChargementCarte<_CarteFrequentation, FrequentationJour> {
  late DateTime _jour = Periode.jour(widget.maintenant());

  /// 3.11.1 : largeur des tranches (1 h ou 2 h) et plage d'heures ; changer l'un ou l'autre ne relit rien.
  var _largeur = 1;
  var _plage = PlageHoraire.ouverture;

  @override
  void initState() {
    super.initState();
    AffichageFrequentationPrefs.charger().then((c) {
      if (mounted) {
        setState(() {
          _largeur = c.$1;
          _plage = c.$2;
        });
      }
    });
  }

  @override
  ActualisationTableauBord get actualisation => widget.actualisation;

  @override
  Future<FrequentationJour> lire(BuildContext context) => ApiTableauBord.frequentation(context, _jour);

  void _choisir(DateTime j) {
    if (!mounted) return;
    setState(() => _jour = j);
    recharger();
  }

  void _afficher(int largeur, PlageHoraire plage) {
    setState(() {
      _largeur = largeur;
      _plage = plage;
    });
    AffichageFrequentationPrefs.enregistrer(largeur, plage);
  }

  Widget _reglages() => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          PucesChoix<int>(
            choix: const [(1, 'Par heure'), (2, 'Par 2 h')],
            valeur: _largeur,
            cle: (l, _) => Key('frequentation_largeur_$l'),
            onChanged: (l) => _afficher(l, _plage),
          ),
          PopupMenuButton<PlageHoraire>(
            key: const Key('frequentation_plage'),
            tooltip: 'Plage d\'heures',
            initialValue: _plage,
            onSelected: (p) => _afficher(_largeur, p),
            itemBuilder: (_) => [
              for (final p in PlageHoraire.values)
                PopupMenuItem(
                  key: Key('frequentation_plage_${p.name}'),
                  value: p,
                  child: Text(p.libelle, style: const TextStyle(color: Charte.encre, fontWeight: FontWeight.w600)),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.schedule, size: 18, color: Charte.navy),
                const SizedBox(width: 4),
                Flexible(child: Text(_plage.libelle, style: const TextStyle(color: Charte.navy, fontSize: 13.5, fontWeight: FontWeight.w700))),
                const Icon(Icons.arrow_drop_down, color: Charte.navy),
              ]),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => _Cadre(
        carte: CarteTableauBord.frequentation,
        action: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _ChoixJour(prefixe: 'frequentation', jour: _jour, maintenant: widget.maintenant, aide: 'Jour de la fréquentation', onChanged: _choisir),
          _reglages(),
        ]),
        child: corps((f) {
          final t = f.tranches(largeur: _largeur, plage: _plage);
          if (f.totalVentes == 0 && (f.reference ?? const []).every((v) => v == 0)) {
            return const Text('Aucune vente sur ce jour.', style: TextStyle(color: Charte.gris));
          }
          if (t.isEmpty) return const Text('Aucune vente sur cette plage.', style: TextStyle(color: Charte.gris));
          final pointe = t.indexed.reduce((a, b) => a.$2.ventes >= b.$2.ventes ? a : b);
          final max = t.fold<int>(0, (m, x) => x.ventes > m ? x.ventes : m);
          final reference = f.semaine ? 'la semaine précédente' : 'la veille';
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
                '${grouperMilliers(f.totalVentes)} vente${f.totalVentes > 1 ? 's' : ''} · pointe ${pointe.$2.libelle}'
                '${f.semaine ? ' · ${f.libelle}' : ''}',
                key: const Key('frequentation_resume'),
                style: const TextStyle(color: Charte.encre, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final (i, x) in t.indexed)
              LigneHoraire(key: Key('frequentation_tranche_${x.debut}'), tranche: x, max: max, pointe: i == pointe.$1, largeurLibelle: _largeur == 1 ? 46 : 70,
                  reference: reference),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  f.reference == null
                      ? 'Pourcentage : part de la tranche dans le chiffre d\'affaires.'
                      : 'Pourcentage : part de la tranche dans le chiffre d\'affaires. Entre parenthèses : écart du nombre de ventes avec $reference.',
                  style: const TextStyle(color: Charte.gris, fontSize: 12.5)),
            ),
          ]);
        }),
      );
}

/// Une tranche de la fréquentation (3.11.1) : heure, barre et nombre de ventes ; dessous, la part du CA de la
/// journée et, entre parenthèses, l'écart avec le jour de comparaison — signe, flèche ET couleur (vert : hausse,
/// rouge : baisse, gris : égal), jamais la couleur seule.
class LigneHoraire extends StatelessWidget {
  final TrancheHoraire tranche;
  final int max;
  final bool pointe;
  final double largeurLibelle;
  final String reference;
  const LigneHoraire({super.key, required this.tranche, required this.max, this.pointe = false, this.largeurLibelle = 46, this.reference = 'la veille'});

  @override
  Widget build(BuildContext context) {
    final x = tranche, e = x.ecart;
    final f = max <= 0 ? 0.0 : (x.ventes / max).clamp(0.0, 1.0);
    final poids = pointe ? FontWeight.w800 : FontWeight.w600;
    final (icone, couleur, mot) = e == null
        ? (null, Charte.gris, '')
        : e > 0
            ? (Icons.arrow_upward, Charte.vertTexte, 'hausse')
            : e < 0
                ? (Icons.arrow_downward, Charte.rougeTexte, 'baisse')
                : (Icons.drag_handle, Charte.grisTexte, 'égal');
    final ecart = e == null ? null : (e > 0 ? '+${grouperMilliers(e)}' : (e < 0 ? '−${grouperMilliers(-e)}' : '0'));
    final part = x.partCa == null ? null : '${pourcentTexte(x.partCa)} du CA';
    return Semantics(
      label: '${x.libelle} : ${grouperMilliers(x.ventes)} vente${x.ventes > 1 ? 's' : ''}'
          '${part == null ? '' : ', $part'}${e == null ? '' : ', $mot de $ecart par rapport à $reference'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: largeurLibelle,
            child: Text(x.libelle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Charte.encre, fontWeight: poids)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Container(
                    height: 14,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: Charte.grisClair, borderRadius: BorderRadius.circular(4)),
                    child: FractionallySizedBox(
                      widthFactor: f,
                      child: Container(decoration: BoxDecoration(color: pointe ? Charte.ambre : Charte.navy2, borderRadius: BorderRadius.circular(4))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 28),
                  child: Text(grouperMilliers(x.ventes),
                      key: Key('frequentation_ventes_${x.debut}'), textAlign: TextAlign.right, style: TextStyle(fontSize: 13.5, color: Charte.encre, fontWeight: poids)),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  if (part != null) Text(part, key: Key('frequentation_part_${x.debut}'), style: const TextStyle(color: Charte.grisTexte, fontSize: 12.5)),
                  if (e != null)
                    Row(key: Key('frequentation_ecart_${x.debut}'), mainAxisSize: MainAxisSize.min, children: [
                      Text('(', style: TextStyle(color: couleur, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      Icon(icone, size: 13, color: couleur),
                      Text('$ecart)', style: TextStyle(color: couleur, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ]),
                ]),
              ),
            ]),
          ),
        ]),
      ),
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
