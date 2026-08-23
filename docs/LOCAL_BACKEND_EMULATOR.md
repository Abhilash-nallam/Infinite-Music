# Local Backend + Android Emulator

Infinite Music can keep its music backend on the developer machine while the Android emulator runs the Flutter app.

## Emulator backend address

Android Emulator reaches the host machine through `10.0.2.2`.

Configure the app with:

```text
INFINITE_MUSIC_API_BASE_URL=http://10.0.2.2:3000
```

Do not use `localhost` from inside the Android emulator; `localhost` points to the emulator itself.

## Local test flow

1. Start the music backend on the host machine on port `3000`.
2. Confirm the backend is listening on the host interface required by the emulator.
3. Start the Android emulator.
4. Build/install the Flutter app.
5. Verify login, catalog/search, playback, downloads/cache, and other API-backed flows.

GitHub Actions builds and tests the Flutter project, but it cannot access a backend running only on the developer's local machine.
