// lib/nouvelle_interface/modules/controle_achat_nouveau.dart
// État de Contrôle des Achats de la nouvelle interface. Mêmes données que l'écran d'origine (EtatControleAchats,
// lib/donnees/controle_achat_donnees.dart) : groupes de grossistes (GET /groupegrossiste) et état par groupe
// GET /etat-control-bon/list-annuelle (dtStart, dtEnd, groupeId, groupBy=GROUP, limit=9999). Mise en page refaite :
// période commune (chargée à l'ouverture sur « Aujourd'hui »), groupe dans la feuille du bas, totaux du serveur en
// chiffres clés, groupes en cartes (téléphone) ou tableau avec total (tablette).
import 'package:flutter/material.dart';

import '../../donnees/controle_achat_donnees.dart';
import '../../models/common_data_model.dart';
import '../composants.dart';
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixListe;
import 'commun.dart';
import 'commun_lot2.dart';
import 'periode.dart';

class ControleAchatNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const ControleAchatNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<ControleAchatNouveau> createState() => _ControleAchatNouveauState();
}

class _ControleAchatNouveauState extends State<ControleAchatNouveau> with ChargementSuivi<ControleAchatNouveau, EtatControleAchats> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  List<CommonData>? _groupes;
  Object? _erreurGroupes;
  CommonData? _groupe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chargerGroupes();
      _charger();
    });
  }

  Future<void> _chargerGroupes() async {
    setState(() => _erreurGroupes = null);
    try {
      final g = await EtatControleAchats.groupes(context, onSessionInvalid: sessionInvalide(context));
      if (mounted) setState(() => _groupes = g ?? const []);
    } catch (e) {
      if (mounted) setState(() => _erreurGroupes = e);
    }
  }

  Future<void> _charger() => charger(() async =>
      await EtatControleAchats.charger(context, _periode.debut, _periode.fin, groupeId: _groupe?.id ?? '', onSessionInvalid: sessionInvalide(context)) ??
      const EtatControleAchats([], null));

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  Future<void> _filtres() async {
    if (_groupes == null && _erreurGroupes != null) _chargerGroupes();
    var groupe = _groupe?.id ?? '';
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les achats',
      effacer: () => groupe = '',
      contenu: (ctx, setState) => ChoixListe(
        key: const Key('filtre_groupe'),
        libelle: 'Groupe Grossiste',
        icone: Icons.groups_outlined,
        options: _groupes == null ? null : [for (final g in _groupes!) OptionListe(g.id, g.libelle)],
        erreur: _erreurGroupes,
        valeur: groupe,
        tous: 'Tous les groupes',
        onChanged: (v) => setState(() => groupe = v),
      ),
    );
    if (!applique || !mounted) return;
    setState(() => _groupe = groupe.isEmpty ? null : _groupes?.where((g) => g.id == groupe).firstOrNull);
    _charger();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Etat de Contrôle des Achats'),
          actions: [BoutonFiltres(actifs: _groupe == null ? 0 : 1, onPressed: _filtres)],
        ),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            EtiquettesFiltres(etiquettes: [if (_groupe != null) 'Groupe : ${_groupe!.libelle}'], onRetirer: () {
              setState(() => _groupe = null);
              _charger();
            }),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des achats…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final r = donnees;
    if (r == null || r.lignes.isEmpty) {
      return const [
        EtatVide(titre: 'Aucune donnée trouvée', texte: 'Aucun achat pour les critères sélectionnés.', icone: Icons.fact_check_outlined),
      ];
    }
    final t = r.totaux;
    final l = r.lignes;
    return [
      if (t != null) ...[
        GrilleKpi([
          ChiffreCle(libelle: 'Total Achats TTC', valeur: formaterMontant(t.totalTtc), id: 'achats_ttc', enAvant: true),
          ChiffreCle(libelle: 'Total Bons', valeur: formaterNombre(t.totalNbreBon), id: 'bons'),
          ChiffreCle(libelle: 'Total Marge', valeur: formaterMontant(t.totalMarge), id: 'marge'),
          ChiffreCle(libelle: 'Total Ventes TTC', valeur: formaterMontant(t.totalVenteTtc), id: 'ventes_ttc'),
        ]),
        const SizedBox(height: 12),
        CarteSection(titre: 'Totaux de la période', icone: Icons.functions, enfants: [
          LigneDetail('Total Bons', formaterNombre(t.totalNbreBon)),
          LigneDetail('Total Achats HT', formaterMontant(t.totaltHtaxe)),
          LigneDetail('Total TVA', formaterMontant(t.totalTaxe)),
          LigneDetail('Total Achats TTC', formaterMontant(t.totalTtc), gras: true),
          LigneDetail('Total Ventes TTC', formaterMontant(t.totalVenteTtc)),
          LigneDetail('Total Marge', formaterMontant(t.totalMarge), gras: true),
        ]),
      ],
      const TitreSection('Par groupe'),
      ListeOuTableau(
        nombre: l.length,
        colonnes: const [
          Colonne('Groupe', flex: 4),
          Colonne('Nb Bons', flex: 2, droite: true),
          Colonne('Montant HT', flex: 3, droite: true),
          Colonne('Montant TTC', flex: 3, droite: true),
          Colonne('Marge', flex: 3, droite: true),
        ],
        cellules: (i) => [l[i].groupByLibelle, formaterNombre(l[i].nbreBon), formaterMontant(l[i].montantHtaxe), formaterMontant(l[i].montantTtc), formaterMontant(l[i].montantMarge)],
        total: t == null ? null : ['Total', formaterNombre(t.totalNbreBon), formaterMontant(t.totaltHtaxe), formaterMontant(t.totalTtc), formaterMontant(t.totalMarge)],
        carte: (i) => CarteLigne(
          titre: l[i].groupByLibelle,
          lignes: [
            '${formaterNombre(l[i].nbreBon)} bon${l[i].nbreBon > 1 ? 's' : ''} · HT ${formaterMontant(l[i].montantHtaxe)}',
            'Marge ${formaterMontant(l[i].montantMarge)}',
          ],
          libelleValeur: 'TTC',
          valeur: formaterMontant(l[i].montantTtc),
        ),
      ),
    ];
  }
}
