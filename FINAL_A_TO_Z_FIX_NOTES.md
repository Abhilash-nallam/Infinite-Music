# Infinite Music — A-to-Z local/app fix

- Fixed direct My Device route background by making LibraryScreen a real Scaffold.
- Removed the confusing mini-player X; Android media notification is now the playback control/close surface.
- Added just_audio_background for Android media notification, lock-screen/media controls and background playback.
- Added media metadata tags for local and remote playback.
- Added Android notification/audio permissions and custom AudioServiceActivity.
- App label is now `Infinite Music`.
- Splash uses a dedicated centered splash mark instead of the full wordmark, preventing Android 12 icon cropping/zoom.
- App launcher keeps the full Infinite Music logo with white outer canvas removed.
- Notification permission is requested only when playback starts and notifications are enabled.
- Cloud backend remains untouched.

IMPORTANT: this package includes Android changes because notification controls cannot work from Dart-only files. Preserve `android/local.properties` from your existing project.
