// lib/nouvelle_interface/modules/suivi_credit_nouveau.dart
// Suivi des Crédits de la nouvelle interface. Mêmes données que l'écran d'origine (SuiviCredits : GET
// /recap/credits avec dtStart / dtEnd ; filtre par tiers payant appliqué sur la liste reçue, sans nouvelle
// requête), mise en page refaite : période commune, chiffres clés de la liste affichée, filtres (tiers payant,
// type) dans une feuille du bas, cartes (téléphone) ou tableau (tablette). Chargé à l'ouverture.
import 'package:flutter/material.dart';

import '../../donnees/suivi_credit_donnees.dart';
import '../../models/suivi_credit_model.dart';
import '../../utils/saisie.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'periode.dart';

class SuiviCreditNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const SuiviCreditNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<SuiviCreditNouveau> createState() => _SuiviCreditNouveauState();
}

class _SuiviCreditNouveauState extends State<SuiviCreditNouveau> with ChargementSuivi<SuiviCreditNouveau, List<SuiviCredit>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  String _tiers = '';
  String? _type;

  /// Champ de la feuille des filtres (gardé par l'écran : la feuille peut encore s'animer après sa fermeture).
  final _champTiers = TextEditingController();

  @override
  void dispose() {
    _champTiers.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() => charger(() async =>
      await SuiviCredits.charger(context, _periode.debut, _periode.fin, onSessionInvalid: sessionInvalide(context)) ?? const <SuiviCredit>[]);

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  int get _actifs => (_tiers.isEmpty ? 0 : 1) + (_type == null ? 0 : 1);

  List<SuiviCredit> get _affichees {
    final l = SuiviCredits.filtrer(donnees ?? const [], _tiers);
    return _type == null ? l : l.where((c) => c.libelleTypeTiersPayant == _type).toList();
  }

  Future<void> _filtres() async {
    final types = {for (final c in donnees ?? const <SuiviCredit>[]) c.libelleTypeTiersPayant}.toList()..sort();
    final champ = _champTiers..text = _tiers;
    String? type = _type;
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les crédits',
      effacer: () {
        champ.clear();
        type = null;
      },
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          key: const Key('filtre_tiers'),
          controller: champ,
          inputFormatters: ChampRecherche.formatteurs,
          decoration: const InputDecoration(labelText: 'Tiers payant', hintText: 'Nom ou partie du nom', prefixIcon: Icon(Icons.search)),
        ),
        if (types.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Type de tiers payant', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 0, children: [
            for (final t in [null, ...types])
              ChoiceChip(
                key: Key('filtre_type_${t ?? 'tous'}'),
                label: Text(t ?? 'Tous', style: TextStyle(color: type == t ? Charte.blanc : Charte.navy)),
                selected: type == t,
                showCheckmark: false,
                onSelected: (_) => setState(() => type = t),
              ),
          ]),
        ],
      ]),
    );
    if (applique && mounted) {
      setState(() {
        _tiers = Saisie.recherche(champ.text);
        _type = type;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Suivi des Crédits'), actions: [BoutonFiltres(actifs: _actifs, onPressed: _filtres)]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            if (_actifs > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (_tiers.isNotEmpty) Etiquette('Tiers : $_tiers'),
                  if (_type != null) Etiquette('Type : $_type'),
                  TextButton(
                    key: const Key('filtres_retirer'),
                    onPressed: () => setState(() {
                      _tiers = '';
                      _type = null;
                    }),
                    child: const Text('Retirer les filtres'),
                  ),
                ]),
              ),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des crédits…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final tout = donnees ?? const <SuiviCredit>[];
    if (tout.isEmpty) {
      return const [EtatVide(titre: 'Aucun crédit sur la période', texte: 'Choisissez une autre période.', icone: Icons.request_quote_outlined)];
    }
    final l = _affichees;
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucun résultat pour vos filtres', texte: 'Modifiez ou retirez les filtres.', icone: Icons.filter_alt_off_outlined)];
    }
    final montant = l.fold<double>(0, (s, c) => s + c.montant);
    final bons = l.fold<int>(0, (s, c) => s + c.nbreBons);
    final clients = l.fold<int>(0, (s, c) => s + c.nbreClient);
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Montant des crédits', valeur: formaterMontant(montant), id: 'montant', enAvant: true, detail: _actifs > 0 ? 'Liste filtrée' : null),
        ChiffreCle(libelle: 'Tiers payants', valeur: formaterNombre(l.length), id: 'tiers'),
        ChiffreCle(libelle: 'Nombre de bons', valeur: formaterNombre(bons), id: 'bons'),
        ChiffreCle(libelle: 'Nombre de clients', valeur: formaterNombre(clients), id: 'clients'),
      ]),
      const TitreSection('Crédits par tiers payant'),
      ListeOuTableau(
        nombre: l.length,
        colonnes: const [
          Colonne('Tiers payant', flex: 4),
          Colonne('Type', flex: 3),
          Colonne('Bons', flex: 1, droite: true),
          Colonne('Clients', flex: 1, droite: true),
          Colonne('Montant', flex: 2, droite: true),
        ],
        cellules: (i) => [l[i].libelleTiersPayant, l[i].libelleTypeTiersPayant, '${l[i].nbreBons}', '${l[i].nbreClient}', formaterMontant(l[i].montant)],
        total: ['Total', '', formaterNombre(bons), formaterNombre(clients), formaterMontant(montant)],
        carte: (i) => CarteLigne(
          titre: l[i].libelleTiersPayant,
          etiquette: Etiquette(l[i].libelleTypeTiersPayant, ton: Ton.gris),
          lignes: ['${l[i].nbreBons} bon${l[i].nbreBons > 1 ? 's' : ''} · ${l[i].nbreClient} client${l[i].nbreClient > 1 ? 's' : ''}'],
          valeur: formaterMontant(l[i].montant),
        ),
      ),
    ];
  }
}
