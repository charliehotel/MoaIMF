<p align="center">
  <a href="README.md">🇰🇷 한국어</a> | <a href="README.en.md">🇺🇸 English</a> | <a href="README.ja.md">🇯🇵 日本語</a> | <a href="README.zh-Hans.md">🇨🇳 简体中文</a> | <a href="README.zh-Hant.md">🇹🇼 繁體中文</a> | <a href="README.vi.md">🇻🇳 Tiếng Việt</a>
  <br>
  <a href="README.fr.md">🇫🇷 Français</a> | <a href="README.de.md">🇩🇪 Deutsch</a> | <a href="README.es.md">🇪🇸 Español</a> | <a href="README.pt.md">🇵🇹 Português</a> | <a href="README.th.md">🇹🇭 ไทย</a> | <a href="README.ar.md">🇸🇦 العربية</a>
</p>

<p align="center">
  <img src="../Assets.xcassets/MoaIMF_icon.png" width="128" height="128" alt="أيقونة MoaIMF">
</p>

<h1 align="center">MoaIMF</h1>

<p align="center">
  <strong>Initial. Medial. Final. Composed.</strong><br>
  تطبيق لشريط قوائم macOS يطبع أسماء ملفات Unicode المفككة بأمان إلى صيغة NFC المركبة
</p>

<p align="center">
  <a href="#نظرة-عامة">نظرة عامة</a> ·
  <a href="#الاستخدام">الاستخدام</a> ·
  <a href="#التثبيت-والبناء">التثبيت والبناء</a> ·
  <a href="#السلامة-والخصوصية">السلامة</a> ·
  <a href="#التطوير">التطوير</a>
</p>

## نظرة عامة

MoaIMF هو تطبيق لشريط قوائم macOS يطبع أسماء الملفات والمجلدات داخل المجلدات التي يختارها المستخدم إلى Unicode NFC. يشير الاسم إلى جمع Initial و Medial و Final في مقطع Hangul واحد وتحويلها إلى حرف مركب.

على macOS قد تُحفظ أسماء الملفات الكورية بصيغة مفككة شبيهة بـ NFD بعد المرور عبر أنظمة ملفات أو تطبيقات أو أدوات تنزيل أو فك ضغط أو أقراص خارجية أو NAS أو أدوات مزامنة سحابية. قد يعرض Finder الاسم كـ `한글.txt`، بينما يراه Alfred أو بحث الطرفية أو بعض سكربتات الأتمتة كـ `ㅎㅏㄴㄱㅡㄹ.txt` فلا تجد الملف.

MoaIMF ليس سكربت تنظيف يعمل مرة واحدة. إنه أداة محلية تراقب باستمرار المجلدات التي وافق عليها المستخدم وتصلح مشاكل أسماء الملفات الجديدة أو المحملة.

## لقطات الشاشة

أثناء المراقبة يتغير رمز شريط القوائم بالترتيب `ㅎ`, `ㅏ`, `ㄴ`, `한`. عند الإيقاف المؤقت يتوقف عند `ㅎ`.

<table>
  <tr>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_ko.gif" alt="تحريك شريط القوائم الكوري في MoaIMF" width="100%"></kbd>
    </td>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_en.png" alt="شاشة شريط القوائم الإنجليزية في MoaIMF" width="100%"></kbd>
    </td>
  </tr>
</table>

### المجلدات المراقبة

<kbd><img src="../Screenshots/MoaIMF_monitoring_folders_en.png" alt="إعدادات المجلدات المراقبة" width="100%"></kbd>

تبدأ الإعدادات بالمجلد `Downloads` افتراضياً. يمكن إضافة المجلدات أو إزالتها باستخدام `+` و `-`. يمكن تفعيل كل مجلد أو تعطيله بشكل مستقل.

### استثناءات استقرار التنزيل

<kbd><img src="../Screenshots/MoaIMF_exceptions_en.png" alt="استثناءات استقرار التنزيل" width="100%"></kbd>

قد لا يكون للملف الجاري تنزيله اسم نهائي بعد، وقد يستمر حجم الملف أو وقت تعديله في التغير. يوفر MoaIMF قواعد مقفلة لـ `.crdownload`, `.download`, `.part`, `.partial`, `.tmp`، ويسمح بإضافة قواعد مخصصة.

### السجل الحديث

<kbd><img src="../Screenshots/MoaIMF_recent_history_en.png" alt="السجل الحديث" width="100%"></kbd>

يمكن عرض السجل حسب اليوم أو 7 أيام أو 30 يوماً أو كامل المدة، وتصفيته حسب إعادة التسمية أو التعارض أو الصلاحية أو الخطأ. يقارن البحث أيضاً المتغيرات المطبعة حتى تُعامل فروق NFC/NFD كإدخال واحد.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/history.jsonl
```

### حول التطبيق

<kbd><img src="../Screenshots/MoaIMF_about_en.png" alt="حول MoaIMF" width="100%"></kbd>

تعرض نافذة About اسم التطبيق والإصدار ووصفاً قصيراً وحقوق النشر. توضح الصورة فكرة جمع jamo مفككة في حرف مركب، مثل `ㅎㅏㄴ -> 한`.

## الميزات

- عرض حالة المراقبة من شريط القوائم، والإيقاف المؤقت، والاستئناف، والخروج
- استخدام Downloads كموقع مراقبة افتراضي
- إدارة عدة مجلدات باستخدام `+` و `-`
- فحص المجلدات بشكل متكرر
- الوصول فقط إلى المجلدات التي اختارها المستخدم عبر security-scoped bookmarks
- اكتشاف التغييرات باستخدام FSEvents
- المعالجة فقط بعد استقرار حجم الملف ووقت التعديل
- عدم الكتابة فوق الملفات تلقائياً عند احتمال التعارض
- حفظ السجل محلياً
- لا خادم خارجي، ولا حساب، ولا telemetry

## آلية العمل

لا يغير MoaIMF محتوى الملفات. يتعامل فقط مع شكل Unicode normalization لأسماء الملفات والمجلدات.

التدفق: يختار المستخدم مجلداً، يحفظ التطبيق الصلاحية كـ bookmark، يلتقط FSEvents التغييرات، يتحقق الفاحص من الاستثناءات والاستقرار، يحسب اسم NFC الهدف، يفحص التعارضات، يتحقق من هوية الملف قبل rename وبعده، ثم يحفظ النتيجة.

لا يدمج MoaIMF الملفات المتعارضة تلقائياً ولا ينشئ أسماء مثل `-1` أو `copy` أو `복사본`. الحالات التي تحتاج إلى قرار المستخدم تبقى في السجل والإشعارات.

## الاستخدام

1. افتح `MoaIMF.app`؛ يظهر الرمز في شريط القوائم.
2. افتح `Watched Folder Settings...` وأضف المجلدات.
3. اختر `Normalize Existing Items` أو `Watch New Items Only`.
4. استخدم `Pause Watching` و `Resume Watching`.
5. استخدم `Scan All Now` أو `Scan Now` للفحص اليدوي.
6. اختر اللغة من قائمة `Language`.
7. فعّل `Launch at Login` إذا أردت تشغيله عند تسجيل الدخول.
8. اختر `Quit MoaIMF` للخروج من دون ترك daemon أو helper.

اللغات المتوفرة هي ترجمات ذكاء اصطناعي للتسهيل. أبلغ عن الأخطاء أو طلبات اللغات عبر `Issues`.

## التثبيت والبناء

حالياً يفترض MoaIMF التثبيت من المصدر. لا توجد حزمة موقعة بـ Developer ID وموثقة من Apple بعد.

```sh
git clone https://github.com/charliehotel/MoaIMF.git
cd MoaIMF
scripts/check.sh
open .build/MoaIMF.app
```

المتطلبات: macOS 13 Ventura أو أحدث، Xcode 16 أو Command Line Tools متوافقة، Swift 6 toolchain، و Git. لبناء حزمة التطبيق فقط:

```sh
scripts/build-app.sh
```

## موقع البيانات المحلي

يحفظ MoaIMF حالة التطبيق والسجل في Application Support داخل حاوية sandbox الخاصة بتطبيق macOS.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

الملفات الرئيسية هي `watched-folders.json`, `stability-rules.json`, `history.jsonl`, و `recovery/`. تحفظ بعض الإعدادات أيضاً في `UserDefaults`.

## السلامة والخصوصية

يغير MoaIMF الأسماء فقط. لا يقرأ محتوى الملفات ولا يعدله، ولا يصل إلا إلى المجلدات المختارة، ولا يتبع symlinks، ولا يفحص حزماً مثل `.app` أو `.photoslibrary`، ويتحقق من التعارضات، ويعمل محلياً بالكامل. لا شبكة، لا حساب، لا analytics، ولا telemetry.

## القيود

لا يغير MoaIMF طريقة تخزين أسماء الملفات في macOS على مستوى النظام، ولا يجبر كل التطبيقات على الحفظ بصيغة NFC، ولا يحل التعارضات تلقائياً، ولا يعيد بناء فهارس Spotlight أو Alfred مباشرة، ويركز حالياً على البناء من المصدر.

## الإزالة

1. أوقف `Launch at Login`.
2. اختر `Quit MoaIMF`.
3. احذف `MoaIMF.app`.
4. لحذف الحالة المحلية أيضاً، احذف مجلد MoaIMF Application Support داخل حاوية التطبيق.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

هذا لا يعيد أسماء الملفات التي حُولت بالفعل إلى NFC إلى NFD.

## التطوير

يعتمد المشروع على Swift Package Manager.

```sh
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test
swift build
scripts/build-app.sh
```

- [مواصفة التصميم v0.1](../docs/superpowers/specs/2026-06-21-moaimf-v0.1-design.md)
- [خطة التنفيذ v0.1](../docs/superpowers/plans/2026-06-21-moaimf-v0.1.md)
- [دليل المساهمة](../CONTRIBUTING.md)
- [سياسة الأمان](../SECURITY.md)

## الرخصة

يوزع MoaIMF بموجب [MIT License](../LICENSE).
