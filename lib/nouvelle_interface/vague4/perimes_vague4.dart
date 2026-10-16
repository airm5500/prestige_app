// lib/nouvelle_interface/vague4/perimes_vague4.dart
// 3.11.0 (demande du pharmacien, « cloche » : avoirs, périmés à venir 6 mois, saisie en périmés) :
//  - [AlerteSaisiesPerimes] : alerte « Saisies en périmés » du bloc « À surveiller » (accueil A et onglet
//    « Surveiller et alertes » de la Balance) : nombre de produits saisis en périmés ces 30 derniers jours, compté À LA
//    DEMANDE seulement (son bouton ⟳ : une lecture, une ligne demandée), comme les autres alertes de l'accueil ;
//    touchée, elle ouvre la liste ;
//  - [SaisiesPerimesScreen] : la liste (GET /fichearticle/saisieperimes, période commune, recherche, pages de 50).
// Les avoirs et les périmés à venir (6 mois par défaut) viennent de l'appel unique des alertes du tableau de bord.
import 'package:flutter/material.dart';

import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/periode.dart';
import '../vague2/donnees_vague2.dart' show grouperMilliers;
import 'donnees_vague4.dart';

/// Dernier comptage des saisies en périmés (gardé pendant toute la session de l'application).
class ComptageSaisiesPerimes {
  ComptageSaisiesPerimes._();
  static final etat = ValueNotifier<({int? nombre, DateTime? le, bool enCours, String? echec})>((nombre: null, le: null, enCours: false, echec: null));

  /// Oublie le dernier comptage (déconnexion, tests).
  static void oublier() => etat.value = (nombre: null, le: null, enCours: false, echec: null);

  static Future<void> compter(BuildContext context, {DateTime Function() maintenant = DateTime.now}) async {
    if (etat.value.enCours) return; // double appui
    final avant = etat.value;
    etat.value = (nombre: avant.nombre, le: avant.le, enCours: true, echec: null);
    try {
      final n = await ApiSaisiesPerimes.compter(context, maintenant());
      etat.value = (nombre: n, le: maintenant(), enCours: false, echec: null);
    } catch (e) {
      etat.value = (nombre: avant.nombre, le: avant.le, enCours: false, echec: DiagnosticErreur.de(e).message);
    }
  }
}

/// Alerte « Saisies en périmés » (30 derniers jours), même présentation que les autres alertes de l'accueil.
class AlerteSaisiesPerimes extends StatelessWidget {
  final DateTime Function() maintenant;
  const AlerteSaisiesPerimes({super.key = const Key('alerte_saisies_perimes'), this.maintenant = DateTime.now});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: ComptageSaisiesPerimes.etat,
        builder: (context, e, _) {
          const petit = TextStyle(fontSize: 13, color: Charte.gris);
          String deux(int v) => v.toString().padLeft(2, '0');
          return CarteBande(
            bande: Charte.rouge,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaisiesPerimesScreen(maintenant: maintenant))),
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Saisies en périmés', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Charte.encre)),
                  const Text('Produits saisis en périmés ces ${ApiSaisiesPerimes.joursAlerte} derniers jours', style: petit),
                  const SizedBox(height: 2),
                  if (e.enCours)
                    const Text('Comptage en cours…', key: Key('alerte_saisies_perimes_encours'), style: petit)
                  else if (e.echec != null)
                    Text(e.echec!, key: const Key('alerte_saisies_perimes_echec'), style: const TextStyle(fontSize: 13, color: Charte.rougeTexte, fontWeight: FontWeight.w600)),
                  if (e.nombre != null)
                    Text.rich(
                      key: const Key('alerte_saisies_perimes_nombre'),
                      TextSpan(children: [
                        TextSpan(
                            text: '${grouperMilliers(e.nombre!)} saisie${e.nombre! > 1 ? 's' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Charte.encre)),
                        TextSpan(text: ' · à ${deux(e.le!.hour)}:${deux(e.le!.minute)}', style: petit),
                      ]),
                    )
                  else if (!e.enCours && e.echec == null)
                    const Text.rich(
                      key: Key('alerte_saisies_perimes_invite'),
                      TextSpan(style: petit, children: [
                        TextSpan(text: 'Touchez '),
                        WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.refresh, size: 16, color: Charte.gris)),
                        TextSpan(text: ' pour compter'),
                      ]),
                      semanticsLabel: 'Touchez Actualiser pour compter',
                    ),
                ]),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: e.enCours
                    ? Semantics(
                        label: 'Comptage en cours',
                        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Charte.navy))),
                      )
                    : IconButton(
                        key: const Key('alerte_saisies_perimes_actualiser'),
                        tooltip: 'Compter les saisies en périmés',
                        onPressed: () => ComptageSaisiesPerimes.compter(context, maintenant: maintenant),
                        icon: const Icon(Icons.refresh, color: Charte.navy),
                      ),
              ),
              const Icon(Icons.chevron_right, color: Charte.gris),
            ]),
          );
        },
      );
}

/// Liste des saisies en périmés : période commune (30 derniers jours à l'ouverture… « Ce mois » par défaut du
/// sélecteur), recherche (produit, CIP, lot), pages de 50 (« Afficher plus »).
class SaisiesPerimesScreen extends StatefulWidget {
  final DateTime Function() maintenant;
  const SaisiesPerimesScreen({super.key, this.maintenant = DateTime.now});

  @override
  State<SaisiesPerimesScreen> createState() => _SaisiesPerimesScreenState();
}

class _SaisiesPerimesScreenState extends State<SaisiesPerimesScreen> {
  late Periode _periode = Periode.rapide(PeriodeRapide.ceMois, widget.maintenant());
  final _recherche = TextEditingController();
  final _lignes = <SaisiePerime>[];
  int _total = 0;
  bool _enCours = false;
  Object? _erreur;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _charger({bool suite = false}) async {
    if (!mounted) return;
    final g = ++_generation;
    setState(() {
      _enCours = true;
      _erreur = null;
      if (!suite) {
        _lignes.clear();
        _total = 0;
      }
    });
    try {
      final p = await ApiSaisiesPerimes.page(context, _periode.debut, _periode.fin, recherche: _recherche.text, start: suite ? _lignes.length : 0);
      if (!mounted || g != _generation) return;
      setState(() {
        _lignes.addAll(p.lignes);
        _total = p.total;
        _enCours = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _erreur = e;
        _enCours = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Saisies en périmés')),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView.builder(
            key: const Key('defilement_saisies_perimes'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: 3 + _lignes.length,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SelecteurPeriode(
                      periode: _periode,
                      maintenant: widget.maintenant,
                      onChanged: (p) {
                        setState(() => _periode = p);
                        _charger();
                      }),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('recherche_saisies_perimes'),
                    controller: _recherche,
                    maxLength: 50,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _charger(),
                    decoration: InputDecoration(
                      hintText: 'Produit, CIP ou lot',
                      counterText: '',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(tooltip: 'Rechercher', icon: const Icon(Icons.arrow_forward), onPressed: _charger),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                ]);
              }
              if (i == 1) {
                if (_erreur != null) return EtatErreur(erreur: _erreur!, reessayer: _charger);
                if (_enCours && _lignes.isEmpty) return const EtatChargement(texte: 'Chargement des saisies…');
                if (_lignes.isEmpty) {
                  return const EtatVide(titre: 'Aucune saisie en périmés', texte: 'Aucun produit saisi en périmés sur cette période.', icone: Icons.check_circle_outline);
                }
                return Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('${grouperMilliers(_total)} saisie${_total > 1 ? 's' : ''}',
                      key: const Key('saisies_perimes_total'), style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
                );
              }
              if (i == 2 + _lignes.length) {
                if (_lignes.isEmpty || _lignes.length >= _total) return const SizedBox.shrink();
                return PiedPagination(affichees: _lignes.length, total: _total, enCours: _enCours, onPlus: () => _charger(suite: true));
              }
              final s = _lignes[i - 2];
              return CarteLigne(
                titre: s.libelle.isEmpty ? 'Produit' : s.libelle,
                bande: Charte.rouge,
                lignes: [
                  [if (s.cip.isNotEmpty) 'CIP ${s.cip}', if (s.lot.isNotEmpty) 'Lot ${s.lot}'].join(' · '),
                  [if (s.peremption.isNotEmpty) 'Péremption ${s.peremption}', if (s.saisieLe.isNotEmpty) 'saisi le ${s.saisieLe}'].join(' · '),
                  if (s.rayon.isNotEmpty) s.rayon,
                ],
                libelleValeur: 'Quantité',
                valeur: grouperMilliers(s.quantite),
              );
            },
          ),
        ),
      );
}
