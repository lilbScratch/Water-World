# Water World

แอป Flutter สำหรับจัดการสต็อก การผลิต การจัดซื้อ คำสั่งซื้อ B2B และรายงานของธุรกิจน้ำดื่ม แอปใช้ฐานข้อมูล SQLite ภายในอุปกรณ์แต่ละเครื่อง และยังไม่ซิงก์ข้อมูลระหว่างโทรศัพท์

## สิ่งที่ต้องติดตั้ง

- Flutter SDK: ใช้ **3.44.4** ในการตรวจสอบล่าสุด โดย `pubspec.yaml` กำหนดให้ใช้ Dart `^3.12.2` (ตั้งแต่เวอร์ชัน 3.12.2 ขึ้นไป ไม่ได้ล็อกไว้ที่เวอร์ชันเดียว)
- Git
- Android Studio พร้อม Android SDK และ platform tools หรือ VS Code พร้อมส่วนขยาย Flutter และ Dart
- Android emulator (เช่น Pixel 7) หรือโทรศัพท์ Android ที่เปิด USB debugging
- เครื่องพัฒนาที่ใช้ Windows, macOS หรือ Linux

ไม่ต้องติดตั้งเซิร์ฟเวอร์ฐานข้อมูลหรือแพ็กเกจ Dart แยกเอง คำสั่ง `flutter pub get` จะติดตั้งแพ็กเกจ Flutter/Dart ที่ระบุใน `pubspec.yaml` ส่วน Android Studio ใช้ติดตั้งเครื่องมือสำหรับ build แอป แอปใช้ SQLite ผ่านแพ็กเกจ Flutter

ถ้าต้องการเปิด LINE bridge แยกต่างหาก ต้องมี Python 3.9 ขึ้นไป โดยไม่ต้องติดตั้งแพ็กเกจ Python เพิ่ม ดูคู่มือ `Project/Writeup/line_bridge/README.md` ในชุดไฟล์งานที่ได้รับ

## ติดตั้งและเปิดแอปบน Android

1. ติดตั้ง Flutter และ Android Studio จาก Android Studio ให้ติดตั้ง Android SDK และยอมรับใบอนุญาตให้เรียบร้อย
2. ตรวจสอบเครื่องมือที่ติดตั้ง:

   ```powershell
   flutter doctor
   ```

   แก้ปัญหา Android toolchain ที่ `flutter doctor` แจ้งก่อนทำขั้นต่อไป
3. Clone โปรเจกต์และเข้าโฟลเดอร์:

   ```powershell
   git clone --branch feature/waterworld-work2 https://github.com/lilbScratch/Water-World.git
   cd Water-World
   ```

   branch นี้มีแอป WaterWorld รุ่น Work2 ปัจจุบัน หากต้องการรุ่นพื้นฐานที่เผยแพร่ก่อนหน้า ให้ clone branch `master` โดยระบุ `--branch master`

   หากได้รับไฟล์ ZIP ให้แตกไฟล์ แล้วเปิดโฟลเดอร์ที่มี `pubspec.yaml`
4. ดาวน์โหลดแพ็กเกจและตรวจสอบอุปกรณ์ที่เชื่อมต่อ:

   ```powershell
   flutter pub get
   flutter devices
   ```
5. เปิด Android emulator จาก Device Manager ใน Android Studio หรือเชื่อมต่อโทรศัพท์ที่เปิด USB debugging แล้วสั่ง:

   ```powershell
   flutter run
   ```

   หากต้องการเลือกอุปกรณ์ ให้ใช้ `flutter run -d <device-id>` โดยแทน `<device-id>` ด้วย ID จาก `flutter devices` ใน VS Code ให้เปิดโฟลเดอร์โปรเจกต์ เลือกอุปกรณ์จากแถบสถานะ แล้วกด **F5**

## บัญชีตัวอย่าง

เมื่อเริ่มใช้ฐานข้อมูลในเครื่องเป็นครั้งแรก บัญชีผู้จัดการตัวอย่างคือชื่อผู้ใช้ `admin` และ PIN `123456` ข้อมูลนี้มีไว้สำหรับนำเสนอต้นแบบเท่านั้น ห้ามใช้กับข้อมูลธุรกิจจริง บัญชีผู้ใช้และสต็อกถูกเก็บไว้ใน SQLite ภายในอุปกรณ์

## วิธีใช้งานหลัก

1. ตรวจสอบสต็อกและเพิ่มรายการสินค้าหรือวัตถุดิบที่ยังไม่มี
2. บันทึกรับวัตถุดิบ หรือปรับยอดให้ตรงกับการนับจริง
3. ตั้งค่าการวางแผนสต็อกและตรวจสอบรายการที่ใกล้หมด
4. เพิ่มลูกค้า B2B และสร้างคำสั่งซื้อ แอปตรวจสอบและจองวัตถุดิบก่อนรับงานผลิต
5. บันทึกการผลิตและการจัดส่ง จากนั้นตรวจสอบประวัติรายการและ Dashboard
6. หากใช้ LINE ส่งคำขอเปลี่ยนสต็อก ให้เปิด LINE bridge แยกต่างหาก และตรวจสอบพร้อมยืนยันคำขอในแอปก่อนปรับสต็อก ดูคู่มือ `Project/Writeup/line_bridge/README.md` ในชุดไฟล์งานที่ได้รับ

## แพ็กเกจที่ใช้

แพ็กเกจของแอประบุไว้ใน `pubspec.yaml` และล็อกเวอร์ชันไว้ใน `pubspec.lock`:

- Flutter SDK: ส่วนติดต่อ Material และการตั้งค่าภาษาไทย
- `provider`: จัดการสถานะแอปและการเข้าถึง dependencies
- `sqflite`: ฐานข้อมูล SQLite ภายในเครื่อง
- `path`: จัดการตำแหน่งไฟล์ฐานข้อมูล
- `intl`: จัดรูปแบบวันที่และตัวเลข
- `cryptography`: แฮชรหัสผ่าน/PIN
- `cupertino_icons`: ชุดไอคอน
- สำหรับพัฒนาและทดสอบ: `flutter_test`, `flutter_lints` และ `sqflite_common_ffi`

ไม่ต้องติดตั้งทีละแพ็กเกจ ให้สั่ง `flutter pub get` จากโฟลเดอร์ที่มี `pubspec.yaml`

## ทดสอบและ build

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

ไฟล์ APK สำหรับ debug จะอยู่ที่ `build/app/outputs/flutter-apk/app-debug.apk`

## ไฟล์สำคัญในโปรเจกต์

- จุดเริ่มแอปและการตั้งค่า dependencies: `lib/main.dart`
- โครงสร้างฐานข้อมูลและ migrations: `lib/data/app_db.dart`
- การจัดการสต็อกและรายการเคลื่อนไหว: `lib/data/stock_repository.dart`
- หน้าจอแอป: `lib/screens/`
- ตัวจัดการสถานะ: `lib/providers/`
- คู่มืออธิบายไฟล์และขั้นตอนการทำงานฉบับเต็มอยู่ในชุดไฟล์งานที่ `Project/Writeup/docs/WORK2_CODE_GUIDE.md`
- คู่มือติดตั้ง LINE bridge และข้อควรระวังอยู่ที่ `Project/Writeup/line_bridge/README.md`

## ข้อมูลและความปลอดภัย

SQLite เก็บข้อมูลไว้ในอุปกรณ์เครื่องนั้น ควรสำรองข้อมูลแอปก่อนติดตั้งใหม่ เพราะการถอนการติดตั้งอาจลบฐานข้อมูลในเครื่อง ต้นแบบนี้ยังซิงก์ข้อมูลข้ามอุปกรณ์ไม่ได้ ห้าม commit LINE channel secret, access token หรือ bridge token ให้ตั้งค่าความลับผ่าน environment variables บนเครื่องที่รัน bridge และใช้ช่องกรอก token ในแอปเมื่อเริ่มใช้งาน

คู่มือประกอบรายวิชาและบริการ LINE bridge อยู่ภายนอก repository นี้ โฟลเดอร์ `Project/Writeup` มีเฉพาะในชุดไฟล์งานที่จัดส่งให้ ไม่ได้อยู่บน GitHub
