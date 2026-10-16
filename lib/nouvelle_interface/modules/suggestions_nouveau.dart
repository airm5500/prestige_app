// lib/nouvelle_interface/modules/suggestions_nouveau.dart
// Suggestions de commande de la nouvelle interface. Mêmes données et MÊMES ÉCRITURES que l'écran d'origine
// (Suggestions, lib/donnees/suggestions_donnees.dart) :
//  - liste : GET /suggestion/list?limit=50 (chargée à l'ouverture, rechargée au retour d'une suggestion) ;
//  - ouverture d'une suggestion : GET /suggestion/set-pending/{id} puis la page de la suggestion ;
//  - lignes et montants : GET /suggestion/list/items?orderId=&limit=9999 puis GET /suggestion/amount/{id} ;
//  - quantité : POST /suggestion/item/update-qte-cmde {itemId, qte}, entier de 0 à 99 999 (refus sinon), puis
//    relecture des montants ;
//  - suppressions (ligne, suggestion) : DELETE, toujours après confirmation ;
//  - export CSV « cip;qte » dans le menu Exporter (et dans le menu ⋮ de chaque suggestion de la liste).
// En plus : anti double envoi (un appui de plus pendant un envoi ne renvoie rien), message de résultat clair
// (réussi / non enregistré et pourquoi). Aucune commande PharmaML (prévue plus tard).
// 3.11.0 (demandes du pharmacien) : liste sans compteurs (nombre de suggestions, en cours, grossistes), statut en
// face du grossiste, « Créée le … · Réf. … » sur une seule ligne ; dans une suggestion, curseur placé
// automatiquement dans la quantité du premier article à l'ouverture (texte sélectionné : la saisie le remplace), et
// après la saisie d'une quantité (touche « Suivant » du clavier) le curseur passe à l'article suivant.
import 'package:flutter/material.dart';

import '../../donnees/suggestions_donnees.dart';
import '../../models/suggestion_amount_model.dart';
import '../../models/suggestion_item_model.dart';
import '../../models/suggestion_model.dart';
import '../../utils/date_formatter.dart';
import '../../utils/saisie.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'commun_lot2.dart';

/// Export CSV d'une suggestion (relit ses lignes, comme l'écran d'origine), avec message de résultat.
Future<void> exporterCsvSuggestion(BuildContext context, Suggestion s) async {
  try {
    final lignes = await Suggestions.lignes(context, s.id, onSessionInvalid: sessionInvalide(context));
    if (!context.mounted) return;
    if (lignes == null) {
      messageResultat(context, 'Export impossible : réponse inattendue du serveur.', echec: true);
      return;
    }
    final nom = await Suggestions.enregistrerCsv(Suggestions.nomFichier(s), Suggestions.csv(lignes));
    if (!context.mounted) return;
    if (nom == null) {
      messageResultat(context, 'Export impossible : permission de stockage refusée.', echec: true);
    } else {
      messageResultat(context, 'Fichier enregistré dans Téléchargements : $nom');
    }
  } catch (e) {
    if (context.mounted) messageResultat(context, 'Export impossible : ${DiagnosticErreur.de(e).message}', echec: true);
  }
}

class SuggestionsNouveau extends StatefulWidget {
  const SuggestionsNouveau({super.key});

  @override
  State<SuggestionsNouveau> createState() => _SuggestionsNouveauState();
}

class _SuggestionsNouveauState extends State<SuggestionsNouveau> with ChargementSuivi<SuggestionsNouveau, List<Suggestion>> {
  /// Suggestions en cours d'ouverture ou de suppression (anti double appui).
  final _actions = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger({bool garder = false}) =>
      charger(() async => await Suggestions.liste(context, onSessionInvalid: sessionInvalide(context)) ?? const <Suggestion>[], garder: garder);

  Future<void> _ouvrir(Suggestion s) async {
    if (!_actions.add(s.id)) return;
    setState(() {});
    try {
      await Suggestions.ouvrir(context, s.id, onSessionInvalid: sessionInvalide(context));
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SuggestionDetailNouveau(suggestion: s)));
      if (mounted) _charger(garder: true);
    } catch (e) {
      if (mounted) messageResultat(context, 'Suggestion non ouverte : ${DiagnosticErreur.de(e).message}', echec: true);
    } finally {
      _actions.remove(s.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _supprimer(Suggestion s) async {
    if (_actions.contains(s.id)) return;
    final ok = await confirmer(context, titre: 'Confirmation', texte: 'Voulez-vous vraiment supprimer cette suggestion ?\n\n${s.grossiste} · ${s.name}');
    if (!ok || !mounted || !_actions.add(s.id)) return;
    setState(() {});
    try {
      await Suggestions.supprimer(context, s.id, onSessionInvalid: sessionInvalide(context));
      if (!mounted) return;
      messageResultat(context, 'Suggestion supprimée : ${s.grossiste} · ${s.name}');
      _charger(garder: true);
    } catch (e) {
      if (mounted) messageResultat(context, 'Suggestion non supprimée : ${DiagnosticErreur.de(e).message}', echec: true);
    } finally {
      _actions.remove(s.id);
      if (mounted) setState(() {});
    }
  }

  Widget _menu(Suggestion s) => _actions.contains(s.id)
      ? const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)))
      : IconButton(
          key: Key('suggestion_menu_${s.id}'),
          tooltip: 'Actions sur la suggestion',
          icon: const Icon(Icons.more_vert, color: Charte.navy),
          onPressed: () => _actionsSuggestion(s),
        );

  /// Actions d'une suggestion dans une feuille du bas : ouvrir, exporter en CSV, supprimer (avec confirmation).
  Future<void> _actionsSuggestion(Suggestion s) async {
    final choix = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(key: const Key('suggestion_actions'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('${s.grossiste} · ${s.name}', style: const TextStyle(color: Charte.navy, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            key: const Key('suggestion_ouvrir'),
            leading: const Icon(Icons.folder_open_outlined, color: Charte.navy),
            title: const Text('Ouvrir la suggestion'),
            onTap: () => Navigator.of(ctx).pop(0),
          ),
          ListTile(
            key: const Key('suggestion_exporter'),
            leading: const Icon(Icons.download_outlined, color: Charte.navy),
            title: const Text('Exporter (CSV)'),
            onTap: () => Navigator.of(ctx).pop(1),
          ),
          ListTile(
            key: const Key('suggestion_supprimer'),
            leading: const Icon(Icons.delete_outline, color: Charte.rougeTexte),
            title: const Text('Supprimer la suggestion', style: TextStyle(color: Charte.rougeTexte)),
            onTap: () => Navigator.of(ctx).pop(2),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || choix == null) return;
    switch (choix) {
      case 0:
        await _ouvrir(s);
      case 1:
        await exporterCsvSuggestion(context, s);
      case 2:
        await _supprimer(s);
    }
  }

  static bool _enCours(Suggestion s) => s.status == 'pending';

  /// « Créée le 14/10/2026 · Réf. SUG-12 » (une seule ligne).
  static String ligneReference(Suggestion s) => [if (_date(s).isNotEmpty) 'Créée le ${_date(s)}', 'Réf. ${s.name}'].join(' · ');

  /// Carte d'une suggestion : grossiste et statut sur la même ligne, puis date et référence sur une ligne.
  Widget _carte(Suggestion s) => Padding(
        key: Key('suggestion_${s.id}'),
        padding: const EdgeInsets.only(bottom: 8),
        child: CarteBande(
          bande: _enCours(s) ? Charte.vert : null,
          onTap: () => _ouvrir(s),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Text(s.grossiste, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Charte.encre))),
                  const SizedBox(width: 6),
                  KeyedSubtree(
                    key: Key('suggestion_statut_${s.id}'),
                    child: _enCours(s) ? const Etiquette('En cours', ton: Ton.vert) : Etiquette(s.status, ton: Ton.gris),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(ligneReference(s),
                      key: Key('suggestion_reference_${s.id}'), style: const TextStyle(fontSize: 13, color: Charte.gris)),
                ),
              ]),
            ),
            _menu(s),
          ]),
        ),
      );
  static String _date(Suggestion s) => s.dtCreated == null ? '' : DateFormatter.toDisplayFormat(s.dtCreated!);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Suggestions de Commande'), actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualiser', onPressed: enCours ? null : _charger),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: _corps()),
        ),
      );

  List<Widget> _corps() {
    if (enCours && donnees == null) return const [EtatChargement(texte: 'Chargement des suggestions…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <Suggestion>[];
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucune suggestion de commande', texte: 'Aucune suggestion de commande disponible.', icone: Icons.lightbulb_outline)];
    }
    return [
      const Text('Touchez une suggestion pour l\'ouvrir et ajuster les quantités.', style: TextStyle(color: Charte.grisTexte, fontSize: 13, fontWeight: FontWeight.w600)),
      const TitreSection('Suggestions'),
      ListeOuTableau(
        nombre: l.length,
        onTap: (i) => _ouvrir(l[i]),
        fin: (i) => _menu(l[i]),
        colonnes: const [
          Colonne('Grossiste', flex: 4),
          Colonne('Référence', flex: 4),
          Colonne('Créée le', flex: 2),
          Colonne('Statut', flex: 2),
        ],
        cellules: (i) => [l[i].grossiste, l[i].name, _date(l[i]), _enCours(l[i]) ? 'En cours' : l[i].status],
        carte: (i) => _carte(l[i]),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Une suggestion : lignes, quantités, montants
// ---------------------------------------------------------------------------------------------------------------

class SuggestionDetailNouveau extends StatefulWidget {
  final Suggestion suggestion;
  const SuggestionDetailNouveau({super.key, required this.suggestion});

  @override
  State<SuggestionDetailNouveau> createState() => _SuggestionDetailNouveauState();
}

class _SuggestionDetailNouveauState extends State<SuggestionDetailNouveau> {
  List<SuggestionItem>? _lignes;
  SuggestionAmount? _montant;
  bool _enCours = true;
  Object? _erreur;
  int _generation = 0;

  /// Champs de quantité (un par ligne) et dernière quantité enregistrée par ligne.
  final _champs = <String, TextEditingController>{};
  final _erreursChamp = <String, String>{};
  final _enregistrees = <String>{};

  /// Lignes en cours d'envoi (quantité ou suppression) : anti double envoi.
  final _envois = <String>{};

  /// Focus de chaque champ de quantité (curseur automatique, passage à l'article suivant).
  final _focus = <String, FocusNode>{};
  bool _focusInitialPose = false;

  FocusNode _noeud(String itemId) => _focus[itemId] ??= FocusNode(debugLabel: 'qte_$itemId');

  /// Place le curseur dans la quantité de [l] et sélectionne son texte (la saisie remplace la valeur).
  void _placer(SuggestionItem l) {
    final c = _champs[l.itemId];
    if (c != null) c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    _noeud(l.itemId).requestFocus();
  }

  /// Après la saisie de [l] : curseur sur l'article suivant (le dernier ferme le clavier).
  void _suivant(SuggestionItem l) {
    final lignes = _lignes ?? const <SuggestionItem>[];
    final i = lignes.indexWhere((x) => x.itemId == l.itemId);
    if (i >= 0 && i + 1 < lignes.length) {
      _placer(lignes[i + 1]);
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  String get _id => widget.suggestion.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  @override
  void dispose() {
    for (final c in _champs.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// Lignes puis montants (dans cet ordre, comme l'écran d'origine).
  Future<void> _charger() async {
    final g = ++_generation;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final lignes = await Suggestions.lignes(context, _id, onSessionInvalid: sessionInvalide(context));
      if (!mounted || g != _generation) return;
      final montant = await Suggestions.montant(context, _id, onSessionInvalid: sessionInvalide(context));
      if (!mounted || g != _generation) return;
      setState(() {
        _lignes = lignes ?? _lignes ?? const [];
        _montant = montant ?? _montant;
        for (final l in _lignes!) {
          (_champs[l.itemId] ??= TextEditingController()).text = '${l.quantiteSuggeree}';
        }
        _erreursChamp.clear();
        _enCours = false;
      });
      // Curseur automatique dans la quantité du premier article, une seule fois (pas à chaque relecture).
      if (!_focusInitialPose && _lignes!.isNotEmpty) {
        _focusInitialPose = true;
        final premier = _lignes!.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _placer(premier);
        });
      }
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _erreur = e;
        _enCours = false;
      });
    }
  }

  Future<void> _rechargerMontant() async {
    try {
      final m = await Suggestions.montant(context, _id, onSessionInvalid: sessionInvalide(context));
      if (mounted && m != null) setState(() => _montant = m);
    } catch (_) {
      // Montant non relu : l'ancien reste affiché (la quantité, elle, est enregistrée).
    }
  }

  Future<void> _enregistrer(SuggestionItem l) async {
    if (_envois.contains(l.itemId)) return; // déjà en cours d'envoi : rien de plus
    final texte = _champs[l.itemId]?.text ?? '';
    final qte = Suggestions.quantite(texte);
    if (qte == null) {
      setState(() => _erreursChamp[l.itemId] = '0 à ${formaterNombre(Saisie.maxQuantite)}');
      messageResultat(context, Suggestions.messageQuantiteInvalide, echec: true);
      return;
    }
    setState(() {
      _envois.add(l.itemId);
      _erreursChamp.remove(l.itemId);
      _enregistrees.remove(l.itemId);
    });
    try {
      await Suggestions.enregistrerQuantite(context, l.itemId, qte, onSessionInvalid: sessionInvalide(context));
      if (!mounted) return;
      setState(() {
        l.quantiteSuggeree = qte;
        _champs[l.itemId]?.text = '$qte';
        _enregistrees.add(l.itemId);
      });
      messageResultat(context, 'Quantité enregistrée : $qte · ${l.name}');
      await _rechargerMontant();
    } catch (e) {
      if (mounted) messageResultat(context, 'Quantité non enregistrée sur le serveur : ${DiagnosticErreur.de(e).message}', echec: true);
    } finally {
      _envois.remove(l.itemId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _retirer(SuggestionItem l) async {
    if (_envois.contains(l.itemId)) return;
    final ok = await confirmer(context, titre: 'Confirmation', texte: 'Voulez-vous vraiment supprimer cet article de la suggestion ?\n\n${l.name}');
    if (!ok || !mounted || _envois.contains(l.itemId)) return;
    setState(() => _envois.add(l.itemId));
    try {
      await Suggestions.supprimerLigne(context, l.itemId, onSessionInvalid: sessionInvalide(context));
      if (!mounted) return;
      messageResultat(context, 'Article retiré de la suggestion : ${l.name}');
      _envois.remove(l.itemId);
      await _charger();
    } catch (e) {
      if (mounted) messageResultat(context, 'Article non supprimé : ${DiagnosticErreur.de(e).message}', echec: true);
    } finally {
      _envois.remove(l.itemId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.suggestion.grossiste, overflow: TextOverflow.ellipsis), actions: [
          MenuExports(actions: [ActionExport('CSV de la suggestion (cip;qte)', Icons.table_view_outlined, () => exporterCsvSuggestion(context, widget.suggestion))]),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_detail'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: _corps()),
        ),
      );

  List<Widget> _corps() {
    final l = _lignes;
    if (_enCours && l == null) return const [EtatChargement(texte: 'Chargement de la suggestion…')];
    if (_erreur != null && l == null) return [EtatErreur(erreur: _erreur!, reessayer: _charger)];
    final lignes = l ?? const <SuggestionItem>[];
    final quantite = lignes.fold<int>(0, (s, x) => s + x.quantiteSuggeree);
    return [
      Text(widget.suggestion.name, style: const TextStyle(color: Charte.navy, fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (_erreur != null) EtatErreur(erreur: _erreur!, reessayer: _charger),
      GrilleKpi([
        ChiffreCle(libelle: 'Montant Achat', valeur: formaterMontant(_montant?.montantAchat), id: 'montant_achat', enAvant: true),
        ChiffreCle(libelle: 'Montant Vente', valeur: formaterMontant(_montant?.montantVente), id: 'montant_vente'),
        ChiffreCle(libelle: 'Articles', valeur: formaterNombre(lignes.length), id: 'articles'),
        ChiffreCle(libelle: 'Quantité à commander', valeur: formaterNombre(quantite), id: 'quantite'),
      ]),
      if (_enCours) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      const SizedBox(height: 10),
      const Text('Saisissez la quantité (0 à 99 999) puis touchez le bouton Enregistrer.', style: TextStyle(color: Charte.grisTexte, fontSize: 13, fontWeight: FontWeight.w600)),
      const TitreSection('Articles'),
      if (lignes.isEmpty)
        const EtatVide(titre: 'Aucun article', texte: 'Cette suggestion ne contient aucun article.', icone: Icons.inventory_2_outlined)
      else
        LayoutBuilder(
          builder: (context, c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final x in lignes) _ligne(x, large: c.maxWidth >= largeurTableau),
          ]),
        ),
    ];
  }

  Widget _quantite(SuggestionItem l, {required bool large}) {
    final envoi = _envois.contains(l.itemId);
    final ok = _enregistrees.contains(l.itemId);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: TextField(
          key: Key('qte_${l.itemId}'),
          controller: _champs[l.itemId] ??= TextEditingController(text: '${l.quantiteSuggeree}'),
          focusNode: _noeud(l.itemId),
          enabled: !envoi,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: (_lignes?.isNotEmpty ?? false) && _lignes!.last.itemId == l.itemId ? TextInputAction.done : TextInputAction.next,
          inputFormatters: Saisie.entierFormatters(5), // 0 à 99 999
          onChanged: (_) => setState(() {
            _enregistrees.remove(l.itemId);
            _erreursChamp.remove(l.itemId);
          }),
          onSubmitted: (_) {
            _suivant(l);
            _enregistrer(l);
          },
          decoration: InputDecoration(
            labelText: 'Qté à commander',
            isDense: true,
            errorText: _erreursChamp[l.itemId],
            helperText: ok ? 'Enregistrée' : null,
            helperStyle: const TextStyle(color: Charte.vertTexte, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      envoi
          ? const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)))
          : IconButton(
              key: Key('qte_enregistrer_${l.itemId}'),
              tooltip: 'Enregistrer la quantité',
              icon: Icon(ok ? Icons.check_circle : Icons.check, color: ok ? Charte.vertTexte : Charte.navy),
              onPressed: () => _enregistrer(l),
            ),
      IconButton(
        key: Key('ligne_supprimer_${l.itemId}'),
        tooltip: 'Retirer l\'article',
        icon: const Icon(Icons.delete_outline, color: Charte.rougeTexte),
        onPressed: envoi ? null : () => _retirer(l),
      ),
    ]);
  }

  Widget _ligne(SuggestionItem l, {required bool large}) {
    final conso = 'Conso M/M-1/M-2/M-3 : ${l.consoM0}/${l.consoM1}/${l.consoM2}/${l.consoM3} · Moy. ${l.averageConsumption.toStringAsFixed(2)}';
    final prix = 'CIP ${l.cip} · PA ${formaterMontant(l.prixAchat)} · PV ${formaterMontant(l.prixVente)}';
    final infos = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Charte.encre)),
      const SizedBox(height: 3),
      Text(prix, style: const TextStyle(fontSize: 13, color: Charte.gris)),
      Text(conso, style: const TextStyle(fontSize: 13, color: Charte.gris)),
      const SizedBox(height: 3),
      Text('Stock : ${l.stock}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Charte.navy)),
    ]);
    return Padding(
      key: Key('ligne_${l.itemId}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: CarteBande(
        bande: _enregistrees.contains(l.itemId) ? Charte.vert : null,
        child: large
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: infos),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _quantite(l, large: true)),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [infos, const SizedBox(height: 8), _quantite(l, large: false)]),
      ),
    );
  }
}
