# Infinite Music — Phase A UI/Artwork Refresh

This patch is based on the uploaded `infinite_music_PHASE_A_widgetfix7(1).zip`.

## Current scope
Cloud backend deployment is intentionally NOT changed.

## Main changes
- Local Android artwork is loaded from MediaStore using `on_audio_query` audio IDs.
- Remote catalog artwork uses `CachedNetworkImage`.
- Artwork widgets keep their loaded image stable to prevent player artwork flashing/blinking.
- Player now uses the same artwork for the large cover, ambient background and mini-player.
- Added a shared `LocalMusicProvider` so Library and Search use one local-device music source.
- Search now searches both local device songs and the synced catalog.
- Library redesigned with Downloads / My Device / Playlists / Liked.
- Added playlist creation UI placeholder for the future persistent playlist system.
- Profile redesigned with app sections, settings, privacy, about and future premium entry.
- Added Settings screen.
- Added in-app Privacy Policy screen.
- Home redesigned to be local-first and friendly when the cloud catalog is unavailable.
- Cloud catalog artwork will display automatically when `artworkUrl` is populated.
- Player playback requests are guarded so a previous async load cannot start after the user selects a newer song.
- App version bumped to 0.2.0.

## Important
The uploaded source archive did not contain the normal Android main manifest/build files. Preserve the existing `android/` project files from the working `E:\infinite_music` project when applying this patch. The existing app already has working audio permission behavior.

## Build
From the existing working project:
flutter clean
flutter pub get
flutter build apk --release

Then install/send the resulting APK and test local songs, artwork, Search, Profile and Settings.
