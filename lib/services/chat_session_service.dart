import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ── Data models ────────────────────────────────────────────────────────────────

class ChatSessionMessage {
  final String text;
  final bool   isUser;
  final DateTime timestamp;

  const ChatSessionMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'text':      text,
    'isUser':    isUser,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatSessionMessage.fromJson(Map<String, dynamic> j) =>
      ChatSessionMessage(
        text:      j['text']  as String,
        isUser:    j['isUser'] as bool,
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
}

class ChatSession {
  final String   id;
  String         title;
  final DateTime createdAt;
  DateTime       updatedAt;
  final List<ChatSessionMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
    'id':        id,
    'title':     title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages':  messages.map((m) => m.toJson()).toList(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
    id:        j['id']    as String,
    title:     j['title'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    messages:  (j['messages'] as List)
        .map((m) => ChatSessionMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}

// ── Service ────────────────────────────────────────────────────────────────────

class ChatSessionService {
  static const _prefKey  = 'chat_sessions_v1';
  static const _maxSessions = 20;

  // Load all sessions from SharedPreferences, newest first
  static Future<List<ChatSession>> loadSessions() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final raw     = prefs.getString(_prefKey);
      if (raw == null) return [];
      final list    = jsonDecode(raw) as List;
      final sessions = list
          .map((j) => ChatSession.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSession(ChatSession session) async {
    final sessions = await loadSessions();
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      sessions[idx] = session;
    } else {
      sessions.insert(0, session);
    }
    // Keep only most recent _maxSessions
    if (sessions.length > _maxSessions) {
      sessions.removeRange(_maxSessions, sessions.length);
    }
    await _persist(sessions);
  }

  static Future<void> deleteSession(String id) async {
    final sessions = await loadSessions();
    sessions.removeWhere((s) => s.id == id);
    await _persist(sessions);
  }

  static Future<void> _persist(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  /// Auto-generates a session title from the first user message.
  static String titleFromFirstMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return 'Chat';
    final words = trimmed.split(RegExp(r'\s+'));
    final title = words.take(6).join(' ');
    return title.length > 40 ? '${title.substring(0, 40)}…' : title;
  }
}
