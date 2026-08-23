import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/app_database.dart';
import 'models/audio_player_controller.dart';
import 'models/player_state.dart';
import 'providers/catalog_provider.dart';
import 'providers/local_music_provider.dart';
import 'screens/root_shell.dart';
import 'services/api_service.dart';
import 'services/background_audio_handler.dart';
import 'services/app_preferences.dart';
import 'services/library_store.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';

const _configuredApiBaseUrl = String.fromEnvironment('INFINITE_MUSIC_API_BASE_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final settings = AppPreferences(prefs);
  final library = LibraryStore(prefs);
  final db = AppDatabase();

  InfiniteAudioHandler? audioHandler;
  PlayerState? startupPlayerState;

  // Background audio must never prevent the main UI from opening.
  try {
    audioHandler = await AudioService.init(
      builder: () => InfiniteAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.infinite_music.audio.v3',
        androidNotificationChannelName: 'Infinite Music playback',
        androidNotificationChannelDescription:
            'Playback controls for Infinite Music',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'drawable/ic_stat_music_note',
        androidShowNotificationBadge: false,
        androidNotificationClickStartsActivity: true,
        preloadArtwork: true,
      ),
    ).timeout(const Duration(seconds: 8));
  } catch (error, stackTrace) {
    debugPrint('AudioService unavailable; using local playback fallback: $error');
    debugPrintStack(stackTrace: stackTrace);
    startupPlayerState = PlayerState(
      controller: JustAudioPlayerController(),
      settings: settings,
      library: library,
    );
  }

  final api = _configuredApiBaseUrl.isNotEmpty
      ? ApiService(baseUrl: _configuredApiBaseUrl)
      : ApiService.forEmulator();
  final syncService = SyncService(api: api, db: db);

  runApp(
    InfiniteMusicApp(
      db: db,
      syncService: syncService,
      settings: settings,
      library: library,
      playerState: startupPlayerState,
      backgroundHandler: audioHandler,
    ),
  );
}

class InfiniteMusicApp extends StatelessWidget {
  final AppDatabase db;
  final SyncService syncService;
  final AppPreferences settings;
  final LibraryStore library;
  final PlayerState? playerState;
  final bool autoSyncCatalog;
  final InfiniteAudioHandler? backgroundHandler;

  const InfiniteMusicApp({
    super.key,
    required this.db,
    required this.syncService,
    required this.settings,
    required this.library,
    this.playerState,
    this.autoSyncCatalog = true,
    this.backgroundHandler,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider(
          create: (_) => playerState ?? PlayerState(
            settings: settings,
            library: library,
            backgroundHandler: backgroundHandler,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => CatalogProvider(
            db: db,
            syncService: syncService,
            settings: settings,
            autoSync: autoSyncCatalog,
          ),
        ),
        ChangeNotifierProvider(create: (_) => LocalMusicProvider()),
      ],
      child: MaterialApp(
        title: 'Infinite Music',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const RootShell(),
      ),
    );
  }
}
