// Contrôle des requêtes de la vague 2 : aucune route INTERDITE au mobile (écritures, recalculs, créations) ne doit
// jamais être reçue par le faux serveur, et aucune requête autre que GET sur les routes de la vague 2.
import 'faux_serveur_prestige.dart';

/// Routes interdites testées (mêmes que routesInterditesVague2, plus celles d'une garde).
const routesInterditesTestees = <String>[
  '/analyse-commande/analyse/appliquer',
  '/analyse-commande/previsions/suggestion',
  '/analyse-commande/previsions/inventaire',
  '/analyse-commande/recalculer',
  '/analyse-commande/parametres',
  '/pilotage/recalculer',
  '/pilotage/charges',
  '/ca-zone-geo/detail/inventaire',
  '/gardes/supprimer',
  '/gardes/GARDE-TEST-1/inventaire',
  '/gardes/GARDE-TEST-1/suggestion',
];

const prefixesVague2 = ['/analyse-commande', '/pilotage', '/gardes', '/ca-zone-geo'];

/// Requêtes fautives reçues : route interdite, ou méthode autre que GET sur une route de la vague 2.
List<String> requetesInterdites(FauxServeurPrestige s) => [
      for (final r in s.requetes)
        if (routesInterditesTestees.contains(r.chemin) ||
            RegExp(r'^/gardes/[^/]+/(inventaire|suggestion)$').hasMatch(r.chemin) ||
            (prefixesVague2.any((p) => r.chemin.startsWith(p)) && r.methode != 'GET'))
          '$r',
    ];
