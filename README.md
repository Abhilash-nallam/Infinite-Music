# Infinite Music (Flutter)

Offline-first music app. Catalog data flows:

```
Backend (../infinite_music_backend) -> ApiService -> SyncService
  -> AppDatabase (Drift, atomic) -> CatalogProvider -> Home / Library / Search
```

`CatalogProvider` is the single source of truth for catalog data — no
screen reads `mock_data.dart` or talks to the database/API directly.

## Requirements

- Flutter SDK (this project was last built against a 3.3+ compatible SDK —
  check `pubspec.yaml`'s `environment:` field for the exact constraint)
- The backend running separately (see `../infinite_music_backend/README.md`)

## Setup

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

The second command is **required**, not optional — it generates
`lib/database/app_database.g.dart` from the Drift table definitions in
`lib/database/tables.dart`. The app will not compile without it.

## Static analysis

```
flutter analyze
```

## Run the test suite

```
flutter test
```

Covers (in `test/`, **33 written test cases**):
- `song_mapper_test.dart` — every SongRow field maps to Song correctly
- `database_test.dart` — atomic sync commits, stale/regressive cursor rejection,
  local offline search, and preservation of local liked/downloaded state during remote updates
- `sync_service_test.dart` — full sync, delta sync, repeated no-op sync,
  deletions, offline resilience, concurrent-sync coalescing, and end-to-end stale-version rejection
- `catalog_provider_test.dart` — error handling, downloaded/liked filters,
  search, like-toggling, all through the same provider the UI uses

## Run the app

Start the backend first (separate terminal), then:

```
flutter run -d <device-id>
```

For the Android emulator specifically, the app defaults to
`ApiService.forEmulator()`, which points at `http://10.0.2.2:3000` — that
address is a special alias the emulator provides for your host machine's
`localhost` and **only works from the emulator**. For a physical device on
the same network, change `main.dart` to use
`ApiService.forHost('192.168.x.x')` with your computer's actual LAN IP
instead.

## ⚠️ Verification status of this README's commands

The commands above were **not executed** by the assistant that wrote this
project — the development sandbox used to build it has Node.js but no
Flutter/Dart SDK available (network access is restricted to package
registries, not Google's SDK distribution servers). Run all five commands
above yourself; if `build_runner` or `analyze` surface anything, that needs
fixing before this is genuinely done.
