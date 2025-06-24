// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ip_config_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

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
  bool _isLoading = false;

  bool _isPingingLocal = false;
  bool _isPingingRemote = false;
  bool _isPortEditable = false;

  String? _localPingMessage;
  bool? _localPingSuccess;
  String? _remotePingMessage;
  bool? _remotePingSuccess;

  @override
  void initState() {
    super.initState();
    final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
    _localIpController = TextEditingController(text: ipProvider.localIp == AppConstants.defaultLocalIp ? '' : ipProvider.localIp);
    _remoteIpController = TextEditingController(text: ipProvider.remoteIp == AppConstants.defaultRemoteIp ? '' : ipProvider.remoteIp);
    _portController = TextEditingController(text: ipProvider.port);
    _timeoutController = TextEditingController(text: ipProvider.sessionTimeout.toString());
  }

  @override
  void dispose() {
    _localIpController.dispose();
    _remoteIpController.dispose();
    _portController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _handlePing(bool isLocal) async {
    FocusScope.of(context).unfocus();
    final ipToTest = isLocal ? _localIpController.text.trim() : _remoteIpController.text.trim();

    if (ipToTest.isEmpty) {
      if (mounted) {
        setState(() {
          if (isLocal) { _localPingMessage = 'Champ vide.'; _localPingSuccess = false; }
          else { _remotePingMessage = 'Champ vide.'; _remotePingSuccess = false; }
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        if (isLocal) { _isPingingLocal = true; _localPingMessage = 'Test en cours...'; _localPingSuccess = null; }
        else { _isPingingRemote = true; _remotePingMessage = 'Test en cours...'; _remotePingSuccess = null; }
      });
    }

    final success = await ApiService.ping(ipToTest, _portController.text.trim());

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

      // Logique de ping automatique
      List<Future> pingTasks = [];
      if (_localIpController.text.trim().isNotEmpty) {
        pingTasks.add(_handlePing(true));
      }
      if (_remoteIpController.text.trim().isNotEmpty) {
        pingTasks.add(_handlePing(false));
      }
      await Future.wait(pingTasks);

      try {
        await ipProvider.updateSettings(
          _localIpController.text.trim(),
          _remoteIpController.text.trim(),
          _portController.text.trim(),
          int.tryParse(_timeoutController.text.trim()) ?? AppConstants.defaultSessionTimeout,
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

  // CORRECTION: Ce widget était manquant dans la version précédente.
  Widget _buildIpInputRow({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required bool isPinging,
    required String? pingMessage,
    required bool? pingSuccess,
    required VoidCallback onPing,
    bool isRemote = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: labelText,
                  hintText: hintText,
                  prefixIcon: Icon(icon),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (!isRemote && (value == null || value.trim().isEmpty)) {
                    return 'Ce champ est requis.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            isPinging
                ? const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
                : IconButton(
              icon: const Icon(Icons.network_ping),
              tooltip: 'Tester la connexion',
              onPressed: onPing,
              padding: const EdgeInsets.only(top: 8),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: (pingMessage != null)
              ? Padding(
            key: ValueKey<String>(pingMessage),
            padding: const EdgeInsets.only(top: 6.0, left: 12.0),
            child: Text(
              pingMessage,
              style: TextStyle(
                color: (pingSuccess == null)
                    ? Colors.grey.shade600
                    : (pingSuccess == true ? Colors.green.shade700 : Colors.red.shade700),
                fontWeight: FontWeight.bold,
              ),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.canPop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration IP'),
        automaticallyImplyLeading: canPop,
      ),
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

                _buildIpInputRow(
                  controller: _localIpController,
                  labelText: 'Adresse IP Locale',
                  hintText: 'ex: 192.168.1.100',
                  icon: Icons.computer,
                  isPinging: _isPingingLocal,
                  pingMessage: _localPingMessage,
                  pingSuccess: _localPingSuccess,
                  onPing: () => _handlePing(true),
                ),

                const SizedBox(height: 20),

                _buildIpInputRow(
                  controller: _remoteIpController,
                  labelText: 'Adresse IP Distante',
                  hintText: 'ex: example.com',
                  icon: Icons.public,
                  isPinging: _isPingingRemote,
                  pingMessage: _remotePingMessage,
                  pingSuccess: _remotePingSuccess,
                  onPing: () => _handlePing(false),
                  isRemote: true,
                ),

                const SizedBox(height: 20),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _portController,
                        enabled: _isPortEditable,
                        decoration: const InputDecoration(
                          labelText: 'Port du Serveur',
                          prefixIcon: Icon(Icons.settings_ethernet),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Le port est requis.';
                          if (int.tryParse(value.trim()) == null) return 'Port invalide.';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_isPortEditable ? Icons.lock_open_outlined : Icons.edit_outlined),
                      tooltip: _isPortEditable ? 'Verrouiller le port' : 'Modifier le port',
                      onPressed: () {
                        setState(() {
                          _isPortEditable = !_isPortEditable;
                        });
                      },
                      padding: const EdgeInsets.only(top: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _timeoutController,
                  decoration: const InputDecoration(
                    labelText: 'Délai de déconnexion (minutes)',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Le délai est requis.';
                    if (int.tryParse(value.trim()) == null) return 'Valeur invalide.';
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt_outlined),
                  label: Text(canPop ? 'Enregistrer' : 'Enregistrer et Continuer'),
                  onPressed: _saveSettings,
                  style: theme.elevatedButtonTheme.style?.copyWith(padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 15))),
                ),
                const SizedBox(height: 20),
                Text('Note: L\'adresse IP locale est requise pour utiliser l\'application.', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
