# Infinite Music — Final UI / Local-App Update

This update is for the APK/local-app stage only. The production cloud backend is intentionally unchanged.

## Included
- Branded dark native splash using the supplied Infinite Music logo.
- White outer canvas removed from the supplied logo; transparent outside the icon frame.
- Splash is preserved for at least 1.5 seconds.
- App icon configuration uses the supplied logo.
- Home greeting follows the device local time.
- Home search bar removed.
- Home top-right profile avatar replaced with an AI Premium badge.
- Home My Device card/banner opens My Device directly.
- Local songs are shown as artwork shelves/banners on Home and Search.
- Local artwork and catalog artwork remain supported in the mini player and full player.
- Local artwork is cached in memory to reduce player artwork flashing.
- Mini-player has a compact X button to hide it.
- Search refresh now refreshes both local device music and the catalog sync.
- Profile My Device opens the My Device tab directly.
- Settings are persisted using SharedPreferences.
- Autoplay is wired into PlayerState for both local and catalog songs.
- Audio-quality, Wi-Fi-only, data-saver and notification preferences persist for future catalog/download/background-audio integration.
- Pull-to-refresh on Home retries catalog sync and rescans device music together.

## Important
Copy the `lib/`, `assets/`, `test/`, and `pubspec.yaml` from this update into your existing working project `E:\infinite_music`.

Do NOT replace your existing `android/` folder with this archive. Your working Android project contains the device-specific signing/permission configuration.

After copying:

```bat
cd E:\infinite_music
flutter clean
flutter pub get
dart run flutter_native_splash:create
dart run flutter_launcher_icons
flutter build apk --release
```

The cloud backend is not part of this update.
