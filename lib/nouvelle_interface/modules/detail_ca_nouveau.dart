// lib/nouvelle_interface/modules/detail_ca_nouveau.dart
// Détail CA de la nouvelle interface. Mêmes données et mêmes calculs que l'écran d'origine (DetailCa : GET /ca-all
// avec dtStart / dtEnd, cumul de la période, répartition par mode de paiement), mise en page refaite : période
// commune, chiffres clés, répartition en barres (pourcentages identiques au camembert d'origine), totaux de la
// période, puis jour par jour en cartes (téléphone) ou en tableau (tablette). Chargé à l'ouverture.
// Mobile Money dépliable (flèche du chiffre clé et de la ligne « Total Mobile Money ») : détail par opérateur, avec
// son taux dans le total Mobile Money et dans le CA global (= « Total brut paiements » affiché). Le détail vient du
// champ « detailMobile » de /ca-all s'il existe, sinon de GET /stats-recette-caisse/modes appelé AU PREMIER
// DÉPLIAGE seulement (mêmes dates), avec chargement et erreur propres à la ligne dépliée.
import 'package:flutter/material.dart';

import '../../donnees/detail_ca_donnees.dart';
import '../../models/ca_comptant_model.dart';
import '../../utils/date_formatter.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'commun_lot3.dart';
import 'periode.dart';

class DetailCaNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const DetailCaNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<DetailCaNouveau> createState() => _DetailCaNouveauState();
}

class _DetailCaNouveauState extends State<DetailCaNouveau> with ChargementSuivi<DetailCaNouveau, List<CaComptant>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());

  /// Période de la dernière demande /ca-all (l'appel complémentaire reprend EXACTEMENT ces dates).
  Periode? _periodeChargee;

  // Détail Mobile Money : déplié ?, opérateurs (cache de la période), chargement, erreur locale.
  bool _mobileDeplie = false;
  List<OperateurMobile>? _operateurs;
  bool _mobileEnCours = false;
  Object? _mobileErreur;
  int _mobileGeneration = 0;
  final _cleMobile = GlobalKey();

  /// Couleurs des modes de paiement (charte : bleu nuit, ambre, vert, bleu, gris, rouge).
  static const _couleurs = [Charte.navy, Charte.ambre, Charte.vert, Charte.bleu, Charte.grisTexte, Charte.rouge];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() {
    final p = _periode;
    _oublierMobile();
    _periodeChargee = p;
    return charger(() => DetailCa.charger(context, p.debut, p.fin, onSessionInvalid: sessionInvalide(context)));
  }

  /// Nouvelles données /ca-all : détail replié et oublié (réponse en route ignorée).
  void _oublierMobile() {
    _mobileGeneration++;
    _mobileDeplie = false;
    _operateurs = null;
    _mobileEnCours = false;
    _mobileErreur = null;
  }

  /// Flèche ▸ / ▾. [defiler] : amène la ligne dépliée à l'écran (appui sur le chiffre clé).
  void _basculerMobile({bool defiler = false}) {
    setState(() => _mobileDeplie = !_mobileDeplie);
    if (!_mobileDeplie) return;
    if (_operateurs == null && !_mobileEnCours && _mobileErreur == null) _chargerMobile();
    if (defiler) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _cleMobile.currentContext;
        if (c != null && c.mounted) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250), alignment: 0.1);
      });
    }
  }

  Future<void> _chargerMobile() async {
    final lignes = donnees ?? const <CaComptant>[];
    final duServeur = DetailCa.detailDepuisCaAll(lignes);
    if (duServeur != null || DetailCa.cumul(lignes).totMobile == 0 || _periodeChargee == null) {
      setState(() => _operateurs = duServeur ?? const []);
      return;
    }
    final g = ++_mobileGeneration;
    final p = _periodeChargee!;
    setState(() {
      _mobileEnCours = true;
      _mobileErreur = null;
    });
    try {
      final r = await DetailCa.chargerModes(context, p.debut, p.fin, onSessionInvalid: sessionInvalide(context));
      if (!mounted || g != _mobileGeneration) return;
      setState(() {
        _operateurs = r;
        _mobileEnCours = false;
      });
    } catch (e) {
      if (!mounted || g != _mobileGeneration) return;
      setState(() {
        _mobileErreur = e;
        _mobileEnCours = false;
      });
    }
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Détail CA')),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  /// Une courbe par mode de paiement présent sur la période (mêmes modes et couleurs que la liste), jour par jour.
  Widget _courbes(List<CaComptant> lignes, List<(String, double, double)> repartition) {
    final jours = [...lignes]..sort((a, b) => (a.mvtDate ?? DateTime(0)).compareTo(b.mvtDate ?? DateTime(0)));
    final valeurs = [for (final c in jours) DetailCa.modes(c)];
    return GraphiqueCourbes(
      libelle: 'Courbes de la répartition par mode de paiement, ${jours.length} jours',
      jours: [for (final c in jours) c.mvtDate],
      series: [
        for (var i = 0; i < repartition.length; i++)
          (SerieGraphique(repartition[i].$1, _couleurs[i % _couleurs.length]), [for (final v in valeurs) v[repartition[i].$1] ?? 0]),
      ],
    );
  }

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Calcul du chiffre d\'affaires…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final lignes = donnees ?? const <CaComptant>[];
    if (lignes.isEmpty) {
      return const [EtatVide(titre: 'Aucun CA trouvé pour la période', texte: 'Choisissez une autre période.', icone: Icons.payments_outlined)];
    }
    final t = DetailCa.cumul(lignes);
    final repartition = DetailCa.repartition(t);
    String date(CaComptant c) => c.mvtDate == null ? '—' : DateFormatter.toDisplayFormat(c.mvtDate!).replaceAll('-', '/');
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Total brut paiements', valeur: formaterMontant(t.totalPaiements), id: 'total', enAvant: true),
        ChiffreCle(libelle: 'Espèces', valeur: formaterMontant(t.totEsp), id: 'especes'),
        ChiffreCle(libelle: 'Crédit', valeur: formaterMontant(t.montantCredit), id: 'credit'),
        _Depliable(
          cle: const Key('deplier_mobile_kpi'),
          deplie: _mobileDeplie,
          onTap: () => _basculerMobile(defiler: true),
          enCarte: true,
          child: ChiffreCle(libelle: 'Mobile Money', valeur: formaterMontant(t.totMobile), id: 'mobile'),
        ),
      ]),
      const SizedBox(height: 12),
      CarteSection(titre: 'Répartition par mode de paiement', icone: Icons.donut_small_outlined, enfants: [
        if (repartition.isEmpty)
          const Text('Aucun encaissement sur la période.', style: TextStyle(color: Charte.gris))
        else ...[
          // 3.11.0 (demande du pharmacien) : la répartition se lit en COURBES (une par mode de paiement, jour par jour)
          // et non plus en barres ; montants et parts restent écrits sous la courbe.
          if (lignes.length >= 2) ...[
            CadreGraphique(key: const Key('repartition_courbes'), hauteur: 240, child: _courbes(lignes, repartition)),
            const SizedBox(height: 8),
          ] else
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('Choisissez plusieurs jours pour voir les courbes.', style: TextStyle(color: Charte.grisTexte, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          for (var i = 0; i < repartition.length; i++) _BarreRepartition(repartition[i], _couleurs[i % _couleurs.length]),
        ],
      ]),
      CarteSection(titre: 'Totaux sur la période', icone: Icons.functions, enfants: [
        LigneDetail('Total Espèces', formaterMontant(t.totEsp)),
        LigneDetail('Total Crédit', formaterMontant(t.montantCredit)),
        _Depliable(
          key: _cleMobile,
          cle: const Key('deplier_mobile'),
          deplie: _mobileDeplie,
          onTap: _basculerMobile,
          child: LigneDetail('Total Mobile Money', formaterMontant(t.totMobile)),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _mobileDeplie ? _detailMobile(lignes, t) : const SizedBox(width: double.infinity),
        ),
        LigneDetail('Total Carte Bancaire', formaterMontant(t.totCB)),
        LigneDetail('Total Chèque', formaterMontant(t.totChq)),
        LigneDetail('Total Virement', formaterMontant(t.totVirement)),
        const Divider(height: 14),
        LigneDetail('TOTAL BRUT PAIEMENTS', formaterMontant(t.totalPaiements), gras: true, couleur: Charte.navy),
        LigneDetail('Remise sur CA', formaterMontant(t.remiseSurCA)),
        LigneDetail('Total TVA', formaterMontant(t.totTVA)),
      ]),
      const TitreSection('Jour par jour'),
      ListeOuTableau(
        nombre: lignes.length,
        colonnes: const [
          Colonne('Date', flex: 2),
          Colonne('Espèces', flex: 2, droite: true),
          Colonne('Crédit', flex: 2, droite: true),
          Colonne('Mobile', flex: 2, droite: true),
          Colonne('Carte B.', flex: 2, droite: true),
          Colonne('Total', flex: 2, droite: true),
        ],
        cellules: (i) {
          final c = lignes[i];
          return [date(c), formaterMontant(c.totEsp), formaterMontant(c.montantCredit), formaterMontant(c.totMobile), formaterMontant(c.totCB),
            formaterMontant(c.totalPaiements)];
        },
        carte: (i) {
          final c = lignes[i];
          return CarteLigne(
            titre: date(c),
            lignes: [
              'Espèces ${formaterMontant(c.totEsp)} · Crédit ${formaterMontant(c.montantCredit)}',
              'Mobile ${formaterMontant(c.totMobile)} · Carte ${formaterMontant(c.totCB)}',
            ],
            libelleValeur: 'Total',
            valeur: formaterMontant(c.totalPaiements),
            // 3.11.2 (demande du pharmacien) : évolution du Total par rapport au jour précédent de la liste, sous le
            // Total, sans agrandir la carte.
            sousValeur: EvolutionTotalJour(evolutionTotalJour(lignes, i), key: Key('jour_evolution_$i')),
          );
        },
      ),
    ];
  }
}

extension _DetailMobileVue on _DetailCaNouveauState {
  Widget _detailMobile(List<CaComptant> lignes, CaComptant t) {
    Widget cadre(List<Widget> enfants) => Container(
          key: const Key('detail_mobile'),
          width: double.infinity,
          margin: const EdgeInsets.only(left: 8, bottom: 6, top: 2),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: const BoxDecoration(
            color: Charte.page,
            border: Border(left: BorderSide(color: Charte.navy, width: 3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: enfants),
        );
    if (_mobileEnCours) {
      return cadre(const [
        Padding(
          key: Key('mobile_chargement'),
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(width: 12),
            Expanded(child: Text('Chargement du détail par opérateur…', style: TextStyle(color: Charte.gris))),
          ]),
        ),
      ]);
    }
    if (_mobileErreur != null) {
      final d = DiagnosticErreur.de(_mobileErreur!);
      return cadre([
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(d.icone, color: Charte.rougeTexte, size: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                liveRegion: true,
                child: Text(d.titre, key: Key('mobile_erreur_${d.cause.name}'),
                    style: const TextStyle(color: Charte.rougeTexte, fontWeight: FontWeight.bold, fontSize: 14.5)),
              ),
              Text(d.message, style: const TextStyle(color: Charte.rougeTexte, fontSize: 13)),
            ]),
          ),
        ]),
        if (d.cause != CauseErreur.droit)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('mobile_reessayer'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _chargerMobile,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ),
      ]);
    }
    final ops = _operateurs;
    if (ops == null) return cadre(const []);
    final duServeur = DetailCa.detailDepuisCaAll(lignes) != null;
    final detail = DetailMobile(
      operateurs: ops,
      totMobile: t.totMobile,
      caGlobal: t.totalPaiements,
      source: duServeur ? SourceDetailMobile.caAll : SourceDetailMobile.modes,
    );
    if (t.totMobile == 0 && ops.isEmpty) {
      return cadre(const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Aucun encaissement Mobile Money sur la période.', key: Key('mobile_vide'), style: TextStyle(color: Charte.gris)),
        ),
      ]);
    }
    final ecart = detail.ecart;
    final rangs = <_RangMobile>[
      for (final o in ops) _RangMobile(o.libelle, o.montant, detail.tauxMobile(o.montant), detail.tauxCa(o.montant)),
      if (ecart != null) _RangMobile('Autres / écart', ecart, detail.tauxMobile(ecart), detail.tauxCa(ecart), ecart: true),
    ];
    return cadre([
      LayoutBuilder(builder: (context, c) {
        final tableau = c.maxWidth >= 560;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (tableau) const _EnteteMobile(),
          for (final r in rangs) tableau ? _LigneTableauMobile(r) : _LigneMobile(r),
        ]);
      }),
      if (ecart != null)
        const Padding(
          key: Key('mobile_note_ecart'),
          padding: EdgeInsets.only(top: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16, color: Charte.gris),
            SizedBox(width: 6),
            Expanded(
              child: Text('Autres / écart : différence de calcul entre deux sources du serveur.',
                  style: TextStyle(color: Charte.gris, fontSize: 12.5)),
            ),
          ]),
        ),
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('Taux : part du total Mobile Money et part du CA global (total brut paiements).',
            style: TextStyle(color: Charte.gris, fontSize: 12.5)),
      ),
    ]);
  }
}

/// Une ligne du détail Mobile Money (opérateur ou écart).
class _RangMobile {
  final String libelle;
  final double montant;
  final double? tauxMobile;
  final double? tauxCa;
  final bool ecart;
  const _RangMobile(this.libelle, this.montant, this.tauxMobile, this.tauxCa, {this.ecart = false});
}

/// « 50,5 % » (virgule décimale) ; « — » si le taux n'existe pas (total nul).
String formaterTaux(double? t) => t == null ? '—' : '${t.toStringAsFixed(1).replaceAll('.', ',')}\u00a0%';

const _styleMontantMobile = TextStyle(color: Charte.encre, fontWeight: FontWeight.w700, fontSize: 14);

/// Téléphone : opérateur et montant, puis les deux taux en toutes lettres.
class _LigneMobile extends StatelessWidget {
  final _RangMobile r;
  const _LigneMobile(this.r);

  @override
  Widget build(BuildContext context) => Padding(
        key: Key('mobile_ligne_${r.libelle}'),
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(r.libelle,
                  style: TextStyle(color: Charte.encre, fontSize: 14, fontWeight: FontWeight.w600, fontStyle: r.ecart ? FontStyle.italic : null)),
            ),
            const SizedBox(width: 8),
            Text(formaterMontant(r.montant), style: _styleMontantMobile),
          ]),
          Text('${formaterTaux(r.tauxMobile)} du Mobile Money · ${formaterTaux(r.tauxCa)} du CA',
              style: const TextStyle(color: Charte.grisTexte, fontSize: 12.5)),
        ]),
      );
}

const _flexMobile = [4, 3, 3, 3];

class _EnteteMobile extends StatelessWidget {
  const _EnteteMobile();

  @override
  Widget build(BuildContext context) {
    const titres = ['OPÉRATEUR', 'MONTANT', 'PART MOBILE MONEY', 'PART DU CA'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        for (var i = 0; i < titres.length; i++)
          Expanded(
            flex: _flexMobile[i],
            child: Text(titres[i],
                textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                style: const TextStyle(color: Charte.gris, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
          ),
      ]),
    );
  }
}

/// Tablette : tableau à 4 colonnes (opérateur, montant, part du Mobile Money, part du CA).
class _LigneTableauMobile extends StatelessWidget {
  final _RangMobile r;
  const _LigneTableauMobile(this.r);

  @override
  Widget build(BuildContext context) {
    final cellules = [r.libelle, formaterMontant(r.montant), formaterTaux(r.tauxMobile), formaterTaux(r.tauxCa)];
    return Container(
      key: Key('mobile_ligne_${r.libelle}'),
      constraints: const BoxConstraints(minHeight: 40),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Charte.ligne))),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        for (var i = 0; i < cellules.length; i++)
          Expanded(
            flex: _flexMobile[i],
            child: Text(cellules[i],
                textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                style: i == 1
                    ? _styleMontantMobile
                    : TextStyle(
                        color: i == 0 ? Charte.encre : Charte.grisTexte,
                        fontSize: 14,
                        fontWeight: i == 0 ? FontWeight.w600 : FontWeight.normal,
                        fontStyle: r.ecart && i == 0 ? FontStyle.italic : null)),
          ),
      ]),
    );
  }
}

/// Zone dépliable : contenu + flèche ▸ / ▾ (cible ≥ 48 dp, annoncée « Détail Mobile Money », état déplié/replié).
class _Depliable extends StatelessWidget {
  final Key cle;
  final bool deplie;
  final VoidCallback onTap;
  final Widget child;

  /// Chiffre clé : flèche dans le coin de la carte (toute la carte est la cible).
  final bool enCarte;
  const _Depliable({super.key, required this.cle, required this.deplie, required this.onTap, required this.child, this.enCarte = false});

  @override
  Widget build(BuildContext context) {
    final fleche = AnimatedRotation(
      turns: deplie ? 0.25 : 0,
      duration: const Duration(milliseconds: 200),
      child: const Icon(Icons.arrow_right, color: Charte.navy, size: 28),
    );
    return Semantics(
      button: true,
      expanded: deplie,
      label: 'Détail Mobile Money',
      hint: deplie ? 'Replier le détail par opérateur' : 'Déplier le détail par opérateur',
      container: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: cle,
          borderRadius: BorderRadius.circular(enCarte ? 14 : 8),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: enCarte
                ? Stack(children: [child, Positioned(right: 2, top: 2, child: fleche)])
                : Row(children: [Expanded(child: child), const SizedBox(width: 4), fleche]),
          ),
        ),
      ),
    );
  }
}

/// Mode de paiement : pastille de la couleur de sa courbe, libellé, pourcentage (même calcul que le camembert d'origine)
/// et montant.
class _BarreRepartition extends StatelessWidget {
  final (String, double, double) mode;
  final Color couleur;
  const _BarreRepartition(this.mode, this.couleur);

  @override
  Widget build(BuildContext context) {
    final (libelle, montant, pourcent) = mode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          // Pastille de la couleur de la courbe (3.11.0 : plus de barre).
          Container(width: 12, height: 12, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(libelle, style: const TextStyle(fontWeight: FontWeight.w600, color: Charte.encre))),
          Text('${pourcent.toStringAsFixed(1)}%', style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text(formaterMontant(montant), style: const TextStyle(fontWeight: FontWeight.bold, color: Charte.encre)),
        ]),
      ]),
    );
  }
}

/// Évolution (en %) du Total du jour [i] par rapport au jour précédent de la liste, au dixième ; null pour le premier
/// jour ou après un jour à 0.
double? evolutionTotalJour(List<CaComptant> l, int i) {
  if (i <= 0 || i >= l.length) return null;
  final avant = l[i - 1].totalPaiements, jour = l[i].totalPaiements;
  if (avant == 0) return null;
  return ((jour - avant) * 1000 / avant).round() / 10;
}

/// « ↑ +12,5 % » vert (hausse), « ↓ −8,0 % » rouge (baisse), « = 0,0 % » gris (égal) : flèche, signe ET couleur ;
/// rien sans évolution. Une seule ligne, réduite si la place manque (la carte ne grandit pas).
class EvolutionTotalJour extends StatelessWidget {
  final double? evolution;
  const EvolutionTotalJour(this.evolution, {super.key});

  @override
  Widget build(BuildContext context) {
    final e = evolution;
    if (e == null) return const SizedBox.shrink();
    final (icone, mot, couleur) = e > 0
        ? (Icons.arrow_upward, 'Hausse', Charte.vertTexte)
        : e < 0
            ? (Icons.arrow_downward, 'Baisse', Charte.rougeTexte)
            : (Icons.drag_handle, 'Stable', Charte.grisTexte);
    final s = e.abs().toStringAsFixed(1).replaceAll('.', ',');
    final texte = e > 0 ? '+$s %' : (e < 0 ? '−$s %' : '0,0 %');
    return Semantics(
      label: '$mot de $texte par rapport au jour précédent',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, size: 14, color: couleur),
          const SizedBox(width: 2),
          Text(texte, style: TextStyle(color: couleur, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
