import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Backs up / restores the app's data JSON to a shared private GitHub repo —
/// one file per user, keyed by a chosen username + id (path
/// `users/<username>-<id>.json`). Every PUT is a commit, so the repo doubles as
/// a versioned store.
///
/// The GitHub token is injected at build via `--dart-define GH_BACKUP_TOKEN=…`
/// from a GitHub Actions secret (same pattern as HF_TOKEN / FDC_API_KEY) — never
/// committed to source. An empty token or repo ⇒ cloud sync is simply disabled,
/// and the app still works fully via local Export/Import.
///
/// ⚠️ A build-injected token is extractable from the APK and grants access to
/// the whole repo, and a chosen username+id is identification, not a password —
/// so this is for PERSONAL / TESTING use, NOT a public multi-user product. A
/// real product needs a backend that authenticates each user.
class CloudBackupService {
  CloudBackupService._();
  static final CloudBackupService instance = CloudBackupService._();

  static const String token =
      String.fromEnvironment('GH_BACKUP_TOKEN', defaultValue: '');
  static const String repo =
      String.fromEnvironment('GH_BACKUP_REPO', defaultValue: '');
  static const String branch =
      String.fromEnvironment('GH_BACKUP_BRANCH', defaultValue: 'main');

  /// Cloud sync is available only when a token + a valid repo were injected.
  static bool get enabled => token.isNotEmpty && isValidRepo(repo);

  static const _ua = 'KFitness/1.0';
  static const _timeout = Duration(seconds: 15);

  static const _userKey = 'cloud_username';
  static const _idKey = 'cloud_userid';
  static const _lastKey = 'cloud_last_backup_ms';
  static const _shaPrefix = 'cloud_sha_';

  // ── Account (username + id) ──────────────────────────────────────────────────
  Future<String?> username() async =>
      (await SharedPreferences.getInstance()).getString(_userKey);
  Future<String?> userId() async =>
      (await SharedPreferences.getInstance()).getString(_idKey);
  Future<bool> get hasAccount async =>
      (await username())?.isNotEmpty == true &&
      (await userId())?.isNotEmpty == true;
  Future<int> lastBackupMs() async =>
      (await SharedPreferences.getInstance()).getInt(_lastKey) ?? 0;

  Future<void> saveAccount(String username, String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, username.trim());
    await prefs.setString(_idKey, id.trim());
  }

  // ── Pure helpers (testable) ──────────────────────────────────────────────────
  /// Repo path for a username+id pair: `users/<slug>-<slug>.json`.
  static String filePathFor(String username, String id) =>
      'users/${_slug(username)}-${_slug(id)}.json';

  static String _slug(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static bool isValidRepo(String r) =>
      RegExp(r'^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$').hasMatch(r.trim());

  /// True when username + id both slugify to a non-empty key.
  static bool isValidAccount(String username, String id) =>
      _slug(username).isNotEmpty && _slug(id).isNotEmpty;

  /// Decodes a GitHub Contents API `content` field (base64, newline-chunked).
  static String decodeContentField(Map<String, dynamic> body) {
    final raw = (body['content'] as String?) ?? '';
    return utf8.decode(base64Decode(raw.replaceAll(RegExp(r'\s'), '')));
  }

  static String errorFor(int status) {
    switch (status) {
      case 401:
        return 'GitHub auth failed — token invalid or expired.';
      case 403:
        return 'GitHub denied the request (token scope or rate limit).';
      case 404:
        return 'Repo not found — check the backup repo setting.';
      case 409:
      case 422:
        return 'Backup conflict — try again.';
      default:
        return 'GitHub error $status.';
    }
  }

  // ── API ──────────────────────────────────────────────────────────────────────
  static Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': _ua,
      };

  static Uri _contentsUri(String path) =>
      Uri.parse('https://api.github.com/repos/$repo/contents/$path');

  /// Pushes [jsonContent] to the current account's file (create or update).
  /// Returns a status message. Throws [Exception] on misconfig / HTTP error.
  Future<String> backup(String jsonContent) async {
    if (!enabled) throw Exception('Cloud sync not configured');
    final u = await username();
    final id = await userId();
    if (u == null || id == null || !isValidAccount(u, id)) {
      throw Exception('Set a username and id first');
    }
    final path = filePathFor(u, id);
    final prefs = await SharedPreferences.getInstance();
    var sha = prefs.getString('$_shaPrefix$path');
    sha ??= await _fetchSha(path);

    final body = <String, dynamic>{
      'message': 'K Fitness backup ($u) ${DateTime.now().toIso8601String()}',
      'content': base64Encode(utf8.encode(jsonContent)),
      'branch': branch,
      if (sha != null) 'sha': sha,
    };
    final resp = await http
        .put(_contentsUri(path), headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final newSha =
          ((jsonDecode(resp.body) as Map)['content'] as Map?)?['sha'] as String?;
      if (newSha != null) await prefs.setString('$_shaPrefix$path', newSha);
      await prefs.setInt(_lastKey, DateTime.now().millisecondsSinceEpoch);
      return 'Backed up as $u';
    }
    throw Exception(errorFor(resp.statusCode));
  }

  /// Fetches the backup JSON for [username]+[id], or null when none exists.
  Future<String?> restore(String username, String id) async {
    if (!enabled) throw Exception('Cloud sync not configured');
    if (!isValidAccount(username, id)) {
      throw Exception('Enter a username and id');
    }
    final path = filePathFor(username, id);
    final uri = _contentsUri(path).replace(queryParameters: {'ref': branch});
    final resp = await http.get(uri, headers: _headers).timeout(_timeout);
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) throw Exception(errorFor(resp.statusCode));
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final sha = decoded['sha'] as String?;
    if (sha != null) {
      await (await SharedPreferences.getInstance())
          .setString('$_shaPrefix$path', sha);
    }
    return decodeContentField(decoded);
  }

  /// Auto-backup hook: pushes [buildJson]'s result if cloud sync is on, an
  /// account exists, and it's been ≥1 day since the last push (or never).
  /// Silent on failure. Returns true if a backup was pushed.
  Future<bool> autoBackupIfDue(Future<String> Function() buildJson) async {
    if (!enabled || !await hasAccount) return false;
    final last = await lastBackupMs();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != 0 && now - last < const Duration(days: 1).inMilliseconds) {
      return false;
    }
    try {
      await backup(await buildJson());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _fetchSha(String path) async {
    try {
      final uri = _contentsUri(path).replace(queryParameters: {'ref': branch});
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        return (jsonDecode(resp.body) as Map<String, dynamic>)['sha'] as String?;
      }
    } catch (_) {/* 404 / error → treat as create */}
    return null;
  }
}
