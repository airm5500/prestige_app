// lib/presences/presences_reglages_screen.dart
// Réglages du pharmacien pour les présences : seuil de retard (0 à 480 min, 60 par défaut).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'presences_modeles.dart';
import 'presences_reglages.dart';
import 'presences_widgets.dart';

class ReglagesPresencesScreen extends StatefulWidget {
  const ReglagesPresencesScreen({super.key});

  @override
  State<ReglagesPresencesScreen> createState() => _ReglagesPresencesScreenState();
}

class _ReglagesPresencesScreenState extends State<ReglagesPresencesScreen> {
  final _form = GlobalKey<FormState>();
  late final _seuil = TextEditingController(text: '${ReglagesPresences.seuil.value}');

  @override
  void dispose() {
    _seuil.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final v = int.parse(_seuil.text.trim());
    await ReglagesPresences.enregistrerSeuil(v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Seuil de retard enregistré : ${dureeLisible(v)}.'), backgroundColor: couleurPresent),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Réglages des présences')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Seuil de retard', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: couleurEncre)),
            const SizedBox(height: 6),
            const Text(
              'Un employé est marqué « En retard » si son arrivée dépasse l\'heure prévue de plus de ce nombre de minutes. '
              'Ce réglage ne change que l\'affichage sur ce téléphone (Prestige garde sa propre tolérance pour ses calculs et exports).',
              style: TextStyle(color: couleurGris),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('reglage_seuil'),
              controller: _seuil,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              decoration: const InputDecoration(
                labelText: 'Seuil (minutes)',
                helperText: 'De ${ReglagesPresences.seuilMin} à ${ReglagesPresences.seuilMax} minutes · 60 par défaut',
                suffixText: 'min',
                border: OutlineInputBorder(),
              ),
              validator: ReglagesPresences.erreurSeuil,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final v in const [15, 30, 60, 90])
                ActionChip(label: Text(dureeLisible(v)), onPressed: () => setState(() => _seuil.text = '$v')),
            ]),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('reglage_enregistrer'),
              onPressed: _enregistrer,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer'),
            ),
          ]),
        ),
      );
}
