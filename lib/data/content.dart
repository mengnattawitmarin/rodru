import 'package:flutter/material.dart';

import '../theme.dart';

/// Offline content: works without internet.
class Hazard {
  final String id, title, subtitle;
  final IconData icon;
  final Color color;
  final List<String> before, during, after;
  const Hazard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.before,
    required this.during,
    required this.after,
  });
}

const hazards = <Hazard>[
  Hazard(
    id: 'flood',
    title: 'น้ำท่วม',
    subtitle: 'น้ำท่วมขัง น้ำป่าไหลหลาก น้ำล้นตลิ่ง',
    icon: Icons.flood,
    color: blue,
    before: [
      'รู้ระดับความสูงของบ้านเทียบกับพื้นที่รอบ ๆ และเส้นทางไปที่สูง',
      'เตรียมกระเป๋าฉุกเฉิน ยาประจำตัว เอกสารใส่ถุงกันน้ำ',
      'ย้ายของมีค่าและเครื่องใช้ไฟฟ้าขึ้นที่สูง',
      'จอดรถไว้ที่สูง เติมน้ำมันให้เต็ม ชาร์จแบตโทรศัพท์และพาวเวอร์แบงก์',
    ],
    during: [
      'อพยพทันทีเมื่อเจ้าหน้าที่สั่ง ไม่ต้องรอให้น้ำถึงบ้าน',
      'ห้ามเดินหรือขับรถฝ่าน้ำไหล น้ำลึกเพียง 15 ซม. ก็พัดคนล้มได้ 30 ซม. พัดรถได้',
      'ตัดไฟที่เบรกเกอร์หลักถ้าทำได้อย่างปลอดภัย อยู่ห่างสายไฟและเสาไฟ',
      'ระวังสัตว์มีพิษ งู ตะขาบ ที่หนีน้ำ',
    ],
    after: [
      'กลับบ้านเมื่อเจ้าหน้าที่ประกาศว่าปลอดภัยเท่านั้น',
      'ให้ช่างตรวจระบบไฟก่อนเปิดใช้',
      'ทิ้งอาหารที่สัมผัสน้ำท่วม ดื่มน้ำสะอาดหรือต้มสุก',
      'ล้างมือบ่อย ๆ ระวังโรคฉี่หนู น้ำกัดเท้า และท้องร่วง',
    ],
  ),
  Hazard(
    id: 'rain',
    title: 'ฝนหนัก/ดินถล่ม',
    subtitle: 'ฝนตกหนักต่อเนื่อง ดินโคลนถล่ม',
    icon: Icons.thunderstorm,
    color: amber,
    before: [
      'ถ้าอยู่เชิงเขา สังเกตรอยแยกบนพื้นดิน ต้นไม้เอียง น้ำในลำห้วยขุ่นข้น',
      'วางแผนเส้นทางอพยพที่ไม่ผ่านลำห้วยหรือทางน้ำ',
    ],
    during: [
      'ถ้าได้ยินเสียงดังผิดปกติจากภูเขา หรือน้ำในลำห้วยลดลงฉับพลัน ให้อพยพทันที',
      'หลีกเลี่ยงพื้นที่ต่ำ ทางลอด และสะพานข้ามลำน้ำ',
      'อยู่ในอาคารแข็งแรง ห่างจากแนวลาดชัน',
    ],
    after: [
      'อยู่ห่างพื้นที่ถล่ม อาจเกิดซ้ำได้',
      'แจ้งผู้สูญหายหรือติดค้างกับ 1784 หรือ 1669',
    ],
  ),
  Hazard(
    id: 'earthquake',
    title: 'แผ่นดินไหว',
    subtitle: 'หมอบ กำบัง ยึดจับ',
    icon: Icons.vibration,
    color: red,
    before: [
      'ยึดตู้ ชั้นวาง และของหนักติดผนัง',
      'รู้จุดที่ปลอดภัยในแต่ละห้อง (ใต้โต๊ะแข็งแรง) และทางออก',
      'นัดจุดพบกันของครอบครัวนอกอาคาร',
    ],
    during: [
      'หมอบลง ใช้โต๊ะแข็งแรงกำบังศีรษะ ยึดจับขาโต๊ะจนกว่าจะหยุดสั่น',
      'อยู่ห่างกระจก หน้าต่าง และสิ่งของที่อาจหล่น',
      'ห้ามใช้ลิฟต์ ห้ามวิ่งออกระหว่างสั่น',
      'ถ้าอยู่กลางแจ้ง ไปที่โล่ง ห่างอาคาร ป้าย และสายไฟ',
      'ถ้าอยู่ในรถ จอดในที่โล่ง อยู่ในรถจนหยุดสั่น',
    ],
    after: [
      'ออกจากอาคารทางบันไดหากอาคารเสียหาย ระวังอาฟเตอร์ช็อก',
      'ตรวจแก๊สรั่ว (ได้กลิ่น) ปิดวาล์ว ห้ามจุดไฟ',
      'ถ้าอยู่ชายฝั่งและสั่นแรงหรือนาน ให้ขึ้นที่สูงทันที (เสี่ยงสึนามิ)',
    ],
  ),
  Hazard(
    id: 'tsunami',
    title: 'สึนามิ',
    subtitle: 'ชายฝั่งอันดามันและอ่าวไทย',
    icon: Icons.waves,
    color: blue,
    before: [
      'รู้เส้นทางอพยพและป้ายหนีสึนามิในพื้นที่ชายฝั่ง',
      'รู้จุดที่สูงหรืออาคารสูงแข็งแรง (ชั้น 4 ขึ้นไป) ใกล้ที่พัก',
    ],
    during: [
      'แผ่นดินไหวแรง/นาน น้ำทะเลลดลงผิดปกติ หรือได้ยินเสียงคำราม → หนีขึ้นที่สูงทันที ไม่ต้องรอประกาศ',
      'ไปให้ไกลจากชายฝั่งหรือสูงอย่างน้อย 10 เมตร',
      'ห้ามลงไปดูคลื่นหรือเก็บของบนชายหาด',
    ],
    after: [
      'คลื่นอาจมาหลายระลอก อย่ากลับจนกว่าจะประกาศยกเลิก',
      'อยู่ห่างอาคารที่เสียหายและน้ำที่มีเศษซาก',
    ],
  ),
  Hazard(
    id: 'storm',
    title: 'พายุ/ฟ้าผ่า',
    subtitle: 'พายุฤดูร้อน พายุโซนร้อน ลมกระโชก',
    icon: Icons.air,
    color: amber,
    before: [
      'ตัดกิ่งไม้ใกล้บ้าน ผูกยึดหลังคาและสิ่งของนอกบ้าน',
      'ชาร์จโทรศัพท์ เตรียมไฟฉายและวิทยุ',
    ],
    during: [
      'อยู่ในอาคารแข็งแรงหรือรถที่ปิดกระจก',
      'อยู่ห่างต้นไม้ใหญ่ เสาไฟ ป้ายโฆษณา และหลังคาสังกะสี',
      'งดใช้โทรศัพท์บ้านแบบมีสายและถอดปลั๊กเครื่องใช้ไฟฟ้า',
      'ถ้าติดอยู่กลางแจ้งเมื่อฟ้าผ่า ให้นั่งยอง ๆ เท้าชิด ก้มศีรษะ อย่านอนราบ',
    ],
    after: [
      'ระวังสายไฟขาดและต้นไม้ล้ม แจ้งการไฟฟ้า',
      'ตรวจความเสียหายของหลังคาก่อนฝนรอบถัดไป',
    ],
  ),
  Hazard(
    id: 'fire',
    title: 'ไฟป่า/ไฟไหม้',
    subtitle: 'ไฟป่า หมอกควัน ไฟไหม้อาคาร',
    icon: Icons.local_fire_department,
    color: red,
    before: [
      'กำจัดเชื้อเพลิงแห้งรอบบ้าน ไม่เผาในที่โล่ง',
      'รู้ทางหนีไฟอย่างน้อย 2 ทาง ติดเครื่องตรวจจับควัน',
    ],
    during: [
      'ไฟไหม้อาคาร: ก้มต่ำ คลานใต้ควัน คลำประตูก่อนเปิด ถ้าร้อนอย่าเปิด',
      'ห้ามใช้ลิฟต์ โทร 199',
      'ไฟป่า: ทำตามคำสั่งอพยพ เคลื่อนที่ทวนลมออกจากแนวไฟ',
    ],
    after: [
      'อย่ากลับเข้าพื้นที่จนกว่าจะดับสนิท',
      'สวมหน้ากาก N95 เมื่อทำความสะอาดเขม่า',
    ],
  ),
  Hazard(
    id: 'pm25',
    title: 'ฝุ่น PM2.5',
    subtitle: 'หมอกควันและฝุ่นละอองขนาดเล็ก',
    icon: Icons.masks,
    color: purple,
    before: [
      'เตรียมหน้ากาก N95 และเครื่องฟอกอากาศ/ห้องปลอดฝุ่น',
      'ตรวจค่าฝุ่นก่อนออกนอกบ้าน',
    ],
    during: [
      'เกิน 37.5 µg/m³: ลดกิจกรรมกลางแจ้ง โดยเฉพาะเด็ก ผู้สูงอายุ คนมีโรคหัวใจ/ปอด',
      'เกิน 75 µg/m³: งดกิจกรรมกลางแจ้ง ปิดหน้าต่าง สวม N95',
      'ไอ แน่นหน้าอก หายใจลำบาก → พบแพทย์',
    ],
    after: [
      'ทำความสะอาดบ้านด้วยผ้าชุบน้ำแทนการกวาด',
    ],
  ),
  Hazard(
    id: 'heat',
    title: 'อากาศร้อนจัด',
    subtitle: 'ฮีทสโตรก ภาวะขาดน้ำ',
    icon: Icons.thermostat,
    color: Color(0xFFFF9F43),
    before: [
      'วางแผนกิจกรรมกลางแจ้งช่วงเช้าหรือเย็น',
      'ดูแลผู้สูงอายุ เด็ก และสัตว์เลี้ยงเป็นพิเศษ',
    ],
    during: [
      'ดื่มน้ำบ่อย ๆ แม้ไม่กระหาย เลี่ยงแอลกอฮอล์',
      'สัญญาณฮีทสโตรก: ตัวร้อนจัด สับสน หมดสติ ไม่มีเหงื่อ → โทร 1669',
      'ปฐมพยาบาล: พาเข้าที่ร่ม คลายเสื้อผ้า เช็ดตัวด้วยน้ำเย็น',
    ],
    after: [
      'พักผ่อนและดื่มน้ำเกลือแร่หากเสียเหงื่อมาก',
    ],
  ),
];

Hazard? hazardById(String id) {
  for (final h in hazards) {
    if (h.id == id) return h;
  }
  return null;
}

class Hotline {
  final String number, name, desc;
  final IconData icon;
  final Color color;
  final String category;
  const Hotline(this.number, this.name, this.desc, this.icon, this.color, {this.category = 'ฉุกเฉินหลัก'});
}

/// วันที่ตรวจสอบเบอร์ล่าสุด (เทียบกับข่าว/เว็บไซต์หน่วยงาน) — อัปเดตทุกครั้งที่แก้รายการ
const hotlinesVerifiedAt = 'พ.ย. 2569';

/// Four main numbers shown as big buttons on the SOS page (keep order).
const hotlines = <Hotline>[
  Hotline('1669', 'เจ็บป่วยฉุกเฉิน', 'สถาบันการแพทย์ฉุกเฉินแห่งชาติ (ทั่วประเทศ)', Icons.medical_services, red),
  Hotline('191', 'เหตุด่วนเหตุร้าย', 'ตำรวจ', Icons.local_police, blue),
  Hotline('199', 'ดับเพลิง', 'แจ้งไฟไหม้ สัตว์เข้าบ้าน', Icons.fire_truck, Color(0xFFFF9F43)),
  Hotline('1784', 'สายด่วนนิรภัย ปภ.', 'กรมป้องกันและบรรเทาสาธารณภัย', Icons.shield, amber),
  Hotline('1182', 'กรมอุตุนิยมวิทยา', 'สอบถามสภาพอากาศ/ประกาศเตือน', Icons.cloud, Color(0xFF7FD1FF), category: 'ภัยธรรมชาติ & น้ำ'),
  Hotline('1155', 'ตำรวจท่องเที่ยว', 'เหตุร้ายที่เกี่ยวกับนักท่องเที่ยว', Icons.luggage, green, category: 'การเดินทาง & ถนน'),
  Hotline('1193', 'ตำรวจทางหลวง', 'อุบัติเหตุบนทางหลวง', Icons.add_road, purple, category: 'การเดินทาง & ถนน'),
  Hotline('1196', 'อุบัติเหตุทางน้ำ', 'ศูนย์ปลอดภัยทางน้ำ กรมเจ้าท่า', Icons.directions_boat, blue, category: 'การเดินทาง & ถนน'),
];

const _med = 'การแพทย์ & สุขภาพ';
const _rescue = 'กู้ภัย & อาสา';
const _nature = 'ภัยธรรมชาติ & น้ำ';
const _util = 'ไฟฟ้า & ประปา';
const _road = 'การเดินทาง & ถนน';
const _social = 'สังคม & อาชญากรรม';

/// Full directory (สมุดเบอร์ฉุกเฉิน). Numbers cross-checked with at least one
/// news/agency source in Nov 2026 — see AGENTS.md before editing.
const hotlineDirectory = <Hotline>[
  ...hotlines,
  // การแพทย์
  Hotline('1646', 'ศูนย์เอราวัณ กทม.', 'หน่วยแพทย์ฉุกเฉิน สำนักการแพทย์ กทม.', Icons.emergency, red, category: _med),
  Hotline('1554', 'หน่วยแพทย์กู้ชีวิต วชิรพยาบาล', 'รถพยาบาลฉุกเฉิน (กทม.)', Icons.local_hospital, red, category: _med),
  Hotline('1691', 'โรงพยาบาลตำรวจ', 'ศูนย์รับแจ้งเหตุ รพ.ตำรวจ', Icons.local_hospital, red, category: _med),
  Hotline('1367', 'ศูนย์พิษวิทยา รามาธิบดี', 'ได้รับสารพิษ กินยาเกิน ถูกงู/สัตว์มีพิษ', Icons.science, purple, category: _med),
  Hotline('1323', 'สายด่วนสุขภาพจิต', 'กรมสุขภาพจิต ปรึกษาได้ 24 ชม.', Icons.psychology, green, category: _med),
  // กู้ภัย
  Hotline('1677', 'ร่วมด้วยช่วยกัน', 'เครือข่ายอาสาสมัคร ประสานความช่วยเหลือ', Icons.volunteer_activism, amber, category: _rescue),
  Hotline('1418', 'มูลนิธิปอเต็กตึ๊ง', 'กู้ภัย (กทม.)', Icons.health_and_safety, amber, category: _rescue),
  Hotline('1137', 'จส.100', 'แจ้งเหตุด่วนบนถนน ประสานต่อ', Icons.radio, amber, category: _rescue),
  Hotline('1644', 'สวพ. FM91', 'แจ้งเหตุ/สภาพจราจร', Icons.radio, amber, category: _rescue),
  // ภัยธรรมชาติ
  Hotline('192', 'ศูนย์เตือนภัยพิบัติแห่งชาติ', 'แจ้ง/สอบถามภัยพิบัติ สึนามิ', Icons.tsunami, blue, category: _nature),
  Hotline('1460', 'กรมชลประทาน', 'สถานการณ์น้ำ เขื่อน น้ำท่วม', Icons.water, blue, category: _nature),
  Hotline('1555', 'กรุงเทพมหานคร', 'ศูนย์รับเรื่อง/ประสานเหตุฉุกเฉินใน กทม. น้ำท่วมขัง', Icons.location_city, blue, category: _nature),
  // สาธารณูปโภค
  Hotline('1130', 'การไฟฟ้านครหลวง (กฟน.)', 'ไฟดับ สายไฟขาด — กทม. นนทบุรี สมุทรปราการ', Icons.electric_bolt, amber, category: _util),
  Hotline('1129', 'การไฟฟ้าส่วนภูมิภาค (กฟภ.)', 'ไฟดับ สายไฟขาด — ต่างจังหวัด', Icons.electric_bolt, amber, category: _util),
  Hotline('1125', 'การประปานครหลวง (กปน.)', 'น้ำไม่ไหล ท่อแตก — กทม. นนทบุรี สมุทรปราการ', Icons.water_drop, blue, category: _util),
  Hotline('1662', 'การประปาส่วนภูมิภาค (กปภ.)', 'น้ำไม่ไหล ท่อแตก — ต่างจังหวัด (24 ชม.)', Icons.water_drop, blue, category: _util),
  // เดินทาง
  Hotline('1586', 'กรมทางหลวง', 'ถนนทางหลวง ขาด/ชำรุด', Icons.alt_route, purple, category: _road),
  Hotline('1146', 'กรมทางหลวงชนบท', 'ถนนในพื้นที่ต่างจังหวัด', Icons.alt_route, purple, category: _road),
  Hotline('1543', 'การทางพิเศษ (ทางด่วน)', 'อุบัติเหตุบนทางด่วน', Icons.speed, purple, category: _road),
  Hotline('1197', 'ศูนย์ควบคุมการจราจร', 'ข้อมูลจราจร ตำรวจ', Icons.traffic, purple, category: _road),
  Hotline('1356', 'ศูนย์ปลอดภัยคมนาคม', 'ประสานความปลอดภัยการขนส่ง', Icons.commute, purple, category: _road),
  Hotline('1584', 'กรมการขนส่งทางบก', 'ร้องเรียนรถสาธารณะ/แท็กซี่', Icons.local_taxi, purple, category: _road),
  Hotline('1690', 'การรถไฟแห่งประเทศไทย', 'สอบถาม/แจ้งเหตุรถไฟ', Icons.train, purple, category: _road),
  Hotline('1490', 'บขส.', 'บริษัท ขนส่ง จำกัด', Icons.directions_bus, purple, category: _road),
  // สังคม
  Hotline('1300', 'ศูนย์ช่วยเหลือสังคม (พม.)', 'คนหาย ความรุนแรง เด็ก ผู้สูงอายุ', Icons.family_restroom, green, category: _social),
  Hotline('1192', 'แจ้งรถหาย', 'ศูนย์ปราบปรามการโจรกรรมรถ', Icons.car_crash, green, category: _social),
  Hotline('1195', 'กองปราบปราม', 'แจ้งอาชญากรรมร้ายแรง', Icons.gavel, green, category: _social),
  Hotline('1441', 'ศูนย์ต่อต้านอาชญากรรมออนไลน์ (AOC)', 'โดนหลอกโอนเงิน อายัดบัญชี', Icons.phishing, green, category: _social),
];

const hotlineCategories = ['ฉุกเฉินหลัก', _med, _rescue, _nature, _util, _road, _social];

class OfficialSource {
  final String name, desc, url;
  const OfficialSource(this.name, this.desc, this.url);
}

const officialSources = <OfficialSource>[
  OfficialSource('กรมอุตุนิยมวิทยา (TMD)', 'ประกาศเตือนพายุ ฝนหนัก แผ่นดินไหว', 'https://www.tmd.go.th'),
  OfficialSource('กรมป้องกันและบรรเทาสาธารณภัย (ปภ.)', 'สถานการณ์สาธารณภัย การอพยพ', 'https://www.disaster.go.th'),
  OfficialSource('ThaiWater (สสน.)', 'ระดับน้ำ ฝน เขื่อน แบบเรียลไทม์', 'https://www.thaiwater.net'),
  OfficialSource('Air4Thai (กรมควบคุมมลพิษ)', 'คุณภาพอากาศจากสถานีตรวจวัด', 'http://air4thai.pcd.go.th'),
  OfficialSource('ศูนย์เตือนภัยพิบัติแห่งชาติ', 'เตือนภัยสึนามิและภัยพิบัติ', 'https://ndwc.disaster.go.th'),
];

class ChecklistItem {
  final String id, label, category;
  const ChecklistItem(this.id, this.label, this.category);
}

const goBag = <ChecklistItem>[
  ChecklistItem('water', 'น้ำดื่ม อย่างน้อย 3 ลิตร/คน/วัน สำหรับ 3 วัน', 'อาหาร & น้ำ'),
  ChecklistItem('food', 'อาหารแห้ง/กระป๋อง พร้อมที่เปิดกระป๋อง', 'อาหาร & น้ำ'),
  ChecklistItem('meds', 'ยาประจำตัว (สำรอง 7 วัน) และใบสั่งยา', 'สุขภาพ'),
  ChecklistItem('firstaid', 'ชุดปฐมพยาบาล ยาสามัญ', 'สุขภาพ'),
  ChecklistItem('mask', 'หน้ากาก N95 / หน้ากากอนามัย', 'สุขภาพ'),
  ChecklistItem('hygiene', 'ของใช้ส่วนตัว ผ้าอนามัย เจลล้างมือ', 'สุขภาพ'),
  ChecklistItem('torch', 'ไฟฉาย + ถ่านสำรอง', 'อุปกรณ์'),
  ChecklistItem('power', 'พาวเวอร์แบงก์ชาร์จเต็ม + สายชาร์จ', 'อุปกรณ์'),
  ChecklistItem('radio', 'วิทยุแบบใช้ถ่าน', 'อุปกรณ์'),
  ChecklistItem('whistle', 'นกหวีดขอความช่วยเหลือ', 'อุปกรณ์'),
  ChecklistItem('bags', 'ถุงกันน้ำ / ถุงดำ', 'อุปกรณ์'),
  ChecklistItem('docs', 'สำเนาบัตรประชาชน ทะเบียนบ้าน โฉนด ประกัน (ใส่ซองกันน้ำ)', 'เอกสาร & เงิน'),
  ChecklistItem('cash', 'เงินสดย่อย (ATM อาจใช้ไม่ได้)', 'เอกสาร & เงิน'),
  ChecklistItem('contacts', 'รายชื่อเบอร์ติดต่อฉุกเฉินเขียนบนกระดาษ', 'เอกสาร & เงิน'),
  ChecklistItem('clothes', 'เสื้อผ้าสำรอง เสื้อกันฝน รองเท้าบูท', 'เสื้อผ้า'),
  ChecklistItem('blanket', 'ผ้าห่ม / ผ้าห่มฉุกเฉิน', 'เสื้อผ้า'),
  ChecklistItem('kids', 'ของจำเป็นสำหรับเด็ก ผู้สูงอายุ ผู้พิการ', 'ครอบครัว'),
  ChecklistItem('pets', 'อาหารและสายจูงสัตว์เลี้ยง', 'ครอบครัว'),
];

const homePrep = <ChecklistItem>[
  ChecklistItem('plan_meet', 'นัดจุดพบกันของครอบครัว 2 แห่ง (ใกล้บ้าน/นอกพื้นที่)', 'แผนครอบครัว'),
  ChecklistItem('plan_route', 'รู้เส้นทางอพยพอย่างน้อย 2 เส้นทาง', 'แผนครอบครัว'),
  ChecklistItem('plan_breaker', 'ทุกคนรู้วิธีตัดไฟ ปิดแก๊ส ปิดน้ำ', 'แผนครอบครัว'),
  ChecklistItem('plan_drill', 'ซ้อมอพยพกับครอบครัวปีละครั้ง', 'แผนครอบครัว'),
  ChecklistItem('home_fix', 'ยึดเฟอร์นิเจอร์สูงติดผนัง', 'บ้าน'),
  ChecklistItem('home_ext', 'มีถังดับเพลิงและเครื่องตรวจจับควัน', 'บ้าน'),
];
