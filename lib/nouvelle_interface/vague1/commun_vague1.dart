// lib/nouvelle_interface/vague1/commun_vague1.dart
// Mises en forme propres aux écrans de la vague 1. Les COMPOSANTS (sélecteur de période et contrôle des dates,
// calendrier d'une date, états chargement / vide / erreur dont « Droit manquant », puces de choix, cartes, tableau
// dense, feuille des filtres, recherche, pagination) sont ceux du lot 1 : modules/commun.dart et
// modules/periode.dart, pour le même aspect et le même comportement dans toute la nouvelle interface.
import 'package:intl/intl.dart';

/// « 14/10/2026 ».
String dateCourte(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

/// « 12,5 % » ; « — » si null.
String pourcent(double? v) => v == null ? '—' : '${v.toStringAsFixed(1).replaceAll('.', ',')} %';
