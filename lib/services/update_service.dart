import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

const _repo = 'Karthik77-kk/kfit';
const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';
const _assetName = 'kfit.apk';

class AppUpdateInfo {
  final String tag;
  final int build;
  final String versionName;
  final String notes;
  final String apkUrl;
  final int sizeBytes;

  const AppUpdateInfo({
    required this.tag,
    required this.build,
    required this.versionName,
    required this.notes,
    required this.apkUrl,
    required this.sizeBytes,
  });
}

class UpdateService {
  UpdateService({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  /// Extracts the build number (commit count) from a tag like `v2.3.272` → 272.
  /// Returns null if the tag doesn't match the expected format.
  static int? buildFromTag(String tag) {
    final parts = tag.split('.');
    if (parts.length < 3) return null;
    return int.tryParse(parts.last);
  }

  /// Parses the GitHub releases/latest JSON into [AppUpdateInfo].
  /// Returns null if the response is malformed or the kfit.apk asset is missing.
  static AppUpdateInfo? parseLatest(Map<String, dynamic> json) {
    try {
      final tag = json['tag_name'] as String? ?? '';
      final build = buildFromTag(tag);
      if (build == null) return null;

      final assets = (json['assets'] as List<dynamic>?) ?? [];
      final asset = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] as String?) == _assetName,
        orElse: () => {},
      );
      if (asset.isEmpty) return null;

      final apkUrl = asset['browser_download_url'] as String? ?? '';
      if (apkUrl.isEmpty) return null;

      return AppUpdateInfo(
        tag: tag,
        build: build,
        versionName: tag.replaceFirst('v', ''),
        notes: (json['body'] as String?) ?? '',
        apkUrl: apkUrl,
        sizeBytes: (asset['size'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetches the latest release from GitHub unconditionally.
  /// Returns [AppUpdateInfo] if the release has a kfit.apk asset, null otherwise.
  /// Use this right before downloading to get a fresher URL than the initial check.
  Future<AppUpdateInfo?> fetchLatestInfo() async {
    try {
      final response = await _client
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/vnd.github.v3+json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return parseLatest(json);
    } catch (_) {
      return null;
    }
  }

  /// Checks GitHub for a newer release. Returns [AppUpdateInfo] if an update
  /// exists, null if already up-to-date, network fails, or the API errors.
  Future<AppUpdateInfo?> checkForUpdate(int currentBuild) async {
    try {
      final response = await _client
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/vnd.github.v3+json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final info = parseLatest(json);
      if (info == null || info.build <= currentBuild) return null;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the APK from [info.apkUrl] to the temp directory, calling
  /// [onProgress] with a 0.0–1.0 fraction as bytes arrive.
  /// Returns the local [File] on success.
  Future<File> downloadApk(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final tmp = await getTemporaryDirectory();
    final dest = File('${tmp.path}/kfit_${info.build}.apk');

    final request = http.Request('GET', Uri.parse(info.apkUrl));
    final response = await _client.send(request);

    final total = response.contentLength ?? info.sizeBytes;
    var received = 0;

    final sink = dest.openWrite();
    await response.stream.listen((chunk) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0 && onProgress != null) {
        onProgress(received / total);
      }
    }).asFuture<void>();
    await sink.flush();
    await sink.close();

    return dest;
  }

  /// Opens the downloaded APK with the system package installer.
  Future<void> install(File apkFile) async {
    await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );
  }
}
