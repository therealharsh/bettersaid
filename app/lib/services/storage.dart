import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // Secret management (stored in memory only for security)
  static final Map<String, String> _secrets = {};

  // Session management
  Future<void> setSessionId(String publicCode, String sessionId) async {
    await _prefs.setString('session_$publicCode', sessionId);
  }

  Future<String?> getSessionId(String publicCode) async {
    return _prefs.getString('session_$publicCode');
  }

  // Secret management (memory only - never persisted)
  Future<void> setSecret(String publicCode, String secret) async {
    _secrets[publicCode] = secret;
  }

  Future<String?> getSecret(String publicCode) async {
    return _secrets[publicCode];
  }

  // Display name for room
  Future<void> setDisplayName(String publicCode, String displayName) async {
    await _prefs.setString('display_name_$publicCode', displayName);
  }

  Future<String?> getDisplayName(String publicCode) async {
    return _prefs.getString('display_name_$publicCode');
  }

  // Room goal
  Future<void> setRoomGoal(String publicCode, String goal) async {
    await _prefs.setString('goal_$publicCode', goal);
  }

  Future<String?> getRoomGoal(String publicCode) async {
    return _prefs.getString('goal_$publicCode');
  }

  // TTL expiration
  Future<void> setTtlExpiration(String publicCode, DateTime expiration) async {
    await _prefs.setString('ttl_$publicCode', expiration.toIso8601String());
  }

  Future<DateTime?> getTtlExpiration(String publicCode) async {
    final ttlString = _prefs.getString('ttl_$publicCode');
    return ttlString != null ? DateTime.parse(ttlString) : null;
  }

  // Last message timestamp for polling
  Future<void> setLastMessageTime(String publicCode, DateTime timestamp) async {
    await _prefs.setString('last_msg_$publicCode', timestamp.toIso8601String());
  }

  Future<DateTime?> getLastMessageTime(String publicCode) async {
    final timeString = _prefs.getString('last_msg_$publicCode');
    return timeString != null ? DateTime.parse(timeString) : null;
  }

  // Settings
  Future<void> setThemeMode(String mode) async {
    await _prefs.setString('theme_mode', mode);
  }

  Future<String> getThemeMode() async {
    return _prefs.getString('theme_mode') ?? 'system';
  }

  Future<void> setTelemetryEnabled(bool enabled) async {
    await _prefs.setBool('telemetry_enabled', enabled);
  }

  Future<bool> getTelemetryEnabled() async {
    return _prefs.getBool('telemetry_enabled') ?? true;
  }

  // Clean up room data
  Future<void> clearRoom(String publicCode) async {
    final keys = [
      'session_$publicCode',
      'display_name_$publicCode',
      'goal_$publicCode',
      'ttl_$publicCode',
      'last_msg_$publicCode',
    ];

    for (final key in keys) {
      await _prefs.remove(key);
    }

    // Remove secret from memory
    _secrets.remove(publicCode);
  }

  // Get all stored room codes (for cleanup/debugging)
  Future<List<String>> getStoredRooms() async {
    final keys = _prefs.getKeys();
    final roomCodes = <String>{};

    for (final key in keys) {
      if (key.startsWith('session_')) {
        roomCodes.add(key.substring(8)); // Remove 'session_' prefix
      }
    }

    return roomCodes.toList();
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs.clear();
    _secrets.clear();
  }
}

// Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized with SharedPreferences');
});

// Async provider for initialization
final storageServiceAsyncProvider = FutureProvider<StorageService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return StorageService(prefs);
});
