// lib/nouvelle_interface/modules/rapport_activite_nouveau.dart
// Rapport d'Activité de la nouvelle interface. Mêmes données que l'écran d'origine (RapportActivite.charger :
// /recap/dashboard, /recap/credits, /recap/credits/totaux, /recap/reglements avec dtStart / dtEnd), mise en page
// refaite : période commune, chiffres clés en cartes, sections lisibles, crédits et règlements en cartes
// (téléphone) ou en tableau (tablette). Chargé à l'ouverture sur « Aujourd'hui ».
import 'package:flutter/material.dart';

import '../../donnees/rapport_activite_donnees.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'periode.dart';

class RapportActiviteNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const RapportActiviteNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<RapportActiviteNouveau> createState() => _RapportActiviteNouveauState();
}

class _RapportActiviteNouveauState extends State<RapportActiviteNouveau> with ChargementSuivi<RapportActiviteNouveau, RapportActivite> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() =>
      charger(() => RapportActivite.charger(context, _periode.debut, _periode.fin, onSessionInvalid: sessionInvalide(context)));

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Rapport d\'Activité')),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Préparation du rapport…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final r = donnees;
    if (r == null || r.vide) {
      return const [EtatVide(titre: 'Aucune activité sur la période', texte: 'Choisissez une autre période.', icone: Icons.summarize_outlined)];
    }
    final d = r.dashboard;
    final tablette = MediaQuery.sizeOf(context).width >= largeurTableau;
    return [
      if (d != null) ...[
        GrilleKpi([
          ChiffreCle(libelle: 'Montant Total TTC', valeur: formaterMontant(d.montantTtc), id: 'ttc', enAvant: true),
          ChiffreCle(
              libelle: 'Marge brute',
              valeur: formaterMontant(d.marge),
              id: 'marge',
              detail: d.montantTtc == 0 ? null : '${(d.marge * 100 / d.montantTtc).toStringAsFixed(1).replaceAll('.', ',')} % du TTC'),
          ChiffreCle(libelle: 'Montant Crédit', valeur: formaterMontant(d.montantCredit), id: 'credit'),
          ChiffreCle(libelle: 'Montant Réglé', valeur: formaterMontant(d.montantRegle), id: 'regle'),
        ]),
        const SizedBox(height: 12),
        CarteSection(titre: 'Vue d\'ensemble', icone: Icons.summarize_outlined, enfants: [
          LigneDetail('Montant Total HT', formaterMontant(d.montantHt)),
          LigneDetail('Montant Total TVA', formaterMontant(d.montantTVA)),
          LigneDetail('Ratio', d.ratio.toStringAsFixed(2)),
        ]),
        if (d.reglements.isNotEmpty)
          CarteSection(titre: 'Détail des règlements', icone: Icons.payments_outlined, enfants: [
            for (final x in d.reglements) LigneDetail(x.libelle, formaterMontant(x.montant)),
          ]),
        if (d.achats.isNotEmpty)
          CarteSection(titre: 'Achats', icone: Icons.local_shipping_outlined, enfants: [
            for (final a in d.achats) LigneDetail(a.libelleGroupeGrossiste, formaterMontant(a.montantTTC)),
          ]),
        if (d.mvtsCaisse.isNotEmpty)
          CarteSection(titre: 'Mouvements de caisse', icone: Icons.point_of_sale_outlined, enfants: [
            for (final m in d.mvtsCaisse) LigneDetail('${m['libelle']}', formaterMontant(m['montant'] is num ? m['montant'] as num : null)),
          ]),
      ],
      if (r.credits.isNotEmpty) ...[
        const TitreSection('Crédits accordés'),
        ListeOuTableau(
          nombre: r.credits.length,
          colonnes: const [Colonne('Tiers payant', flex: 4), Colonne('Type', flex: 3), Colonne('Montant', flex: 2, droite: true)],
          cellules: (i) => [r.credits[i].tiersPayant, r.credits[i].typeTiersPayant, formaterMontant(r.credits[i].montant)],
          total: r.creditTotals == null
              ? null
              : ['Total : ${r.creditTotals!.totalClients} clients · ${r.creditTotals!.totalBons} bons', '', formaterMontant(r.creditTotals!.totalMontant)],
          carte: (i) => CarteLigne(
            titre: r.credits[i].tiersPayant,
            lignes: [r.credits[i].typeTiersPayant],
            valeur: formaterMontant(r.credits[i].montant),
          ),
        ),
        if (r.creditTotals != null && !tablette)
          CarteSection(titre: 'Total des crédits', enfants: [
            LigneDetail('Nombre total de clients', '${r.creditTotals!.totalClients}'),
            LigneDetail('Nombre total de bons', '${r.creditTotals!.totalBons}'),
            LigneDetail('Montant total des crédits', formaterMontant(r.creditTotals!.totalMontant), gras: true, couleur: Charte.navy),
          ]),
      ],
      if (r.reglements.isNotEmpty) ...[
        const TitreSection('Règlements reçus'),
        ListeOuTableau(
          nombre: r.reglements.length,
          colonnes: const [Colonne('Description', flex: 4), Colonne('Référence', flex: 3), Colonne('Montant', flex: 2, droite: true)],
          cellules: (i) => [r.reglements[i].description, r.reglements[i].reference, formaterMontant(r.reglements[i].montant)],
          carte: (i) => CarteLigne(
            titre: r.reglements[i].description,
            lignes: [if (r.reglements[i].reference.isNotEmpty) 'Réf. ${r.reglements[i].reference}'],
            valeur: formaterMontant(r.reglements[i].montant),
          ),
        ),
      ],
    ];
  }
}
