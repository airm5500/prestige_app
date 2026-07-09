import 'package:flutter/material.dart';
import '../models/recap_caisse_model.dart';
import '../services/api_service.dart';
import '../ui_helpers/base_screen_logic.dart';
import '../utils/date_formatter.dart';

class RecapCaisseScreen extends StatefulWidget {
  const RecapCaisseScreen({super.key});

  @override
  State<RecapCaisseScreen> createState() => _RecapCaisseScreenState();
}

class _RecapCaisseScreenState extends State<RecapCaisseScreen> with BaseScreenLogic<RecapCaisseScreen> {
  RecapData? _recapData;

  // Filtres
  DateTime _dtStart = DateTime.now();
  DateTime _dtEnd = DateTime.now();
  TimeOfDay _hrStart = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _hrEnd = const TimeOfDay(hour: 23, minute: 59);
  String _userId = 'ALL';
  final String _description = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await ApiService().fetchRecapCaisse(
        context,
        dtStart: DateFormatter.toApiFormat(_dtStart),
        dtEnd: DateFormatter.toApiFormat(_dtEnd),
        hrStart: _formatTime(_hrStart),
        hrEnd: _formatTime(_hrEnd),
        userId: _userId,
        description: _description,
      );

      if (mounted) {
        setState(() {
          if (response != null) {
            _recapData = response.data;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = "Erreur de chargement: $e");
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // --- UI Filtres (BottomSheet) ---
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Filtres de recherche', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildFilterButton(
                        label: 'Date début\n${DateFormatter.toDisplayFormat(_dtStart)}',
                        icon: Icons.calendar_today,
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: _dtStart, firstDate: DateTime(2020), lastDate: DateTime(2100));
                          if (picked != null) setModalState(() => _dtStart = picked);
                        },
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _buildFilterButton(
                        label: 'Date fin\n${DateFormatter.toDisplayFormat(_dtEnd)}',
                        icon: Icons.calendar_today,
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: _dtEnd, firstDate: DateTime(2020), lastDate: DateTime(2100));
                          if (picked != null) setModalState(() => _dtEnd = picked);
                        },
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildFilterButton(
                        label: 'Heure début\n${_formatTime(_hrStart)}',
                        icon: Icons.access_time,
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: _hrStart);
                          if (picked != null) setModalState(() => _hrStart = picked);
                        },
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _buildFilterButton(
                        label: 'Heure fin\n${_formatTime(_hrEnd)}',
                        icon: Icons.access_time,
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: _hrEnd);
                          if (picked != null) setModalState(() => _hrEnd = picked);
                        },
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _userId == 'ALL' ? '' : _userId,
                    decoration: const InputDecoration(labelText: 'Utilisateur (Laissez vide pour Tous)', border: OutlineInputBorder()),
                    onChanged: (value) => _userId = value.trim().isEmpty ? 'ALL' : value.trim(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _dtStart = DateTime.now();
                            _dtEnd = DateTime.now();
                            _hrStart = const TimeOfDay(hour: 0, minute: 0);
                            _hrEnd = const TimeOfDay(hour: 23, minute: 59);
                            _userId = 'ALL';
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _loadData();
                        },
                        child: const Text('Rechercher'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterButton({required String label, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(RecapAmount amount, {bool isBold = false}) {
    final isNegative = amount.montant.trim().startsWith('-');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(amount.modeLibelle, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Text(amount.montant, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isNegative ? Colors.red : Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Récap de caisse', style: TextStyle(fontSize: 18)),
            Text('Du ${DateFormatter.toDisplayFormat(_dtStart)} ${_formatTime(_hrStart)} au ${DateFormatter.toDisplayFormat(_dtEnd)} ${_formatTime(_hrEnd)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterSheet),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // Totaux généraux
            if (!isLoading && errorMessage == null && _recapData != null && _recapData!.totaux.isNotEmpty)
              Container(
                height: 100,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recapData!.totaux.length,
                  itemBuilder: (context, index) {
                    final total = _recapData!.totaux[index];
                    final isNegative = total.montant.trim().startsWith('-');
                    return Card(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(total.modeLibelle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(total.montant, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isNegative ? Colors.red : Theme.of(context).primaryColor)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Liste
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadData, child: const Text('Réessayer'))
              ]))
                  : _recapData == null || _recapData!.datas.isEmpty
                  ? const Center(child: Text('Aucun récap de caisse trouvé pour cette période.'))
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _recapData!.datas.length,
                itemBuilder: (context, index) {
                  final userData = _recapData!.datas[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              Text(userData.user, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(),
                          const Text('Modes de paiement', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          ...userData.modePaymentAmounts.map((a) => _buildAmountRow(a)),
                          if (userData.totaux.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text('Totaux', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            ...userData.totaux.map((t) => _buildAmountRow(t, isBold: true)),
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}