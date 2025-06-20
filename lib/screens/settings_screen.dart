// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ip_config_provider.dart';
import '../utils/constants.dart'; // For AppConstants
import 'home_screen.dart'; // To navigate to HomeScreen after saving

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _localIpController;
  late TextEditingController _remoteIpController;
  // late TextEditingController _portController; // Optional: if port is also configurable

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
    // Initialize with current provider values, but show empty if they are the placeholder defaults
    _localIpController = TextEditingController(
        text: ipProvider.localIp == AppConstants.defaultLocalIp ? '' : ipProvider.localIp);
    _remoteIpController = TextEditingController(
        text: ipProvider.remoteIp == AppConstants.defaultRemoteIp ? '' : ipProvider.remoteIp);
    // _portController = TextEditingController(text: ipProvider.port);
  }

  @override
  void dispose() {
    _localIpController.dispose();
    _remoteIpController.dispose();
    // _portController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
      try {
        await ipProvider.updateSettings(
          _localIpController.text.trim(),
          _remoteIpController.text.trim(),
          // _portController.text.trim(), // if port is configurable
        );

        // Check if context is still mounted before showing SnackBar or navigating
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration enregistrée avec succès.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access theme for consistent styling
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration IP'),
        automaticallyImplyLeading: false, // No back button if it's the first screen
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
                Text(
                  'Configurer les adresses IP du serveur',
                  style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColorDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _localIpController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse IP Locale (ex: 192.168.1.100)',
                    hintText: 'Entrez l\'adresse IP locale',
                    prefixIcon: Icon(Icons.computer),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url, // Allows dots and numbers
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez entrer une adresse IP locale.';
                    }
                    // Basic IP format validation (not exhaustive)
                    // RegExp ipRegex = RegExp(r"^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$");
                    // if (!ipRegex.hasMatch(value.trim())) {
                    //   return 'Format d\'IP invalide.';
                    // }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _remoteIpController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse IP Distante ',
                    hintText: 'Entrez l\'adresse IP distante',
                    prefixIcon: Icon(Icons.public),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    // Remote IP can be optional if local is primary
                    // if (value == null || value.trim().isEmpty) {
                    //   return 'Veuillez entrer une adresse IP distante.';
                    // }
                    return null;
                  },
                ),
                // SizedBox(height: 20),
                // TextFormField(
                //   controller: _portController,
                //   decoration: InputDecoration(
                //     labelText: 'Port (ex: 8080)',
                //     hintText: 'Entrez le numéro de port',
                //     prefixIcon: Icon(Icons.settings_ethernet),
                //   ),
                //   keyboardType: TextInputType.number,
                //   validator: (value) {
                //     if (value == null || value.trim().isEmpty) {
                //       return 'Veuillez entrer un numéro de port.';
                //     }
                //     if (int.tryParse(value.trim()) == null) {
                //       return 'Port invalide.';
                //     }
                //     return null;
                //   },
                // ),
                const SizedBox(height: 30),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Enregistrer et Continuer'),
                  onPressed: _saveSettings,
                  style: theme.elevatedButtonTheme.style?.copyWith(
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Note: L\'adresse IP locale est requise. L\'adresse distante est optionnelle.',
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
