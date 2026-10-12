// lib/screens/serveur_injoignable_screen.dart
// Lancement : le serveur n'a pas pu être interrogé (injoignable, délai, application Prestige absente à
// cette adresse, erreur du serveur). Même règle que prestige_vente_app (lib/connexion/lancement_screen.dart) :
// la licence n'est PAS en cause ; message clair, « Réessayer », réessai automatique toutes les 10 s,
// « Configuration » protégée par le code administrateur.
// Avant l'étape 1, ce cas était affiché comme « Licence requise » (écran d'enregistrement de licence).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/licence_lookup.dart';
import '../providers/ip_config_provider.dart';
import '../providers/licence_provider.dart';
import '../widgets/pin_code_dialog.dart';
import 'settings_screen.dart';

/// Compte à rebours avant un nouvel essai automatique (copie de prestige_vente_app).
class CompteARebours extends ChangeNotifier {
  final Duration duree;
  final FutureOr<void> Function() action;
  Timer? _t;
  int reste = 0;
  bool _fini = false;

  CompteARebours({required this.duree, required this.action});

  bool get actif => _t?.isActive ?? false;

  void demarrer() {
    _t?.cancel();
    reste = duree.inSeconds;
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      reste--;
      if (reste <= 0) {
        t.cancel();
        if (!_fini) action();
      }
      if (!_fini) notifyListeners();
    });
    notifyListeners();
  }

  void arreter() {
    _t?.cancel();
    reste = 0;
  }

  @override
  void dispose() {
    _fini = true;
    _t?.cancel();
    super.dispose();
  }
}

class ServeurInjoignableScreen extends StatefulWidget {
  /// Intervalle du réessai automatique.
  static const intervalleReessai = Duration(seconds: 10);

  const ServeurInjoignableScreen({super.key});

  @override
  State<ServeurInjoignableScreen> createState() => _ServeurInjoignableScreenState();
}

class _ServeurInjoignableScreenState extends State<ServeurInjoignableScreen> {
  late final CompteARebours _rebours = CompteARebours(duree: ServeurInjoignableScreen.intervalleReessai, action: _reessayer)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  @override
  void initState() {
    super.initState();
    _rebours.demarrer();
  }

  @override
  void dispose() {
    _rebours.dispose();
    super.dispose();
  }

  Future<void> _reessayer() async {
    if (!mounted) return;
    _rebours.arreter();
    setState(() {});
    final licence = context.read<LicenceProvider>();
    await licence.checkLicence(context, silencieux: true);
    // Toujours injoignable : l'écran reste affiché, nouveau compte à rebours.
    if (mounted && licence.status == LicenceStatus.error) _rebours.demarrer();
  }

  Future<void> _configuration() async {
    _rebours.arreter();
    // Sans être connecté, la configuration du serveur est protégée par le code administrateur.
    if (await PinCodeDialog.show(context) && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
    if (mounted) _reessayer();
  }

  Future<void> _basculer(IpConfigProvider ip) async {
    ip.setUseLocalIp(!ip.useLocalIp);
    await Future<void>.delayed(Duration.zero);
    _reessayer();
  }

  static (String, String) _textes(LicenceLookup? echec) {
    switch (echec?.issue) {
      case LicenceIssue.appNotFound:
        return (
          'Prestige introuvable à cette adresse',
          'Un serveur répond, mais l\'application Prestige n\'y est pas trouvée (nom de l\'application ou port incorrect, '
              'application arrêtée). La licence n\'est pas en cause.'
        );
      case LicenceIssue.serverError:
        return (
          'Le serveur Prestige a répondu par une erreur',
          'Le serveur de l\'officine est joignable mais n\'a pas pu répondre. Réessayez dans un instant. La licence n\'est pas en cause.'
        );
      case LicenceIssue.unexpectedResponse:
        return (
          'Réponse inattendue du serveur',
          'L\'adresse configurée ne semble pas être celle du serveur Prestige. Vérifiez la configuration. La licence n\'est pas en cause.'
        );
      case LicenceIssue.unreachable:
      case null:
        return (
          'Le serveur ne répond pas',
          'Vérifiez le Wi-Fi ou les données mobiles et que le serveur de l\'officine est allumé. La licence n\'est pas en cause.'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<IpConfigProvider>();
    final licence = context.watch<LicenceProvider>();
    final enCours = licence.verificationEnCours;
    final (titre, texte) = _textes(licence.dernierEchec);
    final adresse = ip.useLocalIp ? ip.localIp : ip.remoteIp;
    final autreAdresse = ip.useLocalIp ? ip.remoteIp : ip.localIp;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Connexion au serveur'), automaticallyImplyLeading: false),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.wifi_off, size: 72, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(titre,
                      key: const Key('injoignable_titre'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Serveur ${ip.useLocalIp ? 'local' : 'distant'} · $adresse:${ip.port}',
                  key: const Key('injoignable_adresse'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(texte, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF5B6B82), height: 1.35)),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    key: const Key('injoignable_reessayer'),
                    onPressed: enCours ? null : _reessayer,
                    icon: enCours
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    enCours || _rebours.reste <= 0 ? 'Nouvel essai…' : 'Nouvel essai automatique dans ${_rebours.reste} s',
                    key: const Key('injoignable_decompte'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF5B6B82)),
                  ),
                ),
                const SizedBox(height: 16),
                if (autreAdresse.isNotEmpty)
                  OutlinedButton.icon(
                    key: const Key('injoignable_basculer'),
                    onPressed: enCours ? null : () => _basculer(ip),
                    icon: Icon(ip.useLocalIp ? Icons.public : Icons.computer),
                    label: Text(ip.useLocalIp ? 'Essayer le serveur distant' : 'Essayer le serveur local'),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const Key('injoignable_configuration'),
                    onPressed: _configuration,
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Configuration'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
