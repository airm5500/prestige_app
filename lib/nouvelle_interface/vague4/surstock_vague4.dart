// lib/nouvelle_interface/vague4/surstock_vague4.dart
// 3.11.0 — menu « Sur-stocks » (web « gestionsurstock »), administrateur et pharmacien, LECTURE SEULE :
//  - GET /surstock (historique et projection en mois, 3 et 3 par défaut comme le web ; recherche produit / CIP ;
//    filtres emplacement, grossiste, famille à choix multiple ; pages de 50 : la première recalcule, les suivantes
//    relisent le cache du serveur) ; produits triés par valeur du surplus (ordre du serveur) ;
//  - Exporter → classeur Excel du web (GET /surstock/excel), Partager / Ouvrir ;
//  - JAMAIS : création d'inventaire (POST /surstock/create-inventaire, écriture).
import 'package:flutter/material.dart';

import '../../presences/export_fichier.dart';
import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/commun_lot2.dart' show messageResultat;
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixMultiple;
import '../vague2/donnees_vague2.dart' show ApiVague2, FiltresCa, decimalTexte, grouperMilliers;
import 'donnees_vague4.dart';

class SurstocksScreen extends StatefulWidget {
  final FiltresSurstock filtresInitiaux;
  const SurstocksScreen({super.key, this.filtresInitiaux = const FiltresSurstock()});

  @override
  State<SurstocksScreen> createState() => _SurstocksScreenState();
}

class _SurstocksScreenState extends State<SurstocksScreen> {
  late FiltresSurstock _filtres = widget.filtresInitiaux;
  late final _recherche = TextEditingController(text: widget.filtresInitiaux.recherche);
  final _produits = <ProduitSurstock>[];
  int _total = 0;
  int _valeur = 0;
  List<String> _mois = const ['', '', '', ''];
  bool _enCours = false;
  bool _charge = false;
  Object? _erreur;
  int _generation = 0;
  bool _export = false;
  final _options = <String, List<OptionListe>>{};
  final _erreursOptions = <String, Object>{};
  final _versionOptions = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _recherche.dispose();
    _versionOptions.dispose();
    super.dispose();
  }

  Future<void> _charger({bool suite = false}) async {
    if (!mounted) return;
    final g = ++_generation;
    final f = _filtres;
    setState(() {
      _enCours = true;
      _erreur = null;
      if (!suite) {
        _produits.clear();
        _charge = false;
      }
    });
    try {
      final p = await ApiSurstock.page(context, f, start: suite ? _produits.length : 0);
      if (!mounted || g != _generation) return;
      setState(() {
        _produits.addAll(p.produits);
        _total = p.total;
        _valeur = p.totalValeur;
        if (p.mois.any((m) => m.isNotEmpty)) _mois = p.mois;
        _enCours = false;
        _charge = true;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _erreur = e;
        _enCours = false;
      });
    }
  }

  void _rechercher() {
    setState(() => _filtres = _filtres.copie(recherche: _recherche.text));
    _charger();
  }

  Future<void> _chargerOption(String route, String quoi) async {
    if (_options.containsKey(route)) return;
    _erreursOptions.remove(route);
    try {
      _options[route] = await ApiVague2.options(context, route, quoi);
    } catch (e) {
      _erreursOptions[route] = e;
    }
    if (!mounted) return;
    _versionOptions.value++;
  }

  Future<void> _ouvrirFiltres() async {
    var f = _filtres;
    _chargerOption(ApiVague2.routeRayons, 'la liste des emplacements');
    _chargerOption(ApiVague2.routeGrossistes, 'la liste des grossistes');
    _chargerOption(ApiVague2.routeFamilles, 'la liste des familles');
    Widget mois(String titre, String cle, int valeur, ValueChanged<int> choisir) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(titre, style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          PucesChoix<int>(
            choix: [for (final m in FiltresSurstock.choixMois) (m, '$m mois')],
            valeur: valeur,
            cle: (m, _) => Key('${cle}_$m'),
            onChanged: choisir,
          ),
        ]);
    final ok = await ouvrirFeuilleFiltres(
      context,
      titre: 'Critères des sur-stocks',
      effacer: () => f = FiltresSurstock(recherche: f.recherche),
      contenu: (ctx, setState) => ValueListenableBuilder<int>(
        valueListenable: _versionOptions,
        builder: (_, __, ___) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          mois('Historique des ventes', 'surstock_historique', f.moisHistorique, (m) => setState(() => f = f.copie(moisHistorique: m))),
          const SizedBox(height: 12),
          mois('Projection (couverture visée)', 'surstock_projection', f.moisProjection, (m) => setState(() => f = f.copie(moisProjection: m))),
          const SizedBox(height: 14),
          ChoixMultiple(
            key: const Key('filtre_emplacement'),
            cle: 'emplacement',
            libelle: 'Emplacements',
            icone: Icons.shelves,
            options: _options[ApiVague2.routeRayons],
            erreur: _erreursOptions[ApiVague2.routeRayons],
            valeurs: f.rayons,
            onChanged: (v) => setState(() => f = f.copie(rayons: v)),
          ),
          const SizedBox(height: 12),
          ChoixMultiple(
            key: const Key('filtre_grossiste'),
            cle: 'grossiste',
            libelle: 'Grossistes',
            icone: Icons.local_shipping_outlined,
            options: _options[ApiVague2.routeGrossistes],
            erreur: _erreursOptions[ApiVague2.routeGrossistes],
            valeurs: f.grossistes,
            onChanged: (v) => setState(() => f = f.copie(grossistes: v)),
          ),
          const SizedBox(height: 12),
          ChoixMultiple(
            key: const Key('filtre_famille'),
            cle: 'famille',
            libelle: 'Familles',
            icone: Icons.category_outlined,
            options: _options[ApiVague2.routeFamilles],
            erreur: _erreursOptions[ApiVague2.routeFamilles],
            valeurs: f.familles,
            onChanged: (v) => setState(() => f = f.copie(familles: v)),
          ),
        ]),
      ),
    );
    if (!ok || !mounted) return;
    List<String>? ids(String route) => _options[route]?.map((o) => o.id).toList();
    setState(() => _filtres = f.copie(
          recherche: _recherche.text,
          rayons: FiltresCa.normaliser(f.rayons, ids(ApiVague2.routeRayons)),
          grossistes: FiltresCa.normaliser(f.grossistes, ids(ApiVague2.routeGrossistes)),
          familles: FiltresCa.normaliser(f.familles, ids(ApiVague2.routeFamilles)),
        ));
    _charger();
  }

  Future<void> _exporter() async {
    if (_export) return;
    setState(() => _export = true);
    try {
      final f = await ApiSurstock.excel(context, _filtres);
      if (!mounted) return;
      await ExportFichier.proposer(context, f, sujet: 'Gestion des sur-stocks');
    } catch (e) {
      if (mounted) messageResultat(context, 'Export impossible : ${DiagnosticErreur.de(e).message}', echec: true);
    } finally {
      if (mounted) setState(() => _export = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sur-stocks'), actions: [
          _export
              ? const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  key: const Key('surstock_excel'),
                  tooltip: 'Exporter (Excel)',
                  icon: const Icon(Icons.table_view_outlined),
                  onPressed: _charge && _total > 0 ? _exporter : null,
                ),
          BoutonFiltres(actifs: _filtres.actifs + (_filtres.moisHistorique == 3 && _filtres.moisProjection == 3 ? 0 : 1), onPressed: _ouvrirFiltres),
          IconButton(key: const Key('surstock_actualiser'), tooltip: 'Actualiser', icon: const Icon(Icons.refresh), onPressed: _enCours ? null : _charger),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          // Produits construits à l'affichage (listes longues).
          child: ListView.builder(
            key: const Key('defilement_surstock'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: 3 + _produits.length,
            itemBuilder: (context, i) {
              if (i == 0) return _entete();
              if (i == 1) return _etat();
              if (i == 2 + _produits.length) {
                if (_produits.isEmpty || _produits.length >= _total) return const SizedBox.shrink();
                return PiedPagination(affichees: _produits.length, total: _total, enCours: _enCours, onPlus: () => _charger(suite: true));
              }
              return _carte(_produits[i - 2], i - 2);
            },
          ),
        ),
      );

  Widget _entete() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          key: const Key('recherche_surstock'),
          controller: _recherche,
          maxLength: FiltresSurstock.maxRecherche,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _rechercher(),
          decoration: InputDecoration(
            hintText: 'Produit ou CIP',
            counterText: '',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(tooltip: 'Rechercher', icon: const Icon(Icons.arrow_forward), onPressed: _rechercher),
            isDense: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
          child: Text('Historique ${_filtres.moisHistorique} mois · projection ${_filtres.moisProjection} mois',
              key: const Key('surstock_criteres'), style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]);

  Widget _etat() {
    if (_erreur != null) return EtatErreur(erreur: _erreur!, reessayer: _charger);
    if (_enCours && _produits.isEmpty) return const EtatChargement(texte: 'Calcul des sur-stocks…');
    if (!_charge) return const SizedBox.shrink();
    if (_produits.isEmpty) {
      return const EtatVide(titre: 'Aucun sur-stock', texte: 'Aucun produit au-delà de la couverture visée.', icone: Icons.check_circle_outline);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GrilleKpi([
        ChiffreCle(libelle: 'Produits en sur-stock', valeur: grouperMilliers(_total), id: 'surstock_total', enAvant: true),
        ChiffreCle(libelle: 'Valeur du surplus', valeur: formaterMontant(_valeur), id: 'surstock_valeur', detail: 'au prix d\'achat'),
      ]),
    );
  }

  Widget _carte(ProduitSurstock p, int i) {
    final ventes = [for (var k = 3; k >= 1; k--) if (_mois[k].isNotEmpty) '${_mois[k]} ${grouperMilliers(p.mois[k])}'];
    return CarteLigne(
      key: Key('surstock_$i'),
      titre: p.libelle.isEmpty ? 'Produit' : p.libelle,
      bande: Charte.ambre,
      lignes: [
        [if (p.cip.isNotEmpty) 'CIP ${p.cip}', if (p.emplacement.isNotEmpty) p.emplacement].join(' · '),
        'Stock ${grouperMilliers(p.stock)} · surplus ${grouperMilliers(p.qteSurplus)} · ${decimalTexte(p.nbMoisStock)} mois de stock',
        if (ventes.isNotEmpty) 'Ventes : ${ventes.join(' · ')}${_mois[0].isEmpty ? '' : ' · ${_mois[0]} (en cours) ${grouperMilliers(p.mois[0])}'}',
        'Moyenne ${decimalTexte(p.moyenneMensuelle)} / mois · PA ${formaterMontant(p.prixAchat)}${p.datePeremption.isEmpty ? '' : ' · péremption ${p.datePeremption}'}',
      ],
      libelleValeur: 'Surplus',
      valeur: formaterMontant(p.valeurSurplus),
    );
  }
}
