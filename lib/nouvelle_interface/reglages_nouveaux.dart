// lib/nouvelle_interface/reglages_nouveaux.dart
// Réglages de la nouvelle interface (page ouverte par le bouton engrenage de l'accueil, plus un onglet) :
//  - Apparence : « Nouvelle interface » (retour à l'ancienne, mémorisé) et présentation A / B / C (mémorisée sur
//    l'appareil, valable pour tous les comptes ; seul l'administrateur la change : compte « admin », ou code
//    administrateur demandé) ; taille de l'écran (Automatique / Compact / Très compact, docs/TAILLE_ECRAN.md ; même
//    règle que la présentation depuis la 3.8.0 : sans code pour le compte « admin », code pour les autres) ;
//    « Menus de l'accueil » (3.10.0 : tout sur une page / une rubrique par page / 6 tuiles par page ; modifiable par
//    l'administrateur ou le pharmacien SEULEMENT, verrouillé avec explication pour les autres comptes) ; « Style des
//    icônes » (propositions visuelles 3.9.0, P4 « icônes illustrées » en 3.10.0, réglage caché : montré au seul
//    compte « admin ») ;
//  - Serveur : mode local / distant, configuration du serveur ;
//  - Accueil : personnaliser (ordre et menus masqués, communs aux deux interfaces) ;
//  - Compte : utilisateur, officine, licence, déconnexion.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../interface_version.dart';
import '../providers/auth_provider.dart';
import '../providers/ip_config_provider.dart';
import '../providers/licence_provider.dart';
import '../screens/personalize_home_screen.dart';
import '../screens/settings_screen.dart';
import 'accueil_nouveau.dart';
import 'apparence_accueil.dart';
import 'charte.dart';
import 'composants.dart';
import 'menus.dart';
import 'presentation.dart';
import '../version_app.dart';
import '../widgets/taille_ecran_reglage.dart';

/// Page des Réglages (bouton engrenage en haut à droite de l'accueil).
class ReglagesScreen extends StatelessWidget {
  const ReglagesScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: OngletReglages(retour: true));
}

class OngletReglages extends StatelessWidget {
  /// Flèche de retour dans l'en-tête (page ouverte depuis l'accueil).
  final bool retour;
  const OngletReglages({super.key, this.retour = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ip = context.watch<IpConfigProvider>();
    final licence = context.watch<LicenceProvider>();
    final admin = PresentationPrefs.estAdministrateur(context);
    final tablette = estTabletteNouvelle(context);
    final jours = licence.licence?.daysRemaining;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      EnTeteNavy(titre: 'Réglages', sousTitre: 'Apparence, serveur et compte', retour: retour),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          CarteSection(
            titre: 'Apparence',
            icone: Icons.palette_outlined,
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
            enfants: [
              const InterfaceVersionTile(),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  admin
                      ? 'Présentation (pour tous les comptes de ce téléphone)'
                      : 'Présentation (choisie par l\'administrateur ; le code administrateur est demandé pour la changer)',
                  style: const TextStyle(color: Charte.gris, fontSize: 13),
                ),
              ),
              ValueListenableBuilder<Presentation>(
                valueListenable: PresentationPrefs.choix,
                builder: (context, choix, _) => RadioGroupPresentation(
                  choix: choix,
                  verrouille: !admin,
                  effective: PresentationPrefs.effective(choix, tablette: tablette),
                ),
              ),
              const Divider(height: 1),
              // Menus de l'accueil : tout sur une page (0, défaut), une rubrique par page (1), 6 tuiles par page (2) ;
              // administrateur ou pharmacien seulement (3.10.0).
              ValueListenableBuilder<AffichageMenus>(
                valueListenable: ApparenceAccueilPrefs.affichage,
                builder: (context, choix, _) =>
                    ChoixAffichageMenus(choix: choix, verrouille: !ApparenceAccueilPrefs.peutChangerAffichage(context)),
              ),
              if (admin) ...[
                const Divider(height: 1),
                // Propositions visuelles (3.9.0) : réglage caché, compte « admin » seulement.
                ValueListenableBuilder<StyleIcones>(
                  valueListenable: ApparenceAccueilPrefs.style,
                  builder: (context, choix, _) => ChoixStyleIcones(choix: choix),
                ),
              ],
              const Divider(height: 1),
              // Affichage : taille de l'écran (appliquée au prochain lancement) ; compte « admin » : sans code (3.8.0).
              TailleEcranSetting(couleurAide: Charte.gris, administrateur: admin),
            ],
          ),
          CarteSection(
            titre: 'Serveur',
            icone: Icons.dns_outlined,
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
            enfants: [
              SwitchListTile(
                key: const Key('reglages_serveur_local'),
                title: const Text('Serveur local'),
                subtitle: Text(ip.useLocalIp
                    ? 'Adresse locale utilisée (${ip.localIp}:${ip.port})'
                    : 'Adresse distante utilisée (${ip.remoteIp}:${ip.port})'),
                value: ip.useLocalIp,
                onChanged: (_) => basculerServeur(context),
              ),
              ListTile(
                leading: const Icon(Icons.settings_ethernet),
                title: const Text('Configuration du serveur'),
                subtitle: const Text('Adresses, port, délai de déconnexion'),
                trailing: const Icon(Icons.chevron_right, color: Charte.gris),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
          CarteSection(
            titre: 'Accueil',
            icone: Icons.dashboard_customize_outlined,
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
            enfants: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Personnaliser l\'accueil'),
                subtitle: const Text('Ordre des menus, menus masqués'),
                trailing: const Icon(Icons.chevron_right, color: Charte.gris),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PersonalizeHomeScreen(allItems: [for (final m in menusAutorises()) m.pourPersonnalisation]))),
              ),
            ],
          ),
          CarteSection(
            titre: 'Compte',
            icone: Icons.person_outline,
            enfants: [
              Text(auth.user?.fullName ?? 'Utilisateur', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if ((auth.user?.login ?? '').isNotEmpty)
                Text('Identifiant : ${auth.user!.login}${admin ? ' (administrateur)' : ''}', style: const TextStyle(color: Charte.gris)),
              // Rôle donné par les serveurs récents à la connexion (3.10.0) ; rien sur un serveur plus ancien.
              if ((auth.user?.roleLibelle ?? '').isNotEmpty)
                Text('Rôle : ${auth.user!.roleLibelle}', key: const Key('reglages_role'), style: const TextStyle(color: Charte.gris)),
              if (auth.officine != null) Text(auth.officine!.nomComplet, style: const TextStyle(color: Charte.gris)),
              if (jours != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Etiquette('Licence valide : $jours jours restants', ton: jours < 30 ? Ton.rouge : Ton.vert),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
              ),
            ],
          ),
          // Version installée, discrète (lue à l'exécution : pubspec.yaml est la seule source).
          const Padding(key: Key('reglages_version'), padding: EdgeInsets.only(top: 12), child: VersionAffichee(couleur: Charte.gris)),
        ]),
      ),
    ]);
  }
}

/// Choix de la présentation (Automatique, A, B, C).
class RadioGroupPresentation extends StatelessWidget {
  final Presentation choix;
  final Presentation effective;
  final bool verrouille;
  const RadioGroupPresentation({super.key, required this.choix, required this.effective, required this.verrouille});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final p in Presentation.values)
          ListTile(
            key: Key('presentation_${p.name}'),
            leading: Icon(p == choix ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: p == choix ? Charte.navy : Charte.gris),
            title: Text(p.libelle),
            subtitle: Text(p == Presentation.automatique && p == choix ? '${p.description} · affichée : ${effective.lettre}' : p.description),
            trailing: verrouille && p != choix ? const Icon(Icons.lock_outline, color: Charte.gris, semanticLabel: 'Réservé à l\'administrateur') : null,
            selected: p == choix,
            onTap: () => PresentationPrefs.changer(context, p),
          ),
      ]);
}

/// Choix « Menus de l'accueil » : tout sur une page (défaut) / une rubrique par page / 6 tuiles par page.
/// [verrouille] : compte ni administrateur ni pharmacien — choix visible, non modifiable, avec l'explication.
class ChoixAffichageMenus extends StatelessWidget {
  final AffichageMenus choix;
  final bool verrouille;
  const ChoixAffichageMenus({super.key, required this.choix, required this.verrouille});

  void _refuser(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(key: Key('affichage_menus_refus'), content: Text(ApparenceAccueilPrefs.explicationAffichageVerrouille)));
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Menus de l\'accueil (présentations A et B sur téléphone)', style: TextStyle(color: Charte.gris, fontSize: 13)),
        ),
        if (verrouille)
          const Padding(
            key: Key('affichage_menus_verrouille'),
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lock_outline, size: 18, color: Charte.grisTexte),
              SizedBox(width: 6),
              Expanded(
                child: Text(ApparenceAccueilPrefs.explicationAffichageVerrouille, style: TextStyle(color: Charte.grisTexte, fontSize: 13)),
              ),
            ]),
          ),
        for (final a in AffichageMenus.values)
          ListTile(
            key: Key('affichage_menus_${a.name}'),
            leading: Icon(a == choix ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: a == choix ? Charte.navy : Charte.gris),
            title: Text(a == AffichageMenus.unePage ? '${a.libelle} (par défaut)' : a.libelle),
            subtitle: Text(a.description),
            trailing: verrouille && a != choix
                ? const Icon(Icons.lock_outline, color: Charte.gris, semanticLabel: 'Réservé à l\'administrateur ou au pharmacien')
                : null,
            selected: a == choix,
            onTap: () {
              if (a == choix) return;
              if (verrouille) {
                _refuser(context);
                return;
              }
              ApparenceAccueilPrefs.changerAffichage(context, a);
            },
          ),
      ]);
}

/// Choix « Style des icônes » (propositions, compte « admin » seulement).
class ChoixStyleIcones extends StatelessWidget {
  final StyleIcones choix;
  const ChoixStyleIcones({super.key, required this.choix});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Style des icônes (propositions à essayer ; réglage visible du seul compte « admin »)',
              style: TextStyle(color: Charte.gris, fontSize: 13)),
        ),
        for (final s in StyleIcones.values)
          ListTile(
            key: Key('style_icones_${s.name}'),
            leading: Icon(s == choix ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: s == choix ? Charte.navy : Charte.gris),
            title: Text(s.libelle),
            subtitle: Text(s.description),
            selected: s == choix,
            onTap: () => ApparenceAccueilPrefs.changerStyle(context, s),
          ),
      ]);
}
