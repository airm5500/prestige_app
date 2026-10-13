// lib/presences/pointage_view.dart
// « Pointage & téléphones » : QR code de pointage du moment (GET /rh/mobile/code, change chaque minute) avec
// compte à rebours et rafraîchissement automatique, affichable en plein écran sur une tablette posée à l'officine ;
// liste des téléphones enregistrés (GET /rh/mobile/terminaux) avec Retirer / Réactiver, après confirmation.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/erreurs_chargement.dart';
import 'presences_api.dart';
import 'presences_modeles.dart';
import 'presences_widgets.dart';

/// QR du moment, rafraîchi tout seul : à la fin du compte à rebours (resteSec du serveur), un nouveau code est
/// demandé ; en cas d'échec, nouvel essai toutes les [attenteApresEchec] (le dernier code reste affiché, barré).
class QrPointage extends StatefulWidget {
  final bool pleinEcran;
  const QrPointage({super.key, this.pleinEcran = false});

  static const attenteApresEchec = Duration(seconds: 10);

  @override
  State<QrPointage> createState() => _QrPointageState();
}

class _QrPointageState extends State<QrPointage> {
  CodePointageMoment? _code;
  Object? _erreur;
  int _reste = 0;
  Timer? _minuteur;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    if (_enCours) return;
    _enCours = true;
    _minuteur?.cancel();
    try {
      final c = await const PresencesApi().codePointage(context);
      if (!mounted) return;
      setState(() {
        _code = c;
        _erreur = null;
        _reste = c.resteSec;
      });
      _minuteur = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e);
      _minuteur = Timer(QrPointage.attenteApresEchec, _charger);
    } finally {
      _enCours = false;
    }
  }

  void _tic() {
    if (!mounted) return;
    if (_reste <= 1) {
      _minuteur?.cancel();
      setState(() => _reste = 0);
      _charger();
      return;
    }
    setState(() => _reste--);
  }

  @override
  Widget build(BuildContext context) {
    final c = _code;
    final plein = widget.pleinEcran;
    final taille = plein ? (MediaQuery.sizeOf(context).shortestSide * 0.6).clamp(160.0, 520.0) : 200.0;
    if (c == null) {
      if (_erreur != null) {
        return BlocErreur(message: messageErreur(_erreur!), onRetry: _charger);
      }
      return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
    }
    final perime = _erreur != null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (!plein) const Text('QR code du moment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: couleurEncre)),
      if (!c.actif)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Pointage mobile désactivé dans Prestige', style: TextStyle(color: couleurAbsent, fontWeight: FontWeight.bold)),
        ),
      const SizedBox(height: 10),
      Opacity(
        opacity: perime ? 0.25 : 1,
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
          child: QrCodeDessin(c.contenu, key: ValueKey('qr_${c.code}'), taille: taille),
        ),
      ),
      const SizedBox(height: 8),
      Text(c.codeAffiche,
          key: const Key('qr_code_texte'),
          style: TextStyle(fontSize: plein ? 40 : 28, fontWeight: FontWeight.bold, letterSpacing: 4, color: couleurEncre)),
      const SizedBox(height: 8),
      SizedBox(
        width: plein ? taille : 220,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: c.periodeSec <= 0 ? 0 : _reste / c.periodeSec,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            color: const Color(0xFFF59E0B),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        perime ? 'Code périmé : ${messageErreur(_erreur!)}' : (_reste > 0 ? 'Change dans $_reste s' : 'Nouveau code…'),
        key: const Key('qr_reste'),
        textAlign: TextAlign.center,
        style: TextStyle(color: perime ? couleurAbsent : couleurGris, fontSize: plein ? 18 : 13),
      ),
      if (plein)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('Scannez avec Prestige Vente, menu « Pointage présence »', style: TextStyle(fontSize: 16, color: couleurGris)),
        )
      else ...[
        const SizedBox(height: 10),
        _reglage('QR exigé', c.qrExige ? 'Oui' : 'Non'),
        _reglage('Position exigée', c.gpsExige ? 'Oui' : 'Non'),
        if (c.gpsExige) _reglage('Rayon', '${c.rayon} m'),
      ],
    ]);
  }

  Widget _reglage(String t, String v) => SizedBox(
        width: 240,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(t, style: const TextStyle(color: couleurGris))),
            Text(v, style: const TextStyle(fontWeight: FontWeight.bold, color: couleurEncre)),
          ]),
        ),
      );
}

/// QR en plein écran (tablette posée au comptoir) : fond blanc, barres système masquées.
class QrPleinEcranScreen extends StatefulWidget {
  const QrPleinEcranScreen({super.key});

  @override
  State<QrPleinEcranScreen> createState() => _QrPleinEcranScreenState();
}

class _QrPleinEcranScreenState extends State<QrPleinEcranScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(children: [
            const Center(child: SingleChildScrollView(child: QrPointage(pleinEcran: true))),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                key: const Key('qr_quitter_plein_ecran'),
                tooltip: 'Quitter le plein écran',
                icon: const Icon(Icons.close, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ]),
        ),
      );
}

class PointageView extends StatefulWidget {
  const PointageView({super.key});

  @override
  State<PointageView> createState() => PointageViewState();
}

class PointageViewState extends State<PointageView> {
  List<TerminalMobile>? _terminaux;
  Object? _erreur;
  bool _chargement = false;
  final Set<String> _enCours = {};
  Key _cleQr = UniqueKey();

  @override
  void initState() {
    super.initState();
    _chargerTerminaux();
  }

  /// Bouton Actualiser : nouveau code et liste des téléphones.
  Future<void> actualiser() async {
    setState(() => _cleQr = UniqueKey());
    await _chargerTerminaux();
  }

  Future<void> _chargerTerminaux() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final t = await const PresencesApi().terminaux(context);
      if (!mounted) return;
      setState(() {
        _terminaux = t;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e;
        _chargement = false;
      });
    }
  }

  Future<void> _changer(TerminalMobile t, {required bool reactiver}) async {
    if (_enCours.contains(t.id)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(reactiver ? 'Réactiver ce téléphone ?' : 'Retirer ce téléphone ?'),
        content: Text(reactiver
            ? '${t.appareil} de ${t.titre} pourra de nouveau pointer.'
            : '${t.appareil} de ${t.titre} sera déconnecté immédiatement : l\'employé devra se reconnecter pour pointer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            key: const Key('terminal_confirmer'),
            style: reactiver ? null : FilledButton.styleFrom(backgroundColor: couleurAbsent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(reactiver ? 'Réactiver' : 'Retirer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _enCours.add(t.id));
    try {
      final message = await const PresencesApi().changerTerminal(context, t.id, reactiver: reactiver);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: couleurPresent));
      await _chargerTerminaux();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e)), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _enCours.remove(t.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tablette = estTablette(context);
    final qr = CartePresence(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        QrPointage(key: _cleQr),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('qr_plein_ecran'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrPleinEcranScreen())),
          icon: const Icon(Icons.fullscreen),
          label: const Text('Plein écran'),
        ),
        const SizedBox(height: 6),
        const Text('Les employés scannent ce code avec Prestige Vente (menu « Pointage présence »).',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: couleurGris)),
      ]),
    );
    final telephones = _sectionTelephones();
    if (tablette) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: qr),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: telephones),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: actualiser,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [qr, const SizedBox(height: 12), telephones],
      ),
    );
  }

  Widget _sectionTelephones() {
    final t = _terminaux;
    return CartePresence(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t == null ? 'Téléphones enregistrés' : 'Téléphones enregistrés (${t.length})',
            key: const Key('terminaux_titre'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: couleurEncre)),
        const SizedBox(height: 6),
        if (_chargement) const LinearProgressIndicator(),
        if (_erreur != null)
          (t == null
              ? BlocErreur(message: messageErreur(_erreur!), onRetry: _chargerTerminaux)
              : LoadErrorBanner(message: messageErreur(_erreur!), onRetry: _chargerTerminaux)),
        if (t != null && t.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Aucun téléphone enregistré pour le pointage.', key: Key('terminaux_vide'), textAlign: TextAlign.center),
          ),
        if (t != null)
          for (final x in t) _terminal(x),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF5D08A)),
          ),
          child: const Text(
            'Retirer un téléphone le déconnecte immédiatement ; l\'employé devra se reconnecter. Chaque action est confirmée.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF7C2D12)),
          ),
        ),
      ]),
    );
  }

  Widget _terminal(TerminalMobile t) {
    final occupe = _enCours.contains(t.id);
    return Container(
      key: Key('terminal_${t.id}'),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.titre, style: TextStyle(fontWeight: t.actif ? FontWeight.bold : FontWeight.normal, color: couleurEncre)),
            Text(
              [t.appareil, if (t.derniereActivite.isNotEmpty) 'activité ${t.derniereActivite}'].join(' · '),
              style: const TextStyle(fontSize: 12.5, color: couleurGris),
            ),
          ]),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (t.actif ? couleurPresent : couleurGris).withAlpha(28),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(t.statutLisible, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: t.actif ? couleurPresent : couleurGris)),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 104,
          child: OutlinedButton(
            key: Key('terminal_action_${t.id}'),
            onPressed: occupe ? null : () => _changer(t, reactiver: !t.actif),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
            child: occupe
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t.actif ? 'Retirer' : 'Réactiver'),
          ),
        ),
      ]),
    );
  }
}
