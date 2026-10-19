// lib/nouvelle_interface/vague3/pointage_vague3.dart
// Menu « Pointage BL » (web « pointagebl », onglet Pointage seulement ; le rapprochement avec le relevé PDF reste sur
// le web). Droit P_SM_POINTAGE_BL vérifié par le serveur sur toutes les routes (refus → « Droit manquant »).
//  - critères : un grossiste OU un groupe de grossistes (obligatoire, comme le web), période (« Ce mois » à
//    l'ouverture = début du mois, un an au plus comme le serveur), état Toutes / Non pointées / Pointées ;
//  - totaux du serveur en cartes : BL, avoirs, net HT, pointées, à pointer ;
//  - pièces : type, N° BL, date, montant HT (négatif pour un avoir), statut, contrôle fait dans l'application ;
//  - actions, SEULEMENT sur une pièce pointable (BL, avoir d'un retour ; jamais « manquants à la réception ») :
//    pointer / dépointer (PUT /pointage-bl/pointer/{BL|RETOUR}/{id}?pointe=), N° de séquence d'un BL
//    (PUT …/sequence/{id}?valeur=, 20 caractères), référence d'avoir d'un retour (PUT …/avoir/{id}?valeur=,
//    40 caractères) — mêmes contrôles que le serveur AVANT envoi, valeur inchangée = rien d'envoyé ;
//  - mise à jour OPTIMISTE (la pièce change tout de suite), ANNULÉE si le serveur refuse ou ne répond pas, avec la
//    cause en message rouge ; une seule écriture à la fois par pièce (anti double envoi).
// 3.9.0 (question du pharmacien « comment valider une recherche sans grossiste ? ») : vérifié dans le serveur
// (PointageBLRessource.criteres), une recherche sur TOUS les grossistes est impossible (« Choisissez un grossiste ou
// un groupe de grossistes. ») ; l'écran l'explique et reprend le DERNIER grossiste (ou groupe) utilisé
// (DernierCriterePointage).
// 3.10.0 (décision du pharmacien : « le montant par grossiste ou par groupe de grossistes », jamais « tous les
// grossistes ») : choix explicite « Par grossiste » / « Par groupe de grossistes » (une seule liste à la fois ; un
// groupe envoie `groupe=<id>`, lu par PointageBLRessource.criteres → grossistes du groupe) ; montant du grossiste ou
// du groupe mis en avant ; pour un groupe, montant de chaque grossiste du groupe quand le serveur le permet
// (PointageBl.detailGroupe ; demande : regroupé dans prestige_vente_app/docs/serveur/TRANSMISSION_SERVEUR_2026-10-15.md (§ 3)). Aucune requête « tous les
// grossistes » (FiltresPointage.complet refuse aussi l'identifiant « ALL »).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/commun_lot2.dart';
import '../modules/periode.dart';
import '../vague1/profil_acces.dart';
import '../vague2/commun_vague2.dart' show ChoixListe, GrilleChiffres;
import 'donnees_vague3.dart';

class PointageBlScreen extends StatefulWidget {
  final DateTime Function() maintenant;

  /// Critères de départ (tests, captures) ; sinon aucun grossiste choisi, « Ce mois », toutes les pièces.
  final String grossisteInitial;
  const PointageBlScreen({super.key, this.maintenant = DateTime.now, this.grossisteInitial = ''});

  @override
  State<PointageBlScreen> createState() => _PointageBlScreenState();
}

class _PointageBlScreenState extends State<PointageBlScreen> with ChargementSuivi<PointageBlScreen, PointageBl> {
  late Periode _periode = Periode.rapide(PeriodeRapide.ceMois, widget.maintenant());
  late FiltresPointage _filtres =
      FiltresPointage(grossiste: widget.grossisteInitial, debut: _periode.debut, fin: _periode.fin);
  List<OptionListe>? _grossistes;
  List<OptionListe>? _groupes;
  Object? _erreurGrossistes;
  Object? _erreurGroupes;

  /// Pièces dont une écriture est en route (clé « BL:id ») : un second appui n'envoie rien.
  final _enCours = <String>{};

  /// Le grossiste (ou groupe) affiché vient du dernier choix mémorisé (3.9.0).
  bool _repris = false;

  /// Recherche par groupe de grossistes (3.10.0) ; sinon par grossiste.
  bool _parGroupe = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!_filtres.complet) {
        // Dernier grossiste (ou groupe) utilisé, repris avant le chargement des listes.
        final dernier = await DernierCriterePointage.lire();
        if (!mounted) return;
        if (dernier != null && !_filtres.complet) {
          setState(() {
            _filtres = _filtres.copie(grossiste: dernier.$1, groupe: dernier.$2);
            _parGroupe = _filtres.parGroupe;
            _repris = true;
          });
        }
      }
      if (_repris) {
        // Choix repris : listes d'abord (un grossiste disparu est oublié sans requête), puis les pièces.
        await _chargerListes();
        if (mounted && _filtres.complet) _charger();
        return;
      }
      _chargerListes();
      if (_filtres.complet) _charger();
    });
  }

  /// Le choix repris n'existe plus dans la liste (grossiste supprimé…) : il est oublié, rien n'est affiché.
  void _verifierRepris() {
    if (!_repris) return;
    final inconnu = (_filtres.grossiste.isNotEmpty && _grossistes != null && !_grossistes!.any((o) => o.id == _filtres.grossiste)) ||
        (_filtres.grossiste.isEmpty && _filtres.groupe.isNotEmpty && _groupes != null && !_groupes!.any((o) => o.id == _filtres.groupe));
    if (!inconnu) return;
    DernierCriterePointage.oublier();
    setState(() {
      _repris = false;
      _filtres = _filtres.copie(grossiste: '', groupe: '');
    });
    abandonner();
  }

  Future<void> _chargerListes() async {
    setState(() {
      _erreurGrossistes = null;
      _erreurGroupes = null;
    });
    try {
      final g = await ApiPointage.grossistes(context);
      if (mounted) setState(() => _grossistes = g);
      if (mounted) _verifierRepris();
    } catch (e) {
      if (mounted) setState(() => _erreurGrossistes = e);
    }
    if (!mounted) return;
    try {
      final g = await ApiPointage.groupes(context);
      if (mounted) setState(() => _groupes = g);
      if (mounted) _verifierRepris();
    } catch (e) {
      if (mounted) setState(() => _erreurGroupes = e);
    }
  }

  void _charger() {
    if (!_filtres.complet) {
      abandonner();
      return;
    }
    final f = _filtres;
    DernierCriterePointage.enregistrer(f);
    charger(() => ApiPointage.liste(context, f));
  }

  /// « Par grossiste » / « Par groupe de grossistes » : l'autre choix est effacé, rien n'est demandé tant que la liste
  /// n'a pas de valeur.
  void _changerMode(bool parGroupe) {
    if (parGroupe == _parGroupe) return;
    setState(() {
      _parGroupe = parGroupe;
      _repris = false;
      _filtres = _filtres.copie(grossiste: '', groupe: '');
    });
    abandonner();
  }

  void _changer(FiltresPointage f) {
    setState(() {
      if (f.grossiste != _filtres.grossiste || f.groupe != _filtres.groupe) _repris = false;
      _filtres = f;
    });
    _charger();
  }

  // --- Écritures (optimistes, annulées en cas d'échec) ---

  /// Remplace la pièce [cle] par [nouvelle] dans les données affichées ; [delta] : pointées +1 / −1.
  void _remplacer(String cle, PieceBl nouvelle, {int delta = 0}) {
    final d = donnees;
    if (d == null) return;
    setState(() => donnees = d.avec([for (final p in d.pieces) p.cle == cle ? nouvelle : p], deltaPointes: delta));
  }

  Future<void> _ecrire(PieceBl avant, PieceBl apres, int delta, Future<void> Function() envoi, String reussite) async {
    if (_enCours.contains(avant.cle)) return;
    _enCours.add(avant.cle);
    _remplacer(avant.cle, apres, delta: delta);
    try {
      await envoi();
      if (mounted) messageResultat(context, reussite);
    } catch (e) {
      if (!mounted) return;
      // Annulation : la pièce revient à son état d'avant (sans toucher aux autres pièces).
      _remplacer(avant.cle, avant, delta: -delta);
      final d = DiagnosticErreur.de(e);
      messageResultat(context, 'Non enregistré : ${d.cause == CauseErreur.autre ? d.message : '${d.titre}. ${d.message}'}', echec: true);
    } finally {
      _enCours.remove(avant.cle);
      if (mounted) setState(() {});
    }
  }

  void _pointer(PieceBl p) {
    if (!p.pointable || _enCours.contains(p.cle)) return;
    final pointe = !p.pointe;
    final qui = ProfilAcces.utilisateur.value;
    final apres = p.copie(
      pointe: pointe,
      pointeLe: pointe ? horodatage(widget.maintenant()) : '',
      pointePar: pointe ? (qui == null ? '' : '${qui.firstName} ${qui.lastName}'.trim()) : '',
    );
    _ecrire(p, apres, pointe ? 1 : -1, () => ApiPointage.pointer(context, p, pointe),
        pointe ? 'Pièce pointée : ${p.libelleType} ${p.reference}' : 'Pointage retiré : ${p.libelleType} ${p.reference}');
  }

  Future<void> _saisir(PieceBl p, {required bool sequence}) async {
    if (_enCours.contains(p.cle)) return;
    final avant = sequence ? p.sequence : p.referenceAvoir;
    final valeur = await showDialog<String>(context: context, builder: (_) => _DialogueSaisie(sequence: sequence, initiale: avant));
    if (valeur == null || !mounted) return;
    final propre = ControlePointage.nettoyer(valeur);
    if (propre == avant.trim()) return; // inchangé : rien n'est envoyé (comme le web)
    final apres = sequence ? p.copie(sequence: propre) : p.copie(referenceAvoir: propre);
    await _ecrire(
      p,
      apres,
      0,
      () => sequence ? ApiPointage.sequence(context, p, propre) : ApiPointage.referenceAvoir(context, p, propre),
      sequence ? 'N° de séquence enregistré : ${propre.isEmpty ? '(effacé)' : propre}' : 'Référence d\'avoir enregistrée : ${propre.isEmpty ? '(effacée)' : propre}',
    );
  }

  // --- Affichage ---

  @override
  Widget build(BuildContext context) {
    final d = donnees;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pointage BL'),
        actions: [
          IconButton(
            key: const Key('pointage_actualiser'),
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: enCours || !_filtres.complet ? null : _charger,
          ),
        ],
      ),
      body: ListView(key: const Key('defilement_pointage'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        _criteres(),
        const SizedBox(height: 8),
        SelecteurPeriode(
          periode: _periode,
          maintenant: widget.maintenant,
          controle: ControlePointage.erreurPeriode,
          onChanged: (p) {
            final e = ControlePointage.erreurPeriode(p.debut, p.fin, widget.maintenant());
            if (e != null) {
              messageResultat(context, e, echec: true);
              return;
            }
            setState(() => _periode = p);
            _changer(_filtres.copie(debut: p.debut, fin: p.fin));
          },
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: PucesChoix<EtatPointage>(
            choix: [for (final e in EtatPointage.values) (e, e.libelle)],
            valeur: _filtres.etat,
            cle: (e, _) => Key('etat_pointage_${e.name}'),
            onChanged: (e) => _changer(_filtres.copie(etat: e)),
          ),
        ),
        const SizedBox(height: 8),
        if (!_filtres.complet)
          const _PourquoiGrossiste()
        else ...[
          if (enCours) const EtatChargement(texte: 'Chargement des pièces…'),
          if (erreur != null && !enCours) EtatErreur(erreur: erreur!, reessayer: _charger),
          if (d != null && !enCours) ..._resultats(d),
        ],
      ]),
    );
  }

  Widget _criteres() {
    final listesKo = _erreurGrossistes != null || _erreurGroupes != null;
    return CarteSection(titre: 'Grossiste ou groupe', icone: Icons.local_shipping_outlined, enfants: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: PucesChoix<bool>(
          choix: const [(false, 'Par grossiste'), (true, 'Par groupe de grossistes')],
          valeur: _parGroupe,
          cle: (v, _) => Key(v ? 'pointage_mode_groupe' : 'pointage_mode_grossiste'),
          onChanged: _changerMode,
        ),
      ),
      const SizedBox(height: 10),
      if (!_parGroupe)
        ChoixListe(
          key: const Key('pointage_grossiste'),
          libelle: 'Grossiste',
          icone: Icons.store_outlined,
          options: _grossistes,
          erreur: _erreurGrossistes,
          valeur: _filtres.grossiste,
          tous: 'Choisir un grossiste',
          onChanged: (v) => _changer(_filtres.copie(grossiste: v, groupe: '')),
        )
      else
        ChoixListe(
          key: const Key('pointage_groupe'),
          libelle: 'Groupe de grossistes',
          icone: Icons.groups_2_outlined,
          options: _groupes,
          erreur: _erreurGroupes,
          valeur: _filtres.groupe,
          tous: 'Choisir un groupe',
          onChanged: (v) => _changer(_filtres.copie(groupe: v, grossiste: '')),
        ),
      if (_repris && _filtres.complet)
        const Padding(
          padding: EdgeInsets.only(top: 6, left: 4),
          child: Text('Dernier choix utilisé, repris automatiquement.',
              key: Key('pointage_dernier_choix'), style: TextStyle(color: Charte.gris, fontSize: 13)),
        ),
      if (listesKo)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('pointage_listes_reessayer'),
            onPressed: _chargerListes,
            icon: const Icon(Icons.refresh),
            label: const Text('Recharger les listes'),
          ),
        ),
    ]);
  }

  /// Libellé du grossiste ou du groupe choisi (identifiant à défaut).
  String _libelleChoix() {
    final groupe = _filtres.parGroupe;
    final id = groupe ? _filtres.groupe : _filtres.grossiste;
    final options = groupe ? _groupes : _grossistes;
    final o = options?.where((o) => o.id == id).firstOrNull;
    return o == null || o.libelle.isEmpty ? id : o.libelle;
  }

  /// Montant du grossiste ou du groupe (mis en avant), et pour un groupe le montant de chacun de ses grossistes.
  Widget _montant(PointageBl d) {
    final groupe = _filtres.parGroupe;
    final detail = groupe ? d.detailGroupe(toutesLesPieces: _filtres.etat == EtatPointage.tous) : null;
    return CarteSection(
      key: const Key('pointage_montant'),
      titre: groupe ? 'Montant du groupe' : 'Montant du grossiste',
      icone: Icons.payments_outlined,
      enfants: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(_libelleChoix(),
                key: const Key('pointage_montant_libelle'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Charte.encre)),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Net HT', style: TextStyle(fontSize: 12, color: Charte.gris)),
            Text(formaterMontant(d.net),
                key: const Key('pointage_montant_net'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Charte.navy)),
          ]),
        ]),
        Text('BL ${formaterMontant(d.totalBl)} · avoirs ${formaterMontant(d.totalAvoirs)} · période choisie, toutes pièces',
            style: const TextStyle(fontSize: 13, color: Charte.gris)),
        if (groupe && detail != null) ...[
          const SizedBox(height: 8),
          const Text('Par grossiste du groupe', style: TextStyle(fontSize: 13, color: Charte.gris, fontWeight: FontWeight.w700)),
          for (final m in detail.$1)
            Padding(
              key: Key('pointage_grossiste_du_groupe_${m.grossisteId}'),
              padding: const EdgeInsets.only(top: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                LigneDetail(m.libelle, formaterMontant(m.net)),
                // 3.14.1 : pointées / à pointer de chaque grossiste, quand le serveur les donne (demande 45).
                if (m.pointes != null && m.nonPointes != null)
                  Text(
                      '${formaterNombre(m.pieces)} pièce${m.pieces > 1 ? 's' : ''} · ${formaterNombre(m.pointes!)} pointée${m.pointes! > 1 ? 's' : ''}'
                      ' · ${formaterNombre(m.nonPointes!)} à pointer',
                      key: Key('pointage_compteurs_grossiste_${m.grossisteId}'),
                      style: const TextStyle(fontSize: 12.5, color: Charte.grisTexte)),
              ]),
            ),
        ] else if (groupe)
          const Padding(
            key: Key('pointage_detail_groupe_absent'),
            padding: EdgeInsets.only(top: 6),
            child: Text('Montant de chaque grossiste du groupe : pas encore fourni par ce serveur Prestige '
                '(choisissez « Par grossiste » pour le voir grossiste par grossiste).',
                style: TextStyle(fontSize: 13, color: Charte.grisTexte)),
          ),
      ],
    );
  }

  List<Widget> _resultats(PointageBl d) => [
        _montant(d),
        const SizedBox(height: 8),
        GrilleChiffres([
          ChiffreCle(libelle: 'Total BL', valeur: formaterMontant(d.totalBl), id: 'total_bl'),
          ChiffreCle(libelle: 'Avoirs', valeur: formaterMontant(d.totalAvoirs), id: 'total_avoirs'),
          ChiffreCle(libelle: 'Net HT', valeur: formaterMontant(d.net), enAvant: true, id: 'net'),
          ChiffreCle(libelle: 'Pointées', valeur: formaterNombre(d.pointes), id: 'pointees'),
          ChiffreCle(libelle: 'À pointer', valeur: formaterNombre(d.nonPointes), id: 'a_pointer'),
        ]),
        const SizedBox(height: 12),
        if (d.pieces.isEmpty)
          EtatVide(
            titre: switch (_filtres.etat) {
              EtatPointage.tous => 'Aucun BL ni avoir sur la période',
              EtatPointage.nonPointes => 'Aucune pièce à pointer',
              EtatPointage.pointes => 'Aucune pièce pointée',
            },
            icone: Icons.fact_check_outlined,
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('${d.pieces.length} pièce${d.pieces.length > 1 ? 's' : ''}',
                key: const Key('pointage_total'), style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
          ),
          // Téléphone : une colonne ; tablette (≥ 720 dp) : deux colonnes de cartes.
          LayoutBuilder(builder: (context, c) {
            final colonnes = c.maxWidth >= largeurTableau ? 2 : 1;
            final largeur = (c.maxWidth - (colonnes - 1) * 8) / colonnes;
            return Wrap(spacing: 8, children: [
              for (final p in d.pieces)
                SizedBox(
                  width: largeur,
                  child: _CartePiece(
                    key: Key('piece_${p.cle}'),
                    piece: p,
                    envoi: _enCours.contains(p.cle),
                    onPointer: () => _pointer(p),
                    onSequence: () => _saisir(p, sequence: true),
                    onAvoir: () => _saisir(p, sequence: false),
                  ),
                ),
            ]);
          }),
        ],
      ];
}

/// Sans grossiste ni groupe : pourquoi le choix est obligatoire (3.9.0, question du pharmacien).
class _PourquoiGrossiste extends StatelessWidget {
  const _PourquoiGrossiste();

  @override
  Widget build(BuildContext context) => const Column(key: Key('pointage_choisir'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EtatVide(
          titre: 'Choisissez un grossiste ou un groupe',
          texte: 'Les BL et avoirs de la période s\'afficheront ici pour être pointés.',
          icone: Icons.local_shipping_outlined,
        ),
        Encadre(
          key: Key('pointage_pourquoi'),
          avertissement: true,
          icone: Icons.info_outline,
          titre: 'Pourquoi ce choix est obligatoire',
          texte: 'Le pointage se fait par grossiste ou par groupe de grossistes, comme l\'écran « Pointage BL » du web : '
              'il se compare au relevé envoyé par chaque grossiste, et le montant se lit grossiste par grossiste ou '
              'groupe par groupe. Choisissez « Par groupe de grossistes » pour réunir plusieurs grossistes. '
              'Votre dernier choix sera repris à la prochaine ouverture.',
        ),
      ]);
}

/// Carte d'une pièce : informations, puis actions si la pièce est pointable.
class _CartePiece extends StatelessWidget {
  final PieceBl piece;
  final bool envoi;
  final VoidCallback onPointer;
  final VoidCallback onSequence;
  final VoidCallback onAvoir;
  const _CartePiece({super.key, required this.piece, required this.envoi, required this.onPointer, required this.onSequence, required this.onAvoir});

  @override
  Widget build(BuildContext context) {
    final p = piece;
    final ecart = p.controleEcarts > 0;
    final infos = <Widget>[
      Text('${p.date.isEmpty ? '—' : p.date} · ${p.statut.isEmpty ? '—' : p.statut}', style: const TextStyle(fontSize: 13, color: Charte.gris)),
      if (p.estBl || p.sequence.isNotEmpty) Text('N° séq. : ${p.sequence.isEmpty ? '—' : p.sequence}', style: const TextStyle(fontSize: 13, color: Charte.gris)),
      if (p.estRetour) Text('Réf. avoir : ${p.referenceAvoir.isEmpty ? '—' : p.referenceAvoir}', style: const TextStyle(fontSize: 13, color: Charte.gris)),
      if (p.controle.isNotEmpty)
        Text('Contrôle (appli) : ${p.controle}',
            key: Key('controle_${p.cle}'),
            style: TextStyle(fontSize: 13, color: ecart ? Charte.rougeTexte : Charte.vertTexte, fontWeight: FontWeight.w600)),
      if (p.pointe)
        Text('Pointée${p.pointeLe.isEmpty ? '' : ' le ${p.pointeLe}'}${p.pointePar.isEmpty ? '' : ' par ${p.pointePar}'}',
            style: const TextStyle(fontSize: 13, color: Charte.vertTexte, fontWeight: FontWeight.w600)),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CarteBande(
        bande: p.pointe ? Charte.vert : (p.pointable ? Charte.ambre : Charte.bordure),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.reference.isEmpty ? p.libelleType : 'N° ${p.reference}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Charte.encre)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  Etiquette(p.libelleType, ton: p.estAvoir ? Ton.ambre : Ton.bleu),
                  if (p.pointable) Etiquette(p.pointe ? 'Pointée' : 'À pointer', ton: p.pointe ? Ton.vert : Ton.gris) else const Etiquette('Non pointable', ton: Ton.gris),
                ]),
                const SizedBox(height: 2),
                ...infos,
              ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Montant HT', style: TextStyle(fontSize: 12, color: Charte.gris)),
              Text(formaterMontant(p.montantHt),
                  key: Key('montant_${p.cle}'),
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: p.montantHt < 0 ? Charte.rougeTexte : Charte.navy)),
            ]),
          ]),
          if (p.pointable) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (envoi)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, semanticsLabel: 'Envoi en cours')),
                )
              else if (p.pointe)
                OutlinedButton.icon(
                  key: Key('pointer_${p.cle}'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: onPointer,
                  icon: const Icon(Icons.undo),
                  label: const Text('Dépointer'),
                )
              else
                ElevatedButton.icon(
                  key: Key('pointer_${p.cle}'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: onPointer,
                  icon: const Icon(Icons.check),
                  label: const Text('Pointer'),
                ),
              if (p.sequenceModifiable)
                TextButton.icon(
                  key: Key('sequence_${p.cle}'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: envoi ? null : onSequence,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('N° de séquence'),
                ),
              if (p.avoirModifiable)
                TextButton.icon(
                  key: Key('avoir_${p.cle}'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: envoi ? null : onAvoir,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Réf. d\'avoir'),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Saisie du N° de séquence (BL) ou de la référence d'avoir (retour) : mêmes contrôles que le serveur, refus affiché
/// sous le champ, rien n'est renvoyé tant que la saisie est refusée.
class _DialogueSaisie extends StatefulWidget {
  final bool sequence;
  final String initiale;
  const _DialogueSaisie({required this.sequence, required this.initiale});

  @override
  State<_DialogueSaisie> createState() => _DialogueSaisieState();
}

class _DialogueSaisieState extends State<_DialogueSaisie> {
  late final _champ = TextEditingController(text: widget.initiale);
  String? _erreur;

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  String? _controler(String v) => widget.sequence ? ControlePointage.erreurSequence(v) : ControlePointage.erreurAvoir(v);

  void _valider() {
    final e = _controler(_champ.text);
    if (e != null) {
      setState(() => _erreur = e);
      return;
    }
    Navigator.of(context).pop(_champ.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.sequence ? 'N° de séquence du BL' : 'Référence de l\'avoir'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Lettres, chiffres, espace, - / . (vide : effacer).', style: TextStyle(color: Charte.gris, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
            key: const Key('saisie_pointage'),
            controller: _champ,
            autofocus: true,
            maxLength: widget.sequence ? ControlePointage.maxSequence : ControlePointage.maxAvoir,
            // Pas de coupure silencieuse : un texte trop long ou un caractère refusé est SIGNALÉ (comme le serveur).
            maxLengthEnforcement: MaxLengthEnforcement.none,
            textInputAction: TextInputAction.done,
            onChanged: (v) {
              if (_erreur != null) setState(() => _erreur = _controler(v));
            },
            onSubmitted: (_) => _valider(),
            decoration: InputDecoration(
              labelText: widget.sequence ? 'N° de séquence' : 'Référence d\'avoir',
              errorText: _erreur,
              errorMaxLines: 3,
            ),
          ),
          ]),
        ),
        actions: [
          TextButton(key: const Key('saisie_annuler'), onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          ElevatedButton(key: const Key('saisie_enregistrer'), onPressed: _valider, child: const Text('Enregistrer')),
        ],
      );
}
