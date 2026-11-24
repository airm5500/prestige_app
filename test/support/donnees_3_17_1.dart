// Données fictives de la 3.17.1 : déplacées dans lib/demo/donnees/ (3.18.0, mode démonstration). Reste ici le client
// de test qui sérialise les requêtes lourdes d'une session.
import 'package:http/http.dart' as http;

export 'package:prestige_app/demo/donnees/donnees_3_17_1.dart';

/// Client de test : un serveur dont les requêtes LOURDES d'une même session passent une à une (pire cas : session
/// sérialisée), chacune [duree] ; le serveur termine son travail même si l'application abandonne la requête (comme
/// Payara : la requête SQL continue). Les abandons (http.Abortable) sont relevés : aucune requête orpheline.
class ClientSessionSerialisee extends http.BaseClient {
  final http.Client interne;
  final bool Function(Uri url) lourde;
  final Duration Function(Uri url) duree;
  ClientSessionSerialisee(this.interne, {required this.lourde, required this.duree});

  Future<void> _file = Future<void>.value();

  /// Requêtes lourdes envoyées, terminées (réponse reçue par l'application), abandonnées par l'application.
  final envoyees = <String>[];
  final recues = <String>[];
  final abandonnees = <String>[];

  /// Requêtes lourdes ni reçues ni abandonnées.
  int get enSuspens => envoyees.length - recues.length - abandonnees.length;

  static String _cle(Uri u) => u.queryParameters['search'] ?? u.path;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!lourde(request.url)) return interne.send(request);
    final cle = _cle(request.url);
    envoyees.add(cle);
    final precedente = _file;
    final travail = () async {
      await precedente;
      await Future<void>.delayed(duree(request.url));
    }();
    _file = travail;
    final abandon = request is http.Abortable ? request.abortTrigger : null;
    var abandonnee = false;
    if (abandon != null) {
      await Future.any([travail, abandon.then((_) => abandonnee = true)]);
    } else {
      await travail;
    }
    if (abandonnee) {
      abandonnees.add(cle);
      throw http.RequestAbortedException(request.url);
    }
    final r = await interne.send(request);
    recues.add(cle);
    return r;
  }
}
