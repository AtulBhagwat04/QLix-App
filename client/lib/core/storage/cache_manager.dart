import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class CacheManager {
  static const String _settingsBoxName = 'app_settings';
  static const String _sessionBoxName =
      'guest_sessions'; // maps session code -> participant details

  late Box _settingsBox;
  late Box _sessionBox;

  Future<void> init() async {
    if (kIsWeb) {
      Hive.init('');
    } else {
      await Hive.initFlutter();
    }
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _sessionBox = await Hive.openBox(_sessionBoxName);

    // Initialize a persistent unique device ID if not existing
    if (getDeviceId() == null) {
      final deviceId = const Uuid().v4();
      await _settingsBox.put('device_id', deviceId);
    }
  }

  String? getDeviceId() {
    return _settingsBox.get('device_id') as String?;
  }

  String? getServerIpOverride() {
    return _settingsBox.get('server_ip_override') as String?;
  }

  Future<void> saveServerIpOverride(String ip) async {
    await _settingsBox.put('server_ip_override', ip);
  }

  Future<void> saveLastParticipantName(String name) async {
    await _settingsBox.put('participant_name', name);
  }

  String getParticipantName() {
    return (_settingsBox.get('participant_name') as String?) ?? 'Anonymous';
  }

  Future<void> saveSessionParticipant({
    required String sessionCode,
    required String participantId,
    required String name,
  }) async {
    await _sessionBox.put(sessionCode, {
      'participantId': participantId,
      'name': name,
    });
  }

  Map<dynamic, dynamic>? getSessionParticipant(String sessionCode) {
    final data = _sessionBox.get(sessionCode);
    if (data != null) {
      return data as Map<dynamic, dynamic>;
    }
    return null;
  }

  Future<void> saveVotedPollId(String sessionCode, String pollId) async {
    final existing = getVotedPollIds(sessionCode);
    if (!existing.contains(pollId)) {
      existing.add(pollId);
      await _settingsBox.put('voted_polls_$sessionCode', existing);
    }
  }

  List<String> getVotedPollIds(String sessionCode) {
    final list = _settingsBox.get('voted_polls_$sessionCode') as List?;
    if (list != null) {
      return List<String>.from(list);
    }
    return [];
  }

  static const String _sessionsCacheKey = 'cached_host_sessions';
  static const String _statsCacheKey = 'cached_overview_stats';

  Future<void> saveCachedSessions(List<Map<String, dynamic>> sessions) async {
    final jsonable = sessions.map((s) => Map<String, dynamic>.from(s)).toList();
    await _settingsBox.put(_sessionsCacheKey, jsonable);
  }

  List<Map<String, dynamic>> getCachedSessions() {
    final raw = _settingsBox.get(_sessionsCacheKey);
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  Future<void> saveCachedOverviewStats(Map<String, dynamic> stats) async {
    await _settingsBox.put(_statsCacheKey, Map<String, dynamic>.from(stats));
  }

  Map<String, dynamic>? getCachedOverviewStats() {
    final raw = _settingsBox.get(_statsCacheKey);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Future<void> clearCache() async {
    await _settingsBox.clear();
    await _sessionBox.clear();
  }
}
