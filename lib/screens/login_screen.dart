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
  String? _uiErrorMessage;
  String? _officineName;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndDisplayOfficineName(); // MODIFICATION
    });
    _usernameController.addListener(_clearError);
    _passwordController.addListener(_clearError);
  }

  // AJOUT: Nouvelle fonction pour récupérer le nom de la pharmacie
  Future<void> _fetchAndDisplayOfficineName() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // D'abord, on essaie de charger depuis le cache
    final cachedName = await authProvider.getLastKnownOfficineName();
    if (mounted && cachedName != null) {
      setState(() {
        _officineName = cachedName;
      });
    }
    // Ensuite, on lance une requête pour avoir la version la plus récente
    await authProvider.fetchAndStoreOfficineInfo(context);
    // On recharge depuis le cache au cas où ça aurait été mis à jour
    final freshName = await authProvider.getLastKnownOfficineName();
    if (mounted && freshName != null) {
      setState(() {
        _officineName = freshName;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_uiErrorMessage != null) {
      setState(() {
        _uiErrorMessage = null;
      });
    }
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
      setState(() {
        _isLoading = true;
        _uiErrorMessage = null;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final String? errorMessage = await authProvider.login(
        context,
        _usernameController.text.trim(),
        _passwordController.text.trim(),
        _rememberMe,
      );

      if (!mounted) return;

      if (errorMessage != null) {
        setState(() {
          _uiErrorMessage = errorMessage;
        });
      } else {
        _fetchAndDisplayOfficineName();
      }

      setState(() => _isLoading = false);
    }
  }

  Widget _buildErrorMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _uiErrorMessage != null
          ? Container(
        key: const ValueKey('error'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.redAccent.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent.withAlpha(100))
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  _uiErrorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ),
      )
          : const SizedBox.shrink(key: ValueKey('no-error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // MODIFICATION: On écoute les changements de l'ipProvider
    final ipProvider = context.watch<IpConfigProvider>();

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

          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.only(top: 8, right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ipProvider.useLocalIp ? 'Local' : 'Distant', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    Switch(
                      value: ipProvider.useLocalIp,
                      onChanged: (value) async { // MODIFICATION: async
                        if (!value && (ipProvider.remoteIp.isEmpty || ipProvider.remoteIp == AppConstants.defaultRemoteIp)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('L\'adresse IP distante n\'est pas configurée.'), backgroundColor: Colors.orange));
                          return;
                        }
                        ipProvider.setUseLocalIp(value);
                        // On rafraîchit le nom de la pharmacie après le changement
                        await _fetchAndDisplayOfficineName();
                      },
                      activeTrackColor: theme.colorScheme.primary.withAlpha(100),
                      activeColor: Colors.white,
                      inactiveTrackColor: Colors.white.withAlpha(100),
                      inactiveThumbColor: Colors.grey.shade300,
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                      tooltip: 'Configuration IP',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text("Prestige Connexion", textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold, color: theme.primaryColor)),
                            // MODIFICATION: Affichage dynamique du nom de l'officine
                            if (_officineName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _officineName!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.lato(fontSize: 18, color: theme.colorScheme.secondary),
                                ),
                              ),
                            const SizedBox(height: 24),
                            _buildErrorMessage(),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(labelText: 'Identifiant', prefixIcon: Icon(Icons.person_outline)),
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
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(value: _rememberMe, onChanged: (value) => setState(() => _rememberMe = value!), activeColor: theme.primaryColor),
                                    GestureDetector(onTap: () => setState(() => _rememberMe = !_rememberMe), child: const Text("Rester connecté")),
                                  ],
                                ),
                                if (_isLoading)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                                    child: CircularProgressIndicator(),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: _handleLogin,
                                    child: const Text('Connexion'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}