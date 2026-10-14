// lib/nouvelle_interface/modules/commun.dart
// Briques COMMUNES aux modules refaits de la nouvelle interface (lot 1) et aux nouveaux menus (vague 1) :
//  - chargement suivi : une seule requête « vivante » par écran ; la réponse d'une requête remplacée (nouvelle
//    période, nouvelle recherche, Réessayer) est ignorée ;
//  - états clairs : chargement, vide, erreur avec « Réessayer », qui distingue serveur injoignable, délai, session
//    expirée (le retour à la connexion reste celui d'ApiService / AuthProvider), erreur du serveur, accès refusé ;
//  - chiffres clés en cartes ; liste en cartes sur téléphone, tableau dense sur tablette ;
//  - filtres dans une feuille du bas, exports dans un menu unique ;
//  - champ de recherche contrôlé (longueur, caractères, anti-rebond).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/saisie.dart';
import '../charte.dart';
import '../composants.dart';

/// Rappel d'une session invalide, comme les écrans d'origine (en plus du traitement global d'ApiService).
VoidCallback sessionInvalide(BuildContext context) => Provider.of<AuthProvider>(context, listen: false).forceLogout;

/// Largeur (dp) à partir de laquelle les listes passent en tableau dense.
const largeurTableau = 720.0;

/// « 1 245 » (espaces insécables entre les milliers).
String formaterNombre(num n) {
  final t = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < t.length; i++) {
    if (i > 0 && (t.length - i) % 3 == 0) b.write('\u00a0');
    b.write(t[i]);
  }
  return b.toString();
}

// ---------------------------------------------------------------------------------------------------------------
// Chargement suivi
// ---------------------------------------------------------------------------------------------------------------

/// Données [T] d'un écran : chargement en cours, dernier résultat, dernier échec.
mixin ChargementSuivi<W extends StatefulWidget, T> on State<W> {
  T? donnees;
  bool enCours = false;
  Object? erreur;
  int _generation = 0;

  /// Le chargement a-t-il abouti au moins une fois (succès) ?
  bool charge = false;

  /// Lance [appel] ; toute requête précédente encore en route est abandonnée (sa réponse sera ignorée).
  Future<void> charger(Future<T?> Function() appel, {bool garder = false}) async {
    final g = ++_generation;
    setState(() {
      enCours = true;
      erreur = null;
      if (!garder) donnees = null;
    });
    try {
      final r = await appel();
      if (!mounted || g != _generation) return;
      setState(() {
        donnees = r;
        charge = true;
        enCours = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        erreur = e;
        enCours = false;
      });
    }
  }

  /// Abandonne la requête en cours (sa réponse sera ignorée) et revient à l'état initial.
  void abandonner() {
    _generation++;
    setState(() {
      enCours = false;
      erreur = null;
      donnees = null;
      charge = false;
    });
  }
}

// ---------------------------------------------------------------------------------------------------------------
// États : chargement, vide, erreur
// ---------------------------------------------------------------------------------------------------------------

class EtatChargement extends StatelessWidget {
  final String texte;
  const EtatChargement({super.key = const Key('etat_chargement'), this.texte = 'Chargement…'});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(texte, textAlign: TextAlign.center, style: const TextStyle(color: Charte.gris, fontSize: 14)),
        ]),
      );
}

class EtatVide extends StatelessWidget {
  final String titre;
  final String? texte;
  final IconData icone;
  const EtatVide({super.key = const Key('etat_vide'), required this.titre, this.texte, this.icone = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconeMenu(icone, taille: 56),
          const SizedBox(height: 12),
          Text(titre, textAlign: TextAlign.center, style: const TextStyle(color: Charte.encre, fontSize: 16, fontWeight: FontWeight.bold)),
          if (texte != null) ...[
            const SizedBox(height: 4),
            Text(texte!, textAlign: TextAlign.center, style: const TextStyle(color: Charte.gris, fontSize: 14)),
          ],
        ]),
      );
}

/// Cause d'un échec, telle que l'écran l'explique.
enum CauseErreur { reseau, delai, session, serveur, droit, autre }

class DiagnosticErreur {
  final CauseErreur cause;
  final String titre;
  final String message;
  final IconData icone;
  const DiagnosticErreur(this.cause, this.titre, this.message, this.icone);

  static DiagnosticErreur de(Object e) {
    if (e is! ApiLoadException) {
      return const DiagnosticErreur(CauseErreur.autre, 'Chargement impossible', 'Une erreur inattendue est survenue.', Icons.error_outline);
    }
    return switch (e.nature) {
      NatureErreur.reseau => DiagnosticErreur(CauseErreur.reseau, 'Serveur injoignable', e.message, Icons.wifi_off),
      NatureErreur.delai => DiagnosticErreur(CauseErreur.delai, 'Le serveur ne répond pas', e.message, Icons.hourglass_empty),
      NatureErreur.session =>
        const DiagnosticErreur(CauseErreur.session, 'Session expirée', 'Votre session a expiré : reconnectez-vous.', Icons.lock_clock),
      NatureErreur.serveur => DiagnosticErreur(CauseErreur.serveur, 'Erreur du serveur', e.message, Icons.dns_outlined),
      NatureErreur.droit => DiagnosticErreur(CauseErreur.droit, 'Droit manquant', e.message, Icons.lock_outline),
      NatureErreur.refus || NatureErreur.reponse => DiagnosticErreur(CauseErreur.autre, 'Chargement impossible', e.message, Icons.error_outline),
    };
  }
}

/// Échec de chargement : cause en titre, explication, « Réessayer » (sauf droit manquant : réessayer ne changerait
/// rien ; sauf aussi sans [reessayer]).
class EtatErreur extends StatelessWidget {
  final Object erreur;
  final VoidCallback? reessayer;
  const EtatErreur({super.key = const Key('etat_erreur'), required this.erreur, this.reessayer});

  @override
  Widget build(BuildContext context) {
    final d = DiagnosticErreur.de(erreur);
    final droit = d.cause == CauseErreur.droit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Encadre(titre: d.titre, texte: d.message, icone: d.icone, avertissement: droit, cleTitre: Key('erreur_${d.cause.name}')),
        if (reessayer != null && !droit) ...[
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(
              key: const Key('bouton_reessayer'),
              onPressed: reessayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Chiffres clés, lignes de détail
// ---------------------------------------------------------------------------------------------------------------

/// Chiffre clé sur carte blanche ([enAvant] : carte ambre). Libellé, valeur, précision.
class ChiffreCle extends StatelessWidget {
  final String libelle;
  final String valeur;
  final String? detail;
  final bool enAvant;

  /// Clé de la valeur (tests de non-régression).
  final String? id;
  const ChiffreCle({super.key, required this.libelle, required this.valeur, this.detail, this.enAvant = false, this.id});

  @override
  Widget build(BuildContext context) {
    final fg = enAvant ? Charte.surAmbre : Charte.encre;
    final secondaire = enAvant ? Charte.surAmbre : Charte.gris;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: enAvant ? Charte.ambre : Charte.blanc,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(libelle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: secondaire, fontSize: 12.5, fontWeight: FontWeight.w600)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(valeur,
              key: id == null ? null : Key('chiffre_$id'), maxLines: 1, style: TextStyle(color: fg, fontSize: 19, fontWeight: FontWeight.w800)),
        ),
        if (detail != null)
          Text(detail!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: secondaire, fontSize: 12)),
      ]),
    );
  }
}

/// Ligne « libellé … valeur » d'une carte de détail.
class LigneDetail extends StatelessWidget {
  final String libelle;
  final String valeur;
  final bool gras;
  final Color? couleur;
  const LigneDetail(this.libelle, this.valeur, {super.key, this.gras = false, this.couleur});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(libelle, style: TextStyle(color: gras ? Charte.encre : Charte.grisTexte, fontSize: 14, fontWeight: gras ? FontWeight.bold : FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(valeur,
                textAlign: TextAlign.right,
                style: TextStyle(color: couleur ?? Charte.encre, fontSize: 14.5, fontWeight: gras ? FontWeight.w800 : FontWeight.w600)),
          ),
        ]),
      );
}

// ---------------------------------------------------------------------------------------------------------------
// Listes : cartes (téléphone) ou tableau dense (tablette)
// ---------------------------------------------------------------------------------------------------------------

/// Colonne du tableau dense.
class Colonne {
  final String titre;
  final int flex;
  final bool droite;
  const Colonne(this.titre, {this.flex = 2, this.droite = false});
}

/// Carte d'une ligne de liste (téléphone) : titre, étiquette, lignes secondaires, valeur mise en avant.
class CarteLigne extends StatelessWidget {
  final String titre;
  final List<String> lignes;
  final String? valeur;
  final String? libelleValeur;
  final Widget? etiquette;
  final Widget? pied;
  final Color? bande;
  final VoidCallback? onTap;

  /// Action en fin de carte (menu « ⋮ »…), à la place du chevron.
  final Widget? action;
  const CarteLigne(
      {super.key, required this.titre, this.lignes = const [], this.valeur, this.libelleValeur, this.etiquette, this.pied, this.bande, this.onTap, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CarteBande(
          bande: bande,
          onTap: onTap,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Charte.encre)),
                if (etiquette != null) Padding(padding: const EdgeInsets.only(top: 4), child: etiquette!),
                for (final l in lignes) Padding(padding: const EdgeInsets.only(top: 3), child: Text(l, style: const TextStyle(fontSize: 13, color: Charte.gris))),
                if (pied != null) pied!,
              ]),
            ),
            if (valeur != null) ...[
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (libelleValeur != null) Text(libelleValeur!, style: const TextStyle(fontSize: 12, color: Charte.gris)),
                Text(valeur!, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Charte.navy)),
              ]),
            ],
            if (action != null)
              action!
            else if (onTap != null)
              const Padding(padding: EdgeInsets.only(left: 4, top: 2), child: Icon(Icons.chevron_right, color: Charte.gris)),
          ]),
        ),
      );
}

/// Tableau dense (tablette) : en-tête gris, lignes ≥ 48 dp, touchables si [onTap].
class TableauDense extends StatelessWidget {
  final List<Colonne> colonnes;
  final List<List<String>> lignes;
  final void Function(int index)? onTap;

  /// Dernière ligne en gras (total).
  final List<String>? total;

  /// Action en fin de ligne (menu « ⋮ »…), à la place du chevron ; [largeurFin] : sa largeur.
  final Widget Function(int index)? fin;
  final double largeurFin;
  const TableauDense({super.key, required this.colonnes, required this.lignes, this.onTap, this.total, this.fin, this.largeurFin = 48});

  Widget _ligne(List<String> cellules, {bool entete = false, bool gras = false, int? index}) => Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          for (var c = 0; c < colonnes.length; c++)
            Expanded(
              flex: colonnes[c].flex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  c < cellules.length ? cellules[c] : '',
                  textAlign: colonnes[c].droite ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontSize: entete ? 12.5 : 14,
                    color: entete ? Charte.gris : Charte.encre,
                    fontWeight: entete || gras ? FontWeight.bold : (c == 0 ? FontWeight.w600 : FontWeight.normal),
                    letterSpacing: entete ? 0.4 : 0,
                  ),
                ),
              ),
            ),
          if (fin != null)
            SizedBox(width: largeurFin, child: index == null ? null : fin!(index))
          else if (onTap != null)
            SizedBox(width: 24, child: entete || gras ? null : const Icon(Icons.chevron_right, color: Charte.gris, size: 20)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('tableau_dense'),
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(color: Charte.grisClair, child: _ligne([for (final c in colonnes) c.titre.toUpperCase()], entete: true)),
          for (var i = 0; i < lignes.length; i++)
            Material(
              color: i.isOdd ? Charte.page : Charte.blanc,
              child: InkWell(onTap: onTap == null ? null : () => onTap!(i), child: _ligne(lignes[i], index: i)),
            ),
          if (total != null)
            Container(
              decoration: const BoxDecoration(color: Charte.bleuClair, border: Border(top: BorderSide(color: Charte.bordure))),
              child: _ligne(total!, gras: true),
            ),
        ]),
      );
}

/// Liste en cartes sur téléphone, en tableau dense à partir de [largeurTableau] dp.
class ListeOuTableau extends StatelessWidget {
  final int nombre;
  final Widget Function(int index) carte;
  final List<Colonne> colonnes;
  final List<String> Function(int index) cellules;
  final void Function(int index)? onTap;
  final List<String>? total;

  /// Action en fin de ligne du tableau (voir [TableauDense.fin]).
  final Widget Function(int index)? fin;
  const ListeOuTableau(
      {super.key, required this.nombre, required this.carte, required this.colonnes, required this.cellules, this.onTap, this.total, this.fin});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= largeurTableau) {
          return TableauDense(colonnes: colonnes, lignes: [for (var i = 0; i < nombre; i++) cellules(i)], onTap: onTap, total: total, fin: fin);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < nombre; i++) carte(i)]);
      });
}

/// Puces à choix unique (type, regroupement…) : bleu nuit et texte blanc si choisie, sans coche.
class PucesChoix<T> extends StatelessWidget {
  final List<(T, String)> choix;
  final T valeur;
  final ValueChanged<T> onChanged;

  /// Clé de chaque puce (tests).
  final Key Function(T valeur, String libelle)? cle;
  const PucesChoix({super.key, required this.choix, required this.valeur, required this.onChanged, this.cle});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 0, children: [
        for (final (v, libelle) in choix)
          ChoiceChip(
            key: cle?.call(v, libelle),
            label: Text(libelle, style: TextStyle(color: v == valeur ? Charte.blanc : Charte.navy)),
            selected: v == valeur,
            showCheckmark: false,
            onSelected: (_) => onChanged(v),
          ),
      ]);
}

/// Bandeau « 12 lignes affichées sur 230 » et bouton « Afficher plus » (pagination explicite : un appel par appui).
class PiedPagination extends StatelessWidget {
  final int affichees;
  final int total;
  final bool enCours;
  final VoidCallback onPlus;
  const PiedPagination({super.key, required this.affichees, required this.total, required this.enCours, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    final reste = total - affichees;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text('${formaterNombre(affichees)} ${affichees > 1 ? 'lignes affichées' : 'ligne affichée'} sur ${formaterNombre(total)}',
            style: const TextStyle(color: Charte.gris)),
        if (reste > 0) ...[
          const SizedBox(height: 8),
          enCours
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
              : OutlinedButton.icon(
                  key: const Key('bouton_afficher_plus'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: onPlus,
                  icon: const Icon(Icons.expand_more),
                  label: Text('Afficher plus (${formaterNombre(reste)})'),
                ),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Filtres (feuille du bas) et exports (menu unique)
// ---------------------------------------------------------------------------------------------------------------

/// Bouton « Filtres » de la barre (pastille : nombre de filtres actifs).
class BoutonFiltres extends StatelessWidget {
  final int actifs;
  final VoidCallback onPressed;
  const BoutonFiltres({super.key = const Key('bouton_filtres'), required this.actifs, required this.onPressed});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: actifs == 0 ? 'Filtres' : 'Filtres ($actifs actif${actifs > 1 ? 's' : ''})',
        onPressed: onPressed,
        icon: Badge(
          isLabelVisible: actifs > 0,
          backgroundColor: Charte.ambre,
          textColor: Charte.surAmbre,
          label: Text('$actifs'),
          child: const Icon(Icons.tune),
        ),
      );
}

/// Feuille du bas des filtres : [contenu] (construit avec un setState local), « Effacer » et « Appliquer ».
/// Renvoie vrai si l'utilisateur a appliqué.
Future<bool> ouvrirFeuilleFiltres(
  BuildContext context, {
  required String titre,
  required Widget Function(BuildContext context, StateSetter setState) contenu,
  required VoidCallback effacer,
  bool Function()? valider,
  String libelleEffacer = 'Effacer',
  String libelleAppliquer = 'Appliquer',
}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          key: const Key('feuille_filtres'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(titre, style: const TextStyle(color: Charte.navy, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            contenu(ctx, setState),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('filtres_effacer'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => setState(effacer),
                  child: Text(libelleEffacer, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const Key('filtres_appliquer'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () {
                    if (valider != null && !valider()) return;
                    Navigator.of(ctx).pop(true);
                  },
                  child: Text(libelleAppliquer, textAlign: TextAlign.center),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
  return r ?? false;
}

/// Une action d'export (PDF existant…).
class ActionExport {
  final String libelle;
  final IconData icone;
  final Future<void> Function() action;
  const ActionExport(this.libelle, this.icone, this.action);
}

/// Menu unique des exports (barre de l'écran).
class MenuExports extends StatelessWidget {
  final List<ActionExport> actions;
  const MenuExports({super.key = const Key('menu_exports'), required this.actions});

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
        tooltip: 'Exporter',
        // Blanc explicite : le thème des menus (bleu nuit) rendrait l'icône invisible sur la barre bleu nuit.
        icon: const Icon(Icons.ios_share, color: Charte.blanc),
        onSelected: (i) => actions[i].action(),
        itemBuilder: (_) => [
          for (var i = 0; i < actions.length; i++)
            PopupMenuItem<int>(
              key: Key('export_$i'),
              value: i,
              child: Row(children: [Icon(actions[i].icone, color: Charte.navy), const SizedBox(width: 12), Flexible(child: Text(actions[i].libelle))]),
            ),
        ],
      );
}

// ---------------------------------------------------------------------------------------------------------------
// Recherche contrôlée
// ---------------------------------------------------------------------------------------------------------------

/// Champ de recherche contrôlé : longueur maximale (Saisie.maxRecherche), caractères autorisés (lettres, chiffres,
/// espace et ponctuation courante des libellés), anti-rebond de [antiRebond] ; [onRecherche] reçoit le texte nettoyé
/// (aussi à la validation du clavier et à l'effacement).
class ChampRecherche extends StatefulWidget {
  final TextEditingController controleur;
  final String libelle;
  final String? aide;
  final ValueChanged<String> onRecherche;
  final Duration antiRebond;
  final bool enCours;
  final FocusNode? focus;
  const ChampRecherche({
    super.key,
    required this.controleur,
    required this.libelle,
    this.aide,
    required this.onRecherche,
    this.antiRebond = const Duration(milliseconds: 500),
    this.enCours = false,
    this.focus,
  });

  /// Caractères acceptés dans une recherche.
  static final caracteres = RegExp(r"[\p{L}\p{N} .,'’/%+()&*_#-]", unicode: true);

  static List<TextInputFormatter> get formatteurs => [
        ...Saisie.rechercheFormatters,
        FilteringTextInputFormatter.allow(caracteres),
      ];

  @override
  State<ChampRecherche> createState() => _ChampRechercheState();
}

class _ChampRechercheState extends State<ChampRecherche> {
  Timer? _minuterie;
  String _dernier = '';

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  void _envoyer() {
    _minuterie?.cancel();
    final t = Saisie.recherche(widget.controleur.text);
    if (t == _dernier) return;
    _dernier = t;
    widget.onRecherche(t);
  }

  void _surSaisie(String _) {
    setState(() {});
    _minuterie?.cancel();
    _minuterie = Timer(widget.antiRebond, _envoyer);
  }

  @override
  Widget build(BuildContext context) => TextField(
        key: const Key('champ_recherche'),
        controller: widget.controleur,
        focusNode: widget.focus,
        inputFormatters: ChampRecherche.formatteurs,
        textInputAction: TextInputAction.search,
        onChanged: _surSaisie,
        onSubmitted: (_) {
          _dernier = '\u0000'; // validation explicite : relance même si le texte n'a pas changé
          _envoyer();
        },
        decoration: InputDecoration(
          labelText: widget.libelle,
          hintText: widget.aide,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: widget.enCours
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : (widget.controleur.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        widget.controleur.clear();
                        setState(() {});
                        _envoyer();
                      },
                    )),
        ),
      );
}
