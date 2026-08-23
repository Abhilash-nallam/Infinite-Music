import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/app_database.dart';
import 'models/audio_player_controller.dart';
import 'models/player_state.dart';
import 'providers/catalog_provider.dart';
import 'providers/local_music_provider.dart';
import 'screens/root_shell.dart';
import 'services/api_service.dart';
import 'services/app_preferences.dart';
import 'services/library_store.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';

const _configuredApiBaseUrl = String.fromEnvironment('INFINITE_MUSIC_API_BASE_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the Flutter UI with a plain just_audio controller. The Android
  // media-service bridge is intentionally not initialized during app startup;
  // a broken media-service/plugin registration must never close the app.
  final prefs = await SharedPreferences.getInstance();
  final settings = AppPreferences(prefs);
  final library = LibraryStore(prefs);
  final db = AppDatabase();
  final playerState = PlayerState(
    controller: JustAudioPlayerController(),
    settings: settings,
    library: library,
  );

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
      playerState: playerState,
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

  const InfiniteMusicApp({
    super.key,
    required this.db,
    required this.syncService,
    required this.settings,
    required this.library,
    this.playerState,
    this.autoSyncCatalog = true,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(
          value: playerState ?? PlayerState(
            controller: JustAudioPlayerController(),
            settings: settings,
            library: library,
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
