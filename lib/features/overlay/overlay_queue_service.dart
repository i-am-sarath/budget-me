import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';

/// Bridges the overlay isolate → main app for transaction saves.
/// The overlay writes parsed transactions here; the main app reads + clears.
class OverlayQueueService {
  static const _key = 'overlay_pending_transactions';

  static Future<void> enqueue(List<TransactionModel> txs) async {
    if (txs.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    final List<dynamic> list =
        existing != null ? jsonDecode(existing) as List : [];
    for (final tx in txs) {
      list.add(tx.toMap());
    }
    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<List<TransactionModel>> dequeueAll() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing == null || existing.isEmpty || existing == '[]') return [];
    await prefs.remove(_key);
    final List<dynamic> list = jsonDecode(existing) as List;
    return list
        .map((m) => TransactionModel.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  static Future<bool> hasPending() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key);
    return val != null && val.isNotEmpty && val != '[]';
  }
}
