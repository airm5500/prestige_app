// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ip_config_provider.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';
import '../utils/adresse_serveur.dart';
import '../utils/constants.dart';
import '../widgets/pin_code_dialog.dart';
import '../utils/saisie.dart';
import '../interface_version.dart';
import '../nouvelle_interface/charte.dart';
import '../nouvelle_interface/composants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _localIpController;
  late TextEditingController _remoteIpController;
  late TextEditingController _portController;
  late TextEditingController _timeoutController;
  late TextEditingController _appNameController;
  bool _isLoading = false;

  bool _isPingingLocal = false;
  bool _isPingingRemote = false;
  bool _isPortEditable = false;
  bool _isAppNameEditable = false;

  String? _localPingMessage;
  bool? _localPingSuccess;
  String? _remotePingMessage;
  bool? _remotePingSuccess;

  @override
  void initState() {
    super.initState();
    final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
    _localIpController = TextEditingController(text: ipProvider.localIp);
    _remoteIpController = TextEditingController(text: ipProvider.remoteIp);
    _portController = TextEditingController(text: ipProvider.port);
    _timeoutController = TextEditingController(text: ipProvider.sessionTimeout.toString());
    _appNameController = TextEditingController(text: ipProvider.appName);
  }

  @override
  void dispose() {
    _localIpController.dispose();
    _remoteIpController.dispose();
    _portController.dispose();
    _timeoutController.dispose();
    _appNameController.dispose();
    super.dispose();
  }

  Future<void> _handlePing(bool isLocal) async {
    FocusScope.of(context).unfocus();
    final ipToTest = isLocal ? _localIpController.text.trim() : _remoteIpController.text.trim();

    if (ipToTest.isEmpty) {
      if (mounted) setState(() {
        if (isLocal) { _localPingMessage = 'Champ vide.'; _localPingSuccess = false; }
        else { _remotePingMessage = 'Champ vide.'; _remotePingSuccess = false; }
      });
      return;
    }

    if (mounted) setState(() {
      if (isLocal) { _isPingingLocal = true; _localPingMessage = 'Test en cours...'; _localPingSuccess = null; }
      else { _isPingingRemote = true; _remotePingMessage = 'Test en cours...'; _remotePingSuccess = null; }
    });

    final success = await ApiService.ping(ipToTest, _portController.text.trim(), _appNameController.text.trim());

    if (mounted) {
      setState(() {
        if (isLocal) { _isPingingLocal = false; _localPingSuccess = success; _localPingMessage = success ? 'Réussi !' : 'Échec.'; }
        else { _isPingingRemote = false; _remotePingSuccess = success; _remotePingMessage = success ? 'Réussi !' : 'Échec.'; }
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      List<Future> pingTasks = [];
      if (_localIpController.text.trim().isNotEmpty) pingTasks.add(_handlePing(true));
      if (_remoteIpController.text.trim().isNotEmpty) pingTasks.add(_handlePing(false));
      await Future.wait(pingTasks);

      try {
        await ipProvider.updateSettings(
          _localIpController.text.trim(),
          _remoteIpController.text.trim(),
          _portController.text.trim(),
          int.tryParse(_timeoutController.text.trim()) ?? AppConstants.defaultSessionTimeout,
          _appNameController.text.trim(),
        );

        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Configuration enregistrée avec succès.'), backgroundColor: Colors.green));

        if (navigator.canPop()) {
          navigator.pop();
        }

      } catch (e) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erreur lors de l\'enregistrement: ${e.toString()}'), backgroundColor: Colors.red));
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nouvelle interface : mêmes champs et mêmes contrôles, rangés en cartes.
    if (InterfaceVersion.nouvelle(context)) return _buildNouveau(context);
    final theme = Theme.of(context);
    final canPop = Navigator.canPop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration IP'), automaticallyImplyLeading: canPop),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Configurer les adresses IP du serveur', style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColorDark), textAlign: TextAlign.center),
                const SizedBox(height: 30),
                _buildIpInputRow(controller: _localIpController, labelText: 'Adresse IP Locale', hintText: 'ex: 192.168.1.100', icon: Icons.computer, isPinging: _isPingingLocal, pingMessage: _localPingMessage, pingSuccess: _localPingSuccess, onPing: () => _handlePing(true)),
                const SizedBox(height: 20),
                _buildIpInputRow(controller: _remoteIpController, labelText: 'Adresse IP Distante', hintText: 'ex: https://pharmacie.example.com', icon: Icons.public, isPinging: _isPingingRemote, pingMessage: _remotePingMessage, pingSuccess: _remotePingSuccess, onPing: () => _handlePing(false), isRemote: true),
                const SizedBox(height: 20),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _appNameController,
                        enabled: _isAppNameEditable,
                        decoration: const InputDecoration(labelText: 'Nom de l\'application serveur', prefixIcon: Icon(Icons.apps)),
                        inputFormatters: Saisie.nomApplicationFormatters,
                        validator: Saisie.erreurNomApplication,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: Icon(_isAppNameEditable ? Icons.lock_open_outlined : Icons.edit_outlined), tooltip: 'Modifier le nom', onPressed: () => setState(() => _isAppNameEditable = !_isAppNameEditable), padding: const EdgeInsets.only(top: 12)),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _portController,
                        enabled: _isPortEditable,
                        decoration: const InputDecoration(labelText: 'Port du Serveur', prefixIcon: Icon(Icons.settings_ethernet)),
                        keyboardType: TextInputType.number,
                        inputFormatters: Saisie.entierFormatters(5),
                        validator: Saisie.erreurPort,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: Icon(_isPortEditable ? Icons.lock_open_outlined : Icons.edit_outlined), tooltip: _isPortEditable ? 'Verrouiller le port' : 'Modifier le port', onPressed: () => setState(() => _isPortEditable = !_isPortEditable), padding: const EdgeInsets.only(top: 12)),
                  ],
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _timeoutController,
                  // MODIFICATION: Ajout du helperText
                  decoration: const InputDecoration(
                    labelText: 'Délai de déconnexion (minutes)',
                    prefixIcon: Icon(Icons.timer_outlined),
                    helperText: 'Saisir 0 pour désactiver le délai.',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: Saisie.entierFormatters(4),
                  validator: Saisie.erreurDelai,
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(icon: const Icon(Icons.save_alt_outlined), label: Text(canPop ? 'Enregistrer' : 'Enregistrer et Continuer'), onPressed: _saveSettings, style: theme.elevatedButtonTheme.style?.copyWith(padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 15)))),
                const SizedBox(height: 20),
                Text('Note: L\'adresse IP locale est requise pour utiliser l\'application.', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                // Code qui protège cette configuration quand elle est ouverte sans être connecté.
                TextButton.icon(
                  key: const Key('changer_code_admin'),
                  icon: const Icon(Icons.pin_outlined),
                  label: const Text('Changer le code administrateur'),
                  onPressed: () => PinCodeDialog.changePin(context),
                ),
                // Retour à la nouvelle interface (choix mémorisé sur le téléphone).
                const InterfaceVersionTile(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNouveau(BuildContext context) {
    final canPop = Navigator.canPop(context);
    Widget champVerrouille({
      required TextEditingController controller,
      required bool editable,
      required String label,
      required IconData icone,
      required String infobulle,
      required VoidCallback basculer,
      TextInputType? clavier,
      List<TextInputFormatter>? formats,
      String? Function(String?)? validator,
    }) =>
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: editable,
              decoration: InputDecoration(labelText: label, prefixIcon: Icon(icone)),
              keyboardType: clavier,
              inputFormatters: formats,
              validator: validator,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(icon: Icon(editable ? Icons.lock_open_outlined : Icons.edit_outlined), tooltip: infobulle, onPressed: basculer),
        ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration IP'), automaticallyImplyLeading: canPop),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text('Configurer les adresses IP du serveur', style: TextStyle(color: Charte.gris, fontSize: 15)),
                ),
                CarteSection(titre: 'Adresses du serveur', icone: Icons.dns_outlined, enfants: [
                  _buildIpInputRow(controller: _localIpController, labelText: 'Adresse IP Locale', hintText: 'ex: 192.168.1.100', icon: Icons.computer, isPinging: _isPingingLocal, pingMessage: _localPingMessage, pingSuccess: _localPingSuccess, onPing: () => _handlePing(true)),
                  const SizedBox(height: 16),
                  _buildIpInputRow(controller: _remoteIpController, labelText: 'Adresse IP Distante', hintText: 'ex: https://pharmacie.example.com', icon: Icons.public, isPinging: _isPingingRemote, pingMessage: _remotePingMessage, pingSuccess: _remotePingSuccess, onPing: () => _handlePing(false), isRemote: true),
                  const SizedBox(height: 8),
                  const Text('L\'adresse IP locale est requise pour utiliser l\'application.', style: TextStyle(color: Charte.gris, fontSize: 13)),
                ]),
                CarteSection(titre: 'Application Prestige', icone: Icons.apps, enfants: [
                  champVerrouille(
                    controller: _appNameController,
                    editable: _isAppNameEditable,
                    label: 'Nom de l\'application serveur',
                    icone: Icons.apps,
                    infobulle: 'Modifier le nom',
                    basculer: () => setState(() => _isAppNameEditable = !_isAppNameEditable),
                    formats: Saisie.nomApplicationFormatters,
                    validator: Saisie.erreurNomApplication,
                  ),
                  const SizedBox(height: 16),
                  champVerrouille(
                    controller: _portController,
                    editable: _isPortEditable,
                    label: 'Port du Serveur',
                    icone: Icons.settings_ethernet,
                    infobulle: _isPortEditable ? 'Verrouiller le port' : 'Modifier le port',
                    basculer: () => setState(() => _isPortEditable = !_isPortEditable),
                    clavier: TextInputType.number,
                    formats: Saisie.entierFormatters(5),
                    validator: Saisie.erreurPort,
                  ),
                ]),
                CarteSection(titre: 'Sécurité', icone: Icons.shield_outlined, enfants: [
                  TextFormField(
                    controller: _timeoutController,
                    decoration: const InputDecoration(
                      labelText: 'Délai de déconnexion (minutes)',
                      prefixIcon: Icon(Icons.timer_outlined),
                      helperText: 'Saisir 0 pour désactiver le délai.',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: Saisie.entierFormatters(4),
                    validator: Saisie.erreurDelai,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('changer_code_admin'),
                      icon: const Icon(Icons.pin_outlined),
                      label: const Text('Changer le code administrateur'),
                      onPressed: () => PinCodeDialog.changePin(context),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt_outlined),
                          label: Text(canPop ? 'Enregistrer' : 'Enregistrer et Continuer'),
                          onPressed: _saveSettings,
                        ),
                      ),
                const SizedBox(height: 16),
                const CarteSection(
                  titre: 'Apparence',
                  icone: Icons.palette_outlined,
                  padding: EdgeInsets.fromLTRB(0, 14, 0, 8),
                  enfants: [InterfaceVersionTile()],
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildIpInputRow({required TextEditingController controller, required String labelText, required String hintText, required IconData icon, required bool isPinging, required String? pingMessage, required bool? pingSuccess, required VoidCallback onPing, bool isRemote = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(labelText: labelText, hintText: hintText, prefixIcon: Icon(icon)),
                keyboardType: TextInputType.url,
                autocorrect: false,
                inputFormatters: [LengthLimitingTextInputFormatter(AdresseServeur.maxLongueur)],
                // IP ou nom ; « https://… » accepté (serveur avec certificat), HTTP par défaut.
                validator: (value) => AdresseServeur.erreur(value, requis: !isRemote),
              ),
            ),
            const SizedBox(width: 8),
            isPinging
                ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5)))
                : IconButton(icon: const Icon(Icons.network_ping), tooltip: 'Tester la connexion', onPressed: onPing, padding: const EdgeInsets.only(top: 8)),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: (pingMessage != null)
              ? Padding(
            key: ValueKey<String>(pingMessage),
            padding: const EdgeInsets.only(top: 6.0, left: 12.0),
            child: Text(
              pingMessage,
              style: TextStyle(
                color: (pingSuccess == null) ? Colors.grey.shade600 : (pingSuccess == true ? Colors.green.shade700 : Colors.red.shade700),
                fontWeight: FontWeight.bold,
              ),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}