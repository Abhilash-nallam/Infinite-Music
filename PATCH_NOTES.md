# Infinite Music — Final Artwork / Splash Patch (0.2.2)

## Included
- Preserves the working Android MediaSession/background playback controls.
- Local embedded album art is materialized at high quality (up to 2000px JPEG) and passed as a file URI to Android MediaItem metadata.
- Notification/lock-screen artwork can use HTTP(S), file, and content URIs.
- Flutter artwork renderer requests high-quality embedded artwork and uses high image filtering.
- Launcher artwork is flattened onto the Infinite Music dark-purple background so transparent/black empty corners do not appear.
- Android adaptive launcher icon uses the full Infinite Music artwork as its background with a transparent foreground, avoiding the previous oversized foreground margins.
- The supplied 1.5-second `assets/splash/infinite_music_intro.mp4` is declared as a Flutter asset and remains the branded startup animation.
- Native Android splash icon remains transparent so it does not replace the MP4 intro with a static launcher icon.
- App display name remains `Infinite Music`.

## Important
This patch was source-reviewed in the packaging environment, but Flutter/Dart SDK tooling is not installed in this environment, so a local `flutter analyze`/`flutter build apk --release` could not be executed here. Run the commands below on the Windows Flutter machine.

## Build/test
```powershell
cd E:\infinite_music
flutter clean
flutter pub get
flutter analyze
flutter build apk --release
```

Do not run `dart run flutter_launcher_icons` before the first test; the launcher resources are already prepared in this patch.

## Real-device checks
1. Launch app: native dark handoff -> supplied 1.5s MP4 -> Home.
2. Confirm launcher label is `Infinite Music` and the icon has no empty transparent corners.
3. Play a local song.
4. Lock the phone and open the notification/media panel.
5. Confirm song artwork, title, artist, seek bar, play/pause, previous, next and stop.
6. Minimize/close the app and confirm playback continues with Android media controls.
7. Check artwork in Home, My Device, Library, mini-player and full player.
