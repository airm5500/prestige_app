// lib/providers/home_settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HomeSettingsProvider with ChangeNotifier {
  List<String> _featureOrder = [];
  List<String> _disabledFeatures = [];
  static const String _orderKey = 'feature_order_key';
  static const String _disabledKey = 'disabled_features_key';

  List<String> get featureOrder => _featureOrder;
  List<String> get disabledFeatures => _disabledFeatures;

  HomeSettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _featureOrder = prefs.getStringList(_orderKey) ?? [];
    _disabledFeatures = prefs.getStringList(_disabledKey) ?? [];
    notifyListeners();
  }

  /// Ordre à enregistrer quand l'écran de personnalisation ne proposait qu'une partie des menus (nouvelle
  /// interface : sans « Fournisseurs » ni « Fiche Article », 3.9.0) : les menus de [ancien] absents de [nouveau]
  /// reprennent leur place d'avant (même rang), au lieu de disparaître de l'ordre de l'ancienne interface.
  static List<String> fusionnerOrdre(List<String> ancien, List<String> nouveau) {
    final resultat = [...nouveau];
    for (var i = 0; i < ancien.length; i++) {
      final t = ancien[i];
      if (resultat.contains(t)) continue;
      resultat.insert(i.clamp(0, resultat.length), t);
    }
    return resultat;
  }

  Future<void> saveFeatureOrder(List<String> newOrder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_orderKey, newOrder);
    _featureOrder = newOrder;
    notifyListeners();
  }

  Future<void> toggleFeature(String featureTitle, bool isEnabled) async {
    if (isEnabled) {
      _disabledFeatures.remove(featureTitle);
    } else {
      if (!_disabledFeatures.contains(featureTitle)) {
        _disabledFeatures.add(featureTitle);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_disabledKey, _disabledFeatures);
    notifyListeners();
  }
}