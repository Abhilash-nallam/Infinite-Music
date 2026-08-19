import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import '../database/app_database.dart';

class SyncResult {
  final List<SongsCompanion> upserts;
  final List<String> deletedIds;
  final int catalogVersion;

  SyncResult({
    required this.upserts,
    required this.deletedIds,
    required this.catalogVersion,
  });
}

/// Thrown for any non-2xx response, carrying enough detail to distinguish
/// "network unreachable" from "server rejected the request" in the UI/logs.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Interface seam so SyncService can be unit tested against a fake
/// implementation instead of real HTTP — see test/sync_service_test.dart.
abstract class CatalogApi {
  Future<SyncResult> fetchSync(int sinceVersion);
}

/// Talks to the Infinite Music backend (see /infinite_music_backend).
///
/// Audit fix (#11): base URL is now fully configurable rather than a
/// hardcoded constant, since 10.0.2.2 (the Android emulator's alias for the
/// host machine's localhost) is ONLY valid for emulator development. Pass
/// your computer's LAN IP for a physical device, e.g.
///   ApiService(baseUrl: 'http://192.168.1.42:3000/api/v1')
/// or your real deployed backend's URL in production, e.g.
///   ApiService(baseUrl: 'https://api.infinitemusic.example.com/v1')
///
/// `ApiService.forEmulator()` exists purely to make the emulator-only
/// nature of 10.0.2.2 explicit at the call site instead of an unlabeled
/// default that's easy to accidentally ship.
class ApiService implements CatalogApi {
  final String baseUrl;

  ApiService({required String baseUrl})
      : baseUrl = _normalizeBaseUrl(baseUrl);

  static String _normalizeBaseUrl(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (normalized.isEmpty || uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(value, 'baseUrl', 'must be a valid absolute HTTP(S) URL');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError.value(value, 'baseUrl', 'scheme must be http or https');
    }
    return normalized;
  }

  factory ApiService.forEmulator({int port = 3000}) =>
      ApiService(baseUrl: 'http://10.0.2.2:$port/api/v1');

  factory ApiService.forHost(String hostOrIp, {int port = 3000}) =>
      ApiService(baseUrl: 'http://$hostOrIp:$port/api/v1');

  @override
  Future<SyncResult> fetchSync(int sinceVersion) async {
    if (sinceVersion < 0) {
      throw ApiException('sinceVersion cannot be negative');
    }
    final uri = Uri.parse('$baseUrl/catalog/sync?version=$sinceVersion');
    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw ApiException('Network error reaching $baseUrl: $e');
    }

    if (response.statusCode != 200) {
      throw _apiExceptionFromResponse(response);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      throw ApiException('Malformed sync response JSON: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Malformed sync response: expected a JSON object');
    }

    final catalogVersion = _requiredInt(decoded['catalogVersion'], 'catalogVersion');
    if (catalogVersion < sinceVersion) {
      throw ApiException(
        'Invalid sync response: catalogVersion=$catalogVersion is behind requested version=$sinceVersion',
      );
    }

    final songsJson = _mapList(decoded['songs'], 'songs');
    final deletionsJson = _mapList(decoded['deletions'], 'deletions');

    final upserts = <SongsCompanion>[];
    for (final j in songsJson) {
      final id = _requiredString(j['id'], 'songs[].id');
      final title = _requiredString(j['title'], 'songs[].title');
      final artist = _requiredString(j['artist'], 'songs[].artist');
      final version = _requiredInt(j['version'], 'songs[].version');
      if (version <= sinceVersion || version > catalogVersion) {
        throw ApiException(
          'Invalid sync response: song $id has version=$version outside ($sinceVersion, $catalogVersion]',
        );
      }
      upserts.add(
        SongsCompanion.insert(
          id: id,
          title: title,
          artist: artist,
          artistId: Value(_nullableString(j['artistId'], 'songs[].artistId')),
          albumId: Value(_nullableString(j['albumId'], 'songs[].albumId')),
          albumName: Value(_nullableString(j['albumName'], 'songs[].albumName')),
          artworkUrl: Value(_nullableString(j['artworkUrl'], 'songs[].artworkUrl') ?? ''),
          streamUrl: Value(_nullableString(j['streamUrl'], 'songs[].streamUrl') ?? ''),
          downloadUrl: Value(_nullableString(j['downloadUrl'], 'songs[].downloadUrl')),
          durationMs: Value(_nonNegativeInt(j['durationMs'], 'songs[].durationMs') ?? 0),
          fileSizeBytes: Value(_nonNegativeInt(j['fileSizeBytes'], 'songs[].fileSizeBytes')),
          mimeType: Value(_nullableString(j['mimeType'], 'songs[].mimeType')),
          version: Value(version),
          createdAt: Value(_nullableInt(j['createdAt'], 'songs[].createdAt')),
          updatedAt: Value(_nullableInt(j['updatedAt'], 'songs[].updatedAt')),
        ),
      );
    }

    final deletedIds = <String>[];
    for (final d in deletionsJson) {
      final id = _requiredString(d['id'], 'deletions[].id');
      final version = _requiredInt(d['version'], 'deletions[].version');
      if (version <= sinceVersion || version > catalogVersion) {
        throw ApiException(
          'Invalid sync response: deletion $id has version=$version outside ($sinceVersion, $catalogVersion]',
        );
      }
      deletedIds.add(id);
    }

    return SyncResult(
      upserts: upserts,
      deletedIds: deletedIds,
      catalogVersion: catalogVersion,
    );
  }

  ApiException _apiExceptionFromResponse(http.Response response) {
    var message = 'HTTP ${response.statusCode}';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        final serverMessage = error['message'];
        if (serverMessage is String && serverMessage.isNotEmpty) {
          message = '$message — $serverMessage';
        }
      }
    } catch (_) {}
    return ApiException(message, statusCode: response.statusCode);
  }

  static List<Map<String, dynamic>> _mapList(dynamic value, String field) {
    if (value == null) return <Map<String, dynamic>>[];
    if (value is! List) throw ApiException('Malformed sync response: $field must be an array');
    final result = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map) throw ApiException('Malformed sync response: $field contains a non-object item');
      result.add(Map<String, dynamic>.from(item));
    }
    return result;
  }

  static String _requiredString(dynamic value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw ApiException('Malformed sync response: $field must be a non-empty string');
    }
    return value;
  }

  static String? _nullableString(dynamic value, String field) {
    if (value == null) return null;
    if (value is! String) throw ApiException('Malformed sync response: $field must be a string or null');
    return value;
  }

  static int _requiredInt(dynamic value, String field) {
    if (value is! int) throw ApiException('Malformed sync response: $field must be an integer');
    return value;
  }

  static int? _nullableInt(dynamic value, String field) {
    if (value == null) return null;
    if (value is! int) throw ApiException('Malformed sync response: $field must be an integer or null');
    return value;
  }

  static int? _nonNegativeInt(dynamic value, String field) {
    final result = _nullableInt(value, field);
    if (result != null && result < 0) throw ApiException('Malformed sync response: $field cannot be negative');
    return result;
  }

  /// Secondary/backend search (audit item #5) — NOT the primary search
  /// path. The app should call AppDatabase.searchSongs() for offline local
  /// search; this exists only for a future "search the full remote catalog
  /// beyond what's synced locally" capability.
  Future<List<Map<String, dynamic>>> searchRemote(String query) async {
    final uri = Uri.parse('$baseUrl/search?q=${Uri.encodeQueryComponent(query)}');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw ApiException('Remote search failed', statusCode: response.statusCode);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['songs'] as List).cast<Map<String, dynamic>>();
  }
}
