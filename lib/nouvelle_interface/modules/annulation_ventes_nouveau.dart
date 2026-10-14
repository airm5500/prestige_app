// lib/nouvelle_interface/modules/annulation_ventes_nouveau.dart
// Annulation de ventes de la nouvelle interface. Mêmes données et MÊME écriture que l'écran d'origine
// (AnnulationVente, lib/donnees/annulation_vente_donnees.dart) : recherche GET /ventestats (numéro obligatoire,
// 50 ventes au plus), détail GET /ventestats/find-one/{id}, annulation GET /vente/annulation/{id} (route serveur
// inchangée, déroulé partagé : relecture avant, envoi unique, relecture après, jamais de renvoi automatique).
//
// Sécurité renforcée côté application (l'annulation est IRRÉVERSIBLE) :
//  1. la vente s'ouvre d'abord en DÉTAIL (référence, date, client, montant, lignes) ; le bouton « Annuler cette
//     vente » n'existe que là, et seulement une fois le détail chargé et si la vente n'est pas déjà annulée ;
//  2. CONFIRMATION RENFORCÉE : récapitulatif, puis saisie de la référence de la vente ou du mot « ANNULER » ; le
//     bouton de validation reste désactivé tant que la saisie n'est pas complète ; « Ne pas annuler » n'envoie rien ;
//  3. CODE ADMINISTRATEUR (celui des zones protégées de l'application, PinCodeDialog) si le compte n'est ni
//     administrateur ni pharmacien (profil « xtypeuser » ≠ « dashboard », ProfilAcces) ; code refusé = rien d'envoyé ;
//  4. ANTI DOUBLE ENVOI : un verrou est pris dès l'appui (avant la confirmation) et rendu à la fin ; pendant l'envoi
//     le bouton devient un indicateur ;
//  5. message de résultat clair (vert / rouge) et encadré sur la page ; liste relue au retour ;
//  6. journal : seulement l'issue (aucune référence, client, montant ni identifiant).
// Le serveur reste juge du droit (P_BT_ANNULER_VENTE) : un refus est affiché « Annulation refusée : … ».
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../donnees/annulation_vente_donnees.dart';
import '../../models/vente_detail_model.dart';
import '../../models/vente_stat_model.dart';
import '../../widgets/pin_code_dialog.dart';
import '../charte.dart';
import '../composants.dart';
import '../vague1/profil_acces.dart';
import 'commun.dart';
import 'commun_lot2.dart';
import 'periode.dart';

/// Demande du code administrateur (remplaçable dans les tests).
typedef DemandeCodeAdmin = Future<bool> Function(BuildContext context);

class AnnulationVentesNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const AnnulationVentesNouveau({super.key, this.maintenant = DateTime.now});

  /// Code administrateur demandé aux comptes qui ne sont ni administrateur ni pharmacien.
  static DemandeCodeAdmin demanderCode = PinCodeDialog.show;

  @override
  State<AnnulationVentesNouveau> createState() => _AnnulationVentesNouveauState();
}

class _AnnulationVentesNouveauState extends State<AnnulationVentesNouveau> with ChargementSuivi<AnnulationVentesNouveau, List<VenteStat>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  final _recherche = TextEditingController();
  String _texte = '';

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  /// Recherche (numéro obligatoire, comme à l'origine : rien n'est envoyé sans numéro).
  Future<void> _charger() async {
    if (_texte.isEmpty) {
      abandonner();
      return;
    }
    await charger(() async =>
        await AnnulationVente.rechercher(context, debut: _periode.debut, fin: _periode.fin, recherche: _texte, onSessionInvalid: sessionInvalide(context)) ??
        const <VenteStat>[]);
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  Future<void> _ouvrir(VenteStat v) async {
    final modifiee = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DetailAnnulationVente(vente: v, periode: _periode, recherche: _texte),
    ));
    if (modifiee == true && mounted) _charger(); // état relu après une annulation
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Annulation de Ventes')),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            ChampRecherche(
              controleur: _recherche,
              libelle: 'Numéro de vente',
              aide: 'Ex. 260819_00001',
              enCours: enCours,
              onRecherche: (t) {
                setState(() => _texte = t);
                _charger();
              },
            ),
            const SizedBox(height: 8),
            const Encadre(
              titre: 'Annulation définitive',
              texte: 'Ouvrez la vente pour vérifier son détail. L\'annulation demande une confirmation et ne peut pas être défaite.',
              icone: Icons.info_outline,
              avertissement: true,
            ),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (_texte.isEmpty) {
      return const [
        EtatVide(
            titre: 'Recherchez une vente',
            texte: 'Saisissez le numéro de la vente à annuler ; la recherche porte sur la période choisie.',
            icone: Icons.manage_search),
      ];
    }
    if (enCours) return const [EtatChargement(texte: 'Recherche des ventes…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <VenteStat>[];
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucune vente trouvée', texte: 'Aucune vente trouvée pour ce numéro sur la période.', icone: Icons.search_off)];
    }
    final total = l.fold<double>(0, (s, v) => s + v.intPRICE);
    final annulees = l.where((v) => v.cancel).length;
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Ventes trouvées', valeur: formaterNombre(l.length), id: 'ventes', detail: l.length >= AnnulationVente.limite ? '50 au plus' : null),
        ChiffreCle(libelle: 'Montant', valeur: formaterMontant(total), id: 'montant', enAvant: true),
        ChiffreCle(libelle: 'Déjà annulées', valeur: formaterNombre(annulees), id: 'annulees'),
      ]),
      const TitreSection('Ventes'),
      ListeOuTableau(
        nombre: l.length,
        onTap: (i) => _ouvrir(l[i]),
        colonnes: const [
          Colonne('Référence', flex: 4),
          Colonne('Date', flex: 3),
          Colonne('Type', flex: 2),
          Colonne('Vendeur', flex: 3),
          Colonne('État', flex: 2),
          Colonne('Montant', flex: 3, droite: true),
        ],
        cellules: (i) => [l[i].strREF, '${l[i].dtCREATED} à ${l[i].HEUREVENTE}', l[i].strTYPEVENTE, l[i].userVendeurName,
          l[i].cancel ? 'Annulée' : 'Active', formaterMontant(l[i].intPRICE)],
        carte: (i) => CarteLigne(
          key: Key('vente_${l[i].lgPREENREGISTREMENTID}'),
          titre: 'Vente N° ${l[i].strREF}',
          etiquette: l[i].cancel ? const Etiquette('Annulée', ton: Ton.rouge) : null,
          lignes: ['${l[i].dtCREATED} à ${l[i].HEUREVENTE}${l[i].strTYPEVENTE.isEmpty ? '' : ' · ${l[i].strTYPEVENTE}'}', 'Vendeur : ${l[i].userVendeurName}'],
          libelleValeur: 'Montant',
          valeur: formaterMontant(l[i].intPRICE),
          onTap: () => _ouvrir(l[i]),
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Détail d'une vente et annulation
// ---------------------------------------------------------------------------------------------------------------

/// Détail d'une vente (lecture) et, seulement ici, son annulation protégée. Renvoie vrai au retour si une demande
/// d'annulation est partie (la liste est alors relue).
class DetailAnnulationVente extends StatefulWidget {
  final VenteStat vente;

  /// Période et numéro de la recherche : la relecture avant / après l'envoi refait la même recherche (comme l'origine).
  final Periode periode;
  final String recherche;
  const DetailAnnulationVente({super.key, required this.vente, required this.periode, required this.recherche});

  @override
  State<DetailAnnulationVente> createState() => _DetailAnnulationVenteState();
}

class _DetailAnnulationVenteState extends State<DetailAnnulationVente> with ChargementSuivi<DetailAnnulationVente, VenteDetail> {
  late VenteStat _vente = widget.vente;

  /// Verrou anti double envoi : pris dès l'appui sur « Annuler cette vente », rendu à la fin du déroulé.
  bool _verrou = false;

  /// Requête d'annulation (ou relectures) en cours.
  bool _envoi = false;

  ResultatAnnulation? _resultat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() => charger(() async =>
      await AnnulationVente.detail(context, _vente.lgPREENREGISTREMENTID, onSessionInvalid: sessionInvalide(context)) ??
      (throw const FormatException('Détail de la vente illisible')));

  /// Relecture de la vente (même recherche que la liste). Échec : ApiLoadException.
  Future<VenteStat?> _relire() async {
    final ventes = await AnnulationVente.rechercher(context, debut: widget.periode.debut, fin: widget.periode.fin, recherche: widget.recherche);
    if (ventes == null) return null;
    for (final v in ventes) {
      if (v.lgPREENREGISTREMENTID == _vente.lgPREENREGISTREMENTID) {
        if (mounted) setState(() => _vente = v);
        return v;
      }
    }
    return null;
  }

  bool get _dejaAnnulee => _vente.cancel || (donnees?.annulee ?? false) || (_resultat?.venteAnnulee ?? false);

  bool get _peutAnnuler => !_verrou && !enCours && erreur == null && donnees != null && !_dejaAnnulee;

  Future<void> _demanderAnnulation() async {
    if (!_peutAnnuler) return;
    setState(() => _verrou = true); // pris AVANT toute attente : un second appui ne fait rien
    try {
      final ok = await confirmerAnnulation(context, _vente, donnees!);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Annulation abandonnée : rien n\'a été envoyé.')));
        return;
      }
      if (!ProfilAcces.responsable) {
        final code = await AnnulationVentesNouveau.demanderCode(context);
        if (!mounted) return;
        if (!code) {
          messageResultat(context, 'Code administrateur non validé : la vente n\'a pas été annulée.', echec: true);
          return;
        }
      }
      setState(() => _envoi = true);
      final r = await AnnulationVente.executer(context, _vente, relire: _relire);
      if (r == null || !mounted) return;
      setState(() => _resultat = r);
      messageResultat(context, r.message, echec: r.ton != TonResultat.succes);
    } finally {
      if (mounted) {
        setState(() {
          _verrou = false;
          _envoi = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        // Retour (barre ou système) : refusé pendant l'envoi ; sinon la liste apprend si une demande est partie.
        canPop: false,
        onPopInvokedWithResult: (fait, _) {
          if (fait) return;
          if (_envoi) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Annulation en cours : attendez la réponse du serveur.')));
            return;
          }
          Navigator.of(context).pop(_resultat?.envoyee ?? false);
        },
        child: Scaffold(
            appBar: AppBar(title: const Text('Détail de la vente')),
            body: RefreshIndicator(
              onRefresh: _charger,
              child: ListView(key: const Key('defilement_detail'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                Text('Vente N° ${_vente.strREF}', style: const TextStyle(color: Charte.navy, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  _dejaAnnulee
                      ? const Etiquette('Annulée', ton: Ton.rouge, key: Key('etat_annulee'))
                      : const Etiquette('Non annulée', ton: Ton.vert, key: Key('etat_active')),
                  if (_vente.strTYPEVENTE.isNotEmpty) Etiquette(_vente.strTYPEVENTE, ton: Ton.gris),
                ]),
                const SizedBox(height: 8),
                ..._corps(),
              ]),
            ),
          ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement du détail de la vente…')];
    if (erreur != null) {
      return [
        EtatErreur(erreur: erreur!, reessayer: _charger),
        const Encadre(
          texte: 'Le détail de la vente doit être affiché avant toute annulation.',
          icone: Icons.lock_outline,
          avertissement: true,
        ),
      ];
    }
    final d = donnees;
    if (d == null) return const [];
    final r = _resultat;
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Montant', valeur: formaterMontant(_vente.intPRICE), id: 'montant', enAvant: true),
        ChiffreCle(libelle: 'Articles', valeur: formaterNombre(d.items.length), id: 'articles'),
      ]),
      const SizedBox(height: 12),
      CarteSection(titre: 'Vente', icone: Icons.receipt_long_outlined, enfants: [
        LigneDetail('Référence', _vente.strREF),
        LigneDetail('Date', '${_vente.dtCREATED} à ${_vente.HEUREVENTE}'),
        LigneDetail('Client', d.client.isEmpty ? 'Non renseigné' : d.client),
        LigneDetail('Vendeur', d.vendeur),
        LigneDetail('Type de vente', d.typeVente),
        if (_vente.strREFTICKET.isNotEmpty) LigneDetail('Ticket', _vente.strREFTICKET),
        LigneDetail('Montant', formaterMontant(_vente.intPRICE), gras: true),
      ]),
      const TitreSection('Lignes de la vente'),
      if (d.items.isEmpty)
        const EtatVide(titre: 'Aucune ligne', icone: Icons.inventory_2_outlined)
      else
        ListeOuTableau(
          nombre: d.items.length,
          colonnes: const [
            Colonne('Produit', flex: 6),
            Colonne('Qté', flex: 1, droite: true),
            Colonne('Prix unitaire', flex: 3, droite: true),
            Colonne('Montant', flex: 3, droite: true),
          ],
          cellules: (i) => [d.items[i].strDESCRIPTION, '${d.items[i].intQUANTITY}', formaterMontant(d.items[i].intPRICEUNITAIR), formaterMontant(d.items[i].intPRICE)],
          carte: (i) => CarteLigne(
            titre: d.items[i].strDESCRIPTION,
            lignes: ['${d.items[i].intQUANTITY} × ${formaterMontant(d.items[i].intPRICEUNITAIR)}'],
            valeur: formaterMontant(d.items[i].intPRICE),
          ),
        ),
      const SizedBox(height: 16),
      if (r != null) ...[
        _EncadreResultat(r),
        const SizedBox(height: 12),
      ],
      if (_envoi)
        const Center(
          key: Key('annulation_en_cours'),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Annulation en cours… ne quittez pas l\'écran.', style: TextStyle(color: Charte.gris)),
            ]),
          ),
        )
      else if (_dejaAnnulee)
        const Encadre(texte: 'Cette vente est annulée : aucune action possible.', icone: Icons.block, avertissement: true)
      else
        ElevatedButton.icon(
          key: const Key('bouton_annuler_vente'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: Charte.rougeTexte,
            foregroundColor: Charte.blanc,
          ),
          onPressed: _peutAnnuler ? _demanderAnnulation : null,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Annuler cette vente'),
        ),
    ];
  }
}

class _EncadreResultat extends StatelessWidget {
  final ResultatAnnulation r;
  const _EncadreResultat(this.r);

  @override
  Widget build(BuildContext context) {
    final succes = r.ton == TonResultat.succes;
    if (!succes) {
      return Encadre(
          key: const Key('resultat_annulation'),
          titre: r.envoyee ? 'Résultat de l\'annulation' : 'Annulation non envoyée',
          texte: r.message,
          icone: Icons.error_outline,
          avertissement: r.ton == TonResultat.neutre);
    }
    return Container(
      key: const Key('resultat_annulation'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Charte.vertClair, borderRadius: BorderRadius.circular(12), border: Border.all(color: Charte.vert)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_outline, color: Charte.vertTexte),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
                liveRegion: true,
                child: const Text('Vente annulée', style: TextStyle(color: Charte.vertTexte, fontSize: 16, fontWeight: FontWeight.bold))),
            Text(r.message, style: const TextStyle(color: Charte.vertTexte, fontSize: 13.5, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Confirmation renforcée
// ---------------------------------------------------------------------------------------------------------------

/// Confirmation renforcée : récapitulatif, puis saisie de la référence de la vente ou de « ANNULER ». Vrai seulement
/// si l'utilisateur valide une saisie complète ; « Ne pas annuler » ou le retour donnent faux.
Future<bool> confirmerAnnulation(BuildContext context, VenteStat vente, VenteDetail detail) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConfirmationAnnulation(vente: vente, detail: detail),
  );
  return r == true;
}

class _ConfirmationAnnulation extends StatefulWidget {
  final VenteStat vente;
  final VenteDetail detail;
  const _ConfirmationAnnulation({required this.vente, required this.detail});

  @override
  State<_ConfirmationAnnulation> createState() => _ConfirmationAnnulationState();
}

class _ConfirmationAnnulationState extends State<_ConfirmationAnnulation> {
  final _saisie = TextEditingController();
  bool _ferme = false;

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  bool get _valide => AnnulationVente.confirmationValide(_saisie.text, widget.vente.strREF);

  void _fermer(bool resultat) {
    if (_ferme) return; // double appui : un seul retour
    _ferme = true;
    Navigator.of(context).pop(resultat);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vente, d = widget.detail;
    return AlertDialog(
      key: const Key('confirmation_annulation'),
      scrollable: true,
      title: const Text('Annuler définitivement cette vente ?'),
      content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        LigneDetail('Référence', v.strREF),
        LigneDetail('Date', '${v.dtCREATED} à ${v.HEUREVENTE}'),
        LigneDetail('Client', d.client.isEmpty ? 'Non renseigné' : d.client),
        LigneDetail('Articles', formaterNombre(d.items.length)),
        LigneDetail('Montant', formaterMontant(v.intPRICE), gras: true),
        const SizedBox(height: 10),
        const Encadre(
          texte: 'Cette annulation est définitive : elle ne pourra pas être défaite depuis l\'application.',
          icone: Icons.warning_amber_rounded,
          avertissement: true,
        ),
        const SizedBox(height: 12),
        Text('Pour confirmer, saisissez la référence de la vente (${v.strREF}) ou le mot ${AnnulationVente.motConfirmation}.',
            style: const TextStyle(color: Charte.encre, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          key: const Key('confirmation_saisie'),
          controller: _saisie,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(40), FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_ ./-]'))],
          decoration: const InputDecoration(labelText: 'Référence ou ANNULER'),
          onChanged: (_) => setState(() {}),
        ),
      ]),
      actions: [
        TextButton(key: const Key('confirmation_non'), onPressed: () => _fermer(false), child: const Text('Ne pas annuler')),
        ElevatedButton(
          key: const Key('confirmation_oui'),
          style: ElevatedButton.styleFrom(backgroundColor: Charte.rougeTexte, foregroundColor: Charte.blanc),
          onPressed: _valide ? () => _fermer(true) : null,
          child: const Text('Annuler la vente'),
        ),
      ],
    );
  }
}
