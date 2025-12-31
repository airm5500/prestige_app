import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/screens/settings_screen.dart';

class LicenceRegistrationScreen extends StatefulWidget {
  const LicenceRegistrationScreen({Key? key}) : super(key: key);

  @override
  _LicenceRegistrationScreenState createState() => _LicenceRegistrationScreenState();
}

class _LicenceRegistrationScreenState extends State<LicenceRegistrationScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final licenceProvider = Provider.of<LicenceProvider>(context);
    final isExpired = licenceProvider.status == LicenceStatus.expired;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Activation Licence"),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          // Bouton Configuration si besoin
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: "Configuration Serveur",
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isExpired ? Icons.timer_off_outlined : Icons.vpn_key_outlined,
                  size: 80,
                  color: isExpired ? Colors.red : Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 20),
                Text(
                  isExpired ? "Votre licence a expiré." : "Licence requise",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  isExpired
                      ? "Veuillez saisir une nouvelle clé pour continuer à utiliser l'application."
                      : "Bienvenue. Veuillez saisir votre clé de licence pour activer l'application.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _keyController,
                  decoration: const InputDecoration(
                    labelText: "Clé de licence",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                  ),
                ),
                const SizedBox(height: 20),
                if (licenceProvider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      licenceProvider.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () async {
                      if (_keyController.text.isEmpty) return;

                      setState(() => _isSubmitting = true);
                      final success = await licenceProvider.registerLicence(context, _keyController.text.trim());
                      setState(() => _isSubmitting = false);

                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Licence activée avec succès !")),
                        );
                        // La redirection sera gérée automatiquement par le AuthWrapper dans main.dart
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("VALIDER LA LICENCE"),
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