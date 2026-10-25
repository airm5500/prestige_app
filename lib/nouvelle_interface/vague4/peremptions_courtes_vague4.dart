// lib/nouvelle_interface/vague4/peremptions_courtes_vague4.dart
// 3.15.0 (décision du pharmacien) — menu « Péremptions courtes » (web : GESTION DES COMMANDES > Péremptions courtes,
// demande mobile 36 D12, serveur 99a13f57), administrateur et pharmacien. Lots à péremption courte ACCEPTÉS ou REFUSÉS
// à la réception des BL (journal rempli par l'application de réception) :
//  - GET /reception/peremptions-courtes?du=&au=[&grossiste=][&statut=] (mêmes filtres que le web : période, ce mois
//    par défaut ; grossiste ; statut) → {total, valeur, data: [{id, bl, cip, produit, grossiste, numLot,
//    datePeremption, joursRestants, quantite, valeur (= quantité × PAF, calculée par le serveur), decision, motif,
//    statut, utilisateur, le}]} ;
//  - Exporter : Excel (GET …/excel) et PDF (GET …/pdf) du web, mêmes filtres ; Partager / Ouvrir ;
//  - statut de traitement (À traiter / Réclamé / Avoir reçu) : PUT …/{id}/statut?statut= — le SERVEUR vérifie le droit
//    (P_BL_MOBILE_ACCEPTER_PEREMPTION_COURTE) ; refus → message « Droit manquant », le statut ne change pas et le
//    changement n'est plus proposé sur cet écran ;
//  - serveur sans ces routes (404) : « Indisponible sur ce serveur » (liste) ou « Export indisponible » (fichiers).
// Rien n'est gardé sur l'appareil (ni préférence, ni cache) ; le journal de l'application ne note que le chemin.
import 'package:flutter/material.dart';

import '../../presences/export_fichier.dart';
import '../../services/api_service.dart';
import '../../utils/date_formatter.dart';
import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/commun_lot2.dart' show messageResultat;
import '../modules/periode.dart';
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixListe;
import '../vague2/donnees_vague2.dart' show ApiVague2, grouperMilliers;
import '../vague3/donnees_vague3.dart' show ApiVague3, entierTolerant, texteTolerant;

// ---------------------------------------------------------------------------------------------------------------
// Données
// ---------------------------------------------------------------------------------------------------------------

enum StatutPeremptionCourte {
  aTraiter('A_TRAITER', 'À traiter', Ton.ambre),
  reclame('RECLAME', 'Réclamé', Ton.bleu),
  avoirRecu('AVOIR_RECU', 'Avoir reçu', Ton.vert);

  final String code;
  final String libelle;
  final Ton ton;
  const StatutPeremptionCourte(this.code, this.libelle, this.ton);

  /// Code du serveur → statut (inconnu ou vide : null).
  static StatutPeremptionCourte? depuis(String code) {
    final c = code.trim().toUpperCase();
    for (final s in values) {
      if (s.code == c) return s;
    }
    return null;
  }
}

/// Une péremption courte de la réception (données du serveur, gardées le temps de l'écran seulement).
class PeremptionCourte {
  final String id;
  final String bl;
  final String cip;
  final String produit;
  final String grossiste;
  final String numLot;
  final String datePeremption;
  final int joursRestants;
  final int quantite;
  final int valeur;
  final bool acceptee;
  final String motif;
  final String statut;
  final String utilisateur;
  final String le;
  const PeremptionCourte({
    required this.id,
    this.bl = '',
    this.cip = '',
    this.produit = '',
    this.grossiste = '',
    this.numLot = '',
    this.datePeremption = '',
    this.joursRestants = 0,
    this.quantite = 0,
    this.valeur = 0,
    this.acceptee = false,
    this.motif = '',
    this.statut = '',
    this.utilisateur = '',
    this.le = '',
  });

  factory PeremptionCourte.depuis(Map<String, dynamic> j) => PeremptionCourte(
        id: texteTolerant(j['id']),
        bl: texteTolerant(j['bl']),
        cip: texteTolerant(j['cip']),
        produit: texteTolerant(j['produit']),
        grossiste: texteTolerant(j['grossiste']),
        numLot: texteTolerant(j['numLot']),
        datePeremption: texteTolerant(j['datePeremption']),
        joursRestants: entierTolerant(j['joursRestants']),
        quantite: entierTolerant(j['quantite']),
        valeur: entierTolerant(j['valeur']),
        acceptee: texteTolerant(j['decision']).toUpperCase() == 'ACCEPTE',
        motif: texteTolerant(j['motif']),
        statut: texteTolerant(j['statut']),
        utilisateur: texteTolerant(j['utilisateur']),
        le: texteTolerant(j['le']),
      );

  StatutPeremptionCourte? get statutConnu => StatutPeremptionCourte.depuis(statut);

  PeremptionCourte avecStatut(StatutPeremptionCourte s) => PeremptionCourte(
      id: id, bl: bl, cip: cip, produit: produit, grossiste: grossiste, numLot: numLot, datePeremption: datePeremption,
      joursRestants: joursRestants, quantite: quantite, valeur: valeur, acceptee: acceptee, motif: motif, statut: s.code,
      utilisateur: utilisateur, le: le);

  /// « 2026-10-19… » → « 19/10/2026 » (autre format rendu tel quel).
  static String date(String v) => v.length >= 10 && v[4] == '-' && v[7] == '-' ? '${v.substring(8, 10)}/${v.substring(5, 7)}/${v.substring(0, 4)}' : v;

  /// « 2026-10-19T09:30:00 » → « 09:30 » (vide si absent).
  static String heure(String v) => v.length >= 16 && v[10] == 'T' ? v.substring(11, 16) : '';
}

/// Filtres de la liste (comme le web) : période (ce mois par défaut), grossiste, statut.
class FiltresPeremptionsCourtes {
  final Periode periode;
  final String grossiste;
  final String libelleGrossiste;
  final StatutPeremptionCourte? statut;
  const FiltresPeremptionsCourtes({required this.periode, this.grossiste = '', this.libelleGrossiste = '', this.statut});

  factory FiltresPeremptionsCourtes.defaut(DateTime maintenant) =>
      FiltresPeremptionsCourtes(periode: Periode.rapide(PeriodeRapide.ceMois, maintenant));

  FiltresPeremptionsCourtes copie({Periode? periode, String? grossiste, String? libelleGrossiste, StatutPeremptionCourte? statut, bool sansStatut = false}) =>
      FiltresPeremptionsCourtes(
        periode: periode ?? this.periode,
        grossiste: grossiste ?? this.grossiste,
        libelleGrossiste: libelleGrossiste ?? this.libelleGrossiste,
        statut: sansStatut ? null : (statut ?? this.statut),
      );

  Map<String, String> get parametres => {
        'du': DateFormatter.toApiFormat(periode.debut),
        'au': DateFormatter.toApiFormat(periode.fin),
        if (grossiste.isNotEmpty) 'grossiste': grossiste,
        if (statut != null) 'statut': statut!.code,
      };
}

class ListePeremptionsCourtes {
  final List<PeremptionCourte> lignes;
  final int total;
  final int valeur;
  const ListePeremptionsCourtes(this.lignes, this.total, this.valeur);
}

class ApiPeremptionsCourtes {
  ApiPeremptionsCourtes._();

  static const route = '/reception/peremptions-courtes';
  static const routeExcel = '$route/excel';
  static const routePdf = '$route/pdf';
  static String routeStatut(String id) => '$route/${Uri.encodeComponent(id)}/statut';

  static const consulter = 'consulter les péremptions courtes';
  static const changer = 'changer le statut d\'une péremption courte';

  static Future<ListePeremptionsCourtes> liste(BuildContext context, FiltresPeremptionsCourtes f) async {
    final j = await ApiVague3.get(context, route, f.parametres, consulter);
    return ApiVague3.lire(() {
      final d = j['data'];
      if (d != null && d is! List) throw const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse);
      final l = [
        for (final x in (d as List?) ?? const [])
          if (x is Map) PeremptionCourte.depuis(Map<String, dynamic>.from(x)),
      ];
      // Serveur sans total ou valeur : calculés sur les lignes reçues.
      return ListePeremptionsCourtes(l, j['total'] == null ? l.length : entierTolerant(j['total']),
          j['valeur'] == null ? l.fold<int>(0, (s, x) => s + x.valeur) : entierTolerant(j['valeur']));
    }, 'les péremptions courtes');
  }

  /// Statut de traitement (droit vérifié par le serveur).
  static Future<void> statut(BuildContext context, String id, StatutPeremptionCourte s) async {
    if (id.isEmpty) throw const ApiLoadException('Ligne inconnue.', nature: NatureErreur.refus);
    await ApiVague3.put(context, routeStatut(id), {'statut': s.code}, changer);
  }

  static Future<FichierTelecharge> excel(BuildContext context, FiltresPeremptionsCourtes f) =>
      ApiService().getBytes(context, routeExcel, queryParams: f.parametres, nomParDefaut: 'peremptions_courtes.xlsx');

  static Future<FichierTelecharge> pdf(BuildContext context, FiltresPeremptionsCourtes f) =>
      ApiService().getBytes(context, routePdf, queryParams: f.parametres, nomParDefaut: 'peremptions_courtes.pdf');
}

/// Route absente sur ce serveur (Prestige répond 404).
bool _routeAbsente(Object e) => e is ApiLoadException && e.code == 404 && !e.serveurIndisponible;

// ---------------------------------------------------------------------------------------------------------------
// Écran
// ---------------------------------------------------------------------------------------------------------------

class PeremptionsCourtesScreen extends StatefulWidget {
  final DateTime Function() maintenant;
  const PeremptionsCourtesScreen({super.key, this.maintenant = DateTime.now});

  @override
  State<PeremptionsCourtesScreen> createState() => _PeremptionsCourtesScreenState();
}

class _PeremptionsCourtesScreenState extends State<PeremptionsCourtesScreen> {
  late FiltresPeremptionsCourtes _filtres = FiltresPeremptionsCourtes.defaut(widget.maintenant());
  final _lignes = <PeremptionCourte>[];
  int _total = 0;
  int _valeur = 0;
  bool _enCours = false;
  bool _charge = false;
  Object? _erreur;
  int _generation = 0;
  bool _export = false;

  /// Lignes dont le statut part au serveur (anti double appui).
  final _envois = <String>{};

  /// Le serveur a refusé le changement de statut (droit manquant) : plus proposé sur cet écran.
  String? _droitRefuse;

  List<OptionListe>? _grossistes;
  Object? _erreurGrossistes;
  final _versionOptions = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _versionOptions.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    if (!mounted) return;
    final g = ++_generation;
    final f = _filtres;
    setState(() {
      _enCours = true;
      _erreur = null;
      _lignes.clear();
      _charge = false;
    });
    try {
      final l = await ApiPeremptionsCourtes.liste(context, f);
      if (!mounted || g != _generation) return;
      setState(() {
        _lignes.addAll(l.lignes);
        _total = l.total;
        _valeur = l.valeur;
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

  void _appliquer(FiltresPeremptionsCourtes f) {
    setState(() => _filtres = f);
    _charger();
  }

  Future<void> _chargerGrossistes() async {
    if (_grossistes != null) return;
    _erreurGrossistes = null;
    try {
      _grossistes = await ApiVague2.options(context, ApiVague2.routeGrossistes, 'la liste des grossistes');
    } catch (e) {
      _erreurGrossistes = e;
    }
    if (mounted) _versionOptions.value++;
  }

  Future<void> _ouvrirFiltres() async {
    var grossiste = _filtres.grossiste;
    _chargerGrossistes();
    final ok = await ouvrirFeuilleFiltres(
      context,
      titre: 'Critères des péremptions courtes',
      effacer: () => grossiste = '',
      contenu: (ctx, setState) => ValueListenableBuilder<int>(
        valueListenable: _versionOptions,
        builder: (_, __, ___) => ChoixListe(
          key: const Key('pc_filtre_grossiste'),
          libelle: 'Grossiste',
          icone: Icons.local_shipping_outlined,
          options: _grossistes,
          erreur: _erreurGrossistes,
          valeur: grossiste,
          tous: 'Tous les grossistes',
          onChanged: (v) => setState(() => grossiste = v),
        ),
      ),
    );
    if (!ok || !mounted) return;
    final libelle = grossiste.isEmpty ? '' : (_grossistes?.where((o) => o.id == grossiste).firstOrNull?.libelle ?? '');
    _appliquer(_filtres.copie(grossiste: grossiste, libelleGrossiste: libelle));
  }

  Future<void> _exporter(bool pdf) async {
    if (_export) return;
    setState(() => _export = true);
    try {
      final lecture = pdf ? ApiPeremptionsCourtes.pdf(context, _filtres) : ApiPeremptionsCourtes.excel(context, _filtres);
      final f = await lecture;
      if (!mounted) return;
      await ExportFichier.proposer(context, f, sujet: 'Péremptions courtes ${_filtres.periode.resume}');
    } catch (e) {
      if (!mounted) return;
      messageResultat(
          context, _routeAbsente(e) ? 'Export indisponible sur ce serveur (mise à jour de Prestige nécessaire).' : 'Export impossible : ${DiagnosticErreur.de(e).message}',
          echec: true);
    } finally {
      if (mounted) setState(() => _export = false);
    }
  }

  Future<void> _changerStatut(int i) async {
    final l = _lignes[i];
    if (_droitRefuse != null || _envois.contains(l.id)) return;
    final choix = await showModalBottomSheet<StatutPeremptionCourte>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Statut : ${l.produit.isEmpty ? 'péremption courte' : l.produit}',
                style: const TextStyle(color: Charte.navy, fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          for (final s in StatutPeremptionCourte.values)
            ListTile(
              key: Key('pc_choix_${s.code}'),
              minTileHeight: 52,
              leading: Icon(s.code == l.statut ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: Charte.navy),
              title: Text(s.libelle, style: const TextStyle(color: Charte.encre, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(ctx).pop(s),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted) return;
    if (choix == null || choix.code == l.statut) return;
    setState(() => _envois.add(l.id));
    try {
      await ApiPeremptionsCourtes.statut(context, l.id, choix);
      if (!mounted) return;
      setState(() {
        final k = _lignes.indexWhere((x) => x.id == l.id);
        if (k >= 0) _lignes[k] = _lignes[k].avecStatut(choix);
      });
      messageResultat(context, 'Statut enregistré : ${choix.libelle}.');
    } catch (e) {
      if (!mounted) return;
      final d = DiagnosticErreur.de(e);
      if (e is ApiLoadException && e.nature == NatureErreur.droit) setState(() => _droitRefuse = d.message);
      messageResultat(context, 'Statut non enregistré : ${d.message}', echec: true);
    } finally {
      if (mounted) setState(() => _envois.remove(l.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Péremptions courtes'), actions: [
          if (_export)
            const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_charge && _lignes.isNotEmpty)
            MenuExports(actions: [
              ActionExport('Excel', Icons.table_view_outlined, () => _exporter(false)),
              ActionExport('PDF', Icons.picture_as_pdf_outlined, () => _exporter(true)),
            ]),
          BoutonFiltres(actifs: _filtres.grossiste.isEmpty ? 0 : 1, onPressed: _ouvrirFiltres),
          IconButton(key: const Key('pc_actualiser'), tooltip: 'Actualiser', icon: const Icon(Icons.refresh), onPressed: _enCours ? null : _charger),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView.builder(
            key: const Key('defilement_peremptions_courtes'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: 2 + _lignes.length,
            itemBuilder: (context, i) {
              if (i == 0) return _entete();
              if (i == 1) return _etat();
              return _carte(i - 2);
            },
          ),
        ),
      );

  Widget _entete() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SelecteurPeriode(periode: _filtres.periode, maintenant: widget.maintenant, onChanged: (p) => _appliquer(_filtres.copie(periode: p))),
        const SizedBox(height: 8),
        PucesChoix<StatutPeremptionCourte?>(
          choix: [(null, 'Tous'), for (final s in StatutPeremptionCourte.values) (s, s.libelle)],
          valeur: _filtres.statut,
          cle: (s, _) => Key('pc_statut_${s?.code ?? 'TOUS'}'),
          onChanged: (s) => _appliquer(s == null ? _filtres.copie(sansStatut: true) : _filtres.copie(statut: s)),
        ),
        if (_filtres.grossiste.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              const Icon(Icons.local_shipping_outlined, size: 16, color: Charte.gris),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Grossiste : ${_filtres.libelleGrossiste.isEmpty ? 'choisi' : _filtres.libelleGrossiste}',
                    key: const Key('pc_grossiste_choisi'), style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                key: const Key('pc_retirer_grossiste'),
                onPressed: () => _appliquer(_filtres.copie(grossiste: '', libelleGrossiste: '')),
                child: const Text('Retirer'),
              ),
            ]),
          ),
        const SizedBox(height: 8),
      ]);

  Widget _etat() {
    final e = _erreur;
    if (e != null) {
      if (_routeAbsente(e)) {
        return const EtatVide(
            titre: 'Indisponible sur ce serveur',
            texte: 'Les péremptions courtes demandent la mise à jour du serveur Prestige (octobre 2026).',
            icone: Icons.cloud_off_outlined);
      }
      return EtatErreur(erreur: e, reessayer: _charger);
    }
    if (_enCours && _lignes.isEmpty) return const EtatChargement(texte: 'Lecture des péremptions courtes…');
    if (!_charge) return const SizedBox.shrink();
    if (_lignes.isEmpty) {
      return const EtatVide(titre: 'Aucune péremption courte', texte: 'Aucune péremption courte sur cette période.', icone: Icons.check_circle_outline);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GrilleKpi([
        ChiffreCle(libelle: 'Lignes', valeur: grouperMilliers(_total), id: 'pc_total', enAvant: true),
        ChiffreCle(libelle: 'Valeur', valeur: formaterMontant(_valeur), id: 'pc_valeur', detail: 'quantité × prix d\'achat'),
      ]),
      if (_droitRefuse != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Changement de statut non autorisé pour ce compte. $_droitRefuse',
              key: const Key('pc_droit_refuse'), style: const TextStyle(color: Charte.rougeTexte, fontSize: 13)),
        ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _carte(int i) {
    final l = _lignes[i];
    final s = l.statutConnu;
    final envoi = _envois.contains(l.id);
    final modifiable = _droitRefuse == null && !envoi && l.id.isNotEmpty;
    final saisie = [
      if (l.le.isNotEmpty) 'Saisi le ${PeremptionCourte.date(l.le)}${PeremptionCourte.heure(l.le).isEmpty ? '' : ' à ${PeremptionCourte.heure(l.le)}'}',
      if (l.utilisateur.isNotEmpty) 'par ${l.utilisateur}',
    ].join(' ');
    final jours = l.joursRestants;
    return CarteLigne(
      key: Key('pc_ligne_$i'),
      titre: l.produit.isEmpty ? 'Produit' : l.produit,
      bande: l.acceptee ? Charte.ambre : Charte.rouge,
      etiquette: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Etiquette(l.acceptee ? 'Accepté' : 'Refusé', ton: l.acceptee ? Ton.vert : Ton.rouge),
        Semantics(
          button: modifiable,
          label: 'Statut : ${s?.libelle ?? (l.statut.isEmpty ? 'inconnu' : l.statut)}${modifiable ? ', toucher pour le changer' : ''}',
          excludeSemantics: true,
          child: InkWell(
            key: Key('pc_statut_ligne_$i'),
            borderRadius: BorderRadius.circular(20),
            onTap: modifiable ? () => _changerStatut(i) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Etiquette(s?.libelle ?? (l.statut.isEmpty ? 'Statut inconnu' : l.statut), ton: s?.ton ?? Ton.gris),
                if (envoi)
                  const Padding(padding: EdgeInsets.only(left: 6), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                else if (modifiable)
                  const Padding(padding: EdgeInsets.only(left: 2), child: Icon(Icons.arrow_drop_down, color: Charte.navy)),
              ]),
            ),
          ),
        ),
      ]),
      lignes: [
        [if (l.cip.isNotEmpty) 'CIP ${l.cip}', if (l.bl.isNotEmpty) 'BL ${l.bl}'].join(' · '),
        if (l.grossiste.isNotEmpty) l.grossiste,
        [
          if (l.numLot.isNotEmpty) 'Lot ${l.numLot}',
          if (l.datePeremption.isNotEmpty) 'péremption ${PeremptionCourte.date(l.datePeremption)}',
          if (l.datePeremption.isNotEmpty) jours < 0 ? 'périmé' : '$jours jour${jours > 1 ? 's' : ''} restant${jours > 1 ? 's' : ''} à la réception',
        ].join(' · '),
        'Quantité ${grouperMilliers(l.quantite)}',
        if (l.motif.isNotEmpty) 'Motif : ${l.motif}',
        if (saisie.isNotEmpty) saisie,
      ].where((x) => x.isNotEmpty).toList(),
      libelleValeur: 'Valeur',
      valeur: formaterMontant(l.valeur),
    );
  }
}
