// lib/nouvelle_interface/vague1/profil_acces.dart
// Visibilité des nouveaux menus (décision du pharmacien) : ADMINISTRATEUR et PHARMACIEN seulement.
// Le profil est donné par le serveur à la connexion : POST /user/auth renvoie « xtypeuser » = « dashboard » pour
// l'administrateur (compte « 00 »), le super-administrateur, l'administrateur et le pharmacien
// (AccountResource.java), « mainmenumanager » pour les autres profils. AuthProvider le garde dans AppUser.typeUser
// et le publie ici à chaque connexion / déconnexion.
// Le serveur ne vérifie aucun droit sur les routes de la vague 1 (session seulement) : ce filtre est donc la seule
// barrière côté application ; un refus du serveur reste affiché « Droit manquant : … » (donnees_vague1.dart).
// 3.10.0 : les serveurs récents (branche du 15/10/2026) donnent aussi le RÔLE à la connexion (`role.code`) : un rôle
// PHARMACIEN, ADMINISTRATEUR, SUPER_ADMINISTRATEUR ou SYSTEME compte comme responsable (en plus de « dashboard »).
// Sa présence indique un serveur qui connaît les nouveautés livrées avec lui ([serveurRecent]) : filtre utilisateur
// de Visualisation BL, relecture d'un avis sans le marquer « lu ». Sur un serveur plus ancien, rien ne change.
import 'package:flutter/foundation.dart';

import '../../models/user_model.dart';

class ProfilAcces {
  ProfilAcces._();

  /// Valeur de « xtypeuser » des profils administrateur et pharmacien.
  static const typeResponsable = 'dashboard';

  /// Utilisateur connecté (null : personne).
  static final ValueNotifier<AppUser?> utilisateur = ValueNotifier<AppUser?>(null);

  /// Rôles responsables (`role.code` de la connexion, serveurs récents).
  static const rolesResponsables = {'PHARMACIEN', 'ADMINISTRATEUR', 'SUPER_ADMINISTRATEUR', 'SYSTEME'};

  /// Le compte peut voir les nouveaux menus (administrateur ou pharmacien).
  static bool estResponsable(AppUser? u) =>
      u != null && (u.typeUser.trim().toLowerCase() == typeResponsable || rolesResponsables.contains(u.roleCode));

  static bool get responsable => estResponsable(utilisateur.value);

  /// Le serveur connecté est récent (il a donné le rôle à la connexion) : nouveaux paramètres utilisables (userId de
  /// Visualisation BL, marquerLu=false des avis). Faux sur un serveur plus ancien ou sans connexion.
  static bool get serveurRecent => (utilisateur.value?.roleCode ?? '').isNotEmpty;
}
