[🇰🇷 한국어](README.md) | [🇺🇸 English](README.en.md) | [🇯🇵 日本語](README.ja.md) | [🇨🇳 简体中文](README.zh-Hans.md) | [🇹🇼 繁體中文](README.zh-Hant.md) | [🇻🇳 Tiếng Việt](README.vi.md)<br>
[🇫🇷 Français](README.fr.md) | [🇩🇪 Deutsch](README.de.md) | [🇪🇸 Español](README.es.md) | [🇵🇹 Português](README.pt.md) | [🇹🇭 ไทย](README.th.md) | [🇸🇦 العربية](README.ar.md)


<p align="center">
  <img src="../Assets.xcassets/MoaIMF_icon.png" width="128" height="128" alt="ไอคอน MoaIMF">
</p>

<h1 align="center">MoaIMF</h1>

<p align="center">
  <strong>Initial. Medial. Final. Composed.</strong><br>
  แอปแถบเมนู macOS สำหรับปรับชื่อไฟล์ Unicode ที่แยกองค์ประกอบให้เป็นรูป NFC อย่างปลอดภัย
</p>

<p align="center">
  <a href="#ภาพรวม">ภาพรวม</a> ·
  <a href="#วิธีใช้">วิธีใช้</a> ·
  <a href="#การติดตั้งและ-build">การติดตั้งและ build</a> ·
  <a href="#ความปลอดภัยและความเป็นส่วนตัว">ความปลอดภัย</a> ·
  <a href="#การพัฒนา">การพัฒนา</a>
</p>

## ภาพรวม

MoaIMF เป็นแอปแถบเมนูสำหรับ macOS ที่ปรับชื่อไฟล์และโฟลเดอร์ในตำแหน่งที่ผู้ใช้เลือกให้เป็น Unicode NFC ชื่อของแอปหมายถึงการรวม Initial, Medial และ Final ของพยางค์ฮันกึลให้เป็นอักขระแบบ composed

บน macOS ชื่อไฟล์ภาษาเกาหลีอาจถูกบันทึกในรูปแบบที่แยกองค์ประกอบคล้าย NFD หลังผ่านระบบไฟล์ แอป เครื่องมือดาวน์โหลด เครื่องมือแตกไฟล์ ไดรฟ์ภายนอก NAS หรือเครื่องมือซิงก์คลาวด์ Finder อาจแสดงเป็น `한글.txt` แต่ Alfred, การค้นหาในเทอร์มินัล หรือสคริปต์บางตัวอาจเห็นเป็น `ㅎㅏㄴㄱㅡㄹ.txt` และหาไฟล์ไม่พบ

MoaIMF ไม่ใช่สคริปต์ล้างข้อมูลแบบใช้ครั้งเดียว แต่เป็นยูทิลิตีที่ทำงานเฉพาะในเครื่อง คอยเฝ้าดูโฟลเดอร์ที่ผู้ใช้อนุญาตและแก้ปัญหาชื่อไฟล์ใหม่ที่ถูกสร้างหรือดาวน์โหลด

## ภาพหน้าจอ

ระหว่างเฝ้าดูโฟลเดอร์ ไอคอนแถบเมนูจะเปลี่ยนตามลำดับ `ㅎ`, `ㅏ`, `ㄴ`, `한` เมื่อหยุดพัก ไอคอนจะหยุดที่ `ㅎ`

<table>
  <tr>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_ko.gif" alt="แอนิเมชันแถบเมนูภาษาเกาหลีของ MoaIMF" width="100%"></kbd>
    </td>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_en.png" alt="หน้าจอแถบเมนูภาษาอังกฤษของ MoaIMF" width="100%"></kbd>
    </td>
  </tr>
</table>

### โฟลเดอร์ที่เฝ้าดู

<kbd><img src="../Screenshots/MoaIMF_monitoring_folders_en.png" alt="การตั้งค่าโฟลเดอร์ที่เฝ้าดู" width="100%"></kbd>

ค่าเริ่มต้นคือโฟลเดอร์ `Downloads` ใช้ปุ่ม `+` และ `-` เพื่อเพิ่มหรือลบโฟลเดอร์ แต่ละโฟลเดอร์เปิดหรือปิดแยกกันได้

### ข้อยกเว้นความเสถียรของการดาวน์โหลด

<kbd><img src="../Screenshots/MoaIMF_exceptions_en.png" alt="ข้อยกเว้นความเสถียรของการดาวน์โหลด" width="100%"></kbd>

ไฟล์ที่กำลังดาวน์โหลดอาจยังไม่มีชื่อสุดท้าย หรือขนาดไฟล์และเวลาแก้ไขยังเปลี่ยนอยู่ MoaIMF มี rule ที่ล็อกไว้สำหรับ `.crdownload`, `.download`, `.part`, `.partial`, `.tmp` และให้ผู้ใช้เพิ่ม rule เองได้

### ประวัติล่าสุด

<kbd><img src="../Screenshots/MoaIMF_recent_history_en.png" alt="ประวัติล่าสุด" width="100%"></kbd>

ดูประวัติได้ตามวันนี้ 7 วัน 30 วัน หรือทั้งหมด และกรองตามการเปลี่ยนชื่อ conflict permission หรือ error ได้ การค้นหาจะเทียบรูปแบบที่ normalize แล้วด้วย เพื่อมองความต่าง NFC/NFD เป็นอินพุตเดียวกัน

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/history.jsonl
```

### เกี่ยวกับ

<kbd><img src="../Screenshots/MoaIMF_about_en.png" alt="เกี่ยวกับ MoaIMF" width="100%"></kbd>

หน้าต่าง About แสดงชื่อแอป เวอร์ชัน คำอธิบายสั้น และลิขสิทธิ์ ภาพด้านบนแสดงแนวคิดการรวม jamo ที่แยกอยู่ให้เป็นอักขระเดียว เช่น `ㅎㅏㄴ -> 한`

## คุณสมบัติ

- ดูสถานะจากแถบเมนู หยุดพัก ทำต่อ และออกจากแอป
- ใช้ Downloads เป็นตำแหน่งเริ่มต้น
- เพิ่มหรือลบหลายโฟลเดอร์ด้วย `+` และ `-`
- สแกนโฟลเดอร์และโฟลเดอร์ย่อยแบบ recursive
- เข้าถึงเฉพาะโฟลเดอร์ที่ผู้ใช้เลือกด้วย security-scoped bookmarks
- ตรวจจับการเปลี่ยนแปลงด้วย FSEvents
- ประมวลผลหลังจากขนาดไฟล์และเวลาแก้ไขนิ่งแล้วเท่านั้น
- ไม่ overwrite อัตโนมัติเมื่อมีโอกาสชนกัน
- บันทึกประวัติไว้ในเครื่อง
- ไม่มีเซิร์ฟเวอร์ภายนอก บัญชี หรือ telemetry

## วิธีทำงาน

MoaIMF ไม่แก้ไขเนื้อหาไฟล์ แอปจัดการเฉพาะรูปแบบ Unicode normalization ของชื่อไฟล์และโฟลเดอร์

ขั้นตอนคือเลือกโฟลเดอร์ บันทึกสิทธิ์เป็น bookmark รับเหตุการณ์จาก FSEvents ตรวจ rule และความเสถียร คำนวณชื่อ NFC ตรวจ conflict ตรวจตัวตนไฟล์ก่อนและหลัง rename แล้วบันทึกผล

MoaIMF ไม่รวมไฟล์ที่อาจ conflict และไม่สร้างชื่ออย่าง `-1`, `copy` หรือ `복사본` เอง กรณีที่ต้องให้ผู้ใช้ตัดสินใจจะอยู่ในประวัติและการแจ้งเตือน

## วิธีใช้

1. เปิด `MoaIMF.app`; ไอคอนจะอยู่บนแถบเมนู
2. เปิด `Watched Folder Settings...` แล้วเพิ่มโฟลเดอร์
3. เลือก `Normalize Existing Items` หรือ `Watch New Items Only`
4. ใช้ `Pause Watching` และ `Resume Watching`
5. ใช้ `Scan All Now` หรือ `Scan Now` เพื่อสแกนเอง
6. เลือกภาษาในเมนู `Language`
7. เปิด `Launch at Login` หากต้องการให้เริ่มตอน login
8. เลือก `Quit MoaIMF` เพื่อออก โดยไม่เหลือ daemon หรือ helper

ภาษาที่ให้มาเป็นคำแปล AI เพื่อความสะดวก หากพบคำแปลผิดหรือต้องการภาษาเพิ่ม แจ้งผ่าน `Issues`

## การติดตั้งและ build

ตอนนี้ MoaIMF ใช้วิธี build จาก source ยังไม่มีแพ็กเกจที่เซ็นด้วย Developer ID และ notarized โดย Apple

```sh
git clone https://github.com/charliehotel/MoaIMF.git
cd MoaIMF
scripts/check.sh
open .build/MoaIMF.app
```

ต้องใช้ macOS 13 Ventura ขึ้นไป, Xcode 16 หรือ Command Line Tools ที่เข้ากันได้, Swift 6 toolchain และ Git หากต้องการ build เฉพาะ app bundle:

```sh
scripts/build-app.sh
```

## ตำแหน่งข้อมูลในเครื่อง

MoaIMF เก็บสถานะและประวัติไว้ใน Application Support ภายใน sandbox container ของแอป macOS

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

ไฟล์หลักคือ `watched-folders.json`, `stability-rules.json`, `history.jsonl`, `recovery/` และบางค่าจะอยู่ใน `UserDefaults`

## ความปลอดภัยและความเป็นส่วนตัว

MoaIMF เปลี่ยนเฉพาะชื่อ ไม่อ่านหรือแก้เนื้อหาไฟล์ เข้าถึงเฉพาะโฟลเดอร์ที่ผู้ใช้เลือก ไม่ตาม symlink ไม่สแกน package เช่น `.app` หรือ `.photoslibrary` ตรวจ conflict และทำงานในเครื่องทั้งหมด ไม่มี network, account, analytics หรือ telemetry

## ข้อจำกัด

MoaIMF ไม่เปลี่ยนวิธีเก็บชื่อไฟล์ทั้งระบบของ macOS ไม่บังคับทุกแอปให้บันทึกเป็น NFC ไม่แก้ conflict อัตโนมัติ ไม่สร้าง index ของ Spotlight หรือ Alfred ใหม่โดยตรง และตอนนี้เน้นการ build จาก source

## ถอนการติดตั้ง

1. ปิด `Launch at Login`
2. เลือก `Quit MoaIMF`
3. ลบ `MoaIMF.app`
4. หากต้องการลบสถานะในเครื่องด้วย ให้ลบโฟลเดอร์ Application Support ของ MoaIMF ใน app container

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

การลบนี้ไม่เปลี่ยนชื่อที่ถูกแปลงเป็น NFC แล้วกลับเป็น NFD

## การพัฒนา

โปรเจกต์ใช้ Swift Package Manager

```sh
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test
swift build
scripts/build-app.sh
```

- [สเปกการออกแบบ v0.1](../docs/superpowers/specs/2026-06-21-moaimf-v0.1-design.md)
- [แผนการพัฒนา v0.1](../docs/superpowers/plans/2026-06-21-moaimf-v0.1.md)
- [คู่มือการมีส่วนร่วม](../CONTRIBUTING.md)
- [นโยบายความปลอดภัย](../SECURITY.md)

## License

MoaIMF เผยแพร่ภายใต้ [MIT License](../LICENSE)
