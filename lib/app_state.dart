import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'logic/format.dart';
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
  List<WaterStation> waterStations = const [];
  DateTime? waterUpdated;
  Set<String> pinnedHotlines = {};
  List<RiskAlert> alerts = const [];
  bool loading = false;
  String? error;
  DateTime? lastUpdated;

  // Personal data (on-device only)
  Set<String> checklistDone = {};
  List<EmergencyContact> contacts = [];
  MedicalInfo medical = const MedicalInfo();
  Map<String, String> familyPlan = {};
  List<FamilyMember> members = [];

  // Radiation (ปส. weekly report via repo data file) and admin notices
  RadiationReport? radiation;
  List<Notice> notices = const [];
  Set<String> dismissedNotices = {};

  // App mode / settings (read synchronously so the first frame is right)
  late bool onboarded = storage.getBool(Keys.onboarded);
  late bool emergencyMode = storage.getBool(Keys.emergencyMode);
  late double textScale = double.tryParse(storage.getString(Keys.textScale) ?? '') ?? 1.0;

  int get topLevel => alerts.isEmpty ? 0 : alerts.first.level;

  /// Notices for the current area that have not expired (warnings first).
  List<Notice> get activeNotices {
    final now = DateTime.now();
    final l = notices.where((n) => n.activeFor(location.name, now)).toList();
    l.sort((a, b) => b.level.compareTo(a.level));
    return l;
  }

  /// Active notices the user has not dismissed (level-2 cannot be dismissed).
  List<Notice> get visibleNotices =>
      activeNotices.where((n) => n.level >= 2 || !dismissedNotices.contains(n.id)).toList();

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
    pinnedHotlines = storage.getSet(Keys.pinnedHotlines);
    contacts = storage
        .getJsonList(Keys.contacts)
        .whereType<Map<String, dynamic>>()
        .map(EmergencyContact.fromJson)
        .toList();
    final med = storage.getJson(Keys.medical);
    if (med != null) medical = MedicalInfo.fromJson(med);
    members = storage.getJsonList(Keys.members).whereType<Map<String, dynamic>>().map(FamilyMember.fromJson).toList();
    final plan = storage.getJson(Keys.familyPlan);
    if (plan != null) familyPlan = plan.map((k, v) => MapEntry(k, '$v'));
    dismissedNotices = storage.getSet(Keys.dismissedNotices);
    _loadCaches();
    _recompute();
    notifyListeners();
    unawaited(refresh());
  }

  /// Last good copies of every feed so the app is useful offline (C3).
  void _loadCaches() {
    final a = storage.getJson(Keys.cacheAir);
    if (a != null) air = AirQuality.fromJson(a);
    quakes = storage.getJsonList(Keys.cacheQuakes).whereType<Map<String, dynamic>>().map(Quake.fromJson).whereType<Quake>().toList();
    waterStations =
        storage.getJsonList(Keys.cacheWater).whereType<Map<String, dynamic>>().map(WaterStation.fromJson).whereType<WaterStation>().toList();
    final r = storage.getJson(Keys.cacheRadiation);
    if (r != null) {
      try {
        radiation = RadiationReport.fromJson(r);
      } catch (_) {}
    }
    notices = storage.getJsonList(Keys.cacheNotices).whereType<Map<String, dynamic>>().map(Notice.fromJson).whereType<Notice>().toList();
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
          await storage.setJson(Keys.cacheAir, air!.toJson());
        } catch (_) {
          errors.add('ฝุ่น');
        }
      }(),
      () async {
        try {
          quakes = await api.fetchQuakes();
          await storage.setJson(Keys.cacheQuakes, quakes.map((q) => q.toJson()).toList());
        } catch (_) {
          errors.add('แผ่นดินไหว');
        }
      }(),
      () async {
        // ~800 stations nationwide; refresh at most every 20 minutes.
        if (waterUpdated != null && DateTime.now().difference(waterUpdated!) < const Duration(minutes: 20)) return;
        if (emergencyMode) return; // save data/battery in emergency mode
        try {
          waterStations = await api.fetchWaterLevels();
          waterUpdated = DateTime.now();
          await storage.setJson(Keys.cacheWater, waterStations.map((w) => w.toJson()).toList());
        } catch (_) {
          // Not fatal: the water layer shows its own error.
        }
      }(),
      () async {
        try {
          notices = await api.fetchNotices();
          await storage.setJson(Keys.cacheNotices, [
            for (final n in notices)
              {
                'id': n.id,
                'title': n.title,
                'body': n.body,
                'level': n.level,
                'link': n.link,
                'expires': n.expires?.toIso8601String(),
                'areas': n.areas,
              }
          ]);
        } catch (_) {}
      }(),
      () async {
        if (emergencyMode) return;
        try {
          final raw = await api.fetchRadiationRaw();
          radiation = RadiationReport.fromJson(raw);
          await storage.setJson(Keys.cacheRadiation, raw);
        } catch (_) {}
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
    alerts = RiskEngine.evaluate(
      forecast: forecast,
      air: air,
      quakes: quakes,
      location: location,
      waterStations: waterStations,
    );
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

  /// Nearest water-level station within [maxKm], or null.
  WaterStation? nearestWaterStation({double maxKm = 30}) {
    WaterStation? best;
    var bestD = maxKm * 1000;
    for (final w in waterStations) {
      final d = haversine(location.lat, location.lon, w.lat, w.lon);
      if (d < bestD) {
        bestD = d;
        best = w;
      }
    }
    return best;
  }

  Future<void> togglePinnedHotline(String number) async {
    if (!pinnedHotlines.remove(number)) pinnedHotlines.add(number);
    notifyListeners();
    await storage.setSet(Keys.pinnedHotlines, pinnedHotlines);
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

  Future<void> saveMember(FamilyMember m) async {
    final i = members.indexWhere((e) => e.id == m.id);
    members = [...members];
    if (i >= 0) {
      members[i] = m;
    } else {
      members.add(m);
    }
    notifyListeners();
    await storage.setJson(Keys.members, members.map((e) => e.toJson()).toList());
  }

  Future<void> removeMember(FamilyMember m) async {
    members = members.where((e) => e.id != m.id).toList();
    notifyListeners();
    await storage.setJson(Keys.members, members.map((e) => e.toJson()).toList());
  }

  // ---- notices & settings ----
  Future<void> dismissNotice(Notice n) async {
    dismissedNotices = {...dismissedNotices, n.id};
    notifyListeners();
    await storage.setSet(Keys.dismissedNotices, dismissedNotices);
  }

  Future<void> setOnboarded() async {
    onboarded = true;
    notifyListeners();
    await storage.setBool(Keys.onboarded, true);
  }

  Future<void> setEmergencyMode(bool on) async {
    emergencyMode = on;
    notifyListeners();
    await storage.setBool(Keys.emergencyMode, on);
    if (!on) unawaited(refresh());
  }

  Future<void> setTextScale(double v) async {
    textScale = v;
    notifyListeners();
    await storage.setString(Keys.textScale, v.toString());
  }

  /// Refresh if data is older than [maxAge] (used on app resume / timer).
  Future<void> refreshIfStale({Duration maxAge = const Duration(minutes: 10)}) async {
    if (loading) return;
    final last = lastUpdated;
    if (last == null || DateTime.now().difference(last) > maxAge) await refresh();
  }

  Future<void> resetAll() async {
    await storage.clearAll();
    location = AppLocation.bangkok;
    checklistDone = {};
    contacts = [];
    medical = const MedicalInfo();
    familyPlan = {};
    pinnedHotlines = {};
    members = [];
    dismissedNotices = {};
    onboarded = false;
    emergencyMode = false;
    textScale = 1.0;
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
