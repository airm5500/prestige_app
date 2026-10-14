// lib/nouvelle_interface/modules/ajustements_nouveau.dart
// Suivi des Ajustements de la nouvelle interface. Mêmes données que l'écran d'origine (Ajustements,
// lib/donnees/ajustements_donnees.dart) : motifs (GET /common/type-ajustements), ajustements GET /ajustement
// (dtStart, dtEnd, typeFiltre, page=1, start=0, limit=100), produits d'un ajustement GET /ajustement/items et
// analyse (valeurs ajoutée / retirée). Mise en page refaite : période commune (chargée à l'ouverture sur
// « Aujourd'hui »), motif dans la feuille du bas, chiffres clés, cartes (téléphone) ou tableau (tablette), détail en
// page avec l'analyse en chiffres clés.
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

  Future<void> _charger() => charger(() async =>
      await Ajustements.charger(context, _periode.debut, _periode.fin, typeId: _type?.id ?? '', onSessionInvalid: sessionInvalide(context)) ??
      const <Ajustement>[]);

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
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Ajustements', valeur: formaterNombre(l.length), id: 'ajustements', enAvant: true, detail: l.length >= 100 ? '100 premiers' : null),
        ChiffreCle(libelle: 'Opérateurs', valeur: formaterNombre(operateurs), id: 'operateurs'),
      ]),
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
