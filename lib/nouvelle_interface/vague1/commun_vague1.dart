// lib/nouvelle_interface/vague1/commun_vague1.dart
// Éléments communs des écrans de la vague 1 (nouvelle interface, charte bleu nuit / ambre de charte.dart) :
// contrôle des périodes, sélecteur de période, recherche avec anti-rebond, états chargement / vide / erreur
// (dont « Droit manquant »), puces de choix, tableau dense pour tablette.
// Toutes les zones touchables font au moins 48 dp et portent un libellé.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../charte.dart';
import '../composants.dart';
import 'donnees_vague1.dart';

/// Largeur (dp) à partir de laquelle une liste s'affiche en tableau (tablette).
const largeurTableauVague1 = 720.0;

/// « 14/10/2026 ».
String dateCourte(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

/// « 12,5 % » ; « — » si null.
String pourcent(double? v) => v == null ? '—' : '${v.toStringAsFixed(1).replaceAll('.', ',')} %';

// ---------------------------------------------------------------------------------------------------------------
// Périodes
// ---------------------------------------------------------------------------------------------------------------

/// Plus ancienne date proposée.
final premiereDateVague1 = DateTime(2015, 1, 1);

/// Durée maximale d'une période (le serveur relit les ventes : on évite les années entières sur mobile).
const joursMaxPeriode = 366;

/// Contrôle d'une période : début ≤ fin, aucune date future, au plus [maxJours] jours. Message, ou null si correcte.
String? controlerPeriode(DateTime debut, DateTime fin, {DateTime? maintenant, int maxJours = joursMaxPeriode}) {
  final jour = jourDe(maintenant ?? DateTime.now());
  final d = jourDe(debut), f = jourDe(fin);
  if (d.isAfter(jour) || f.isAfter(jour)) return 'Les dates ne peuvent pas être dans le futur.';
  if (d.isAfter(f)) return 'La date de début doit précéder la date de fin.';
  if (d.isBefore(premiereDateVague1)) return 'Date trop ancienne (avant le ${dateCourte(premiereDateVague1)}).';
  if (f.difference(d).inDays + 1 > maxJours) return 'Période trop longue : $maxJours jours au plus.';
  return null;
}

/// Raccourcis de période (courtes par défaut : aujourd'hui).
enum PeriodeRapide { aujourdhui, hier, septJours, trenteJours }

extension PeriodeRapideTextes on PeriodeRapide {
  String get libelle => switch (this) {
        PeriodeRapide.aujourdhui => 'Aujourd\'hui',
        PeriodeRapide.hier => 'Hier',
        PeriodeRapide.septJours => '7 jours',
        PeriodeRapide.trenteJours => '30 jours',
      };

  (DateTime, DateTime) bornes(DateTime maintenant) {
    final j = jourDe(maintenant);
    return switch (this) {
      PeriodeRapide.aujourdhui => (j, j),
      PeriodeRapide.hier => (j.subtract(const Duration(days: 1)), j.subtract(const Duration(days: 1))),
      PeriodeRapide.septJours => (j.subtract(const Duration(days: 6)), j),
      PeriodeRapide.trenteJours => (j.subtract(const Duration(days: 29)), j),
    };
  }
}

/// Choix d'une date (jamais dans le futur).
Future<DateTime?> choisirDate(BuildContext context, DateTime initiale, {String? aide}) {
  final aujourdhui = jourDe(DateTime.now());
  final init = initiale.isAfter(aujourdhui) ? aujourdhui : (initiale.isBefore(premiereDateVague1) ? premiereDateVague1 : initiale);
  return showDatePicker(
    context: context,
    initialDate: init,
    firstDate: premiereDateVague1,
    lastDate: aujourdhui,
    locale: const Locale('fr', 'FR'),
    helpText: aide,
  );
}

/// Sélecteur de période : « Du … », « Au … » et raccourcis. Contrôle affiché sous les dates (la période fautive
/// n'est pas transmise : [onChanged] n'est appelé qu'avec une période correcte).
class SelecteurPeriodeVague1 extends StatefulWidget {
  final DateTime debut;
  final DateTime fin;
  final void Function(DateTime debut, DateTime fin) onChanged;
  const SelecteurPeriodeVague1({super.key, required this.debut, required this.fin, required this.onChanged});

  @override
  State<SelecteurPeriodeVague1> createState() => _SelecteurPeriodeVague1State();
}

class _SelecteurPeriodeVague1State extends State<SelecteurPeriodeVague1> {
  String? _erreur;
  late DateTime _debut = widget.debut;
  late DateTime _fin = widget.fin;

  @override
  void didUpdateWidget(SelecteurPeriodeVague1 old) {
    super.didUpdateWidget(old);
    if (_erreur == null) {
      _debut = widget.debut;
      _fin = widget.fin;
    }
  }

  void _appliquer(DateTime d, DateTime f) {
    final erreur = controlerPeriode(d, f);
    setState(() {
      _debut = d;
      _fin = f;
      _erreur = erreur;
    });
    if (erreur == null) widget.onChanged(d, f);
  }

  Future<void> _choisir(bool debut) async {
    final d = await choisirDate(context, debut ? _debut : _fin, aide: debut ? 'Date de début' : 'Date de fin');
    if (d == null || !mounted) return;
    _appliquer(debut ? d : _debut, debut ? _fin : d);
  }

  @override
  Widget build(BuildContext context) {
    final maintenant = DateTime.now();
    Widget bouton(String prefixe, DateTime d, bool debut) => OutlinedButton.icon(
          key: Key(debut ? 'periode_debut' : 'periode_fin'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 10)),
          onPressed: () => _choisir(debut),
          icon: const Icon(Icons.event_outlined, size: 18),
          label: Text('$prefixe ${dateCourte(d)}', maxLines: 1, overflow: TextOverflow.ellipsis),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: bouton('Du', _debut, true)),
        const SizedBox(width: 8),
        Expanded(child: bouton('Au', _fin, false)),
      ]),
      if (_erreur != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_erreur!, key: const Key('periode_erreur'), style: const TextStyle(color: Charte.rougeTexte, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 4),
      Wrap(spacing: 6, children: [
        for (final p in PeriodeRapide.values)
          ChoiceChip(
            label: Text(p.libelle),
            selected: _erreur == null && memeJour(p.bornes(maintenant).$1, _debut) && memeJour(p.bornes(maintenant).$2, _fin),
            onSelected: (_) {
              final (d, f) = p.bornes(maintenant);
              _appliquer(d, f);
            },
          ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Recherche avec anti-rebond
// ---------------------------------------------------------------------------------------------------------------

/// Champ de recherche : [onRecherche] n'est appelé qu'après [delai] sans frappe (anti-rebond), avec le texte rogné ;
/// la croix efface tout de suite. 60 caractères au plus.
class ChampRechercheVague1 extends StatefulWidget {
  final String indication;
  final ValueChanged<String> onRecherche;
  final Duration delai;
  final String initial;
  const ChampRechercheVague1({
    super.key,
    required this.indication,
    required this.onRecherche,
    this.delai = const Duration(milliseconds: 450),
    this.initial = '',
  });

  @override
  State<ChampRechercheVague1> createState() => _ChampRechercheVague1State();
}

class _ChampRechercheVague1State extends State<ChampRechercheVague1> {
  late final _texte = TextEditingController(text: widget.initial);
  Timer? _minuterie;
  String _dernier = '';

  @override
  void initState() {
    super.initState();
    _dernier = widget.initial.trim();
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    _texte.dispose();
    super.dispose();
  }

  void _envoyer() {
    final t = _texte.text.trim();
    if (t == _dernier) return;
    _dernier = t;
    widget.onRecherche(t);
  }

  void _modifie(String _) {
    setState(() {}); // croix d'effacement
    _minuterie?.cancel();
    _minuterie = Timer(widget.delai, _envoyer);
  }

  @override
  Widget build(BuildContext context) => TextField(
        key: const Key('recherche_vague1'),
        controller: _texte,
        onChanged: _modifie,
        onSubmitted: (_) {
          _minuterie?.cancel();
          _envoyer();
        },
        textInputAction: TextInputAction.search,
        inputFormatters: [LengthLimitingTextInputFormatter(60)],
        decoration: InputDecoration(
          hintText: widget.indication,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: _texte.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer la recherche',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _minuterie?.cancel();
                    setState(_texte.clear);
                    _envoyer();
                  },
                ),
        ),
      );
}

// ---------------------------------------------------------------------------------------------------------------
// États
// ---------------------------------------------------------------------------------------------------------------

class ChargementVague1 extends StatelessWidget {
  final String texte;
  const ChargementVague1({super.key, this.texte = 'Chargement…'});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 12),
          Text(texte, style: const TextStyle(color: Charte.gris)),
        ]),
      );
}

class VideVague1 extends StatelessWidget {
  final String texte;
  final IconData icone;
  const VideVague1(this.texte, {super.key, this.icone = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(children: [
          Icon(icone, color: Charte.gris, size: 36),
          const SizedBox(height: 8),
          Text(texte, key: const Key('etat_vide'), textAlign: TextAlign.center, style: const TextStyle(color: Charte.gris, fontSize: 15)),
        ]),
      );
}

/// Titre d'une erreur selon sa nature.
String titreErreur(Object e) {
  if (e is! ApiLoadException) return 'Chargement impossible';
  return switch (e.nature) {
    NatureErreur.reseau => 'Serveur injoignable',
    NatureErreur.delai => 'Délai dépassé',
    NatureErreur.serveur => 'Erreur du serveur',
    NatureErreur.session => 'Session expirée',
    NatureErreur.droit => 'Droit manquant',
    NatureErreur.refus => 'Demande refusée',
    NatureErreur.reponse => 'Réponse inattendue',
  };
}

/// Erreur affichée à la place des données (jamais « aucun résultat ») ; « Réessayer » sauf droit manquant.
class ErreurVague1 extends StatelessWidget {
  final Object erreur;
  final VoidCallback? reessayer;
  const ErreurVague1(this.erreur, {super.key, this.reessayer});

  @override
  Widget build(BuildContext context) {
    final e = erreur;
    final droit = e is ApiLoadException && e.nature == NatureErreur.droit;
    final message = e is ApiLoadException ? e.message : 'Une erreur inattendue est survenue.';
    final icone = switch (e is ApiLoadException ? e.nature : null) {
      NatureErreur.droit => Icons.lock_outline,
      NatureErreur.reseau || NatureErreur.delai => Icons.cloud_off,
      _ => Icons.error_outline,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Encadre(titre: titreErreur(e), texte: message, icone: icone, avertissement: droit, cleTitre: const Key('erreur_titre')),
        if (reessayer != null && !droit) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('bouton_reessayer'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
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
// Puces, lignes, tableau
// ---------------------------------------------------------------------------------------------------------------

/// Puces à choix unique (type, regroupement).
class PucesChoixVague1<T> extends StatelessWidget {
  final List<(T, String)> choix;
  final T valeur;
  final ValueChanged<T> onChanged;
  final String prefixeCle;
  const PucesChoixVague1({super.key, required this.choix, required this.valeur, required this.onChanged, this.prefixeCle = 'puce'});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, children: [
        for (final (v, libelle) in choix)
          ChoiceChip(
            key: Key('${prefixeCle}_$libelle'),
            label: Text(libelle),
            selected: v == valeur,
            onSelected: (_) => onChanged(v),
          ),
      ]);
}

/// Ligne « libellé … valeur » d'un détail.
class LigneValeurVague1 extends StatelessWidget {
  final String libelle;
  final String valeur;
  final bool fort;
  final Color? couleur;
  const LigneValeurVague1(this.libelle, this.valeur, {super.key, this.fort = false, this.couleur});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(libelle, style: const TextStyle(color: Charte.gris, fontSize: 14))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(valeur,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 14, color: couleur ?? Charte.encre, fontWeight: fort ? FontWeight.bold : FontWeight.w600)),
          ),
        ]),
      );
}

/// Colonne d'un [TableauVague1].
class ColonneVague1<T> {
  final String titre;
  final String Function(T) valeur;
  final int flex;
  final bool nombre;
  const ColonneVague1(this.titre, this.valeur, {this.flex = 2, this.nombre = false});
}

/// Tableau dense (tablette) : en-tête bleu clair, lignes alternées, ligne touchable si [onTap].
class TableauVague1<T> extends StatelessWidget {
  final List<ColonneVague1<T>> colonnes;
  final List<T> lignes;
  final void Function(T)? onTap;
  final String Function(T)? libelleLigne;
  const TableauVague1({super.key, required this.colonnes, required this.lignes, this.onTap, this.libelleLigne});

  @override
  Widget build(BuildContext context) {
    Widget cellule(String t, ColonneVague1<T> c, {bool entete = false}) => Expanded(
          flex: c.flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(t,
                textAlign: c.nombre ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                    fontSize: entete ? 13 : 14,
                    fontWeight: entete ? FontWeight.bold : FontWeight.normal,
                    color: entete ? Charte.navy : Charte.encre)),
          ),
        );
    return Container(
      decoration: BoxDecoration(color: Charte.blanc, borderRadius: BorderRadius.circular(14), border: Border.all(color: Charte.ligne)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          color: Charte.bleuClair,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [for (final c in colonnes) cellule(c.titre, c, entete: true)]),
        ),
        for (var i = 0; i < lignes.length; i++)
          Material(
            color: i.isEven ? Charte.blanc : Charte.page,
            child: InkWell(
              onTap: onTap == null ? null : () => onTap!(lignes[i]),
              child: Semantics(
                label: libelleLigne?.call(lignes[i]),
                button: onTap != null,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [for (final c in colonnes) cellule(c.valeur(lignes[i]), c)]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Bandeau « 12 lignes sur 230 » et bouton « Afficher plus » (pagination explicite : un appel par appui).
class PiedPaginationVague1 extends StatelessWidget {
  final int affichees;
  final int total;
  final bool enCours;
  final VoidCallback onPlus;
  const PiedPaginationVague1({super.key, required this.affichees, required this.total, required this.enCours, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    final reste = total - affichees;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text('${grouperMilliers(affichees)} ${affichees > 1 ? 'lignes affichées' : 'ligne affichée'} sur ${grouperMilliers(total)}',
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
                  label: Text('Afficher plus (${grouperMilliers(reste)})'),
                ),
        ],
      ]),
    );
  }
}
