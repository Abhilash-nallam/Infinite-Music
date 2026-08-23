# Infinite Music

Infinite Music is an **offline-first Flutter music app** designed to make device music and a future cloud catalog feel like one library.

## Product direction

- Local device music must remain usable without internet.
- A remote catalog is synchronized into a local Drift database.
- Home, Search and Library read catalog data through `CatalogProvider`.
- Playback is handled by `just_audio` + `audio_service` for background and notification controls.
- The supplied Infinite Music branding remains the source of truth for the app icon and startup splash.
- The cloud backend is deployed separately; the mobile repository does not contain the production backend.

## Architecture

```text
Cloud backend
    -> ApiService
    -> SyncService
    -> Drift / SQLite local catalog
    -> CatalogProvider
    -> Home / Search / Library

Device MediaStore
    -> LocalMusicService
    -> LocalMusicProvider
    -> Home / Search / My Device

Song selection
    -> PlayerState
    -> InfiniteAudioHandler
    -> just_audio
    -> Android media notification / lock screen controls
```

The local database is the offline catalog cache. Sync applies additions, updates, deletions and the catalog cursor atomically so a failed sync cannot leave the cursor ahead of stored data.

## Android development

### Requirements

- Flutter stable
- Android SDK / Android Studio
- An Android emulator or physical Android device
- The separate Infinite Music backend when testing cloud catalog sync

### Install and generate code

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Analyze and test

```bash
flutter analyze
flutter test
```

GitHub Actions runs dependency installation, Drift code generation, analysis and tests on `main`/`cleanup-and-bugfix-final` and on pull requests to `main`.

### Run on Android emulator

```bash
flutter run
```

The app uses `http://10.0.2.2:3000/api/v1` by default for emulator development. `10.0.2.2` is Android Emulator's alias for the host computer's localhost.

For a physical device on the same Wi-Fi network, pass the host machine's LAN address:

```bash
flutter run --dart-define=INFINITE_MUSIC_API_BASE_URL=http://192.168.x.x:3000/api/v1
```

For production, pass the HTTPS backend URL:

```bash
flutter build apk --release --dart-define=INFINITE_MUSIC_API_BASE_URL=https://your-api.example.com/api/v1
```

Release Android builds do **not** allow cleartext HTTP. Local HTTP is enabled only in debug builds.

## Branding

The source branding asset is:

```text
assets/icon/app_icon.png
```

It is intentionally kept unchanged for the launcher and Flutter branded splash. Obsolete duplicate branding assets and unused mock catalog data are not kept in the repository.

## Current app capabilities

- Local device music discovery
- Offline catalog cache
- Catalog delta synchronization
- Offline search
- Artwork caching
- Full-screen and mini-player playback
- Queue, shuffle and repeat controls
- Android background playback and media notification
- Persistent settings
- Persistent liked songs and playlists
- Privacy/permission screen
- Infinite Music branded startup experience

## Backend

The production backend is intentionally separate from this Flutter repository. The mobile app only depends on its documented catalog-sync API contract. The planned production infrastructure can use the low-cost Oracle Cloud deployment discussed for Infinite Music, with HTTPS used by release builds.

## Repository hygiene

Generated build output, Dart tooling caches, coverage output, obsolete patch-note files, unused mock data and duplicate unused branding assets should stay out of the repository. The Android platform configuration is retained because Android is the current launch target.
