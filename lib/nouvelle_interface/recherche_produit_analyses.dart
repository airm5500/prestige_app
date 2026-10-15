// lib/nouvelle_interface/recherche_produit_analyses.dart
// Zone de recherche de produit en haut de l'onglet « Analyses » (3.9.0, demande du pharmacien) : mode « CONTIENT »
// (une partie du nom, du CIP ou de l'EAN), puis l'analyse du produit touché (même écran de détail qu'Analyse
// Article). Données : lib/donnees/recherche_produit_donnees.dart (/espace-produit/recherche puis /info au CIP
// exact ; repli « commence par » sur un serveur plus ancien, dit à l'écran). Recherche vide : les menus de l'onglet
// ([menus]) s'affichent comme avant.
import 'package:flutter/material.dart';

import '../donnees/recherche_produit_donnees.dart';
import 'charte.dart';
import 'composants.dart';
import 'modules/articles_nouveau.dart';
import 'modules/commun.dart';
import 'modules/commun_lot2.dart' show messageResultat;

class RechercheProduitAnalyses extends StatefulWidget {
  /// Contenu affiché sans recherche (menus de l'onglet).
  final Widget menus;
  const RechercheProduitAnalyses({super.key, required this.menus});

  @override
  State<RechercheProduitAnalyses> createState() => _RechercheProduitAnalysesState();
}

class _RechercheProduitAnalysesState extends State<RechercheProduitAnalyses>
    with ChargementSuivi<RechercheProduitAnalyses, ResultatRechercheProduit> {
  final _controleur = TextEditingController();
  String _terme = '';

  /// CIP dont l'analyse est en cours d'ouverture (un seul à la fois : anti double appui).
  String? _ouverture;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _rechercher(String texte) {
    _terme = texte;
    if (!RechercheProduit.assezLong(texte)) {
      abandonner();
      return;
    }
    charger(() => RechercheProduit.rechercher(context, texte, onSessionInvalid: sessionInvalide(context)));
  }

  Future<void> _ouvrir(ProduitTrouve p) async {
    if (_ouverture != null) return;
    setState(() => _ouverture = p.cip);
    try {
      final a = await RechercheProduit.analyse(context, p, onSessionInvalid: sessionInvalide(context));
      if (!mounted) return;
      if (a == null) {
        messageResultat(context, 'Analyse introuvable pour le CIP ${p.cip}.', echec: true);
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailAnalyseArticle(article: a)));
    } catch (e) {
      if (!mounted) return;
      final d = DiagnosticErreur.de(e);
      messageResultat(context, d.cause == CauseErreur.autre ? d.message : '${d.titre}. ${d.message}', echec: true);
    } finally {
      if (mounted) setState(() => _ouverture = null);
    }
  }

  bool get _active => _controleur.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          key: const Key('recherche_produit_analyses'),
          color: Charte.blanc,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: ChampRecherche(
            controleur: _controleur,
            libelle: 'Rechercher un produit',
            aide: 'Une partie du nom, du CIP ou de l\'EAN',
            enCours: enCours,
            onRecherche: (t) {
              setState(() {});
              _rechercher(t);
            },
          ),
        ),
        Expanded(child: _active ? _resultats() : widget.menus),
      ]);

  Widget _resultats() {
    final enfants = <Widget>[];
    final r = donnees;
    if (!RechercheProduit.assezLong(_controleur.text)) {
      enfants.add(const EtatVide(
          titre: 'Recherchez un produit', texte: 'Saisissez au moins 2 caractères : une partie du nom, du CIP ou de l\'EAN.', icone: Icons.search));
    } else if (enCours) {
      enfants.add(const EtatChargement(texte: 'Recherche en cours…'));
    } else if (erreur != null) {
      enfants.add(EtatErreur(erreur: erreur!, reessayer: () => _rechercher(_terme)));
    } else if (r != null) {
      if (!r.contient) {
        enfants.add(const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Encadre(
            key: Key('recherche_produit_commence_par'),
            avertissement: true,
            icone: Icons.info_outline,
            titre: 'Recherche « commence par »',
            texte: 'Ce serveur Prestige ne propose pas encore la recherche « contient » : '
                'produits dont le nom ou le CIP commence par le texte saisi.',
          ),
        ));
      }
      if (r.produits.isEmpty) {
        enfants.add(EtatVide(titre: 'Aucun produit trouvé', texte: 'Aucun produit pour « $_terme ».', icone: Icons.search_off));
      } else {
        enfants.add(TitreSection(
            '${r.produits.length} produit${r.produits.length > 1 ? 's' : ''}${r.contient ? ' contenant « $_terme »' : ''}',
            marge: const EdgeInsets.fromLTRB(4, 4, 4, 6)));
        if (r.limiteAtteinte) {
          enfants.add(const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text('Les ${RechercheProduit.maxResultats} premiers : précisez la recherche pour voir les autres.',
                key: Key('recherche_produit_limite'), style: TextStyle(color: Charte.gris, fontSize: 13)),
          ));
        }
        for (final p in r.produits) {
          enfants.add(CarteLigne(
            key: Key('produit_${p.cip}'),
            titre: p.designation,
            lignes: [
              ['CIP ${p.cip}', if (p.stockTotal != null) 'Stock ${formaterNombre(p.stockTotal!)}', if (p.emplacement != null) p.emplacement!]
                  .join(' · '),
            ],
            valeur: p.prixVente == null ? null : formaterMontant(p.prixVente),
            action: _ouverture == p.cip
                ? const Padding(
                    padding: EdgeInsets.only(left: 8, top: 2),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : null,
            onTap: () => _ouvrir(p),
          ));
        }
      }
    }
    return ListView(key: const Key('defilement_recherche_produit'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: enfants);
  }
}
