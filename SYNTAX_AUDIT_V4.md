Infinite Music V4 source audit

Changes from V3:
- Removed the Dart switch-expression from LibraryScreen and replaced it with ordinary if/return logic to avoid parser/SDK compatibility issues.
- Corrected initialTab clamp assignment with .toInt().
- Rechecked all lib/*.dart files for balanced (), [], {} delimiters after the change.
- No switch expressions remain in lib/.

Important: this environment does not have the Flutter/Dart SDK, so a real `flutter analyze`, `flutter test`, and APK build cannot be executed here. The Windows Flutter environment remains the final compiler check.
