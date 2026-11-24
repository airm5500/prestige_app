// Faux serveurs pour la 3.17.1 — données fictives uniquement. Trois serveurs Prestige possibles en officine :
//  - ANCIEN (déployé, 76aa5fc1) : /tableau-bord/version { success, version } sans « routes », pas de
//    /tableau-bord/tva (404), /ca-credit → LISTE (paramètres de page ignorés) ;
//  - 67/68 INITIAL (8dd9c9be) : version sans « routes », /tableau-bord/tva, /ca-credit paginé SANS luLe ni
//    tiersPayantsRetenus (support/donnees_3_17_0.dart) ;
//  - 67/68 + RETOUR du 20/11 (58db6a4e, intégration 63e9c10c) : version avec « routes »: ["tva", "ca-credit"],
//    /ca-credit paginé AVEC tiersPayantsRetenus et luLe (lecture gardée 60 s après la dernière page servie ; start=0
//    sans recherche ni tiers payant → relecture, nouveau luLe), comme rest.service.impl.PeriodesCaCredit.
// Plus, pour l'Analyse Article : produits « DOLIFICTIF » (recherche légère) et /info au CIP exact.
import 'donnees_3_17_0.dart';
import 'donnees_fictives.dart';
import 'donnees_lot3.dart';
import '../serveur_fictif.dart';

enum ServeurOfficine {
  ancien('ancien (76aa5fc1)'),
  initial('67/68 initial (8dd9c9be)'),
  retour('67/68 + retour du 20/11 (63e9c10c)');

  final String nom;
  const ServeurOfficine(this.nom);
}

class Donnees3171 {
  Donnees3171._();

  /// Routes annoncées par le serveur « retour ».
  static const routes = ['tva', 'ca-credit'];

  /// GET /tableau-bord/version : [routes] null = serveur antérieur (sans le champ).
  static Map<String, Object?> version({List<String>? routes}) => {'success': true, 'version': 'NOUVEAU', if (routes != null) 'routes': routes};

  /// Lecture du serveur « retour » : repère de la lecture en cours (horloge simulée du faux serveur).
  static int luLeCourant = 1795209514636;

  /// Fait comme si la période avait été relue côté serveur (plus de 60 s sans page, ou autre téléphone).
  static void relire() => luLeCourant += 61000;

  /// Page du serveur « retour » : page du 67 initial + tiersPayantsRetenus + luLe.
  static Object caCreditRetour(List<Map<String, Object?>> lignes, Map<String, String> p) {
    final rep = Donnees3170.caCredit(lignes, p);
    if (rep is! Map<String, Object?>) return rep;
    if (Donnees3170.premiere(p)) relire();
    final retenues = Donnees3170.filtrer(lignes, p['query'], p['tiersPayant']);
    return {
      ...rep,
      'tiersPayantsRetenus': {for (final o in retenues) if (o['tiersPayantLibelle'] is String) o['tiersPayantLibelle']}.length,
      'luLe': luLeCourant,
    };
  }

  /// Installe un des trois serveurs (routes 67 / 68 et version) ; [lignes] : ventes à crédit fictives.
  static void installer(ServeurFictif s, ServeurOfficine v, {List<Map<String, Object?>>? lignes, List<String>? routesAnnoncees}) {
    donneesLot3(s);
    final ventes = lignes ?? DonneesLot3.caCredit();
    switch (v) {
      case ServeurOfficine.ancien:
        s.quand('/tableau-bord/version', ReponseFausse.json(version()), methode: 'GET');
        s.quand('/tableau-bord/tva', ReponseFausse.introuvable(), methode: 'GET');
        s.quand('/ca-credit', ReponseFausse.json(ventes), methode: 'GET');
      case ServeurOfficine.initial:
        s.quand('/tableau-bord/version', ReponseFausse.json(version()), methode: 'GET');
        s.route('/tableau-bord/tva', (r) => ReponseFausse.json(Donnees3170.tva()), methode: 'GET');
        Donnees3170.installerCaCredit(s, ventes);
      case ServeurOfficine.retour:
        luLeCourant = 1795209514636;
        s.quand('/tableau-bord/version', ReponseFausse.json(version(routes: routesAnnoncees ?? routes)), methode: 'GET');
        if (routesAnnoncees == null || routesAnnoncees.contains('tva')) {
          s.route('/tableau-bord/tva', (r) => ReponseFausse.json(Donnees3170.tva()), methode: 'GET');
        } else {
          s.quand('/tableau-bord/tva', ReponseFausse.introuvable(), methode: 'GET');
        }
        if (routesAnnoncees == null || routesAnnoncees.contains('ca-credit')) {
          s.route('/ca-credit', (r) => ReponseFausse.json(caCreditRetour(ventes, r.parametres)), methode: 'GET');
        } else {
          s.quand('/ca-credit', ReponseFausse.json(ventes), methode: 'GET');
        }
    }
  }

  // --- Analyse Article (« doli ») -----------------------------------------------------------------------------

  static const cipsDoli = ['9991001', '9991002', '9991003', '9991004'];
  static const libellesDoli = ['DOLIFICTIF 1000MG CPR B/8', 'DOLIFICTIF 500MG CPR B/16', 'DOLIFICTIF 2.4% SIROP', 'DOLIFICTIF 150MG SUPPO B/10'];

  /// GET /espace-produit/recherche?q=doli.
  static Map<String, Object?> rechercheDoli() => {
        'total': 4,
        'data': [
          for (var i = 0; i < 4; i++)
            {'id': 'PRD-DOLI-$i', 'cip': cipsDoli[i], 'designation': libellesDoli[i], 'emplacement': 'RAYON FICTIF', 'prixVente': 1000 + 100 * i, 'stockTotal': 10 + i},
        ],
      };

  /// GET /info?search=<CIP> : l'article fictif de ce CIP (format de /info).
  static List<Map<String, Object?>> infoDoli(String cip) {
    final i = cipsDoli.indexOf(cip);
    if (i < 0) return const [];
    return [
      {...DonneesFictives.articlesAnalyse().first, 'produitId': 'PRD-DOLI-$i', 'codeCip': cip, 'libelle': libellesDoli[i]},
    ];
  }
}
