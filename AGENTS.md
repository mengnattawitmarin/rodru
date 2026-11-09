# AGENTS.md — คู่มือส่งต่องานสำหรับ AI / นักพัฒนา

> ไฟล์นี้เขียนให้ AI ทุกตัว (Claude, ChatGPT/Codex, Gemini, Copilot, Cursor ฯลฯ) อ่านก่อนเริ่มงาน
> **ทุกครั้งที่ทำงานเสร็จ ให้อัปเดตหัวข้อ "สถานะล่าสุด" และ "บันทึกการส่งต่อ" ด้านล่าง** เพื่อให้ AI ตัวถัดไปทำต่อได้ทันที

## โปรเจกต์คืออะไร
**RODRU รอดรู้** — แอปเตรียมรับมือภัยพิบัติภาษาไทย (Flutter, Android + iOS)
- Repo: https://github.com/mengnattawitmarin/rodru
- ดาวน์โหลด APK ล่าสุด: https://github.com/mengnattawitmarin/rodru/releases/latest
- เวอร์ชันเว็บ (iPhone/Safari → เพิ่มไปยังหน้าจอโฮม): https://mengnattawitmarin.github.io/rodru/ — CI job `web` build แล้ว push ไป branch `gh-pages` (ต้องเปิด Settings → Pages → Branch gh-pages ครั้งเดียว)
- เจ้าของ: mengnattawitmarin · ภาษา UI: ไทย · ธีม: dark navy (ดู `lib/theme.dart`)
- ภาพดีไซน์ต้นแบบ: 4 หน้าจอ (หน้าหลัก, แผนที่สถานการณ์, เส้นทางไปจุดปลอดภัย, ท้องฟ้า & ธรรมชาติ)

## สถานะล่าสุด (v0.3 — 2026-11-03)
- ✅ v0.2 ทดสอบบนมือถือ Android จริงแล้ว (เจ้าของ) — รายการปรับปรุงจาก feedback อยู่ใน Backlog ของโปรเจกต์ (`RODRU/BACKLOG.md` บน claude.ai)
- v0.3 ทำ Backlog #1–#8 ครบ: การ์ดสรุปอากาศสไตล์ทีวี, SOS ลอย, สมุดเบอร์ฉุกเฉิน 36 เบอร์, ระดับน้ำ ThaiWater,
  เรดาร์เคลื่อนไหว + ทิศที่ฝนกำลังไป + ชั้นลม, โหมดแผ่นดินไหว/สึนามิ (วงแรงสั่น, ShakeMap, ประวัติ 50 ปี), กล้อง AR ท้องฟ้า, Overpass สำรอง + แคช
- ⚠️ ฟีเจอร์ v0.3 ยังไม่ได้ทดสอบบนเครื่องจริง โดยเฉพาะกล้อง AR (ความแม่นยำเซนเซอร์/FOV) และ ThaiWater API
- 5 แท็บ: หน้าหลัก · แผนที่ · เตรียมพร้อม · ท้องฟ้า · ฉัน + หน้า SOS, สมุดเบอร์, แจ้งเตือน, เส้นทาง, คู่มือ, เลือกพื้นที่, AR

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
lib/logic/daily_brief.dart    DailyBriefBuilder — สร้างข้อความ "พยากรณ์ทีวี" (วันนี้/พรุ่งนี้/ต้องพก/ข้างหน้า/ไลฟ์สไตล์) โหมดจริงจังเมื่อเตือนภัยระดับ 2
lib/logic/quake_intensity.dart ประมาณ MMI จากขนาด+ระยะ, รัศมีวงแรงสั่น, สี USGS, เกณฑ์ศักยภาพสึนามิ
lib/logic/sky_projection.dart ทิศเครื่องจาก accelerometer+magnetometer และ projection ท้องฟ้า→จอ (ใช้ในกล้อง AR)
lib/data/content.dart         hazards (คู่มือ 8 ภัย), hotlines (4 เบอร์หลัก+), hotlineDirectory (36 เบอร์, ตรวจ พ.ย. 2569), officialSources, goBag, homePrep — ออฟไลน์
lib/pages/*.dart              home, map, route, ready, guide, sky, sky_ar (กล้อง AR), hotlines (สมุดเบอร์), me (+MedicalPage, FamilyPlanPage), sos (+SignalLightPage), alerts, location_picker
lib/widgets/common.dart       Panel, InfoCard, ActionTile, Pill, SectionTitle, PageHeader, Disclaimer, callNumber, openWeb, openDirections, confirmCall, toast
test/logic_test.dart          tests: geo, suncalc, risk engine, PM bands
test/brief_test.dart          tests: daily brief, ThaiWater parse, Overpass parse, hotlines, quake intensity, steering wind
test/projection_test.dart     tests: AR orientation/projection
test/widget_test.dart         app เปิดได้แบบออฟไลน์ (MockClient)
tool/setup_platforms.sh       flutter create android/ios + patch (ไม่ commit โฟลเดอร์ android/ ios/)
tool/patch_platforms.py       ใส่ permission, ชื่อแอป, <queries>, ไอคอน, Info.plist
tool/signing/debug.keystore   คีย์ทดสอบ — patch_platforms.py ตั้ง signingConfig "rodruTest" ใน build.gradle.kts ให้ release ใช้คีย์นี้ และ CI ตรวจ SHA-256 (e438ec08…) ทุก build ให้ APK ติดตั้งทับกันได้ — ห้ามใช้ขึ้น Play Store
.github/workflows/build.yml   CI: analyze → test → build apk → Release "build-N" (error ของ analyze/test/build ถูกส่งเป็น annotation อ่านได้ผ่าน API check-runs โดยไม่ต้อง login)
```

## Packages (pubspec.yaml)
http, flutter_map ^8, latlong2, geolocator ^13, url_launcher, share_plus ^10 (ใช้ `Share.share`), shared_preferences, sensors_plus ^6, camera ^0.11. Dart SDK ≥3.6. ไม่มี state-management package (ใช้ InheritedNotifier)

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

## แหล่งข้อมูลที่ใช้ (ไม่ต้องใช้ key)
Open-Meteo (forecast, air, marine, multi-point wind), USGS (FDSN query, event detail + ShakeMap `download/cont_mmi.json`),
RainViewer (`weather-maps.json` past/nowcast, zoom ≤ 7), ThaiWater `https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel_load`
(field: `waterlevel_data.data[].station.tele_station_lat/long`, `waterlevel_msl`, `situation_level` 1–5, `diff_wl_bank(_text)`),
Overpass (3 เซิร์ฟเวอร์สำรอง), OSRM demo, Nominatim, Open-Meteo geocoding.
ตัวเลือกอนาคต: TMD earthquake RSS `https://earthquake.tmd.go.th/feed/rss_tmd.xml`, ThaiWater `rain_24h`, `flood_road` (เซนเซอร์ถนน กทม.)

## งานถัดไป (เรียงตามความสำคัญ)
1. รับ feedback v0.3 บนเครื่องจริง (กล้อง AR, ระดับน้ำ, เรดาร์เคลื่อนไหว, การ์ดสรุป) แล้วแก้
2. เชื่อมประกาศเตือนภัยทางการ (TMD / ปภ. / NDWC) — แสดงแยกจาก RiskAlert ที่แอปคำนวณ
3. Push notification ตามพื้นที่ + สรุปอากาศเช้า 06:30 (FCM/workmanager + flutter_local_notifications — ต้องใส่ core library desugaring ผ่าน patch script)
4. กราฟระดับน้ำย้อนหลังรายสถานี (หา endpoint ThaiWater), ระดับน้ำคลอง กทม., น้ำในเขื่อน
5. เส้นรอยเลื่อนมีพลัง (GeoJSON จากกรมทรัพยากรธรณี) บนแผนที่
6. AR: ถ่าย/แชร์ภาพพร้อมเส้นซ้อน, gyroscope fusion ให้นิ่งขึ้น
7. ศูนย์พักพิงที่หน่วยงานยืนยัน + สถานะเปิด/เต็ม; เบอร์ระดับจังหวัด
8. แผนที่ออฟไลน์, หลายภาษา, accessibility, release signing + Play Store

## บันทึกการส่งต่อ (เพิ่มรายการใหม่ไว้บนสุด)
| วันที่ | ผู้ทำ (AI/คน) | ทำอะไร | ค้าง/ข้อควรรู้ |
|---|---|---|---|
| 2026-11-09 | Claude (claude.ai) | AR iPhone รวน: `webkitCompassHeading` แกว่งตอนถือตั้ง → เรียน offset (alpha→ทิศเหนือ) ตอนวางราบ แล้วใช้ alpha จากไจโร + ปุ่มปรับเทียบเล็งดวงอาทิตย์/จันทร์ + แก้ทิศ/FOV ด้วยมือ (จำค่าใน Storage `ar_az_offset`, `ar_vfov`) | รอผลทดสอบ iPhone; alpha ของ iOS อาจ drift ช้า ๆ — วางราบอีกครั้งเพื่อแก้ |
| 2026-11-09 | Claude (claude.ai) | AR บนเว็บ/iPhone: ใช้ `deviceorientation` + `webkitCompassHeading` ผ่าน `lib/services/web_orientation*.dart` (conditional export) และปุ่มขอสิทธิ์ (iOS ต้องกดเอง) | ยังไม่ยืนยันความแม่นยำบน iPhone จริง |
| 2026-11-05 | Claude (claude.ai) | เพิ่มเวอร์ชันเว็บ (PWA) สำหรับ iPhone ผ่าน GitHub Pages | บนเว็บ: เซนเซอร์เข็มทิศ/AR ใน Safari อาจไม่ทำงาน (iOS ต้องขอสิทธิ์ DeviceMotion), ThaiWater อาจติด CORS, ไม่มีแจ้งเตือน; แอป iOS จริงต้องมี Apple Developer + TestFlight |
| 2026-11-03 | Claude (claude.ai) | แก้ "แพ็กเกจขัดแย้ง" ตอนติดตั้งทับ: build เก่าเซ็นด้วยคีย์สุ่มของ runner → ตอนนี้เซ็นด้วยคีย์ใน repo + CI ตรวจ | ผู้ใช้ต้องถอนแอปเก่า 1 ครั้ง (build-8 ขึ้นไปติดตั้งทับกันได้) |
| 2026-11-03 | Claude (claude.ai) | v0.3: ทำ Backlog #1–#8 (ดู CHANGELOG) | ยังไม่ทดสอบบนเครื่องจริง; FOV กล้อง AR ปรับได้ในแอป; ThaiWater อาจเปลี่ยนรูปแบบข้อมูล (มี test parse) |
| 2026-10-29 | Claude (claude.ai) | ปรับจาก MVP ไฟล์เดียวเป็น v0.2 ทั้งระบบ + CI APK | ยังไม่ทดสอบบนเครื่องจริง; Node20 actions warning (อัปเป็น checkout@v5/setup-java@v5 ได้) |
