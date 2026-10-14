// lib/nouvelle_interface/modules/recap_caisse_nouveau.dart
// Récap de caisse (ticket Z) de la nouvelle interface. Mêmes données que l'écran d'origine (RecapCaisse,
// lib/donnees/recap_caisse_donnees.dart) : caissiers GET /common/users?limit=9999, récapitulatif
// POST /caisse/fetch-tickez {description: ALL, dtStart, dtEnd, hrStart, hrEnd, userId}. Les montants sont ceux du
// serveur, affichés tels quels (aucun recalcul). Mise en page refaite : période commune chargée dès l'ouverture
// (« Aujourd'hui », 00:00 → 23:59, tous les caissiers : valeurs par défaut d'origine), caissier et heures dans la
// feuille des filtres, chiffres clés, totaux globaux (carte sur téléphone, tableau dense sur tablette), une carte par
// caissier (deux colonnes sur tablette). Aucun export à l'origine : pas de menu « Exporter ».
import 'package:flutter/material.dart';

import '../../donnees/recap_caisse_donnees.dart';
import '../../models/common_data_model.dart';
import '../../models/ticket_z_model.dart';
import '../charte.dart';
import '../composants.dart';
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixListe;
import 'commun.dart';
import 'commun_lot2.dart';
import 'periode.dart';

class RecapCaisseNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const RecapCaisseNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<RecapCaisseNouveau> createState() => _RecapCaisseNouveauState();
}

class _RecapCaisseNouveauState extends State<RecapCaisseNouveau> with ChargementSuivi<RecapCaisseNouveau, TicketZResponse> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  TimeOfDay _heureDebut = RecapCaisse.heureDebutDefaut;
  TimeOfDay _heureFin = RecapCaisse.heureFinDefaut;
  String _caissier = RecapCaisse.tous;

  List<CommonData>? _caissiers;
  Object? _erreurCaissiers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chargerCaissiers();
      _charger();
    });
  }

  Future<void> _chargerCaissiers() async {
    setState(() => _erreurCaissiers = null);
    try {
      final c = await RecapCaisse.caissiers(context);
      if (mounted) setState(() => _caissiers = c);
    } catch (e) {
      if (mounted) setState(() => _erreurCaissiers = e);
    }
  }

  Future<void> _charger() => charger(() => RecapCaisse.charger(
      context,
      RecapCaisse.corps(debut: _periode.debut, fin: _periode.fin, heureDebut: _heureDebut, heureFin: _heureFin, userId: _caissier)));

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  static bool _memeHeure(TimeOfDay a, TimeOfDay b) => a.hour == b.hour && a.minute == b.minute;

  bool get _heuresParDefaut => _memeHeure(_heureDebut, RecapCaisse.heureDebutDefaut) && _memeHeure(_heureFin, RecapCaisse.heureFinDefaut);

  int get _actifs => (_caissier == RecapCaisse.tous ? 0 : 1) + (_heuresParDefaut ? 0 : 1);

  String get _nomCaissier =>
      _caissiers?.where((c) => c.id == _caissier).map((c) => c.libelle).firstOrNull ?? _caissier;

  /// Sur une seule journée, l'heure de début doit précéder l'heure de fin.
  String? _erreurHeures(TimeOfDay debut, TimeOfDay fin) =>
      _periode.nombreJours == 1 && debut.hour * 60 + debut.minute > fin.hour * 60 + fin.minute
          ? 'Sur une journée, l\'heure de début doit précéder l\'heure de fin.'
          : null;

  Future<TimeOfDay?> _choisirHeure(BuildContext ctx, TimeOfDay initiale, String aide) => showTimePicker(
        context: ctx,
        initialTime: initiale,
        helpText: aide,
        confirmText: 'Valider',
        cancelText: 'Annuler',
        builder: (c, enfant) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: enfant!),
      );

  Future<void> _filtres() async {
    if (_caissiers == null && _erreurCaissiers != null) _chargerCaissiers();
    var caissier = _caissier == RecapCaisse.tous ? '' : _caissier;
    var debut = _heureDebut, fin = _heureFin;
    String? refus;
    StateSetter? maj;
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer le récapitulatif',
      effacer: () {
        caissier = '';
        debut = RecapCaisse.heureDebutDefaut;
        fin = RecapCaisse.heureFinDefaut;
        refus = null;
      },
      valider: () {
        final e = _erreurHeures(debut, fin);
        maj?.call(() => refus = e);
        return e == null;
      },
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Builder(builder: (_) {
          maj = setState;
          return const SizedBox.shrink();
        }),
        ChoixListe(
          key: const Key('filtre_caissier'),
          libelle: 'Caissier',
          icone: Icons.person_outline,
          options: _caissiers == null ? null : [for (final c in _caissiers!) OptionListe(c.id, c.libelle)],
          erreur: _erreurCaissiers,
          valeur: caissier,
          tous: RecapCaisse.libelleTous,
          onChanged: (v) => setState(() => caissier = v),
        ),
        const SizedBox(height: 14),
        const Text('Heures', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('filtre_heure_debut'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.schedule),
              label: Text('De ${RecapCaisse.heure(debut)}'),
              onPressed: () async {
                final h = await _choisirHeure(ctx, debut, 'Heure de début');
                if (h != null) setState(() => debut = h);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('filtre_heure_fin'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.schedule),
              label: Text('À ${RecapCaisse.heure(fin)}'),
              onPressed: () async {
                final h = await _choisirHeure(ctx, fin, 'Heure de fin');
                if (h != null) setState(() => fin = h);
              },
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          refus ?? 'Par défaut : toute la journée (00:00 → 23:59).',
          key: const Key('filtre_heures_aide'),
          style: TextStyle(color: refus == null ? Charte.gris : Charte.rougeTexte, fontSize: 13, fontWeight: refus == null ? FontWeight.normal : FontWeight.bold),
        ),
      ]),
    );
    if (!applique || !mounted) return;
    setState(() {
      _caissier = caissier.isEmpty ? RecapCaisse.tous : caissier;
      _heureDebut = debut;
      _heureFin = fin;
    });
    _charger();
  }

  void _retirerFiltres() {
    setState(() {
      _caissier = RecapCaisse.tous;
      _heureDebut = RecapCaisse.heureDebutDefaut;
      _heureFin = RecapCaisse.heureFinDefaut;
    });
    _charger();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Récap de caisse'), actions: [
          BoutonFiltres(actifs: _actifs, onPressed: _filtres),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            EtiquettesFiltres(etiquettes: [
              if (_caissier != RecapCaisse.tous) 'Caissier : $_nomCaissier',
              if (!_heuresParDefaut) 'De ${RecapCaisse.heure(_heureDebut)} à ${RecapCaisse.heure(_heureFin)}',
            ], onRetirer: _retirerFiltres),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  /// « 125 000 F » à partir du montant déjà formaté par le serveur.
  static String _montant(String m) => m.trim().isEmpty ? '—' : '${m.trim()} F';

  static Widget _ligne(TicketZAmount a, {bool gras = false}) {
    final vnoVo = RecapCaisse.estTotalVnoVo(a.modeLibelle);
    return LigneDetail(a.modeLibelle, _montant(a.montant),
        gras: gras || vnoVo, couleur: RecapCaisse.estNegatif(a.montant) ? Charte.rougeTexte : (vnoVo ? Charte.navy : null));
  }

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement du récapitulatif de caisse…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final r = donnees;
    if (r == null || RecapCaisse.estVide(r)) {
      return const [EtatVide(titre: 'Aucune donnée pour cette période', texte: 'Choisissez une autre période ou un autre caissier.', icone: Icons.point_of_sale_outlined)];
    }
    final especes = RecapCaisse.totalGlobal(r, 'TOTAL ESP');
    final vnoVo = r.totauxGlobaux.where((t) => RecapCaisse.estTotalVnoVo(t.modeLibelle)).map((t) => t.montant).firstOrNull;
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Caissiers', valeur: formaterNombre(r.datas.length), id: 'caissiers'),
        ChiffreCle(libelle: 'Espèces', valeur: especes == null ? '—' : _montant(especes), id: 'especes', enAvant: true),
        if (vnoVo != null) ChiffreCle(libelle: 'Total (VNO/VO)', valeur: _montant(vnoVo), id: 'vno_vo'),
        ChiffreCle(libelle: 'Totaux globaux', valeur: formaterNombre(r.totauxGlobaux.length), id: 'totaux', detail: 'modes et totaux'),
      ]),
      if (r.totauxGlobaux.isNotEmpty) ...[
        const TitreSection('Totaux globaux'),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= largeurTableau
              ? TableauDense(
                  colonnes: const [Colonne('Mode ou total', flex: 4), Colonne('Montant', flex: 2, droite: true)],
                  lignes: [for (final t in r.totauxGlobaux) [t.modeLibelle, _montant(t.montant)]],
                )
              : CarteSection(
                  key: const Key('totaux_globaux'),
                  titre: 'Tous les caissiers',
                  icone: Icons.account_balance_wallet_outlined,
                  enfants: [for (final t in r.totauxGlobaux) _ligne(t)],
                ),
        ),
      ],
      if (r.datas.isNotEmpty) ...[
        const TitreSection('Par caissier'),
        LayoutBuilder(builder: (context, c) {
          final deux = c.maxWidth >= largeurTableau;
          final largeur = deux ? (c.maxWidth - 12) / 2 : c.maxWidth;
          return Wrap(spacing: 12, children: [
            for (final u in r.datas) SizedBox(width: largeur, child: _carteCaissier(u)),
          ]);
        }),
      ],
    ];
  }

  Widget _carteCaissier(TicketZUserData u) => CarteSection(
        key: Key('caissier_${u.user}'),
        titre: u.user,
        icone: Icons.person_outline,
        enfants: [
          for (final a in u.modePaymentAmounts) _ligne(a),
          if (u.totaux.isNotEmpty) ...[
            const Divider(height: 16),
            for (final a in u.totaux) _ligne(a, gras: true),
          ],
          if (u.modePaymentAmounts.isEmpty && u.totaux.isEmpty)
            const Text('Aucun encaissement.', style: TextStyle(color: Charte.gris)),
        ],
      );
}
