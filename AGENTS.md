# AGENTS.md — คู่มือส่งต่องานสำหรับ AI / นักพัฒนา

> ไฟล์นี้เขียนให้ AI ทุกตัว (Claude, ChatGPT/Codex, Gemini, Copilot, Cursor ฯลฯ) อ่านก่อนเริ่มงาน
> **ทุกครั้งที่ทำงานเสร็จ ให้อัปเดตหัวข้อ "สถานะล่าสุด" และ "บันทึกการส่งต่อ" ด้านล่าง** เพื่อให้ AI ตัวถัดไปทำต่อได้ทันที

## โปรเจกต์คืออะไร
**RODRU รอดรู้** — แอปเตรียมรับมือภัยพิบัติภาษาไทย (Flutter, Android + iOS)
- Repo: https://github.com/mengnattawitmarin/rodru
- ดาวน์โหลด APK ล่าสุด: https://github.com/mengnattawitmarin/rodru/releases/latest
- เจ้าของ: mengnattawitmarin · ภาษา UI: ไทย · ธีม: dark navy (ดู `lib/theme.dart`)
- ภาพดีไซน์ต้นแบบ: 4 หน้าจอ (หน้าหลัก, แผนที่สถานการณ์, เส้นทางไปจุดปลอดภัย, ท้องฟ้า & ธรรมชาติ)

## สถานะล่าสุด (v0.2 — 2026-10-29)
- ✅ Build ผ่าน CI, unit/widget tests ผ่าน, APK ออกที่ Releases อัตโนมัติ
- ⚠️ ยังไม่ได้ทดสอบบนมือถือจริง — รอผลจากเจ้าของ
- 5 แท็บ: หน้าหลัก · แผนที่ · เตรียมพร้อม · ท้องฟ้า · ฉัน + หน้า SOS, แจ้งเตือน, เส้นทาง, คู่มือ, เลือกพื้นที่

## โครงสร้างโค้ด
```
lib/main.dart                 entry + MainShell (bottom nav 5 แท็บ) + ShellController (สลับแท็บจากหน้าอื่น)
lib/app_state.dart            AppState (ChangeNotifier) + AppScope (InheritedNotifier) — state กลางทั้งหมด
lib/theme.dart                สี: navy, panel, panel2, blue, amber, red, green, purple
lib/models/models.dart        AppLocation, Forecast/HourPoint/DayPoint, AirQuality, Quake, SafePlace, RouteOption, RiskAlert, EmergencyContact, MedicalInfo
lib/services/api.dart         ทุก HTTP call อยู่ที่นี่ (Open-Meteo, air, marine, USGS, RainViewer, Overpass, OSRM, geocoding, Nominatim)
lib/services/storage.dart     SharedPreferences wrapper + Keys
lib/services/location_service.dart  GPS + permission (geolocator)
lib/logic/risk.dart           RiskEngine.evaluate() — กฎเตือนภัย (เกณฑ์ TMD ฝน, PCD PM2.5)
lib/logic/suncalc.dart        พอร์ต SunCalc: sunTimes, sunPosition, moonPosition, moonIllumination, moonTimes
lib/logic/format.dart         วันที่ไทย, haversine, bearing, weatherText/Icon (WMO code)
lib/data/content.dart         hazards (คู่มือ 8 ภัย), hotlines, officialSources, goBag, homePrep — ออฟไลน์
lib/pages/*.dart              home, map, route, ready, guide, sky, me (+MedicalPage, FamilyPlanPage), sos (+SignalLightPage), alerts, location_picker
lib/widgets/common.dart       Panel, InfoCard, ActionTile, Pill, SectionTitle, PageHeader, Disclaimer, callNumber, openWeb, openDirections, confirmCall, toast
test/logic_test.dart          tests: geo, suncalc, risk engine, PM bands
test/widget_test.dart         app เปิดได้แบบออฟไลน์ (MockClient)
tool/setup_platforms.sh       flutter create android/ios + patch (ไม่ commit โฟลเดอร์ android/ ios/)
tool/patch_platforms.py       ใส่ permission, ชื่อแอป, <queries>, ไอคอน, Info.plist
tool/signing/debug.keystore   คีย์ทดสอบ (ใช้บน CI เท่านั้น ให้ APK ติดตั้งทับกันได้) — ห้ามใช้ขึ้น Play Store
.github/workflows/build.yml   CI: analyze → test → build apk → Release "build-N"
```

## Packages (pubspec.yaml)
http, flutter_map ^8, latlong2, geolocator ^13, url_launcher, share_plus ^10 (ใช้ `Share.share`), shared_preferences, sensors_plus ^6. Dart SDK ≥3.6. ไม่มี state-management package (ใช้ InheritedNotifier)

## กติกาการแก้โค้ด
1. ข้อความ UI เป็นภาษาไทย; ทุกจุดที่เป็นข้อมูลประเมิน/ไม่ทางการ ต้องมี `Disclaimer(...)`
2. HTTP ใหม่ → เพิ่มใน `services/api.dart` เท่านั้น, มี timeout, จับ error แล้วแสดงข้อความไทย
3. ข้อมูลผู้ใช้เก็บในเครื่องเท่านั้น (Storage + Keys) ห้ามส่งขึ้นเซิร์ฟเวอร์โดยไม่ขอความยินยอม
4. ใช้ `withValues(alpha:)` ไม่ใช้ `withOpacity`
5. เพิ่ม permission/native config → แก้ `tool/patch_platforms.py` (เพราะ android/ ios/ ถูกสร้างใหม่ทุกครั้งบน CI)
6. เพิ่ม logic ใหม่ → เพิ่ม test ใน `test/`
7. Commit ขึ้น `main` → CI build APK ใหม่ (~8 นาที) ดูผลที่ Actions

## ส่งต่อให้ AI ที่ไม่มีสิทธิ์เข้า GitHub
`python3 tool/make_bundle.py` → ได้ `RODRU_bundle.md` ไฟล์เดียวรวมโค้ดทั้งหมด อัปโหลดเข้าแชต AI ได้เลย
เมื่อได้โค้ดกลับมา: วางไฟล์ทับตาม path แล้ว commit ขึ้น main (หรืออัปโหลดผ่านหน้าเว็บ GitHub → Add file → Upload files)

## รันบนเครื่อง
```bash
bash tool/setup_platforms.sh && flutter pub get && flutter test && flutter run
```

## งานถัดไป (เรียงตามความสำคัญ)
1. รับ feedback จากการทดสอบบนมือถือจริง แล้วแก้บั๊ก/UI
2. เชื่อมประกาศเตือนภัยทางการ (TMD / ปภ. / NDWC) — แสดงแยกจาก RiskAlert ที่แอปคำนวณ
3. Push notification ตามพื้นที่ (FCM + workmanager) — ต้องใส่ core library desugaring ใน gradle ผ่าน patch script
4. ศูนย์พักพิงที่หน่วยงานยืนยัน (ฐานข้อมูล/Google Sheet) + สถานะเปิด/เต็ม
5. ระดับน้ำ ThaiWater, รายงานถนนน้ำท่วมจากผู้ใช้
6. แผนที่ออฟไลน์, โหมดกล้อง AR ในหน้าท้องฟ้า
7. หลายภาษา (en/my/lo/km), accessibility ตัวอักษรใหญ่
8. Release signing จริง + เตรียมขึ้น Play Store / TestFlight

## บันทึกการส่งต่อ (เพิ่มรายการใหม่ไว้บนสุด)
| วันที่ | ผู้ทำ (AI/คน) | ทำอะไร | ค้าง/ข้อควรรู้ |
|---|---|---|---|
| 2026-10-29 | Claude (claude.ai) | ปรับจาก MVP ไฟล์เดียวเป็น v0.2 ทั้งระบบ + CI APK | ยังไม่ทดสอบบนเครื่องจริง; Node20 actions warning (อัปเป็น checkout@v5/setup-java@v5 ได้) |
