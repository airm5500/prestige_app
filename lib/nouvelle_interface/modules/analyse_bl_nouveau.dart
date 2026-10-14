// lib/nouvelle_interface/modules/analyse_bl_nouveau.dart
// Analyse des Saisies BL de la nouvelle interface. Mêmes données que l'écran d'origine (AnalyseSaisiesBl,
// lib/donnees/analyse_bl_donnees.dart) : GET /etat-control-bon/list?dtStart=&dtEnd=&limit=9999, délai de saisie et
// statut « Bon » (≤ 1 jour) / « Pas bon », filtre local par statut. Mise en page refaite : période commune (chargée
// à l'ouverture sur « Aujourd'hui »), statut dans la feuille du bas (aucune nouvelle requête), chiffres clés, BL en
// cartes (téléphone) ou tableau (tablette).
import 'package:flutter/material.dart';

import '../../donnees/analyse_bl_donnees.dart';
import '../../models/bon_livraison_stat_model.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'commun_lot2.dart';
import 'periode.dart';

class AnalyseBlNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const AnalyseBlNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<AnalyseBlNouveau> createState() => _AnalyseBlNouveauState();
}

class _AnalyseBlNouveauState extends State<AnalyseBlNouveau> with ChargementSuivi<AnalyseBlNouveau, List<BonLivraisonStat>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  String _statut = 'Tous';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() => charger(() async =>
      await AnalyseSaisiesBl.charger(context, _periode.debut, _periode.fin, onSessionInvalid: sessionInvalide(context)) ?? const <BonLivraisonStat>[]);

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  Future<void> _filtres() async {
    var statut = _statut;
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les BL',
      effacer: () => statut = 'Tous',
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Statut de la saisie', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Bon : saisi au plus 1 jour après la livraison. Pas bon : plus d\'un jour.', style: TextStyle(color: Charte.grisTexte, fontSize: 13)),
        const SizedBox(height: 8),
        PucesChoix<String>(
          choix: [for (final s in statutsSaisieBl) (s, s)],
          valeur: statut,
          cle: (v, _) => Key('filtre_statut_${v.replaceAll(' ', '_')}'),
          onChanged: (v) => setState(() => statut = v),
        ),
      ]),
    );
    if (applique && mounted) setState(() => _statut = statut);
  }

  static Ton _ton(String statut) => switch (statut) {
        'Bon' => Ton.vert,
        'Pas bon' => Ton.rouge,
        _ => Ton.gris,
      };

  static String _delai(BonLivraisonStat b) => b.delayInDays != null ? '${b.delayInDays} jour(s)' : 'N/A';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Analyse des Saisies BL'), actions: [BoutonFiltres(actifs: _statut == 'Tous' ? 0 : 1, onPressed: _filtres)]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            EtiquettesFiltres(etiquettes: [if (_statut != 'Tous') 'Statut : $_statut'], onRetirer: () => setState(() => _statut = 'Tous')),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Analyse des saisies…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final tout = donnees ?? const <BonLivraisonStat>[];
    if (tout.isEmpty) {
      return const [EtatVide(titre: 'Aucune donnée trouvée', texte: 'Aucun BL saisi sur la période.', icone: Icons.document_scanner_outlined)];
    }
    final l = AnalyseSaisiesBl.filtrer(tout, _statut);
    final bons = tout.where((b) => b.status == 'Bon').length;
    final pasBons = tout.where((b) => b.status == 'Pas bon').length;
    final moyen = AnalyseSaisiesBl.delaiMoyen(tout);
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Nombre de BL affichés', valeur: formaterNombre(l.length), id: 'affiches', enAvant: true, detail: 'sur ${formaterNombre(tout.length)}'),
        ChiffreCle(libelle: 'Bon (≤ 1 jour)', valeur: formaterNombre(bons), id: 'bons'),
        ChiffreCle(libelle: 'Pas bon (> 1 jour)', valeur: formaterNombre(pasBons), id: 'pas_bons'),
        ChiffreCle(
            libelle: 'Délai moyen de saisie',
            valeur: moyen == null ? 'N/A' : '${moyen.toStringAsFixed(1).replaceAll('.', ',')} j',
            id: 'delai_moyen'),
      ]),
      const TitreSection('Bons de livraison'),
      if (l.isEmpty)
        const EtatVide(titre: 'Aucun BL ne correspond à ce filtre.', texte: 'Modifiez ou retirez le filtre.', icone: Icons.filter_alt_off_outlined)
      else
        ListeOuTableau(
          nombre: l.length,
          colonnes: const [Colonne('Référence', flex: 3), Colonne('Fournisseur', flex: 4), Colonne('Délai', flex: 2, droite: true), Colonne('Statut', flex: 2)],
          cellules: (i) => [l[i].refLivraison, l[i].fournisseur, _delai(l[i]), l[i].status],
          carte: (i) => CarteLigne(
            titre: l[i].refLivraison,
            bande: l[i].status == 'Pas bon' ? Charte.rouge : null,
            etiquette: Etiquette(l[i].status, ton: _ton(l[i].status)),
            lignes: [l[i].fournisseur],
            libelleValeur: 'Délai',
            valeur: _delai(l[i]),
          ),
        ),
    ];
  }
}
