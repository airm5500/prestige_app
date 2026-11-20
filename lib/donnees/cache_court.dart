// lib/donnees/cache_court.dart
// 3.16.0 — cache MÉMOIRE court (jamais sur disque) des lectures répétées : recherche d'articles, analyse d'un
// produit, cartes de l'accueil. Une lecture en cours est partagée (jamais deux requêtes identiques en parallèle) ;
// un échec (ou une lecture abandonnée, null) n'est jamais gardé. La clé commence par la source ([CacheCourt.source] :
// serveur local ou distant, et session) : l'autre serveur, une autre session (reconnexion, autre compte) ne relisent
// jamais les données d'avant.
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/ip_config_provider.dart';
import '../services/api_service.dart';

class CacheCourt<T> {
  CacheCourt({required this.duree, this.maxEntrees = 100, DateTime Function()? horloge}) : horloge = horloge ?? DateTime.now;

  /// Durée de vie d'une réponse.
  final Duration duree;

  /// Entrées gardées au plus (les plus anciennes partent d'abord).
  final int maxEntrees;
  final DateTime Function() horloge;

  final _entrees = <String, ({DateTime le, Future<T> valeur})>{};

  /// Valeurs déjà arrivées (affichage immédiat, sans attendre une image).
  final _arrivees = <String, T>{};

  /// Lectures réellement lancées (diagnostic, tests).
  int lectures = 0;

  /// Valeur de [cle] : fraîche en cache ou en cours, sinon [charger] (une seule fois). [frais] : relecture forcée.
  Future<T> lire(String cle, Future<T> Function() charger, {bool frais = false}) {
    final e = _entrees[cle];
    if (!frais && e != null && horloge().difference(e.le) < duree) return e.valeur;
    lectures++;
    final f = charger();
    _entrees.remove(cle);
    _arrivees.remove(cle);
    _entrees[cle] = (le: horloge(), valeur: f);
    while (_entrees.length > maxEntrees) {
      _arrivees.remove(_entrees.keys.first);
      _entrees.remove(_entrees.keys.first);
    }
    // Un échec, ou une lecture abandonnée (null : écran fermé), n'est jamais gardé (la prochaine lecture réessaie).
    // L'erreur reste transmise à l'appelant.
    void oublier() {
      if (identical(_entrees[cle]?.valeur, f)) _entrees.remove(cle);
    }

    f.then((v) {
      if (v == null) {
        oublier();
      } else if (identical(_entrees[cle]?.valeur, f)) {
        _arrivees[cle] = v;
      }
    }, onError: (Object _) => oublier());
    return f;
  }

  /// La valeur de [cle] est-elle en cache (fraîche, arrivée ou en cours) ?
  bool contient(String cle) {
    final e = _entrees[cle];
    return e != null && horloge().difference(e.le) < duree;
  }

  /// Valeur de [cle] déjà arrivée et encore fraîche, sinon null.
  T? connue(String cle) => contient(cle) ? _arrivees[cle] : null;

  void vider() {
    _entrees.clear();
    _arrivees.clear();
  }

  /// Source d'une clé : mode du serveur (local / distant) et session en cours. L'adresse elle-même n'y est pas : elle
  /// peut être relue juste après le lancement (même serveur) ; un autre serveur, c'est une autre session (connexion).
  static String source(BuildContext context) =>
      '${Provider.of<IpConfigProvider>(context, listen: false).useLocalIp ? 'local' : 'distant'}|${ApiService().empreinteSession}';
}
