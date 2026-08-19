import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:infinite_music/database/app_database.dart';
import 'package:infinite_music/models/audio_player_controller.dart';
import 'package:infinite_music/models/player_state.dart';
import 'package:infinite_music/providers/catalog_provider.dart';
import 'package:infinite_music/providers/local_music_provider.dart';
import 'package:infinite_music/screens/root_shell.dart';
import 'package:infinite_music/services/api_service.dart';
import 'package:infinite_music/services/library_store.dart';
import 'package:infinite_music/services/sync_service.dart';
import 'package:infinite_music/theme/app_theme.dart';

class _NoopCatalogApi implements CatalogApi {
  @override
  Future<SyncResult> fetchSync(int sinceVersion) async {
    return SyncResult(
      upserts: const [],
      deletedIds: const [],
      catalogVersion: sinceVersion,
    );
  }
}

class FakeAudioPlayerController implements AudioPlayerController {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<ja.PlayerState> _playerStateController =
      StreamController<ja.PlayerState>.broadcast();

  bool _playing = false;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<ja.PlayerState> get playerStateStream =>
      _playerStateController.stream;

  @override
  bool get playing => _playing;

  @override
  Future<void> setFilePath(String path, {MediaItem? tag}) async {}

  @override
  Future<void> setUrl(String url, {MediaItem? tag}) async {}

  @override
  Future<void> play() async {
    _playing = true;
    _playerStateController.add(
      ja.PlayerState(true, ja.ProcessingState.ready),
    );
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _playerStateController.add(
      ja.PlayerState(false, ja.ProcessingState.ready),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    _positionController.add(position);
  }

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _playerStateController.close();
  }
}

void main() {
  testWidgets(
    'InfiniteMusicApp builds and shows the real root navigation '
    '(Home/Search/Library/Profile)',
    (tester) async {
      final db = AppDatabase.forTesting();
      final syncService = SyncService(
        api: _NoopCatalogApi(),
        db: db,
      );
      final fakeAudio = FakeAudioPlayerController();
      final playerState = PlayerState(controller: fakeAudio);
      final catalogProvider = CatalogProvider.forTesting(
        db: db,
        syncService: syncService,
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final library = LibraryStore(prefs);

      addTearDown(() async {
        catalogProvider.dispose();
        playerState.dispose();
        library.dispose();
        await db.close();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PlayerState>.value(value: playerState),
            ChangeNotifierProvider<CatalogProvider>.value(
              value: catalogProvider,
            ),
            ChangeNotifierProvider<LibraryStore>.value(value: library),
            ChangeNotifierProvider<LocalMusicProvider>(
              create: (_) => LocalMusicProvider(),
            ),
          ],
          child: MaterialApp(
            title: 'Infinite Music',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: const RootShell(),
          ),
        ),
      );

      // Give the real widget tree one frame to build without waiting for
      // unrelated/background animations to settle indefinitely.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.textContaining('Abhilash'), findsOneWidget);
    },
  );
}
