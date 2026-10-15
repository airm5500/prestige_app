// lib/nouvelle_interface/modules/suivi_2080_nouveau.dart
// Suivi 20/80 de la nouvelle interface. Mêmes données que l'écran d'origine (Suivi2080Donnees,
// lib/donnees/analyses_ventes_donnees.dart) : GET /statfamillearticle/vingtQuatreVingt?dtStart=&dtEnd=&limit=
// &codeFamile=&codeRayon=&codeGrossiste=&qtyOrCa=false&page=1&start=0 → « data ». Mise en page refaite : période
// commune chargée dès l'ouverture (« Aujourd'hui », dates par défaut d'origine), nombre d'articles (1 à 9 999, 50
// par défaut) dans la feuille des filtres, chiffres clés, articles dans l'ordre du serveur avec leur rang et leur
// part du montant affiché, détail d'un article en feuille.
// 3.8.0 (choix du pharmacien) : puces « Classer par : Chiffre d'affaires | Quantité » sur la vue (défaut : chiffre
// d'affaires, requête identique à avant) ; quantité : vingtType=QTY (lu par le serveur) et tri par quantité vendue,
// part de la quantité affichée.
// 3.9.0 (demande du pharmacien) : choix « Tous » dans la feuille des filtres (interrupteur « Tous les articles ») :
// « topN » n'est alors pas envoyé (absent = tous pour le serveur) ; défaut toujours 50.
import 'package:flutter/material.dart';

import '../../donnees/analyses_ventes_donnees.dart';
import '../../models/suivi_20_80_model.dart';
import '../../utils/saisie.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'commun_lot2.dart';
import 'commun_lot3.dart';
import 'periode.dart';

class Suivi2080Nouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const Suivi2080Nouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<Suivi2080Nouveau> createState() => _Suivi2080NouveauState();
}

class _Suivi2080NouveauState extends State<Suivi2080Nouveau> with ChargementSuivi<Suivi2080Nouveau, List<Suivi2080>>, AffichageParTranches {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  int _limite = Suivi2080Donnees.limiteParDefaut;
  CritereVingt _critere = CritereVingt.chiffreAffaires;
  final _champLimite = TextEditingController();

  @override
  void dispose() {
    _champLimite.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() {
    reinitialiserTranches();
    return charger(() async =>
        await Suivi2080Donnees.charger(context, _periode.debut, _periode.fin, _limite, critere: _critere, onSessionInvalid: sessionInvalide(context)) ??
        const <Suivi2080>[]);
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  /// Message d'un nombre d'articles refusé (vide accepté : 50 par défaut).
  static String? _erreurLimite(String t) =>
      t.trim().isEmpty || Saisie.entier(t, min: 1, max: Saisie.maxLignes) != null ? null : 'Entre 1 et ${formaterNombre(Saisie.maxLignes)}';

  bool get _tous => _limite == Suivi2080Donnees.tous;

  /// Libellé du nombre d'articles choisi (étiquette de filtre, chiffre clé).
  String get _libelleLimite => _tous ? 'Tous les articles' : '${formaterNombre(_limite)} articles au plus';

  Future<void> _filtres() async {
    var tous = _tous;
    _champLimite.text = tous ? '${Suivi2080Donnees.limiteParDefaut}' : '$_limite';
    String? erreurChamp;
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer le Suivi 20/80',
      effacer: () {
        _champLimite.text = '${Suivi2080Donnees.limiteParDefaut}';
        erreurChamp = null;
        tous = false;
      },
      valider: () => tous || _erreurLimite(_champLimite.text) == null,
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // « Tous » (3.9.0) : aucun nombre envoyé au serveur (topN absent = tous les articles).
        SwitchListTile(
          key: const Key('filtre_tous'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Tous les articles'),
          subtitle: const Text('Aucune limite : peut être long sur une grande période'),
          value: tous,
          onChanged: (v) => setState(() => tous = v),
        ),
        TextField(
          key: const Key('filtre_limite'),
          controller: _champLimite,
          enabled: !tous,
          keyboardType: TextInputType.number,
          inputFormatters: Saisie.entierFormatters(4), // 1 à 9 999
          onChanged: (t) => setState(() => erreurChamp = _erreurLimite(t)),
          decoration: InputDecoration(
            labelText: 'Nombre d\'articles à afficher',
            errorText: tous ? null : erreurChamp,
            prefixIcon: const Icon(Icons.format_list_numbered),
          ),
        ),
        const SizedBox(height: 6),
        Text(
            tous
                ? 'Tous les articles de la période.'
                : 'De 1 à ${formaterNombre(Saisie.maxLignes)} ; vide = ${Suivi2080Donnees.limiteParDefaut}.',
            style: const TextStyle(color: Charte.grisTexte, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
    if (!applique || !mounted) return;
    setState(() => _limite = tous ? Suivi2080Donnees.tous : Suivi2080Donnees.limite(_champLimite.text));
    _charger();
  }

  void _changerCritere(CritereVingt c) {
    if (c == _critere) return;
    setState(() => _critere = c);
    _charger();
  }

  bool get _parQuantite => _critere == CritereVingt.quantite;

  void _detail(Suivi2080 a, int rang, int total, int quantite) => ouvrirFeuilleDetail(context,
          titre: a.libelle, sousTitre: 'Rang $rang (${_critere.libelle.toLowerCase()}) · CIP ${a.cip}', lignes: [
        LigneDetail('Quantité vendue', formaterNombre(a.quantiteVendue), gras: _parQuantite),
        LigneDetail('Stock actuel', formaterNombre(a.stock)),
        LigneDetail('Montant', formaterMontant(a.montant), gras: !_parQuantite),
        if (_parQuantite)
          LigneDetail('Part de la quantité affichée', quantite == 0 ? '—' : formaterPourcent(a.quantiteVendue / quantite * 100))
        else
          LigneDetail('Part du montant affiché', total == 0 ? '—' : formaterPourcent(a.montant / total * 100)),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Suivi 20/80'), actions: [
          BoutonFiltres(actifs: _limite == Suivi2080Donnees.limiteParDefaut ? 0 : 1, onPressed: _filtres),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
              const Text('Classer par', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
              PucesChoix<CritereVingt>(
                choix: [for (final c in CritereVingt.values) (c, c.libelle)],
                valeur: _critere,
                cle: (c, _) => Key('classement_${c.name}'),
                onChanged: _changerCritere,
              ),
            ]),
            EtiquettesFiltres(
              etiquettes: [if (_limite != Suivi2080Donnees.limiteParDefaut) _libelleLimite],
              onRetirer: () {
                setState(() => _limite = Suivi2080Donnees.limiteParDefaut);
                _charger();
              },
            ),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des articles…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <Suivi2080>[];
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucune donnée trouvée', texte: 'Aucun article pour les critères sélectionnés.', icone: Icons.star_border)];
    }
    final total = Suivi2080Donnees.montantTotal(l);
    final quantite = Suivi2080Donnees.quantiteTotale(l);
    final n = affichees.clamp(0, l.length);
    final q = _parQuantite;
    String part(Suivi2080 a) => q
        ? (quantite == 0 ? '—' : formaterPourcent(a.quantiteVendue / quantite * 100))
        : (total == 0 ? '—' : formaterPourcent(a.montant / total * 100));
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Montant', valeur: formaterMontant(total), id: 'montant', enAvant: !q),
        ChiffreCle(libelle: 'Articles', valeur: formaterNombre(l.length), id: 'articles', detail: _tous ? 'Tous demandés' : '${formaterNombre(_limite)} demandés au plus'),
        ChiffreCle(libelle: 'Quantité vendue', valeur: formaterNombre(quantite), id: 'quantite', enAvant: q),
      ]),
      TitreSection(q ? 'Articles (par quantité vendue)' : 'Articles'),
      ListeOuTableau(
        nombre: n,
        onTap: (i) => _detail(l[i], i + 1, total, quantite),
        colonnes: [
          const Colonne('Rang', flex: 1),
          const Colonne('CIP', flex: 3),
          const Colonne('Produit', flex: 6),
          const Colonne('Qté vendue', flex: 2, droite: true),
          const Colonne('Stock', flex: 2, droite: true),
          const Colonne('Montant', flex: 3, droite: true),
          Colonne(q ? 'Part qté' : 'Part', flex: 2, droite: true),
        ],
        cellules: (i) => ['${i + 1}', l[i].cip, l[i].libelle, formaterNombre(l[i].quantiteVendue), formaterNombre(l[i].stock), formaterMontant(l[i].montant), part(l[i])],
        total: n == l.length ? ['', '', 'Total', formaterNombre(quantite), '', formaterMontant(total), ''] : null,
        carte: (i) => q
            ? CarteLigne(
                titre: '${i + 1}. ${l[i].libelle}',
                lignes: ['CIP ${l[i].cip}', 'Stock actuel ${formaterNombre(l[i].stock)} · ${part(l[i])} de la quantité'],
                etiquette: Etiquette('Montant ${formaterMontant(l[i].montant)}', ton: Ton.vert),
                libelleValeur: 'Qté vendue',
                valeur: formaterNombre(l[i].quantiteVendue),
                onTap: () => _detail(l[i], i + 1, total, quantite),
              )
            : CarteLigne(
                titre: '${i + 1}. ${l[i].libelle}',
                lignes: ['CIP ${l[i].cip}', 'Stock actuel ${formaterNombre(l[i].stock)} · ${part(l[i])} du montant'],
                etiquette: Etiquette('Qté vendue ${formaterNombre(l[i].quantiteVendue)}', ton: Ton.vert),
                libelleValeur: 'Montant',
                valeur: formaterMontant(l[i].montant),
                onTap: () => _detail(l[i], i + 1, total, quantite),
              ),
      ),
      piedTranches(l.length),
    ];
  }
}
