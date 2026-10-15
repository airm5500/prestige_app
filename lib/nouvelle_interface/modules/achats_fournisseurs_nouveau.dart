// lib/nouvelle_interface/modules/achats_fournisseurs_nouveau.dart
// Achats fournisseurs de la nouvelle interface, en LECTURE SEULE comme l'écran d'origine. Mêmes données et mêmes
// calculs (AchatsFournisseurs, lib/donnees/achats_fournisseurs_donnees.dart) : fournisseurs GET /fournisseurs, achats
// GET /achats-fournisseurs?dtStart=&dtEnd= ; recherche (fournisseur, N° de BL, N° de commande) et filtre fournisseur
// LOCAUX (aucune nouvelle requête) ; « Récap Achat » : totaux HT / TVA / TTC du fournisseur choisi ou par fournisseur,
// sur tous les achats de la période. Mise en page refaite : période commune chargée dès l'ouverture (« Aujourd'hui »,
// dates par défaut d'origine), recherche contrôlée, fournisseur dans la feuille des filtres, chiffres clés, cartes
// (téléphone) ou tableau dense avec total (tablette) construits 50 par 50, détail d'un achat en feuille.
// Aucun export à l'origine : pas de menu « Exporter ».
import 'package:flutter/material.dart';

import '../../donnees/achats_fournisseurs_donnees.dart';
import '../../models/achat_fournisseur_model.dart';
import '../../models/fournisseur_model.dart';
import '../../utils/date_formatter.dart';
import '../charte.dart';
import '../composants.dart';
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixListe;
import 'commun.dart';
import 'commun_lot2.dart';
import 'commun_lot3.dart';
import 'periode.dart';

class AchatsFournisseursNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const AchatsFournisseursNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<AchatsFournisseursNouveau> createState() => _AchatsFournisseursNouveauState();
}

class _AchatsFournisseursNouveauState extends State<AchatsFournisseursNouveau>
    with ChargementSuivi<AchatsFournisseursNouveau, List<AchatFournisseur>>, AffichageParTranches {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  final _recherche = TextEditingController();
  String _texte = '';
  List<Fournisseur>? _fournisseurs;
  Object? _erreurFournisseurs;
  Fournisseur? _fournisseur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chargerFournisseurs();
      _charger();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _chargerFournisseurs() async {
    setState(() => _erreurFournisseurs = null);
    try {
      final f = await AchatsFournisseurs.fournisseurs(context, onSessionInvalid: sessionInvalide(context));
      if (mounted) setState(() => _fournisseurs = f ?? const []);
    } catch (e) {
      if (mounted) setState(() => _erreurFournisseurs = e);
    }
  }

  Future<void> _charger() {
    reinitialiserTranches();
    return charger(() async =>
        await AchatsFournisseurs.achats(context, _periode.debut, _periode.fin, onSessionInvalid: sessionInvalide(context)) ?? const <AchatFournisseur>[]);
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  Future<void> _filtres() async {
    if (_fournisseurs == null && _erreurFournisseurs != null) _chargerFournisseurs();
    var fournisseur = _fournisseur?.fournisseurId ?? '';
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les achats',
      effacer: () => fournisseur = '',
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChoixListe(
          key: const Key('filtre_fournisseur'),
          libelle: 'Fournisseur',
          icone: Icons.local_shipping_outlined,
          options: _fournisseurs == null ? null : [for (final f in _fournisseurs!) OptionListe(f.fournisseurId, f.fournisseurLibelle)],
          erreur: _erreurFournisseurs,
          valeur: fournisseur,
          tous: 'Tous les fournisseurs',
          onChanged: (v) => setState(() => fournisseur = v),
        ),
        const SizedBox(height: 6),
        const Text('Parmi les achats déjà chargés (aucune nouvelle requête).', style: TextStyle(color: Charte.gris, fontSize: 13)),
      ]),
    );
    if (!applique || !mounted) return;
    setState(() {
      _fournisseur = fournisseur.isEmpty ? null : _fournisseurs?.where((f) => f.fournisseurId == fournisseur).firstOrNull;
      reinitialiserTranches();
    });
  }

  List<AchatFournisseur> _affiches(List<AchatFournisseur> l) => AchatsFournisseurs.filtrer(l, _texte, _fournisseur?.fournisseurId);

  static String _date(AchatFournisseur a) => a.mvtDate != null ? DateFormatter.toDisplayFormat(a.mvtDate!) : 'N/A';

  void _detail(AchatFournisseur a) => ouvrirFeuilleDetail(context, titre: a.fournisseurLibelle, sousTitre: 'Achat du ${_date(a)}', lignes: [
        LigneDetail('Date', _date(a)),
        LigneDetail('N° BL', a.numeroBL.isEmpty ? '—' : a.numeroBL),
        LigneDetail('N° Commande', a.numeroCommade.isEmpty ? '—' : a.numeroCommade),
        const Divider(height: 16),
        LigneDetail('Montant HT', formaterMontant(a.montantHT)),
        LigneDetail('Montant TVA', formaterMontant(a.montantTVA)),
        LigneDetail('Montant TTC', formaterMontant(a.montantTTC), gras: true),
      ]);

  /// « Récap Achat » d'origine : fournisseur choisi, sinon par fournisseur, sur tous les achats de la période.
  void _recap() {
    final tout = donnees ?? const <AchatFournisseur>[];
    if (tout.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Aucun achat sur la période : rien à récapituler.')));
      return;
    }
    final f = _fournisseur;
    final recap = AchatsFournisseurs.recapitulatif(tout, fournisseurId: f?.fournisseurId, libelle: f?.fournisseurLibelle);
    ouvrirFeuilleDetail(
      context,
      titre: f == null ? 'Récapitulatif par fournisseur' : 'Récapitulatif pour ${f.fournisseurLibelle}',
      sousTitre: '${_periode.resume} · tous les achats de la période',
      lignes: [
        for (final e in recap.entries) ...[
          if (f == null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(e.key, style: const TextStyle(color: Charte.navy, fontWeight: FontWeight.bold, fontSize: 15))),
          LigneDetail('Total HT', formaterMontant(e.value.ht)),
          LigneDetail('Total TVA', formaterMontant(e.value.tva)),
          LigneDetail('Total TTC', formaterMontant(e.value.ttc), gras: true),
          if (e.key != recap.keys.last) const Divider(height: 12),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Achats Fournisseurs'), actions: [
          IconButton(key: const Key('achats_recap'), tooltip: 'Récap Achat', icon: const Icon(Icons.summarize_outlined), onPressed: _recap),
          BoutonFiltres(actifs: _fournisseur == null ? 0 : 1, onPressed: _filtres),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            ChampRecherche(
              controleur: _recherche,
              libelle: 'Rechercher un achat',
              aide: 'Fournisseur, N° de BL, N° de commande',
              onRecherche: (t) => setState(() {
                _texte = t;
                reinitialiserTranches();
              }),
            ),
            EtiquettesFiltres(
              etiquettes: [if (_fournisseur != null) 'Fournisseur : ${_fournisseur!.fournisseurLibelle}'],
              onRetirer: () => setState(() {
                _fournisseur = null;
                reinitialiserTranches();
              }),
            ),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des achats…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final tout = donnees ?? const <AchatFournisseur>[];
    if (tout.isEmpty) {
      return const [EtatVide(titre: 'Aucun achat', texte: 'Aucun achat trouvé pour la période sélectionnée.', icone: Icons.shopping_cart_checkout_outlined)];
    }
    final l = _affiches(tout);
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucun achat ne correspond', texte: 'Modifiez la recherche ou le filtre.', icone: Icons.filter_alt_off_outlined)];
    }
    final t = AchatsFournisseurs.totaux(l);
    final n = affichees.clamp(0, l.length);
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Montant TTC', valeur: formaterMontant(t.ttc), id: 'ttc', enAvant: true),
        ChiffreCle(libelle: 'Montant HT', valeur: formaterMontant(t.ht), id: 'ht'),
        ChiffreCle(libelle: 'Montant TVA', valeur: formaterMontant(t.tva), id: 'tva'),
        ChiffreCle(
          libelle: 'Achats',
          valeur: formaterNombre(l.length),
          id: 'achats',
          detail: '${formaterNombre({for (final a in l) a.fournisseurLibelle}.length)} fournisseur(s)${l.length == tout.length ? '' : ' · sur ${formaterNombre(tout.length)}'}',
        ),
      ]),
      const TitreSection('Achats'),
      ListeOuTableau(
        nombre: n,
        onTap: (i) => _detail(l[i]),
        colonnes: const [
          Colonne('Date', flex: 2),
          Colonne('Fournisseur', flex: 4),
          Colonne('N° BL', flex: 3),
          Colonne('N° commande', flex: 3),
          Colonne('HT', flex: 3, droite: true),
          Colonne('TVA', flex: 2, droite: true),
          Colonne('TTC', flex: 3, droite: true),
        ],
        cellules: (i) => [_date(l[i]), l[i].fournisseurLibelle, l[i].numeroBL, l[i].numeroCommade, formaterMontant(l[i].montantHT),
          formaterMontant(l[i].montantTVA), formaterMontant(l[i].montantTTC)],
        total: n == l.length ? ['Total', '', '', '', formaterMontant(t.ht), formaterMontant(t.tva), formaterMontant(t.ttc)] : null,
        carte: (i) => CarteLigne(
          titre: l[i].fournisseurLibelle,
          lignes: [
            '${_date(l[i])} · BL ${l[i].numeroBL.isEmpty ? '—' : l[i].numeroBL}',
            'Commande ${l[i].numeroCommade.isEmpty ? '—' : l[i].numeroCommade}',
            'HT ${formaterMontant(l[i].montantHT)} · TVA ${formaterMontant(l[i].montantTVA)}',
          ],
          libelleValeur: 'TTC',
          valeur: formaterMontant(l[i].montantTTC),
          onTap: () => _detail(l[i]),
        ),
      ),
      piedTranches(l.length),
    ];
  }
}
