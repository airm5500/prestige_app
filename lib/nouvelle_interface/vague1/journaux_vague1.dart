// lib/nouvelle_interface/vague1/journaux_vague1.dart
// « Retraits et abandons » (GET /vente-suppressions) et « Ventes modifiées » (GET /ventes-modifiees) : journaux en
// LECTURE SEULE (pas de « Créer inventaire », qui écrit). Mêmes composants que les modules du lot 1
// (modules/commun.dart, modules/periode.dart) : période commune en haut (aujourd'hui par défaut, début ≤ fin,
// jamais future, 3 ans au maximum), filtres type et utilisateur (/common/users) dans la feuille du bas (bouton
// « Filtres » de la barre), recherche contrôlée (anti-rebond ; une réponse arrivée après un nouveau filtre est
// ignorée). Pages de 50 lignes (« Afficher plus »), cartes sur téléphone, tableau dense sur tablette.
// Ventes modifiées : détail des lignes avant / après.
import 'package:flutter/material.dart';

import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/periode.dart';
import 'commun_vague1.dart';
import 'donnees_vague1.dart';

/// Écran de journal paginé, filtré (commun aux deux menus).
class EcranJournalVague1<T> extends StatefulWidget {
  final String titre;
  final String indicationRecherche;

  /// Types proposés (code envoyé au serveur, libellé) ; le premier est « Tous » (code vide).
  final List<(String, String)> types;
  final Future<PageResultats<T>> Function(BuildContext context, FiltresJournal filtres, int start) charger;
  final Widget Function(BuildContext context, T ligne, VoidCallback? ouvrir) carte;

  /// Tableau dense (tablette) : colonnes et cellules d'une ligne.
  final List<Colonne> colonnes;
  final List<String> Function(T ligne) cellules;
  final Widget Function(T ligne)? detail;
  final String texteVide;

  /// Maintenant (remplaçable dans les tests).
  final DateTime Function() maintenant;

  const EcranJournalVague1({
    super.key,
    required this.titre,
    required this.indicationRecherche,
    required this.types,
    required this.charger,
    required this.carte,
    required this.colonnes,
    required this.cellules,
    required this.texteVide,
    this.detail,
    this.maintenant = DateTime.now,
  });

  @override
  State<EcranJournalVague1<T>> createState() => _EcranJournalVague1State<T>();
}

class _EcranJournalVague1State<T> extends State<EcranJournalVague1<T>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  late FiltresJournal _filtres = FiltresJournal(debut: _periode.debut, fin: _periode.fin);
  List<OptionListe>? _utilisateurs;
  Object? _erreurUtilisateurs;
  final _recherche = TextEditingController();

  final _lignes = <T>[];
  int _total = 0;
  bool _charge = false;
  bool _chargement = false;
  bool _chargementPlus = false;
  Object? _erreur;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chargerUtilisateurs();
      _recharger();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _chargerUtilisateurs() async {
    try {
      final u = await ApiJournaux.utilisateurs(context);
      if (mounted) setState(() => _utilisateurs = u);
    } catch (e) {
      if (mounted) setState(() => _erreurUtilisateurs = e);
    }
  }

  /// Première page avec les filtres courants ; toute réponse d'une demande plus ancienne est ignorée.
  Future<void> _recharger() async {
    final generation = ++_generation;
    final filtres = _filtres;
    setState(() {
      _chargement = true;
      _chargementPlus = false;
      _erreur = null;
    });
    try {
      final p = await widget.charger(context, filtres, 0);
      if (!mounted || generation != _generation) return;
      setState(() {
        _lignes
          ..clear()
          ..addAll(p.lignes);
        _total = p.total;
        _charge = true;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _erreur = e;
        _chargement = false;
      });
    }
  }

  Future<void> _plus() async {
    if (_chargementPlus || _chargement) return;
    final generation = _generation;
    setState(() => _chargementPlus = true);
    try {
      final p = await widget.charger(context, _filtres, _lignes.length);
      if (!mounted || generation != _generation) return;
      setState(() {
        _lignes.addAll(p.lignes);
        _total = p.total < _lignes.length ? _lignes.length : p.total;
        if (p.lignes.isEmpty) _total = _lignes.length; // plus rien côté serveur
        _chargementPlus = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _chargementPlus = false;
        _erreur = e;
      });
    }
  }

  void _filtrer(FiltresJournal f) {
    _filtres = f;
    _recharger();
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _filtrer(_filtres.copie(debut: p.debut, fin: p.fin));
  }

  int get _actifs => (_filtres.type.isEmpty ? 0 : 1) + (_filtres.utilisateurId.isEmpty ? 0 : 1);

  String _libelleType(String code) => widget.types.firstWhere((t) => t.$1 == code, orElse: () => (code, code)).$2;

  String _libelleUtilisateur(String id) => (_utilisateurs ?? const <OptionListe>[]).where((o) => o.id == id).firstOrNull?.libelle ?? id;

  /// Feuille des filtres commune (type, utilisateur) : appliquée seulement sur « Appliquer ».
  Future<void> _ouvrirFiltres() async {
    var type = _filtres.type;
    var utilisateur = _filtres.utilisateurId;
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer : ${widget.titre.toLowerCase()}',
      effacer: () {
        type = '';
        utilisateur = '';
      },
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Type', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        PucesChoix<String>(
          choix: widget.types,
          valeur: type,
          cle: (_, libelle) => Key('filtre_type_$libelle'),
          onChanged: (t) => setState(() => type = t),
        ),
        const SizedBox(height: 14),
        _ChoixUtilisateur(
          utilisateurs: _utilisateurs,
          erreur: _erreurUtilisateurs,
          valeur: utilisateur,
          onChanged: (id) => setState(() => utilisateur = id),
        ),
      ]),
    );
    if (applique && mounted && (type != _filtres.type || utilisateur != _filtres.utilisateurId)) {
      _filtrer(_filtres.copie(type: type, utilisateurId: utilisateur));
    }
  }

  void _ouvrir(T ligne) {
    final d = widget.detail;
    if (d == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => d(ligne)));
  }

  @override
  Widget build(BuildContext context) {
    final ouvrir = widget.detail == null ? null : _ouvrir;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titre),
        actions: [
          BoutonFiltres(actifs: _actifs, onPressed: _ouvrirFiltres),
          IconButton(
            key: const Key('journal_actualiser'),
            tooltip: 'Actualiser',
            onPressed: _chargement ? null : _recharger,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(key: const Key('defilement_journal'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
        if (_actifs > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (_filtres.type.isNotEmpty) Etiquette('Type : ${_libelleType(_filtres.type)}'),
              if (_filtres.utilisateurId.isNotEmpty) Etiquette('Par : ${_libelleUtilisateur(_filtres.utilisateurId)}'),
              TextButton(
                key: const Key('filtres_retirer'),
                onPressed: () => _filtrer(_filtres.copie(type: '', utilisateurId: '')),
                child: const Text('Retirer les filtres'),
              ),
            ]),
          ),
        const SizedBox(height: 10),
        ChampRecherche(
          controleur: _recherche,
          libelle: 'Rechercher',
          aide: widget.indicationRecherche,
          onRecherche: (q) => _filtrer(_filtres.copie(recherche: q)),
        ),
        const SizedBox(height: 8),
        if (_chargement) const EtatChargement(),
        if (_erreur != null) EtatErreur(erreur: _erreur!, reessayer: _lignes.isEmpty ? _recharger : _plus),
        if (_charge && !_chargement) ...[
          if (_lignes.isEmpty && _erreur == null)
            EtatVide(titre: widget.texteVide, texte: 'Choisissez une autre période ou modifiez les filtres.', icone: Icons.check_circle_outline)
          else if (_lignes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8, left: 4),
              child: Text(
                '${grouperMilliers(_total)} ${_total > 1 ? 'lignes' : 'ligne'} · ${_periodeTexte(_filtres)}',
                key: const Key('journal_total'),
                style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600),
              ),
            ),
            ListeOuTableau(
              nombre: _lignes.length,
              colonnes: widget.colonnes,
              cellules: (i) => widget.cellules(_lignes[i]),
              onTap: ouvrir == null ? null : (i) => ouvrir(_lignes[i]),
              carte: (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: widget.carte(context, _lignes[i], ouvrir == null ? null : () => ouvrir(_lignes[i])),
              ),
            ),
            PiedPagination(affichees: _lignes.length, total: _total, enCours: _chargementPlus, onPlus: _plus),
          ],
        ],
      ]),
    );
  }
}

/// « le 14/10/2026 » ou « du 01/10/2026 au 14/10/2026 ».
String _periodeTexte(FiltresJournal f) =>
    memeJour(f.debut, f.fin) ? 'le ${dateCourte(f.debut)}' : 'du ${dateCourte(f.debut)} au ${dateCourte(f.fin)}';

class _ChoixUtilisateur extends StatelessWidget {
  final List<OptionListe>? utilisateurs;
  final Object? erreur;
  final String valeur;
  final ValueChanged<String> onChanged;
  const _ChoixUtilisateur({required this.utilisateurs, required this.erreur, required this.valeur, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final u = utilisateurs ?? const <OptionListe>[];
    final connu = valeur.isEmpty || u.any((o) => o.id == valeur);
    return DropdownButtonFormField<String>(
      key: const Key('filtre_utilisateur'),
      value: connu ? valeur : '',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Utilisateur',
        prefixIcon: const Icon(Icons.person_outline),
        helperText: erreur != null ? 'Liste des utilisateurs indisponible' : null,
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('Tous les utilisateurs')),
        for (final o in u) DropdownMenuItem(value: o.id, child: Text(o.libelle, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: utilisateurs == null ? null : (v) => onChanged(v ?? ''),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Retraits et abandons
// ---------------------------------------------------------------------------------------------------------------

class RetraitsAbandonsScreen extends StatelessWidget {
  final DateTime Function() maintenant;
  const RetraitsAbandonsScreen({super.key, this.maintenant = DateTime.now});

  @override
  Widget build(BuildContext context) => EcranJournalVague1<SuppressionVente>(
        titre: 'Retraits et abandons',
        indicationRecherche: 'Produit, CIP ou n° de vente',
        maintenant: maintenant,
        types: const [('', 'Tous'), ('PRODUIT', 'Produit retiré'), ('VENTE', 'Vente abandonnée')],
        charger: (ctx, f, start) => ApiJournaux.suppressions(ctx, f, start: start),
        texteVide: 'Aucun produit retiré ni vente abandonnée sur cette période.',
        colonnes: const [
          Colonne('Date', flex: 3),
          Colonne('Type', flex: 3),
          Colonne('Vente', flex: 3),
          Colonne('CIP', flex: 2),
          Colonne('Produit', flex: 5),
          Colonne('Qté', flex: 1, droite: true),
          Colonne('Par', flex: 3),
          Colonne('Vente ouverte par', flex: 3),
        ],
        cellules: (s) => [s.moment, s.typeLibelle, s.venteRef, s.produitCip, s.produitLibelle, grouperMilliers(s.quantite), s.utilisateur, s.utilisateurOrigine],
        carte: (context, s, _) => CarteBande(
          bande: s.venteAbandonnee ? Charte.rouge : Charte.ambre,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Etiquette(s.typeLibelle, ton: s.venteAbandonnee ? Ton.rouge : Ton.ambre),
              Text(s.moment, style: const TextStyle(color: Charte.gris, fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            Text(s.produitLibelle.isEmpty ? 'Produit inconnu' : s.produitLibelle,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Charte.encre)),
            Text('${s.produitCip.isEmpty ? '' : 'CIP ${s.produitCip} · '}Quantité ${grouperMilliers(s.quantite)}',
                style: const TextStyle(color: Charte.gris, fontSize: 13)),
            if (s.venteRef.isNotEmpty) Text('Vente ${s.venteRef}', style: const TextStyle(color: Charte.encre, fontSize: 13)),
            Text(
              'Par ${s.utilisateur.isEmpty ? '—' : s.utilisateur}'
              '${s.utilisateurOrigine.isNotEmpty && s.utilisateurOrigine != s.utilisateur ? ' · vente ouverte par ${s.utilisateurOrigine}' : ''}',
              style: const TextStyle(color: Charte.gris, fontSize: 13),
            ),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------------------------------------------
// Ventes modifiées
// ---------------------------------------------------------------------------------------------------------------

String montantOuTiret(int? v) => v == null ? '—' : formaterMontant(v);

class VentesModifieesScreen extends StatelessWidget {
  final DateTime Function() maintenant;
  const VentesModifieesScreen({super.key, this.maintenant = DateTime.now});

  @override
  Widget build(BuildContext context) => EcranJournalVague1<VenteModifiee>(
        titre: 'Ventes modifiées',
        indicationRecherche: 'N° de vente, produit ou CIP',
        maintenant: maintenant,
        types: const [('', 'Tous'), ('PRODUITS', 'Produits'), ('INFOS', 'Infos'), ('DATE', 'Date')],
        charger: (ctx, f, start) => ApiJournaux.modifiees(ctx, f, start: start),
        texteVide: 'Aucune vente modifiée sur cette période.',
        detail: (v) => VenteModifieeDetailScreen(vente: v),
        colonnes: const [
          Colonne('Date', flex: 3),
          Colonne('Type', flex: 4),
          Colonne('Vente', flex: 3),
          Colonne('Par', flex: 3),
          Colonne('Avant', flex: 2, droite: true),
          Colonne('Après', flex: 2, droite: true),
          Colonne('Description', flex: 5),
        ],
        cellules: (v) => [v.moment, v.typeLibelle, v.venteRef, v.utilisateur, montantOuTiret(v.montantAvant), montantOuTiret(v.montantApres), v.description],
        carte: (context, v, ouvrir) => CarteBande(
          key: Key('vente_modifiee_${v.id}'),
          bande: Charte.navy2,
          onTap: ouvrir,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Etiquette(v.typeLibelle),
                  Text(v.moment, style: const TextStyle(color: Charte.gris, fontSize: 13)),
                ]),
                const SizedBox(height: 4),
                Text('Vente ${v.venteRef.isEmpty ? '—' : v.venteRef}${v.venteDate.isEmpty ? '' : ' du ${v.venteDate}'}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Charte.encre)),
                if (v.montantAvant != null || v.montantApres != null)
                  Text('${montantOuTiret(v.montantAvant)} → ${montantOuTiret(v.montantApres)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: (v.ecart ?? 0) < 0 ? Charte.rougeTexte : Charte.encre)),
                Text('Par ${v.utilisateur.isEmpty ? '—' : v.utilisateur}', style: const TextStyle(color: Charte.gris, fontSize: 13)),
                if (v.description.isNotEmpty)
                  Text(v.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Charte.gris, fontSize: 13)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Charte.gris),
          ]),
        ),
      );
}

/// Détail d'une vente modifiée : en-tête, montants avant / après, lignes modifiées.
class VenteModifieeDetailScreen extends StatelessWidget {
  final VenteModifiee vente;
  const VenteModifieeDetailScreen({super.key, required this.vente});

  @override
  Widget build(BuildContext context) {
    final v = vente;
    String avantApres(int? a, int? b, String Function(int) f) => '${a == null ? '—' : f(a)} → ${b == null ? '—' : f(b)}';
    return Scaffold(
      appBar: AppBar(title: const Text('Vente modifiée')),
      body: ListView(key: const Key('defilement_detail_vente'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        CarteSection(
          titre: 'Vente ${v.venteRef.isEmpty ? '—' : v.venteRef}',
          icone: Icons.receipt_long_outlined,
          enfants: [
            LigneDetail('Modification', v.typeLibelle),
            if (v.venteDate.isNotEmpty) LigneDetail('Vente du', v.venteDate),
            LigneDetail('Modifiée le', v.moment),
            LigneDetail('Par', v.utilisateur.isEmpty ? '—' : v.utilisateur),
            const Divider(height: 16),
            LigneDetail('Montant avant', montantOuTiret(v.montantAvant), gras: true),
            LigneDetail('Montant après', montantOuTiret(v.montantApres), gras: true),
            if (v.ecart != null)
              LigneDetail('Écart', formaterMontant(v.ecart), couleur: v.ecart! < 0 ? Charte.rougeTexte : Charte.vertTexte),
            if (v.description.isNotEmpty) ...[
              const Divider(height: 16),
              Text(v.description, key: const Key('detail_description'), style: const TextStyle(color: Charte.encre, fontSize: 14)),
            ],
          ],
        ),
        const TitreSection('Lignes modifiées'),
        if (v.lignes.isEmpty)
          const EtatVide(titre: 'Aucune ligne de produit modifiée', texte: 'Seules les informations de la vente ont changé.')
        else
          for (final l in v.lignes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CarteBande(
                bande: switch (l.action) {
                  'RETRAIT' => Charte.rouge,
                  'AJOUT' => Charte.vert,
                  _ => Charte.ambre,
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    Etiquette(l.actionLibelle, ton: switch (l.action) {
                      'RETRAIT' => Ton.rouge,
                      'AJOUT' => Ton.vert,
                      _ => Ton.ambre,
                    }),
                  ]),
                  const SizedBox(height: 4),
                  Text(l.produitLibelle.isEmpty ? 'Produit' : l.produitLibelle,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Charte.encre)),
                  if (l.produitCip.isNotEmpty) Text('CIP ${l.produitCip}', style: const TextStyle(color: Charte.gris, fontSize: 13)),
                  if (l.qteAvant != null || l.qteApres != null) LigneDetail('Quantité', avantApres(l.qteAvant, l.qteApres, grouperMilliers)),
                  if (l.puAvant != null || l.puApres != null) LigneDetail('Prix unitaire', avantApres(l.puAvant, l.puApres, formaterMontant)),
                  if (l.montantAvant != null || l.montantApres != null)
                    LigneDetail('Montant', avantApres(l.montantAvant, l.montantApres, formaterMontant)),
                ]),
              ),
            ),
      ]),
    );
  }
}
