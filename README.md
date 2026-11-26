# رحّالة | Rahala

رحّالة لعبة جغرافيا عربية لنظام أندرويد. تعرّف على الأعلام والعواصم في جولات قصيرة، واجمع النجوم ونقاط الخبرة وأختام الدول في جواز سفرك.

## الإصدار ٠٫٢٫٠

- ١١٦ محطة متدرجة عبر ثمانية فصول، بأربع طرق للعب تشمل الأعلام والعواصم وتحديد الدولة على الخريطة والتعرّف على شكلها.
- أطلس تفاعلي وموسوعة لـ١٩٥ دولة، مع البحث وتصفية القارات والتكبير وتحريك الخريطة.
- تلميحات عند الحاجة، وتدريب بحسب الفصل، ومراجعة للأخطاء وتكرار متباعد. اجمع أختام الدول في جواز رحّالة.
- تُرفق الخرائط والأعلام والخط والحقائق بالتطبيق، ويُحفظ التقدّم على الجهاز.
- راجع [خطة التطوير](ROADMAP.md) للمحطات والأوضاع اللاحقة.

## تنزيل اللعبة من الهاتف

1. افتح [GitHub Actions](https://github.com/mrmaftahsa/rahala/actions) وسجّل الدخول إلى GitHub لتنزيل الملف.
2. اختر سير العمل **Android APK**، ثم افتح تشغيلًا ناجحًا للفرع أو طلب السحب الذي تريده.
3. من قسم **Artifacts** أسفل صفحة التشغيل، نزّل **app-debug.apk** مباشرةً. يحتفظ GitHub بالملف لمدة ١٤ يومًا.
4. افتح الملف على هاتفك لتثبيت **رحّالة**. يتوفر أيضًا الملف المضغوط **rahala-debug-apk** لمن يفضّل تنزيله.

يحافظ الإصدار على التقدّم السابق عند التحديث بتوقيع أندرويد المطابق. تحمل ملفات المعاينة التي تبنيها GitHub Actions مفاتيح تصحيح مؤقتة، ولذلك قد يرفض أندرويد تثبيت بناء جديد فوق بناء سابق. حذف التطبيق يمحو التقدّم المحفوظ على الجهاز.

## Cloud development

The Android application ID is provisionally `com.rahala.geography`. The build uses Flutter stable 3.41.9 (Dart 3.11.5), Java 21, Gradle 8.14, Android Gradle Plugin 8.11.1, Kotlin 2.2.20, and Android SDK 36. The debug APK supports Android 7.0 (API 24) and later.

GitHub Actions runs on pull requests and pushes to `main`. Use **Run workflow** on the **Android APK** page for a manual run once the workflow is on the default branch. The workflow runs the following cloud checks.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

See [GAME_DESIGN.md](GAME_DESIGN.md) for game rules, [AGENTS.md](AGENTS.md) for development instructions, and [Data sources and licenses](docs/DATA_SOURCES.md) for provenance and catalog updates.
