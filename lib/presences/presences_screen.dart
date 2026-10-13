// lib/presences/presences_screen.dart
// Module « Présences » (menu ajouté à l'accueil existant). Le pharmacien a tous les droits une fois connecté :
// rien n'est masqué ; si Prestige refuse (droit P_SM_RH absent du profil), chaque écran l'explique clairement.
// Trois onglets : Jour (présence du jour / de la veille), Période (tableau + exports), Pointage (QR + téléphones) ;
// réglages du module (seuil de retard) dans la barre. Téléphone : barre d'onglets en bas ; tablette : rail latéral.
import 'package:flutter/material.dart';

import 'pointage_view.dart';
import 'presence_jour_view.dart';
import 'presences_reglages.dart';
import 'presences_reglages_screen.dart';
import 'presences_widgets.dart';
import 'tableau_periode_view.dart';

class PresencesScreen extends StatefulWidget {
  /// Onglet ouvert au départ (0 : Jour, 1 : Période, 2 : Pointage).
  final int onglet;
  const PresencesScreen({super.key, this.onglet = 0});

  @override
  State<PresencesScreen> createState() => _PresencesScreenState();
}

class _PresencesScreenState extends State<PresencesScreen> {
  late int _onglet = widget.onglet.clamp(0, 2);
  final _cleJour = GlobalKey<PresenceJourViewState>();
  final _clePeriode = GlobalKey<TableauPeriodeViewState>();
  final _clePointage = GlobalKey<PointageViewState>();
  bool _reglagesCharges = false;

  static const _titres = ['Présence du jour', 'Tableau des présences', 'Pointage & téléphones'];

  @override
  void initState() {
    super.initState();
    ReglagesPresences.charger().then((_) {
      if (mounted) setState(() => _reglagesCharges = true);
    });
  }

  void _actualiser() {
    switch (_onglet) {
      case 0:
        _cleJour.currentState?.actualiser();
      case 1:
        _clePeriode.currentState?.actualiser();
      default:
        _clePointage.currentState?.actualiser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tablette = estTablette(context);
    // Le seuil du pharmacien est lu avant la première liste (sinon le premier affichage utiliserait 60 min).
    final Widget vue = !_reglagesCharges
        ? const Center(child: CircularProgressIndicator())
        : switch (_onglet) {
            0 => PresenceJourView(key: _cleJour),
            1 => TableauPeriodeView(key: _clePeriode),
            _ => PointageView(key: _clePointage),
          };
    const destinations = [
      (Icons.today_outlined, Icons.today, 'Jour'),
      (Icons.calendar_month_outlined, Icons.calendar_month, 'Période'),
      (Icons.qr_code_2_outlined, Icons.qr_code_2, 'Pointage'),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: Text(_titres[_onglet]),
        actions: [
          IconButton(key: const Key('presences_actualiser'), tooltip: 'Actualiser', onPressed: _actualiser, icon: const Icon(Icons.refresh)),
          IconButton(
            key: const Key('presences_reglages'),
            tooltip: 'Réglages des présences',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReglagesPresencesScreen())),
          ),
        ],
      ),
      body: tablette
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              NavigationRail(
                selectedIndex: _onglet,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (i) => setState(() => _onglet = i),
                destinations: [
                  for (final d in destinations) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: vue),
            ])
          : vue,
      bottomNavigationBar: tablette
          ? null
          : NavigationBar(
              selectedIndex: _onglet,
              height: 64,
              onDestinationSelected: (i) => setState(() => _onglet = i),
              destinations: [
                for (final d in destinations) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
              ],
            ),
    );
  }
}
