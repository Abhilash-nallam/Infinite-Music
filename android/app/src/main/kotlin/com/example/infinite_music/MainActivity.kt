package com.example.infinite_music

import io.flutter.embedding.android.FlutterActivity

/**
 * Plain Flutter activity.
 *
 * Background audio is intentionally not coupled to activity startup. This
 * keeps the app launch path independent from the audio-service Android
 * plugin so a media-service initialization problem cannot terminate the UI.
 */
class MainActivity : FlutterActivity()
