import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over SharedPreferences. Everything the user enters stays
/// on the device — nothing is uploaded.
class Storage {
  Storage._(this._p);
  final SharedPreferences _p;

  static Future<Storage> open() async => Storage._(await SharedPreferences.getInstance());

  String? getString(String k) => _p.getString(k);
  Future<void> setString(String k, String v) => _p.setString(k, v);
  bool getBool(String k, {bool def = false}) => _p.getBool(k) ?? def;
  Future<void> setBool(String k, bool v) => _p.setBool(k, v);

  Map<String, dynamic>? getJson(String k) {
    final s = _p.getString(k);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  List<dynamic> getJsonList(String k) {
    final s = _p.getString(k);
    if (s == null) return const [];
    try {
      return jsonDecode(s) as List<dynamic>;
    } catch (_) {
      return const [];
    }
  }

  Future<void> setJson(String k, Object v) => _p.setString(k, jsonEncode(v));

  Set<String> getSet(String k) => (_p.getStringList(k) ?? const []).toSet();
  Future<void> setSet(String k, Set<String> v) => _p.setStringList(k, v.toList());

  Future<void> clearAll() => _p.clear();
}

abstract class Keys {
  static const location = 'location';
  static const forecastCache = 'forecast_cache';
  static const forecastCacheAt = 'forecast_cache_at';
  static const checklist = 'checklist_done';
  static const contacts = 'contacts';
  static const medical = 'medical';
  static const familyPlan = 'family_plan';
  static const onboarded = 'onboarded';
}
