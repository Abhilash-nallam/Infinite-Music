import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../database/song_mapper.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/app_preferences.dart';
import '../services/sync_service.dart';

/// The single source of truth for catalog data in the UI (audit fix #3/#4).
/// Home, Library, and Search all read through this provider — none of them
/// touch AppDatabase, ApiService, or mock_data.dart directly. That means
/// there's exactly one place catalog state can diverge from what's synced,
/// and exactly one place to fix it if it does.
///
/// `songs` updates automatically whenever a sync writes to the DB, since
/// it's driven by a live Drift stream rather than a one-time fetch.
class CatalogProvider extends ChangeNotifier {
  final AppDatabase db;
  final SyncService syncService;
  final AppPreferences? settings;

  List<Song> _songs = [];
  bool _isSyncing = false;
  String? _syncError;
  StreamSubscription<List<SongRow>>? _subscription;
  bool _disposed = false;

  /// Test-only constructor for widget tests that need the real navigation
  /// tree but do not need a live Drift database. It deliberately creates no
  /// database subscription and no asynchronous reload, so the test has no
  /// background database isolate to shut down.
  CatalogProvider.forTesting({
    required this.db,
    required this.syncService,
    this.settings,
  });

  CatalogProvider({
    required this.db,
    required this.syncService,
    this.settings,
    bool autoSync = true,
  }) {
    _subscription = db.watchAllSongs().listen((rows) {
      if (_disposed) return;
      _songs = rows.map((r) => r.toSong()).toList();
      notifyListeners();
    });
    // Load the current persisted catalog immediately as well as subscribing
    // to future changes. Drift stream delivery is asynchronous, so relying
    // solely on the first stream event can leave callers observing an empty
    // in-memory catalog immediately after a completed sync.
    unawaited(_reloadFromDatabase());
    if (autoSync && !(settings?.dataSaver ?? false)) unawaited(syncNow());
  }

  List<Song> get songs => _songs;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  bool get hasCatalog => _songs.isNotEmpty;

  List<Song> get downloadedSongs =>
      _songs.where((s) => s.isDownloaded).toList(growable: false);

  List<Song> get likedSongs =>
      _songs.where((s) => s.isLiked).toList(growable: false);

  Future<void> syncNow() async {
    if (_disposed) return;
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    try {
      await syncService.syncCatalog();
      await _reloadFromDatabase();
    } on ApiException catch (e) {
      // Roadmap section 10: keep the local catalog usable when the network
      // is unavailable rather than blocking the UI — _songs (already
      // loaded from the DB stream) is left untouched, we just surface the
      // error for an optional banner.
      if (_disposed) return;
      _syncError = e.message;
    } catch (e) {
      if (_disposed) return;
      _syncError = e.toString();
      // Preserve/refresh the cached catalog even when the network sync fails.
      await _reloadFromDatabase();
    }
    // The provider may have been disposed while the sync/reload above was
    // still in flight (e.g. the user navigated away). Calling
    // notifyListeners() on a disposed ChangeNotifier throws, so this guard
    // must be the last check before touching state.
    if (_disposed) return;
    _isSyncing = false;
    notifyListeners();
  }

  Future<void> _reloadFromDatabase() async {
    final rows = await db.watchAllSongs().first;
    if (_disposed) return;
    _songs = rows.map((r) => r.toSong()).toList();
    notifyListeners();
  }

  /// Audit fix (#5): local, offline-capable search — the PRIMARY search
  /// path. Backed by Drift's SQL LIKE against title/artist/albumName, not
  /// a remote call, so it works with no network at all.
  Stream<List<Song>> watchSearch(String query) {
    return db.watchSearchSongs(query).map((rows) => rows.map((r) => r.toSong()).toList());
  }

  Future<void> setLiked(String songId, bool liked) async {
    await db.setLiked(songId, liked);
  }

  Future<void> toggleLiked(Song song) async {
    if (song.isLocal) return;
    await setLiked(song.id, !song.isLiked);
    // No manual state mutation needed — the watchAllSongs() stream above
    // picks up the DB write and rebuilds _songs automatically.
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
