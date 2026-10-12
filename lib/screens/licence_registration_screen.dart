import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:prestige_app/widgets/pin_code_dialog.dart';

class LicenceRegistrationScreen extends StatefulWidget {
  const LicenceRegistrationScreen({Key? key}) : super(key: key);

  @override
  _LicenceRegistrationScreenState createState() => _LicenceRegistrationScreenState();
}

class _LicenceRegistrationScreenState extends State<LicenceRegistrationScreen> {
  static String _dateFin(LicenceProvider p) {
    final fin = p.licence?.expiryDate;
    if (fin == null) return '';
    return ' le ${fin.day.toString().padLeft(2, '0')}/${fin.month.toString().padLeft(2, '0')}/${fin.year}';
  }

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
            // Sans être connecté, la configuration du serveur est protégée par le code administrateur.
            onPressed: () async {
              if (!await PinCodeDialog.show(context) || !context.mounted) return;
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
                  isExpired ? "Votre licence a expiré${_dateFin(licenceProvider)}." : "Licence requise",
                  key: const Key('licence_titre'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                // Le serveur a bien répondu : c'est la licence qui manque (une panne réseau a son propre écran).
                Text(
                  isExpired
                      ? "Le serveur Prestige a bien répondu : la licence de l'officine n'est plus valide. "
                          "Contactez Prestige pour la renouveler, puis saisissez la nouvelle clé pour continuer à utiliser l'application."
                      : "Le serveur Prestige a bien répondu : aucune licence n'est enregistrée. "
                          "Contactez Prestige pour en obtenir une, puis saisissez votre clé de licence pour activer l'application.",
                  key: const Key('licence_explication'),
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
                      if (!context.mounted) return;
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
                const SizedBox(height: 12),
                // Licence renouvelée depuis le poste Prestige : nouvelle vérification sans saisir de clé.
                TextButton.icon(
                  key: const Key('verifier_licence'),
                  onPressed: _isSubmitting ? null : () => licenceProvider.checkLicence(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Vérifier à nouveau'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}