// lib/widgets/pin_code_dialog.dart
// Code administrateur des zones protégées (copie de prestige_vente_app). Le code n'est jamais gardé en clair : empreinte salée dans le
// stockage sécurisé, migration de l'ancienne clé, attente progressive après 5 erreurs, changement
// obligatoire du code par défaut — voir CodeAdmin (lib/services/pin_securise.dart).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pin_securise.dart';

class PinCodeDialog {
  // Méthode 1 : VÉRIFIER le code (pour accéder à un menu)
  static Future<bool> show(BuildContext context) async {
    final code = CodeAdmin.instance;
    final attente = await code.attenteRestante();
    if (attente != null) {
      if (context.mounted) _message(context, _texteAttente(attente), Colors.red);
      return false;
    }
    if (!context.mounted) return false;
    final resultat = await showDialog<VerificationPin>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VerificationDialog(code: code, parent: context),
    );
    if (!context.mounted) return false;
    switch (resultat) {
      case VerificationPin.accepte:
        return true;
      case VerificationPin.changementObligatoire:
        // Le code par défaut n'ouvre que le changement du code ; l'accès suit si le nouveau code est enregistré.
        return await _nouveauCode(context, obligatoire: true);
      case VerificationPin.bloque:
        final reste = await code.attenteRestante();
        if (context.mounted) _message(context, _texteAttente(reste ?? CodeAdmin.attentes.first), Colors.red);
        return false;
      case VerificationPin.indisponible:
        _message(context, 'Stockage sécurisé indisponible : réessayez.', Colors.red);
        return false;
      case VerificationPin.refuse:
      case null:
        return false;
    }
  }

  // Méthode 2 : CHANGER le code (pour l'admin)
  static Future<void> changePin(BuildContext context) async {
    await _nouveauCode(context, obligatoire: false);
  }

  static Future<bool> _nouveauCode(BuildContext context, {required bool obligatoire}) async {
    final ok = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => NouveauPinDialog(code: CodeAdmin.instance, obligatoire: obligatoire),
        ) ??
        false;
    if (ok && context.mounted) _message(context, 'Code PIN modifié avec succès', Colors.green);
    return ok;
  }

  static String _texteAttente(Duration d) =>
      'Trop d\'erreurs : réessayez dans ${CodeAdmin.formaterAttente(Duration(seconds: d.inSeconds + (d.inMilliseconds % 1000 > 0 ? 1 : 0)))}.';

  static void _message(BuildContext context, String texte, Color couleur) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte), backgroundColor: couleur));
  }
}

const _stylePin = TextStyle(fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold);

class _VerificationDialog extends StatefulWidget {
  final CodeAdmin code;
  final BuildContext parent;
  const _VerificationDialog({required this.code, required this.parent});

  @override
  State<_VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<_VerificationDialog> {
  final _controller = TextEditingController();
  bool _occupe = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (_occupe) return;
    setState(() => _occupe = true);
    final r = await widget.code.verifier(_controller.text);
    if (!mounted) return;
    setState(() => _occupe = false);
    if (r == VerificationPin.refuse) {
      if (widget.parent.mounted) PinCodeDialog._message(widget.parent, 'Code incorrect', Colors.red);
      _controller.clear();
      return;
    }
    Navigator.pop(context, r);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Accès Sécurisé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Code Administrateur requis :'),
            const SizedBox(height: 15),
            TextField(
              key: const Key('pin_admin_saisie'),
              controller: _controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: ReglesPin.longueurMax,
              textAlign: TextAlign.center,
              style: _stylePin,
              decoration: const InputDecoration(hintText: '****', counterText: '', border: OutlineInputBorder()),
              onSubmitted: (_) => _valider(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: _occupe ? null : () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(onPressed: _occupe ? null : _valider, child: const Text('Valider')),
        ],
      );
}

/// Saisie double d'un nouveau code administrateur (règles : [ReglesPin]).
/// [obligatoire] : code par défaut encore en place — explication affichée, « Annuler » refuse l'accès.
class NouveauPinDialog extends StatefulWidget {
  final CodeAdmin code;
  final bool obligatoire;
  const NouveauPinDialog({super.key, required this.code, this.obligatoire = false});

  @override
  State<NouveauPinDialog> createState() => _NouveauPinDialogState();
}

class _NouveauPinDialogState extends State<NouveauPinDialog> {
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  String? _erreur;
  bool _occupe = false;

  @override
  void dispose() {
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (_occupe) return;
    final a = _nouveau.text.trim(), b = _confirmation.text.trim();
    final motif = ReglesPin.refus(a) ?? (a != b ? 'Les deux saisies sont différentes.' : null);
    if (motif != null) {
      setState(() => _erreur = motif);
      return;
    }
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    final refus = await widget.code.definir(a);
    if (!mounted) return;
    if (refus != null) {
      setState(() {
        _occupe = false;
        _erreur = refus;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  InputDecoration _deco(String label) => InputDecoration(labelText: label, counterText: '', border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.obligatoire ? 'Changement du code obligatoire' : 'Nouveau Code PIN'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.obligatoire
                  ? 'Le code par défaut 1234 est encore en place. Définissez un nouveau code administrateur '
                      '(${ReglesPin.longueurMin} à ${ReglesPin.longueurMax} chiffres) pour continuer.'
                  : 'Définir le nouveau code (${ReglesPin.longueurMin} à ${ReglesPin.longueurMax} chiffres) :'),
              const SizedBox(height: 15),
              TextField(
                key: const Key('pin_admin_nouveau'),
                controller: _nouveau,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: ReglesPin.longueurMax,
                textAlign: TextAlign.center,
                style: _stylePin,
                decoration: _deco('Nouveau code'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('pin_admin_confirmation'),
                controller: _confirmation,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: ReglesPin.longueurMax,
                textAlign: TextAlign.center,
                style: _stylePin,
                decoration: _deco('Confirmer le code'),
                onSubmitted: (_) => _enregistrer(),
              ),
              if (_erreur != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_erreur!, key: const Key('pin_admin_erreur'), style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _occupe ? null : () => Navigator.pop(context, false), child: Text(widget.obligatoire ? 'Annuler (accès refusé)' : 'Annuler')),
          ElevatedButton(onPressed: _occupe ? null : _enregistrer, child: const Text('Enregistrer')),
        ],
      );
}
