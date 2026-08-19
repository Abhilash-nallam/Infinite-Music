import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent app settings used by both local-device playback and the future
/// catalog player. These are user preferences, not critical application data.
class AppPreferences extends ChangeNotifier {
  static const _autoplayKey = 'autoplay';
  static const _wifiOnlyKey = 'wifi_only_downloads';
  static const _dataSaverKey = 'data_saver';
  static const _notificationsKey = 'playback_notifications';
  static const _qualityKey = 'audio_quality';

  final SharedPreferences _prefs;

  AppPreferences(this._prefs);

  bool get autoplay => _prefs.getBool(_autoplayKey) ?? true;
  bool get wifiOnlyDownloads => _prefs.getBool(_wifiOnlyKey) ?? true;
  bool get dataSaver => _prefs.getBool(_dataSaverKey) ?? false;
  bool get notifications => _prefs.getBool(_notificationsKey) ?? true;
  String get audioQuality => _prefs.getString(_qualityKey) ?? 'Standard';

  Future<void> setAutoplay(bool value) async {
    await _prefs.setBool(_autoplayKey, value);
    notifyListeners();
  }

  Future<void> setWifiOnlyDownloads(bool value) async {
    await _prefs.setBool(_wifiOnlyKey, value);
    notifyListeners();
  }

  Future<void> setDataSaver(bool value) async {
    await _prefs.setBool(_dataSaverKey, value);
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    await _prefs.setBool(_notificationsKey, value);
    notifyListeners();
  }

  Future<void> setAudioQuality(String value) async {
    await _prefs.setString(_qualityKey, value);
    notifyListeners();
  }
}
