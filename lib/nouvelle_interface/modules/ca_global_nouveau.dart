// lib/nouvelle_interface/modules/ca_global_nouveau.dart
// CA Global de la nouvelle interface. Mêmes données et mêmes calculs que l'écran d'origine (CaGlobalDonnees,
// lib/donnees/analyses_ventes_donnees.dart) : GET /ca-all?dtStart=&dtEnd= → une ligne par jour triée par date, cumul
// de la période, CA brut = espèces + crédit + mobile money + carte + chèque + virement, CA net = brut − remise.
// Mise en page refaite : période commune chargée dès l'ouverture (« Aujourd'hui », dates par défaut d'origine),
// chiffres clés (brut, net, remise, TVA), répartition par mode de paiement avec la part du CA brut, jour par jour
// (cartes sur téléphone, tableau avec total sur tablette), détail d'un jour en feuille.
// 3.10.0 : sous « Total Mobile Money », le montant de chaque opérateur (Orange Money, Wave, MTN…) quand le serveur
// le donne dans /ca-all (« detailMobile », serveurs récents, demande 25) ; rien de plus sinon (aucun appel en plus).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../donnees/analyses_ventes_donnees.dart';
import '../../models/ca_global_model.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'commun_lot3.dart';
import 'periode.dart';

class CaGlobalNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const CaGlobalNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<CaGlobalNouveau> createState() => _CaGlobalNouveauState();
}

class _CaGlobalNouveauState extends State<CaGlobalNouveau> with ChargementSuivi<CaGlobalNouveau, List<CaGlobal>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() => charger(() async =>
      await CaGlobalDonnees.charger(context, _periode.debut, _periode.fin, onSessionInvalid: sessionInvalide(context)) ?? const <CaGlobal>[]);

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  static String _date(CaGlobal c) => c.mvtDate == null ? 'N/A' : DateFormat('dd/MM/yyyy').format(c.mvtDate!);

  static String _part(double v, double total) => total == 0 ? '' : formaterPourcent(v / total * 100);

  /// Lignes « mode … montant » (libellés de l'écran d'origine) et totaux.
  static List<Widget> _lignes(CaGlobal c) => [
        for (final (libelle, v) in CaGlobalDonnees.modes(c)) LigneDetail(libelle, formaterMontant(v)),
        const Divider(height: 16),
        LigneDetail('TOTAL CA BRUT', formaterMontant(c.totalCa), gras: true),
        LigneDetail('Remise sur CA', formaterMontant(c.remiseSurCA)),
        LigneDetail('Total TVA', formaterMontant(c.totTVA)),
        LigneDetail('TOTAL CA NET', formaterMontant(CaGlobalDonnees.net(c)), gras: true, couleur: Charte.vertTexte),
      ];

  void _detail(CaGlobal c) => ouvrirFeuilleDetail(context, titre: _date(c), sousTitre: 'Chiffre d\'affaires du jour', lignes: _lignes(c));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('CA Global')),
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
    if (enCours) return const [EtatChargement(texte: 'Chargement du chiffre d\'affaires…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <CaGlobal>[];
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucune donnée pour cette période', texte: 'Choisissez une autre période.', icone: Icons.receipt_long_outlined)];
    }
    final c = CaGlobalDonnees.cumul(l);
    final operateurs = CaGlobalDonnees.detailMobile(l);
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'CA brut', valeur: formaterMontant(c.totalCa), id: 'brut', enAvant: true, detail: '${l.length} jour${l.length > 1 ? 's' : ''}'),
        ChiffreCle(libelle: 'CA net', valeur: formaterMontant(CaGlobalDonnees.net(c)), id: 'net', detail: 'brut − remise'),
        ChiffreCle(libelle: 'Remise sur CA', valeur: formaterMontant(c.remiseSurCA), id: 'remise'),
        ChiffreCle(libelle: 'Total TVA', valeur: formaterMontant(c.totTVA), id: 'tva'),
      ]),
      const TitreSection('Par mode de paiement'),
      CarteSection(enfants: [
        for (final (libelle, v) in CaGlobalDonnees.modes(c))
          Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                LigneDetail(libelle, formaterMontant(v)),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: c.totalCa == 0 ? 0 : (v / c.totalCa).clamp(0, 1), minHeight: 6, color: Charte.navy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_part(v, c.totalCa), style: const TextStyle(color: Charte.grisTexte, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ]),
                // Opérateurs Mobile Money (« dont Orange Money … »), si le serveur les donne.
                if (libelle == 'Total Mobile Money' && operateurs != null && operateurs.isNotEmpty)
                  Padding(
                    key: const Key('ca_global_mobile_detail'),
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final o in operateurs) LigneDetail('dont ${o.libelle}', formaterMontant(o.montant)),
                    ]),
                  ),
              ]),
            ),
        const Divider(height: 16),
        LigneDetail('TOTAL CA BRUT', formaterMontant(c.totalCa), gras: true),
        LigneDetail('Remise sur CA', formaterMontant(c.remiseSurCA)),
        LigneDetail('Total TVA', formaterMontant(c.totTVA)),
        LigneDetail('TOTAL CA NET', formaterMontant(CaGlobalDonnees.net(c)), gras: true, couleur: Charte.vertTexte),
      ]),
      if (l.length > 1) ...[
        const TitreSection('Jour par jour'),
        ListeOuTableau(
          nombre: l.length,
          onTap: (i) => _detail(l[i]),
          colonnes: const [
            Colonne('Date', flex: 2),
            Colonne('Espèces', flex: 3, droite: true),
            Colonne('Crédit', flex: 3, droite: true),
            Colonne('Mobile money', flex: 3, droite: true),
            Colonne('Total CA', flex: 3, droite: true),
          ],
          cellules: (i) => [_date(l[i]), formaterMontant(l[i].totEsp), formaterMontant(l[i].montantCredit), formaterMontant(l[i].totMobile), formaterMontant(l[i].totalCa)],
          total: ['Total', formaterMontant(c.totEsp), formaterMontant(c.montantCredit), formaterMontant(c.totMobile), formaterMontant(c.totalCa)],
          carte: (i) => CarteLigne(
            titre: _date(l[i]),
            lignes: ['Espèces ${formaterMontant(l[i].totEsp)} · Crédit ${formaterMontant(l[i].montantCredit)}'],
            libelleValeur: 'Total CA',
            valeur: formaterMontant(l[i].totalCa),
            onTap: () => _detail(l[i]),
          ),
        ),
      ],
    ];
  }
}
