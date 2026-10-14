// lib/nouvelle_interface/vague2/garde_vague2.dart
// Menu « Analyse de garde » (web « gardemanager ») en LECTURE SEULE :
//  - gardes d'une année (GET /gardes/annees puis GET /gardes?annee=, la plus récente année par défaut) ;
//  - pour une garde (GET /gardes/{id}/rapport?heures=2&tri=montant&classe=&start=0&limit=25) : chiffres clés
//    (ventes, clients, montant, marge et taux, montant par heure, espèces / mobile…), tranches horaires en barres
//    (largeur 1 à 4 h), résumé ABC ; produits classés A / B / C, triés par montant / quantité / marge, pages de 100
//    (le serveur recalcule l'analyse à chaque page : moins de pages, moins de recalculs) ;
//  - ce qui est chargé est GARDÉ : onglets conservés (pas de rechargement en changeant d'onglet), et changer la
//    largeur des tranches ne relit que la synthèse (limit=1) sans vider les produits déjà chargés ;
//    vendeurs (GET /gardes/{id}/vendeurs, lus à la première ouverture de l'onglet).
// Aucune création, modification ni suppression de garde, ni inventaire, ni suggestion.
import 'package:flutter/material.dart';

import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import 'commun_vague2.dart';
import 'donnees_vague2.dart';

class AnalyseGardeScreen extends StatefulWidget {
  final DateTime Function() maintenant;
  const AnalyseGardeScreen({super.key, this.maintenant = DateTime.now});

  @override
  State<AnalyseGardeScreen> createState() => _AnalyseGardeScreenState();
}

class _AnalyseGardeScreenState extends State<AnalyseGardeScreen> with ChargementSuivi<AnalyseGardeScreen, List<Garde>> {
  List<int>? _annees;
  Object? _erreurAnnees;
  int? _annee;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerAnnees());
  }

  Future<void> _chargerAnnees() async {
    if (!mounted) return;
    setState(() => _erreurAnnees = null);
    try {
      final a = await ApiGardes.annees(context);
      if (!mounted) return;
      final annee = a.isEmpty ? widget.maintenant().year : a.first;
      setState(() {
        _annees = a.isEmpty ? [annee] : a;
        _annee = annee;
      });
      _chargerGardes();
    } catch (e) {
      if (mounted) setState(() => _erreurAnnees = e);
    }
  }

  void _chargerGardes() {
    final a = _annee;
    if (a != null && mounted) charger(() => ApiGardes.gardes(context, a));
  }

  @override
  Widget build(BuildContext context) {
    final g = donnees;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse de garde'),
        actions: [
          IconButton(
            key: const Key('gardes_actualiser'),
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: enCours ? null : (_annees == null ? _chargerAnnees : _chargerGardes),
          ),
        ],
      ),
      body: ListView(key: const Key('defilement_gardes'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        if (_erreurAnnees != null) EtatErreur(erreur: _erreurAnnees!, reessayer: _chargerAnnees),
        if (_annees == null && _erreurAnnees == null) const EtatChargement(texte: 'Chargement des gardes…'),
        if (_annees != null) ...[
          SingleChildScrollView(
            key: const Key('gardes_annees'),
            scrollDirection: Axis.horizontal,
            child: PucesChoix<int>(
              choix: [for (final a in _annees!) (a, '$a')],
              valeur: _annee ?? _annees!.first,
              cle: (a, _) => Key('annee_$a'),
              onChanged: (a) {
                setState(() => _annee = a);
                _chargerGardes();
              },
            ),
          ),
          const SizedBox(height: 8),
          if (enCours) const EtatChargement(texte: 'Chargement des gardes…'),
          if (erreur != null) EtatErreur(erreur: erreur!, reessayer: _chargerGardes),
          if (g != null && !enCours) ...[
            if (g.isEmpty)
              EtatVide(titre: 'Aucune garde en ${_annee ?? ''}', texte: 'Les gardes s\'enregistrent dans Prestige (web).', icone: Icons.nightlight_outlined)
            else ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('${g.length} garde${g.length > 1 ? 's' : ''} en $_annee',
                    key: const Key('gardes_total'), style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
              ),
              ListeOuTableau(
                nombre: g.length,
                onTap: (i) => _ouvrir(g[i]),
                colonnes: const [Colonne('Garde', flex: 4), Colonne('Début', flex: 3), Colonne('Fin', flex: 3), Colonne('Durée', flex: 2, droite: true)],
                cellules: (i) => [g[i].titre, g[i].debutLisible, g[i].finLisible, g[i].duree],
                carte: (i) => CarteLigne(
                  key: Key('garde_${g[i].id}'),
                  titre: g[i].titre,
                  lignes: ['Du ${g[i].debutLisible}', 'au ${g[i].finLisible}'],
                  libelleValeur: 'Durée',
                  valeur: g[i].duree.isEmpty ? '—' : g[i].duree,
                  onTap: () => _ouvrir(g[i]),
                ),
              ),
            ],
          ],
        ],
      ]),
    );
  }

  void _ouvrir(Garde g) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GardeDetailScreen(garde: g)));
}

class GardeDetailScreen extends StatefulWidget {
  final Garde garde;
  const GardeDetailScreen({super.key, required this.garde});

  @override
  State<GardeDetailScreen> createState() => _GardeDetailScreenState();
}

class _GardeDetailScreenState extends State<GardeDetailScreen> with SingleTickerProviderStateMixin {
  late final _onglets = TabController(length: 3, vsync: this);
  int _heures = 2;
  TriGarde _tri = TriGarde.montant;
  String _classe = '';

  RapportGarde? _rapport;
  final _abc = <ProduitAbc>[];
  bool _chargement = false;
  bool _chargementPlus = false;
  Object? _erreur;
  int _generation = 0;

  // Synthèse seule (largeur des tranches) : les produits déjà chargés sont gardés.
  bool _chargementSynthese = false;
  Object? _erreurSynthese;
  int _generationSynthese = 0;

  List<VendeurGarde>? _vendeurs;
  Object? _erreurVendeurs;
  bool _chargementVendeurs = false;

  @override
  void initState() {
    super.initState();
    _onglets.addListener(() {
      if (!mounted || _onglets.indexIsChanging) return;
      setState(() {});
      if (_onglets.index == 2 && _vendeurs == null && !_chargementVendeurs) _chargerVendeurs();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final g = ++_generation;
    _generationSynthese++;
    setState(() {
      _chargementSynthese = false;
      _erreurSynthese = null;
      _chargement = true;
      _chargementPlus = false;
      _erreur = null;
    });
    try {
      final r = await ApiGardes.rapport(context, widget.garde.id, heures: _heures, tri: _tri, classe: _classe);
      if (!mounted || g != _generation) return;
      setState(() {
        _rapport = r;
        _abc
          ..clear()
          ..addAll(r.abc);
        _chargement = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _erreur = e;
        _chargement = false;
      });
    }
  }

  /// Nouvelle largeur des tranches : relit la synthèse (1 produit demandé), garde la liste des produits.
  Future<void> _chargerSynthese() async {
    if (_rapport == null || _chargement) return _charger();
    final g = ++_generationSynthese;
    setState(() {
      _chargementSynthese = true;
      _erreurSynthese = null;
    });
    try {
      final r = await ApiGardes.rapport(context, widget.garde.id, heures: _heures, tri: _tri, classe: _classe, limit: 1);
      if (!mounted || g != _generationSynthese) return;
      final avant = _rapport!;
      setState(() {
        _rapport = RapportGarde(
            garde: r.garde ?? avant.garde, kpi: r.kpi, tranches: r.tranches, abc: _abc, totalAbc: avant.totalAbc, totalFiltre: avant.totalFiltre, resume: r.resume);
        _chargementSynthese = false;
      });
    } catch (e) {
      if (!mounted || g != _generationSynthese) return;
      setState(() {
        _erreurSynthese = e;
        _chargementSynthese = false;
      });
    }
  }

  Future<void> _plus() async {
    if (_chargement || _chargementPlus) return;
    final g = _generation;
    setState(() => _chargementPlus = true);
    try {
      final r = await ApiGardes.rapport(context, widget.garde.id, heures: _heures, tri: _tri, classe: _classe, start: _abc.length);
      if (!mounted || g != _generation) return;
      setState(() {
        _abc.addAll(r.abc);
        if (r.abc.isEmpty) _rapport = RapportGarde(garde: _rapport?.garde, kpi: _rapport!.kpi, tranches: _rapport!.tranches, abc: _abc, totalAbc: _rapport!.totalAbc, totalFiltre: _abc.length, resume: _rapport!.resume);
        _chargementPlus = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _erreur = e;
        _chargementPlus = false;
      });
    }
  }

  Future<void> _chargerVendeurs() async {
    setState(() {
      _chargementVendeurs = true;
      _erreurVendeurs = null;
    });
    try {
      final v = await ApiGardes.vendeurs(context, widget.garde.id);
      if (mounted) setState(() => _vendeurs = v);
    } catch (e) {
      if (mounted) setState(() => _erreurVendeurs = e);
    } finally {
      if (mounted) setState(() => _chargementVendeurs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _rapport;
    final garde = r?.garde ?? widget.garde;
    return Scaffold(
      appBar: AppBar(
        title: Text(garde.titre),
        bottom: ongletsBlancs(_onglets, const ['Synthèse', 'Produits', 'Vendeurs'], key: const Key('garde_onglets')),
      ),
      body: IndexedStack(index: _onglets.index, children: [
        ListView(key: const Key('defilement_garde_synthese'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Text('Du ${garde.debutLisible} au ${garde.finLisible}${garde.duree.isEmpty ? '' : ' · ${garde.duree}'}',
              style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._etat(),
          if (_chargementSynthese) const EtatChargement(texte: 'Nouvelles tranches horaires…'),
          if (_erreurSynthese != null) EtatErreur(erreur: _erreurSynthese!, reessayer: _chargerSynthese),
          if (r != null && !_chargement && !_chargementSynthese) ..._synthese(r),
        ]),
        ListView(key: const Key('defilement_garde_produits'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          const Text('Trier par', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
          PucesChoix<TriGarde>(
            choix: [for (final t in TriGarde.values) (t, t.libelle)],
            valeur: _tri,
            cle: (t, _) => Key('tri_${t.code}'),
            onChanged: (t) {
              setState(() => _tri = t);
              _charger();
            },
          ),
          const SizedBox(height: 6),
          const Text('Classe', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
          PucesChoix<String>(
            choix: [for (final c in ApiGardes.classes) (c, c.isEmpty ? 'Toutes' : 'Classe $c')],
            valeur: _classe,
            cle: (c, _) => Key('classe_${c.isEmpty ? 'toutes' : c}'),
            onChanged: (c) {
              setState(() => _classe = c);
              _charger();
            },
          ),
          const SizedBox(height: 8),
          ..._etat(),
          if (r != null && !_chargement) ..._produits(r),
        ]),
        ListView(key: const Key('defilement_garde_vendeurs'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          if (_chargementVendeurs) const EtatChargement(texte: 'Chargement des vendeurs…'),
          if (_erreurVendeurs != null) EtatErreur(erreur: _erreurVendeurs!, reessayer: _chargerVendeurs),
          if (_vendeurs != null && !_chargementVendeurs) ..._listeVendeurs(_vendeurs!),
        ]),
      ]),
    );
  }

  List<Widget> _etat() => [
        if (_chargement) const EtatChargement(texte: 'Analyse de la garde…'),
        if (_erreur != null) EtatErreur(erreur: _erreur!, reessayer: _abc.isEmpty ? _charger : _plus),
      ];

  List<Widget> _synthese(RapportGarde r) {
    final k = r.kpi;
    return [
      GrilleChiffres([
        ChiffreCle(libelle: 'Chiffre d\'affaires', valeur: formaterMontant(k.montant), enAvant: true, id: 'garde_montant'),
        ChiffreCle(libelle: 'Ventes', valeur: grouperMilliers(k.ventes), id: 'garde_ventes'),
        ChiffreCle(libelle: 'Clients', valeur: grouperMilliers(k.clients), id: 'garde_clients'),
        ChiffreCle(libelle: 'Marge', valeur: formaterMontant(k.marge), detail: 'taux ${pourcentTexte(k.tauxMarge)}', id: 'garde_marge'),
        ChiffreCle(libelle: 'Montant par heure', valeur: formaterMontant(k.montantParHeure), id: 'garde_par_heure'),
        ChiffreCle(libelle: 'Espèces', valeur: formaterMontant(k.caEspeces), id: 'garde_especes'),
        ChiffreCle(libelle: 'Mobile money', valeur: formaterMontant(k.caMobile), id: 'garde_mobile'),
        if (k.caCarte > 0) ChiffreCle(libelle: 'Carte', valeur: formaterMontant(k.caCarte)),
        if (k.caCheque > 0) ChiffreCle(libelle: 'Chèque', valeur: formaterMontant(k.caCheque)),
        if (k.montantCredit > 0) ChiffreCle(libelle: 'Crédit', valeur: formaterMontant(k.montantCredit)),
      ]),
      const TitreSection('Tranches horaires'),
      PucesChoix<int>(
        choix: [for (final h in ApiGardes.heuresPossibles) (h, '$h h')],
        valeur: _heures,
        cle: (h, _) => Key('heures_$h'),
        onChanged: (h) {
          setState(() => _heures = h);
          _chargerSynthese();
        },
      ),
      const SizedBox(height: 6),
      if (r.tranches.isEmpty)
        const EtatVide(titre: 'Aucune vente pendant la garde')
      else
        CarteSection(enfants: [
          BarresHorizontales(
            key: const Key('garde_tranches'),
            barres: [for (final t in r.tranches) (t.libelle, t.montant.toDouble(), '${formaterMontant(t.montant)} · ${t.clients} cl.')],
            largeurLibelle: 88,
          ),
        ]),
      if (r.resume.isNotEmpty) ...[
        const TitreSection('Classement ABC'),
        CarteSection(enfants: [
          for (final c in r.resume) LigneDetail('Classe ${c.classe} · ${grouperMilliers(c.produits)} produits', '${formaterMontant(c.montant)} (${pourcentTexte(c.part)})'),
        ]),
      ],
    ];
  }

  List<Widget> _produits(RapportGarde r) {
    if (_abc.isEmpty) return [const EtatVide(titre: 'Aucun produit', texte: 'Aucun produit vendu pour ce choix.', icone: Icons.search_off)];
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text('${grouperMilliers(r.totalFiltre)} produits${_classe.isEmpty ? '' : ' en classe $_classe'} sur ${grouperMilliers(r.totalAbc)}',
            key: const Key('garde_produits_total'), style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
      ),
      ListeOuTableau(
        nombre: _abc.length,
        colonnes: const [
          Colonne('Cl.', flex: 1),
          Colonne('Produit', flex: 5),
          Colonne('Qté', flex: 2, droite: true),
          Colonne('Montant', flex: 3, droite: true),
          Colonne('Marge', flex: 3, droite: true),
          Colonne('Part', flex: 2, droite: true),
          Colonne('Stock', flex: 2, droite: true),
        ],
        cellules: (i) {
          final p = _abc[i];
          return [p.classe, p.libelle, grouperMilliers(p.quantite), formaterMontant(p.montant), formaterMontant(p.marge), pourcentTexte(p.part), grouperMilliers(p.stock)];
        },
        carte: (i) {
          final p = _abc[i];
          return CarteLigne(
            titre: p.libelle,
            etiquette: Etiquette('Classe ${p.classe.isEmpty ? '?' : p.classe}', ton: p.classe == 'A' ? Ton.vert : (p.classe == 'B' ? Ton.ambre : Ton.gris)),
            lignes: [
              [if (p.cip.isNotEmpty) 'CIP ${p.cip}', 'quantité ${grouperMilliers(p.quantite)}', 'stock ${grouperMilliers(p.stock)}'].join(' · '),
              'Marge ${formaterMontant(p.marge)} (${pourcentTexte(p.tauxMarge)}) · part ${pourcentTexte(p.part)}',
            ],
            libelleValeur: 'Montant',
            valeur: formaterMontant(p.montant),
          );
        },
      ),
      PiedPagination(affichees: _abc.length, total: r.totalFiltre < _abc.length ? _abc.length : r.totalFiltre, enCours: _chargementPlus, onPlus: _plus),
    ];
  }

  List<Widget> _listeVendeurs(List<VendeurGarde> v) {
    if (v.isEmpty) return [const EtatVide(titre: 'Aucun vendeur', texte: 'Aucune vente pendant cette garde.')];
    return [
      ListeOuTableau(
        nombre: v.length,
        colonnes: const [
          Colonne('Vendeur', flex: 4),
          Colonne('Ventes', flex: 2, droite: true),
          Colonne('Clients', flex: 2, droite: true),
          Colonne('Montant', flex: 3, droite: true),
          Colonne('Marge', flex: 3, droite: true),
          Colonne('Part', flex: 2, droite: true),
        ],
        cellules: (i) => [v[i].nom, grouperMilliers(v[i].ventes), grouperMilliers(v[i].clients), formaterMontant(v[i].montant), formaterMontant(v[i].marge), pourcentTexte(v[i].part)],
        carte: (i) => CarteLigne(
          key: Key('vendeur_$i'),
          titre: v[i].nom.isEmpty ? 'Vendeur' : v[i].nom,
          lignes: [
            '${grouperMilliers(v[i].ventes)} ventes · ${grouperMilliers(v[i].clients)} clients',
            'Marge ${formaterMontant(v[i].marge)} (${pourcentTexte(v[i].tauxMarge)}) · part ${pourcentTexte(v[i].part)}',
          ],
          libelleValeur: 'Montant',
          valeur: formaterMontant(v[i].montant),
        ),
      ),
    ];
  }
}
