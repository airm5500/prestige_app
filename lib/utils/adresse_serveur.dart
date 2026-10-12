// lib/utils/adresse_serveur.dart
// Adresse du serveur saisie dans la Configuration : « 192.168.1.10 », « pharmacie.example.com »,
// ou avec le protocole : « https://pharmacie.example.com » (serveur exposé sur Internet avec un certificat)
// ou « http://… ». Sans protocole, HTTP est utilisé (réseau local : comportement d'origine, inchangé).
// HTTPS n'est jamais imposé. La valeur est gardée telle que saisie, sous les mêmes clés (local_ip,
// remote_ip) : aucune migration.
class AdresseServeur {
  AdresseServeur._();

  static final RegExp _protocole = RegExp(r'^(https?)://', caseSensitive: false);
  static final RegExp _ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
  static final RegExp _nomHote = RegExp(r'^(?=.{1,253}$)([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$');

  /// Longueur maximale de la saisie.
  static const maxLongueur = 270;

  /// Protocole (« http » ou « https ») et hôte, ou null si la saisie est vide / invalide.
  static ({String protocole, String hote})? analyser(String? saisie) {
    var t = (saisie ?? '').trim();
    if (t.isEmpty) return null;
    var protocole = 'http';
    final m = _protocole.firstMatch(t);
    if (m != null) {
      protocole = m.group(1)!.toLowerCase();
      t = t.substring(m.end);
    }
    while (t.endsWith('/')) {
      t = t.substring(0, t.length - 1);
    }
    if (!estHoteValide(t)) return null;
    return (protocole: protocole, hote: t);
  }

  static bool estHoteValide(String hote) {
    final ip = _ipv4.firstMatch(hote);
    if (ip != null) {
      for (var i = 1; i <= 4; i++) {
        if (int.parse(ip.group(i)!) > 255) return false;
      }
      return true;
    }
    if (RegExp(r'^[\d.]+$').hasMatch(hote)) return false; // « 192.168.1 » : IP incomplète
    return _nomHote.hasMatch(hote);
  }

  /// La saisie demande HTTPS.
  static bool estHttps(String? saisie) => analyser(saisie)?.protocole == 'https';

  /// Motif de refus, ou null si la saisie est acceptée ([requis] : champ obligatoire).
  static String? erreur(String? saisie, {required bool requis}) {
    final t = (saisie ?? '').trim();
    if (t.isEmpty) return requis ? 'Ce champ est requis.' : null;
    if (t.length > maxLongueur) return 'Adresse trop longue.';
    final sansProtocole = t.replaceFirst(_protocole, '');
    if (RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(sansProtocole) || (t.contains('://') && !_protocole.hasMatch(t))) {
      return 'Seuls http:// et https:// sont acceptés.';
    }
    if (sansProtocole.contains(':')) return 'Indiquez le port dans le champ « Port du Serveur ».';
    if (RegExp(r'/.+').hasMatch(sansProtocole)) return 'Indiquez seulement l\'adresse (sans chemin).';
    if (analyser(t) == null) return 'Adresse invalide (ex : 192.168.1.100 ou https://pharmacie.example.com).';
    return null;
  }

  /// Racine du serveur : « http(s)://hôte:port/application ». Saisie invalide : utilisée telle quelle en
  /// HTTP (comportement d'origine), la requête échouera avec un message clair.
  static String racine(String saisie, String port, String application) {
    final a = analyser(saisie);
    final protocole = a?.protocole ?? 'http';
    final hote = a?.hote ?? (saisie.trim().isEmpty ? '0.0.0.0' : saisie.trim());
    return '$protocole://$hote:$port/$application';
  }
}
