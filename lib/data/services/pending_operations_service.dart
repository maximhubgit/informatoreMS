import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:informatoreMS/core/models/pending_operation.dart';

/// Servizio che gestisce la coda operazioni offline usando SharedPreferences.
class PendingOperationsService {
  static const _key = 'pending_operations';
  static final PendingOperationsService _instance =
      PendingOperationsService._internal();
  factory PendingOperationsService() => _instance;
  PendingOperationsService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<PendingOperation>> getAll() async {
    await init();
    final rawList = _prefs!.getStringList(_key) ?? [];
    return rawList
        .map((raw) {
          try {
            return PendingOperation.fromRawJson(raw);
          } catch (_) {
            return null;
          }
        })
        .whereType<PendingOperation>()
        .toList();
  }

  Future<void> enqueue(PendingOperation op) async {
    await init();
    final list = _prefs!.getStringList(_key) ?? [];
    list.add(op.toRawJson());
    await _prefs!.setStringList(_key, list);
  }

  Future<void> remove(String id) async {
    await init();
    final list = _prefs!.getStringList(_key) ?? [];
    list.removeWhere((raw) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return json['id'] == id;
      } catch (_) {
        return true;
      }
    });
    await _prefs!.setStringList(_key, list);
  }

  Future<void> clear() async {
    await init();
    await _prefs!.remove(_key);
  }
}
