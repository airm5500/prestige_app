// lib/nouvelle_interface/vague3/rappels_vague3.dart
// Menu « Rappels traitement » (web « rappelstraitement ») : traitements habituels des clients dont le prochain achat
// arrive (piluliers à préparer). Droit P_SM_RAPPELS_HABITUDE vérifié par le serveur (refus → « Droit manquant »).
//  - onglet « Liste » : GET /rappels-habitude/liste?statut=&query=&dtStart=&dtEnd= (statut « À préparer » à
//    l'ouverture ; liste NON paginée par le serveur, 2000 lignes au plus) affichée de façon VIRTUALISÉE (seules les
//    lignes visibles sont construites) ; compteur « à préparer » (GET /rappels-habitude/compteur) ; recherche
//    (client, téléphone, produit, CIP) ; date prévue dans la feuille des filtres ;
//  - action « Marquer » : sélection multiple → Préparé / Racheté / Écarté / À préparer (« Racheté » à la main depuis la
//    3.14.0, serveur du 19/10/2026 ; serveur plus ancien : message clair), confirmation, POST /rappels-habitude/marquer?statut= {ids}, un
//    envoi par appui, puis relecture de la liste et du compteur ;
//  - onglet « Analyse » : GET /rappels-habitude/analyse (6 mois par défaut ; 3 ou 12 mois au choix).
//  - « Actualiser la liste » (3.8.0, demande du pharmacien : le serveur ne recalcule pas tout seul) : POST
//    /rappels-habitude/actualiser à la demande seulement, après confirmation (recalcul sur un an de ventes, peut être
//    long), un appel par appui (bouton remplacé par un indicateur), refus « déjà en cours » affiché, puis relecture
//    de la liste et du compteur. Aucun message n'est envoyé.
// PAS d'envoi de SMS / WhatsApp (/envoyer, /sms) : refusés avant envoi (donnees_vague3.dart). Données de santé (patient, téléphone, traitement) : affichées seulement,
// jamais journalisées ni gardées sur le disque.
import 'package:flutter/material.dart';

import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/commun_lot2.dart';
import '../vague2/commun_vague2.dart' show BarresHorizontales, GrilleChiffres, ongletsBlancs;
import 'donnees_vague3.dart';

String _pluriel(int n, String s, String p) => '$n ${n > 1 ? p : s}';

Etiquette etiquetteStatutRappel(StatutRappel? s) => switch (s) {
      StatutRappel.aPreparer => const Etiquette('À préparer', ton: Ton.ambre),
      StatutRappel.prepare => const Etiquette('Préparé', ton: Ton.vert),
      StatutRappel.ecarte => const Etiquette('Écarté', ton: Ton.gris),
      StatutRappel.achete => const Etiquette('Racheté', ton: Ton.bleu),
      null => const Etiquette('—', ton: Ton.gris),
    };

class RappelsScreen extends StatefulWidget {
  final DateTime Function() maintenant;
  final int ongletInitial;
  const RappelsScreen({super.key, this.maintenant = DateTime.now, this.ongletInitial = 0});

  @override
  State<RappelsScreen> createState() => _RappelsScreenState();
}

class _RappelsScreenState extends State<RappelsScreen> with SingleTickerProviderStateMixin, ChargementSuivi<RappelsScreen, List<Rappel>> {
  late final _onglets = TabController(length: 2, vsync: this, initialIndex: widget.ongletInitial);
  final _recherche = TextEditingController();
  FiltresRappels _filtres = const FiltresRappels();

  /// Rappels choisis (identifiants).
  final _choisis = <String>{};
  bool _envoi = false;

  int? _compteur;

  /// Actualisation (recalcul serveur) en cours : un seul appel à la fois.
  bool _actualisation = false;

  /// Fenêtre de confirmation de l'actualisation ouverte (un second appui n'en ouvre pas une autre).
  bool _confirmation = false;

  DureeAnalyseRappels _duree = DureeAnalyseRappels.sixMois;
  AnalyseRappels? _analyse;
  Object? _erreurAnalyse;
  bool _chargementAnalyse = false;
  int _generationAnalyse = 0;

  @override
  void initState() {
    super.initState();
    _onglets.addListener(() {
      if (!mounted || _onglets.indexIsChanging) return;
      setState(() {});
      if (_onglets.index == 1 && _analyse == null && !_chargementAnalyse) _chargerAnalyse();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_onglets.index == 0) {
        _charger();
        _chargerCompteur();
      } else {
        _chargerAnalyse();
      }
    });
  }

  @override
  void dispose() {
    _onglets.dispose();
    _recherche.dispose();
    super.dispose();
  }

  void _charger() {
    final f = _filtres;
    setState(_choisis.clear);
    charger(() => ApiRappels.liste(context, f, widget.maintenant()));
  }

  Future<void> _chargerCompteur() async {
    try {
      final n = await ApiRappels.compteur(context);
      if (mounted) setState(() => _compteur = n);
    } catch (_) {
      // Compteur indicatif : son échec n'empêche pas la liste (dont l'erreur, elle, est affichée).
      if (mounted) setState(() => _compteur = null);
    }
  }

  Future<void> _chargerAnalyse() async {
    final g = ++_generationAnalyse;
    final (debut, fin) = _duree.bornes(widget.maintenant());
    setState(() {
      _chargementAnalyse = true;
      _erreurAnalyse = null;
    });
    try {
      final a = await ApiRappels.analyse(context, debut, fin);
      if (!mounted || g != _generationAnalyse) return;
      setState(() {
        _analyse = a;
        _chargementAnalyse = false;
      });
    } catch (e) {
      if (!mounted || g != _generationAnalyse) return;
      setState(() {
        _erreurAnalyse = e;
        _chargementAnalyse = false;
      });
    }
  }

  void _appliquer(FiltresRappels f) {
    setState(() => _filtres = f);
    _charger();
  }

  Future<void> _ouvrirFiltres() async {
    var prevu = _filtres.prevu;
    final ok = await ouvrirFeuilleFiltres(
      context,
      titre: 'Date prévue du prochain achat',
      effacer: () => prevu = PrevuRappel.toutes,
      contenu: (ctx, majFeuille) => PucesChoix<PrevuRappel>(
        choix: [for (final p in PrevuRappel.values) (p, p.libelle)],
        valeur: prevu,
        cle: (p, _) => Key('filtre_prevu_${p.name}'),
        onChanged: (p) => majFeuille(() => prevu = p),
      ),
    );
    if (ok && mounted) _appliquer(_filtres.copie(prevu: prevu));
  }

  /// « Marquer » : confirmation, puis UN envoi (anti double appui), puis relecture.
  Future<void> _marquer(StatutRappel statut) async {
    if (_envoi) return;
    final ids = _choisis.toList();
    final e = ControleRappels.erreurSelection(ids.length);
    if (e != null) {
      messageResultat(context, e, echec: true);
      return;
    }
    setState(() => _envoi = true);
    try {
      final oui = await confirmer(
        context,
        titre: 'Marquer les rappels',
        texte: 'Marquer ${_pluriel(ids.length, 'rappel', 'rappels')} « ${statut.libelle} » ?\nAucun message n\'est envoyé au client.',
        oui: 'Oui, marquer',
      );
      if (!oui || !mounted) return;
      final n = await ApiRappels.marquer(context, ids, statut);
      if (!mounted) return;
      messageResultat(context, '${_pluriel(n, 'rappel marqué', 'rappels marqués')} « ${statut.libelle} ».');
      _charger();
      _chargerCompteur();
    } catch (e) {
      if (!mounted) return;
      final d = DiagnosticErreur.de(e);
      messageResultat(context, 'Rappels non marqués : ${d.cause == CauseErreur.autre ? d.message : '${d.titre}. ${d.message}'}', echec: true);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  /// « Actualiser la liste » : confirmation, UN appel (anti double appui), puis relecture de la liste et du compteur.
  Future<void> _actualiser() async {
    if (_actualisation || _confirmation || _envoi) return;
    _confirmation = true;
    final bool oui;
    try {
      oui = await confirmer(
        context,
        titre: 'Actualiser la liste',
        texte: 'Le serveur recalcule les rappels sur un an de ventes : cela peut prendre du temps (plusieurs minutes).\n'
            'Aucun message n\'est envoyé au client.',
        oui: 'Oui, actualiser',
      );
    } finally {
      _confirmation = false;
    }
    if (!oui || !mounted || _actualisation) return;
    setState(() => _actualisation = true);
    try {
      final r = await ApiRappels.actualiser(context);
      if (!mounted) return;
      messageResultat(context, r.message);
      _charger();
      _chargerCompteur();
    } catch (e) {
      if (!mounted) return;
      final d = DiagnosticErreur.de(e);
      final texte = switch (d.cause) {
        CauseErreur.autre => d.message,
        CauseErreur.delai => '${d.titre}. Le calcul continue peut-être sur le serveur : rechargez la liste dans quelques minutes.',
        _ => '${d.titre}. ${d.message}',
      };
      messageResultat(context, 'Liste non actualisée : $texte', echec: true);
    } finally {
      if (mounted) setState(() => _actualisation = false);
    }
  }

  Widget _boutonActualiser() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _actualisation
            ? Row(key: const Key('rappels_actualisation_en_cours'), children: [
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: const Text('Actualisation en cours… (calcul sur un an de ventes)',
                        style: TextStyle(color: Charte.encre, fontWeight: FontWeight.w600)),
                  ),
                ),
              ])
            : OutlinedButton.icon(
                key: const Key('rappels_recalculer'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _envoi ? null : _actualiser,
                icon: const Icon(Icons.sync),
                label: const Text('Actualiser la liste'),
              ),
      );

  @override
  Widget build(BuildContext context) {
    final liste = _onglets.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rappels traitement'),
        actions: [
          if (liste) BoutonFiltres(actifs: _filtres.prevu == PrevuRappel.toutes ? 0 : 1, onPressed: _ouvrirFiltres),
          IconButton(
            key: const Key('rappels_actualiser'),
            tooltip: 'Recharger',
            icon: const Icon(Icons.refresh),
            onPressed: liste
                ? (enCours || _envoi || _actualisation
                    ? null
                    : () {
                        _charger();
                        _chargerCompteur();
                      })
                : (_chargementAnalyse ? null : _chargerAnalyse),
          ),
        ],
        bottom: ongletsBlancs(_onglets, const ['Liste', 'Analyse'], key: const Key('onglets_rappels')),
      ),
      body: TabBarView(controller: _onglets, children: [_ongletListe(), _ongletAnalyse()]),
      bottomNavigationBar: liste && _choisis.isNotEmpty ? _barreMarquer() : null,
    );
  }

  Widget _barreMarquer() => Material(
        key: const Key('barre_marquer'),
        color: Charte.blanc,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${_pluriel(_choisis.length, 'rappel choisi', 'rappels choisis')} · marquer :',
                  key: const Key('rappels_choisis'), style: const TextStyle(color: Charte.encre, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              // 3.14.0 : quatre statuts (« Racheté » ajouté) sur deux rangées, lisibles sur un Sunmi de 360 dp.
              for (var r = 0; r < StatutRappel.marquables.length; r += 2) ...[
                if (r > 0) const SizedBox(height: 6),
                Row(children: [
                  for (final s in StatutRappel.marquables.skip(r).take(2)) ...[
                    if (s != StatutRappel.marquables[r]) const SizedBox(width: 8),
                    Expanded(child: _boutonMarquer(s)),
                  ],
                ]),
              ],
            ]),
          ),
        ),
      );

  Widget _boutonMarquer(StatutRappel s) {
    final cle = Key('marquer_${s.code}');
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, 48)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6)),
    );
    final action = _envoi ? null : () => _marquer(s);
    final texte = _envoi && s == StatutRappel.prepare
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, semanticsLabel: 'Envoi en cours'))
        : Text(s.libelle, textAlign: TextAlign.center);
    return s == StatutRappel.prepare
        ? ElevatedButton(key: cle, style: style, onPressed: action, child: texte)
        : OutlinedButton(key: cle, style: style, onPressed: action, child: texte);
  }

  Widget _ongletListe() {
    final l = donnees;
    final clients = l == null ? 0 : {for (final r in l) r.clientId.isEmpty ? r.client : r.clientId}.length;
    final maintenant = widget.maintenant();
    return CustomScrollView(key: const Key('defilement_rappels'), slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList.list(children: [
          _boutonActualiser(),
          if (_compteur != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.medication_outlined, color: Charte.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${_pluriel(_compteur!, 'rappel', 'rappels')} à préparer au total',
                      key: const Key('rappels_compteur'), style: const TextStyle(color: Charte.encre, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: PucesChoix<FiltreStatutRappel>(
              choix: [for (final s in FiltreStatutRappel.values) (s, s.libelle)],
              valeur: _filtres.statut,
              cle: (s, _) => Key('statut_rappel_${s.name}'),
              onChanged: (s) => _appliquer(_filtres.copie(statut: s)),
            ),
          ),
          const SizedBox(height: 6),
          ChampRecherche(
            controleur: _recherche,
            libelle: 'Rechercher',
            aide: 'Client, téléphone, produit, CIP',
            enCours: enCours && _filtres.recherche.isNotEmpty,
            onRecherche: (t) => _appliquer(_filtres.copie(recherche: t.length > ControleRappels.maxRecherche ? t.substring(0, ControleRappels.maxRecherche) : t)),
          ),
          EtiquettesFiltres(
            etiquettes: [if (_filtres.prevu != PrevuRappel.toutes) 'Prévus : ${_filtres.prevu.libelle}'],
            onRetirer: () => _appliquer(_filtres.copie(prevu: PrevuRappel.toutes)),
          ),
          const SizedBox(height: 8),
          if (enCours) const EtatChargement(texte: 'Chargement des rappels…'),
          if (erreur != null && !enCours) EtatErreur(erreur: erreur!, reessayer: _charger),
          if (l != null && !enCours && l.isEmpty)
            const EtatVide(titre: 'Aucun rappel', texte: 'Aucun rappel ne correspond au statut et aux filtres.', icone: Icons.medication_outlined),
          if (l != null && !enCours && l.isNotEmpty)
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
              Text('${_pluriel(l.length, 'produit', 'produits')}, ${_pluriel(clients, 'client', 'clients')}',
                  key: const Key('rappels_total'), style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
              TextButton(
                key: const Key('rappels_tout_choisir'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _envoi
                    ? null
                    : () => setState(() {
                          if (_choisis.length == l.length) {
                            _choisis.clear();
                          } else {
                            _choisis
                              ..clear()
                              ..addAll(l.map((r) => r.id));
                          }
                        }),
                child: Text(_choisis.length == l.length ? 'Ne rien choisir' : 'Tout choisir'),
              ),
            ]),
        ]),
      ),
      if (l != null && !enCours && l.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          // Liste virtualisée : seules les lignes visibles sont construites (jusqu'à 2000 lignes).
          sliver: SliverList.builder(
            itemCount: l.length,
            itemBuilder: (context, i) => _LigneRappel(
              key: Key('rappel_${l[i].id}'),
              rappel: l[i],
              choisi: _choisis.contains(l[i].id),
              enRetard: l[i].enRetard(maintenant),
              onChoisir: _envoi
                  ? null
                  : (v) => setState(() {
                        if (v) {
                          _choisis.add(l[i].id);
                        } else {
                          _choisis.remove(l[i].id);
                        }
                      }),
            ),
          ),
        ),
    ]);
  }

  Widget _ongletAnalyse() {
    final a = _analyse;
    return ListView(key: const Key('defilement_analyse_rappels'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      PucesChoix<DureeAnalyseRappels>(
        choix: [for (final d in DureeAnalyseRappels.values) (d, d.libelle)],
        valeur: _duree,
        cle: (d, _) => Key('duree_rappels_${d.name}'),
        onChanged: (d) {
          setState(() => _duree = d);
          _chargerAnalyse();
        },
      ),
      if (a != null && a.debut.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 2, bottom: 6),
          child: Text('Rappels prévus du ${dateIsoLisible(a.debut)} au ${dateIsoLisible(a.fin)}', style: const TextStyle(color: Charte.gris, fontSize: 13)),
        ),
      if (_chargementAnalyse) const EtatChargement(texte: 'Analyse des rappels…'),
      if (_erreurAnalyse != null && !_chargementAnalyse) EtatErreur(erreur: _erreurAnalyse!, reessayer: _chargerAnalyse),
      if (a != null && !_chargementAnalyse) ..._analyseRemplie(a),
    ]);
  }

  List<Widget> _analyseRemplie(AnalyseRappels a) {
    final t = a.total;
    if (t.total == 0) return [const EtatVide(titre: 'Aucun rappel sur la période', icone: Icons.medication_outlined)];
    String canal(String c) => switch (c) {
          'SMS' => 'SMS',
          'WHATSAPP' => 'WhatsApp',
          'SMS_WHATSAPP' => 'WhatsApp / SMS',
          'NON_RENSEIGNE' => 'Non renseigné',
          _ => c,
        };
    return [
      GrilleChiffres([
        ChiffreCle(libelle: 'Rappels', valeur: formaterNombre(t.total), id: 'rappels_total_analyse'),
        ChiffreCle(libelle: 'À préparer', valeur: formaterNombre(t.aPreparer)),
        ChiffreCle(libelle: 'Préparés', valeur: formaterNombre(t.prepares)),
        ChiffreCle(libelle: 'Écartés', valeur: formaterNombre(t.ecartes)),
        ChiffreCle(libelle: 'Rachetés', valeur: formaterNombre(t.rachetes), detail: '${t.rachetesApresEnvoi} après un rappel'),
        ChiffreCle(libelle: 'Rappels envoyés', valeur: formaterNombre(t.envoyes)),
        ChiffreCle(
            libelle: 'Efficacité', valeur: '${t.efficacite.toStringAsFixed(1).replaceAll('.', ',')} %', detail: 'rachetés après un rappel envoyé', enAvant: true, id: 'efficacite'),
      ]),
      const SizedBox(height: 12),
      if (t.canaux.isNotEmpty)
        CarteSection(titre: 'Rappels envoyés par canal', icone: Icons.forum_outlined, enfants: [
          BarresHorizontales(largeurLibelle: 110, barres: [for (final e in t.canaux.entries) (canal(e.key), e.value.toDouble(), formaterNombre(e.value))]),
        ]),
      if (a.mois.isNotEmpty)
        CarteSection(titre: 'Par mois (date prévue)', icone: Icons.calendar_month_outlined, enfants: [
          ListeOuTableau(
            nombre: a.mois.length,
            colonnes: const [
              Colonne('Mois', flex: 2),
              Colonne('Rappels', droite: true),
              Colonne('Préparés', droite: true),
              Colonne('Rachetés', droite: true),
              Colonne('Envoyés', droite: true),
              Colonne('Efficacité', droite: true),
            ],
            cellules: (i) {
              final m = a.mois[i];
              return [m.moisLisible, '${m.total}', '${m.prepares}', '${m.rachetes}', '${m.envoyes}', '${m.efficacite.toStringAsFixed(1).replaceAll('.', ',')} %'];
            },
            carte: (i) {
              final m = a.mois[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(m.moisLisible, style: const TextStyle(color: Charte.encre, fontWeight: FontWeight.bold)),
                  LigneDetail('Rappels · préparés · rachetés', '${m.total} · ${m.prepares} · ${m.rachetes}'),
                  LigneDetail('Envoyés · efficacité', '${m.envoyes} · ${m.efficacite.toStringAsFixed(1).replaceAll('.', ',')} %'),
                  if (i < a.mois.length - 1) const Divider(height: 8),
                ]),
              );
            },
          ),
        ]),
    ];
  }
}

/// Ligne d'un rappel : case à cocher (≥ 48 dp, libellée), produit, client, dates, statut.
class _LigneRappel extends StatelessWidget {
  final Rappel rappel;
  final bool choisi;
  final bool enRetard;
  final ValueChanged<bool>? onChoisir;
  const _LigneRappel({super.key, required this.rappel, required this.choisi, required this.enRetard, this.onChoisir});

  @override
  Widget build(BuildContext context) {
    final r = rappel;
    const secondaire = TextStyle(fontSize: 13, color: Charte.gris);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CarteBande(
        bande: choisi ? Charte.navy : (enRetard ? Charte.ambre : null),
        padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
        onTap: onChoisir == null ? null : () => onChoisir!(!choisi),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            label: 'Choisir ${r.produit} pour ${r.client}',
            child: Checkbox(key: Key('choisir_${r.id}'), value: choisi, onChanged: onChoisir == null ? null : (v) => onChoisir!(v ?? false)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.produit.isEmpty ? '—' : r.produit, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Charte.encre)),
                Text('${r.client.isEmpty ? '—' : r.client}${r.telephone.isEmpty ? '' : ' · ${r.telephone}'}',
                    style: const TextStyle(fontSize: 14, color: Charte.encre)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  etiquetteStatutRappel(r.statut),
                  if (enRetard) const Etiquette('En retard', ton: Ton.rouge),
                  if (r.stock <= 0) const Etiquette('Stock 0', ton: Ton.rouge),
                ]),
                const SizedBox(height: 3),
                Text('Prévu le ${dateIsoLisible(r.prevu)} · tous les ${r.frequence} j', style: secondaire),
                Text('Dernier achat ${dateIsoLisible(r.dernierAchat)} · stock ${r.stock}${r.cip.isEmpty ? '' : ' · CIP ${r.cip}'}', style: secondaire),
                if (r.envoi != null) Text('Rappel envoyé le ${horodatage(r.envoi!)}', style: secondaire),
                if (r.traitePar.isNotEmpty && r.statut != StatutRappel.aPreparer) Text('Par ${r.traitePar}', style: secondaire),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
