// lib/screens/recap_caisse_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/common_data_model.dart';
import '../models/ticket_z_model.dart';
import '../services/api_service.dart';
import '../services/journal_app.dart';

class RecapCaisseScreen extends StatefulWidget {
  const RecapCaisseScreen({super.key});

  @override
  State<RecapCaisseScreen> createState() => _RecapCaisseScreenState();
}

class _RecapCaisseScreenState extends State<RecapCaisseScreen> {
  DateTime _dtStart = DateTime.now();
  DateTime _dtEnd = DateTime.now();
  TimeOfDay _hrStart = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _hrEnd = const TimeOfDay(hour: 23, minute: 59);

  String _userId = 'ALL';
  String _description = 'ALL';

  bool _isLoading = false;
  String? _errorMessage;
  TicketZResponse? _data;
  List<CommonData> _usersList = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final api = ApiService();
      final fetchedUsers = await api.getUsers(context);
      if (mounted) {
        setState(() {
          _usersList = [
            CommonData(id: 'ALL', libelle: 'Tous les utilisateurs'),
            ...fetchedUsers
          ];
        });
      }
    } catch (e) {
      JournalApp.debug('Récap caisse, utilisateurs : ${e.runtimeType}');
      // On conserve au moins l'option ALL en cas d'erreur
      setState(() {
        _usersList = [CommonData(id: 'ALL', libelle: 'Tous les utilisateurs')];
      });
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchTicketZ() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _data = null;
    });

    try {
      final payload = {
        "description": _description,
        "dtStart": _formatDate(_dtStart),
        "dtEnd": _formatDate(_dtEnd),
        "hrStart": _formatTime(_hrStart),
        "hrEnd": _formatTime(_hrEnd),
        "userId": _userId,
      };

      final api = ApiService();
      final response = await api.fetchTicketZ(context, payload);

      if (mounted) {
        if (response != null && response['data'] != null) {
          setState(() {
            _data = TicketZResponse.fromJson(response['data']);
          });
        } else {
          // Succès mais sans données
          setState(() {
            _data = TicketZResponse(datas: [], totauxGlobaux: []);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _dtStart : _dtEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _dtStart = picked;
          if (_dtEnd.isBefore(_dtStart)) _dtEnd = _dtStart;
        } else {
          _dtEnd = picked;
          if (_dtStart.isAfter(_dtEnd)) _dtStart = _dtEnd;
        }
      });
    }
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final initialTime = isStart ? _hrStart : _hrEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _hrStart = picked;
        } else {
          _hrEnd = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Récap de caisse'),
      ),
      body: Column(
        children: [
          _buildFiltersCard(theme),
          Expanded(
            child: _buildBodyContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Ligne des Dates
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date de début', isDense: true),
                      child: Text(_formatDate(_dtStart), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date de fin', isDense: true),
                      child: Text(_formatDate(_dtEnd), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Ligne des Heures
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Heure début', isDense: true),
                      child: Text(_formatTime(_hrStart), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Heure fin', isDense: true),
                      child: Text(_formatTime(_hrEnd), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Ligne Utilisateur
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Utilisateur', isDense: true),
              value: _userId,
              isExpanded: true,
              items: _usersList.isNotEmpty
                  ? _usersList.map((u) => DropdownMenuItem(value: u.id, child: Text(u.libelle))).toList()
                  : [const DropdownMenuItem(value: 'ALL', child: Text('Tous les utilisateurs'))],
              onChanged: (val) {
                if (val != null) setState(() => _userId = val);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchTicketZ,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(_isLoading ? 'Recherche en cours...' : 'Rechercher'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 50),
              const SizedBox(height: 12),
              Text(
                "Une erreur est survenue",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700),
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    if (_data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.point_of_sale_outlined, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text("Lancez une recherche pour voir le récapitulatif", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    if (_data!.datas.isEmpty && _data!.totauxGlobaux.isEmpty) {
      return Center(
        child: Text("Aucune donnée pour cette période.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Liste par utilisateur
        ..._data!.datas.map((userTickez) => _buildUserCard(userTickez, theme)).toList(),

        const SizedBox(height: 16),
        // Totaux globaux
        if (_data!.totauxGlobaux.isNotEmpty)
          _buildGlobalTotalsCard(_data!.totauxGlobaux, theme),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUserCard(TicketZUserData userData, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(
          backgroundColor: theme.primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, color: theme.primaryColor),
        ),
        title: Text(userData.user, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                ...userData.modePaymentAmounts.map((amt) => _buildAmountRow(amt.modeLibelle, amt.montant)),
                if (userData.totaux.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(thickness: 1.5),
                  ),
                  ...userData.totaux.map((amt) => _buildAmountRow(amt.modeLibelle, amt.montant, isBold: true)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalTotalsCard(List<TicketZAmount> totaux, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.primaryColorDark,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "TOTAUX GLOBAUX",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...totaux.map((amt) {
            final isGlobalVNO = amt.modeLibelle.toUpperCase().contains('TOTAL (VNO/VO)');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    amt.modeLibelle,
                    style: TextStyle(
                      color: isGlobalVNO ? Colors.amberAccent : Colors.white70,
                      fontWeight: isGlobalVNO ? FontWeight.bold : FontWeight.normal,
                      fontSize: isGlobalVNO ? 16 : 14,
                    ),
                  ),
                  Text(
                    amt.montant,
                    style: TextStyle(
                      color: amt.montant.contains('-') ? Colors.redAccent.shade100 : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isGlobalVNO ? 18 : 15,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String libelle, String montant, {bool isBold = false}) {
    final isNegative = montant.contains('-');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            libelle,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            montant,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: isNegative ? Colors.red.shade700 : (isBold ? Colors.indigo.shade700 : Colors.black87),
              fontSize: isBold ? 15 : 14,
            ),
          ),
        ],
      ),
    );
  }
}