import '../models/song.dart';

/// TEST/DEMO DATA ONLY (audit fix #4) — no production screen or provider
/// reads this anymore. The real catalog now flows through
/// Backend -> ApiService -> SyncService -> AppDatabase -> CatalogProvider,
/// with CatalogProvider as the single source of truth for Home, Library,
/// and Search. This file exists only in case a future widget test wants
/// fixed sample data without spinning up a database.
final List<Song> mockCatalog = [
  Song(
    id: '1',
    title: 'Midnight Drift',
    artist: 'Arka Sen',
    artworkUrl: '',
    streamUrl: '',
    duration: const Duration(minutes: 3, seconds: 47),
    isDownloaded: true,
    fileSizeMb: 4.2,
  ),
  Song(
    id: '2',
    title: 'Neon Hours',
    artist: 'Levit',
    artworkUrl: '',
    streamUrl: '',
    duration: const Duration(minutes: 4, seconds: 2),
    isDownloaded: true,
    fileSizeMb: 3.8,
  ),
  Song(
    id: '3',
    title: 'Static Bloom',
    artist: 'Rhea K.',
    artworkUrl: '',
    streamUrl: '',
    duration: const Duration(minutes: 3, seconds: 18),
  ),
  Song(
    id: '4',
    title: 'Amber Skies',
    artist: 'Nova Loop',
    artworkUrl: '',
    streamUrl: '',
    duration: const Duration(minutes: 3, seconds: 55),
    isDownloaded: true,
    fileSizeMb: 5.1,
  ),
  Song(
    id: '5',
    title: 'Echo Chamber',
    artist: 'Wilt',
    artworkUrl: '',
    streamUrl: '',
    duration: const Duration(minutes: 2, seconds: 59),
  ),
  Song(
    id: '6',
    title: 'Glass Petals',
    artist: 'Anya M.',
    artworkUrl: '',
    streamUrl: '',
    duration: const Duration(minutes: 4, seconds: 10),
    isDownloaded: true,
    fileSizeMb: 4.6,
  ),
  Song(
    id: '7',
    title: 'Velvet Static',
    artist: 'Kado',
    artworkUrl: '',
    streamUrl: '',
    duration: const Duration(minutes: 3, seconds: 2),
    isDownloaded: true,
    fileSizeMb: 3.4,
  ),
  Song(
    id: '8',
    title: 'Slowburn',
    artist: 'Rhea K.',
    artworkUrl: '',
    streamUrl: '',
    duration: const Duration(minutes: 3, seconds: 33),
  ),
];
