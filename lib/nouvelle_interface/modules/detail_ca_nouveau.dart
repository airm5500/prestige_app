// lib/nouvelle_interface/modules/detail_ca_nouveau.dart
// Détail CA de la nouvelle interface. Mêmes données et mêmes calculs que l'écran d'origine (DetailCa : GET /ca-all
// avec dtStart / dtEnd, cumul de la période, répartition par mode de paiement), mise en page refaite : période
// commune, chiffres clés, répartition en barres (pourcentages identiques au camembert d'origine), totaux de la
// période, puis jour par jour en cartes (téléphone) ou en tableau (tablette). Chargé à l'ouverture.
import 'package:flutter/material.dart';

import '../../donnees/detail_ca_donnees.dart';
import '../../models/ca_comptant_model.dart';
import '../../utils/date_formatter.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'periode.dart';

class DetailCaNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const DetailCaNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<DetailCaNouveau> createState() => _DetailCaNouveauState();
}

class _DetailCaNouveauState extends State<DetailCaNouveau> with ChargementSuivi<DetailCaNouveau, List<CaComptant>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());

  /// Couleurs des modes de paiement (charte : bleu nuit, ambre, vert, bleu, gris, rouge).
  static const _couleurs = [Charte.navy, Charte.ambre, Charte.vert, Charte.bleu, Charte.grisTexte, Charte.rouge];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() => charger(() => DetailCa.charger(context, _periode.debut, _periode.fin, onSessionInvalid: sessionInvalide(context)));

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Détail CA')),
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
    if (enCours) return const [EtatChargement(texte: 'Calcul du chiffre d\'affaires…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final lignes = donnees ?? const <CaComptant>[];
    if (lignes.isEmpty) {
      return const [EtatVide(titre: 'Aucun CA trouvé pour la période', texte: 'Choisissez une autre période.', icone: Icons.payments_outlined)];
    }
    final t = DetailCa.cumul(lignes);
    final repartition = DetailCa.repartition(t);
    String date(CaComptant c) => c.mvtDate == null ? '—' : DateFormatter.toDisplayFormat(c.mvtDate!).replaceAll('-', '/');
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Total brut paiements', valeur: formaterMontant(t.totalPaiements), id: 'total', enAvant: true),
        ChiffreCle(libelle: 'Espèces', valeur: formaterMontant(t.totEsp), id: 'especes'),
        ChiffreCle(libelle: 'Crédit', valeur: formaterMontant(t.montantCredit), id: 'credit'),
        ChiffreCle(libelle: 'Mobile Money', valeur: formaterMontant(t.totMobile), id: 'mobile'),
      ]),
      const SizedBox(height: 12),
      CarteSection(titre: 'Répartition par mode de paiement', icone: Icons.donut_small_outlined, enfants: [
        if (repartition.isEmpty)
          const Text('Aucun encaissement sur la période.', style: TextStyle(color: Charte.gris))
        else
          for (var i = 0; i < repartition.length; i++) _BarreRepartition(repartition[i], _couleurs[i % _couleurs.length]),
      ]),
      CarteSection(titre: 'Totaux sur la période', icone: Icons.functions, enfants: [
        LigneDetail('Total Espèces', formaterMontant(t.totEsp)),
        LigneDetail('Total Crédit', formaterMontant(t.montantCredit)),
        LigneDetail('Total Mobile Money', formaterMontant(t.totMobile)),
        LigneDetail('Total Carte Bancaire', formaterMontant(t.totCB)),
        LigneDetail('Total Chèque', formaterMontant(t.totChq)),
        LigneDetail('Total Virement', formaterMontant(t.totVirement)),
        const Divider(height: 14),
        LigneDetail('TOTAL BRUT PAIEMENTS', formaterMontant(t.totalPaiements), gras: true, couleur: Charte.navy),
        LigneDetail('Remise sur CA', formaterMontant(t.remiseSurCA)),
        LigneDetail('Total TVA', formaterMontant(t.totTVA)),
      ]),
      const TitreSection('Jour par jour'),
      ListeOuTableau(
        nombre: lignes.length,
        colonnes: const [
          Colonne('Date', flex: 2),
          Colonne('Espèces', flex: 2, droite: true),
          Colonne('Crédit', flex: 2, droite: true),
          Colonne('Mobile', flex: 2, droite: true),
          Colonne('Carte B.', flex: 2, droite: true),
          Colonne('Total', flex: 2, droite: true),
        ],
        cellules: (i) {
          final c = lignes[i];
          return [date(c), formaterMontant(c.totEsp), formaterMontant(c.montantCredit), formaterMontant(c.totMobile), formaterMontant(c.totCB),
            formaterMontant(c.totalPaiements)];
        },
        carte: (i) {
          final c = lignes[i];
          return CarteLigne(
            titre: date(c),
            lignes: [
              'Espèces ${formaterMontant(c.totEsp)} · Crédit ${formaterMontant(c.montantCredit)}',
              'Mobile ${formaterMontant(c.totMobile)} · Carte ${formaterMontant(c.totCB)}',
            ],
            libelleValeur: 'Total',
            valeur: formaterMontant(c.totalPaiements),
          );
        },
      ),
    ];
  }
}

/// Mode de paiement : libellé, montant, pourcentage (même calcul que le camembert d'origine) et barre.
class _BarreRepartition extends StatelessWidget {
  final (String, double, double) mode;
  final Color couleur;
  const _BarreRepartition(this.mode, this.couleur);

  @override
  Widget build(BuildContext context) {
    final (libelle, montant, pourcent) = mode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(libelle, style: const TextStyle(fontWeight: FontWeight.w600, color: Charte.encre))),
          Text('${pourcent.toStringAsFixed(1)}%', style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text(formaterMontant(montant), style: const TextStyle(fontWeight: FontWeight.bold, color: Charte.encre)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pourcent / 100, minHeight: 8, color: couleur, backgroundColor: Charte.grisClair),
        ),
      ]),
    );
  }
}
