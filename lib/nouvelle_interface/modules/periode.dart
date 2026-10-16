// lib/nouvelle_interface/modules/periode.dart
// Sélecteur de période COMMUN aux modules de la nouvelle interface : Aujourd'hui / Hier / 7 jours / Ce mois /
// Mois dernier / Personnalisée. Dates contrôlées (ControlePeriode) : début ≤ fin, rien dans le futur, pas avant le
// 01/01/2000 (première date des sélecteurs d'origine), 3 ans au plus (1096 jours, décision du pharmacien). Les dates
// partent au serveur au format d'origine (yyyy-MM-dd, DateFormatter.toApiFormat) : mêmes paramètres que les écrans
// d'origine. Commun au lot 1 (Rapport, Détail CA, Suivi Crédit) et à la vague 1 (Retraits et abandons, Ventes
// modifiées, date de la Valorisation : [choisirJour]).
import 'package:flutter/material.dart';

import '../../utils/date_formatter.dart';
import '../charte.dart';

enum PeriodeRapide {
  aujourdhui('Aujourd\'hui'),
  hier('Hier'),
  septJours('7 jours'),
  ceMois('Ce mois'),
  moisDernier('Mois dernier'),
  personnalisee('Personnalisée');

  final String libelle;
  const PeriodeRapide(this.libelle);
}

/// Période choisie : du [debut] au [fin] inclus (dates sans heure).
class Periode {
  final PeriodeRapide choix;
  final DateTime debut;
  final DateTime fin;
  const Periode._(this.choix, this.debut, this.fin);

  static DateTime jour(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Période rapide calculée au jour de [maintenant] ([PeriodeRapide.personnalisee] : aujourd'hui).
  factory Periode.rapide(PeriodeRapide choix, DateTime maintenant) {
    final j = jour(maintenant);
    return switch (choix) {
      PeriodeRapide.aujourdhui || PeriodeRapide.personnalisee => Periode._(choix, j, j),
      PeriodeRapide.hier => Periode._(choix, DateTime(j.year, j.month, j.day - 1), DateTime(j.year, j.month, j.day - 1)),
      PeriodeRapide.septJours => Periode._(choix, DateTime(j.year, j.month, j.day - 6), j),
      PeriodeRapide.ceMois => Periode._(choix, DateTime(j.year, j.month, 1), j),
      // DateTime gère le passage d'année (janvier → décembre précédent) et le dernier jour du mois (jour 0).
      PeriodeRapide.moisDernier => Periode._(choix, DateTime(j.year, j.month - 1, 1), DateTime(j.year, j.month, 0)),
    };
  }

  /// Période personnalisée, ou null si [ControlePeriode.erreur] la refuse.
  static Periode? personnalisee(DateTime debut, DateTime fin, DateTime maintenant) =>
      ControlePeriode.erreur(debut, fin, maintenant) == null ? Periode._(PeriodeRapide.personnalisee, jour(debut), jour(fin)) : null;

  int get nombreJours => fin.difference(debut).inDays + 1;

  /// « Aujourd'hui · 14/10/2026 », « 7 jours · du 08/10/2026 au 14/10/2026 ».
  String get resume {
    String f(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final dates = debut == fin ? f(debut) : 'du ${f(debut)} au ${f(fin)}';
    return '${choix.libelle} · $dates';
  }

  /// Paramètres d'origine des écrans (dtStart / dtEnd).
  Map<String, String> get parametres => {'dtStart': DateFormatter.toApiFormat(debut), 'dtEnd': DateFormatter.toApiFormat(fin)};

  @override
  bool operator ==(Object other) => other is Periode && other.choix == choix && other.debut == debut && other.fin == fin;

  @override
  int get hashCode => Object.hash(choix, debut, fin);
}

/// Contrôles des dates d'une période.
class ControlePeriode {
  ControlePeriode._();

  /// Première date acceptée (celle des sélecteurs de date d'origine).
  static final borneMin = DateTime(2000, 1, 1);

  /// Durée maximale d'une période : 3 ans (jours, bornes comprises ; 3 × 365 + 1 jour de février bissextile).
  static const dureeMaxJours = 1096;

  /// Message d'une période trop longue.
  static const messageTropLongue = 'Période trop longue (3 ans au maximum).';

  /// Motif de refus, ou null si la période est acceptable.
  static String? erreur(DateTime debut, DateTime fin, DateTime maintenant) {
    final d = Periode.jour(debut), f = Periode.jour(fin), aujourdhui = Periode.jour(maintenant);
    if (f.isBefore(d)) return 'La date de début doit précéder la date de fin.';
    if (f.isAfter(aujourdhui) || d.isAfter(aujourdhui)) return 'La période ne peut pas être dans le futur.';
    if (d.isBefore(borneMin)) return 'Date trop ancienne (avant le 01/01/2000).';
    if (f.difference(d).inDays + 1 > dureeMaxJours) return messageTropLongue;
    return null;
  }
}

/// Choix d'UNE date (calendrier commun) : ni dans le futur, ni avant [ControlePeriode.borneMin]. Null si annulé.
Future<DateTime?> choisirJour(BuildContext context, DateTime initiale, {String? aide, DateTime Function() maintenant = DateTime.now}) async {
  final aujourdhui = Periode.jour(maintenant());
  final init = initiale.isAfter(aujourdhui) ? aujourdhui : (initiale.isBefore(ControlePeriode.borneMin) ? ControlePeriode.borneMin : initiale);
  final d = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: ControlePeriode.borneMin,
    lastDate: aujourdhui,
    locale: const Locale('fr', 'FR'),
    helpText: aide,
    confirmText: 'Valider',
  );
  return d == null ? null : Periode.jour(d);
}

/// Puces de période (Aujourd'hui, Hier, Personnaliser), sélecteur « Autres périodes » et résumé des dates. « Personnaliser » ouvre le calendrier (dates
/// futures et antérieures à 2000 grisées) puis contrôle la période choisie.
class SelecteurPeriode extends StatelessWidget {
  final Periode periode;
  final ValueChanged<Periode> onChanged;

  /// Horloge (remplaçable dans les tests).
  final DateTime Function() maintenant;

  /// Contrôle propre à l'écran (ex. un an au plus pour le pointage des BL), appliqué EN PLUS de [ControlePeriode].
  final String? Function(DateTime debut, DateTime fin, DateTime maintenant)? controle;
  const SelecteurPeriode({super.key, required this.periode, required this.onChanged, this.maintenant = DateTime.now, this.controle});

  Future<void> _personnaliser(BuildContext context) async {
    final now = maintenant();
    final aujourdhui = Periode.jour(now);
    final choix = await showDateRangePicker(
      context: context,
      firstDate: ControlePeriode.borneMin,
      lastDate: aujourdhui,
      initialDateRange: DateTimeRange(start: periode.debut, end: periode.fin.isAfter(aujourdhui) ? aujourdhui : periode.fin),
      locale: const Locale('fr', 'FR'),
      helpText: 'Choisir la période',
      saveText: 'Valider',
    );
    if (choix == null || !context.mounted) return;
    final erreur = ControlePeriode.erreur(choix.start, choix.end, now) ?? controle?.call(choix.start, choix.end, now);
    if (erreur != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erreur)));
      return;
    }
    onChanged(Periode.personnalisee(choix.start, choix.end, now)!);
  }

  /// 3.11.0 (demande du pharmacien) : « Aujourd'hui », « Hier » et « Personnaliser » toujours visibles, les autres
  /// périodes dans un sélecteur déroulant (« Autres périodes ▾ ») : plus de puces cachées à droite de l'écran.
  /// Les éléments passent à la ligne sur un écran étroit (rien n'est caché).
  static const visibles = [PeriodeRapide.aujourdhui, PeriodeRapide.hier, PeriodeRapide.personnalisee];
  static const autres = [PeriodeRapide.septJours, PeriodeRapide.ceMois, PeriodeRapide.moisDernier];

  @override
  Widget build(BuildContext context) {
    final autreChoisie = autres.contains(periode.choix);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(key: const Key('periode_puces'), spacing: 6, children: [
        for (final c in visibles)
          _Puce(
            cle: Key('periode_${c.name}'),
            texte: c == PeriodeRapide.personnalisee ? 'Personnaliser' : c.libelle,
            icone: c == PeriodeRapide.personnalisee ? Icons.date_range_outlined : null,
            choisie: c == periode.choix,
            onTap: () => c == PeriodeRapide.personnalisee ? _personnaliser(context) : onChanged(Periode.rapide(c, maintenant())),
          ),
        PopupMenuButton<PeriodeRapide>(
          key: const Key('periode_autres'),
          tooltip: 'Autres périodes',
          initialValue: autreChoisie ? periode.choix : null,
          onSelected: (c) => onChanged(Periode.rapide(c, maintenant())),
          itemBuilder: (_) => [
            for (final c in autres)
              PopupMenuItem(
                key: Key('periode_${c.name}'),
                value: c,
                height: 48,
                child: Text(c.libelle, style: const TextStyle(fontSize: 15, color: Charte.encre, fontWeight: FontWeight.w600)),
              ),
          ],
          child: _Puce(
            texte: autreChoisie ? periode.choix.libelle : 'Autres périodes',
            iconeFin: Icons.arrow_drop_down,
            choisie: autreChoisie,
          ),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
        child: Row(children: [
          const Icon(Icons.event_outlined, size: 16, color: Charte.gris),
          const SizedBox(width: 6),
          Expanded(
            child: Text(periode.resume,
                key: const Key('periode_resume'), style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    ]);
  }
}

/// Puce de période : bleu nuit et texte blanc si choisie, blanche et texte bleu sinon (≥ 48 dp de haut).
class _Puce extends StatelessWidget {
  final Key? cle;
  final String texte;
  final IconData? icone;
  final IconData? iconeFin;
  final bool choisie;

  /// Null : la puce sert d'apparence au sélecteur déroulant (c'est lui qui reçoit le toucher).
  final VoidCallback? onTap;
  const _Puce({this.cle, required this.texte, this.icone, this.iconeFin, required this.choisie, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = choisie ? Charte.blanc : Charte.navy;
    return Semantics(
      selected: choisie,
      button: true,
      child: InkWell(
        key: cle,
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: choisie ? Charte.navy : Charte.blanc,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: choisie ? Charte.navy : Charte.bordure),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icone != null) ...[Icon(icone, size: 16, color: fg), const SizedBox(width: 4)],
                Text(texte, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w700)),
                if (iconeFin != null) Icon(iconeFin, size: 20, color: fg),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
