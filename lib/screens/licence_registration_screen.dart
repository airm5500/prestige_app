import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:prestige_app/widgets/pin_code_dialog.dart';
import 'package:prestige_app/utils/saisie.dart';
import 'package:prestige_app/interface_version.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';

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
    // Nouvelle interface : même saisie, même enregistrement, autre présentation.
    if (InterfaceVersion.nouvelle(context)) return _buildNouveau(context, licenceProvider, isExpired);

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
                  inputFormatters: Saisie.cleLicenceFormatters,
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
                      if (Saisie.cleLicence(_keyController.text).isEmpty) return;

                      setState(() => _isSubmitting = true);
                      final success = await licenceProvider.registerLicence(context, Saisie.cleLicence(_keyController.text));
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

  Future<void> _valider(LicenceProvider licenceProvider) async {
    if (Saisie.cleLicence(_keyController.text).isEmpty) return;
    setState(() => _isSubmitting = true);
    final success = await licenceProvider.registerLicence(context, Saisie.cleLicence(_keyController.text));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Licence activée avec succès !")));
      // La redirection sera gérée automatiquement par le AuthWrapper dans main.dart
    }
  }

  Widget _buildNouveau(BuildContext context, LicenceProvider licenceProvider, bool isExpired) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Activation Licence"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              if (!await PinCodeDialog.show(context) || !context.mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
            tooltip: "Configuration Serveur",
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CarteSection(
              padding: const EdgeInsets.all(20),
              enfants: [
                Center(
                  child: IconeMenu(isExpired ? Icons.timer_off_outlined : Icons.vpn_key_outlined,
                      taille: 64,
                      fond: isExpired ? Charte.rougeClair : Charte.bleuClair,
                      couleur: isExpired ? Charte.rougeTexte : Charte.navy),
                ),
                const SizedBox(height: 16),
                Text(
                  isExpired ? "Votre licence a expiré${_dateFin(licenceProvider)}." : "Licence requise",
                  key: const Key('licence_titre'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Charte.encre),
                ),
                const SizedBox(height: 10),
                Text(
                  isExpired
                      ? "Le serveur Prestige a bien répondu : la licence de l'officine n'est plus valide. "
                          "Contactez Prestige pour la renouveler, puis saisissez la nouvelle clé pour continuer à utiliser l'application."
                      : "Le serveur Prestige a bien répondu : aucune licence n'est enregistrée. "
                          "Contactez Prestige pour en obtenir une, puis saisissez votre clé de licence pour activer l'application.",
                  key: const Key('licence_explication'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Charte.gris, height: 1.35),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _keyController,
                  inputFormatters: Saisie.cleLicenceFormatters,
                  decoration: const InputDecoration(labelText: "Clé de licence", prefixIcon: Icon(Icons.key)),
                ),
                const SizedBox(height: 16),
                if (licenceProvider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Encadre(texte: licenceProvider.errorMessage!, icone: Icons.error_outline),
                  ),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    key: const Key('licence_valider'),
                    onPressed: _isSubmitting ? null : () => _valider(licenceProvider),
                    child: _isSubmitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Charte.surAmbre))
                        : const Text("Valider la licence"),
                  ),
                ),
                const SizedBox(height: 8),
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