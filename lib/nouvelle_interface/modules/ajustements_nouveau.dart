// lib/nouvelle_interface/modules/ajustements_nouveau.dart
// Suivi des Ajustements de la nouvelle interface. Mêmes données que l'écran d'origine (Ajustements,
// lib/donnees/ajustements_donnees.dart) : motifs (GET /common/type-ajustements), ajustements GET /ajustement
// (dtStart, dtEnd, typeFiltre, page=1, start=0, limit=100), produits d'un ajustement GET /ajustement/items et
// analyse (valeurs ajoutée / retirée). Mise en page refaite : période commune (chargée à l'ouverture sur
// « Aujourd'hui »), motif dans la feuille du bas, chiffres clés, cartes (téléphone) ou tableau (tablette), détail en
// page avec l'analyse en chiffres clés.
// 3.8.0 (réponse du pharmacien) : « Afficher plus » au-delà de 100. Le serveur pagine (start / limit, « total ») :
// page suivante start=100, 200… avec EXACTEMENT les filtres de la première page (période et motif lus à ce moment).
// Serveur sans « total » : les 100 premiers comme avant, avec l'avertissement « Limite du serveur atteinte ».
import 'package:flutter/material.dart';

import '../../donnees/ajustements_donnees.dart';
import '../../models/ajustement_detail_model.dart';
import '../../models/ajustement_model.dart';
import '../../models/common_data_model.dart';
import '../charte.dart';
import '../composants.dart';
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixListe;
import 'commun.dart';
import 'commun_lot2.dart';
import 'periode.dart';

class AjustementsNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const AjustementsNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<AjustementsNouveau> createState() => _AjustementsNouveauState();
}

class _AjustementsNouveauState extends State<AjustementsNouveau> with ChargementSuivi<AjustementsNouveau, List<Ajustement>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  List<CommonData>? _types;
  Object? _erreurTypes;
  CommonData? _type;

  // Pagination (3.8.0) : total annoncé par le serveur (null : serveur sans total), filtres de la première page.
  int? _total;
  bool _suiteEnCours = false;
  int _lecture = 0;
  ({Periode periode, String typeId})? _filtresLus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chargerTypes();
      _charger();
    });
  }

  Future<void> _chargerTypes() async {
    setState(() => _erreurTypes = null);
    try {
      final t = await Ajustements.types(context, onSessionInvalid: sessionInvalide(context));
      if (mounted) setState(() => _types = t ?? const []);
    } catch (e) {
      if (mounted) setState(() => _erreurTypes = e);
    }
  }

  /// Première page (filtres du moment) : la requête d'origine (start=0, limit=100).
  Future<void> _charger() {
    final f = _filtresLus = (periode: _periode, typeId: _type?.id ?? '');
    final g = ++_lecture;
    setState(() {
      _total = null;
      _suiteEnCours = false;
    });
    return charger(() async {
      final p = await Ajustements.page(context, f.periode.debut, f.periode.fin, typeId: f.typeId, start: 0, onSessionInvalid: sessionInvalide(context));
      if (g == _lecture) _total = p.total;
      return p.ajustements;
    });
  }

  /// Le serveur annonce-t-il d'autres ajustements que ceux chargés ?
  bool get _aSuite {
    final n = donnees?.length ?? 0;
    return _total != null && n > 0 && n < _total!;
  }

  /// Page suivante (« Afficher plus ») : mêmes filtres que la première page, start = ajustements déjà chargés.
  Future<void> _suite() async {
    final f = _filtresLus;
    final deja = donnees;
    if (_suiteEnCours || enCours || !_aSuite || f == null || deja == null) return;
    final g = _lecture;
    setState(() => _suiteEnCours = true);
    try {
      final p = await Ajustements.page(context, f.periode.debut, f.periode.fin,
          typeId: f.typeId, start: deja.length, onSessionInvalid: sessionInvalide(context));
      if (!mounted || g != _lecture) return;
      setState(() {
        donnees = [...deja, ...p.ajustements];
        // Page vide : rien de plus à attendre (total figé sur ce qui est chargé).
        _total = p.ajustements.isEmpty ? donnees!.length : (p.total ?? _total);
        _suiteEnCours = false;
      });
    } catch (e) {
      if (!mounted || g != _lecture) return;
      setState(() => _suiteEnCours = false);
      messageResultat(context, DiagnosticErreur.de(e).message, echec: true);
    }
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  Future<void> _filtres() async {
    if (_types == null && _erreurTypes != null) _chargerTypes();
    var type = _type?.id ?? '';
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les ajustements',
      effacer: () => type = '',
      contenu: (ctx, setState) => ChoixListe(
        key: const Key('filtre_motif'),
        libelle: 'Motif',
        icone: Icons.rule_folder_outlined,
        options: _types == null ? null : [for (final t in _types!) OptionListe(t.id, t.libelle)],
        erreur: _erreurTypes,
        valeur: type,
        tous: 'Tous les motifs',
        onChanged: (v) => setState(() => type = v),
      ),
    );
    if (!applique || !mounted) return;
    setState(() => _type = type.isEmpty ? null : _types?.where((t) => t.id == type).firstOrNull);
    _charger();
  }

  void _ouvrir(Ajustement a) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailAjustementNouveau(ajustement: a)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Suivi des Ajustements'), actions: [BoutonFiltres(actifs: _type == null ? 0 : 1, onPressed: _filtres)]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            EtiquettesFiltres(etiquettes: [if (_type != null) 'Motif : ${_type!.libelle}'], onRetirer: () {
              setState(() => _type = null);
              _charger();
            }),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des ajustements…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <Ajustement>[];
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucun ajustement trouvé', texte: 'Aucun ajustement pour cette période.', icone: Icons.rule_folder_outlined)];
    }
    final operateurs = {for (final a in l) a.userFullName}.length;
    // Serveur sans « total » qui a rendu une page entière : d'autres ajustements peuvent manquer (comme avant).
    final limite = _total == null && l.length >= Ajustements.taillePage;
    final total = _total ?? l.length;
    return [
      GrilleKpi([
        ChiffreCle(
          libelle: 'Ajustements',
          valeur: formaterNombre(total),
          id: 'ajustements',
          enAvant: true,
          detail: limite ? '100 premiers' : (l.length < total ? '${formaterNombre(l.length)} chargés' : null),
        ),
        ChiffreCle(libelle: 'Opérateurs', valeur: formaterNombre(operateurs), id: 'operateurs', detail: l.length < total ? 'parmi les chargés' : null),
      ]),
      if (limite) ...[
        const SizedBox(height: 10),
        const Encadre(
          key: Key('ajustements_limite'),
          titre: 'Limite du serveur atteinte',
          texte: 'Le serveur n\'indique pas le nombre total d\'ajustements : seuls les 100 premiers sont affichés. Réduisez la période ou filtrez par motif.',
          icone: Icons.info_outline,
          avertissement: true,
        ),
      ],
      const TitreSection('Ajustements'),
      ListeOuTableau(
        nombre: l.length,
        onTap: (i) => _ouvrir(l[i]),
        colonnes: const [Colonne('Description', flex: 5), Colonne('Par', flex: 3), Colonne('Date', flex: 2), Colonne('Heure', flex: 1)],
        cellules: (i) => [l[i].description, l[i].userFullName, l[i].dtUPDATED, l[i].heure],
        carte: (i) => CarteLigne(
          titre: l[i].description,
          lignes: ['Par ${l[i].userFullName} le ${l[i].dtUPDATED} à ${l[i].heure}'],
          onTap: () => _ouvrir(l[i]),
        ),
      ),
      if (_total != null && total > Ajustements.taillePage) PiedPagination(affichees: l.length, total: total, enCours: _suiteEnCours, onPlus: _suite),
    ];
  }
}

/// Produits d'un ajustement et analyse (valeur ajoutée / retirée et leurs parts).
class DetailAjustementNouveau extends StatefulWidget {
  final Ajustement ajustement;
  const DetailAjustementNouveau({super.key, required this.ajustement});

  @override
  State<DetailAjustementNouveau> createState() => _DetailAjustementNouveauState();
}

class _DetailAjustementNouveauState extends State<DetailAjustementNouveau> with ChargementSuivi<DetailAjustementNouveau, List<AjustementDetail>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() => charger(() async =>
      await Ajustements.details(context, widget.ajustement.lgAJUSTEMENTID, onSessionInvalid: sessionInvalide(context)) ?? const <AjustementDetail>[]);

  static String _pct(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} %';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.ajustement.description, overflow: TextOverflow.ellipsis, maxLines: 1)),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_detail'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            Text('Par ${widget.ajustement.userFullName} le ${widget.ajustement.dtUPDATED} à ${widget.ajustement.heure}',
                style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement de l\'ajustement…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <AjustementDetail>[];
    final a = Ajustements.analyser(l);
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Valeur Ajoutée (Positif)', valeur: formaterMontant(a.positif), id: 'positif', detail: _pct(a.partPositif)),
        ChiffreCle(libelle: 'Valeur Retirée (Négatif)', valeur: formaterMontant(a.negatif), id: 'negatif', detail: _pct(a.partNegatif)),
      ]),
      const TitreSection('Produits Ajustés'),
      if (l.isEmpty)
        const EtatVide(titre: 'Aucun produit détaillé pour cet ajustement.', icone: Icons.inventory_2_outlined)
      else
        ListeOuTableau(
          nombre: l.length,
          colonnes: const [
            Colonne('Produit', flex: 5),
            Colonne('Motif', flex: 3),
            Colonne('Qté', flex: 1, droite: true),
            Colonne('Stock avant', flex: 2, droite: true),
            Colonne('Stock après', flex: 2, droite: true),
            Colonne('Valeur', flex: 2, droite: true),
          ],
          cellules: (i) => [
            l[i].strNAME,
            l[i].motifAjustement,
            '${l[i].intNUMBER > 0 ? '+' : ''}${l[i].intNUMBER}',
            '${l[i].intNUMBERCURRENTSTOCK}',
            '${l[i].intNUMBERAFTERSTOCK}',
            formaterMontant(l[i].valeurAjustement),
          ],
          carte: (i) => CarteLigne(
            titre: l[i].strNAME,
            bande: l[i].isPositive ? Charte.vert : Charte.rouge,
            etiquette: Etiquette(l[i].isPositive ? 'Ajout' : 'Retrait', ton: l[i].isPositive ? Ton.vert : Ton.rouge),
            lignes: ['Motif : ${l[i].motifAjustement}', 'Valeur : ${formaterMontant(l[i].valeurAjustement)}'],
            libelleValeur: 'Qté',
            valeur: '${l[i].intNUMBER > 0 ? '+' : ''}${l[i].intNUMBER}',
          ),
        ),
    ];
  }
}
