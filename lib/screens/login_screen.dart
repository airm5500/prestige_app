// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/ip_config_provider.dart';
import '../utils/constants.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(AppConstants.rememberMeKey) ?? false;
    if (rememberMe) {
      _usernameController.text = prefs.getString(AppConstants.savedUsernameKey) ?? '';
      _passwordController.text = prefs.getString(AppConstants.savedPasswordKey) ?? '';
    }
    if (mounted) {
      setState(() {
        _rememberMe = rememberMe;
      });
    }
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      final String? errorMessage = await authProvider.login(
        context,
        _usernameController.text.trim(),
        _passwordController.text.trim(),
        _rememberMe,
      );

      if (!mounted) return;

      if (errorMessage != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ipProvider = Provider.of<IpConfigProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primaryColor, theme.colorScheme.secondary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Prestige Connexion",
                          style: GoogleFonts.lato(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Identifiant',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) => value!.isEmpty ? 'Veuillez entrer un identifiant.' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                          ),
                          validator: (value) => value!.isEmpty ? 'Veuillez entrer un mot de passe.' : null,
                        ),
                        const SizedBox(height: 8),

                        // CORRECTION: Remplacement de CheckboxListTile par une Row centrée
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) => setState(() => _rememberMe = value!),
                              activeColor: theme.primaryColor,
                            ),
                            // GestureDetector pour rendre le texte cliquable
                            GestureDetector(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                child: const Text("Rester connecté")
                            ),
                          ],
                        ),

                        const Divider(),
                        SwitchListTile(
                          title: const Text("Mode de Connexion"),
                          subtitle: Text(ipProvider.useLocalIp ? 'Local' : 'Distant'),
                          value: ipProvider.useLocalIp,
                          onChanged: (value) {
                            if (!value && (ipProvider.remoteIp.isEmpty || ipProvider.remoteIp == AppConstants.defaultRemoteIp)) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('L\'adresse IP distante n\'est pas configurée.'),
                                backgroundColor: Colors.orange,
                              ));
                              return;
                            }
                            ipProvider.setUseLocalIp(value);
                          },
                          secondary: Icon(ipProvider.useLocalIp ? Icons.dns : Icons.public),
                          activeColor: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                          onPressed: _handleLogin,
                          child: const Text('Connexion'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 28),
              tooltip: 'Configuration IP',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }
}
