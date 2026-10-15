// Rapport de tests de LIVRAISON (Prestige Pharmacien), repris de Prestige Inventaire (même format).
//
// Lit les sorties JSON de `flutter test` (une par catégorie, écrites par la CI avec
// `--file-reporter json:build/rapport_tests/<n>-<categorie>.json`) et produit un résumé Markdown :
//  - par catégorie : nombre de tests, réussis, sautés, échecs, durée ;
//  - les tests en échec et les tests sautés (avec leur motif, ex. « Défaut connu D1 ») ;
//  - les MESURES de performance et de requêtes (lignes « PRESTIGE_MESURE {json} » imprimées par
//    test/support/performance.dart) : valeur, seuil, part du seuil utilisée.
//
// Utilisation :
//   dart run tool/rapport_tests.dart build/rapport_tests            # Markdown sur la sortie standard
//   dart run tool/rapport_tests.dart build/rapport_tests >> "$GITHUB_STEP_SUMMARY"
// Écrit aussi build/rapport_tests/rapport.md et build/rapport_tests/resume.json (artefact
// « rapport-tests »). Code de sortie 0 : le rapport ne décide pas du succès du job (les étapes de test
// échouent d'elles-mêmes).
import 'dart:convert';
import 'dart:io';

/// Libellés des catégories (clé = nom du fichier sans le numéro d'ordre ni « .json »).
const libelles = {
  'unitaires': 'Unitaires et non-régression',
  'integration': 'Intégration (services, faux serveur HTTP)',
  'e2e': 'Bout en bout (application entière)',
  'ergonomie': 'Ergonomie et cohérence d\'affichage',
  'performance': 'Performance (temps, images, requêtes)',
  'reseau': 'Réseau (lenteur, tronqué, coupures, local/distant, HTTPS)',
};

class Categorie {
  final String cle;
  int tests = 0, reussis = 0, sautes = 0, echecs = 0;
  int dureeMs = 0;
  bool termine = false;
  final List<String> enEchec = [];
  final List<String> sautesNoms = [];
  Categorie(this.cle);
  String get libelle => libelles[cle] ?? cle;
}

class Mesure {
  final String categorie, nom, unite;
  final num valeur, seuil;
  final String? detail;
  Mesure(this.categorie, this.nom, this.valeur, this.seuil, this.unite, this.detail);
  double get part => seuil == 0 ? (valeur == 0 ? 0 : double.infinity) : valeur / seuil;
}

String cleDe(String fichier) {
  var n = fichier.split(Platform.pathSeparator).last.replaceAll('.json', '');
  final m = RegExp(r'^\d+-').firstMatch(n);
  if (m != null) n = n.substring(m.end);
  return n;
}

String duree(int ms) {
  final s = ms ~/ 1000;
  return s >= 60 ? '${s ~/ 60} min ${(s % 60).toString().padLeft(2, '0')} s' : '$s s';
}

String nombre(num v) {
  if (v is int || v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1).replaceAll('.', ',');
}

void main(List<String> args) {
  final dossier = Directory(args.isEmpty ? 'build/rapport_tests' : args.first);
  final fichiers = dossier.existsSync()
      ? (dossier.listSync().whereType<File>().where((f) => f.path.endsWith('.json') && !f.path.endsWith('resume.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];
  final categories = <Categorie>[];
  final mesures = <Mesure>[];

  for (final f in fichiers) {
    final c = Categorie(cleDe(f.path));
    categories.add(c);
    final noms = <int, String>{};
    final skipMotif = <int, String?>{};
    for (final ligne in f.readAsLinesSync()) {
      if (!ligne.startsWith('{')) continue;
      final Map<String, dynamic> e;
      try {
        e = json.decode(ligne) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final t = e['time'];
      if (t is int && t > c.dureeMs) c.dureeMs = t;
      switch (e['type']) {
        case 'testStart':
          final test = e['test'] as Map<String, dynamic>;
          noms[test['id'] as int] = '${test['name']}';
          skipMotif[test['id'] as int] = (test['metadata'] as Map?)?['skipReason'] as String?;
        case 'testDone':
          if (e['hidden'] == true) {
            // Chargement d'un fichier en échec (erreur de compilation) : compté comme un échec.
            if (e['result'] != 'success') {
              c.tests++;
              c.echecs++;
              c.enEchec.add(noms[e['testID']] ?? '?');
            }
            continue;
          }
          c.tests++;
          final nom = noms[e['testID']] ?? '?';
          if (e['skipped'] == true) {
            c.sautes++;
            final motif = skipMotif[e['testID']];
            c.sautesNoms.add(motif == null || motif.isEmpty ? nom : '$nom — $motif');
          } else if (e['result'] == 'success') {
            c.reussis++;
          } else {
            c.echecs++;
            c.enEchec.add(nom);
          }
        case 'print':
          final m = '${e['message']}';
          const prefixe = 'PRESTIGE_MESURE ';
          for (final l in m.split('\n')) {
            if (!l.startsWith(prefixe)) continue;
            try {
              final d = json.decode(l.substring(prefixe.length)) as Map<String, dynamic>;
              mesures.add(Mesure(c.cle, '${d['nom']}', d['valeur'] as num, d['seuil'] as num, '${d['unite']}', d['detail'] as String?));
            } catch (_) {}
          }
        case 'done':
          c.termine = true;
      }
    }
  }

  final b = StringBuffer();
  final total = Categorie('total');
  for (final c in categories) {
    total
      ..tests += c.tests
      ..reussis += c.reussis
      ..sautes += c.sautes
      ..echecs += c.echecs
      ..dureeMs += c.dureeMs;
  }
  final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(File('pubspec.yaml').existsSync() ? File('pubspec.yaml').readAsStringSync() : '')?.group(1);
  b.writeln('## Rapport de tests de livraison — Prestige Pharmacien${version == null ? '' : ' $version'}');
  b.writeln();
  if (categories.isEmpty) {
    b.writeln('Aucun résultat de test trouvé dans `${dossier.path}`.');
  } else {
    b.writeln(total.echecs == 0 ? '**Tous les tests exécutés sont réussis.**' : '**${total.echecs} test(s) en échec.**');
    b.writeln();
    b.writeln('| Catégorie | Tests | Réussis | Sautés | Échecs | Durée |');
    b.writeln('|---|---:|---:|---:|---:|---:|');
    for (final c in categories) {
      b.writeln('| ${c.libelle}${c.termine ? '' : ' (interrompue)'} | ${c.tests} | ${c.reussis} | ${c.sautes} | ${c.echecs == 0 ? '0' : '**${c.echecs}**'} | ${duree(c.dureeMs)} |');
    }
    b.writeln('| **Total** | **${total.tests}** | **${total.reussis}** | **${total.sautes}** | **${total.echecs}** | **${duree(total.dureeMs)}** |');
    b.writeln();
  }

  if (mesures.isNotEmpty) {
    b.writeln('### Mesures de performance et de requêtes (seuils qui font échouer la CI)');
    b.writeln();
    b.writeln('| Mesure | Valeur | Seuil | Part du seuil | État |');
    b.writeln('|---|---:|---:|---:|:---:|');
    for (final m in mesures) {
      final part = m.part.isFinite ? '${(m.part * 100).round()} %' : '—';
      final etat = m.valeur > m.seuil ? '❌ dépassé' : (m.part > 0.8 && m.unite == 'ms' ? '⚠️ proche' : '✅');
      final detail = m.detail == null || m.detail!.isEmpty ? '' : '<br><sub>${m.detail}</sub>';
      b.writeln('| ${m.nom}$detail | ${nombre(m.valeur)} ${m.unite} | ${nombre(m.seuil)} ${m.unite} | $part | $etat |');
    }
    b.writeln();
  }

  final echecs = [for (final c in categories) for (final n in c.enEchec) '- ${c.libelle} : $n'];
  if (echecs.isNotEmpty) {
    b.writeln('### Tests en échec');
    b.writeln();
    echecs.forEach(b.writeln);
    b.writeln();
  }
  final sautes = [for (final c in categories) for (final n in c.sautesNoms) '- ${c.libelle} : $n'];
  if (sautes.isNotEmpty) {
    b.writeln('<details><summary>Tests sautés (${sautes.length}) — anomalies connues, voir test/README.md</summary>');
    b.writeln();
    sautes.forEach(b.writeln);
    b.writeln();
    b.writeln('</details>');
  }

  final texte = b.toString();
  stdout.write(texte);
  if (dossier.existsSync()) {
    File('${dossier.path}/rapport.md').writeAsStringSync(texte);
    File('${dossier.path}/resume.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'version': version,
      'categories': [
        for (final c in categories)
          {'categorie': c.cle, 'libelle': c.libelle, 'tests': c.tests, 'reussis': c.reussis, 'sautes': c.sautes, 'echecs': c.echecs, 'dureeMs': c.dureeMs},
      ],
      'mesures': [
        for (final m in mesures) {'categorie': m.categorie, 'nom': m.nom, 'valeur': m.valeur, 'seuil': m.seuil, 'unite': m.unite, if (m.detail != null) 'detail': m.detail},
      ],
    }));
  }
}
