// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/ip_config_provider.dart';
import '../services/stockage_securise.dart';
import '../utils/constants.dart';
import 'settings_screen.dart';
import '../widgets/pin_code_dialog.dart';
import '../utils/saisie.dart';
import '../interface_version.dart';
import '../providers/licence_provider.dart';
import '../nouvelle_interface/charte.dart';
import '../nouvelle_interface/composants.dart';
import '../nouvelle_interface/presentation.dart';
import '../version_app.dart';

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
      // Mot de passe mémorisé : stockage sécurisé (migration de l'ancienne clé en clair comprise).
      _passwordController.text = await IdentifiantsSecurises.instance.lire() ?? '';
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
        // Envoyé tel que saisi : le serveur ne rogne pas les espaces (un mot de passe peut en contenir).
        _passwordController.text,
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
    // Nouvelle interface : même logique (contrôles, connexion, mémorisation), autre présentation.
    if (InterfaceVersion.nouvelle(context)) return _buildNouveau(context);
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
                    // Semantics : libellé pour le lecteur d'écran (le texte « Local / Distant » n'est pas relié à l'interrupteur).
                    Semantics(label: 'Serveur local', child: Switch(
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
                    )),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                      tooltip: 'Configuration IP',
                      // Sans être connecté, la configuration du serveur est protégée par le code administrateur.
                      onPressed: () async {
                        if (!await PinCodeDialog.show(context) || !context.mounted) return;
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
                              inputFormatters: Saisie.identifiantFormatters,
                              validator: Saisie.erreurIdentifiant,
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
                                  tooltip: _isPasswordVisible ? 'Masquer le mot de passe' : 'Afficher le mot de passe',
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                              ),
                              inputFormatters: Saisie.motDePasseFormatters,
                              validator: Saisie.erreurMotDePasse,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Flexible : sur un téléphone de 360 dp (ou en grande police), le libellé passe à la ligne
                                // au lieu de pousser le bouton « Connexion » hors de la carte.
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(value: _rememberMe, onChanged: (value) => setState(() => _rememberMe = value!), activeColor: theme.primaryColor, semanticLabel: 'Rester connecté'),
                                      Flexible(child: GestureDetector(onTap: () => setState(() => _rememberMe = !_rememberMe), child: const Text("Rester connecté"))),
                                    ],
                                  ),
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
                            // Version installée, discrète (lue à l'exécution : pubspec.yaml est la seule source).
                            const SizedBox(height: 16),
                            VersionAffichee(couleur: Colors.grey.shade700),
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

  // ------------------------------------------------------------------------------------------------------------
  // Nouvelle interface (maquettes §1) : en-tête bleu avec l'état du serveur (A, C) ou barre blanche (B),
  // formulaire seul, bouton ambre. Mêmes champs, mêmes contrôles de saisie, même appel au serveur.
  // ------------------------------------------------------------------------------------------------------------

  Future<void> _ouvrirConfiguration() async {
    // Sans être connecté, la configuration du serveur est protégée par le code administrateur.
    if (!await PinCodeDialog.show(context) || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
  }

  Future<void> _basculerServeur(IpConfigProvider ipProvider, bool value) async {
    if (!value && (ipProvider.remoteIp.isEmpty || ipProvider.remoteIp == AppConstants.defaultRemoteIp)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('L\'adresse IP distante n\'est pas configurée.')));
      return;
    }
    ipProvider.setUseLocalIp(value);
    await _fetchAndDisplayOfficineName();
  }

  Widget _buildNouveau(BuildContext context) {
    final ipProvider = context.watch<IpConfigProvider>();
    final licence = context.watch<LicenceProvider>().licence?.expiryDate;
    final compact = PresentationPrefs.effective(PresentationPrefs.choix.value, tablette: estTabletteNouvelle(context)) == Presentation.compact;
    final adresse = '${ipProvider.useLocalIp ? ipProvider.localIp : ipProvider.remoteIp}:${ipProvider.port} · ${ipProvider.appName}';
    final mode = ipProvider.useLocalIp ? 'Serveur local' : 'Serveur distant';

    final interrupteur = Semantics(
      label: 'Serveur local',
      child: Switch(
        value: ipProvider.useLocalIp,
        activeTrackColor: compact ? Charte.navy : Charte.ambre,
        activeColor: compact ? Charte.blanc : Charte.surAmbre,
        onChanged: (v) => _basculerServeur(ipProvider, v),
      ),
    );

    final Widget entete = compact
        ? BarreBlanche(
            titre: 'Prestige Pharmacien',
            sousTitre: Row(children: [
              const Point(Charte.vert),
              const SizedBox(width: 6),
              Flexible(child: Text('$mode${_officineName == null ? '' : ' · $_officineName'}', maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
            actions: [
              interrupteur,
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Charte.navy),
                tooltip: 'Configuration IP',
                onPressed: _ouvrirConfiguration,
              ),
            ],
          )
        : EnTeteNavy(
            titre: 'Prestige Pharmacien',
            sousTitre: _officineName,
            retour: false,
            enfants: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(color: Charte.enteteVoile, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Point(Charte.vertVif),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(mode, style: const TextStyle(color: Charte.blanc, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(adresse, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Charte.enteteGris, fontSize: 12)),
                    ]),
                  ),
                  interrupteur,
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Charte.blanc),
                    tooltip: 'Configuration IP',
                    onPressed: _ouvrirConfiguration,
                  ),
                ]),
              ),
            ],
          );

    final formulaire = Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!compact) ...[
          const Text('Connexion', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Charte.encre)),
          const Text('Saisissez vos identifiants Prestige.', style: TextStyle(color: Charte.gris)),
          const SizedBox(height: 18),
        ],
        if (_uiErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Encadre(texte: _uiErrorMessage!, icone: Icons.error_outline),
          ),
        TextFormField(
          controller: _usernameController,
          decoration: const InputDecoration(labelText: 'Identifiant', prefixIcon: Icon(Icons.person_outline)),
          inputFormatters: Saisie.identifiantFormatters,
          validator: Saisie.erreurIdentifiant,
          textInputAction: TextInputAction.next,
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
              tooltip: _isPasswordVisible ? 'Masquer le mot de passe' : 'Afficher le mot de passe',
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
          inputFormatters: Saisie.motDePasseFormatters,
          validator: Saisie.erreurMotDePasse,
          onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _rememberMe,
          onChanged: (value) => setState(() => _rememberMe = value!),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('Rester connecté'),
          subtitle: const Text('Identifiants gardés dans le stockage sécurisé du téléphone', style: TextStyle(color: Charte.gris, fontSize: 12.5)),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
        else
          SizedBox(
            height: 52,
            child: ElevatedButton(
              key: const Key('connexion_se_connecter'),
              onPressed: _handleLogin,
              child: const Text('Se connecter'),
            ),
          ),
        if (licence != null) ...[
          const SizedBox(height: 20),
          Text(
            'Licence valable jusqu\'au ${licence.day.toString().padLeft(2, '0')}/${licence.month.toString().padLeft(2, '0')}/${licence.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Charte.gris, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
        // Version installée, discrète (lue à l'exécution : pubspec.yaml est la seule source).
        const SizedBox(height: 20),
        const VersionAffichee(couleur: Charte.gris),
      ]),
    );

    return Scaffold(
      backgroundColor: Charte.blanc,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        entete,
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: formulaire)),
          ),
        ),
      ]),
    );
  }
}