// lib/nouvelle_interface/accueil_nouveau.dart
// Accueil de la NOUVELLE interface (maquettes §2) avec la barre du bas Accueil · Analyses · Équipe, plus
// « Pilotage » pour l'administrateur et le pharmacien (3.2.0, vague2/pilotage_vague2.dart ; la barre reste à trois
// onglets pour les autres profils). Les Réglages ne sont plus un onglet : le bouton engrenage en haut à
// droite de l'accueil (A, B, C) les ouvre ; sur tablette (B), le menu latéral les ouvre aussi.
//  - A · Tableau de bord (par défaut sur téléphone) : en-tête bleu arrondi, chiffres du jour (CA, marge, crédits,
//    équipe), alertes cliquables dont le nombre se compte à la demande (bouton ⟳, alertes_accueil.dart), puis tous les menus rangés par familles sur une seule page ;
//  - B · Compact (automatiquement sur tablette) : barre blanche, recherche de menu, liste par familles ; sur
//    tablette, menu latéral bleu et menus sur deux colonnes ;
//  - C · Guidé : « Que voulez-vous savoir ? », cinq questions métier, puis les menus de la question.
// Les menus ouvrent les écrans d'origine des modules (mêmes données, mêmes routes serveur).
// 3.9.0 : réglages « Menus de l'accueil » (sur une page / par pages : A et B sur téléphone) et « Style des icônes »
// (propositions P1 / P2 / P3, « Actuel » par défaut), apparence_accueil.dart ; « Fiche Article » retiré (menus.dart) ;
// recherche de produit « contient » en haut de l'onglet Analyses (recherche_produit_analyses.dart).
// 3.10.0 : « Menus de l'accueil » en trois dispositions (tout sur une page, une rubrique par page, 6 tuiles par
// page) ; proposition P4 « icônes illustrées » (icones_illustrees.dart) sur les tuiles, les listes et la barre du bas.
// 3.10.1 : P4 par défaut (style jamais choisi), disposition « tout sur une page » par défaut.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../presences/presences_modeles.dart';
import '../presences/presences_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/home_settings_provider.dart';
import '../providers/ip_config_provider.dart';
import '../providers/licence_provider.dart';
import '../utils/constants.dart';
import 'alertes_accueil.dart';
import 'apparence_accueil.dart';
import 'charte.dart';
import 'chiffres_du_jour.dart';
import 'composants.dart';
import 'icones_illustrees.dart';
import 'menus.dart';
import 'modules/fichier_journal_nouveau.dart';
import 'presentation.dart';
import 'recherche_produit_analyses.dart';
import 'reglages_nouveaux.dart';
import 'vague4/perimes_vague4.dart';
import 'vague4/tableau_bord_vague4.dart';
import 'vague1/alertes_vague1.dart';
import 'vague1/donnees_vague1.dart' show ReglageAlerte, ReglagesAlertes, TypeAlerte, ValeursAlertes;
import 'vague1/profil_acces.dart';
import 'vague2/pilotage_vague2.dart';

/// Passe en mode local / distant (même contrôle que l'ancien accueil : adresse distante requise).
Future<void> basculerServeur(BuildContext context, {VoidCallback? apres}) async {
  final ip = Provider.of<IpConfigProvider>(context, listen: false);
  final versLocal = !ip.useLocalIp;
  if (!versLocal && (ip.remoteIp.isEmpty || ip.remoteIp == AppConstants.defaultRemoteIp)) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('L\'adresse IP distante n\'est pas configurée.')));
    return;
  }
  ip.setUseLocalIp(versLocal);
  await Future<void>.delayed(Duration.zero);
  apres?.call();
}

/// Pastille « ● Serveur local » de l'en-tête bleu : touchée, elle bascule local / distant.
class PastilleServeur extends StatelessWidget {
  final VoidCallback? apres;
  const PastilleServeur({super.key, this.apres});

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<IpConfigProvider>();
    return PastilleEntete(
      ip.useLocalIp ? 'Serveur local' : 'Serveur distant',
      point: Charte.vertVif,
      icone: Icons.swap_horiz,
      infobulle: ip.useLocalIp ? 'Passer en mode Distant' : 'Passer en mode Local',
      onTap: () => basculerServeur(context, apres: apres),
    );
  }
}

/// Onglets de la barre du bas (téléphone) et du menu latéral (tablette), dans l'ordre d'affichage.
/// [pilotage] (réservé à l'administrateur et au pharmacien) n'est montré qu'à eux : [ongletsAccueil].
enum OngletAccueil {
  accueil(Icons.home_outlined, Icons.home, 'Accueil', 'Pilotage'),
  analyses(Icons.insights_outlined, Icons.insights, 'Analyses', 'Pilotage'),
  equipe(Icons.groups_outlined, Icons.groups, 'Équipe', 'Équipe'),
  pilotage(Icons.speed_outlined, Icons.speed, 'Pilotage', 'Officine');

  final IconData icone;
  final IconData iconeChoisie;
  final String libelle;

  /// Rubrique du menu latéral (tablette).
  final String rubrique;
  const OngletAccueil(this.icone, this.iconeChoisie, this.libelle, this.rubrique);
}

/// Couleur de l'onglet actif (styles d'icônes P1 / P2 / P3) : Accueil bleu nuit, Analyses indigo, Équipe framboise,
/// Pilotage ambre.
Teinte teinteOnglet(OngletAccueil o) => switch (o) {
      OngletAccueil.accueil => const Teinte(Charte.navy, Charte.bleuClair, Charte.blanc),
      OngletAccueil.analyses => teinteFamille(Famille.analyses),
      OngletAccueil.equipe => teinteFamille(Famille.equipe),
      OngletAccueil.pilotage => teinteFamille(Famille.credits),
    };

/// Barre du bas (téléphone). Style « Actuel » : celle d'origine (thème). P1 / P2 / P3 : icône et libellé de
/// l'onglet actif dans sa couleur, sur un indicateur (pastille) de la même famille. P4 : icônes illustrées (l'onglet
/// actif en couleur sur une pastille bleu clair, les autres en gris atténué ; libellé actif en gras).
class BarreOnglets extends StatelessWidget {
  final List<OngletAccueil> onglets;
  final int onglet;
  final ValueChanged<int> choisir;
  final StyleIcones style;
  const BarreOnglets({super.key, required this.onglets, required this.onglet, required this.choisir, required this.style});

  @override
  Widget build(BuildContext context) {
    final illustre = style.illustre;
    final colore = style != StyleIcones.actuel && !illustre;
    final t = teinteOnglet(onglets[onglet.clamp(0, onglets.length - 1)]);
    Widget icone(OngletAccueil o, {required bool actif}) {
      final image = illustre ? illustrationOnglet(o.name) : null;
      if (image != null) {
        return IconeIllustree(image,
            key: Key('onglet_illustre_${o.name}${actif ? '_actif' : ''}'),
            taille: 26,
            repli: actif ? o.iconeChoisie : o.icone,
            couleurRepli: actif ? Charte.navy : Charte.gris,
            attenuee: !actif);
      }
      return actif ? Icon(o.iconeChoisie, color: colore ? teinteOnglet(o).icone : null) : Icon(o.icone);
    }

    final barre = NavigationBar(
      key: const Key('barre_accueil'),
      selectedIndex: onglet,
      height: 66,
      onDestinationSelected: choisir,
      indicatorColor: colore ? t.pastille : (illustre ? Charte.bleuClair : null),
      destinations: [
        for (final o in onglets)
          NavigationDestination(
            icon: icone(o, actif: false),
            selectedIcon: icone(o, actif: true),
            label: o.libelle,
          ),
      ],
    );
    if (!colore) return barre;
    final theme = NavigationBarTheme.of(context);
    return NavigationBarTheme(
      data: theme.copyWith(
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final base = theme.labelTextStyle?.resolve(s) ?? const TextStyle(fontSize: 12);
          return s.contains(WidgetState.selected) ? base.copyWith(color: t.icone, fontWeight: FontWeight.w800) : base;
        }),
      ),
      child: barre,
    );
  }
}

/// Onglets affichés : Accueil · Analyses · Équipe, plus Pilotage pour l'administrateur et le pharmacien.
List<OngletAccueil> ongletsAccueil({required bool responsable}) =>
    [for (final o in OngletAccueil.values) if (o != OngletAccueil.pilotage || responsable) o];

/// Ouvre les Réglages (page à part, avec retour).
void ouvrirReglages(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReglagesScreen()));

/// Bouton Réglages (engrenage) en haut à droite de l'accueil : 48 dp, libellé accessible « Réglages ».
class BoutonReglages extends StatelessWidget {
  final Color couleur;
  const BoutonReglages({super.key = const Key('bouton_reglages'), this.couleur = Charte.blanc});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Réglages',
        icon: Icon(Icons.settings_outlined, color: couleur),
        onPressed: () => ouvrirReglages(context),
      );
}

/// Bouton de déconnexion (en-têtes). 3.11.0 (demande du pharmacien) : même bouton que l'en-tête de Prestige web
/// (Header.js : icône « power-off » blanche dans un rond rouge #e74c3c), placé APRÈS les Réglages. Zone touchable de
/// 48 dp, libellé accessible « Déconnexion ». [couleur] est conservé pour compatibilité (le bouton est toujours rouge).
class BoutonDeconnexion extends StatelessWidget {
  final Color couleur;
  const BoutonDeconnexion({super.key = const Key('bouton_deconnexion'), this.couleur = Charte.blanc});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Déconnexion',
        onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(context),
        icon: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Charte.rougeDeconnexion,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Charte.ombreDeconnexion, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: const Icon(Icons.power_settings_new, color: Colors.white, size: 19),
        ),
      );
}

class AccueilNouveau extends StatefulWidget {
  const AccueilNouveau({super.key});

  @override
  State<AccueilNouveau> createState() => _AccueilNouveauState();
}

class _AccueilNouveauState extends State<AccueilNouveau> {
  int _onglet = 0;
  ChiffresDuJour? _chiffres;
  bool _chargementChiffres = false;
  bool _chiffresDemandes = false;
  final _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _chargerChiffres() async {
    if (_chargementChiffres) return;
    setState(() => _chargementChiffres = true);
    final c = await ChiffresDuJour.charger(context);
    if (!mounted) return;
    setState(() {
      _chiffres = c;
      _chargementChiffres = false;
    });
  }

  void _choisirOnglet(int i) => setState(() => _onglet = i);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: ProfilAcces.utilisateur,
        builder: (context, _, __) => ListenableBuilder(listenable: ApparenceAccueilPrefs.ecoute, builder: (context, _) => _construire(context)),
      );

  Widget _construire(BuildContext context) {
    final onglets = ongletsAccueil(responsable: ProfilAcces.responsable);
    if (_onglet >= onglets.length) _onglet = 0;
    return ValueListenableBuilder<Presentation>(
      valueListenable: PresentationPrefs.choix,
      builder: (context, choix, _) {
        final tablette = estTabletteNouvelle(context);
        final p = PresentationPrefs.effective(choix, tablette: tablette);
        if (p == Presentation.tableauDeBord && !_chiffresDemandes) {
          _chiffresDemandes = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _chargerChiffres();
          });
        }
        final contenu = switch (onglets[_onglet]) {
          OngletAccueil.analyses => const OngletAnalyses(),
          OngletAccueil.equipe => const OngletEquipe(),
          OngletAccueil.pilotage => const OngletPilotageAccueil(),
          OngletAccueil.accueil => switch (p) {
              Presentation.compact => _AccueilCompact(recherche: _recherche, tablette: tablette),
              Presentation.guide => const _AccueilGuide(),
              Presentation.tableauPrestige => const AccueilTableauPrestige(),
              _ => _AccueilTableauDeBord(chiffres: _chiffres, chargement: _chargementChiffres, actualiser: _chargerChiffres),
            },
        };
        return PopScope(
          // Retour système sur un autre onglet : revient à l'onglet Accueil.
          canPop: _onglet == 0,
          onPopInvokedWithResult: (aQuitte, _) {
            if (!aQuitte) _choisirOnglet(0);
          },
          child: tablette && p == Presentation.compact
              ? Scaffold(
                  body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _MenuLateral(onglets: onglets, onglet: _onglet, choisir: _choisirOnglet),
                    Expanded(child: KeyedSubtree(key: ValueKey('onglet$_onglet'), child: contenu)),
                  ]),
                )
              : Scaffold(
                  body: KeyedSubtree(key: ValueKey('onglet$_onglet'), child: contenu),
                  bottomNavigationBar:
                      BarreOnglets(onglets: onglets, onglet: _onglet, choisir: _choisirOnglet, style: ApparenceAccueilPrefs.style.value),
                ),
        );
      },
    );
  }
}

/// Alertes « À surveiller » (sans la licence ni le titre) : péremption, ruptures, et pour l'administrateur et le
/// pharmacien (3.11.0, « cloche ») avoirs non clôturés, saisies en périmés, puis « Toutes les alertes ». Nombres
/// comptés à la demande seulement, par UN appel (GET /tableau-bord/alertes) : le ⟳ de n'importe laquelle de ces
/// alertes actualise tout le bloc ; jamais automatiquement (les saisies en périmés ont leur propre ⟳). Sert à
/// l'accueil A et à l'onglet « Surveiller et alertes » de la Balance vente / caisse.
class BlocAlertesSurveiller extends StatelessWidget {
  final bool peremption;
  final bool ruptures;
  final bool toutesAlertes;

  /// Carte « Toutes les alertes » (absente quand toutes les alertes sont déjà affichées dessous).
  final bool carteToutesAlertes;
  const BlocAlertesSurveiller({super.key, required this.peremption, required this.ruptures, required this.toutesAlertes, this.carteToutesAlertes = true});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ValeursAlertes>(
        valueListenable: ReglagesAlertes.valeurs,
        builder: (context, reglages, _) {
          final cartes = <Widget>[
            if (peremption)
              AlerteComptee(
                key: const Key('alerte_peremption'),
                alerte: AlerteAccueil.peremption,
                bande: Charte.rouge,
                titre: 'Produits proches de la péremption',
                // Lots qui périment dans les N prochains mois (réglage, 6 par défaut), hors lots déjà périmés.
                detail: 'Périment dans ${reglages.de(ReglageAlerte.per)} mois (hors lots déjà périmés)',
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlerteListeScreen(type: TypeAlerte.peremptions))),
              ),
            if (ruptures)
              AlerteComptee(
                key: const Key('alerte_ruptures'),
                alerte: AlerteAccueil.ruptures,
                bande: Charte.ambre,
                titre: 'Ruptures de stock',
                detail: 'Produits actifs à stock nul',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlerteListeScreen(type: TypeAlerte.ruptures))),
              ),
            if (toutesAlertes) ...[
              AlerteComptee(
                key: const Key('alerte_avoirs'),
                alerte: AlerteAccueil.avoirs,
                bande: Charte.ambre,
                titre: 'Avoirs',
                detail: 'Ventes en avoir non clôturées',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertesScreen())),
              ),
              const AlerteSaisiesPerimes(),
              if (carteToutesAlertes) const CarteToutesAlertes(),
            ],
          ];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < cartes.length; i++) ...[if (i > 0) const SizedBox(height: 8), cartes[i]],
          ]);
        },
      );
}

/// Menu latéral bleu (présentation B sur tablette).
class _MenuLateral extends StatelessWidget {
  final List<OngletAccueil> onglets;
  final int onglet;
  final ValueChanged<int> choisir;
  const _MenuLateral({required this.onglets, required this.onglet, required this.choisir});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    Widget groupe(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
          child: Text(t.toUpperCase(), style: const TextStyle(color: Charte.enteteGris, fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.bold)),
        );
    Widget element(int i, IconData icone, String texte, {VoidCallback? action}) {
      final actif = action == null && i == onglet;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: actif ? Charte.enteteVoile : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: action ?? () => choisir(i),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Icon(icone, color: actif ? Charte.blanc : Charte.enteteGris, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(texte,
                      style: TextStyle(color: actif ? Charte.blanc : Charte.enteteGris, fontWeight: actif ? FontWeight.bold : FontWeight.w500, fontSize: 15)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 264,
      color: Charte.navy,
      child: SafeArea(
        right: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(10, 16, 10, 16), children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('Prestige Pharmacien', style: TextStyle(color: Charte.blanc, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          if (auth.officine != null || auth.user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: Text(auth.officine?.nomComplet ?? auth.user!.fullName, style: const TextStyle(color: Charte.enteteGris, fontSize: 13)),
            ),
          for (var i = 0; i < onglets.length; i++) ...[
            if (i == 0 || onglets[i - 1].rubrique != onglets[i].rubrique) groupe(onglets[i].rubrique),
            element(i, onglets[i].icone, onglets[i].libelle),
          ],
          groupe('Autres'),
          element(-1, Icons.settings_outlined, 'Réglages', action: () => ouvrirReglages(context)),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft, child: BoutonDeconnexion()),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// A · Tableau de bord
// ---------------------------------------------------------------------------------------------------------------

class _AccueilTableauDeBord extends StatelessWidget {
  final ChiffresDuJour? chiffres;
  final bool chargement;
  final Future<void> Function() actualiser;
  const _AccueilTableauDeBord({required this.chiffres, required this.chargement, required this.actualiser});

  List<Widget> _kpis() {
    final c = chiffres;
    if (c == null) {
      const attente = '…';
      return const [
        TuileKpi(libelle: 'Chiffre d\'affaires', valeur: attente),
        TuileKpi(libelle: 'Marge', valeur: attente),
        TuileKpi(libelle: 'Crédits du jour', valeur: attente),
        TuileKpi(libelle: 'Équipe présente', valeur: attente, enAvant: true),
      ];
    }
    final ventesOk = c.erreurVentes == null;
    final e = c.equipe;
    final taux = c.tauxMarge;
    return [
      TuileKpi(libelle: 'Chiffre d\'affaires', valeur: ventesOk ? formaterMontant(c.ca) : '—', detail: ventesOk ? 'Aujourd\'hui' : 'Indisponible'),
      TuileKpi(
          libelle: 'Marge',
          valeur: ventesOk ? formaterMontant(c.marge) : '—',
          detail: !ventesOk ? 'Indisponible' : (taux == null ? '—' : '${taux.toStringAsFixed(1).replaceAll('.', ',')} % du CA')),
      TuileKpi(libelle: 'Crédits du jour', valeur: ventesOk ? formaterMontant(c.credits) : '—', detail: ventesOk ? 'Ventes à crédit' : 'Indisponible'),
      TuileKpi(
        libelle: 'Équipe présente',
        valeur: e == null ? '—' : '${e.presents} / ${e.prevus}',
        detail: e == null ? 'Indisponible' : (e.retards == 0 ? 'Aucun retard' : '${e.retards} retard${e.retards > 1 ? 's' : ''}'),
        enAvant: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reglages = context.watch<HomeSettingsProvider>();
    final licence = context.watch<LicenceProvider>();
    final menus = menusVisibles(reglages);
    final joursLicence = licence.licence?.daysRemaining ?? 0;
    MenuModule? menu(String titre) => menus.where((m) => m.titre == titre).firstOrNull;
    final peremption = menu('Suivi Péremption');
    // Ruptures : liste propre au tableau de bord (pas de module), proposée dès qu'un menu est affiché.
    final ruptures = menus.isNotEmpty;
    final toutesAlertes = ProfilAcces.responsable && menu('Alertes') != null;

    final style = ApparenceAccueilPrefs.style.value;
    final affichage = estTabletteNouvelle(context) ? AffichageMenus.unePage : ApparenceAccueilPrefs.affichage.value;
    final parPages = affichage.parPages;

    final entete = EnTeteNavy(
      titre: auth.officine?.nomComplet ?? 'Prestige Pharmacien',
      sousTitre: '${auth.user?.fullName ?? 'Utilisateur'} · ${dateLisible(DateTime.now())}',
      retour: false,
      actions: [
        IconButton(
          tooltip: 'Actualiser les chiffres',
          onPressed: chargement ? null : actualiser,
          icon: const Icon(Icons.refresh, color: Charte.blanc),
        ),
        const BoutonReglages(),
        const BoutonDeconnexion(),
      ],
      enfants: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          PastilleServeur(apres: actualiser),
          const PastilleEntete('Aujourd\'hui', icone: Icons.today_outlined),
        ]),
        GrilleKpi(_kpis()),
      ],
    );

    // « À surveiller » : licence, alertes.
    final surveiller = <Widget>[
      if (joursLicence < 365)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CarteBande(
            bande: joursLicence < 30 ? Charte.rouge : Charte.vert,
            child: Row(children: [
              Icon(Icons.verified_user, color: joursLicence < 30 ? Charte.rougeTexte : Charte.vertTexte),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Licence valide : $joursLicence jours restants',
                    style: TextStyle(fontWeight: FontWeight.bold, color: joursLicence < 30 ? Charte.rougeTexte : Charte.vertTexte)),
              ),
            ]),
          ),
        ),
      if (peremption != null || ruptures || toutesAlertes) ...[
        if (!parPages) const TitreSection('À surveiller') else const SizedBox(height: 8),
        BlocAlertesSurveiller(peremption: peremption != null, ruptures: ruptures, toutesAlertes: toutesAlertes),
      ],
    ];

    Widget tuiles(List<MenuModule> liste) => GrilleTuiles([
          for (final m in liste)
            Builder(builder: (context) {
              final a = ApparenceIcone.pourMenu(style, m);
              return TuileMenu(
                  icone: m.icone,
                  titre: m.titre,
                  couleurIcone: a.icone,
                  fondIcone: a.pastille,
                  fond: a.fond,
                  illustration: style.illustre ? illustrationMenu(m.titre) : null,
                  onTap: () => ouvrirModule(context, m));
            }),
        ]);
    Widget grille(Famille f) => tuiles(deLaFamille(menus, f));
    const aucunMenu = Padding(
      padding: EdgeInsets.all(24),
      child: Text('Aucune fonctionnalité activée.\nOuvrez Réglages › Personnaliser l\'accueil pour en activer.',
          textAlign: TextAlign.center, style: TextStyle(color: Charte.gris)),
    );
    final familles = [for (final f in Famille.values) if (deLaFamille(menus, f).isNotEmpty) f];

    // Menus par pages (réglage « Menus de l'accueil », téléphone) : « À surveiller », puis une famille par page
    // (« Une rubrique par page ») ou 6 tuiles par page, dans l'ordre des familles (« 6 tuiles par page »).
    if (parPages) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // En-tête borné (60 % de la hauteur) et défilant : les pages gardent toujours de la place, même en grand texte.
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
          child: SingleChildScrollView(key: const Key('defilement_entete_pages'), child: entete),
        ),
        Expanded(
          child: menus.isEmpty && surveiller.isEmpty
              ? const SingleChildScrollView(child: aucunMenu)
              : PagesMenus(pages: [
                  if (surveiller.isNotEmpty)
                    PageMenus(
                      'À surveiller',
                      ListView(key: const Key('page_menus_surveiller'), padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                        ...surveiller,
                        if (menus.isEmpty) aucunMenu,
                      ]),
                    ),
                  if (affichage == AffichageMenus.parRubrique)
                    for (final f in familles)
                      PageMenus(
                        f.libelle,
                        ListView(key: Key('page_menus_${f.name}'), padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [grille(f)]),
                        couleur: couleurEnTeteFamille(style, f),
                      )
                  else
                    for (final (i, paquet) in paquetsDeMenus(menus).indexed)
                      PageMenus(
                        titrePaquet(paquet),
                        ListView(key: Key('page_menus_paquet_$i'), padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [tuiles(paquet)]),
                        couleur: couleurPaquet(style, paquet),
                      ),
                ]),
        ),
      ]);
    }

    return RefreshIndicator(
      onRefresh: actualiser,
      child: ListView(key: const Key('defilement_accueil'), padding: EdgeInsets.zero, children: [
        entete,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ...surveiller,
            if (menus.isEmpty) aucunMenu,
            for (final f in familles) ...[
              TitreSection(f.libelle, couleur: couleurEnTeteFamille(style, f)),
              grille(f),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// B · Compact
// ---------------------------------------------------------------------------------------------------------------

class _AccueilCompact extends StatefulWidget {
  final TextEditingController recherche;
  final bool tablette;
  const _AccueilCompact({required this.recherche, required this.tablette});

  @override
  State<_AccueilCompact> createState() => _AccueilCompactState();
}

class _AccueilCompactState extends State<_AccueilCompact> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ip = context.watch<IpConfigProvider>();
    final menus = menusVisibles(context.watch<HomeSettingsProvider>());
    final q = sansAccents(widget.recherche.text.trim());
    final trouves = q.isEmpty ? menus : [for (final m in menus) if (sansAccents('${m.titre} ${m.sousTitre}').contains(q)) m];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BarreBlanche(
        titre: 'Prestige Pharmacien',
        sousTitre: Row(children: [
          const Point(Charte.vert),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${auth.officine?.nomComplet ?? 'Officine'} · ${auth.user?.fullName ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: ip.useLocalIp ? 'Passer en mode Distant' : 'Passer en mode Local',
            icon: Icon(ip.useLocalIp ? Icons.lan_outlined : Icons.public, color: Charte.navy),
            onPressed: () => basculerServeur(context),
          ),
          const BoutonReglages(couleur: Charte.navy),
          const BoutonDeconnexion(couleur: Charte.navy),
        ],
      ),
      Container(
        color: Charte.blanc,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: TextField(
          key: const Key('recherche_menu'),
          controller: widget.recherche,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Rechercher un menu',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            suffixIcon: widget.recherche.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(widget.recherche.clear),
                  ),
          ),
        ),
      ),
      Expanded(
        child: trouves.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucun menu ne correspond.', style: TextStyle(color: Charte.gris)),
                ),
              )
            : widget.tablette
                ? _DeuxColonnes(menus: trouves)
                // Menus par pages (réglage, téléphone) ; pendant une recherche, les résultats restent sur une page.
                : switch (q.isEmpty ? ApparenceAccueilPrefs.affichage.value : AffichageMenus.unePage) {
                    AffichageMenus.parRubrique => PagesMenusParFamille(menus: trouves),
                    AffichageMenus.parSix => PagesMenusParSix(menus: trouves),
                    AffichageMenus.unePage => ListeMenusParFamille(menus: trouves),
                  },
      ),
    ]);
  }
}

/// Ligne de menu dans le style d'icônes choisi.
LigneMenu ligneMenuModule(BuildContext context, MenuModule m, StyleIcones style) {
  final a = ApparenceIcone.pourMenu(style, m);
  return LigneMenu(
    icone: m.icone,
    titre: m.titre,
    sousTitre: m.sousTitre,
    couleurIcone: a.icone,
    fondIcone: a.pastille,
    fond: a.fond,
    illustration: style.illustre ? illustrationMenu(m.titre) : null,
    onTap: () => ouvrirModule(context, m),
  );
}

/// Menus rangés par familles (même ordre que la page unique), puis coupés en paquets de [taille] (« 6 tuiles par
/// page »).
List<List<MenuModule>> paquetsDeMenus(List<MenuModule> menus, {int taille = menusParPage}) {
  final ordonnes = [for (final f in Famille.values) ...deLaFamille(menus, f)];
  return [for (var i = 0; i < ordonnes.length; i += taille) ordonnes.sublist(i, (i + taille).clamp(0, ordonnes.length))];
}

/// Titre d'une page de 6 menus : la ou les familles présentes (« Ventes & caisse · Crédits & clients »).
String titrePaquet(List<MenuModule> paquet) => {for (final m in paquet) m.famille.libelle}.join(' · ');

/// Couleur du titre d'une page de 6 menus (P3) : celle de la famille si la page n'en a qu'une.
Color? couleurPaquet(StyleIcones style, List<MenuModule> paquet) {
  final familles = {for (final m in paquet) m.famille};
  return familles.length == 1 ? couleurEnTeteFamille(style, familles.first) : null;
}

/// Liste plate par familles (présentation B, « Tous les menus » de C, onglet Analyses).
class ListeMenusParFamille extends StatelessWidget {
  final List<MenuModule> menus;
  final List<Famille> familles;
  const ListeMenusParFamille({super.key, required this.menus, this.familles = Famille.values});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ApparenceAccueilPrefs.style,
        builder: (context, _) {
          final style = ApparenceAccueilPrefs.style.value;
          return ListView(key: const Key('defilement_menus'), padding: const EdgeInsets.only(bottom: 16), children: [
            for (final f in familles)
              if (deLaFamille(menus, f).isNotEmpty) ...[
                Container(
                  color: Charte.page,
                  child: TitreSection(f.libelle, marge: const EdgeInsets.fromLTRB(16, 14, 16, 6), couleur: couleurEnTeteFamille(style, f)),
                ),
                for (final m in deLaFamille(menus, f)) ligneMenuModule(context, m, style),
              ],
          ]);
        },
      );
}

/// Menus par pages, une famille par page (présentation B sur téléphone, réglage « Menus de l'accueil »).
class PagesMenusParFamille extends StatelessWidget {
  final List<MenuModule> menus;
  const PagesMenusParFamille({super.key, required this.menus});

  @override
  Widget build(BuildContext context) {
    final style = ApparenceAccueilPrefs.style.value;
    return PagesMenus(pages: [
      for (final f in Famille.values)
        if (deLaFamille(menus, f).isNotEmpty)
          PageMenus(
            f.libelle,
            ListView(
              key: Key('page_menus_${f.name}'),
              padding: const EdgeInsets.only(bottom: 16),
              children: [for (final m in deLaFamille(menus, f)) ligneMenuModule(context, m, style)],
            ),
            couleur: couleurEnTeteFamille(style, f),
          ),
    ]);
  }
}

/// Menus par pages de 6 lignes (présentation B sur téléphone, réglage « 6 tuiles par page »).
class PagesMenusParSix extends StatelessWidget {
  final List<MenuModule> menus;
  const PagesMenusParSix({super.key, required this.menus});

  @override
  Widget build(BuildContext context) {
    final style = ApparenceAccueilPrefs.style.value;
    return PagesMenus(pages: [
      for (final (i, paquet) in paquetsDeMenus(menus).indexed)
        PageMenus(
          titrePaquet(paquet),
          ListView(
            key: Key('page_menus_paquet_$i'),
            padding: const EdgeInsets.only(bottom: 16),
            children: [for (final m in paquet) ligneMenuModule(context, m, style)],
          ),
          couleur: couleurPaquet(style, paquet),
        ),
    ]);
  }
}

/// Menus sur deux colonnes (tablette, présentation B).
class _DeuxColonnes extends StatelessWidget {
  final List<MenuModule> menus;
  const _DeuxColonnes({required this.menus});

  @override
  Widget build(BuildContext context) {
    final familles = [for (final f in Famille.values) if (deLaFamille(menus, f).isNotEmpty) f];
    final style = ApparenceAccueilPrefs.style.value;
    Widget carte(Famille f) => CarteSection(
          titre: f.libelle,
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
          enfants: [for (final m in deLaFamille(menus, f)) ligneMenuModule(context, m, style)],
        );
    // Répartition équilibrée : chaque famille va dans la colonne la moins remplie.
    final gauche = <Famille>[], droite = <Famille>[];
    var nG = 0, nD = 0;
    for (final f in familles) {
      final n = deLaFamille(menus, f).length + 1;
      if (nG <= nD) {
        gauche.add(f);
        nG += n;
      } else {
        droite.add(f);
        nD += n;
      }
    }
    return SingleChildScrollView(
      key: const Key('defilement_menus'),
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(children: [for (final f in gauche) carte(f)])),
        const SizedBox(width: 16),
        Expanded(child: Column(children: [for (final f in droite) carte(f)])),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// C · Guidé
// ---------------------------------------------------------------------------------------------------------------

class _AccueilGuide extends StatelessWidget {
  const _AccueilGuide();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final menus = menusVisibles(context.watch<HomeSettingsProvider>());
    final prenom = auth.user?.firstName ?? '';
    return ListView(key: const Key('defilement_accueil'), padding: EdgeInsets.zero, children: [
      EnTeteNavy(
        titre: prenom.isEmpty ? 'Bonjour' : 'Bonjour $prenom',
        sousTitre: 'Que voulez-vous savoir ?',
        retour: false,
        actions: const [BoutonReglages(), BoutonDeconnexion()],
        enfants: const [Align(alignment: Alignment.centerLeft, child: PastilleServeur())],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final q in Question.values)
            if (menus.any((m) => m.question == q))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GrandeCarte(
                  icone: q.icone,
                  fond: q.fond,
                  titre: q.titre,
                  sousTitre: q.detail,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuestionScreen(question: q))),
                ),
              ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TousLesMenusScreen())),
            icon: const Icon(Icons.apps),
            label: const Text('Voir tous les menus'),
          ),
        ]),
      ),
    ]);
  }
}

/// Menus d'une question (présentation C).
class QuestionScreen extends StatelessWidget {
  final Question question;
  const QuestionScreen({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    final menus = [for (final m in menusVisibles(context.watch<HomeSettingsProvider>())) if (m.question == question) m];
    return Scaffold(
      appBar: AppBar(title: Text(question.titre)),
      body: ListView(key: const Key('defilement_question'), padding: const EdgeInsets.all(16), children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Text(question.detail, style: const TextStyle(color: Charte.gris, fontSize: 14)),
        ),
        for (final m in menus)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GrandeCarte(icone: m.icone, fond: question.fond, titre: m.titre, sousTitre: m.sousTitre, onTap: () => ouvrirModule(context, m)),
          ),
      ]),
    );
  }
}

/// Tous les menus en liste (présentation C, « Voir tous les menus »).
class TousLesMenusScreen extends StatelessWidget {
  const TousLesMenusScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tous les menus')),
        body: ListeMenusParFamille(menus: menusVisibles(context.watch<HomeSettingsProvider>())),
      );
}

// ---------------------------------------------------------------------------------------------------------------
// Onglets Analyses et Équipe
// ---------------------------------------------------------------------------------------------------------------

/// Onglet « Analyses » : recherche de produit (mode « contient », 3.9.0) en haut, puis les menus d'analyse.
class OngletAnalyses extends StatelessWidget {
  const OngletAnalyses({super.key});

  @override
  Widget build(BuildContext context) {
    final menus = menusVisibles(context.watch<HomeSettingsProvider>());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const EnTeteNavy(titre: 'Analyses', sousTitre: 'Produits, chiffres, ventes et crédits', retour: false),
      Expanded(child: RechercheProduitAnalyses(menus: ListeMenusParFamille(menus: menus, familles: famillesAnalyses))),
    ]);
  }
}

class OngletEquipe extends StatelessWidget {
  const OngletEquipe({super.key});

  @override
  Widget build(BuildContext context) {
    final menus = menusVisibles(context.watch<HomeSettingsProvider>());
    final presences = menus.any((m) => m.titre == 'Présences');
    final journal = menus.any((m) => m.titre == 'Fichier Journal');
    void ouvrir(Widget ecran) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecran));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const EnTeteNavy(titre: 'Équipe', sousTitre: 'Présences, retards et journal', retour: false),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (presences)
            CarteSection(
              titre: 'Présences',
              icone: Icons.badge_outlined,
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
              enfants: [
                LigneMenu(
                    icone: Icons.today_outlined,
                    titre: 'Présence du jour',
                    sousTitre: 'Retards et absents en premier',
                    onTap: () => ouvrir(const PresencesScreen())),
                LigneMenu(
                    icone: Icons.calendar_month_outlined,
                    titre: 'Tableau des présences',
                    sousTitre: 'Une période, exports Excel et PDF',
                    onTap: () => ouvrir(const PresencesScreen(onglet: 1))),
                LigneMenu(
                    icone: Icons.qr_code_2_outlined,
                    titre: 'Pointage & téléphones',
                    sousTitre: 'QR code du moment, téléphones enregistrés',
                    onTap: () => ouvrir(const PresencesScreen(onglet: 2))),
              ],
            ),
          if (journal)
            CarteSection(
              titre: 'Activité',
              icone: Icons.history_edu_outlined,
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
              enfants: [
                LigneMenu(
                    icone: Icons.history_edu_outlined,
                    titre: 'Fichier Journal',
                    sousTitre: 'Actions des utilisateurs',
                    onTap: () => ouvrir(const FichierJournalNouveau())),
              ],
            ),
          if (!presences && !journal)
            const Text('Aucun menu « Équipe » activé (Réglages › Personnaliser l\'accueil).', style: TextStyle(color: Charte.gris)),
        ]),
      ),
    ]);
  }
}
