// lib/nouvelle_interface/reglages_nouveaux.dart
// Réglages de la nouvelle interface (page ouverte par le bouton engrenage de l'accueil, plus un onglet) :
//  - Apparence : « Nouvelle interface » (retour à l'ancienne, mémorisé) et présentation A / B / C (mémorisée sur
//    l'appareil, valable pour tous les comptes ; seul l'administrateur la change : compte « admin », ou code
//    administrateur demandé) ;
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
import 'charte.dart';
import 'composants.dart';
import 'menus.dart';
import 'presentation.dart';

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
                    builder: (_) => PersonalizeHomeScreen(allItems: [for (final m in menusModules) m.pourPersonnalisation]))),
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
