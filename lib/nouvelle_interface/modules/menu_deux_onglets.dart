// lib/nouvelle_interface/modules/menu_deux_onglets.dart
// 3.11.0 (décision du pharmacien) : deux menus voisins réunis en UN menu à deux onglets, « Détail | Synthèse » :
//  - « Achats Fourn. » : Détail = Achats fournisseurs (achats_fournisseurs_nouveau.dart), Synthèse = État de contrôle
//    des achats (controle_achat_nouveau.dart) ;
//  - « CA Crédit » : Détail = CA Crédit (ca_credit_nouveau.dart), Synthèse = Suivi crédit (suivi_credit_nouveau.dart).
// Aucun écran n'est réécrit : chaque onglet est l'écran complet d'origine (mêmes requêtes, mêmes filtres, mêmes
// exports, même bouton retour), donc aucune fonction perdue et les mêmes droits. Le second écran n'est construit (et
// ne charge ses données) qu'au premier passage sur son onglet ; chacun garde ensuite son état (période, filtres).
// L'ancienne interface garde ses deux menus séparés.
import 'package:flutter/material.dart';

import '../charte.dart';
import 'achats_fournisseurs_nouveau.dart';
import 'ca_credit_nouveau.dart';
import 'controle_achat_nouveau.dart';
import 'suivi_credit_nouveau.dart';

/// Onglet d'un menu double : libellé, icône, écran.
class OngletMenu {
  final String libelle;
  final IconData icone;
  final Widget Function() ecran;
  const OngletMenu(this.libelle, this.icone, this.ecran);
}

/// Menu à deux onglets (barre en bas de l'écran, au-dessus de la barre système).
class MenuDeuxOnglets extends StatefulWidget {
  final List<OngletMenu> onglets;

  /// Onglet affiché à l'ouverture (0 : Détail).
  final int initial;
  const MenuDeuxOnglets({super.key, required this.onglets, this.initial = 0});

  @override
  State<MenuDeuxOnglets> createState() => _MenuDeuxOngletsState();
}

class _MenuDeuxOngletsState extends State<MenuDeuxOnglets> {
  late int _index = widget.initial.clamp(0, widget.onglets.length - 1);

  /// Écrans déjà ouverts (construits au premier passage, gardés ensuite).
  late final _ouverts = <int>{_index};

  void _choisir(int i) => setState(() {
        _index = i;
        _ouverts.add(i);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: [
          for (var i = 0; i < widget.onglets.length; i++)
            _ouverts.contains(i) ? KeyedSubtree(key: Key('onglet_menu_contenu_$i'), child: widget.onglets[i].ecran()) : const SizedBox.shrink(),
        ]),
        bottomNavigationBar: NavigationBar(
          key: const Key('onglets_menu'),
          height: 60,
          selectedIndex: _index,
          onDestinationSelected: _choisir,
          backgroundColor: Charte.blanc,
          destinations: [
            for (var i = 0; i < widget.onglets.length; i++)
              NavigationDestination(
                key: Key('onglet_menu_$i'),
                icon: Icon(widget.onglets[i].icone),
                label: widget.onglets[i].libelle,
              ),
          ],
        ),
      );
}

/// « Achats Fourn. » : Détail (achats par fournisseur) | Synthèse (état de contrôle des achats).
class AchatsFournisseursMenu extends StatelessWidget {
  final int initial;
  const AchatsFournisseursMenu({super.key, this.initial = 0});

  @override
  Widget build(BuildContext context) => MenuDeuxOnglets(initial: initial, onglets: [
        OngletMenu('Détail', Icons.receipt_long_outlined, () => const AchatsFournisseursNouveau()),
        OngletMenu('Synthèse', Icons.fact_check_outlined, () => const ControleAchatNouveau()),
      ]);
}

/// « CA Crédit » : Détail (ventes à crédit) | Synthèse (suivi des crédits, reste à payer).
class CreditsMenu extends StatelessWidget {
  final int initial;
  const CreditsMenu({super.key, this.initial = 0});

  @override
  Widget build(BuildContext context) => MenuDeuxOnglets(initial: initial, onglets: [
        OngletMenu('Détail', Icons.credit_card_outlined, () => const CaCreditNouveau()),
        OngletMenu('Synthèse', Icons.request_quote_outlined, () => const SuiviCreditNouveau()),
      ]);
}
