# رحّالة | Rahala

رحّالة لعبة جغرافيا عربية لنظام أندرويد. تعرّف على الأعلام والعواصم في جولات قصيرة، واجمع النجوم ونقاط الخبرة وأختام الدول في جواز سفرك.

## النسخة الأولى

- ١٥ محطة عبر ثمانية فصول، تشمل الأعلام والعواصم وتحدّيًا يجمعهما.
- ٣٥ دولة من ستّ قارات، مع أعلام وأسماء عواصم وحقائق جغرافية مرفقة بالتطبيق.
- افتح المحطات باجتيازها، وتدرّب حسب الفصل ونوع السؤال، وراجع أخطاءك المحفوظة.
- يُحفظ التقدّم على الجهاز. تعمل اللعبة دون اتصال أو حساب، ومن دون إعلانات أو تتبّع.
- تغطية جميع الدول والخرائط والأشكال والمعالم والجغرافيا الطبيعية وتحديات السرعة ضمن مراحل التطوير اللاحقة.

## تنزيل اللعبة من الهاتف

1. افتح [GitHub Actions](https://github.com/mrmaftahsa/rahala/actions) وسجّل الدخول إلى GitHub لتنزيل الملف.
2. اختر سير العمل **Android APK**، ثم افتح تشغيلًا ناجحًا للفرع أو طلب السحب الذي تريده.
3. من قسم **Artifacts** أسفل صفحة التشغيل، نزّل **rahala-debug-apk**. يحتفظ GitHub بالملف لمدة ١٤ يومًا.
4. فك ضغط الملف على هاتفك، وافتح **app-debug.apk**. اسم التطبيق بعد التثبيت **رحّالة**.

ملفات المعاينة موقّعة بمفتاح التصحيح الذي ينشئه عامل البناء. إذا اختلف المفتاح بين نسختين، فقد يرفض أندرويد التحديث فوق النسخة المثبّتة. حذف التطبيق يمحو تقدّم اللعبة المحفوظ على الجهاز.

## Cloud development

The Android application ID is provisionally `com.rahala.geography`. The build uses Flutter stable 3.41.9 (Dart 3.11.5), Java 21, Gradle 8.14, Android Gradle Plugin 8.11.1, Kotlin 2.2.20, and Android SDK 36. The debug APK supports Android 7.0 (API 24) and later.

GitHub Actions runs on pull requests and pushes to `main`. Use **Run workflow** on the **Android APK** page for a manual run once the workflow is on the default branch. The workflow runs the same cloud checks:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

See [GAME_DESIGN.md](GAME_DESIGN.md) for game rules, [AGENTS.md](AGENTS.md) for development instructions, and [Data sources and licenses](docs/DATA_SOURCES.md) for provenance and catalog updates.
