# RODRU รอดรู้ — รู้ก่อน เตรียมตัวทัน

แอปเตรียมรับมือภัยพิบัติภาษาไทย (Flutter · Android / iOS) — **ต้นแบบทดลอง v0.2**

[![Build APK](https://github.com/mengnattawitmarin/rodru/actions/workflows/build.yml/badge.svg)](https://github.com/mengnattawitmarin/rodru/actions/workflows/build.yml)

## 📲 ทดลองบนมือถือ Android

1. เปิดบนมือถือ: **https://github.com/mengnattawitmarin/rodru/releases/latest**
2. แตะ `rodru.apk` เพื่อดาวน์โหลด
3. เปิดไฟล์ → อนุญาต "ติดตั้งแอปที่ไม่รู้จัก" ให้เบราว์เซอร์ → ติดตั้ง
4. ทุกครั้งที่ push โค้ดขึ้น `main` จะได้ APK ใหม่อัตโนมัติ (ติดตั้งทับของเดิมได้)

> **iPhone:** ติดตั้งไฟล์ตรงไม่ได้ ต้องใช้ Mac + Xcode (`flutter run`) หรือส่งผ่าน TestFlight (ต้องมี Apple Developer account)

## ✨ ฟังก์ชัน

| แท็บ | ฟังก์ชัน |
|---|---|
| **หน้าหลัก** | สถานะเฝ้าระวัง/เตือนภัยของพื้นที่, ควรทำอะไรตอนนี้, ปุ่ม SOS, พยากรณ์รายชั่วโมงและ 7 วัน, PM2.5, แผ่นดินไหวล่าสุด, ลิงก์ประกาศทางการ |
| **แผนที่** | เรดาร์ฝนสด, จุดแผ่นดินไหว, โรงพยาบาล/ตำรวจ/ดับเพลิง/จุดรวมพลใกล้ตัว, เส้นทาง + นำทาง Google Maps |
| **เตรียมพร้อม** | คู่มือ 8 ภัย (ก่อน/ขณะ/หลัง), เช็กลิสต์กระเป๋าฉุกเฉิน, คะแนนความพร้อม, แผนครอบครัว — ใช้ได้ออฟไลน์ |
| **ท้องฟ้า** | ขึ้น-ตกและทิศดวงอาทิตย์/ดวงจันทร์, เฟสจันทร์ + ขึ้น/แรมกี่ค่ำ, น้ำขึ้น-น้ำลง, เข็มทิศท้องฟ้า |
| **ฉัน** | พื้นที่ (GPS/ค้นหา), ผู้ติดต่อฉุกเฉิน, ข้อมูลทางการแพทย์, สายด่วน |
| **SOS** | โทร 1669/191/199/1784, ส่งตำแหน่งขอช่วย/แจ้งว่าปลอดภัย, SMS ถึงผู้ติดต่อ, ไฟสัญญาณ SOS มอร์ส |

ข้อมูลส่วนตัวทั้งหมดเก็บในเครื่อง (SharedPreferences) ไม่มีเซิร์ฟเวอร์ของแอป

## 🗂 โครงสร้างโค้ด

```
lib/
  main.dart               แอป + bottom navigation (5 แท็บ)
  app_state.dart          สถานะกลาง (ChangeNotifier + InheritedNotifier)
  theme.dart              สีและธีม
  models/models.dart      Forecast, AirQuality, Quake, SafePlace, RiskAlert, ...
  services/api.dart       เรียก API ภายนอกทั้งหมดที่เดียว
  services/storage.dart   บันทึกข้อมูลในเครื่อง
  services/location_service.dart  GPS + สิทธิ์
  logic/risk.dart         กฎคำนวณระดับเฝ้าระวัง (เกณฑ์ TMD / PCD)
  logic/suncalc.dart      คำนวณดวงอาทิตย์/ดวงจันทร์ออฟไลน์
  logic/format.dart       วันที่ไทย ระยะทาง รหัสอากาศ
  data/content.dart       คู่มือ สายด่วน เช็กลิสต์ (ออฟไลน์)
  pages/                  หน้าจอทั้งหมด
  widgets/common.dart     UI ที่ใช้ซ้ำ
test/                     unit test (risk, suncalc, geo) + widget test
tool/                     สคริปต์สร้างโฟลเดอร์ android/ios, ไอคอน, คีย์ทดสอบ
.github/workflows/        CI สร้าง APK
```

## 🛠 พัฒนาต่อบนเครื่อง

ต้องมี Flutter SDK (stable) + Android Studio (หรือ Xcode สำหรับ iOS)

```bash
git clone https://github.com/mengnattawitmarin/rodru.git
cd rodru
bash tool/setup_platforms.sh   # สร้าง android/ ios/ + ตั้งค่าสิทธิ์ ไอคอน ชื่อแอป
flutter pub get
flutter run                    # เสียบมือถือหรือเปิด emulator
flutter test
```

> โฟลเดอร์ `android/` และ `ios/` ถูกสร้างอัตโนมัติและอยู่ใน `.gitignore` — เมื่อเริ่มแก้โค้ด native (เช่น ตั้ง signing จริง, push notification) ให้ลบสองบรรทัดนั้นออกจาก `.gitignore` แล้ว commit โฟลเดอร์เข้า repo

**Codespaces / แก้บนเว็บ:** แก้ไฟล์ใน `lib/` แล้ว commit → GitHub Actions build APK ใหม่ให้เองใน ~8 นาที

## 🌐 แหล่งข้อมูล

| ข้อมูล | แหล่ง | หมายเหตุ |
|---|---|---|
| พยากรณ์อากาศ, PM2.5, ระดับน้ำทะเล | [Open-Meteo](https://open-meteo.com) | CC BY 4.0, ฟรีสำหรับไม่แสวงกำไร |
| แผ่นดินไหว | [USGS](https://earthquake.usgs.gov) | สาธารณสมบัติ |
| เรดาร์ฝน | [RainViewer](https://www.rainviewer.com/api.html) | API ฟรีจำกัด zoom ≤ 7 |
| แผนที่, สถานที่ | [OpenStreetMap](https://www.openstreetmap.org) / Overpass | ODbL; tile server มีนโยบายใช้งานจำกัด |
| เส้นทาง | [OSRM demo](https://project-osrm.org) | ใช้ทดสอบเท่านั้น |
| ค้นหาสถานที่ | Open-Meteo Geocoding, Nominatim | |

ก่อนเผยแพร่จริง: เปลี่ยน tile server / routing เป็นบริการที่มี SLA และตรวจเงื่อนไขการใช้งานทุกแหล่ง

## ⚠️ ข้อจำกัดด้านความปลอดภัย

- **ระดับเฝ้าระวังในแอปคำนวณจากพยากรณ์ ไม่ใช่ประกาศทางการ** — ยังไม่ได้เชื่อมฟีดของกรมอุตุฯ / ปภ.
- จุดปลอดภัยมาจาก OpenStreetMap ยังไม่ได้ยืนยันโดยหน่วยงาน และไม่ใช่ศูนย์พักพิงที่ประกาศ
- เส้นทางไม่รู้ว่าถนนไหนน้ำท่วมหรือปิด
- น้ำขึ้น-น้ำลงเป็นค่าจากแบบจำลอง ไม่ใช่ตารางน้ำกรมอุทกศาสตร์
- ยังไม่มีการแจ้งเตือนเบื้องหลัง (push) — ต้องเปิดแอปเพื่อดู
- เมื่อเกิดเหตุจริงให้ทำตามคำสั่งเจ้าหน้าที่และ Cell Broadcast เป็นหลัก

## 🗺 แผนขั้นต่อไป

1. เชื่อมประกาศเตือนภัยทางการ (TMD / ปภ. / Cell Broadcast) พร้อมแหล่งที่มาและเวลา
2. Push notification ตามพื้นที่ (Firebase Cloud Messaging + background fetch)
3. ฐานข้อมูลศูนย์พักพิงที่ อปท. ยืนยัน + สถานะเปิด/เต็มแบบเรียลไทม์
4. ระดับน้ำจาก ThaiWater / กรมชลประทาน และถนนน้ำท่วม (crowd report)
5. แผนที่ออฟไลน์ (เก็บ tile ล่วงหน้า) และแคชคู่มือแบบรูปภาพ
6. โหมดกล้อง AR ซ้อนทิศดวงอาทิตย์/ดวงจันทร์
7. รองรับภาษาอังกฤษ/พม่า/ลาว/กัมพูชา และ accessibility (ตัวอักษรใหญ่, screen reader)
8. ทดสอบกับผู้ใช้จริงในพื้นที่เสี่ยงก่อนเผยแพร่
