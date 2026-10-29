import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'logic/risk.dart';
import 'models/models.dart';
import 'services/api.dart';
import 'services/location_service.dart';
import 'services/storage.dart';

/// Central app state. Pages listen via [AppScope.of].
class AppState extends ChangeNotifier {
  AppState(this.storage, {Api? api}) : api = api ?? Api();

  final Storage storage;
  final Api api;

  AppLocation location = AppLocation.bangkok;
  Forecast? forecast;
  bool forecastFromCache = false;
  AirQuality? air;
  List<Quake> quakes = const [];
  List<RiskAlert> alerts = const [];
  bool loading = false;
  String? error;
  DateTime? lastUpdated;

  // Personal data (on-device only)
  Set<String> checklistDone = {};
  List<EmergencyContact> contacts = [];
  MedicalInfo medical = const MedicalInfo();
  Map<String, String> familyPlan = {};

  int get topLevel => alerts.isEmpty ? 0 : alerts.first.level;

  Future<void> init() async {
    final loc = storage.getJson(Keys.location);
    if (loc != null) {
      try {
        location = AppLocation.fromJson(loc);
      } catch (_) {}
    }
    final cached = storage.getString(Keys.forecastCache);
    final cachedAt = DateTime.tryParse(storage.getString(Keys.forecastCacheAt) ?? '');
    if (cached != null) {
      try {
        forecast = Forecast.fromJson(jsonDecode(cached) as Map<String, dynamic>, fetchedAt: cachedAt);
        forecastFromCache = true;
        lastUpdated = cachedAt;
      } catch (_) {}
    }
    checklistDone = storage.getSet(Keys.checklist);
    contacts = storage
        .getJsonList(Keys.contacts)
        .whereType<Map<String, dynamic>>()
        .map(EmergencyContact.fromJson)
        .toList();
    final med = storage.getJson(Keys.medical);
    if (med != null) medical = MedicalInfo.fromJson(med);
    final plan = storage.getJson(Keys.familyPlan);
    if (plan != null) familyPlan = plan.map((k, v) => MapEntry(k, '$v'));
    _recompute();
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    final lat = location.lat, lon = location.lon;
    final errors = <String>[];

    await Future.wait([
      () async {
        try {
          final raw = await api.fetchForecastRaw(lat, lon);
          forecast = Forecast.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          forecastFromCache = false;
          await storage.setString(Keys.forecastCache, raw);
          await storage.setString(Keys.forecastCacheAt, DateTime.now().toIso8601String());
        } catch (e) {
          errors.add('อากาศ');
        }
      }(),
      () async {
        try {
          air = await api.fetchAir(lat, lon);
        } catch (_) {
          errors.add('ฝุ่น');
        }
      }(),
      () async {
        try {
          quakes = await api.fetchQuakes();
        } catch (_) {
          errors.add('แผ่นดินไหว');
        }
      }(),
    ]);

    if (errors.isEmpty) {
      lastUpdated = DateTime.now();
    } else {
      error = 'โหลดข้อมูล${errors.join(', ')}ไม่สำเร็จ ตรวจสอบอินเทอร์เน็ต';
    }
    loading = false;
    _recompute();
    notifyListeners();
  }

  void _recompute() {
    alerts = RiskEngine.evaluate(forecast: forecast, air: air, quakes: quakes, location: location);
  }

  Future<void> setLocation(AppLocation loc) async {
    location = loc;
    forecast = null;
    air = null;
    await storage.setJson(Keys.location, loc.toJson());
    await storage.setString(Keys.forecastCache, '');
    notifyListeners();
    await refresh();
  }

  /// Returns an error message, or null on success.
  Future<String?> useGps() async {
    final r = await LocationService.current();
    if (r.position == null) return r.error;
    final p = r.position!;
    final name = await api.reverseGeocode(p.latitude, p.longitude) ?? 'ตำแหน่งปัจจุบัน';
    await setLocation(AppLocation(name, p.latitude, p.longitude, fromGps: true));
    return null;
  }

  // ---- checklist ----
  Future<void> toggleCheck(String id) async {
    if (!checklistDone.remove(id)) checklistDone.add(id);
    notifyListeners();
    await storage.setSet(Keys.checklist, checklistDone);
  }

  // ---- contacts ----
  Future<void> addContact(EmergencyContact c) async {
    contacts = [...contacts, c];
    notifyListeners();
    await storage.setJson(Keys.contacts, contacts.map((e) => e.toJson()).toList());
  }

  Future<void> removeContact(EmergencyContact c) async {
    contacts = contacts.where((e) => e != c).toList();
    notifyListeners();
    await storage.setJson(Keys.contacts, contacts.map((e) => e.toJson()).toList());
  }

  Future<void> saveMedical(MedicalInfo m) async {
    medical = m;
    notifyListeners();
    await storage.setJson(Keys.medical, m.toJson());
  }

  Future<void> saveFamilyPlan(Map<String, String> plan) async {
    familyPlan = plan;
    notifyListeners();
    await storage.setJson(Keys.familyPlan, plan);
  }

  Future<void> resetAll() async {
    await storage.clearAll();
    location = AppLocation.bangkok;
    checklistDone = {};
    contacts = [];
    medical = const MedicalInfo();
    familyPlan = {};
    forecast = null;
    notifyListeners();
    await refresh();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to rebuilds (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
